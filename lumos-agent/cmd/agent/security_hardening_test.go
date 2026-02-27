package main

import (
	"testing"

	"golang.org/x/crypto/bcrypt"
)

func TestNormalizeRelayAddress_DisallowLoopback(t *testing.T) {
	if _, err := normalizeRelayAddress("127.0.0.1:8080", true); err == nil {
		t.Fatalf("expected loopback target to be rejected")
	}
}

func TestNormalizeRelayAddress_AllowLoopbackForUIVerification(t *testing.T) {
	got, err := normalizeRelayAddress("127.0.0.1:8080", false)
	if err != nil {
		t.Fatalf("expected loopback target to be allowed: %v", err)
	}
	if got != "http://127.0.0.1:8080" {
		t.Fatalf("unexpected normalized address: %s", got)
	}
}

func TestNormalizeRelayAddress_RejectPathAndQuery(t *testing.T) {
	cases := []string{
		"http://example.com:8080/path",
		"https://example.com:8080?x=1",
	}
	for _, c := range cases {
		if _, err := normalizeRelayAddress(c, true); err == nil {
			t.Fatalf("expected invalid address to be rejected: %s", c)
		}
	}
}

func TestVerifySecretBcryptOnly(t *testing.T) {
	secret := "super-secret"
	if verifySecretBcrypt(secret, "") {
		t.Fatalf("expected empty bcrypt hash to fail")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(secret), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("bcrypt hash generation failed: %v", err)
	}
	if !verifySecretBcrypt(secret, string(hash)) {
		t.Fatalf("expected bcrypt verification to pass")
	}
	if verifySecretBcrypt("wrong", string(hash)) {
		t.Fatalf("expected bcrypt verification to fail for wrong secret")
	}

	if verifySecretBcrypt(secret, "invalid-bcrypt-hash") {
		t.Fatalf("expected malformed bcrypt hash to fail")
	}
}
