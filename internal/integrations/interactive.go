package integrations

import (
	"context"
	"errors"
)

// DisconnectPreparer fences a connection before it is revoked: the Manager
// marks it "disconnecting" first, so queued calls stop using it.
type DisconnectPreparer interface {
	BeforeDisconnect(ctx context.Context, conn Connection) error
}

// ServiceAccessProvider lets the person choose which services of a connected
// account the agent may reach (Tailscale peers).
type ServiceAccessProvider interface {
	ServiceAccess(ctx context.Context, scope Scope, connectionID string) (any, error)
	SetServiceAccess(ctx context.Context, scope Scope, connectionID string, services any) (any, error)
}

// Shutdowner releases what a provider keeps running (sockets, sessions).
type Shutdowner interface {
	Shutdown(ctx context.Context) error
}

// prepareDisconnect fences the connection when the provider asks for it.
func (m *Manager) prepareDisconnect(ctx context.Context, p Provider, conn Connection, userID int64, agentID string) error {
	prep, ok := p.(DisconnectPreparer)
	if !ok {
		return nil
	}
	if _, err := m.svc.DB.W.ExecContext(ctx, `UPDATE integration_connections SET status = 'disconnecting' WHERE id = ? AND user_id = ? AND agent_id = ?`, conn.ID, userID, agentID); err != nil {
		return err
	}
	return prep.BeforeDisconnect(ctx, conn)
}

// LockConnection serialises work on one connection with its tool calls.
func (m *Manager) LockConnection(ctx context.Context, conn Connection) (func(), error) {
	return m.locks.acquire(ctx, lockKey(conn))
}

// Shutdown stops every provider that keeps something running.
func (m *Manager) Shutdown(ctx context.Context) {
	for _, p := range m.providers {
		if s, ok := p.(Shutdowner); ok {
			if err := s.Shutdown(ctx); err != nil {
				m.log.Warn("integration shutdown failed", "provider", p.Info().Key, "error", err)
			}
		}
	}
}

var errNoServices = errors.New("Service access is not supported.")
