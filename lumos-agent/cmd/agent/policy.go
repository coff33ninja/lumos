package main

import (
	"fmt"
	"net/http"
	"strings"
)

func writePolicyDenied(w http.ResponseWriter, action, detail string) {
	msg := "policy_denied"
	a := strings.ToLower(strings.TrimSpace(action))
	if a != "" {
		msg += " (action=" + a + ")"
	}
	if strings.TrimSpace(detail) != "" {
		msg += ": " + strings.TrimSpace(detail)
	}
	writeJSON(w, http.StatusForbidden, APIResponse{OK: false, Message: msg, Reason: "policy_denied"})
}

func (s *Server) isTokenActionAllowed(tokenID, action string) bool {
	cfg := s.cfgSnapshot()
	policy := cfg.DefaultTokenAllowances
	if override, ok := cfg.TokenAllowances[strings.TrimSpace(tokenID)]; ok {
		policy = override
	}
	return isActionAllowed(policy, action)
}

func (s *Server) isRelayOutboundAllowed(targetAgentID, action string) bool {
	cfg := s.cfgSnapshot()
	target := strings.TrimSpace(targetAgentID)
	if target == "" {
		return true
	}
	if policy, ok := cfg.RelayOutboundAllowances[target]; ok {
		return isActionAllowed(policy, action)
	}
	if wildcard, ok := cfg.RelayOutboundAllowances["*"]; ok {
		return isActionAllowed(wildcard, action)
	}
	return true
}

func (s *Server) isRelayInboundAllowed(sourceAgentID, action string) bool {
	cfg := s.cfgSnapshot()
	source := strings.TrimSpace(sourceAgentID)
	if source == "" {
		return true
	}
	if policy, ok := cfg.RelayInboundAllowances[source]; ok {
		return isActionAllowed(policy, action)
	}
	if wildcard, ok := cfg.RelayInboundAllowances["*"]; ok {
		return isActionAllowed(wildcard, action)
	}
	return true
}

func isActionAllowed(policy ActionAllowances, action string) bool {
	a := strings.ToLower(strings.TrimSpace(action))
	switch a {
	case "wake":
		return policy.Wake
	case "shutdown":
		return policy.Shutdown
	case "reboot":
		return policy.Reboot
	case "sleep":
		return policy.Sleep
	case "relay":
		return policy.Relay
	default:
		return false
	}
}

func relayDeniedDetail(direction, peer, action string) string {
	if strings.TrimSpace(peer) == "" {
		peer = "unknown"
	}
	return fmt.Sprintf("%s relay denied for peer=%s action=%s", direction, peer, strings.ToLower(strings.TrimSpace(action)))
}

func cloneAllowancesMap(in map[string]ActionAllowances) map[string]ActionAllowances {
	if len(in) == 0 {
		return map[string]ActionAllowances{}
	}
	out := make(map[string]ActionAllowances, len(in))
	for key, value := range in {
		out[key] = value
	}
	return out
}
