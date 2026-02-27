package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"
)

func newPolicyTestServer(t *testing.T) *Server {
	t.Helper()
	cfg := Config{
		AgentID:                 "local-agent",
		PasswordBcryptHash:      mustBcryptHash(t, "secret"),
		AllowInsecureRemoteHTTP: true,
		DryRun:                  true,
		DefaultTokenAllowances:  allowAllActions(),
		TokenAllowances:         map[string]ActionAllowances{},
		RelayInboundAllowances:  map[string]ActionAllowances{},
		RelayOutboundAllowances: map[string]ActionAllowances{},
	}
	return &Server{cfg: cfg, auth: NewAuthGuard(5, time.Minute), nonceGuard: NewNonceGuard(), pendingOps: make(map[string]SafeModePending)}
}

func putToken(s *Server, id, raw string) {
	sum := sha256.Sum256([]byte(raw))
	s.tokens.Store(id, AuthTokenRecord{ID: id, Label: "t", TokenHash: hex.EncodeToString(sum[:]), CreatedAt: time.Now().UTC()})
}

func TestPowerDeniedByTokenAllowance(t *testing.T) {
	srv := newPolicyTestServer(t)
	putToken(srv, "token-a", "raw-a")
	srv.cfg.TokenAllowances["token-a"] = ActionAllowances{Wake: true, Shutdown: false, Reboot: true, Sleep: true, Relay: true}

	req := httptest.NewRequest(http.MethodPost, "/v1/command/power", strings.NewReader(`{"action":"shutdown"}`))
	req.Header.Set("X-Lumos-Token", "raw-a")
	rec := httptest.NewRecorder()
	srv.handlePower(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d body=%s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), "policy_denied") {
		t.Fatalf("expected policy_denied response, got %s", rec.Body.String())
	}
}

func TestPowerAllowedByTokenAllowance(t *testing.T) {
	srv := newPolicyTestServer(t)
	putToken(srv, "token-b", "raw-b")
	srv.cfg.TokenAllowances["token-b"] = ActionAllowances{Wake: true, Shutdown: true, Reboot: true, Sleep: true, Relay: true}

	req := httptest.NewRequest(http.MethodPost, "/v1/command/power", strings.NewReader(`{"action":"shutdown"}`))
	req.Header.Set("X-Lumos-Token", "raw-b")
	rec := httptest.NewRecorder()
	srv.handlePower(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestRelayOutboundDeniedByPolicy(t *testing.T) {
	srv := newPolicyTestServer(t)
	srv.cfg.ClusterKey = "cluster-secret"
	srv.cfg.RelayOutboundAllowances["peer-a"] = ActionAllowances{Wake: true, Shutdown: false, Reboot: true, Sleep: true, Relay: true}

	req := httptest.NewRequest(http.MethodPost, "/v1/peer/relay", strings.NewReader(`{"target_agent_id":"peer-a","address":"127.0.0.1:65000","action":"shutdown"}`))
	req.Header.Set("X-Lumos-Password", "secret")
	rec := httptest.NewRecorder()
	srv.handlePeerRelay(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d body=%s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), "policy_denied") {
		t.Fatalf("expected policy_denied response, got %s", rec.Body.String())
	}
}

func TestRelayInboundDeniedByPolicy(t *testing.T) {
	srv := newPolicyTestServer(t)
	srv.cfg.ClusterKey = "cluster-secret"
	srv.cfg.RelayInboundAllowances["source-a"] = ActionAllowances{Wake: true, Shutdown: false, Reboot: true, Sleep: true, Relay: true}

	body := []byte(`{"source_agent_id":"source-a","target_agent_id":"local-agent","action":"shutdown","timestamp_unix":1}`)
	req := httptest.NewRequest(http.MethodPost, "/v1/peer/forward", bytes.NewReader(body))
	sigHeaders := signedForwardHeaders("cluster-secret", body)
	for k, v := range sigHeaders {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	srv.handlePeerForward(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d body=%s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), "policy_denied") {
		t.Fatalf("expected policy_denied response, got %s", rec.Body.String())
	}
}

func signedForwardHeaders(clusterKey string, body []byte) map[string]string {
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	nonce := "abcd1234nonceabcd1234nonceabcd12"
	mac := hmac.New(sha256.New, []byte(clusterKey))
	mac.Write([]byte(ts))
	mac.Write([]byte("."))
	mac.Write([]byte(nonce))
	mac.Write([]byte("."))
	mac.Write(body)
	return map[string]string{
		"X-Lumos-Timestamp": ts,
		"X-Lumos-Nonce":     nonce,
		"X-Lumos-Signature": hex.EncodeToString(mac.Sum(nil)),
	}
}
