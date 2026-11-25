package messaging

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
)

// The durable inbound queue: every message is stored with a job row before it
// is handled, so a restart replays what no agent run had started on. Port of
// inbound_store.js.

const maxInboundPayloadBytes = 1024 * 1024

// ErrPayloadTooLarge is returned for a payload above the durability limit.
var ErrPayloadTooLarge = errors.New("Inbound messaging payload exceeds the 1 MiB durability limit.")

// Job is one row of messaging_inbound_jobs.
type Job struct {
	ID             string
	MessageID      int64
	UserID         int64
	AgentID        string
	Platform       string
	PlatformMsgID  string
	PlatformChatID string
	PayloadJSON    string
	Status         string
	Attempts       int
	RunID          string
	LastError      string
}

const jobColumns = `id, message_id, user_id, COALESCE(agent_id, ''), platform, COALESCE(platform_msg_id, ''),
	COALESCE(platform_chat_id, ''), payload_json, status, attempts, COALESCE(run_id, ''), COALESCE(last_error, '')`

type scanner interface{ Scan(dest ...any) error }

func scanJob(row scanner) (*Job, error) {
	var j Job
	err := row.Scan(&j.ID, &j.MessageID, &j.UserID, &j.AgentID, &j.Platform, &j.PlatformMsgID, &j.PlatformChatID,
		&j.PayloadJSON, &j.Status, &j.Attempts, &j.RunID, &j.LastError)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &j, err
}

// Payload is the stored message, or nil when it cannot be read.
func (j *Job) Payload() *Message {
	if j == nil {
		return nil
	}
	var m Message
	if json.Unmarshal([]byte(j.PayloadJSON), &m) != nil || strings.TrimSpace(j.PayloadJSON) == "null" {
		return nil
	}
	return &m
}

func newUUID() (string, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:]), nil
}

func (s *Store) jobBy(ctx context.Context, column string, value any) (*Job, error) {
	return scanJob(s.DB.W.QueryRowContext(ctx, `SELECT `+jobColumns+` FROM messaging_inbound_jobs WHERE `+column+` = ?`, value))
}

// Job reads a job by id; nil when there is none.
func (s *Store) Job(ctx context.Context, id string) (*Job, error) { return s.jobBy(ctx, "id", id) }

// Enqueued is the result of storing an inbound message.
type Enqueued struct {
	// Created is false for a message already stored (a platform redelivery).
	Created bool
	Job     *Job
	Payload *Message
}

// EnqueueInbound stores an inbound message and its job in one transaction. A
// message the platform already delivered returns the existing job.
func (s *Store) EnqueueInbound(ctx context.Context, userID int64, agentID string, msg Message, metadata map[string]any) (Enqueued, error) {
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return Enqueued{}, err
	}
	defer tx.Rollback()

	platformMsgID := string(msg.MessageID)
	if platformMsgID != "" {
		var existing int64
		err := tx.QueryRowContext(ctx, `SELECT id FROM messages
			WHERE user_id = ? AND platform = ? AND platform_msg_id = ? AND role = 'user' LIMIT 1`, userID, msg.Platform, platformMsgID).Scan(&existing)
		if err == nil {
			job, err := scanJob(tx.QueryRowContext(ctx, `SELECT `+jobColumns+` FROM messaging_inbound_jobs WHERE message_id = ?`, existing))
			return Enqueued{Job: job}, err
		}
		if !errors.Is(err, sql.ErrNoRows) {
			return Enqueued{}, err
		}
	}

	jobID, err := newUUID()
	if err != nil {
		return Enqueued{}, err
	}
	msg.InboundJobID, msg.InboundJobIDs = jobID, []string{jobID}
	payload, err := json.Marshal(msg)
	if err != nil {
		return Enqueued{}, err
	}
	if len(payload) > maxInboundPayloadBytes {
		return Enqueued{}, ErrPayloadTooLarge
	}
	var metadataJSON any
	if metadata != nil {
		raw, err := json.Marshal(metadata)
		if err != nil {
			return Enqueued{}, err
		}
		metadataJSON = string(raw)
	}
	var msgID any
	if platformMsgID != "" {
		msgID = platformMsgID
	}
	res, err := tx.ExecContext(ctx, `INSERT INTO messages (
		user_id, agent_id, role, content, platform, platform_msg_id, platform_chat_id, metadata, created_at
	) VALUES (?, ?, 'user', ?, ?, ?, ?, ?, ?)`, userID, agentID, msg.Content, msg.Platform, msgID, msg.ChatID, metadataJSON, msg.Timestamp)
	if err != nil {
		return Enqueued{}, err
	}
	messageID, err := res.LastInsertId()
	if err != nil {
		return Enqueued{}, err
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO messaging_inbound_jobs (
		id, message_id, user_id, agent_id, platform, platform_msg_id, platform_chat_id, payload_json, status
	) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')`, jobID, messageID, userID, agentID, msg.Platform, msgID, msg.ChatID, string(payload)); err != nil {
		return Enqueued{}, err
	}
	job, err := scanJob(tx.QueryRowContext(ctx, `SELECT `+jobColumns+` FROM messaging_inbound_jobs WHERE message_id = ?`, messageID))
	if err != nil {
		return Enqueued{}, err
	}
	if err := tx.Commit(); err != nil {
		return Enqueued{}, err
	}
	return Enqueued{Created: true, Job: job, Payload: &msg}, nil
}

// ClaimJob moves a pending job to processing; false when someone else has it.
func (s *Store) ClaimJob(ctx context.Context, id string) (bool, error) {
	res, err := s.DB.W.ExecContext(ctx, `UPDATE messaging_inbound_jobs
		SET status = 'processing', attempts = attempts + 1, last_error = NULL, updated_at = datetime('now')
		WHERE id = ? AND status = 'pending'`, id)
	return changed(res, err)
}

func changed(res sql.Result, err error) (bool, error) {
	if err != nil {
		return false, err
	}
	n, err := res.RowsAffected()
	return n == 1, err
}

// SettleJob records how a job ended: completed, failed, or pending again.
func (s *Store) SettleJob(ctx context.Context, id, status, failure string) error {
	if status != "pending" && status != "completed" && status != "failed" {
		return fmt.Errorf("Invalid inbound messaging job status: %s", status)
	}
	if len(failure) > 4000 {
		failure = failure[:4000]
	}
	var lastError any
	if failure != "" {
		lastError = failure
	}
	_, err := s.DB.W.ExecContext(ctx, `UPDATE messaging_inbound_jobs
		SET status = ?, last_error = ?,
		    completed_at = CASE WHEN ? IN ('completed', 'failed') THEN datetime('now') ELSE NULL END,
		    updated_at = datetime('now')
		WHERE id = ?`, status, lastError, status, id)
	return err
}

func uniqueIDs(ids []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, id := range ids {
		if id = strings.TrimSpace(id); id != "" && !seen[id] {
			seen[id] = true
			out = append(out, id)
		}
	}
	return out
}

// AttachRunToJobs records the agent run that handles processing jobs.
func (s *Store) AttachRunToJobs(ctx context.Context, jobIDs []string, runID string) (int, error) {
	ids := uniqueIDs(jobIDs)
	if len(ids) == 0 || runID == "" {
		return 0, nil
	}
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()
	count := 0
	for _, id := range ids {
		res, err := tx.ExecContext(ctx, `UPDATE messaging_inbound_jobs SET run_id = ?, updated_at = datetime('now')
			WHERE id = ? AND status = 'processing'`, runID, id)
		if err != nil {
			return 0, err
		}
		n, _ := res.RowsAffected()
		count += int(n)
	}
	return count, tx.Commit()
}

// AnnotateJobs merges annotation into the metadata of the jobs' messages.
func (s *Store) AnnotateJobs(ctx context.Context, jobIDs []string, annotation map[string]any) (int, error) {
	ids := uniqueIDs(jobIDs)
	if len(ids) == 0 {
		return 0, nil
	}
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()
	count := 0
	for _, id := range ids {
		var messageID int64
		var metadata sql.NullString
		err := tx.QueryRowContext(ctx, `SELECT messages.id, messages.metadata FROM messaging_inbound_jobs
			JOIN messages ON messages.id = messaging_inbound_jobs.message_id
			WHERE messaging_inbound_jobs.id = ?`, id).Scan(&messageID, &metadata)
		if errors.Is(err, sql.ErrNoRows) {
			continue
		}
		if err != nil {
			return 0, err
		}
		merged := map[string]any{}
		if metadata.Valid && metadata.String != "" {
			if json.Unmarshal([]byte(metadata.String), &merged) != nil || merged == nil {
				merged = map[string]any{}
			}
		}
		for k, v := range annotation {
			merged[k] = v
		}
		raw, err := json.Marshal(merged)
		if err != nil {
			return 0, err
		}
		if _, err := tx.ExecContext(ctx, `UPDATE messages SET metadata = ? WHERE id = ?`, string(raw), messageID); err != nil {
			return 0, err
		}
		count++
	}
	return count, tx.Commit()
}

// Reconciled counts what ReconcileInterruptedJobs settled.
type Reconciled struct{ Completed, Failed, Pending int64 }

// ReconcileInterruptedJobs settles jobs a restart left in processing: done when
// their run completed, failed when a run began but did not finish, pending when
// no run ever started.
func (s *Store) ReconcileInterruptedJobs(ctx context.Context) (Reconciled, error) {
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return Reconciled{}, err
	}
	defer tx.Rollback()
	var out Reconciled
	for _, step := range []struct {
		target *int64
		query  string
	}{
		{&out.Completed, `UPDATE messaging_inbound_jobs
			SET status = 'completed', completed_at = datetime('now'), updated_at = datetime('now')
			WHERE status = 'processing' AND run_id IN (SELECT id FROM agent_runs WHERE status = 'completed')`},
		{&out.Failed, `UPDATE messaging_inbound_jobs
			SET status = 'failed',
			    last_error = COALESCE(last_error, 'The server restarted after this agent run began; it will not be replayed automatically.'),
			    completed_at = datetime('now'), updated_at = datetime('now')
			WHERE status = 'processing' AND run_id IN (SELECT id FROM agent_runs)`},
		{&out.Pending, `UPDATE messaging_inbound_jobs
			SET status = 'pending', last_error = NULL, updated_at = datetime('now')
			WHERE status = 'processing' AND (run_id IS NULL OR run_id NOT IN (SELECT id FROM agent_runs))`},
	} {
		res, err := tx.ExecContext(ctx, step.query)
		if err != nil {
			return Reconciled{}, err
		}
		*step.target, _ = res.RowsAffected()
	}
	return out, tx.Commit()
}

// RequeueReplayableJob makes a job pending again when no run ever started on
// it; false otherwise.
func (s *Store) RequeueReplayableJob(ctx context.Context, id string) (bool, error) {
	res, err := s.DB.W.ExecContext(ctx, `UPDATE messaging_inbound_jobs
		SET status = 'pending', last_error = NULL, completed_at = NULL, updated_at = datetime('now')
		WHERE id = ? AND run_id IS NULL AND status IN ('processing', 'failed')`, id)
	return changed(res, err)
}

// JobFilter narrows the jobs to list; nil fields match everything.
type JobFilter struct {
	UserID   *int64
	AgentID  *string
	Platform *string
	Limit    int
}

func (f JobFilter) scope(first ...string) (string, []any, int) {
	clauses := append([]string{}, first...)
	var values []any
	if f.UserID != nil {
		clauses, values = append(clauses, "user_id = ?"), append(values, *f.UserID)
	}
	if f.AgentID != nil {
		clauses, values = append(clauses, "agent_id = ?"), append(values, *f.AgentID)
	}
	if f.Platform != nil {
		clauses, values = append(clauses, "platform = ?"), append(values, *f.Platform)
	}
	limit := f.Limit
	if limit <= 0 {
		limit = 100
	}
	return strings.Join(clauses, " AND "), values, min(limit, 500)
}

func (s *Store) listJobs(ctx context.Context, f JobFilter, first ...string) ([]*Job, error) {
	where, values, limit := f.scope(first...)
	rows, err := s.DB.W.QueryContext(ctx, `SELECT `+jobColumns+` FROM messaging_inbound_jobs
		WHERE `+where+` ORDER BY created_at ASC, id ASC LIMIT ?`, append(values, limit)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var jobs []*Job
	for rows.Next() {
		job, err := scanJob(rows)
		if err != nil {
			return nil, err
		}
		jobs = append(jobs, job)
	}
	return jobs, rows.Err()
}

// PendingJobs lists jobs waiting to be handled, oldest first.
func (s *Store) PendingJobs(ctx context.Context, f JobFilter) ([]*Job, error) {
	return s.listJobs(ctx, f, "status = 'pending'")
}

// AbandonedProcessingJobs lists jobs marked processing that no run ever started.
func (s *Store) AbandonedProcessingJobs(ctx context.Context, f JobFilter) ([]*Job, error) {
	return s.listJobs(ctx, f, "status = 'processing'", "run_id IS NULL")
}
