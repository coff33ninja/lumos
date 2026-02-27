package main

import (
	"encoding/json"
	"net/http/httptest"
	"testing"
	"time"
)

func TestSafeModeRequiresConfirmationToken(t *testing.T) {
	s := &Server{
		cfg: Config{
			SafeModeEnabled:         true,
			SafeModeCooldownSeconds: 0,
		},
		pendingOps: make(map[string]SafeModePending),
	}

	req := httptest.NewRequest("POST", "/v1/command/power", nil)
	req.RemoteAddr = "127.0.0.1:1234"
	rec := httptest.NewRecorder()
	if s.requireSafeModeApproval(rec, req, "shutdown", "self", "") {
		t.Fatalf("expected first request to require confirmation")
	}
	if rec.Code != 409 {
		t.Fatalf("expected 409, got %d", rec.Code)
	}

	var payload map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode payload: %v", err)
	}
	token, _ := payload["confirm_token"].(string)
	if token == "" {
		t.Fatalf("expected confirm token in response")
	}

	req2 := httptest.NewRequest("POST", "/v1/command/power", nil)
	req2.RemoteAddr = "127.0.0.1:1234"
	req2.Header.Set("X-Lumos-Confirm-Token", token)
	rec2 := httptest.NewRecorder()
	if !s.requireSafeModeApproval(rec2, req2, "shutdown", "self", "") {
		t.Fatalf("expected second request with token to pass")
	}
}

func TestSafeModeCooldownBlocksRapidDestructiveActions(t *testing.T) {
	s := &Server{
		cfg: Config{
			SafeModeEnabled:         true,
			SafeModeCooldownSeconds: 10,
		},
		pendingOps: make(map[string]SafeModePending),
	}
	s.lastAction = time.Now().UTC()

	req := httptest.NewRequest("POST", "/v1/command/power", nil)
	req.RemoteAddr = "127.0.0.1:1234"
	rec := httptest.NewRecorder()
	if s.requireSafeModeApproval(rec, req, "reboot", "self", "") {
		t.Fatalf("expected cooldown to block request")
	}
	if rec.Code != 429 {
		t.Fatalf("expected 429 during cooldown, got %d", rec.Code)
	}
}
