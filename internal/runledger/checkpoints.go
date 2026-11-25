package runledger

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"

	"github.com/google/uuid"
)

// Checkpoint is a saved point of a run's progress.
type Checkpoint struct {
	ID, RunID, Phase string
	Version          int64
	State            map[string]any
	CreatedAt        string
}

// SaveCheckpoint records a checkpoint and keeps the single-row legacy table the
// older UI reads in step.
func (l *Ledger) SaveCheckpoint(ctx context.Context, runID, phase string, state map[string]any, userID int64, agentID string) (*Checkpoint, error) {
	if phase == "" {
		phase = "checkpoint"
	}
	payload := map[string]any{}
	for k, v := range state {
		payload[k] = v
	}
	payload["savedAt"] = ISO(l.now())
	encoded, _ := json.Marshal(payload)
	tx, err := l.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	var version int64
	if err := tx.QueryRowContext(ctx, `SELECT COALESCE(MAX(version), 0) + 1 FROM agent_runtime_checkpoints WHERE run_id = ?`, runID).Scan(&version); err != nil {
		return nil, err
	}
	id := uuid.NewString()
	if _, err := tx.ExecContext(ctx, `INSERT INTO agent_runtime_checkpoints (id, run_id, version, phase, state_json) VALUES (?, ?, ?, ?, ?)`,
		id, runID, version, phase, string(encoded)); err != nil {
		return nil, err
	}
	_, _ = tx.ExecContext(ctx, `INSERT INTO agent_run_checkpoints (run_id, version, phase, state_json) VALUES (?, ?, ?, ?)
		ON CONFLICT(run_id) DO UPDATE SET version = excluded.version, phase = excluded.phase, state_json = excluded.state_json, updated_at = datetime('now')`,
		runID, version, phase, string(encoded))
	if userID != 0 {
		if _, err := appendEvent(ctx, tx, l.now(), Event{RunID: runID, UserID: userID, AgentID: agentID, Type: EventCheckpointCreated,
			Payload: map[string]any{"kind": "run", "checkpoint_id": id, "version": version, "phase": phase}}); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return &Checkpoint{ID: id, RunID: runID, Version: version, Phase: phase, State: payload}, nil
}

// LatestCheckpoint is a run's newest checkpoint, or nil.
func (l *Ledger) LatestCheckpoint(ctx context.Context, runID string) (*Checkpoint, error) {
	var c Checkpoint
	var state, created sql.NullString
	err := l.DB.R.QueryRowContext(ctx, `SELECT id, run_id, version, phase, state_json, created_at FROM agent_runtime_checkpoints WHERE run_id = ? ORDER BY version DESC LIMIT 1`, runID).
		Scan(&c.ID, &c.RunID, &c.Version, &c.Phase, &state, &created)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	c.State, c.CreatedAt = ParseObject(state.String), created.String
	return &c, nil
}
