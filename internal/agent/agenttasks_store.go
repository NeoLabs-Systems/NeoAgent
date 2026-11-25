package agent

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Durable work between persistent agents. A task has one owner (the agent
// working it) and one requester (the agent that asked). In "delegate" mode the
// result goes back to the requester; in "handoff" mode the owner takes the
// request over and its result goes to the user. Rows live in agent_delegations.

var openTaskStatuses = []string{"pending", "working", "waiting"}
var closedTaskStatuses = []string{"completed", "failed", "cancelled"}

// Plain counts that bound how far work can spread.
const (
	taskDepthLimit       = 2
	tasksPerRunLimit     = 3
	openTasksPerUser     = 20
	messagesPerTaskLimit = 20
	attemptsPerTask      = 6
	taskResultMaxChars   = 20000
)

// AgentTask is one agent_delegations row.
type AgentTask struct {
	ID, ParentAgentID, TargetAgentID, ParentRunID, ChildRunID, ParentTaskID string
	UserID                                                                  int64
	Task, Context, ExpectedOutput, Mode, Status                             string
	ResultSummary, Error, ReplyRoute, ToolRestrictions                      string
	Depth, Attempts                                                         int
	AllowExternalSideEffects, AwaitingReply, ReportPending                  bool
	CreatedAt, UpdatedAt, CompletedAt                                       string
}

func isOpenStatus(status string) bool { return contains(openTaskStatuses, status) }

type taskStore struct{ db *dbx.DB }

const taskColumns = `id, user_id, parent_agent_id, target_agent_id, parent_run_id, child_run_id, parent_task_id, task, context, expected_output, mode, status,
	result_summary, error, reply_route_json, tool_restrictions_json, depth, attempts, allow_external_side_effects, awaiting_reply, report_pending, created_at, updated_at, completed_at`

func scanTask(row interface{ Scan(...any) error }) (*AgentTask, error) {
	var t AgentTask
	var parentRun, childRun, parentTask, context, expected, mode, status, result, errText, route, restrictions, created, updated, completed sql.NullString
	var depth, attempts, allow, awaiting, report sql.NullInt64
	if err := row.Scan(&t.ID, &t.UserID, &t.ParentAgentID, &t.TargetAgentID, &parentRun, &childRun, &parentTask, &t.Task, &context, &expected, &mode, &status,
		&result, &errText, &route, &restrictions, &depth, &attempts, &allow, &awaiting, &report, &created, &updated, &completed); err != nil {
		return nil, err
	}
	t.ParentRunID, t.ChildRunID, t.ParentTaskID = parentRun.String, childRun.String, parentTask.String
	t.Context, t.ExpectedOutput, t.Mode, t.Status = context.String, expected.String, mode.String, status.String
	if t.Mode == "" {
		t.Mode = "delegate"
	}
	t.ResultSummary, t.Error, t.ReplyRoute, t.ToolRestrictions = result.String, errText.String, route.String, restrictions.String
	t.Depth, t.Attempts = int(depth.Int64), int(attempts.Int64)
	t.AllowExternalSideEffects, t.AwaitingReply, t.ReportPending = allow.Int64 == 1, awaiting.Int64 == 1, report.Int64 == 1
	t.CreatedAt, t.UpdatedAt, t.CompletedAt = created.String, updated.String, completed.String
	return &t, nil
}

func (s taskStore) one(ctx context.Context, where string, args ...any) *AgentTask {
	t, err := scanTask(s.db.W.QueryRowContext(ctx, `SELECT `+taskColumns+` FROM agent_delegations WHERE `+where, args...))
	if err != nil {
		return nil
	}
	return t
}

func (s taskStore) many(ctx context.Context, where string, args ...any) []*AgentTask {
	rows, err := s.db.W.QueryContext(ctx, `SELECT `+taskColumns+` FROM agent_delegations WHERE `+where, args...)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []*AgentTask
	for rows.Next() {
		if t, err := scanTask(rows); err == nil {
			out = append(out, t)
		}
	}
	return out
}

func inList(values []string) (string, []any) {
	args := make([]any, len(values))
	for i, v := range values {
		args[i] = v
	}
	return strings.TrimSuffix(strings.Repeat("?, ", len(values)), ", "), args
}

func (s taskStore) get(ctx context.Context, userID int64, id string) *AgentTask {
	if id == "" {
		return nil
	}
	return s.one(ctx, `user_id = ? AND id = ?`, userID, id)
}

func (s taskStore) byID(ctx context.Context, id string) *AgentTask { return s.one(ctx, `id = ?`, id) }

func (s taskStore) forRun(ctx context.Context, runID string) *AgentTask {
	if runID == "" {
		return nil
	}
	return s.one(ctx, `child_run_id = ?`, runID)
}

type newTask struct {
	userID                                     int64
	requester, owner, requesterRun, parentTask string
	goal, context, expected, mode              string
	depth                                      int
	replyRoute                                 any
	restrictions                               map[string]string
	allowSideEffects                           bool
}

func (s taskStore) insert(ctx context.Context, n newTask) *AgentTask {
	id := uuid.NewString()
	var route any
	if n.replyRoute != nil {
		encoded, _ := json.Marshal(n.replyRoute)
		route = string(encoded)
	}
	restrictions, _ := json.Marshal(n.restrictions)
	if n.restrictions == nil {
		restrictions = []byte("{}")
	}
	allow := 0
	if n.allowSideEffects {
		allow = 1
	}
	_, err := s.db.W.ExecContext(ctx, `INSERT INTO agent_delegations (id, user_id, parent_agent_id, target_agent_id, parent_run_id, parent_task_id, task, context,
		expected_output, mode, depth, status, reply_route_json, tool_restrictions_json, allow_external_side_effects) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
		id, n.userID, n.requester, n.owner, nullString(n.requesterRun), nullString(n.parentTask), n.goal, nullString(n.context), nullString(n.expected),
		n.mode, n.depth, route, string(restrictions), allow)
	if err != nil {
		return nil
	}
	return s.byID(ctx, id)
}

// taskUpdate are the fields a task change sets; nil leaves a field alone.
type taskUpdate struct {
	status, owner, ownerRun, mode, result, errText *string
	awaitingReply, reportPending                   *bool
}

func ptr[T any](v T) *T { return &v }

// update changes a task only if it is still in one of fromStatuses, so two
// paths racing to settle the same task cannot both win.
func (s taskStore) update(ctx context.Context, id string, u taskUpdate, fromStatuses ...string) *AgentTask {
	var sets []string
	var args []any
	set := func(column string, v any) {
		sets = append(sets, column+" = ?")
		args = append(args, v)
	}
	if u.status != nil {
		set("status", *u.status)
	}
	if u.owner != nil {
		set("target_agent_id", *u.owner)
	}
	if u.ownerRun != nil {
		set("child_run_id", *u.ownerRun)
	}
	if u.mode != nil {
		set("mode", *u.mode)
	}
	if u.result != nil {
		text := *u.result
		if r := []rune(text); len(r) > taskResultMaxChars {
			text = string(r[:taskResultMaxChars])
		}
		set("result_summary", nullString(text))
	}
	if u.errText != nil {
		set("error", nullString(*u.errText))
	}
	boolInt := func(b bool) int {
		if b {
			return 1
		}
		return 0
	}
	if u.awaitingReply != nil {
		set("awaiting_reply", boolInt(*u.awaitingReply))
	}
	if u.reportPending != nil {
		set("report_pending", boolInt(*u.reportPending))
	}
	if u.status != nil && contains(closedTaskStatuses, *u.status) {
		sets = append(sets, "completed_at = datetime('now')")
	}
	sets = append(sets, "updated_at = datetime('now')")
	query := `UPDATE agent_delegations SET ` + strings.Join(sets, ", ") + ` WHERE id = ?`
	args = append(args, id)
	if len(fromStatuses) > 0 {
		placeholders, values := inList(fromStatuses)
		query += ` AND status IN (` + placeholders + `)`
		args = append(args, values...)
	}
	res, err := s.db.W.ExecContext(ctx, query, args...)
	if err != nil {
		return nil
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return nil
	}
	return s.byID(ctx, id)
}

func (s taskStore) claimForRun(ctx context.Context, id, runID string) *AgentTask {
	res, err := s.db.W.ExecContext(ctx, `UPDATE agent_delegations SET status = 'working', child_run_id = ?, attempts = COALESCE(attempts, 0) + 1, updated_at = datetime('now')
		WHERE id = ? AND status = 'pending'`, runID, id)
	if err != nil {
		return nil
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return nil
	}
	return s.byID(ctx, id)
}

func (s taskStore) claimReport(ctx context.Context, id string) bool {
	res, err := s.db.W.ExecContext(ctx, `UPDATE agent_delegations SET report_pending = 0 WHERE id = ? AND report_pending = 1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s taskStore) count(ctx context.Context, query string, args ...any) int {
	var n int
	_ = s.db.W.QueryRowContext(ctx, query, args...).Scan(&n)
	return n
}

func (s taskStore) countOpen(ctx context.Context, userID int64) int {
	placeholders, values := inList(openTaskStatuses)
	return s.count(ctx, `SELECT COUNT(*) FROM agent_delegations WHERE user_id = ? AND status IN (`+placeholders+`)`, append([]any{userID}, values...)...)
}

func (s taskStore) openDelegatedChildren(ctx context.Context, id string) []*AgentTask {
	placeholders, values := inList(openTaskStatuses)
	return s.many(ctx, `parent_task_id = ? AND mode = 'delegate' AND status IN (`+placeholders+`)`, append([]any{id}, values...)...)
}

func (s taskStore) unreportedChildren(ctx context.Context, id string) []*AgentTask {
	return s.many(ctx, `parent_task_id = ? AND mode = 'delegate' AND report_pending = 1 ORDER BY updated_at ASC`, id)
}

func (s taskStore) openForAgent(ctx context.Context, userID int64, agentID string) []*AgentTask {
	placeholders, values := inList(openTaskStatuses)
	args := append([]any{userID}, values...)
	return s.many(ctx, `user_id = ? AND status IN (`+placeholders+`) AND (parent_agent_id = ? OR target_agent_id = ?) ORDER BY created_at ASC LIMIT 20`, append(args, agentID, agentID)...)
}

func (s taskStore) agentsOnChain(ctx context.Context, id string) map[string]bool {
	agents := map[string]bool{}
	current := s.byID(ctx, id)
	for current != nil {
		agents[current.ParentAgentID], agents[current.TargetAgentID] = true, true
		rows, err := s.db.W.QueryContext(ctx, `SELECT DISTINCT from_agent_id FROM agent_task_messages WHERE task_id = ?`, current.ID)
		if err == nil {
			for rows.Next() {
				var from sql.NullString
				if rows.Scan(&from) == nil && from.String != "" {
					agents[from.String] = true
				}
			}
			rows.Close()
		}
		if current.ParentTaskID == "" {
			break
		}
		current = s.byID(ctx, current.ParentTaskID)
	}
	return agents
}

type taskMessage struct {
	id                int64
	from, content, at string
}

func (s taskStore) addMessage(ctx context.Context, id, from, content string) {
	if r := []rune(content); len(r) > taskResultMaxChars {
		content = string(r[:taskResultMaxChars])
	}
	_, _ = s.db.W.ExecContext(ctx, `INSERT INTO agent_task_messages (task_id, from_agent_id, content) VALUES (?, ?, ?)`, id, nullString(from), content)
}

func (s taskStore) messages(ctx context.Context, query string, args ...any) []taskMessage {
	rows, err := s.db.W.QueryContext(ctx, query, args...)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []taskMessage
	for rows.Next() {
		var m taskMessage
		var from, at sql.NullString
		if rows.Scan(&m.id, &from, &m.content, &at) == nil {
			m.from, m.at = from.String, at.String
			out = append(out, m)
		}
	}
	return out
}

func (s taskStore) unreadFor(ctx context.Context, id, agentID string) []taskMessage {
	return s.messages(ctx, `SELECT id, from_agent_id, content, created_at FROM agent_task_messages WHERE task_id = ? AND delivered_at IS NULL AND COALESCE(from_agent_id, '') != ? ORDER BY id ASC`, id, agentID)
}

func (s taskStore) markRead(ctx context.Context, ids []int64, read bool) {
	if len(ids) == 0 {
		return
	}
	args := make([]any, len(ids))
	for i, id := range ids {
		args[i] = id
	}
	value := "datetime('now')"
	if !read {
		value = "NULL"
	}
	_, _ = s.db.W.ExecContext(ctx, `UPDATE agent_task_messages SET delivered_at = `+value+` WHERE id IN (`+strings.TrimSuffix(strings.Repeat("?, ", len(ids)), ", ")+`)`, args...)
}

func (s taskStore) takeFor(ctx context.Context, id, agentID string) []taskMessage {
	messages := s.unreadFor(ctx, id, agentID)
	ids := make([]int64, len(messages))
	for i, m := range messages {
		ids[i] = m.id
	}
	s.markRead(ctx, ids, true)
	return messages
}

func (s taskStore) hasMessagesFor(ctx context.Context, id, agentID string) bool {
	var one int
	return s.db.W.QueryRowContext(ctx, `SELECT 1 FROM agent_task_messages WHERE task_id = ? AND delivered_at IS NULL AND COALESCE(from_agent_id, '') != ? LIMIT 1`, id, agentID).Scan(&one) == nil
}

func (s taskStore) lastMessageFrom(ctx context.Context, id, agentID string) string {
	var content sql.NullString
	_ = s.db.W.QueryRowContext(ctx, `SELECT content FROM agent_task_messages WHERE task_id = ? AND from_agent_id = ? ORDER BY id DESC LIMIT 1`, id, agentID).Scan(&content)
	return content.String
}

func (s taskStore) agentNames(ctx context.Context, userID int64) map[string]string {
	names := map[string]string{}
	rows, err := s.db.R.QueryContext(ctx, `SELECT id, display_name FROM agents WHERE user_id = ?`, userID)
	if err != nil {
		return names
	}
	defer rows.Close()
	for rows.Next() {
		var id, name sql.NullString
		if rows.Scan(&id, &name) == nil {
			names[id.String] = name.String
		}
	}
	return names
}

// SerializeTask is a task as the app shows it.
func (s taskStore) serialize(ctx context.Context, t *AgentTask) map[string]any {
	names := s.agentNames(ctx, t.UserID)
	return map[string]any{
		"id": t.ID, "mode": t.Mode, "goal": t.Task, "expectedOutput": t.ExpectedOutput, "status": t.Status, "result": t.ResultSummary, "error": t.Error,
		"awaitingReply": t.AwaitingReply, "requester": map[string]any{"id": t.ParentAgentID, "name": names[t.ParentAgentID]},
		"owner": map[string]any{"id": t.TargetAgentID, "name": names[t.TargetAgentID]}, "parentTaskId": nullString(t.ParentTaskID),
		"runId": nullString(t.ChildRunID), "createdAt": t.CreatedAt, "updatedAt": t.UpdatedAt, "completedAt": nullString(t.CompletedAt),
	}
}

var levelRank = map[string]int{"require_approval": 1, "deny": 2}

var policyCategories = map[string]bool{"shell": true, "file_write": true, "android_privileged": true, "desktop_control": true, "browser_privileged": true,
	"credential_use": true, "network_write": true, "user_contact": true, "skill_mutation": true, "agent_creation": true, "external": true}

// NormalizeToolRestrictions reads an agent's stricter-than-account tool rules.
func NormalizeToolRestrictions(raw string) map[string]string {
	out := map[string]string{}
	var parsed map[string]any
	if json.Unmarshal([]byte(raw), &parsed) != nil {
		return out
	}
	for category, level := range parsed {
		l := fmt.Sprint(level)
		if policyCategories[category] && levelRank[l] > 0 {
			out[category] = l
		}
	}
	return out
}

// MergeToolRestrictions is the strictest level per category across sources.
func MergeToolRestrictions(sources ...string) map[string]string {
	merged := map[string]string{}
	for _, source := range sources {
		for category, level := range NormalizeToolRestrictions(source) {
			if levelRank[level] > levelRank[merged[category]] {
				merged[category] = level
			}
		}
	}
	return merged
}

// RestrictionForRun is the restriction a run is under for a tool category: its
// agent's own, plus those of the agents that asked for the task it works on.
func RestrictionForRun(ctx context.Context, db *dbx.DB, userID int64, agentID, runID, category string) string {
	if category == "" {
		return ""
	}
	var agent, task sql.NullString
	if agentID != "" {
		_ = db.R.QueryRowContext(ctx, `SELECT tool_restrictions_json FROM agents WHERE user_id = ? AND id = ?`, userID, agentID).Scan(&agent)
	}
	if runID != "" {
		_ = db.W.QueryRowContext(ctx, `SELECT tool_restrictions_json FROM agent_delegations WHERE child_run_id = ?`, runID).Scan(&task)
	}
	return MergeToolRestrictions(agent.String, task.String)[category]
}
