package tasks

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// taskRow is a stored scheduled task. The last_run_* members come from the
// agent run the list query joins in.
type taskRow struct {
	ID                     int64
	UserID                 int64
	AgentID                sql.NullString
	Name                   string
	TriggerType            sql.NullString
	TriggerConfig          sql.NullString
	CronExpression         sql.NullString
	RunAt                  sql.NullString
	OneTime                sql.NullInt64
	TaskType               sql.NullString
	TaskConfig             sql.NullString
	Enabled                bool
	LastRun                sql.NullString
	LastTriggeredAt        sql.NullString
	LastTriggerFingerprint sql.NullString
	LatestRunID            sql.NullString
	LatestRunStatus        sql.NullString
	LatestRunError         sql.NullString
	LatestRunStartedAt     sql.NullString
}

const taskColumns = `scheduled_tasks.id, scheduled_tasks.user_id, scheduled_tasks.agent_id, scheduled_tasks.name,
  scheduled_tasks.trigger_type, scheduled_tasks.trigger_config, scheduled_tasks.cron_expression, scheduled_tasks.run_at,
  scheduled_tasks.one_time, scheduled_tasks.task_type, scheduled_tasks.task_config, scheduled_tasks.enabled,
  scheduled_tasks.last_run, scheduled_tasks.last_triggered_at, scheduled_tasks.last_trigger_fingerprint`

type scanner interface{ Scan(dest ...any) error }

func scanTask(row scanner, withLatestRun bool) (taskRow, error) {
	var t taskRow
	var enabled sql.NullInt64
	dest := []any{&t.ID, &t.UserID, &t.AgentID, &t.Name, &t.TriggerType, &t.TriggerConfig, &t.CronExpression, &t.RunAt,
		&t.OneTime, &t.TaskType, &t.TaskConfig, &enabled, &t.LastRun, &t.LastTriggeredAt, &t.LastTriggerFingerprint}
	if withLatestRun {
		dest = append(dest, &t.LatestRunID, &t.LatestRunStatus, &t.LatestRunError, &t.LatestRunStartedAt)
	}
	err := row.Scan(dest...)
	t.Enabled = enabled.Int64 != 0
	return t, err
}

// normalizedTask is a task as it is stored.
type normalizedTask struct {
	AgentID       string
	Name          string
	TriggerType   string
	TriggerConfig *jsv.Object
	TaskType      string
	TaskConfig    *jsv.Object
	Enabled       bool
	// The schedule trigger also keeps its time in the table's legacy columns.
	LegacyCron    any
	LegacyRunAt   any
	LegacyOneTime bool
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// repository reads and writes scheduled tasks and the run history around them.
type repository struct{ db *dbx.DB }

func (r repository) create(ctx context.Context, userID int64, t normalizedTask) (int64, error) {
	res, err := r.db.W.ExecContext(ctx, `INSERT INTO scheduled_tasks (
        user_id, agent_id, name, trigger_type, trigger_config, cron_expression, run_at, one_time,
        execution_mode, task_type, task_config, enabled
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		userID, t.AgentID, t.Name, t.TriggerType, jsv.Stringify(t.TriggerConfig), t.LegacyCron, t.LegacyRunAt, boolInt(t.LegacyOneTime),
		"prompt", t.TaskType, jsv.Stringify(t.TaskConfig), boolInt(t.Enabled))
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (r repository) update(ctx context.Context, taskID, userID int64, t normalizedTask) error {
	config := jsv.Stringify(t.TriggerConfig)
	_, err := r.db.W.ExecContext(ctx, `UPDATE scheduled_tasks
       SET last_trigger_fingerprint = CASE
             WHEN trigger_type = ? AND trigger_config = ? THEN last_trigger_fingerprint
             ELSE NULL
           END,
           agent_id = ?, name = ?, trigger_type = ?, trigger_config = ?, cron_expression = ?, run_at = ?,
           one_time = ?, execution_mode = ?, task_type = ?, task_config = ?, enabled = ?
       WHERE id = ? AND user_id = ?`,
		t.TriggerType, config, t.AgentID, t.Name, t.TriggerType, config, t.LegacyCron, t.LegacyRunAt,
		boolInt(t.LegacyOneTime), "prompt", t.TaskType, jsv.Stringify(t.TaskConfig), boolInt(t.Enabled), taskID, userID)
	return err
}

func (r repository) delete(ctx context.Context, taskID, userID int64) error {
	_, err := r.db.W.ExecContext(ctx, `DELETE FROM scheduled_tasks WHERE id = ? AND user_id = ?`, taskID, userID)
	return err
}

// get returns the task, or nil when the user has none with that id.
func (r repository) get(ctx context.Context, taskID, userID int64) (*taskRow, error) {
	t, err := scanTask(r.db.W.QueryRowContext(ctx, `SELECT `+taskColumns+` FROM scheduled_tasks WHERE id = ? AND user_id = ?`, taskID, userID), false)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &t, err
}

const latestRunJoin = `
      SELECT
        ` + taskColumns + `,
        latest_run.id AS last_run_id,
        latest_run.status AS last_run_status,
        latest_run.error AS last_run_error,
        latest_run.created_at AS last_run_started_at
      FROM scheduled_tasks
      LEFT JOIN agent_runs AS latest_run ON latest_run.id = (
        SELECT candidate.id
        FROM agent_runs AS candidate
        WHERE candidate.user_id = scheduled_tasks.user_id
          AND json_valid(candidate.metadata_json)
          AND CAST(json_extract(candidate.metadata_json, '$.taskId') AS TEXT) = CAST(scheduled_tasks.id AS TEXT)
        ORDER BY candidate.created_at DESC, candidate.rowid DESC
        LIMIT 1
      )`

// listForAgent returns the agent's tasks, newest first, with the latest run of
// each. The main agent also owns tasks that predate agents.
func (r repository) listForAgent(ctx context.Context, userID int64, agentID string, includeLegacyMain bool) ([]taskRow, error) {
	query := latestRunJoin + ` WHERE scheduled_tasks.user_id = ? AND scheduled_tasks.agent_id = ? ORDER BY scheduled_tasks.created_at DESC`
	if includeLegacyMain {
		query = latestRunJoin + ` WHERE scheduled_tasks.user_id = ? AND (scheduled_tasks.agent_id = ? OR scheduled_tasks.agent_id IS NULL) ORDER BY scheduled_tasks.created_at DESC`
	}
	rows, err := r.db.W.QueryContext(ctx, query, userID, agentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []taskRow
	for rows.Next() {
		t, err := scanTask(rows, true)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (r repository) query(ctx context.Context, query string, args ...any) ([]taskRow, error) {
	rows, err := r.db.W.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []taskRow
	for rows.Next() {
		t, err := scanTask(rows, false)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (r repository) listEnabled(ctx context.Context) ([]taskRow, error) {
	return r.query(ctx, `SELECT `+taskColumns+` FROM scheduled_tasks WHERE enabled = 1`)
}

// listDueOneTime lists one-time tasks whose time has come. run_at is compared
// as a time, not as text: ISO values ("...T05:00:00.000Z") sort after SQLite's
// "... 09:00:00" on the same day as strings.
func (r repository) listDueOneTime(ctx context.Context) ([]taskRow, error) {
	return r.query(ctx, `SELECT `+taskColumns+` FROM scheduled_tasks
       WHERE trigger_type = 'schedule'
         AND one_time = 1
         AND enabled = 1
         AND run_at IS NOT NULL
         AND julianday(run_at) <= julianday('now')`)
}

func (r repository) listEnabledByTriggerTypes(ctx context.Context, types []string) ([]taskRow, error) {
	if len(types) == 0 {
		return nil, nil
	}
	args := make([]any, len(types))
	for i, t := range types {
		args[i] = t
	}
	return r.query(ctx, `SELECT `+taskColumns+` FROM scheduled_tasks
       WHERE enabled = 1
         AND trigger_type IN (`+strings.TrimSuffix(strings.Repeat("?, ", len(types)), ", ")+`)`, args...)
}

// listEnabledEvent lists the user's enabled tasks of one trigger type; an empty
// agentID matches every agent.
func (r repository) listEnabledEvent(ctx context.Context, userID int64, agentID, triggerType string) ([]taskRow, error) {
	var agent any
	if agentID != "" {
		agent = agentID
	}
	return r.query(ctx, `SELECT `+taskColumns+` FROM scheduled_tasks
       WHERE enabled = 1 AND user_id = ? AND (? IS NULL OR agent_id = ?) AND trigger_type = ?`, userID, agent, agent, triggerType)
}

func (r repository) markTriggered(ctx context.Context, taskID, userID int64, fingerprint string) error {
	_, err := r.db.W.ExecContext(ctx, `UPDATE scheduled_tasks
       SET last_triggered_at = datetime('now'), last_trigger_fingerprint = ?
       WHERE id = ? AND user_id = ?`, fingerprint, taskID, userID)
	return err
}

func (r repository) markRun(ctx context.Context, taskID, userID int64) error {
	_, err := r.db.W.ExecContext(ctx, `UPDATE scheduled_tasks SET last_run = datetime('now') WHERE id = ? AND user_id = ?`, taskID, userID)
	return err
}

func (r repository) markRunFailed(ctx context.Context, runID string, userID int64, message string) error {
	if message == "" {
		message = "Task execution failed."
	}
	_, err := r.db.W.ExecContext(ctx, `UPDATE agent_runs
       SET status = 'failed',
           error = ?,
           updated_at = datetime('now'),
           completed_at = COALESCE(completed_at, datetime('now'))
       WHERE id = ? AND user_id = ?`, message, runID, userID)
	return err
}

func (r repository) updateConfig(ctx context.Context, taskID, userID int64, config *jsv.Object) error {
	_, err := r.db.W.ExecContext(ctx, `UPDATE scheduled_tasks SET task_config = ? WHERE id = ? AND user_id = ?`, jsv.Stringify(config), taskID, userID)
	return err
}

// averageRunSeconds is the average wall-clock duration of the most recent
// completed runs of one task; ok is false when it has none yet.
func (r repository) averageRunSeconds(ctx context.Context, taskID, userID int64) (float64, bool, error) {
	var avg sql.NullFloat64
	err := r.db.W.QueryRowContext(ctx, `SELECT AVG(duration_seconds) AS average_seconds
       FROM (
         SELECT (julianday(completed_at) - julianday(created_at)) * 86400 AS duration_seconds
         FROM agent_runs
         WHERE user_id = ?
           AND status = 'completed'
           AND completed_at IS NOT NULL
           AND json_valid(metadata_json)
           AND CAST(json_extract(metadata_json, '$.taskId') AS TEXT) = ?
         ORDER BY created_at DESC, rowid DESC
         LIMIT ?
       )`, userID, fmt.Sprint(taskID), runSampleSize).Scan(&avg)
	return avg.Float64, err == nil && avg.Valid && avg.Float64 > 0, err
}

// ranSince reports whether the task was last started within the given seconds.
func (r repository) ranSince(ctx context.Context, taskID, userID int64, secondsAgo float64) (bool, error) {
	var one int
	err := r.db.W.QueryRowContext(ctx, `SELECT 1 AS ran FROM scheduled_tasks
       WHERE id = ? AND user_id = ? AND last_run IS NOT NULL
         AND last_run >= datetime('now', ?)`, taskID, userID, fmt.Sprintf("-%d seconds", max(0, int64(secondsAgo+0.5)))).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

// lastRun is the latest run of a task with the messages it delivered.
type lastRun struct {
	Status       string
	Error        sql.NullString
	Final        sql.NullString
	CreatedAt    string
	SentMessages []string
}

func (r repository) lastTaskRun(ctx context.Context, userID, taskID int64, excludeRunID string) (*lastRun, error) {
	var exclude any
	if excludeRunID != "" {
		exclude = excludeRunID
	}
	var id string
	run := lastRun{}
	err := r.db.W.QueryRowContext(ctx, `SELECT id, status, error, final_response, created_at
       FROM agent_runs
       WHERE user_id = ?
         AND json_valid(metadata_json)
         AND CAST(json_extract(metadata_json, '$.taskId') AS TEXT) = ?
         AND id IS NOT ?
       ORDER BY created_at DESC, rowid DESC
       LIMIT 1`, userID, fmt.Sprint(taskID), exclude).Scan(&id, &run.Status, &run.Error, &run.Final, &run.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	rows, err := r.db.W.QueryContext(ctx, `SELECT content FROM messages WHERE run_id = ? AND role = 'assistant' ORDER BY id`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var content sql.NullString
		if err := rows.Scan(&content); err != nil {
			return nil, err
		}
		run.SentMessages = append(run.SentMessages, content.String)
	}
	return &run, rows.Err()
}

// taskConversation is the id of the conversation a task keeps, or "" if none.
func (r repository) taskConversation(ctx context.Context, userID int64, agentID, platform, chatID string) (string, error) {
	var id string
	err := r.db.W.QueryRowContext(ctx, `SELECT id FROM conversations WHERE user_id = ? AND agent_id = ? AND platform = ? AND platform_chat_id = ?`,
		userID, agentID, platform, chatID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	return id, err
}

func (r repository) createTaskConversation(ctx context.Context, id string, userID int64, agentID, platform, chatID, title string) error {
	_, err := r.db.W.ExecContext(ctx, `INSERT INTO conversations (id, user_id, agent_id, platform, platform_chat_id, title) VALUES (?, ?, ?, ?, ?, ?)`,
		id, userID, agentID, platform, chatID, title)
	return err
}

func (r repository) recentMessageTargets(ctx context.Context, userID int64, agentID string, limit int) ([]Target, error) {
	rows, err := r.db.W.QueryContext(ctx, `SELECT platform, platform_chat_id
       FROM messages
       WHERE user_id = ?
         AND agent_id = ?
         AND platform IS NOT NULL
         AND platform_chat_id IS NOT NULL
       ORDER BY id DESC
       LIMIT ?`, userID, agentID, max(1, min(limit, 100)))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Target
	for rows.Next() {
		var t Target
		if err := rows.Scan(&t.Platform, &t.To); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (r repository) userSetting(ctx context.Context, userID int64, key string) (string, bool, error) {
	return r.setting(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`, userID, key)
}

func (r repository) setting(ctx context.Context, query string, args ...any) (string, bool, error) {
	var value sql.NullString
	err := r.db.W.QueryRowContext(ctx, query, args...).Scan(&value)
	if errors.Is(err, sql.ErrNoRows) {
		return "", false, nil
	}
	return value.String, err == nil, err
}
