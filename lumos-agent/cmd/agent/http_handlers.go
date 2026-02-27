package main

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"net/http"
	"os"
	"strings"
	"time"
)

func (s *Server) handlePeerRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if !s.authorizeClusterKey(r) {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "invalid cluster key"})
		return
	}
	var req PeerRegisterRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	if strings.TrimSpace(req.AgentID) == "" || strings.TrimSpace(req.Address) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "agent_id and address are required"})
		return
	}
	s.upsertPeer(req.AgentID, req.Address, req.PublicAddress, req.VPNAddress)
	_ = s.saveState()
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "peer registered"})
}

func (s *Server) handlePeerList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if !s.authorizeClusterKey(r) {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "invalid cluster key"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "peers": s.listPeers()})
}

func (s *Server) handlePeerRelay(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	var req PeerRelayRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	req.Action = strings.ToLower(strings.TrimSpace(req.Action))
	if req.Action == "" {
		s.recordAudit("relay_out", "unknown", req.TargetAgentID, req.MAC, false, "action is required", remoteIP(r))
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "action is required"})
		return
	}
	if _, ok := s.authorizeForActionOrReject(w, r, req.Action); !ok {
		s.recordAudit("relay_out", req.Action, req.TargetAgentID, req.MAC, false, "blocked by token allowance", remoteIP(r))
		return
	}
	if req.Action == "wake" && strings.TrimSpace(req.MAC) == "" {
		s.recordAudit("relay_out", req.Action, req.TargetAgentID, req.MAC, false, "mac is required for wake", remoteIP(r))
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "mac is required for wake"})
		return
	}
	// For wake, relay agent should send magic packet itself first.
	if req.Action == "wake" {
		if err := sendMagicPacket(req.MAC); err == nil {
			s.recordAudit("relay_out", "wake", req.TargetAgentID, req.MAC, true, "relay wake sent locally", remoteIP(r))
			writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "relay wake sent locally"})
			return
		}
	}
	cfg := s.cfgSnapshot()
	if strings.TrimSpace(cfg.ClusterKey) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "cluster key not configured"})
		return
	}
	targetAddress := strings.TrimSpace(req.Address)
	if targetAddress == "" && strings.TrimSpace(req.TargetAgentID) != "" {
		if p, ok := s.getPeer(req.TargetAgentID); ok {
			targetAddress = p.Address
		}
	}
	if targetAddress == "" {
		s.recordAudit("relay_out", req.Action, req.TargetAgentID, req.MAC, false, "target address not found", remoteIP(r))
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "target address not found; provide address or register peer first"})
		return
	}
	if !s.isRelayOutboundAllowed(req.TargetAgentID, req.Action) {
		s.recordAudit("relay_out", req.Action, req.TargetAgentID, req.MAC, false, "blocked by relay outbound allowance", remoteIP(r))
		writePolicyDenied(w, req.Action, relayDeniedDetail("outbound", req.TargetAgentID, req.Action))
		return
	}
	normalizedTarget, err := normalizeRelayAddress(targetAddress, true)
	if err != nil {
		s.recordAudit("relay_out", req.Action, req.TargetAgentID, req.MAC, false, "invalid relay target: "+err.Error(), remoteIP(r))
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "invalid relay target: " + err.Error()})
		return
	}
	targetAddress = normalizedTarget
	if !s.requireSafeModeApproval(w, r, req.Action, targetAddress, req.MAC) {
		s.recordAudit("relay_out", req.Action, targetAddress, req.MAC, false, "blocked by safe mode confirmation/cooldown", remoteIP(r))
		return
	}
	forwardReq := PeerForwardRequest{SourceAgentID: cfg.AgentID, TargetAgentID: req.TargetAgentID, Action: req.Action, MAC: req.MAC, TimestampUnix: time.Now().Unix()}
	if err := s.forwardCommandToPeer(targetAddress, forwardReq); err != nil {
		s.recordAudit("relay_out", req.Action, targetAddress, req.MAC, false, "relay failed: "+err.Error(), remoteIP(r))
		writeJSON(w, http.StatusBadGateway, APIResponse{OK: false, Message: "relay failed: " + err.Error()})
		return
	}
	s.markDestructiveActionExecuted(req.Action)
	s.recordAudit("relay_out", req.Action, targetAddress, req.MAC, true, "relay sent", remoteIP(r))
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "relay sent to " + targetAddress})
}

func (s *Server) handlePeerForward(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if err := s.verifyPeerSignature(r); err != nil {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "peer signature invalid: " + err.Error()})
		return
	}
	var req PeerForwardRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	cfg := s.cfgSnapshot()
	if req.TargetAgentID != "" && req.TargetAgentID != cfg.AgentID {
		s.recordAudit("relay_in", req.Action, req.TargetAgentID, req.MAC, false, "target_agent_id does not match this agent", remoteIP(r))
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "target_agent_id does not match this agent"})
		return
	}
	switch strings.ToLower(req.Action) {
	case "wake":
		if !s.isRelayInboundAllowed(req.SourceAgentID, "wake") {
			s.recordAudit("relay_in", "wake", cfg.AgentID, req.MAC, false, "blocked by relay inbound allowance", remoteIP(r))
			writePolicyDenied(w, "wake", relayDeniedDetail("inbound", req.SourceAgentID, "wake"))
			return
		}
		if strings.TrimSpace(req.MAC) == "" {
			s.recordAudit("relay_in", "wake", cfg.AgentID, req.MAC, false, "mac is required for wake", remoteIP(r))
			writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "mac is required for wake"})
			return
		}
		if err := sendMagicPacket(req.MAC); err != nil {
			s.recordAudit("relay_in", "wake", cfg.AgentID, req.MAC, false, "wake failed: "+err.Error(), remoteIP(r))
			writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "wake failed: " + err.Error()})
			return
		}
		s.recordAudit("relay_in", "wake", cfg.AgentID, req.MAC, true, "peer wake sent", remoteIP(r))
		writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "peer wake sent"})
	case "shutdown", "reboot", "sleep":
		if !s.isRelayInboundAllowed(req.SourceAgentID, req.Action) {
			s.recordAudit("relay_in", strings.ToLower(req.Action), cfg.AgentID, req.MAC, false, "blocked by relay inbound allowance", remoteIP(r))
			writePolicyDenied(w, req.Action, relayDeniedDetail("inbound", req.SourceAgentID, req.Action))
			return
		}
		if cfg.DryRun {
			s.recordAudit("relay_in", strings.ToLower(req.Action), cfg.AgentID, req.MAC, true, "dry-run peer action: "+req.Action, remoteIP(r))
			writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "dry-run peer action: " + req.Action})
			return
		}
		if err := runPowerAction(strings.ToLower(req.Action)); err != nil {
			s.recordAudit("relay_in", strings.ToLower(req.Action), cfg.AgentID, req.MAC, false, "power action failed: "+err.Error(), remoteIP(r))
			writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "power action failed: " + err.Error()})
			return
		}
		s.recordAudit("relay_in", strings.ToLower(req.Action), cfg.AgentID, req.MAC, true, "peer action executed: "+req.Action, remoteIP(r))
		writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "peer action executed: " + req.Action})
	default:
		s.recordAudit("relay_in", strings.ToLower(req.Action), cfg.AgentID, req.MAC, false, "unsupported peer action", remoteIP(r))
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "unsupported peer action"})
	}
}

func (s *Server) handleAuthPair(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if !s.authorizePasswordOnlyOrReject(w, r) {
		return
	}
	var req PairRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	label := strings.TrimSpace(req.Label)
	if label == "" {
		label = "mobile-device"
	}
	scope := normalizeTokenScope(req.Scope)
	tokenID, err := randomHex(8)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "token generation failed"})
		return
	}
	tokenValue, err := randomHex(32)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "token generation failed"})
		return
	}
	sum := sha256.Sum256([]byte(tokenValue))
	record := AuthTokenRecord{ID: tokenID, Label: label, Scope: scope, TokenHash: hex.EncodeToString(sum[:]), CreatedAt: time.Now().UTC()}
	s.tokens.Store(tokenID, record)
	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "token created but persist failed: " + err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, PairResponse{OK: true, TokenID: tokenID, Token: tokenValue, Message: "store this token securely; it is shown once"})
}

func (s *Server) handleAuthTokenList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if !s.authorizePasswordOnlyOrReject(w, r) {
		return
	}
	out := make([]AuthTokenRecord, 0, 8)
	s.tokens.Range(func(_, value any) bool {
		t, ok := value.(AuthTokenRecord)
		if !ok {
			return true
		}
		t.TokenHash = ""
		out = append(out, t)
		return true
	})
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "tokens": out})
}

func (s *Server) handleAuthTokenRevoke(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if !s.authorizePasswordOnlyOrReject(w, r) {
		return
	}
	var req TokenActionRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	v, ok := s.tokens.Load(req.TokenID)
	if !ok {
		writeJSON(w, http.StatusNotFound, APIResponse{OK: false, Message: "token not found"})
		return
	}
	t, _ := v.(AuthTokenRecord)
	now := time.Now().UTC()
	t.RevokedAt = &now
	s.tokens.Store(t.ID, t)
	_ = s.saveState()
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "token revoked"})
}

func (s *Server) handleAuthTokenSelfRevoke(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	rawToken := strings.TrimSpace(r.Header.Get("X-Lumos-Token"))
	if rawToken == "" {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "missing token"})
		return
	}
	if !s.authorizeToken(r) {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "invalid token"})
		return
	}

	sum := sha256.Sum256([]byte(rawToken))
	hash := hex.EncodeToString(sum[:])
	revoked := false
	now := time.Now().UTC()
	s.tokens.Range(func(_, value any) bool {
		t, ok := value.(AuthTokenRecord)
		if !ok || t.RevokedAt != nil {
			return true
		}
		if subtle.ConstantTimeCompare([]byte(t.TokenHash), []byte(hash)) == 1 {
			t.RevokedAt = &now
			s.tokens.Store(t.ID, t)
			revoked = true
			return false
		}
		return true
	})
	if !revoked {
		writeJSON(w, http.StatusNotFound, APIResponse{OK: false, Message: "token not found"})
		return
	}
	_ = s.saveState()
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "token revoked"})
}

func (s *Server) handleAuthTokenRotate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if !s.authorizePasswordOnlyOrReject(w, r) {
		return
	}
	var req TokenActionRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	v, ok := s.tokens.Load(req.TokenID)
	if !ok {
		writeJSON(w, http.StatusNotFound, APIResponse{OK: false, Message: "token not found"})
		return
	}
	oldToken, _ := v.(AuthTokenRecord)
	now := time.Now().UTC()
	oldToken.RevokedAt = &now
	s.tokens.Store(oldToken.ID, oldToken)
	newID, err := randomHex(8)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "token rotate failed"})
		return
	}
	newRaw, err := randomHex(32)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "token rotate failed"})
		return
	}
	sum := sha256.Sum256([]byte(newRaw))
	newToken := AuthTokenRecord{
		ID:        newID,
		Label:     oldToken.Label,
		Scope:     normalizeTokenScope(oldToken.Scope),
		TokenHash: hex.EncodeToString(sum[:]),
		CreatedAt: now,
	}
	s.tokens.Store(newID, newToken)
	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "token rotated but persist failed: " + err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, PairResponse{OK: true, TokenID: newID, Token: newRaw, Message: "token rotated"})
}

func (s *Server) handleAdminShutdown(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	cfg := s.cfgSnapshot()
	if strings.TrimSpace(cfg.ShutdownKey) == "" {
		writeJSON(w, http.StatusForbidden, APIResponse{OK: false, Message: "shutdown key not configured"})
		return
	}
	if !isLoopbackIP(remoteIP(r)) {
		writeJSON(w, http.StatusForbidden, APIResponse{OK: false, Message: "shutdown endpoint is local only"})
		return
	}
	remote := strings.TrimSpace(r.Header.Get("X-Lumos-Shutdown-Key"))
	if subtle.ConstantTimeCompare([]byte(remote), []byte(cfg.ShutdownKey)) != 1 {
		writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "invalid shutdown key"})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "shutting down"})
	go func() {
		time.Sleep(100 * time.Millisecond)
		p, err := os.FindProcess(os.Getpid())
		if err == nil {
			_ = p.Signal(os.Interrupt)
		}
	}()
}
