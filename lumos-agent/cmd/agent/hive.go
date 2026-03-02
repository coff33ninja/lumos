package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

// handleHiveJoin initiates cluster key handshake from master to peer
func (s *Server) handleHiveJoin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}

	// Require master's password
	if !s.authorizePasswordOrReject(w, r) {
		return
	}

	var req HiveJoinRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}

	// Validate required fields
	if strings.TrimSpace(req.PeerAgentID) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "peer_agent_id is required"})
		return
	}
	if strings.TrimSpace(req.PeerAddress) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "peer_address is required"})
		return
	}
	if strings.TrimSpace(req.PeerPassword) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "peer_password is required"})
		return
	}
	if strings.TrimSpace(req.ClusterKey) == "" {
		// Use master's cluster key if not provided
		cfg := s.cfgSnapshot()
		req.ClusterKey = cfg.ClusterKey
	}

	// Initiate handshake with peer
	clusterKeyUpdated, err := s.initiateHiveHandshake(req.PeerAgentID, req.PeerAddress, req.PeerPassword, req.ClusterKey, req.Force)
	if err != nil {
		s.recordAudit("hive", "join", req.PeerAgentID, req.PeerAddress, false, "handshake failed: "+err.Error(), remoteIP(r))
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "handshake failed: " + err.Error()})
		return
	}

	// Register peer after successful handshake
	s.upsertPeer(req.PeerAgentID, req.PeerAddress, "", "")
	_ = s.saveState()

	s.recordAudit("hive", "join", req.PeerAgentID, req.PeerAddress, true, "peer joined hive", remoteIP(r))

	writeJSON(w, http.StatusOK, HiveJoinResponse{
		OK:               true,
		Message:          "peer joined hive successfully",
		PeerAgentID:      req.PeerAgentID,
		PeerAddress:      req.PeerAddress,
		ClusterKeyUpdate: clusterKeyUpdated,
		PeerRestarted:    false,
	})
}

// handleHiveAccept accepts cluster key handshake from master
func (s *Server) handleHiveAccept(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}

	// Require peer's password
	if !s.authorizePasswordOrReject(w, r) {
		return
	}

	var req HiveAcceptRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}

	// Validate required fields
	if strings.TrimSpace(req.MasterAgentID) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "master_agent_id is required"})
		return
	}
	if strings.TrimSpace(req.MasterAddress) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "master_address is required"})
		return
	}
	if strings.TrimSpace(req.ClusterKey) == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "cluster_key is required"})
		return
	}

	cfg := s.cfgSnapshot()

	// Check if cluster key is already the same
	if cfg.ClusterKey == req.ClusterKey {
		s.recordAudit("hive", "accept", req.MasterAgentID, req.MasterAddress, true, "cluster key already synced", remoteIP(r))
		writeJSON(w, http.StatusOK, HiveAcceptResponse{
			OK:               true,
			Message:          "cluster key already synced",
			ClusterKeyUpdate: false,
			RestartRequired:  false,
		})
		return
	}

	// Check if force is required
	if !req.Force && cfg.ClusterKey != "" && cfg.ClusterKey != req.ClusterKey {
		s.recordAudit("hive", "accept", req.MasterAgentID, req.MasterAddress, false, "cluster key mismatch, force required", remoteIP(r))
		writeJSON(w, http.StatusForbidden, APIResponse{
			OK:      false,
			Message: "cluster key mismatch, use force=true to override",
		})
		return
	}

	// Update cluster key
	if err := s.updateClusterKey(req.ClusterKey); err != nil {
		s.recordAudit("hive", "accept", req.MasterAgentID, req.MasterAddress, false, "failed to update cluster key: "+err.Error(), remoteIP(r))
		writeJSON(w, http.StatusInternalServerError, APIResponse{
			OK:      false,
			Message: "failed to update cluster key: " + err.Error(),
		})
		return
	}

	// Register master as peer
	s.upsertPeer(req.MasterAgentID, req.MasterAddress, "", "")
	_ = s.saveState()

	s.recordAudit("hive", "accept", req.MasterAgentID, req.MasterAddress, true, "cluster key accepted", remoteIP(r))

	writeJSON(w, http.StatusOK, HiveAcceptResponse{
		OK:               true,
		Message:          "cluster key accepted and updated",
		ClusterKeyUpdate: true,
		RestartRequired:  false,
	})
}

// initiateHiveHandshake sends cluster key to peer and waits for acceptance
func (s *Server) initiateHiveHandshake(peerAgentID, peerAddress, peerPassword, clusterKey string, force bool) (bool, error) {
	// Normalize peer address
	normalizedAddress, err := normalizeRelayAddress(peerAddress, true)
	if err != nil {
		return false, fmt.Errorf("invalid peer address: %w", err)
	}

	// Verify peer is reachable
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	statusURL := endpointURL(normalizedAddress, "/v1/status")
	statusReq, err := http.NewRequestWithContext(ctx, http.MethodGet, statusURL, nil)
	if err != nil {
		return false, fmt.Errorf("failed to create status request: %w", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	statusResp, err := client.Do(statusReq)
	if err != nil {
		return false, fmt.Errorf("peer unreachable: %w", err)
	}
	statusResp.Body.Close()

	if statusResp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("peer returned status %d", statusResp.StatusCode)
	}

	// Prepare handshake request
	cfg := s.cfgSnapshot()
	handshakeReq := HiveAcceptRequest{
		MasterAgentID: cfg.AgentID,
		MasterAddress: cfg.AdvertiseAddr,
		ClusterKey:    clusterKey,
		Force:         force,
	}

	body, err := json.Marshal(handshakeReq)
	if err != nil {
		return false, fmt.Errorf("failed to marshal handshake request: %w", err)
	}

	// Send handshake to peer
	handshakeURL := endpointURL(normalizedAddress, "/v1/hive/accept")
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, handshakeURL, bytes.NewReader(body))
	if err != nil {
		return false, fmt.Errorf("failed to create handshake request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-Lumos-Password", peerPassword)

	handshakeResp, err := client.Do(httpReq)
	if err != nil {
		return false, fmt.Errorf("handshake request failed: %w", err)
	}
	defer handshakeResp.Body.Close()

	if handshakeResp.StatusCode == http.StatusUnauthorized {
		return false, errors.New("peer password incorrect")
	}

	if handshakeResp.StatusCode == http.StatusForbidden {
		respBody, _ := io.ReadAll(io.LimitReader(handshakeResp.Body, 1024))
		return false, fmt.Errorf("peer rejected handshake: %s", strings.TrimSpace(string(respBody)))
	}

	if handshakeResp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(io.LimitReader(handshakeResp.Body, 1024))
		return false, fmt.Errorf("peer returned %d: %s", handshakeResp.StatusCode, strings.TrimSpace(string(respBody)))
	}

	// Parse response
	var acceptResp HiveAcceptResponse
	if err := json.NewDecoder(handshakeResp.Body).Decode(&acceptResp); err != nil {
		return false, fmt.Errorf("failed to parse handshake response: %w", err)
	}

	if !acceptResp.OK {
		return false, fmt.Errorf("peer rejected handshake: %s", acceptResp.Message)
	}

	return acceptResp.ClusterKeyUpdate, nil
}

// updateClusterKey updates the cluster key in memory and persists to config file
func (s *Server) updateClusterKey(newKey string) error {
	if strings.TrimSpace(newKey) == "" {
		return errors.New("cluster key cannot be empty")
	}

	// Update in-memory config
	s.mu.Lock()
	oldKey := s.cfg.ClusterKey
	s.cfg.ClusterKey = newKey
	s.mu.Unlock()

	// If config was loaded from file, update the file
	cfg := s.cfgSnapshot()
	if cfg.ConfigFromFile {
		if err := s.updateConfigFile(map[string]interface{}{
			"cluster_key": newKey,
		}); err != nil {
			// Rollback in-memory change
			s.mu.Lock()
			s.cfg.ClusterKey = oldKey
			s.mu.Unlock()
			return fmt.Errorf("failed to update config file: %w", err)
		}
	}

	return nil
}

// updateConfigFile updates specific fields in the config file
func (s *Server) updateConfigFile(updates map[string]interface{}) error {
	cfg := s.cfgSnapshot()
	if !cfg.ConfigFromFile {
		return errors.New("config was not loaded from file")
	}

	// Read current config file
	configPath := "lumos-config.json"
	data, err := os.ReadFile(configPath)
	if err != nil {
		return fmt.Errorf("failed to read config file: %w", err)
	}

	// Parse existing config
	var configMap map[string]interface{}
	if err := json.Unmarshal(data, &configMap); err != nil {
		return fmt.Errorf("failed to parse config file: %w", err)
	}

	// Apply updates
	for key, value := range updates {
		configMap[key] = value
	}

	// Write back to file
	updatedData, err := json.MarshalIndent(configMap, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal updated config: %w", err)
	}

	if err := os.WriteFile(configPath, updatedData, 0600); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}
