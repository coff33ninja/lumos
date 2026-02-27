package main

import (
	"fmt"
	"net/http"
	"strings"
	"time"
)

func isDestructiveAction(action string) bool {
	switch strings.ToLower(strings.TrimSpace(action)) {
	case "shutdown", "reboot", "sleep":
		return true
	default:
		return false
	}
}

func (s *Server) requireSafeModeApproval(w http.ResponseWriter, r *http.Request, action, target, mac string) bool {
	cfg := s.cfgSnapshot()
	action = strings.ToLower(strings.TrimSpace(action))
	if !cfg.SafeModeEnabled || !isDestructiveAction(action) {
		return true
	}

	now := time.Now().UTC()
	s.safeModeMu.Lock()
	if cfg.SafeModeCooldownSeconds > 0 && !s.lastAction.IsZero() {
		nextAllowed := s.lastAction.Add(time.Duration(cfg.SafeModeCooldownSeconds) * time.Second)
		if now.Before(nextAllowed) {
			remaining := int(nextAllowed.Sub(now).Round(time.Second).Seconds())
			if remaining < 1 {
				remaining = 1
			}
			s.safeModeMu.Unlock()
			writeJSON(w, http.StatusTooManyRequests, map[string]any{
				"ok":                         false,
				"message":                    fmt.Sprintf("safe mode cooldown active; wait %ds", remaining),
				"cooldown_remaining_seconds": remaining,
			})
			return false
		}
	}

	for token, pending := range s.pendingOps {
		if now.After(pending.ExpiresAt) {
			delete(s.pendingOps, token)
		}
	}

	confirmToken := strings.TrimSpace(r.Header.Get("X-Lumos-Confirm-Token"))
	if confirmToken == "" {
		token, err := randomHex(12)
		if err != nil {
			s.safeModeMu.Unlock()
			writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "safe mode token generation failed"})
			return false
		}
		expiresAt := now.Add(90 * time.Second)
		s.pendingOps[token] = SafeModePending{
			Action:    action,
			Target:    target,
			MAC:       mac,
			RemoteIP:  remoteIP(r),
			ExpiresAt: expiresAt,
		}
		s.safeModeMu.Unlock()
		writeJSON(w, http.StatusConflict, map[string]any{
			"ok":                 false,
			"message":            "safe mode confirmation required; resend request with confirm token",
			"confirm_token":      token,
			"confirm_expires_at": expiresAt.Format(time.RFC3339),
			"action":             action,
			"target":             target,
		})
		return false
	}

	pending, ok := s.pendingOps[confirmToken]
	if !ok || now.After(pending.ExpiresAt) {
		delete(s.pendingOps, confirmToken)
		s.safeModeMu.Unlock()
		writeJSON(w, http.StatusConflict, APIResponse{OK: false, Message: "safe mode confirmation token invalid or expired"})
		return false
	}
	if pending.Action != action || pending.Target != target || pending.MAC != mac || pending.RemoteIP != remoteIP(r) {
		s.safeModeMu.Unlock()
		writeJSON(w, http.StatusConflict, APIResponse{OK: false, Message: "safe mode confirmation token does not match request"})
		return false
	}

	delete(s.pendingOps, confirmToken)
	s.safeModeMu.Unlock()
	return true
}

func (s *Server) markDestructiveActionExecuted(action string) {
	if !isDestructiveAction(action) {
		return
	}
	s.safeModeMu.Lock()
	s.lastAction = time.Now().UTC()
	s.safeModeMu.Unlock()
}
