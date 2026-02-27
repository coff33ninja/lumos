package main

import "time"

const maxAuditEntries = 200

func (s *Server) recordAudit(source, action, target, mac string, success bool, message string, remote string) {
	entry := AuditEntry{
		Timestamp: time.Now().UTC(),
		Source:    source,
		Action:    action,
		Target:    target,
		MAC:       mac,
		Success:   success,
		Message:   message,
		RemoteIP:  remote,
	}

	s.auditMu.Lock()
	s.auditTrail = append(s.auditTrail, entry)
	if len(s.auditTrail) > maxAuditEntries {
		s.auditTrail = append([]AuditEntry(nil), s.auditTrail[len(s.auditTrail)-maxAuditEntries:]...)
	}
	s.auditMu.Unlock()

	s.publishEvent("audit", entry)
}

func (s *Server) listAudit(limit int) []AuditEntry {
	s.auditMu.Lock()
	defer s.auditMu.Unlock()

	if limit <= 0 || limit > len(s.auditTrail) {
		limit = len(s.auditTrail)
	}

	out := make([]AuditEntry, 0, limit)
	for i := len(s.auditTrail) - 1; i >= 0 && len(out) < limit; i-- {
		out = append(out, s.auditTrail[i])
	}
	return out
}
