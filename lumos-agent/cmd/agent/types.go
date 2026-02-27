package main

import (
	"sync"
	"time"
)

type Config struct {
	ConfigFromFile           bool
	Bind                     string
	AdvertiseAddr            string
	AgentID                  string
	PasswordBcryptHash       string
	ClusterKey               string
	BootstrapPeers           []string
	AllowWakeWithoutPassword bool
	DryRun                   bool
	StateFile                string
	TLSCertFile              string
	TLSKeyFile               string
	RequireTLS               bool
	AllowInsecureRemoteHTTP  bool
	UIUser                   string
	UIPasswordBcryptHash     string
	StateEncryptionKey       [32]byte
	ShutdownKey              string
	MDNSEnabled              bool
	MDNSService              string
	PublicAdvertiseAddr      string
	VPNAdvertiseAddr         string
	SafeModeEnabled          bool
	SafeModeCooldownSeconds  int
	DefaultTokenAllowances   ActionAllowances
	TokenAllowances          map[string]ActionAllowances
	RelayInboundAllowances   map[string]ActionAllowances
	RelayOutboundAllowances  map[string]ActionAllowances
}

type Server struct {
	mu         sync.RWMutex
	cfg        Config
	peers      sync.Map
	tokens     sync.Map
	auth       *AuthGuard
	nonceGuard *NonceGuard
	auditMu    sync.Mutex
	auditTrail []AuditEntry
	safeModeMu sync.Mutex
	pendingOps map[string]SafeModePending
	lastAction time.Time
	eventsMu   sync.Mutex
	eventSubs  map[int]chan []byte
	nextSubID  int

	tokenPersistMu   sync.Mutex
	tokenPersistLast time.Time
}

type AuthGuard struct {
	mu       sync.Mutex
	entries  map[string]authState
	maxFails int
	lockFor  time.Duration
}

type authState struct {
	Fails      int
	BlockedTil time.Time
	LastSeen   time.Time
}

type NonceGuard struct {
	mu      sync.Mutex
	entries map[string]time.Time
}

type PeerInfo struct {
	AgentID       string             `json:"agent_id"`
	Address       string             `json:"address"`
	PublicAddress string             `json:"public_address,omitempty"`
	VPNAddress    string             `json:"vpn_address,omitempty"`
	LastSeenAt    time.Time          `json:"last_seen_at"`
	Interfaces    []NetworkInterface `json:"interfaces,omitempty"`
}

type WakeRequest struct {
	MAC string `json:"mac"`
}

type CommandRequest struct {
	Action string `json:"action"`
}

type PeerRegisterRequest struct {
	AgentID       string `json:"agent_id"`
	Address       string `json:"address"`
	PublicAddress string `json:"public_address,omitempty"`
	VPNAddress    string `json:"vpn_address,omitempty"`
	Password      string `json:"password,omitempty"`
}

type PeerForwardRequest struct {
	SourceAgentID string `json:"source_agent_id"`
	TargetAgentID string `json:"target_agent_id"`
	Action        string `json:"action"`
	MAC           string `json:"mac,omitempty"`
	TimestampUnix int64  `json:"timestamp_unix"`
}

type PeerRelayRequest struct {
	TargetAgentID string `json:"target_agent_id"`
	Address       string `json:"address,omitempty"`
	Action        string `json:"action"`
	MAC           string `json:"mac,omitempty"`
}

type UISettingsRequest struct {
	AdvertiseAddr            string `json:"advertise_addr"`
	BootstrapPeers           string `json:"bootstrap_peers"`
	AllowWakeWithoutPassword bool   `json:"allow_wake_without_password"`
	DryRun                   bool   `json:"dry_run"`
	SafeModeEnabled          bool   `json:"safe_mode_enabled"`
	SafeModeCooldownSeconds  int    `json:"safe_mode_cooldown_seconds"`
}

type PersistedState struct {
	AgentID                  string                      `json:"agent_id"`
	AdvertiseAddr            string                      `json:"advertise_addr"`
	BootstrapPeers           []string                    `json:"bootstrap_peers"`
	AllowWakeWithoutPassword bool                        `json:"allow_wake_without_password"`
	DryRun                   bool                        `json:"dry_run"`
	SafeModeEnabled          bool                        `json:"safe_mode_enabled"`
	SafeModeCooldownSeconds  int                         `json:"safe_mode_cooldown_seconds"`
	SafeModeConfigured       bool                        `json:"safe_mode_configured,omitempty"`
	Peers                    []PeerInfo                  `json:"peers"`
	UpdatedAt                time.Time                   `json:"updated_at"`
	Tokens                   []AuthTokenRecord           `json:"tokens,omitempty"`
	DefaultTokenAllowances   ActionAllowances            `json:"default_token_allowances,omitempty"`
	TokenAllowances          map[string]ActionAllowances `json:"token_allowances,omitempty"`
	RelayInboundAllowances   map[string]ActionAllowances `json:"relay_inbound_allowances,omitempty"`
	RelayOutboundAllowances  map[string]ActionAllowances `json:"relay_outbound_allowances,omitempty"`
}

type AuthTokenRecord struct {
	ID         string     `json:"id"`
	Label      string     `json:"label"`
	Scope      string     `json:"scope,omitempty"`
	TokenHash  string     `json:"token_hash"`
	CreatedAt  time.Time  `json:"created_at"`
	LastUsedAt *time.Time `json:"last_used_at,omitempty"`
	RevokedAt  *time.Time `json:"revoked_at,omitempty"`
}

type PairRequest struct {
	Label string `json:"label"`
	Scope string `json:"scope,omitempty"`
}

type PairResponse struct {
	OK      bool   `json:"ok"`
	TokenID string `json:"token_id"`
	Token   string `json:"token"`
	Message string `json:"message,omitempty"`
}

type TokenActionRequest struct {
	TokenID string `json:"token_id"`
}

type PolicyDefaultUpdateRequest struct {
	Allowances ActionAllowances `json:"allowances"`
}

type PolicyTokenUpsertRequest struct {
	TokenID    string           `json:"token_id"`
	Allowances ActionAllowances `json:"allowances"`
}

type PolicyPeerUpsertRequest struct {
	AgentID    string           `json:"agent_id"`
	Allowances ActionAllowances `json:"allowances"`
}

type PolicyDeleteRequest struct {
	Key string `json:"key"`
}

type persistedEnvelope struct {
	Encrypted bool            `json:"encrypted"`
	Nonce     string          `json:"nonce,omitempty"`
	Data      string          `json:"data,omitempty"`
	Plain     *PersistedState `json:"plain,omitempty"`
}

type APIResponse struct {
	OK      bool   `json:"ok"`
	Message string `json:"message,omitempty"`
	Reason  string `json:"reason,omitempty"`
}

type ActionAllowances struct {
	Wake     bool `json:"wake"`
	Shutdown bool `json:"shutdown"`
	Reboot   bool `json:"reboot"`
	Sleep    bool `json:"sleep"`
	Relay    bool `json:"relay"`
}

type ActionAllowancesFile struct {
	Wake     *bool `json:"wake,omitempty"`
	Shutdown *bool `json:"shutdown,omitempty"`
	Reboot   *bool `json:"reboot,omitempty"`
	Sleep    *bool `json:"sleep,omitempty"`
	Relay    *bool `json:"relay,omitempty"`
}

type AuthPrincipal struct {
	Kind    string
	TokenID string
	Scope   string
}

type SafeModePending struct {
	Action    string
	Target    string
	MAC       string
	RemoteIP  string
	ExpiresAt time.Time
}

type AuditEntry struct {
	Timestamp time.Time `json:"timestamp"`
	Source    string    `json:"source"`
	Action    string    `json:"action"`
	Target    string    `json:"target,omitempty"`
	MAC       string    `json:"mac,omitempty"`
	Success   bool      `json:"success"`
	Message   string    `json:"message"`
	RemoteIP  string    `json:"remote_ip,omitempty"`
}
