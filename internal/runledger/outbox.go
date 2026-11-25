package runledger

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"

	"github.com/google/uuid"
)

// Message kinds of the outbox.
const (
	KindAck      = "ack"
	KindInterim  = "interim"
	KindFinal    = "final"
	KindError    = "error"
	KindApproval = "approval"
	KindProgress = "progress"
)

var validKinds = map[string]bool{KindAck: true, KindInterim: true, KindFinal: true, KindError: true, KindApproval: true, KindProgress: true}

var whitespaceRun = regexp.MustCompile(`\s+`)

// ContentHash identifies a message by its text, whitespace aside: "aBc" and
// "ABC" are different messages, as a code or a key.
func ContentHash(content string) string {
	normalized := strings.TrimSpace(whitespaceRun.ReplaceAllString(content, " "))
	sum := sha256.Sum256([]byte(normalized))
	return hex.EncodeToString(sum[:])
}

// SlotForContent is the slot a message without a natural one takes.
func SlotForContent(content string) string { return ContentHash(content)[:32] }

// Entry is one agent_outbox row.
type Entry struct {
	ID, RunID, ScopeID, Channel, Recipient string
	MessageKind, Purpose, Slot             string
	Sequence                               int64
	ContentHash                            string
	Payload                                map[string]any
	Status, PlatformMessageID              string
	CreatedAt, DeliveredAt                 string
}

// Content is the message text of the entry.
func (e *Entry) Content() string {
	s, _ := e.Payload["content"].(string)
	return strings.TrimSpace(s)
}

// Metadata is the delivery metadata of the entry.
func (e *Entry) Metadata() map[string]any {
	m, _ := e.Payload["metadata"].(map[string]any)
	if m == nil {
		m = map[string]any{}
	}
	return m
}

const outboxColumns = `id, run_id, scope_id, channel, recipient, message_kind, purpose, slot, sequence, semantic_hash, payload_json, status, platform_message_id, created_at, delivered_at`

func scanEntry(row interface{ Scan(...any) error }) (*Entry, error) {
	var e Entry
	var scope, recipient, purpose, slot, hash, payload, platform, created, delivered sql.NullString
	var seq sql.NullInt64
	if err := row.Scan(&e.ID, &e.RunID, &scope, &e.Channel, &recipient, &e.MessageKind, &purpose, &slot, &seq, &hash, &payload, &e.Status, &platform, &created, &delivered); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	e.ScopeID = scope.String
	if e.ScopeID == "" {
		e.ScopeID = e.RunID
	}
	e.Recipient, e.Purpose, e.Slot, e.ContentHash = recipient.String, purpose.String, slot.String, hash.String
	e.Sequence = seq.Int64
	if e.Sequence == 0 {
		e.Sequence = 1
	}
	e.Payload = ParseObject(payload.String)
	e.PlatformMessageID, e.CreatedAt, e.DeliveredAt = platform.String, created.String, delivered.String
	return &e, nil
}

// Reservation asks for the one slot a message may use.
type Reservation struct {
	RunID, ScopeID, Channel, Recipient, MessageKind, Purpose, Slot string
	Content                                                        string
	Metadata                                                       map[string]any
}

// Reserve takes a message's slot. The unique index makes a second delivery of
// the same slot an impossible state, whichever path asks for it. fresh is false
// when the slot was already taken; a slot whose attempt was confirmed not
// delivered opens again.
func (l *Ledger) Reserve(ctx context.Context, r Reservation) (entry *Entry, fresh bool, err error) {
	if r.RunID == "" || r.Channel == "" || r.Purpose == "" || r.Slot == "" {
		return nil, false, errors.New("A delivery reservation needs runId, channel, purpose, and slot.")
	}
	if !validKinds[r.MessageKind] {
		return nil, false, fmt.Errorf("Unsupported message kind: %s", r.MessageKind)
	}
	if r.ScopeID == "" {
		r.ScopeID = r.RunID
	}
	metadata := r.Metadata
	if metadata == nil {
		metadata = map[string]any{}
	}
	payload, _ := json.Marshal(map[string]any{"content": r.Content, "metadata": metadata})
	tx, err := l.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, false, err
	}
	defer tx.Rollback()
	existing, err := scanEntry(tx.QueryRowContext(ctx, `SELECT `+outboxColumns+` FROM agent_outbox WHERE scope_id = ? AND COALESCE(recipient, '') = ? AND purpose = ? AND slot = ?`,
		r.ScopeID, r.Recipient, r.Purpose, r.Slot))
	if err != nil {
		return nil, false, err
	}
	if existing != nil && existing.Status != "failed" {
		return existing, false, nil
	}
	var id string
	if existing != nil {
		id = existing.ID
		if _, err := tx.ExecContext(ctx, `UPDATE agent_outbox SET status = 'pending', payload_json = ?, semantic_hash = ? WHERE id = ?`, string(payload), ContentHash(r.Content), id); err != nil {
			return nil, false, err
		}
	} else {
		id = uuid.NewString()
		var seq int64
		if err := tx.QueryRowContext(ctx, `SELECT COALESCE(MAX(sequence), 0) + 1 FROM agent_outbox WHERE run_id = ? AND channel = ? AND message_kind = ?`, r.RunID, r.Channel, r.MessageKind).Scan(&seq); err != nil {
			return nil, false, err
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO agent_outbox (id, run_id, scope_id, channel, recipient, message_kind, purpose, slot, sequence, semantic_hash, payload_json, status)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
			id, r.RunID, r.ScopeID, r.Channel, orNil(r.Recipient), r.MessageKind, r.Purpose, r.Slot, seq, ContentHash(r.Content), string(payload)); err != nil {
			return nil, false, err
		}
	}
	entry, err = scanEntry(tx.QueryRowContext(ctx, `SELECT `+outboxColumns+` FROM agent_outbox WHERE id = ?`, id))
	if err != nil {
		return nil, false, err
	}
	return entry, true, tx.Commit()
}

// FindDeliveredContent is an earlier send of the same text to this recipient in
// this scope, under any slot, that went out or may have.
func (l *Ledger) FindDeliveredContent(ctx context.Context, scopeID, recipient, content, excludeID string) (*Entry, error) {
	return scanEntry(l.DB.W.QueryRowContext(ctx, `SELECT `+outboxColumns+` FROM agent_outbox
		WHERE scope_id = ? AND COALESCE(recipient, '') = ? AND semantic_hash = ? AND status IN ('delivered', 'ambiguous') AND id != ? LIMIT 1`,
		scopeID, recipient, ContentHash(content), excludeID))
}

// MarkDelivered records a confirmed send.
func (l *Ledger) MarkDelivered(ctx context.Context, id, platformMessageID string) error {
	_, err := l.DB.W.ExecContext(ctx, `UPDATE agent_outbox SET status = 'delivered', platform_message_id = COALESCE(?, platform_message_id), delivered_at = datetime('now') WHERE id = ?`, orNil(platformMessageID), id)
	return err
}

// MarkSuppressed records a message that was deliberately not sent.
func (l *Ledger) MarkSuppressed(ctx context.Context, id string) error {
	_, err := l.DB.W.ExecContext(ctx, `UPDATE agent_outbox SET status = 'suppressed' WHERE id = ?`, id)
	return err
}

// MarkFailed records a failed send; an ambiguous one may have reached the user.
func (l *Ledger) MarkFailed(ctx context.Context, id string, ambiguous bool) error {
	status := "failed"
	if ambiguous {
		status = "ambiguous"
	}
	_, err := l.DB.W.ExecContext(ctx, `UPDATE agent_outbox SET status = ? WHERE id = ?`, status, id)
	return err
}

// RecordAttempt logs one delivery attempt.
func (l *Ledger) RecordAttempt(ctx context.Context, outboxID, status, platformMessageID, errText string) error {
	tx, err := l.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var runID string
	if err := tx.QueryRowContext(ctx, `SELECT run_id FROM agent_outbox WHERE id = ?`, outboxID).Scan(&runID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil
		}
		return err
	}
	var attempt int64
	if err := tx.QueryRowContext(ctx, `SELECT COALESCE(MAX(attempt_no), 0) + 1 FROM agent_delivery_attempts WHERE outbox_id = ?`, outboxID).Scan(&attempt); err != nil {
		return err
	}
	if len(errText) > 2000 {
		errText = errText[:2000]
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO agent_delivery_attempts (id, outbox_id, run_id, attempt_no, status, platform_message_id, error) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		uuid.NewString(), outboxID, runID, attempt, status, orNil(platformMessageID), orNil(errText)); err != nil {
		return err
	}
	return tx.Commit()
}

// EntriesForRun lists a run's outbox in creation order.
func (l *Ledger) EntriesForRun(ctx context.Context, runID string) ([]*Entry, error) {
	rows, err := l.DB.W.QueryContext(ctx, `SELECT `+outboxColumns+` FROM agent_outbox WHERE run_id = ? ORDER BY created_at ASC`, runID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*Entry
	for rows.Next() {
		e, err := scanEntry(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// SettleOrphanedReservations resolves what a crash left pending: a final answer
// whose claim never landed certainly was not sent (the claim comes before the
// send); anything else stays unknown and is never sent again.
func (l *Ledger) SettleOrphanedReservations(ctx context.Context, runID string) error {
	var claimed sql.NullString
	_ = l.DB.W.QueryRowContext(ctx, `SELECT final_delivery_id FROM agent_runs WHERE id = ?`, runID).Scan(&claimed)
	if _, err := l.DB.W.ExecContext(ctx, `UPDATE agent_outbox SET status = 'failed' WHERE run_id = ? AND status = 'pending' AND message_kind = 'final' AND id != ?`, runID, claimed.String); err != nil {
		return err
	}
	_, err := l.DB.W.ExecContext(ctx, `UPDATE agent_outbox SET status = 'ambiguous' WHERE run_id = ? AND status = 'pending'`, runID)
	return err
}
