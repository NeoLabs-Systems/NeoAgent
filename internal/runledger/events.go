package runledger

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

// The ledger's whole vocabulary. A new kind of event has to answer a question
// the Runs tab or an eval cannot answer from these.
const (
	EventRunStarted         = "run.started"
	EventRunState           = "run.state"
	EventRunCompleted       = "run.completed"
	EventRunFailed          = "run.failed"
	EventRunCancelled       = "run.cancelled"
	EventContextBuilt       = "context.built"
	EventContextCompacted   = "context.compacted"
	EventMemoryRecall       = "memory.recall"
	EventMemoryWrite        = "memory.write"
	EventModelRequest       = "model.request"
	EventModelResponse      = "model.response"
	EventToolsSelected      = "tools.selected"
	EventToolCall           = "tool.call"
	EventToolResult         = "tool.result"
	EventToolSuppressed     = "tool.suppressed"
	EventPermissionDecision = "permission.decision"
	EventWorkspaceChanged   = "workspace.changed"
	EventCheckpointCreated  = "checkpoint.created"
	EventCheckpointRestored = "checkpoint.restored"
	EventDeliveryReserved   = "delivery.reserved"
	EventDeliverySent       = "delivery.sent"
	EventDeliveryFailed     = "delivery.failed"
	EventDeliverySuppressed = "delivery.suppressed"
	EventRecoveryTriggered  = "recovery.triggered"
	EventAgentTask          = "agent.task"
	EventAgentCreated       = "agent.created"
)

const eventSchemaVersion = 1

// Event is one ledger entry to append. Payloads carry metadata only: raw
// prompts, tool results and memory text live in the run's captures.
type Event struct {
	RunID         string
	UserID        int64
	AgentID       string
	Type          string
	Payload       map[string]any
	Actor         string
	ParentEventID string
	RequestID     string
	StepID        string
}

// Stored is an appended event as listEvents returns it.
type Stored struct {
	ID            int64          `json:"id"`
	RunID         string         `json:"runId"`
	UserID        int64          `json:"userId"`
	AgentID       any            `json:"agentId"`
	EventType     string         `json:"eventType"`
	RequestID     any            `json:"requestId"`
	StepID        any            `json:"stepId"`
	SequenceIndex int64          `json:"sequenceIndex"`
	Payload       map[string]any `json:"payload"`
	CreatedAt     any            `json:"createdAt"`
	EventID       string         `json:"-"`
}

// ArgsDigest is a short digest of tool arguments, never their content.
func ArgsDigest(args any) string {
	if args == nil {
		args = map[string]any{}
	}
	sum := sha256.Sum256([]byte(dyn.Stringify(args)))
	return "sha256:" + hex.EncodeToString(sum[:])[:32]
}

// RedactArgs is what the ledger keeps of tool arguments: names and values may
// both contain user content.
func RedactArgs(args map[string]any) map[string]any {
	return map[string]any{"count": len(args), "digest": ArgsDigest(args)}
}

// RedactPayload is the last-boundary protection for error bodies echoed by
// tools and providers: arbitrary exception text never reaches the ledger.
func RedactPayload(value any) any {
	switch v := value.(type) {
	case []any:
		out := make([]any, len(v))
		for i, item := range v {
			out[i] = RedactPayload(item)
		}
		return out
	case map[string]any:
		out := make(map[string]any, len(v))
		for key, item := range v {
			switch key {
			case "args_redacted":
				m := dyn.Obj(item)
				count, _ := dyn.Float(m["count"])
				digest := m["digest"]
				if dyn.Str(digest) == "" {
					digest = ArgsDigest(item)
				}
				out[key] = map[string]any{"count": count, "digest": digest}
			case "error":
				if dyn.Truthy(item) {
					out[key] = map[string]any{"present": true}
				} else {
					out[key] = nil
				}
			default:
				out[key] = RedactPayload(item)
			}
		}
		return out
	}
	return value
}

type execQueryer interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

func orNil(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func appendEvent(ctx context.Context, q execQueryer, now time.Time, e Event) (*Stored, error) {
	if e.RunID == "" || e.UserID == 0 || e.Type == "" {
		return nil, nil
	}
	eventID := uuid.NewString()
	envelope := map[string]any{}
	if e.Payload != nil {
		envelope = RedactPayload(e.Payload).(map[string]any)
	}
	envelope["schema_version"] = eventSchemaVersion
	envelope["event_id"] = eventID
	envelope["parent_event_id"] = orNil(e.ParentEventID)
	envelope["timestamp"] = ISO(now)
	envelope["actor"] = orNil(e.Actor)
	encoded, err := json.Marshal(envelope)
	if err != nil {
		return nil, err
	}
	var next int64
	if err := q.QueryRowContext(ctx, `SELECT COALESCE(MAX(sequence_index), 0) + 1 FROM agent_run_events WHERE run_id = ?`, e.RunID).Scan(&next); err != nil {
		return nil, err
	}
	res, err := q.ExecContext(ctx, `INSERT INTO agent_run_events (run_id, user_id, agent_id, event_type, request_id, step_id, sequence_index, payload_json)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, e.RunID, e.UserID, orNil(e.AgentID), e.Type, orNil(e.RequestID), orNil(e.StepID), next, string(encoded))
	if err != nil {
		return nil, err
	}
	id, _ := res.LastInsertId()
	var payload map[string]any
	_ = json.Unmarshal(encoded, &payload)
	return &Stored{ID: id, RunID: e.RunID, UserID: e.UserID, AgentID: orNil(e.AgentID), EventType: e.Type, RequestID: orNil(e.RequestID),
		StepID: orNil(e.StepID), SequenceIndex: next, Payload: payload, CreatedAt: now.UTC().Format("2006-01-02 15:04:05"), EventID: eventID}, nil
}

// Append adds an event to the ledger.
func (l *Ledger) Append(ctx context.Context, e Event) (*Stored, error) {
	tx, err := l.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	stored, err := appendEvent(ctx, tx, l.now(), e)
	if err != nil {
		return nil, err
	}
	return stored, tx.Commit()
}

// Record appends an event; telemetry never takes a run down, so a failed write
// costs only that event.
func (l *Ledger) Record(e Event) *Stored {
	stored, err := l.Append(context.Background(), e)
	if err != nil {
		l.log().Warn("Could not record run event", "event", e.Type, "error", err)
		return nil
	}
	return stored
}

// List returns a run's events in order.
func (l *Ledger) List(ctx context.Context, runID string, afterSequence int64, limit int) ([]Stored, error) {
	if runID == "" {
		return []Stored{}, nil
	}
	if limit <= 0 || limit > 20000 {
		limit = 5000
	}
	rows, err := l.DB.R.QueryContext(ctx, `SELECT id, run_id, user_id, agent_id, event_type, request_id, step_id, sequence_index, payload_json, created_at
		FROM agent_run_events WHERE run_id = ? AND sequence_index > ? ORDER BY sequence_index ASC, id ASC LIMIT ?`, runID, afterSequence, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Stored{}
	for rows.Next() {
		var s Stored
		var agent, request, step, payload, created sql.NullString
		var seq sql.NullInt64
		if err := rows.Scan(&s.ID, &s.RunID, &s.UserID, &agent, &s.EventType, &request, &step, &seq, &payload, &created); err != nil {
			return nil, err
		}
		s.AgentID, s.RequestID, s.StepID = orNil(agent.String), orNil(request.String), orNil(step.String)
		s.SequenceIndex, s.Payload, s.CreatedAt = seq.Int64, ParseObject(payload.String), created.String
		out = append(out, s)
	}
	return out, rows.Err()
}
