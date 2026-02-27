package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestPairThenPowerWithToken(t *testing.T) {
	cfg := Config{
		Bind:                    ":0",
		AgentID:                 "test-agent",
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
	srv := &Server{
		cfg:        cfg,
		auth:       NewAuthGuard(5, 1*time.Minute),
		nonceGuard: NewNonceGuard(),
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/auth/pair", srv.handleAuthPair)
	mux.HandleFunc("/v1/command/power", srv.handlePower)

	// Pair token
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/pair", strings.NewReader(`{"label":"t1"}`))
	req.Header.Set("X-Lumos-Password", "secret")
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("pair failed: status=%d body=%s", rec.Code, rec.Body.String())
	}
	var pair PairResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &pair); err != nil {
		t.Fatalf("pair decode failed: %v", err)
	}
	if pair.Token == "" {
		t.Fatalf("pair token empty")
	}

	// Use token for power command
	req2 := httptest.NewRequest(http.MethodPost, "/v1/command/power", strings.NewReader(`{"action":"shutdown"}`))
	req2.Header.Set("X-Lumos-Token", pair.Token)
	rec2 := httptest.NewRecorder()
	mux.ServeHTTP(rec2, req2)
	if rec2.Code != http.StatusOK {
		t.Fatalf("power failed: status=%d body=%s", rec2.Code, rec2.Body.String())
	}
}
