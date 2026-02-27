package main

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/grandcat/zeroconf"
)

func (s *Server) peerSyncLoop() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	s.syncPeers()
	for range ticker.C {
		s.syncPeers()
	}
}

func (s *Server) mdnsAnnounceLoop() {
	cfg := s.cfgSnapshot()
	service := strings.TrimSpace(cfg.MDNSService)
	if service == "" {
		service = "_lumos-agent._tcp"
	}
	port := 8080
	if strings.Contains(cfg.Bind, ":") {
		parts := strings.Split(cfg.Bind, ":")
		last := parts[len(parts)-1]
		if p, err := strconv.Atoi(last); err == nil && p > 0 {
			port = p
		}
	}
	txt := []string{"agent_id=" + cfg.AgentID, "addr=" + cfg.AdvertiseAddr}
	server, err := zeroconf.Register(cfg.AgentID, service, "local.", port, txt, nil)
	if err != nil {
		log.Printf("mdns announce failed: %v", err)
		return
	}
	defer server.Shutdown()
	select {}
}

func (s *Server) mdnsDiscoverLoop() {
	cfg := s.cfgSnapshot()
	service := strings.TrimSpace(cfg.MDNSService)
	if service == "" {
		service = "_lumos-agent._tcp"
	}
	resolver, err := zeroconf.NewResolver(nil)
	if err != nil {
		log.Printf("mdns resolver init failed: %v", err)
		return
	}
	for {
		entries := make(chan *zeroconf.ServiceEntry)
		ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
		go func(results <-chan *zeroconf.ServiceEntry) {
			for entry := range results {
				agentID := entry.Instance
				if strings.TrimSpace(agentID) == "" || agentID == s.cfgSnapshot().AgentID {
					continue
				}
				address := ""
				if len(entry.AddrIPv4) > 0 {
					address = entry.AddrIPv4[0].String() + ":" + strconv.Itoa(entry.Port)
				} else if len(entry.AddrIPv6) > 0 {
					address = "[" + entry.AddrIPv6[0].String() + "]:" + strconv.Itoa(entry.Port)
				}
				if address == "" {
					continue
				}
				s.upsertPeer(agentID, address, "", "")
			}
		}(entries)
		_ = resolver.Browse(ctx, service, "local.", entries)
		<-ctx.Done()
		cancel()
		_ = s.saveState()
		time.Sleep(20 * time.Second)
	}
}

func (s *Server) syncPeers() {
	cfg := s.cfgSnapshot()
	if strings.TrimSpace(cfg.ClusterKey) == "" || len(cfg.BootstrapPeers) == 0 {
		return
	}
	registerReq := PeerRegisterRequest{AgentID: cfg.AgentID, Address: cfg.AdvertiseAddr}
	registerReq.PublicAddress = cfg.PublicAdvertiseAddr
	registerReq.VPNAddress = cfg.VPNAdvertiseAddr
	body, err := json.Marshal(registerReq)
	if err != nil {
		return
	}
	for _, peer := range cfg.BootstrapPeers {
		url := endpointURL(peer, "/v1/peer/register")
		req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
		if err != nil {
			continue
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Lumos-Cluster-Key", cfg.ClusterKey)
		resp, err := (&http.Client{Timeout: 3 * time.Second}).Do(req)
		if err != nil {
			continue
		}
		_ = resp.Body.Close()
	}
}

func (s *Server) forwardCommandToPeer(peerAddress string, req PeerForwardRequest) error {
	cfg := s.cfgSnapshot()
	normalizedAddress, err := normalizeRelayAddress(peerAddress, true)
	if err != nil {
		return err
	}
	body, err := json.Marshal(req)
	if err != nil {
		return err
	}
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	nonce, err := randomHex(16)
	if err != nil {
		return err
	}
	mac := hmac.New(sha256.New, []byte(cfg.ClusterKey))
	mac.Write([]byte(ts))
	mac.Write([]byte("."))
	mac.Write([]byte(nonce))
	mac.Write([]byte("."))
	mac.Write(body)
	signature := hex.EncodeToString(mac.Sum(nil))
	httpReq, err := http.NewRequest(http.MethodPost, endpointURL(normalizedAddress, "/v1/peer/forward"), bytes.NewReader(body))
	if err != nil {
		return err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-Lumos-Timestamp", ts)
	httpReq.Header.Set("X-Lumos-Nonce", nonce)
	httpReq.Header.Set("X-Lumos-Signature", signature)
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return fmt.Errorf("peer returned %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}
	return nil
}

func (s *Server) verifyPeerSignature(r *http.Request) error {
	cfg := s.cfgSnapshot()
	if strings.TrimSpace(cfg.ClusterKey) == "" {
		return errors.New("cluster key not configured")
	}
	ts := r.Header.Get("X-Lumos-Timestamp")
	nonce := r.Header.Get("X-Lumos-Nonce")
	signature := r.Header.Get("X-Lumos-Signature")
	if ts == "" || signature == "" || nonce == "" {
		return errors.New("missing signature headers")
	}
	parsedTS, err := strconv.ParseInt(ts, 10, 64)
	if err != nil {
		return errors.New("bad timestamp")
	}
	now := time.Now().Unix()
	if abs64(now-parsedTS) > 30 {
		return errors.New("timestamp too old or too far in future")
	}
	nowTime := time.Now()
	if s.nonceGuard.Seen(nonce, nowTime) {
		return errors.New("replay nonce")
	}
	bodyBytes, err := readBodyAndRestore(r)
	if err != nil {
		return err
	}
	mac := hmac.New(sha256.New, []byte(cfg.ClusterKey))
	mac.Write([]byte(ts))
	mac.Write([]byte("."))
	mac.Write([]byte(nonce))
	mac.Write([]byte("."))
	mac.Write(bodyBytes)
	expected := hex.EncodeToString(mac.Sum(nil))
	if subtle.ConstantTimeCompare([]byte(expected), []byte(signature)) != 1 {
		return errors.New("signature mismatch")
	}
	s.nonceGuard.Mark(nonce, nowTime.Add(2*time.Minute))
	return nil
}

func (s *Server) cfgSnapshot() Config { s.mu.RLock(); defer s.mu.RUnlock(); return s.cfg }

func (s *Server) upsertPeer(agentID, address, publicAddress, vpnAddress string) {
	s.peers.Store(agentID, PeerInfo{
		AgentID:       strings.TrimSpace(agentID),
		Address:       strings.TrimSpace(address),
		PublicAddress: strings.TrimSpace(publicAddress),
		VPNAddress:    strings.TrimSpace(vpnAddress),
		LastSeenAt:    time.Now().UTC(),
	})
}

func (s *Server) getPeer(agentID string) (PeerInfo, bool) {
	v, ok := s.peers.Load(agentID)
	if !ok {
		return PeerInfo{}, false
	}
	p, ok := v.(PeerInfo)
	return p, ok
}

func (s *Server) listPeers() []PeerInfo {
	out := make([]PeerInfo, 0, 8)
	s.peers.Range(func(_, value any) bool {
		if p, ok := value.(PeerInfo); ok {
			out = append(out, p)
		}
		return true
	})
	return out
}
