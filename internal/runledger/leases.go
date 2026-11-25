package runledger

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

// Lease is a worker's claim on a run.
type Lease struct {
	RunID, WorkerID, ExpiresAt, HeartbeatAt string
}

func leaseFor(lease time.Duration) time.Duration {
	if lease <= 0 {
		lease = DefaultLease
	}
	if lease < time.Second {
		lease = time.Second
	}
	return lease
}

// Acquire claims a run for a worker; nil when another worker's lease is live.
func (l *Ledger) Acquire(ctx context.Context, runID, workerID string, lease time.Duration) (*Lease, error) {
	if runID == "" || workerID == "" {
		return nil, nil
	}
	now := l.now()
	expires := ISO(now.Add(leaseFor(lease)))
	heartbeat := ISO(now)
	tx, err := l.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	var owner, expiresAt sql.NullString
	err = tx.QueryRowContext(ctx, `SELECT lease_owner, lease_expires_at FROM agent_runs WHERE id = ?`, runID).Scan(&owner, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if owner.String != "" && owner.String != workerID {
		if t, ok := parseISO(expiresAt.String); ok && t.After(now) {
			return nil, nil
		}
	}
	if _, err := tx.ExecContext(ctx, `UPDATE agent_runs SET lease_owner = ?, lease_expires_at = ?, heartbeat_at = ?, updated_at = datetime('now') WHERE id = ?`,
		workerID, expires, heartbeat, runID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return &Lease{RunID: runID, WorkerID: workerID, ExpiresAt: expires, HeartbeatAt: heartbeat}, nil
}

// Heartbeat extends a worker's lease.
func (l *Ledger) Heartbeat(ctx context.Context, runID, workerID string) bool {
	if runID == "" || workerID == "" {
		return false
	}
	now := l.now()
	res, err := l.DB.W.ExecContext(ctx, `UPDATE agent_runs SET lease_expires_at = ?, heartbeat_at = ?, updated_at = datetime('now') WHERE id = ? AND lease_owner = ?`,
		ISO(now.Add(DefaultLease)), ISO(now), runID, workerID)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

// Release gives a worker's lease up.
func (l *Ledger) Release(ctx context.Context, runID, workerID string) bool {
	if runID == "" || workerID == "" {
		return false
	}
	res, err := l.DB.W.ExecContext(ctx, `UPDATE agent_runs SET lease_owner = NULL, lease_expires_at = NULL, updated_at = datetime('now') WHERE id = ? AND lease_owner = ?`, runID, workerID)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

// ExpireDeadLeases frees the leases of workers that stopped heartbeating.
func (l *Ledger) ExpireDeadLeases(ctx context.Context, olderThan time.Duration) (int64, error) {
	if olderThan <= 0 {
		olderThan = DefaultLease
	}
	res, err := l.DB.W.ExecContext(ctx, `UPDATE agent_runs
		SET lease_owner = NULL, lease_expires_at = NULL, updated_at = datetime('now')
		WHERE lease_owner IS NOT NULL
		  AND (lease_expires_at IS NULL OR lease_expires_at < datetime('now') OR heartbeat_at < ?)
		  AND runtime_state NOT IN ('completed', 'cancelled', 'failed')`, ISO(l.now().Add(-olderThan)))
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}
