package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

type ConfigFile struct {
	Bind                     string                          `json:"bind,omitempty"`
	AdvertiseAddr            string                          `json:"advertise_addr,omitempty"`
	AgentID                  string                          `json:"agent_id,omitempty"`
	Password                 string                          `json:"password,omitempty"`
	PasswordBcryptHash       string                          `json:"password_bcrypt_hash,omitempty"`
	ClusterKey               string                          `json:"cluster_key,omitempty"`
	BootstrapPeers           []string                        `json:"bootstrap_peers,omitempty"`
	AllowWakeWithoutPassword *bool                           `json:"allow_wake_without_password,omitempty"`
	DryRun                   *bool                           `json:"dry_run,omitempty"`
	StateFile                string                          `json:"state_file,omitempty"`
	TLSCertFile              string                          `json:"tls_cert_file,omitempty"`
	TLSKeyFile               string                          `json:"tls_key_file,omitempty"`
	RequireTLS               *bool                           `json:"require_tls,omitempty"`
	AllowInsecureRemoteHTTP  *bool                           `json:"allow_insecure_remote_http,omitempty"`
	UIUser                   string                          `json:"ui_user,omitempty"`
	UIPassword               string                          `json:"ui_password,omitempty"`
	UIPasswordBcryptHash     string                          `json:"ui_password_bcrypt_hash,omitempty"`
	StateEncryptionSalt      string                          `json:"state_encryption_salt,omitempty"`
	ShutdownKey              string                          `json:"shutdown_key,omitempty"`
	MDNSEnabled              *bool                           `json:"mdns_enabled,omitempty"`
	MDNSService              string                          `json:"mdns_service,omitempty"`
	PublicAdvertiseAddr      string                          `json:"public_advertise_addr,omitempty"`
	VPNAdvertiseAddr         string                          `json:"vpn_advertise_addr,omitempty"`
	SafeModeEnabled          *bool                           `json:"safe_mode_enabled,omitempty"`
	SafeModeCooldownSeconds  *int                            `json:"safe_mode_cooldown_seconds,omitempty"`
	DefaultTokenAllowances   *ActionAllowancesFile           `json:"default_token_allowances,omitempty"`
	TokenAllowances          map[string]ActionAllowancesFile `json:"token_allowances,omitempty"`
	RelayInboundAllowances   map[string]ActionAllowancesFile `json:"relay_inbound_allowances,omitempty"`
	RelayOutboundAllowances  map[string]ActionAllowancesFile `json:"relay_outbound_allowances,omitempty"`
}

func loadConfigFromFile(path string) (*ConfigFile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil // File doesn't exist, not an error
		}
		return nil, err
	}

	var cfg ConfigFile
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}

	return &cfg, nil
}

func saveConfigToFile(path string, cfg *ConfigFile) error {
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0600)
}

func loadConfigWithFallback() (Config, error) {
	configPath := strings.TrimSpace(os.Getenv("LUMOS_CONFIG_FILE"))
	if configPath == "" {
		configPath = defaultConfigPath()
	}
	configDir := filepath.Dir(configPath)

	if _, err := os.Stat(configPath); errors.Is(err, os.ErrNotExist) {
		if err := createDefaultConfigFile(configPath); err != nil {
			return Config{}, err
		}
		log.Printf("created default config file at %s (edit credentials before production use)", configPath)
	}

	// Try to load from JSON file first
	fileCfg, err := loadConfigFromFile(configPath)
	if err != nil {
		return Config{}, err
	}

	// Helper to get value from file, then env, then default
	getString := func(fileVal, envKey, defaultVal string) string {
		if fileVal != "" {
			return fileVal
		}
		return getenvDefault(envKey, defaultVal)
	}

	getBool := func(fileVal *bool, envKey string, defaultVal bool) bool {
		if fileCfg != nil && fileVal != nil {
			return *fileVal
		}
		return getenvBool(envKey, defaultVal)
	}

	getStringSlice := func(fileVal []string, envKey string) []string {
		if fileCfg != nil && len(fileVal) > 0 {
			return fileVal
		}
		return parseCSVEnv(envKey)
	}

	getInt := func(fileVal *int, envKey string, defaultVal int) int {
		if fileCfg != nil && fileVal != nil {
			return *fileVal
		}
		return getenvInt(envKey, defaultVal)
	}

	// Build config with fallback logic
	var bind, advertiseAddr, agentID, password, clusterKey string
	var bootstrapPeers []string
	var allowWakeWithoutPassword, dryRun, requireTLS, allowInsecureRemoteHTTP, mdnsEnabled bool
	var safeModeEnabled bool
	var safeModeCooldownSeconds int
	var stateFile, tlsCertFile, tlsKeyFile, uiUser, uiPassword, stateEncryptionSalt string
	var passwordBcryptHash, uiPasswordBcryptHash string
	var shutdownKey, mdnsService, publicAdvertiseAddr, vpnAdvertiseAddr string
	var defaultTokenAllowances ActionAllowances
	var tokenAllowances map[string]ActionAllowances
	var relayInboundAllowances map[string]ActionAllowances
	var relayOutboundAllowances map[string]ActionAllowances

	if fileCfg != nil {
		bind = getString(fileCfg.Bind, "LUMOS_BIND", ":8080")
		advertiseAddr = getString(fileCfg.AdvertiseAddr, "LUMOS_ADVERTISE_ADDR", "")
		agentID = getString(fileCfg.AgentID, "LUMOS_AGENT_ID", hostnameFallback())
		password = getString(fileCfg.Password, "LUMOS_AGENT_PASSWORD", "")
		passwordBcryptHash = strings.TrimSpace(fileCfg.PasswordBcryptHash)
		clusterKey = getString(fileCfg.ClusterKey, "LUMOS_CLUSTER_KEY", "")
		bootstrapPeers = getStringSlice(fileCfg.BootstrapPeers, "LUMOS_BOOTSTRAP_PEERS")
		allowWakeWithoutPassword = getBool(fileCfg.AllowWakeWithoutPassword, "LUMOS_ALLOW_WAKE_WITHOUT_PASSWORD", false)
		dryRun = getBool(fileCfg.DryRun, "LUMOS_DRY_RUN", true)
		stateFile = getString(fileCfg.StateFile, "LUMOS_STATE_FILE", "lumos-agent-state.json")
		tlsCertFile = getString(fileCfg.TLSCertFile, "LUMOS_TLS_CERT_FILE", "")
		tlsKeyFile = getString(fileCfg.TLSKeyFile, "LUMOS_TLS_KEY_FILE", "")
		requireTLS = getBool(fileCfg.RequireTLS, "LUMOS_REQUIRE_TLS", false)
		allowInsecureRemoteHTTP = getBool(fileCfg.AllowInsecureRemoteHTTP, "LUMOS_ALLOW_INSECURE_REMOTE_HTTP", false)
		uiUser = getString(fileCfg.UIUser, "LUMOS_UI_USER", "lumos")
		uiPassword = getString(fileCfg.UIPassword, "LUMOS_UI_PASSWORD", password)
		uiPasswordBcryptHash = strings.TrimSpace(fileCfg.UIPasswordBcryptHash)
		stateEncryptionSalt = getString(fileCfg.StateEncryptionSalt, "LUMOS_STATE_ENCRYPTION_SALT", "")
		shutdownKey = getString(fileCfg.ShutdownKey, "LUMOS_SHUTDOWN_KEY", "")
		mdnsEnabled = getBool(fileCfg.MDNSEnabled, "LUMOS_MDNS_ENABLED", true)
		mdnsService = getString(fileCfg.MDNSService, "LUMOS_MDNS_SERVICE", "_lumos-agent._tcp")
		publicAdvertiseAddr = getString(fileCfg.PublicAdvertiseAddr, "LUMOS_PUBLIC_ADVERTISE_ADDR", "")
		vpnAdvertiseAddr = getString(fileCfg.VPNAdvertiseAddr, "LUMOS_VPN_ADVERTISE_ADDR", "")
		safeModeEnabled = getBool(fileCfg.SafeModeEnabled, "LUMOS_SAFE_MODE_ENABLED", true)
		safeModeCooldownSeconds = getInt(fileCfg.SafeModeCooldownSeconds, "LUMOS_SAFE_MODE_COOLDOWN_SECONDS", 15)
		defaultTokenAllowances = allowancesFromFile(fileCfg.DefaultTokenAllowances)
		tokenAllowances = allowancesMapFromFile(fileCfg.TokenAllowances)
		relayInboundAllowances = allowancesMapFromFile(fileCfg.RelayInboundAllowances)
		relayOutboundAllowances = allowancesMapFromFile(fileCfg.RelayOutboundAllowances)
	} else {
		// No config file, use environment variables only
		bind = getenvDefault("LUMOS_BIND", ":8080")
		advertiseAddr = getenvDefault("LUMOS_ADVERTISE_ADDR", "")
		agentID = getenvDefault("LUMOS_AGENT_ID", hostnameFallback())
		password = os.Getenv("LUMOS_AGENT_PASSWORD")
		passwordBcryptHash = strings.TrimSpace(os.Getenv("LUMOS_AGENT_PASSWORD_BCRYPT_HASH"))
		clusterKey = os.Getenv("LUMOS_CLUSTER_KEY")
		bootstrapPeers = parseCSVEnv("LUMOS_BOOTSTRAP_PEERS")
		allowWakeWithoutPassword = getenvBool("LUMOS_ALLOW_WAKE_WITHOUT_PASSWORD", false)
		dryRun = getenvBool("LUMOS_DRY_RUN", true)
		stateFile = getenvDefault("LUMOS_STATE_FILE", "lumos-agent-state.json")
		tlsCertFile = strings.TrimSpace(os.Getenv("LUMOS_TLS_CERT_FILE"))
		tlsKeyFile = strings.TrimSpace(os.Getenv("LUMOS_TLS_KEY_FILE"))
		requireTLS = getenvBool("LUMOS_REQUIRE_TLS", false)
		allowInsecureRemoteHTTP = getenvBool("LUMOS_ALLOW_INSECURE_REMOTE_HTTP", false)
		uiUser = getenvDefault("LUMOS_UI_USER", "lumos")
		uiPassword = getenvDefault("LUMOS_UI_PASSWORD", password)
		uiPasswordBcryptHash = strings.TrimSpace(os.Getenv("LUMOS_UI_PASSWORD_BCRYPT_HASH"))
		stateEncryptionSalt = strings.TrimSpace(os.Getenv("LUMOS_STATE_ENCRYPTION_SALT"))
		shutdownKey = strings.TrimSpace(os.Getenv("LUMOS_SHUTDOWN_KEY"))
		mdnsEnabled = getenvBool("LUMOS_MDNS_ENABLED", true)
		mdnsService = getenvDefault("LUMOS_MDNS_SERVICE", "_lumos-agent._tcp")
		publicAdvertiseAddr = strings.TrimSpace(os.Getenv("LUMOS_PUBLIC_ADVERTISE_ADDR"))
		vpnAdvertiseAddr = strings.TrimSpace(os.Getenv("LUMOS_VPN_ADVERTISE_ADDR"))
		safeModeEnabled = getenvBool("LUMOS_SAFE_MODE_ENABLED", true)
		safeModeCooldownSeconds = getenvInt("LUMOS_SAFE_MODE_COOLDOWN_SECONDS", 15)
		defaultTokenAllowances = allowAllActions()
		tokenAllowances = map[string]ActionAllowances{}
		relayInboundAllowances = map[string]ActionAllowances{}
		relayOutboundAllowances = map[string]ActionAllowances{}
	}
	if safeModeCooldownSeconds < 0 {
		safeModeCooldownSeconds = 0
	}

	if !filepath.IsAbs(stateFile) && configDir != "" && configDir != "." {
		stateFile = filepath.Join(configDir, stateFile)
	}

	// Validate required fields
	if strings.TrimSpace(password) == "" {
		return Config{}, errors.New("password is required (set in config.json or LUMOS_AGENT_PASSWORD)")
	}

	// Normalize advertise address
	if advertiseAddr == "" {
		advertiseAddr = normalizedAddress(bind)
	}

	stateKey := deriveStateKey([]byte(password), stateEncryptionSalt)
	passwordBcryptHash, err = ensureBcryptHash(password, passwordBcryptHash, "password_bcrypt_hash")
	if err != nil {
		return Config{}, err
	}
	uiPasswordBcryptHash, err = ensureBcryptHash(uiPassword, uiPasswordBcryptHash, "ui_password_bcrypt_hash")
	if err != nil {
		return Config{}, err
	}

	return Config{
		ConfigFromFile:           fileCfg != nil,
		Bind:                     bind,
		AdvertiseAddr:            advertiseAddr,
		AgentID:                  agentID,
		PasswordBcryptHash:       passwordBcryptHash,
		ClusterKey:               clusterKey,
		BootstrapPeers:           bootstrapPeers,
		AllowWakeWithoutPassword: allowWakeWithoutPassword,
		DryRun:                   dryRun,
		StateFile:                stateFile,
		TLSCertFile:              tlsCertFile,
		TLSKeyFile:               tlsKeyFile,
		RequireTLS:               requireTLS,
		AllowInsecureRemoteHTTP:  allowInsecureRemoteHTTP,
		UIUser:                   uiUser,
		UIPasswordBcryptHash:     uiPasswordBcryptHash,
		StateEncryptionKey:       stateKey,
		ShutdownKey:              shutdownKey,
		MDNSEnabled:              mdnsEnabled,
		MDNSService:              mdnsService,
		PublicAdvertiseAddr:      publicAdvertiseAddr,
		VPNAdvertiseAddr:         vpnAdvertiseAddr,
		SafeModeEnabled:          safeModeEnabled,
		SafeModeCooldownSeconds:  safeModeCooldownSeconds,
		DefaultTokenAllowances:   defaultTokenAllowances,
		TokenAllowances:          tokenAllowances,
		RelayInboundAllowances:   relayInboundAllowances,
		RelayOutboundAllowances:  relayOutboundAllowances,
	}, nil
}

func defaultConfigPath() string {
	exe, err := os.Executable()
	if err != nil || strings.TrimSpace(exe) == "" {
		return "lumos-config.json"
	}
	return filepath.Join(filepath.Dir(exe), "lumos-config.json")
}

func createDefaultConfigFile(path string) error {
	password, err := randomHex(12)
	if err != nil {
		return err
	}
	clusterKey, err := randomHex(16)
	if err != nil {
		return err
	}
	uiPassword, err := randomHex(12)
	if err != nil {
		return err
	}
	shutdownKey, err := randomHex(16)
	if err != nil {
		return err
	}
	stateEncryptionSalt, err := randomHex(16)
	if err != nil {
		return err
	}

	cfg := ConfigFile{
		Bind:                     ":8080",
		AdvertiseAddr:            "",
		AgentID:                  hostnameFallback(),
		Password:                 password,
		ClusterKey:               clusterKey,
		BootstrapPeers:           []string{},
		AllowWakeWithoutPassword: boolPtr(false),
		DryRun:                   boolPtr(true),
		StateFile:                "lumos-agent-state.json",
		TLSCertFile:              "",
		TLSKeyFile:               "",
		RequireTLS:               boolPtr(false),
		AllowInsecureRemoteHTTP:  boolPtr(false),
		UIUser:                   "lumos",
		UIPassword:               uiPassword,
		StateEncryptionSalt:      stateEncryptionSalt,
		ShutdownKey:              shutdownKey,
		MDNSEnabled:              boolPtr(true),
		MDNSService:              "_lumos-agent._tcp",
		PublicAdvertiseAddr:      "",
		VPNAdvertiseAddr:         "",
		SafeModeEnabled:          boolPtr(true),
		SafeModeCooldownSeconds:  intPtr(15),
		DefaultTokenAllowances:   allowancesFileFromAllowances(allowAllActions()),
		TokenAllowances:          map[string]ActionAllowancesFile{},
		RelayInboundAllowances:   map[string]ActionAllowancesFile{},
		RelayOutboundAllowances:  map[string]ActionAllowancesFile{},
	}

	dir := filepath.Dir(path)
	if dir != "." && dir != "" {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
	}
	return saveConfigToFile(path, &cfg)
}

func allowAllActions() ActionAllowances {
	return ActionAllowances{Wake: true, Shutdown: true, Reboot: true, Sleep: true, Relay: true}
}

func allowancesFromFile(in *ActionAllowancesFile) ActionAllowances {
	base := allowAllActions()
	if in == nil {
		return base
	}
	if in.Wake != nil {
		base.Wake = *in.Wake
	}
	if in.Shutdown != nil {
		base.Shutdown = *in.Shutdown
	}
	if in.Reboot != nil {
		base.Reboot = *in.Reboot
	}
	if in.Sleep != nil {
		base.Sleep = *in.Sleep
	}
	if in.Relay != nil {
		base.Relay = *in.Relay
	}
	return base
}

func allowancesMapFromFile(in map[string]ActionAllowancesFile) map[string]ActionAllowances {
	if len(in) == 0 {
		return map[string]ActionAllowances{}
	}
	out := make(map[string]ActionAllowances, len(in))
	for key, value := range in {
		k := strings.TrimSpace(key)
		if k == "" {
			continue
		}
		v := value
		out[k] = allowancesFromFile(&v)
	}
	return out
}

func allowancesFileFromAllowances(in ActionAllowances) *ActionAllowancesFile {
	return &ActionAllowancesFile{
		Wake:     boolPtr(in.Wake),
		Shutdown: boolPtr(in.Shutdown),
		Reboot:   boolPtr(in.Reboot),
		Sleep:    boolPtr(in.Sleep),
		Relay:    boolPtr(in.Relay),
	}
}

func ensureBcryptHash(secret, configuredHash, fieldName string) (string, error) {
	trimmed := strings.TrimSpace(configuredHash)
	if trimmed != "" {
		if _, err := bcrypt.Cost([]byte(trimmed)); err != nil {
			return "", fmt.Errorf("%s is not a valid bcrypt hash: %w", fieldName, err)
		}
		return trimmed, nil
	}
	generated, err := bcrypt.GenerateFromPassword([]byte(secret), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("failed to generate %s: %w", fieldName, err)
	}
	return string(generated), nil
}
