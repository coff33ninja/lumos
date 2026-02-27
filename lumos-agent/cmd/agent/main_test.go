package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http/httptest"
	"testing"
	"time"
)

func TestEncryptDecryptStateEnvelope(t *testing.T) {
	key := deriveStateKey([]byte("abc"), "salt")
	in := PersistedState{
		AgentID:                  "agent-1",
		AllowWakeWithoutPassword: true,
		DryRun:                   true,
		Tokens: []AuthTokenRecord{
			{ID: "tok1", Label: "phone", TokenHash: "hash", CreatedAt: time.Now().UTC()},
		},
	}
	body, err := encryptStateEnvelope(in, key)
	if err != nil {
		t.Fatalf("encrypt failed: %v", err)
	}
	var env persistedEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		t.Fatalf("unmarshal envelope failed: %v", err)
	}
	out, err := decryptStateEnvelope(env, key)
	if err != nil {
		t.Fatalf("decrypt failed: %v", err)
	}
	if out.AgentID != in.AgentID || len(out.Tokens) != 1 {
		t.Fatalf("decrypted mismatch")
	}
}

func TestAuthorizeToken(t *testing.T) {
	s := &Server{}
	raw := "raw-token-value"
	sum := sha256.Sum256([]byte(raw))
	s.tokens.Store("a1", AuthTokenRecord{
		ID:        "a1",
		Label:     "phone",
		TokenHash: hex.EncodeToString(sum[:]),
		CreatedAt: time.Now().UTC(),
	})
	req := httptest.NewRequest("POST", "/v1/command/power", nil)
	req.Header.Set("X-Lumos-Token", raw)
	if !s.authorizeToken(req) {
		t.Fatalf("expected token to authorize")
	}
}

func TestIsLoopbackIP(t *testing.T) {
	if !isLoopbackIP("127.0.0.1") {
		t.Fatalf("expected loopback")
	}
	if isLoopbackIP("192.168.1.10") {
		t.Fatalf("unexpected loopback")
	}
}
