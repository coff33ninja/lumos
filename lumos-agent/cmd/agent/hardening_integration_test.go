package main

import (
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"
)

func TestLoadConfigWithFallbackPointerBools(t *testing.T) {
	tmpDir := t.TempDir()
	cfgPath := filepath.Join(tmpDir, "lumos-config.json")

	t.Setenv("LUMOS_CONFIG_FILE", cfgPath)
	t.Setenv("LUMOS_AGENT_PASSWORD", "env-password")
	t.Setenv("LUMOS_ALLOW_WAKE_WITHOUT_PASSWORD", "true")
	t.Setenv("LUMOS_DRY_RUN", "false")

	t.Run("explicit file bools override env", func(t *testing.T) {
		if err := saveConfigToFile(cfgPath, &ConfigFile{
			Password:                 "file-password",
			AllowWakeWithoutPassword: boolPtr(false),
			DryRun:                   boolPtr(true),
		}); err != nil {
			t.Fatalf("save config: %v", err)
		}

		cfg, err := loadConfigWithFallback()
		if err != nil {
			t.Fatalf("load config: %v", err)
		}
		if cfg.AllowWakeWithoutPassword {
			t.Fatalf("expected AllowWakeWithoutPassword=false from file, got true")
		}
		if !cfg.DryRun {
			t.Fatalf("expected DryRun=true from file, got false")
		}
	})

	t.Run("nil file bools fall back to env", func(t *testing.T) {
		if err := saveConfigToFile(cfgPath, &ConfigFile{
			Password: "file-password",
		}); err != nil {
			t.Fatalf("save config: %v", err)
		}

		cfg, err := loadConfigWithFallback()
		if err != nil {
			t.Fatalf("load config: %v", err)
		}
		if !cfg.AllowWakeWithoutPassword {
			t.Fatalf("expected AllowWakeWithoutPassword=true from env fallback, got false")
		}
		if cfg.DryRun {
			t.Fatalf("expected DryRun=false from env fallback, got true")
		}
	})
}

func TestScanNetworkBounds(t *testing.T) {
	t.Run("large cidr is bounded and not scanned", func(t *testing.T) {
		results, total := scanNetwork("10.0.0.0/19", 65535, time.Millisecond)
		if total <= 4096 {
			t.Fatalf("expected total hosts > 4096 for /19, got %d", total)
		}
		if len(results) != 0 {
			t.Fatalf("expected no scan results when range is bounded, got %d", len(results))
		}
	})

	t.Run("smaller cidr returns expected target count", func(t *testing.T) {
		results, total := scanNetwork("192.0.2.0/24", 65535, time.Millisecond)
		if total != 254 {
			t.Fatalf("expected /24 to enumerate 254 hosts, got %d", total)
		}
		if len(results) > total {
			t.Fatalf("results count cannot exceed targets: results=%d total=%d", len(results), total)
		}
	})
}

func TestSecurityMiddlewareUIAuthBehavior(t *testing.T) {
	cfg := Config{
		UIUser:                  "lumos",
		UIPasswordBcryptHash:    mustBcryptHash(t, "ui-password"),
		AllowInsecureRemoteHTTP: true,
	}
	s := &Server{cfg: cfg}

	protectedCalled := false
	protected := s.securityMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		protectedCalled = true
		w.WriteHeader(http.StatusOK)
	}))

	req1 := httptest.NewRequest(http.MethodGet, "/v1/ui/state", nil)
	rec1 := httptest.NewRecorder()
	protected.ServeHTTP(rec1, req1)
	if rec1.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for /v1/ui/state without auth, got %d", rec1.Code)
	}
	if protectedCalled {
		t.Fatalf("protected handler should not be called when UI auth fails")
	}

	req2 := httptest.NewRequest(http.MethodGet, "/v1/ui/state", nil)
	req2.SetBasicAuth("lumos", "wrong")
	rec2 := httptest.NewRecorder()
	protected.ServeHTTP(rec2, req2)
	if rec2.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for /v1/ui/state with wrong auth, got %d", rec2.Code)
	}

	req3 := httptest.NewRequest(http.MethodGet, "/v1/ui/state", nil)
	req3.SetBasicAuth("lumos", "ui-password")
	rec3 := httptest.NewRecorder()
	protected.ServeHTTP(rec3, req3)
	if rec3.Code != http.StatusOK {
		t.Fatalf("expected 200 for /v1/ui/state with valid auth, got %d", rec3.Code)
	}
	if !protectedCalled {
		t.Fatalf("protected handler should be called when UI auth succeeds")
	}

	publicCalled := false
	public := s.securityMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		publicCalled = true
		w.WriteHeader(http.StatusOK)
	}))
	req4 := httptest.NewRequest(http.MethodGet, "/v1/status", nil)
	rec4 := httptest.NewRecorder()
	public.ServeHTTP(rec4, req4)
	if rec4.Code != http.StatusOK {
		t.Fatalf("expected 200 for /v1/status without UI auth, got %d", rec4.Code)
	}
	if !publicCalled {
		t.Fatalf("public handler should be called for /v1/status")
	}
}
