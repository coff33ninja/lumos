//go:build windows

package main

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/getlantern/systray"
)

var agentCmd *exec.Cmd
var shutdownKey string

// ConfigFile mirrors the structure from cmd/agent/config.go
type ConfigFile struct {
	ShutdownKey string `json:"shutdown_key,omitempty"`
}

func main() {
	systray.Run(onReady, onExit)
}

func onReady() {
	systray.SetTitle("Lumos")
	systray.SetTooltip("Lumos Agent")

	openItem := systray.AddMenuItem("Open Control Panel", "Open Lumos local UI")
	restartItem := systray.AddMenuItem("Restart Agent", "Restart Lumos background agent")
	statusItem := systray.AddMenuItem("Status: starting", "Agent status")
	statusItem.Disable()
	systray.AddSeparator()
	quitItem := systray.AddMenuItem("Quit", "Stop Lumos and quit tray")

	if err := startAgent(); err != nil {
		log.Printf("failed to start agent: %v", err)
	}
	statusItem.SetTitle("Status: running")

	go func() {
		t := time.NewTicker(4 * time.Second)
		defer t.Stop()
		for range t.C {
			if agentCmd == nil || agentCmd.ProcessState != nil {
				statusItem.SetTitle("Status: restarting")
				if err := startAgent(); err != nil {
					log.Printf("failed to auto-restart agent: %v", err)
					statusItem.SetTitle("Status: failed")
				} else {
					statusItem.SetTitle("Status: running")
				}
			}
		}
	}()

	go func() {
		for {
			select {
			case <-openItem.ClickedCh:
				_ = openBrowser(resolveControlURL())
			case <-restartItem.ClickedCh:
				statusItem.SetTitle("Status: restarting")
				_ = stopAgent()
				if err := startAgent(); err != nil {
					log.Printf("failed to restart agent: %v", err)
					statusItem.SetTitle("Status: failed")
				} else {
					statusItem.SetTitle("Status: running")
				}
			case <-quitItem.ClickedCh:
				statusItem.SetTitle("Status: stopping")
				_ = stopAgent()
				systray.Quit()
				return
			}
		}
	}()
}

func onExit() {
	_ = stopAgent()
}

func startAgent() error {
	// Try to read shutdown key from config file
	shutdownKey = loadShutdownKeyFromConfig()
	if shutdownKey == "" {
		// Fallback to generating a key if config file doesn't exist or key is missing
		shutdownKey = generateShutdownKey()
		log.Printf("warning: using generated shutdown key (config file not found or shutdown_key missing)")
	}
	
	agentPath := resolveAgentPath()
	cmd := exec.Command(agentPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	cmd.Env = append(os.Environ(), "LUMOS_SHUTDOWN_KEY="+shutdownKey)
	if err := cmd.Start(); err != nil {
		return err
	}
	agentCmd = cmd
	go func(localCmd *exec.Cmd) {
		_ = localCmd.Wait()
	}(cmd)
	return nil
}

func stopAgent() error {
	if agentCmd == nil || agentCmd.Process == nil {
		return nil
	}
	shutdownURL := strings.TrimRight(resolveControlURL(), "/") + "/v1/admin/shutdown"
	body := bytes.NewBufferString("{}")
	req, err := http.NewRequest("POST", shutdownURL, body)
	if err == nil {
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Lumos-Shutdown-Key", shutdownKey)
		client := &http.Client{Timeout: 2 * time.Second}
		resp, reqErr := client.Do(req)
		if reqErr == nil && resp != nil {
			_ = resp.Body.Close()
		}
	}
	time.Sleep(400 * time.Millisecond)
	if agentCmd.ProcessState == nil {
		_ = agentCmd.Process.Kill()
	}
	agentCmd = nil
	return nil
}

func resolveAgentPath() string {
	if v := os.Getenv("LUMOS_AGENT_BIN"); v != "" {
		return v
	}
	exePath, err := os.Executable()
	if err != nil {
		return "lumos-agent.exe"
	}
	return filepath.Join(filepath.Dir(exePath), "lumos-agent.exe")
}

func openBrowser(rawURL string) error {
	if _, err := url.Parse(rawURL); err != nil {
		return err
	}
	return exec.Command("rundll32", "url.dll,FileProtocolHandler", rawURL).Start()
}

func resolveControlURL() string {
	v := strings.TrimSpace(os.Getenv("LUMOS_CONTROL_URL"))
	if v == "" {
		return "http://127.0.0.1:8080/"
	}
	if !strings.HasSuffix(v, "/") {
		v += "/"
	}
	return v
}

func generateShutdownKey() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "lumos-shutdown"
	}
	return hex.EncodeToString(b)
}

func loadShutdownKeyFromConfig() string {
	// Determine config file path (same logic as agent)
	configPath := strings.TrimSpace(os.Getenv("LUMOS_CONFIG_FILE"))
	if configPath == "" {
		configPath = defaultConfigPath()
	}

	// Try to read the config file
	data, err := os.ReadFile(configPath)
	if err != nil {
		// Config file doesn't exist or can't be read
		return ""
	}

	// Parse JSON to extract shutdown_key
	var cfg ConfigFile
	if err := json.Unmarshal(data, &cfg); err != nil {
		log.Printf("warning: failed to parse config file: %v", err)
		return ""
	}

	return strings.TrimSpace(cfg.ShutdownKey)
}

func defaultConfigPath() string {
	exe, err := os.Executable()
	if err != nil || strings.TrimSpace(exe) == "" {
		return "lumos-config.json"
	}
	return filepath.Join(filepath.Dir(exe), "lumos-config.json")
}
