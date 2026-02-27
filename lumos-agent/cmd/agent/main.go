package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"
)

func main() {
	cfg, err := loadConfigWithFallback()
	if err != nil {
		log.Fatalf("config error: %v", err)
	}
	srv := &Server{
		cfg:        cfg,
		auth:       NewAuthGuard(5, 3*time.Minute),
		nonceGuard: NewNonceGuard(),
		pendingOps: make(map[string]SafeModePending),
		eventSubs:  make(map[int]chan []byte),
	}
	if err := srv.loadState(); err != nil {
		log.Printf("state load warning: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", srv.handleUI)
	mux.HandleFunc("/v1/status", srv.handleStatus)
	mux.HandleFunc("/v1/command/wake", srv.handleWake)
	mux.HandleFunc("/v1/command/power", srv.handlePower)
	mux.HandleFunc("/v1/peer/register", srv.handlePeerRegister)
	mux.HandleFunc("/v1/peer/list", srv.handlePeerList)
	mux.HandleFunc("/v1/peer/forward", srv.handlePeerForward)
	mux.HandleFunc("/v1/peer/relay", srv.handlePeerRelay)
	mux.HandleFunc("/v1/auth/pair", srv.handleAuthPair)
	mux.HandleFunc("/v1/auth/token/list", srv.handleAuthTokenList)
	mux.HandleFunc("/v1/auth/token/self/revoke", srv.handleAuthTokenSelfRevoke)
	mux.HandleFunc("/v1/auth/token/rotate", srv.handleAuthTokenRotate)
	mux.HandleFunc("/v1/auth/token/revoke", srv.handleAuthTokenRevoke)
	mux.HandleFunc("/v1/policy/state", srv.handlePolicyState)
	mux.HandleFunc("/v1/policy/default-token", srv.handlePolicyDefaultToken)
	mux.HandleFunc("/v1/policy/token/upsert", srv.handlePolicyTokenUpsert)
	mux.HandleFunc("/v1/policy/token/delete", srv.handlePolicyTokenDelete)
	mux.HandleFunc("/v1/policy/relay-inbound/upsert", srv.handlePolicyRelayInboundUpsert)
	mux.HandleFunc("/v1/policy/relay-inbound/delete", srv.handlePolicyRelayInboundDelete)
	mux.HandleFunc("/v1/policy/relay-outbound/upsert", srv.handlePolicyRelayOutboundUpsert)
	mux.HandleFunc("/v1/policy/relay-outbound/delete", srv.handlePolicyRelayOutboundDelete)
	mux.HandleFunc("/v1/admin/shutdown", srv.handleAdminShutdown)
	mux.HandleFunc("/v1/ui/state", srv.handleUIState)
	mux.HandleFunc("/v1/ui/settings", srv.handleUISettings)
	mux.HandleFunc("/v1/ui/peer/upsert", srv.handleUIPeerUpsert)
	mux.HandleFunc("/v1/ui/peer/delete", srv.handleUIPeerDelete)
	mux.HandleFunc("/v1/ui/config/load", srv.handleUIConfigLoad)
	mux.HandleFunc("/v1/ui/config/save", srv.handleUIConfigSave)
	mux.HandleFunc("/v1/ui/scan", srv.handleScanNetwork)
	mux.HandleFunc("/v1/scan", srv.handleScanNetwork)
	mux.HandleFunc("/v1/events", srv.handleEvents)

	httpServer := &http.Server{
		Addr:              cfg.Bind,
		Handler:           loggingMiddleware(srv.securityMiddleware(mux)),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       45 * time.Second,
	}

	go srv.peerSyncLoop()
	if cfg.MDNSEnabled {
		go srv.mdnsAnnounceLoop()
		go srv.mdnsDiscoverLoop()
	}
	runtimeCfg := srv.cfgSnapshot()
	log.Printf(
		"lumos-agent starting on %s (agent_id=%s, os=%s, dry_run=%t, config_file=%t)",
		runtimeCfg.Bind,
		runtimeCfg.AgentID,
		runtime.GOOS,
		runtimeCfg.DryRun,
		runtimeCfg.ConfigFromFile,
	)
	go func() {
		var err error
		if cfg.TLSCertFile != "" && cfg.TLSKeyFile != "" {
			err = httpServer.ListenAndServeTLS(cfg.TLSCertFile, cfg.TLSKeyFile)
		} else {
			if cfg.RequireTLS {
				log.Fatal("LUMOS_REQUIRE_TLS=true but certificate/key not provided")
			}
			err = httpServer.ListenAndServe()
		}
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()
	waitForShutdown(httpServer)
}

func waitForShutdown(httpServer *http.Server) {
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	_ = httpServer.Shutdown(shutdownCtx)
}
