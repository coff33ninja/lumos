package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"time"

	"golang.org/x/crypto/pbkdf2"
)

func (s *Server) loadState() error {
	cfg := s.cfgSnapshot()
	path := strings.TrimSpace(cfg.StateFile)
	if path == "" {
		return nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	var env persistedEnvelope
	if err := json.Unmarshal(raw, &env); err == nil && env.Encrypted {
		st, err := decryptStateEnvelope(env, s.cfgSnapshot().StateEncryptionKey)
		if err != nil {
			return err
		}
		s.applyPersistedState(st)
		return nil
	}
	var st PersistedState
	if err := json.Unmarshal(raw, &st); err != nil {
		var compat persistedEnvelope
		if err2 := json.Unmarshal(raw, &compat); err2 == nil && compat.Plain != nil {
			s.applyPersistedState(*compat.Plain)
			return nil
		}
		return err
	}
	s.applyPersistedState(st)
	return nil
}

func (s *Server) applyPersistedState(st PersistedState) {
	s.mu.Lock()
	defer s.mu.Unlock()
	cfgFromFile := s.cfg.ConfigFromFile
	if strings.TrimSpace(st.AgentID) != "" {
		s.cfg.AgentID = st.AgentID
	}
	if strings.TrimSpace(st.AdvertiseAddr) != "" {
		s.cfg.AdvertiseAddr = st.AdvertiseAddr
	}
	s.cfg.BootstrapPeers = uniqueStrings(st.BootstrapPeers)
	// If a config file is present, explicit config values should win over
	// persisted runtime toggles to avoid stale state surprises after restart.
	if !cfgFromFile {
		s.cfg.AllowWakeWithoutPassword = st.AllowWakeWithoutPassword
		s.cfg.DryRun = st.DryRun
		if st.DefaultTokenAllowances != (ActionAllowances{}) {
			s.cfg.DefaultTokenAllowances = st.DefaultTokenAllowances
		}
		if st.TokenAllowances != nil {
			s.cfg.TokenAllowances = st.TokenAllowances
		}
		if st.RelayInboundAllowances != nil {
			s.cfg.RelayInboundAllowances = st.RelayInboundAllowances
		}
		if st.RelayOutboundAllowances != nil {
			s.cfg.RelayOutboundAllowances = st.RelayOutboundAllowances
		}
	}
	if st.SafeModeConfigured && !cfgFromFile {
		s.cfg.SafeModeEnabled = st.SafeModeEnabled
		if st.SafeModeCooldownSeconds >= 0 {
			s.cfg.SafeModeCooldownSeconds = st.SafeModeCooldownSeconds
		}
	}
	for _, p := range st.Peers {
		if strings.TrimSpace(p.AgentID) == "" || strings.TrimSpace(p.Address) == "" {
			continue
		}
		s.peers.Store(p.AgentID, p)
	}
	for _, t := range st.Tokens {
		if strings.TrimSpace(t.ID) == "" || strings.TrimSpace(t.TokenHash) == "" {
			continue
		}
		s.tokens.Store(t.ID, t)
	}
}

func (s *Server) saveState() error {
	cfg := s.cfgSnapshot()
	path := strings.TrimSpace(cfg.StateFile)
	if path == "" {
		return nil
	}
	st := PersistedState{
		AgentID:                  cfg.AgentID,
		AdvertiseAddr:            cfg.AdvertiseAddr,
		BootstrapPeers:           uniqueStrings(cfg.BootstrapPeers),
		AllowWakeWithoutPassword: cfg.AllowWakeWithoutPassword,
		DryRun:                   cfg.DryRun,
		SafeModeEnabled:          cfg.SafeModeEnabled,
		SafeModeCooldownSeconds:  cfg.SafeModeCooldownSeconds,
		SafeModeConfigured:       true,
		Peers:                    s.listPeers(),
		Tokens:                   s.listTokens(),
		DefaultTokenAllowances:   cfg.DefaultTokenAllowances,
		TokenAllowances:          cfg.TokenAllowances,
		RelayInboundAllowances:   cfg.RelayInboundAllowances,
		RelayOutboundAllowances:  cfg.RelayOutboundAllowances,
		UpdatedAt:                time.Now().UTC(),
	}
	body, err := encryptStateEnvelope(st, cfg.StateEncryptionKey)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil && filepath.Dir(path) != "." {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, body, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func (s *Server) listTokens() []AuthTokenRecord {
	out := make([]AuthTokenRecord, 0, 8)
	s.tokens.Range(func(_, value any) bool {
		t, ok := value.(AuthTokenRecord)
		if ok {
			out = append(out, t)
		}
		return true
	})
	return out
}

func deriveStateKey(passwordSecret []byte, salt string) [32]byte {
	normalizedSalt := strings.TrimSpace(salt)
	if normalizedSalt == "" {
		normalizedSalt = "lumos-state"
	}
	derived := pbkdf2.Key(passwordSecret, []byte(normalizedSalt+"|lumos-state|"), 120000, 32, sha256.New)
	var out [32]byte
	copy(out[:], derived)
	return out
}

func encryptStateEnvelope(st PersistedState, key [32]byte) ([]byte, error) {
	plain, err := json.Marshal(st)
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}
	ciphertext := gcm.Seal(nil, nonce, plain, nil)
	env := persistedEnvelope{
		Encrypted: true,
		Nonce:     base64.StdEncoding.EncodeToString(nonce),
		Data:      base64.StdEncoding.EncodeToString(ciphertext),
	}
	return json.MarshalIndent(env, "", "  ")
}

func decryptStateEnvelope(env persistedEnvelope, key [32]byte) (PersistedState, error) {
	nonce, err := base64.StdEncoding.DecodeString(env.Nonce)
	if err != nil {
		return PersistedState{}, err
	}
	ciphertext, err := base64.StdEncoding.DecodeString(env.Data)
	if err != nil {
		return PersistedState{}, err
	}
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return PersistedState{}, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return PersistedState{}, err
	}
	plain, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return PersistedState{}, err
	}
	var st PersistedState
	if err := json.Unmarshal(plain, &st); err != nil {
		return PersistedState{}, err
	}
	return st, nil
}
