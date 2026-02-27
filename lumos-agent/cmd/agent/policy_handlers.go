package main

import (
	"net/http"
	"sort"
	"strings"
)

func (s *Server) handlePolicyState(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if _, ok := s.authorizePolicyReadOrReject(w, r); !ok {
		return
	}

	s.mu.RLock()
	defaultAllowances := s.cfg.DefaultTokenAllowances
	tokenAllowances := cloneAllowancesMap(s.cfg.TokenAllowances)
	inboundAllowances := cloneAllowancesMap(s.cfg.RelayInboundAllowances)
	outboundAllowances := cloneAllowancesMap(s.cfg.RelayOutboundAllowances)
	s.mu.RUnlock()
	tokens := s.listPolicyTokens()
	peers := s.listPeers()
	peerIDs := make([]string, 0, len(peers))
	for _, p := range peers {
		if strings.TrimSpace(p.AgentID) != "" {
			peerIDs = append(peerIDs, p.AgentID)
		}
	}
	sort.Strings(peerIDs)

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                        true,
		"default_token_allowances":  defaultAllowances,
		"token_allowances":          tokenAllowances,
		"relay_inbound_allowances":  inboundAllowances,
		"relay_outbound_allowances": outboundAllowances,
		"tokens":                    tokens,
		"peers":                     peerIDs,
	})
}

func (s *Server) handlePolicyDefaultToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if _, ok := s.authorizePolicyWriteOrReject(w, r); !ok {
		return
	}
	var req PolicyDefaultUpdateRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	s.mu.Lock()
	s.cfg.DefaultTokenAllowances = req.Allowances
	s.mu.Unlock()
	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "policy updated in memory but persist failed: " + err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "default token policy updated"})
}

func (s *Server) handlePolicyTokenUpsert(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if _, ok := s.authorizePolicyWriteOrReject(w, r); !ok {
		return
	}
	var req PolicyTokenUpsertRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	tokenID := strings.TrimSpace(req.TokenID)
	if tokenID == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "token_id is required"})
		return
	}
	s.mu.Lock()
	if s.cfg.TokenAllowances == nil {
		s.cfg.TokenAllowances = map[string]ActionAllowances{}
	}
	s.cfg.TokenAllowances[tokenID] = req.Allowances
	s.mu.Unlock()
	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "token policy updated in memory but persist failed: " + err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "token policy upserted"})
}

func (s *Server) handlePolicyTokenDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if _, ok := s.authorizePolicyWriteOrReject(w, r); !ok {
		return
	}
	var req PolicyDeleteRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	key := strings.TrimSpace(req.Key)
	if key == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "key is required"})
		return
	}
	s.mu.Lock()
	delete(s.cfg.TokenAllowances, key)
	s.mu.Unlock()
	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "token policy deleted in memory but persist failed: " + err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "token policy deleted"})
}

func (s *Server) handlePolicyRelayInboundUpsert(w http.ResponseWriter, r *http.Request) {
	handlePolicyPeerUpsert(w, r, s, true)
}

func (s *Server) handlePolicyRelayInboundDelete(w http.ResponseWriter, r *http.Request) {
	handlePolicyPeerDelete(w, r, s, true)
}

func (s *Server) handlePolicyRelayOutboundUpsert(w http.ResponseWriter, r *http.Request) {
	handlePolicyPeerUpsert(w, r, s, false)
}

func (s *Server) handlePolicyRelayOutboundDelete(w http.ResponseWriter, r *http.Request) {
	handlePolicyPeerDelete(w, r, s, false)
}

func handlePolicyPeerUpsert(w http.ResponseWriter, r *http.Request, s *Server, inbound bool) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if _, ok := s.authorizePolicyWriteOrReject(w, r); !ok {
		return
	}
	var req PolicyPeerUpsertRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	agentID := strings.TrimSpace(req.AgentID)
	if agentID == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "agent_id is required"})
		return
	}
	s.mu.Lock()
	if inbound {
		if s.cfg.RelayInboundAllowances == nil {
			s.cfg.RelayInboundAllowances = map[string]ActionAllowances{}
		}
		s.cfg.RelayInboundAllowances[agentID] = req.Allowances
	} else {
		if s.cfg.RelayOutboundAllowances == nil {
			s.cfg.RelayOutboundAllowances = map[string]ActionAllowances{}
		}
		s.cfg.RelayOutboundAllowances[agentID] = req.Allowances
	}
	s.mu.Unlock()
	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "relay policy updated in memory but persist failed: " + err.Error()})
		return
	}
	if inbound {
		writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "relay inbound policy upserted"})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "relay outbound policy upserted"})
}

func handlePolicyPeerDelete(w http.ResponseWriter, r *http.Request, s *Server, inbound bool) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if _, ok := s.authorizePolicyWriteOrReject(w, r); !ok {
		return
	}
	var req PolicyDeleteRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	key := strings.TrimSpace(req.Key)
	if key == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "key is required"})
		return
	}
	s.mu.Lock()
	if inbound {
		delete(s.cfg.RelayInboundAllowances, key)
	} else {
		delete(s.cfg.RelayOutboundAllowances, key)
	}
	s.mu.Unlock()
	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "relay policy deleted in memory but persist failed: " + err.Error()})
		return
	}
	if inbound {
		writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "relay inbound policy deleted"})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "relay outbound policy deleted"})
}

func (s *Server) listPolicyTokens() []map[string]any {
	out := make([]map[string]any, 0, 8)
	s.tokens.Range(func(_, value any) bool {
		t, ok := value.(AuthTokenRecord)
		if !ok {
			return true
		}
		out = append(out, map[string]any{
			"token_id":   t.ID,
			"label":      t.Label,
			"scope":      normalizeTokenScope(t.Scope),
			"revoked_at": t.RevokedAt,
		})
		return true
	})
	sort.Slice(out, func(i, j int) bool {
		return out[i]["token_id"].(string) < out[j]["token_id"].(string)
	})
	return out
}
