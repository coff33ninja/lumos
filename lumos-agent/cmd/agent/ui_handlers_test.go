package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestVerifyPeerAccessAcceptsValidPassword(t *testing.T) {
	s := &Server{}
	peer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/auth/token/list" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Header.Get("X-Lumos-Password") != "secret" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer peer.Close()

	if err := s.verifyPeerAccess(peer.URL, "secret"); err != nil {
		t.Fatalf("expected no error, got: %v", err)
	}
}

func TestVerifyPeerAccessRejectsInvalidPassword(t *testing.T) {
	s := &Server{}
	peer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer peer.Close()

	if err := s.verifyPeerAccess(peer.URL, "wrong"); err == nil {
		t.Fatalf("expected error for invalid password")
	}
}
