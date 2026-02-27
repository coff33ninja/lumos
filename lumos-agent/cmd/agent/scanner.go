package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

type ScanResult struct {
	Address    string             `json:"address"`
	AgentID    string             `json:"agent_id,omitempty"`
	Reachable  bool               `json:"reachable"`
	OS         string             `json:"os,omitempty"`
	Interfaces []NetworkInterface `json:"interfaces,omitempty"`
}

func (s *Server) handleScanNetwork(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	// /v1/ui/scan is protected by UI basic auth middleware.
	// /v1/scan supports token/password auth for app clients.
	if r.URL.Path == "/v1/scan" && !s.authorizePasswordOrReject(w, r) {
		return
	}

	var req struct {
		Network string `json:"network"` // e.g., "192.168.1.0/24"
		Port    int    `json:"port"`    // default 8080
		Timeout int    `json:"timeout"` // seconds, default 2
	}
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: err.Error()})
		return
	}

	if req.Port == 0 {
		req.Port = 8080
	}
	if req.Timeout == 0 {
		req.Timeout = 2
	}

	// If no network specified, detect local networks and scan each one.
	if strings.TrimSpace(req.Network) == "" {
		localNets, err := detectLocalNetworks()
		if err != nil {
			writeJSON(w, http.StatusBadRequest, APIResponse{OK: false, Message: "network required or auto-detect failed: " + err.Error()})
			return
		}
		mergedByAddress := make(map[string]ScanResult)
		scanned := make([]string, 0, len(localNets))
		totalHosts := 0
		start := time.Now()
		for _, network := range localNets {
			results, hosts := scanNetwork(network, req.Port, time.Duration(req.Timeout)*time.Second)
			totalHosts += hosts
			scanned = append(scanned, network)
			for _, result := range results {
				mergedByAddress[result.Address] = result
			}
		}

		merged := make([]ScanResult, 0, len(mergedByAddress))
		for _, result := range mergedByAddress {
			merged = append(merged, result)
		}
		sort.Slice(merged, func(i, j int) bool {
			return merged[i].Address < merged[j].Address
		})

		writeJSON(w, http.StatusOK, map[string]any{
			"ok":                true,
			"results":           merged,
			"scanned":           strings.Join(scanned, ", "),
			"scanned_networks":  scanned,
			"detected_networks": localNets,
			"hosts_total":       totalHosts,
			"hosts_reachable":   len(merged),
			"duration_ms":       time.Since(start).Milliseconds(),
		})
		return
	}

	start := time.Now()
	results, totalHosts := scanNetwork(req.Network, req.Port, time.Duration(req.Timeout)*time.Second)
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":               true,
		"results":          results,
		"scanned":          req.Network,
		"hosts_total":      totalHosts,
		"hosts_reachable":  len(results),
		"duration_ms":      time.Since(start).Milliseconds(),
		"scanned_networks": []string{req.Network},
	})
}

func scanNetwork(network string, port int, timeout time.Duration) ([]ScanResult, int) {
	_, ipnet, err := net.ParseCIDR(network)
	if err != nil {
		return []ScanResult{}, 0
	}

	targets := enumerateTargets(ipnet)
	if len(targets) == 0 {
		return []ScanResult{}, 0
	}
	// Keep scans bounded for predictable memory/CPU use.
	if len(targets) > 4096 {
		return []ScanResult{}, len(targets)
	}

	var results []ScanResult
	var mu sync.Mutex
	var wg sync.WaitGroup
	jobs := make(chan string)
	workers := len(targets)
	if workers > 128 {
		workers = 128
	}

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for addr := range jobs {
				result := scanHost(addr, port, timeout)
				if result.Reachable {
					mu.Lock()
					results = append(results, result)
					mu.Unlock()
				}
			}
		}()
	}
	for _, ip := range targets {
		jobs <- ip
	}
	close(jobs)

	wg.Wait()
	sort.Slice(results, func(i, j int) bool {
		return results[i].Address < results[j].Address
	})
	return results, len(targets)
}

func scanHost(ip string, port int, timeout time.Duration) ScanResult {
	address := net.JoinHostPort(ip, strconv.Itoa(port))
	result := ScanResult{Address: address, Reachable: false}

	// Try to connect
	conn, err := net.DialTimeout("tcp", address, timeout)
	if err != nil {
		return result
	}
	conn.Close()
	result.Reachable = true

	// Try to get agent status
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	url := fmt.Sprintf("http://%s/v1/status", address)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return result
	}

	client := &http.Client{Timeout: timeout}
	resp, err := client.Do(req)
	if err != nil {
		return result
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		var status struct {
			AgentID    string             `json:"agent_id"`
			OS         string             `json:"os"`
			Interfaces []NetworkInterface `json:"interfaces"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&status); err == nil {
			result.AgentID = status.AgentID
			result.OS = status.OS
			result.Interfaces = status.Interfaces
			// Store interfaces for later use
			if len(status.Interfaces) > 0 {
				result.Reachable = true
			}
		}
	}

	return result
}

func incIP(ip net.IP) {
	for j := len(ip) - 1; j >= 0; j-- {
		ip[j]++
		if ip[j] > 0 {
			break
		}
	}
}

func enumerateTargets(ipnet *net.IPNet) []string {
	networkIP := ipnet.IP.Mask(ipnet.Mask)
	if networkIP == nil {
		return nil
	}

	// For IPv4, skip network and broadcast addresses when possible.
	if networkIP.To4() != nil {
		var out []string
		for ip := append(net.IP(nil), networkIP...); ipnet.Contains(ip); incIP(ip) {
			out = append(out, ip.String())
		}
		if len(out) <= 2 {
			return nil
		}
		return out[1 : len(out)-1]
	}

	// For IPv6, scan all addresses in the provided range (caller limits size).
	var out []string
	for ip := append(net.IP(nil), networkIP...); ipnet.Contains(ip); incIP(ip) {
		out = append(out, ip.String())
	}
	return out
}

func detectLocalNetworks() ([]string, error) {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return nil, err
	}

	seen := map[string]struct{}{}
	networks := make([]string, 0, 4)
	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ip4 := ipnet.IP.To4(); ip4 != nil {
				// Use /24 slices for practical LAN scanning and to avoid very large ranges.
				cidr := fmt.Sprintf("%d.%d.%d.0/24", ip4[0], ip4[1], ip4[2])
				if _, ok := seen[cidr]; ok {
					continue
				}
				seen[cidr] = struct{}{}
				networks = append(networks, cidr)
			}
		}
	}
	sort.Strings(networks)
	if len(networks) == 0 {
		return nil, fmt.Errorf("no local network found")
	}
	return networks, nil
}

func detectLocalNetwork() (string, error) {
	networks, err := detectLocalNetworks()
	if err != nil {
		return "", err
	}
	return networks[0], nil
}
