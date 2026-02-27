package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func newPolicyCRUDServer(t *testing.T) *Server {
	t.Helper()
	return &Server{
		cfg: Config{
			PasswordBcryptHash:      mustBcryptHash(t, "secret"),
			UIPasswordBcryptHash:    mustBcryptHash(t, "secret"),
			UIUser:                  "lumos",
			AllowInsecureRemoteHTTP: true,
			DryRun:                  true,
			StateFile:               "",
			DefaultTokenAllowances:  allowAllActions(),
			TokenAllowances:         map[string]ActionAllowances{},
			RelayInboundAllowances:  map[string]ActionAllowances{},
			RelayOutboundAllowances: map[string]ActionAllowances{},
		},
		auth:       NewAuthGuard(5, time.Minute),
		nonceGuard: NewNonceGuard(),
		pendingOps: make(map[string]SafeModePending),
	}
}

func TestPolicyCRUDTokenAndRelay(t *testing.T) {
	s := newPolicyCRUDServer(t)

	upsertTokenReq := httptest.NewRequest(http.MethodPost, "/v1/policy/token/upsert", strings.NewReader(`{"token_id":"t1","allowances":{"wake":true,"shutdown":false,"reboot":true,"sleep":true,"relay":true}}`))
	upsertTokenReq.Header.Set("X-Lumos-Password", "secret")
	upsertTokenRec := httptest.NewRecorder()
	s.handlePolicyTokenUpsert(upsertTokenRec, upsertTokenReq)
	if upsertTokenRec.Code != http.StatusOK {
		t.Fatalf("token upsert failed: %d %s", upsertTokenRec.Code, upsertTokenRec.Body.String())
	}

	upsertRelayReq := httptest.NewRequest(http.MethodPost, "/v1/policy/relay-outbound/upsert", strings.NewReader(`{"agent_id":"peer-a","allowances":{"wake":true,"shutdown":false,"reboot":false,"sleep":false,"relay":true}}`))
	upsertRelayReq.Header.Set("X-Lumos-Password", "secret")
	upsertRelayRec := httptest.NewRecorder()
	s.handlePolicyRelayOutboundUpsert(upsertRelayRec, upsertRelayReq)
	if upsertRelayRec.Code != http.StatusOK {
		t.Fatalf("relay upsert failed: %d %s", upsertRelayRec.Code, upsertRelayRec.Body.String())
	}

	stateReq := httptest.NewRequest(http.MethodGet, "/v1/policy/state", nil)
	stateReq.Header.Set("X-Lumos-Password", "secret")
	stateRec := httptest.NewRecorder()
	s.handlePolicyState(stateRec, stateReq)
	if stateRec.Code != http.StatusOK {
		t.Fatalf("policy state failed: %d %s", stateRec.Code, stateRec.Body.String())
	}
	var state map[string]any
	if err := json.Unmarshal(stateRec.Body.Bytes(), &state); err != nil {
		t.Fatalf("decode state failed: %v", err)
	}
	tokens, _ := state["token_allowances"].(map[string]any)
	if _, ok := tokens["t1"]; !ok {
		t.Fatalf("expected token policy for t1")
	}

	delTokenReq := httptest.NewRequest(http.MethodPost, "/v1/policy/token/delete", strings.NewReader(`{"key":"t1"}`))
	delTokenReq.Header.Set("X-Lumos-Password", "secret")
	delTokenRec := httptest.NewRecorder()
	s.handlePolicyTokenDelete(delTokenRec, delTokenReq)
	if delTokenRec.Code != http.StatusOK {
		t.Fatalf("token delete failed: %d %s", delTokenRec.Code, delTokenRec.Body.String())
	}

	delRelayReq := httptest.NewRequest(http.MethodPost, "/v1/policy/relay-outbound/delete", strings.NewReader(`{"key":"peer-a"}`))
	delRelayReq.Header.Set("X-Lumos-Password", "secret")
	delRelayRec := httptest.NewRecorder()
	s.handlePolicyRelayOutboundDelete(delRelayRec, delRelayReq)
	if delRelayRec.Code != http.StatusOK {
		t.Fatalf("relay delete failed: %d %s", delRelayRec.Code, delRelayRec.Body.String())
	}
}
