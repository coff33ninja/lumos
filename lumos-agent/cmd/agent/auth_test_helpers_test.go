package main

import (
	"testing"

	"golang.org/x/crypto/bcrypt"
)

func mustBcryptHash(t *testing.T, secret string) string {
	t.Helper()
	hash, err := bcrypt.GenerateFromPassword([]byte(secret), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("bcrypt hash generation failed: %v", err)
	}
	return string(hash)
}
