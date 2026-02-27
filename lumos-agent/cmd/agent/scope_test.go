package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func newScopeTestServer(t *testing.T) *Server {
	t.Helper()
	cfg := Config{
		PasswordBcryptHash:      mustBcryptHash(t, "secret"),
		UIPasswordBcryptHash:    mustBcryptHash(t, "secret"),
		UIUser:                  "lumos",
		AllowInsecureRemoteHTTP: true,
		DryRun:                  true,
		DefaultTokenAllowances:  allowAllActions(),
		TokenAllowances:         map[string]ActionAllowances{},
		RelayInboundAllowances:  map[string]ActionAllowances{},
		RelayOutboundAllowances: map[string]ActionAllowances{},
	}
	return &Server{
		cfg:        cfg,
		auth:       NewAuthGuard(5, time.Minute),
		nonceGuard: NewNonceGuard(),
		pendingOps: map[string]SafeModePending{},
	}
}

func addScopedToken(s *Server, id, raw, scope string) {
	sum := sha256.Sum256([]byte(raw))
	s.tokens.Store(id, AuthTokenRecord{
		ID:        id,
		Label:     "t",
		Scope:     scope,
		TokenHash: hex.EncodeToString(sum[:]),
		CreatedAt: time.Now().UTC(),
	})
}

func TestWakeOnlyScopeDeniesShutdown(t *testing.T) {
	srv := newScopeTestServer(t)
	addScopedToken(srv, "tok1", "raw1", "wake-only")

	req := httptest.NewRequest(http.MethodPost, "/v1/command/power", strings.NewReader(`{"action":"shutdown"}`))
	req.Header.Set("X-Lumos-Token", "raw1")
	rec := httptest.NewRecorder()
	srv.handlePower(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d body=%s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), "policy_denied") {
		t.Fatalf("expected policy_denied, got %s", rec.Body.String())
	}
}

func TestReadOnlyScopeDeniesWake(t *testing.T) {
	srv := newScopeTestServer(t)
	addScopedToken(srv, "tok2", "raw2", "read-only")

	req := httptest.NewRequest(http.MethodPost, "/v1/command/wake", strings.NewReader(`{"mac":"AA:BB:CC:DD:EE:FF"}`))
	req.Header.Set("X-Lumos-Token", "raw2")
	rec := httptest.NewRecorder()
	srv.handleWake(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestPolicyReadAllowsReadOnlyScope(t *testing.T) {
	srv := newScopeTestServer(t)
	addScopedToken(srv, "tok3", "raw3", "read-only")

	req := httptest.NewRequest(http.MethodGet, "/v1/policy/state", nil)
	req.Header.Set("X-Lumos-Token", "raw3")
	rec := httptest.NewRecorder()
	srv.handlePolicyState(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestPolicyWriteDeniesReadOnlyScope(t *testing.T) {
	srv := newScopeTestServer(t)
	addScopedToken(srv, "tok4", "raw4", "read-only")

	req := httptest.NewRequest(http.MethodPost, "/v1/policy/token/upsert", strings.NewReader(`{"token_id":"x","allowances":{"wake":true,"shutdown":true,"reboot":true,"sleep":true,"relay":true}}`))
	req.Header.Set("X-Lumos-Token", "raw4")
	rec := httptest.NewRecorder()
	srv.handlePolicyTokenUpsert(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestPairScopeIsPersisted(t *testing.T) {
	srv := newScopeTestServer(t)

	req := httptest.NewRequest(http.MethodPost, "/v1/auth/pair", strings.NewReader(`{"label":"phone","scope":"wake-only"}`))
	req.Header.Set("X-Lumos-Password", "secret")
	rec := httptest.NewRecorder()
	srv.handleAuthPair(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("pair failed: %d body=%s", rec.Code, rec.Body.String())
	}
	listReq := httptest.NewRequest(http.MethodGet, "/v1/auth/token/list", nil)
	listReq.Header.Set("X-Lumos-Password", "secret")
	listRec := httptest.NewRecorder()
	srv.handleAuthTokenList(listRec, listReq)
	if listRec.Code != http.StatusOK {
		t.Fatalf("token list failed: %d body=%s", listRec.Code, listRec.Body.String())
	}
	var out map[string]any
	if err := json.Unmarshal(listRec.Body.Bytes(), &out); err != nil {
		t.Fatalf("decode token list failed: %v", err)
	}
	tokens, _ := out["tokens"].([]any)
	if len(tokens) == 0 {
		t.Fatalf("expected at least one token")
	}
	first, _ := tokens[0].(map[string]any)
	if strings.TrimSpace(first["scope"].(string)) != "wake-only" {
		t.Fatalf("expected wake-only scope, got %+v", first)
	}
}
