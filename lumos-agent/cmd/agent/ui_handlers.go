package main

import (
	"errors"
	"net/http"
	"runtime"
	"strings"
	"time"
)

func (s *Server) handleUI(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(uiHTML))
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	cfg := s.cfgSnapshot()
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":       true,
		"agent_id": cfg.AgentID,
		"os":       runtime.GOOS,
		"arch":     runtime.GOARCH,
		"now":      time.Now().UTC().Format(time.RFC3339),
		"dry_run":  cfg.DryRun,
		"version":  AgentVersion,
		"compatibility": map[string]string{
			"app_range": CompatibleAppRange,
		},
		"capabilities": map[string]bool{
			"auth_pair":         true,
			"auth_token_list":   true,
			"auth_token_rotate": true,
			"auth_token_revoke": true,
			"auth_token_scope":  true,
			"policy_crud":       true,
			"events_ws":         true,
		},
		"interfaces": getNetworkInterfaces(),
	})
}

func (s *Server) handleWake(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	cfg := s.cfgSnapshot()
	if !cfg.AllowWakeWithoutPassword {
		if _, ok := s.authorizeForActionOrReject(w, r, "wake"); !ok {
			return
		}
	}
	var req WakeRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	if strings.TrimSpace(req.MAC) == "" {
		s.recordAudit("local", "wake", "self", req.MAC, false, "mac is required", remoteIP(r))
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "mac is required"})
		return
	}
	if err := sendMagicPacket(req.MAC); err != nil {
		s.recordAudit("local", "wake", "self", req.MAC, false, "wake failed: "+err.Error(), remoteIP(r))
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "wake failed: " + err.Error()})
		return
	}
	s.recordAudit("local", "wake", "self", req.MAC, true, "magic packet sent", remoteIP(r))
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "magic packet sent"})
}

func (s *Server) handlePower(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	var req CommandRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	action := strings.ToLower(strings.TrimSpace(req.Action))
	if action != "shutdown" && action != "reboot" && action != "sleep" {
		s.recordAudit("local", action, "self", "", false, "invalid power action", remoteIP(r))
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "action must be one of: shutdown, reboot, sleep"})
		return
	}
	if _, ok := s.authorizeForActionOrReject(w, r, action); !ok {
		s.recordAudit("local", action, "self", "", false, "blocked by token allowance", remoteIP(r))
		return
	}
	if !s.requireSafeModeApproval(w, r, action, "self", "") {
		s.recordAudit("local", action, "self", "", false, "blocked by safe mode confirmation/cooldown", remoteIP(r))
		return
	}
	cfg := s.cfgSnapshot()
	if cfg.DryRun {
		s.recordAudit("local", action, "self", "", true, "dry-run: "+action+" queued", remoteIP(r))
		writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "dry-run: " + action + " queued"})
		return
	}
	if err := runPowerAction(action); err != nil {
		s.recordAudit("local", action, "self", "", false, "power action failed: "+err.Error(), remoteIP(r))
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "power action failed: " + err.Error()})
		return
	}
	s.markDestructiveActionExecuted(action)
	s.recordAudit("local", action, "self", "", true, action+" command sent", remoteIP(r))
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: action + " command sent"})
}

func (s *Server) handleUIState(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	cfg := s.cfgSnapshot()
	detectedNetworks, _ := detectLocalNetworks()
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                          true,
		"agent_id":                    cfg.AgentID,
		"os":                          runtime.GOOS,
		"dry_run":                     cfg.DryRun,
		"allow_wake_without_password": cfg.AllowWakeWithoutPassword,
		"safe_mode_enabled":           cfg.SafeModeEnabled,
		"safe_mode_cooldown_seconds":  cfg.SafeModeCooldownSeconds,
		"advertise_addr":              cfg.AdvertiseAddr,
		"bootstrap_peers":             cfg.BootstrapPeers,
		"peers":                       s.listPeers(),
		"audit":                       s.listAudit(60),
		"detected_networks":           detectedNetworks,
		"now":                         time.Now().UTC().Format(time.RFC3339),
	})
}

func (s *Server) handleUISettings(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	var req UISettingsRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	s.mu.Lock()
	s.cfg.AllowWakeWithoutPassword = req.AllowWakeWithoutPassword
	s.cfg.DryRun = req.DryRun
	s.cfg.SafeModeEnabled = req.SafeModeEnabled
	if req.SafeModeCooldownSeconds < 0 {
		req.SafeModeCooldownSeconds = 0
	}
	s.cfg.SafeModeCooldownSeconds = req.SafeModeCooldownSeconds
	if strings.TrimSpace(req.AdvertiseAddr) != "" {
		s.cfg.AdvertiseAddr = strings.TrimSpace(req.AdvertiseAddr)
	}
	s.cfg.BootstrapPeers = uniqueStrings(parseCSV(req.BootstrapPeers))
	s.mu.Unlock()
	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "settings saved in memory but persist failed: " + err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "settings updated"})
}

func (s *Server) handleUIPeerUpsert(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	var req PeerRegisterRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	if strings.TrimSpace(req.AgentID) == "" || strings.TrimSpace(req.Address) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "agent_id and address are required"})
		return
	}

	// If password provided, verify peer is reachable and password is correct
	if strings.TrimSpace(req.Password) != "" {
		if err := s.verifyPeerAccess(req.Address, req.Password); err != nil {
			writeJSON(w, http.StatusUnauthorized, APIResponse{OK: false, Message: "peer verification failed: " + err.Error()})
			return
		}
	}

	s.upsertPeer(req.AgentID, req.Address, "", "")
	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "peer upserted but persist failed: " + err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "peer upserted"})
}

func (s *Server) handleUIPeerDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	var req struct {
		AgentID string `json:"agent_id"`
	}
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}
	if strings.TrimSpace(req.AgentID) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "agent_id is required"})
		return
	}

	s.peers.Delete(req.AgentID)

	if err := s.saveState(); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "peer deleted but persist failed: " + err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "peer deleted"})
}

func (s *Server) handleUIConfigSave(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	var fileCfg ConfigFile
	if err := decodeJSON(r, &fileCfg); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}

	configPath := getenvDefault("LUMOS_CONFIG_FILE", "lumos-config.json")
	if err := saveConfigToFile(configPath, &fileCfg); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "failed to save config: " + err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, APIResponse{OK: true, Message: "config saved; restart agent to apply changes"})
}

func (s *Server) handleUIConfigLoad(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}

	configPath := getenvDefault("LUMOS_CONFIG_FILE", "lumos-config.json")
	fileCfg, err := loadConfigFromFile(configPath)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{OK: false, Message: "failed to load config: " + err.Error()})
		return
	}

	if fileCfg == nil {
		// No config file exists, return current runtime config as template
		cfg := s.cfgSnapshot()
		fileCfg = &ConfigFile{
			Bind:                     cfg.Bind,
			AdvertiseAddr:            cfg.AdvertiseAddr,
			AgentID:                  cfg.AgentID,
			ClusterKey:               cfg.ClusterKey,
			BootstrapPeers:           cfg.BootstrapPeers,
			AllowWakeWithoutPassword: boolPtr(cfg.AllowWakeWithoutPassword),
			DryRun:                   boolPtr(cfg.DryRun),
			StateFile:                cfg.StateFile,
			TLSCertFile:              cfg.TLSCertFile,
			TLSKeyFile:               cfg.TLSKeyFile,
			RequireTLS:               boolPtr(cfg.RequireTLS),
			AllowInsecureRemoteHTTP:  boolPtr(cfg.AllowInsecureRemoteHTTP),
			UIUser:                   cfg.UIUser,
			MDNSEnabled:              boolPtr(cfg.MDNSEnabled),
			MDNSService:              cfg.MDNSService,
			PublicAdvertiseAddr:      cfg.PublicAdvertiseAddr,
			VPNAdvertiseAddr:         cfg.VPNAdvertiseAddr,
			SafeModeEnabled:          boolPtr(cfg.SafeModeEnabled),
			SafeModeCooldownSeconds:  intPtr(cfg.SafeModeCooldownSeconds),
			DefaultTokenAllowances:   allowancesFileFromAllowances(cfg.DefaultTokenAllowances),
			TokenAllowances:          map[string]ActionAllowancesFile{},
			RelayInboundAllowances:   map[string]ActionAllowancesFile{},
			RelayOutboundAllowances:  map[string]ActionAllowancesFile{},
		}
		for key, value := range cfg.TokenAllowances {
			fileCfg.TokenAllowances[key] = *allowancesFileFromAllowances(value)
		}
		for key, value := range cfg.RelayInboundAllowances {
			fileCfg.RelayInboundAllowances[key] = *allowancesFileFromAllowances(value)
		}
		for key, value := range cfg.RelayOutboundAllowances {
			fileCfg.RelayOutboundAllowances[key] = *allowancesFileFromAllowances(value)
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "config": fileCfg})
}

// verifyPeerAccess verifies that a peer is reachable and the password is correct
func (s *Server) verifyPeerAccess(address, password string) error {
	normalizedAddress, err := normalizeRelayAddress(address, false)
	if err != nil {
		return err
	}
	url := endpointURL(normalizedAddress, "/v1/auth/token/list")
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("X-Lumos-Password", password)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized {
		return errors.New("invalid password for peer")
	}
	if resp.StatusCode != http.StatusOK {
		return errors.New("peer returned status " + resp.Status)
	}

	return nil
}
