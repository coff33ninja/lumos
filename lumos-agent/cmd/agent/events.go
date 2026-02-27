package main

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

var wsUpgrader = websocket.Upgrader{
	ReadBufferSize:  2048,
	WriteBufferSize: 2048,
	CheckOrigin: func(r *http.Request) bool {
		// LAN/mobile clients are expected; auth is enforced separately.
		return true
	},
}

func (s *Server) handleEvents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, APIResponse{OK: false, Message: "method not allowed"})
		return
	}
	if !s.authorizePasswordOrReject(w, r) {
		return
	}

	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	subID, subCh := s.subscribeEvents()
	defer s.unsubscribeEvents(subID)

	hello := map[string]any{
		"type":      "hello",
		"agent_id":  s.cfgSnapshot().AgentID,
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	}
	if err := conn.WriteJSON(hello); err != nil {
		return
	}

	_ = conn.SetReadDeadline(time.Now().Add(90 * time.Second))
	conn.SetPongHandler(func(string) error {
		_ = conn.SetReadDeadline(time.Now().Add(90 * time.Second))
		return nil
	})

	readDone := make(chan struct{})
	go func() {
		defer close(readDone)
		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				return
			}
		}
	}()

	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-readDone:
			return
		case msg, ok := <-subCh:
			if !ok {
				return
			}
			_ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			_ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (s *Server) subscribeEvents() (int, chan []byte) {
	s.eventsMu.Lock()
	defer s.eventsMu.Unlock()
	s.nextSubID++
	id := s.nextSubID
	ch := make(chan []byte, 16)
	s.eventSubs[id] = ch
	return id, ch
}

func (s *Server) unsubscribeEvents(id int) {
	s.eventsMu.Lock()
	defer s.eventsMu.Unlock()
	ch, ok := s.eventSubs[id]
	if !ok {
		return
	}
	delete(s.eventSubs, id)
	close(ch)
}

func (s *Server) publishEvent(eventType string, data any) {
	payload := map[string]any{
		"type":      eventType,
		"agent_id":  s.cfgSnapshot().AgentID,
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"data":      data,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return
	}

	s.eventsMu.Lock()
	defer s.eventsMu.Unlock()
	for _, ch := range s.eventSubs {
		select {
		case ch <- body:
		default:
		}
	}
}
