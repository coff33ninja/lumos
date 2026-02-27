package main

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"fmt"
	"net/http"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

func NewAuthGuard(maxFails int, lockFor time.Duration) *AuthGuard {
	return &AuthGuard{entries: make(map[string]authState), maxFails: maxFails, lockFor: lockFor}
}

func NewNonceGuard() *NonceGuard { return &NonceGuard{entries: make(map[string]time.Time)} }

func (a *AuthGuard) Before(ip string, now time.Time) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	st := a.entries[ip]
	if !st.BlockedTil.IsZero() && now.Before(st.BlockedTil) {
		return fmt.Errorf("temporarily locked until %s", st.BlockedTil.UTC().Format(time.RFC3339))
	}
	return nil
}

func (a *AuthGuard) After(ip string, now time.Time, success bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	st := a.entries[ip]
	st.LastSeen = now
	if success {
		st.Fails = 0
		st.BlockedTil = time.Time{}
		a.entries[ip] = st
		return
	}
	st.Fails++
	if st.Fails >= a.maxFails {
		st.BlockedTil = now.Add(a.lockFor)
		st.Fails = 0
	}
	a.entries[ip] = st
}

func (n *NonceGuard) Seen(nonce string, now time.Time) bool {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.pruneLocked(now)
	_, ok := n.entries[nonce]
	return ok
}

func (n *NonceGuard) Mark(nonce string, expiry time.Time) {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.entries[nonce] = expiry
}

func (n *NonceGuard) pruneLocked(now time.Time) {
	for k, exp := range n.entries {
		if now.After(exp) {
			delete(n.entries, k)
		}
	}
}

func (s *Server) authorizePasswordOrReject(w http.ResponseWriter, r *http.Request) bool {
	ip := remoteIP(r)
	now := time.Now()
	if err := s.auth.Before(ip, now); err != nil {
		writeJSON(w, http.StatusTooManyRequests, APIResponse{OK: false, Message: err.Error()})
		return false
	}
	ok := s.authorizePassword(r) || s.authorizeToken(r)
	s.auth.After(ip, now, ok)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "invalid credentials"})
		return false
	}
	return true
}

func (s *Server) authorizeForActionOrReject(w http.ResponseWriter, r *http.Request, action string) (AuthPrincipal, bool) {
	ip := remoteIP(r)
	now := time.Now()
	if err := s.auth.Before(ip, now); err != nil {
		writeJSON(w, http.StatusTooManyRequests, APIResponse{OK: false, Message: err.Error()})
		return AuthPrincipal{}, false
	}
	if s.authorizePassword(r) {
		s.auth.After(ip, now, true)
		return AuthPrincipal{Kind: "password", Scope: "power-admin"}, true
	}
	tokenID, ok := s.authorizeTokenID(r)
	s.auth.After(ip, now, ok)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "invalid credentials"})
		return AuthPrincipal{}, false
	}
	scope := s.tokenScopeByID(tokenID)
	if !scopeAllowsAction(scope, action) {
		writePolicyDenied(w, action, "token_id="+tokenID+" scope="+scope+" denied action="+strings.ToLower(strings.TrimSpace(action)))
		return AuthPrincipal{}, false
	}
	if !s.isTokenActionAllowed(tokenID, action) {
		writePolicyDenied(w, action, "token_id="+tokenID+" denied by token policy")
		return AuthPrincipal{}, false
	}
	return AuthPrincipal{Kind: "token", TokenID: tokenID, Scope: scope}, true
}

func (s *Server) authorizePolicyReadOrReject(w http.ResponseWriter, r *http.Request) (AuthPrincipal, bool) {
	ip := remoteIP(r)
	now := time.Now()
	if err := s.auth.Before(ip, now); err != nil {
		writeJSON(w, http.StatusTooManyRequests, APIResponse{OK: false, Message: err.Error()})
		return AuthPrincipal{}, false
	}
	if s.authorizePassword(r) {
		s.auth.After(ip, now, true)
		return AuthPrincipal{Kind: "password", Scope: "power-admin"}, true
	}
	tokenID, ok := s.authorizeTokenID(r)
	s.auth.After(ip, now, ok)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "invalid credentials"})
		return AuthPrincipal{}, false
	}
	scope := s.tokenScopeByID(tokenID)
	if !scopeAllowsPolicyRead(scope) {
		writePolicyDenied(w, "policy_read", "token_id="+tokenID+" scope="+scope+" denied policy read")
		return AuthPrincipal{}, false
	}
	return AuthPrincipal{Kind: "token", TokenID: tokenID, Scope: scope}, true
}

func (s *Server) authorizePolicyWriteOrReject(w http.ResponseWriter, r *http.Request) (AuthPrincipal, bool) {
	ip := remoteIP(r)
	now := time.Now()
	if err := s.auth.Before(ip, now); err != nil {
		writeJSON(w, http.StatusTooManyRequests, APIResponse{OK: false, Message: err.Error()})
		return AuthPrincipal{}, false
	}
	if s.authorizePassword(r) {
		s.auth.After(ip, now, true)
		return AuthPrincipal{Kind: "password", Scope: "power-admin"}, true
	}
	tokenID, ok := s.authorizeTokenID(r)
	s.auth.After(ip, now, ok)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "invalid credentials"})
		return AuthPrincipal{}, false
	}
	scope := s.tokenScopeByID(tokenID)
	if !scopeAllowsPolicyWrite(scope) {
		writePolicyDenied(w, "policy_write", "token_id="+tokenID+" scope="+scope+" denied policy write")
		return AuthPrincipal{}, false
	}
	return AuthPrincipal{Kind: "token", TokenID: tokenID, Scope: scope}, true
}

func (s *Server) authorizePasswordOnlyOrReject(w http.ResponseWriter, r *http.Request) bool {
	ip := remoteIP(r)
	now := time.Now()
	if err := s.auth.Before(ip, now); err != nil {
		writeJSON(w, http.StatusTooManyRequests, APIResponse{OK: false, Message: err.Error()})
		return false
	}
	ok := s.authorizePassword(r)
	s.auth.After(ip, now, ok)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "invalid password"})
		return false
	}
	return true
}

func (s *Server) authorizePassword(r *http.Request) bool {
	pw := r.Header.Get("X-Lumos-Password")
	cfg := s.cfgSnapshot()
	return verifySecretBcrypt(pw, cfg.PasswordBcryptHash)
}

func (s *Server) authorizeToken(r *http.Request) bool {
	_, ok := s.authorizeTokenID(r)
	return ok
}

func (s *Server) authorizeTokenID(r *http.Request) (string, bool) {
	token := strings.TrimSpace(r.Header.Get("X-Lumos-Token"))
	if token == "" {
		return "", false
	}
	now := time.Now().UTC()
	sum := sha256.Sum256([]byte(token))
	hash := hex.EncodeToString(sum[:])
	found := false
	foundID := ""
	s.tokens.Range(func(_, value any) bool {
		t, ok := value.(AuthTokenRecord)
		if !ok || t.RevokedAt != nil {
			return true
		}
		if subtle.ConstantTimeCompare([]byte(t.TokenHash), []byte(hash)) == 1 {
			tCopy := t
			tCopy.LastUsedAt = &now
			s.tokens.Store(t.ID, tCopy)
			foundID = t.ID
			found = true
			return false
		}
		return true
	})
	if found {
		s.persistTokenUsageMaybe(now)
	}
	return foundID, found
}

func (s *Server) persistTokenUsageMaybe(now time.Time) {
	s.tokenPersistMu.Lock()
	if !s.tokenPersistLast.IsZero() && now.Sub(s.tokenPersistLast) < 30*time.Second {
		s.tokenPersistMu.Unlock()
		return
	}
	s.tokenPersistLast = now
	s.tokenPersistMu.Unlock()

	go func() {
		_ = s.saveState()
	}()
}

func (s *Server) tokenScopeByID(tokenID string) string {
	v, ok := s.tokens.Load(tokenID)
	if !ok {
		return "power-admin"
	}
	t, ok := v.(AuthTokenRecord)
	if !ok {
		return "power-admin"
	}
	return normalizeTokenScope(t.Scope)
}

func normalizeTokenScope(scope string) string {
	switch strings.ToLower(strings.TrimSpace(scope)) {
	case "", "power-admin":
		return "power-admin"
	case "read-only":
		return "read-only"
	case "wake-only":
		return "wake-only"
	default:
		return "power-admin"
	}
}

func scopeAllowsAction(scope, action string) bool {
	s := normalizeTokenScope(scope)
	a := strings.ToLower(strings.TrimSpace(action))
	switch s {
	case "power-admin":
		return true
	case "wake-only":
		return a == "wake"
	case "read-only":
		return false
	default:
		return false
	}
}

func scopeAllowsPolicyRead(scope string) bool {
	s := normalizeTokenScope(scope)
	return s == "power-admin" || s == "read-only"
}

func scopeAllowsPolicyWrite(scope string) bool {
	return normalizeTokenScope(scope) == "power-admin"
}

func (s *Server) authorizeClusterKey(r *http.Request) bool {
	cfg := s.cfgSnapshot()
	if strings.TrimSpace(cfg.ClusterKey) == "" {
		return false
	}
	remote := r.Header.Get("X-Lumos-Cluster-Key")
	return subtle.ConstantTimeCompare([]byte(remote), []byte(cfg.ClusterKey)) == 1
}

func (s *Server) securityMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cfg := s.cfgSnapshot()
		if cfg.TLSCertFile == "" && cfg.TLSKeyFile == "" && !cfg.AllowInsecureRemoteHTTP {
			if !isLoopbackIP(remoteIP(r)) {
				writeJSON(w, http.StatusForbidden, APIResponse{OK: false, Message: "remote HTTP disabled without TLS"})
				return
			}
		}
		if s.requiresUIAuth(r.URL.Path) {
			if !s.authorizeUIBasicAuth(w, r) {
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) requiresUIAuth(path string) bool {
	return path == "/" || path == "/v1/ui/state" || strings.HasPrefix(path, "/v1/ui/")
}

func (s *Server) authorizeUIBasicAuth(w http.ResponseWriter, r *http.Request) bool {
	user, pass, ok := r.BasicAuth()
	if !ok {
		w.Header().Set("WWW-Authenticate", `Basic realm="Lumos"`)
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte("authentication required"))
		return false
	}
	cfg := s.cfgSnapshot()
	userOK := subtle.ConstantTimeCompare([]byte(user), []byte(cfg.UIUser)) == 1
	passOK := verifySecretBcrypt(pass, cfg.UIPasswordBcryptHash)
	if !userOK || !passOK {
		w.Header().Set("WWW-Authenticate", `Basic realm="Lumos"`)
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte("invalid credentials"))
		return false
	}
	return true
}

func verifySecretBcrypt(secret, bcryptHash string) bool {
	trimmed := strings.TrimSpace(bcryptHash)
	if trimmed == "" {
		return false
	}
	return bcrypt.CompareHashAndPassword([]byte(trimmed), []byte(secret)) == nil
}
