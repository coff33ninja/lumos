package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"regexp"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"time"
)

const maxJSONBodyBytes = 1 << 20 // 1 MiB

var normalizedRelayAddressPattern = regexp.MustCompile(`^https?://(?:[A-Za-z0-9.-]+|\[[0-9A-Fa-f:.]+\]):(?:[1-9][0-9]{0,4})$`)

func runPowerAction(action string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		switch action {
		case "shutdown":
			cmd = exec.CommandContext(ctx, "shutdown", "/s", "/t", "0", "/f")
		case "reboot":
			cmd = exec.CommandContext(ctx, "shutdown", "/r", "/t", "0", "/f")
		case "sleep":
			cmd = exec.CommandContext(ctx, "rundll32.exe", "powrprof.dll,SetSuspendState", "0,1,0")
		}
	default:
		switch action {
		case "shutdown":
			cmd = exec.CommandContext(ctx, "systemctl", "poweroff")
		case "reboot":
			cmd = exec.CommandContext(ctx, "systemctl", "reboot")
		case "sleep":
			cmd = exec.CommandContext(ctx, "systemctl", "suspend")
		}
	}
	if cmd == nil {
		return fmt.Errorf("unsupported action %q on os %q", action, runtime.GOOS)
	}
	output, err := cmd.CombinedOutput()
	if err != nil {
		msg := strings.TrimSpace(string(output))
		if msg != "" {
			return fmt.Errorf("command failed: %w: %s", err, msg)
		}
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return fmt.Errorf("command timeout after 5s: %w", err)
		}
		return fmt.Errorf("command failed: %w", err)
	}
	return nil
}

func sendMagicPacket(macAddr string) error {
	mac, err := net.ParseMAC(macAddr)
	if err != nil {
		return err
	}
	packet := make([]byte, 6+16*len(mac))
	for i := 0; i < 6; i++ {
		packet[i] = 0xFF
	}
	for i := 0; i < 16; i++ {
		copy(packet[6+i*len(mac):], mac)
	}

	// WOL reliability varies by network gear. Send to global + directed broadcasts
	// and to both common WOL ports.
	targets := wolBroadcastTargets()
	ports := []int{9, 7}

	var writeErrs []error
	sent := false
	for _, ip := range targets {
		for _, port := range ports {
			addr := &net.UDPAddr{IP: net.ParseIP(ip), Port: port}
			conn, err := net.DialUDP("udp4", nil, addr)
			if err != nil {
				writeErrs = append(writeErrs, err)
				continue
			}
			_ = conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
			if _, err := conn.Write(packet); err != nil {
				writeErrs = append(writeErrs, err)
				_ = conn.Close()
				continue
			}
			sent = true
			_ = conn.Close()
		}
	}

	if sent {
		return nil
	}
	if len(writeErrs) > 0 {
		return errors.Join(writeErrs...)
	}
	return fmt.Errorf("failed to send magic packet")
}

func wolBroadcastTargets() []string {
	seen := map[string]struct{}{
		net.IPv4bcast.String(): {},
	}
	out := []string{net.IPv4bcast.String()}

	ifaces, err := net.Interfaces()
	if err != nil {
		return out
	}
	for _, iface := range ifaces {
		if (iface.Flags&net.FlagUp) == 0 || (iface.Flags&net.FlagLoopback) != 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			ipNet, ok := addr.(*net.IPNet)
			if !ok || ipNet == nil {
				continue
			}
			ip4 := ipNet.IP.To4()
			mask := ipNet.Mask
			if ip4 == nil || len(mask) != net.IPv4len {
				continue
			}
			broadcast := make(net.IP, net.IPv4len)
			for i := 0; i < net.IPv4len; i++ {
				broadcast[i] = ip4[i] | ^mask[i]
			}
			target := broadcast.String()
			if _, exists := seen[target]; exists {
				continue
			}
			seen[target] = struct{}{}
			out = append(out, target)
		}
	}
	slices.Sort(out)
	return out
}

func decodeJSON(r *http.Request, out any) error {
	body, err := io.ReadAll(io.LimitReader(r.Body, maxJSONBodyBytes+1))
	if err != nil {
		return fmt.Errorf("invalid json: %w", err)
	}
	if int64(len(body)) > maxJSONBodyBytes {
		return fmt.Errorf("invalid json: body too large (max %d bytes)", maxJSONBodyBytes)
	}
	if len(bytes.TrimSpace(body)) == 0 {
		return fmt.Errorf("invalid json: empty body")
	}

	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if err := dec.Decode(out); err != nil {
		return fmt.Errorf("invalid json: %w", err)
	}
	var trailing any
	if err := dec.Decode(&trailing); err != io.EOF {
		return fmt.Errorf("invalid json: multiple JSON values are not allowed")
	}
	return nil
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s from=%s duration=%s", r.Method, r.URL.Path, r.RemoteAddr, time.Since(start).Round(time.Millisecond))
	})
}

func readBodyAndRestore(r *http.Request) ([]byte, error) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		return nil, err
	}
	r.Body = io.NopCloser(bytes.NewReader(body))
	return body, nil
}

func remoteIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(strings.TrimSpace(r.RemoteAddr))
	if err == nil && host != "" {
		return host
	}
	return strings.TrimSpace(r.RemoteAddr)
}

func getenvDefault(key, fallback string) string {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return fallback
	}
	return v
}

func getenvBool(key string, fallback bool) bool {
	v := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if v == "" {
		return fallback
	}
	return v == "1" || v == "true" || v == "yes" || v == "on"
}

func getenvInt(key string, fallback int) int {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return parsed
}

func parseCSVEnv(key string) []string { return parseCSV(os.Getenv(key)) }

func parseCSV(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		v := strings.TrimSpace(p)
		if v != "" {
			out = append(out, v)
		}
	}
	return uniqueStrings(out)
}

func uniqueStrings(in []string) []string {
	seen := make(map[string]struct{}, len(in))
	out := make([]string, 0, len(in))
	for _, item := range in {
		v := strings.TrimSpace(item)
		if v == "" {
			continue
		}
		if _, ok := seen[v]; ok {
			continue
		}
		seen[v] = struct{}{}
		out = append(out, v)
	}
	return out
}

func endpointURL(address, path string) string {
	trimmed := strings.TrimSpace(address)
	if strings.HasPrefix(trimmed, "http://") || strings.HasPrefix(trimmed, "https://") {
		return strings.TrimRight(trimmed, "/") + path
	}
	return "http://" + strings.TrimRight(trimmed, "/") + path
}

func normalizeRelayAddress(address string, disallowLoopback bool) (string, error) {
	raw := strings.TrimSpace(address)
	if raw == "" {
		return "", fmt.Errorf("address is required")
	}

	candidate := raw
	if !strings.Contains(candidate, "://") {
		candidate = "http://" + candidate
	}
	parsed, err := url.Parse(candidate)
	if err != nil {
		return "", fmt.Errorf("invalid address: %w", err)
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return "", fmt.Errorf("unsupported address scheme: %s", parsed.Scheme)
	}
	if parsed.Host == "" {
		return "", fmt.Errorf("address host is required")
	}
	if parsed.User != nil || (parsed.Path != "" && parsed.Path != "/") || parsed.RawQuery != "" || parsed.Fragment != "" {
		return "", fmt.Errorf("address must only include host and optional port")
	}

	host := strings.TrimSpace(parsed.Hostname())
	if host == "" {
		return "", fmt.Errorf("address host is required")
	}
	port := strings.TrimSpace(parsed.Port())
	if port == "" {
		port = "443"
		if parsed.Scheme == "http" {
			port = "80"
		}
	}

	resolver := net.DefaultResolver
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	ips, err := resolver.LookupIP(ctx, "ip", host)
	if err != nil {
		return "", fmt.Errorf("address host resolve failed: %w", err)
	}
	if len(ips) == 0 {
		return "", fmt.Errorf("address host resolve failed: no records")
	}
	for _, ip := range ips {
		if isDisallowedRelayIP(ip, disallowLoopback) {
			return "", fmt.Errorf("address host resolves to disallowed target: %s", ip.String())
		}
	}
	if ip := net.ParseIP(host); ip != nil && isDisallowedRelayIP(ip, disallowLoopback) {
		return "", fmt.Errorf("address host is disallowed target: %s", host)
	}

	return parsed.Scheme + "://" + net.JoinHostPort(host, port), nil
}

func isTrustedNormalizedRelayAddress(address string) bool {
	trimmed := strings.TrimSpace(address)
	if !normalizedRelayAddressPattern.MatchString(trimmed) {
		return false
	}
	parsed, err := url.Parse(trimmed)
	if err != nil {
		return false
	}
	port, err := strconv.Atoi(parsed.Port())
	if err != nil {
		return false
	}
	return port >= 1 && port <= 65535
}

func isDisallowedRelayIP(ip net.IP, disallowLoopback bool) bool {
	if ip == nil {
		return true
	}
	if disallowLoopback && ip.IsLoopback() {
		return true
	}
	return ip.IsUnspecified() || ip.IsLinkLocalMulticast() || ip.IsLinkLocalUnicast() || ip.IsMulticast()
}

func normalizedAddress(bind string) string {
	b := strings.TrimSpace(bind)
	if b == "" {
		return "127.0.0.1:8080"
	}
	if strings.HasPrefix(b, ":") {
		return "127.0.0.1" + b
	}
	if strings.HasPrefix(b, "0.0.0.0:") {
		return "127.0.0.1:" + strings.TrimPrefix(b, "0.0.0.0:")
	}
	return b
}

func hostnameFallback() string {
	host, err := os.Hostname()
	if err != nil || strings.TrimSpace(host) == "" {
		return "lumos-agent"
	}
	return host
}

func randomHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func abs64(v int64) int64 {
	if v < 0 {
		return -v
	}
	return v
}

func isLoopbackIP(s string) bool {
	ip := net.ParseIP(strings.TrimSpace(s))
	if ip == nil {
		return false
	}
	return ip.IsLoopback()
}

func boolPtr(v bool) *bool { return &v }
func intPtr(v int) *int    { return &v }
