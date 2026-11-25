package agent

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
)

// Agent tasks run in the background and never block the run that asked: the
// owner works the task in its own run, and the requester hears back through a
// note in its run while it is still going, or a new run on the user's surface
// when it is not. State lives in the task row, so a restart picks work up again.

const (
	workingRunsPerUser  = 2
	maxTaskWait         = 120 * time.Second
	resultInUpdateChars = 4000
)

type agentRow struct {
	ID, Slug, Name, Status, DelegateTargets, ToolRestrictions string
	CanDelegate, CanBeDelegatedTo                             bool
}

func (e *Engine) agentRow(ctx context.Context, userID int64, where string, arg any) *agentRow {
	var a agentRow
	var slug, name, status, targets, restrictions sql.NullString
	var canDelegate, canBe sql.NullInt64
	if err := e.deps.DB.R.QueryRowContext(ctx, `SELECT id, slug, display_name, status, can_delegate, can_be_delegated_to, delegate_targets_json, tool_restrictions_json
		FROM agents WHERE user_id = ? AND `+where, userID, arg).Scan(&a.ID, &slug, &name, &status, &canDelegate, &canBe, &targets, &restrictions); err != nil {
		return nil
	}
	a.Slug, a.Name, a.Status, a.DelegateTargets, a.ToolRestrictions = slug.String, name.String, status.String, targets.String, restrictions.String
	if a.Status == "" {
		a.Status = "active"
	}
	a.CanDelegate = canDelegate.Int64 == 1
	a.CanBeDelegatedTo = !canBe.Valid || canBe.Int64 != 0
	return &a
}

func (e *Engine) findAgent(ctx context.Context, userID int64, reference string) *agentRow {
	text := strings.TrimSpace(reference)
	if text == "" {
		return nil
	}
	if a := e.agentRow(ctx, userID, "id = ?", text); a != nil {
		return a
	}
	if a := e.agentRow(ctx, userID, "slug = ?", text); a != nil {
		return a
	}
	return e.agentRow(ctx, userID, "lower(display_name) = lower(?)", text)
}

func canDelegateTo(source, target *agentRow) bool {
	if source == nil || target == nil || source.ID == target.ID || source.Status != "active" || target.Status != "active" || !source.CanDelegate || !target.CanBeDelegatedTo {
		return false
	}
	allowed := parseDelegateTargets(source.DelegateTargets)
	return len(allowed) == 0 || contains(allowed, target.ID)
}

func (e *Engine) agentName(ctx context.Context, userID int64, agentID string) string {
	if a := e.agentRow(ctx, userID, "id = ?", agentID); a != nil && a.Name != "" {
		return a.Name
	}
	return "another agent"
}

type taskChanges struct {
	mu      sync.Mutex
	waiters map[string][]chan struct{}
}

func (c *taskChanges) notify(id string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, ch := range c.waiters[id] {
		close(ch)
	}
	delete(c.waiters, id)
}

func (c *taskChanges) wait(ctx context.Context, id string, d time.Duration) {
	if d <= 0 {
		return
	}
	ch := make(chan struct{})
	c.mu.Lock()
	if c.waiters == nil {
		c.waiters = map[string][]chan struct{}{}
	}
	c.waiters[id] = append(c.waiters[id], ch)
	c.mu.Unlock()
	select {
	case <-ch:
	case <-time.After(d):
	case <-ctx.Done():
	}
}

var agentTaskChanges taskChanges

func (e *Engine) tasks() taskStore { return taskStore{e.deps.DB} }

func (e *Engine) recordTaskEvent(ctx context.Context, t *AgentTask, action string) {
	runID := t.ParentRunID
	if runID == "" {
		runID = t.ChildRunID
	}
	if runID != "" {
		e.RecordEvent(t.UserID, runID, t.TargetAgentID, runledger.EventAgentTask, map[string]any{"action": action, "task_id": t.ID, "mode": t.Mode, "status": t.Status,
			"requester_agent_id": t.ParentAgentID, "owner_agent_id": t.TargetAgentID})
	}
	e.Emit(t.UserID, "agent_task:update", map[string]any{"task": e.tasks().serialize(ctx, t)})
	agentTaskChanges.notify(t.ID)
}

// DelegateTask is delegate_to_agent.
func (e *Engine) DelegateTask(ctx context.Context, userID int64, agentID, runID string, args map[string]any) map[string]any {
	goal := strings.TrimSpace(fmtAny(args["task"]))
	if goal == "" {
		return map[string]any{"error": "task is required."}
	}
	resolved, _ := e.deps.Agents.Resolve(ctx, userID, agentID)
	requester := e.agentRow(ctx, userID, "id = ?", resolved)
	owner := e.findAgent(ctx, userID, fmtAny(args["agent"]))
	if owner == nil || owner.Status != "active" {
		slugs := []string{}
		if requester != nil {
			for _, t := range DelegationTargets(ctx, e.deps.DB, userID, requester.ID) {
				slugs = append(slugs, t.Slug)
			}
		}
		return map[string]any{"error": fmt.Sprintf(`No active agent matches "%v".`, args["agent"]), "agents": slugs}
	}
	if !canDelegateTo(requester, owner) {
		name := "This agent"
		if requester != nil && requester.Name != "" {
			name = requester.Name
		}
		return map[string]any{"error": fmt.Sprintf("%s may not hand work to %s. The user decides this in the agents' settings.", name, owner.Name)}
	}
	store := e.tasks()
	parent := store.forRun(ctx, runID)
	switch {
	case runID == "":
		return map[string]any{"error": "Agent tasks can only be created from a run."}
	case parent != nil && parent.Depth+1 > taskDepthLimit:
		return map[string]any{"error": "This work has already been passed along as far as it may go. Finish it yourself."}
	case parent != nil && store.agentsOnChain(ctx, parent.ID)[owner.ID]:
		return map[string]any{"error": fmt.Sprintf("%s is already part of this task. Passing work back would go in circles; finish it yourself.", owner.Name)}
	case store.count(ctx, `SELECT COUNT(*) FROM agent_delegations WHERE parent_run_id = ?`, runID) >= tasksPerRunLimit:
		return map[string]any{"error": fmt.Sprintf("One run may start at most %d agent tasks. Wait for those, or do the rest yourself.", tasksPerRunLimit)}
	case store.countOpen(ctx, userID) >= openTasksPerUser:
		return map[string]any{"error": "Too many agent tasks are still open on this account. Do the work yourself."}
	}
	mode := "delegate"
	if args["handoff"] == true {
		mode = "handoff"
	}
	var route any
	parentID, depth, parentRestrictions := "", 0, ""
	if parent != nil {
		parentID, depth, parentRestrictions = parent.ID, parent.Depth+1, parent.ToolRestrictions
		if parent.ReplyRoute != "" {
			var r any
			_ = json.Unmarshal([]byte(parent.ReplyRoute), &r)
			route = r
		}
	} else if r := e.routeOfRun(ctx, runID); r != nil {
		route = r
	}
	task := store.insert(ctx, newTask{userID: userID, requester: requester.ID, owner: owner.ID, requesterRun: runID, parentTask: parentID, goal: goal,
		context: strings.TrimSpace(fmtAny(args["context"])), expected: strings.TrimSpace(fmtAny(args["expected_output"])), mode: mode, depth: depth,
		replyRoute: route, restrictions: MergeToolRestrictions(requester.ToolRestrictions, parentRestrictions), allowSideEffects: args["allow_external_side_effects"] == true})
	if task == nil {
		return map[string]any{"error": "The task could not be recorded."}
	}
	e.recordTaskEvent(ctx, task, "created")
	e.dispatchTasks()
	note := fmt.Sprintf(`%s works on it in the background and its result comes back to you as an agent task update. Carry on or end your turn; use agent_task with action "status" and wait_seconds only when you cannot continue without it.`, owner.Name)
	if mode == "handoff" {
		note = fmt.Sprintf("%s owns this now and its result reaches the user without you. Tell the user in a sentence who took it over.", owner.Name)
	}
	status := task.Status
	if fresh := store.byID(ctx, task.ID); fresh != nil {
		status = fresh.Status
	}
	return map[string]any{"task_id": task.ID, "owner": owner.Name, "mode": mode, "status": status, "note": note}
}

func fencedNote(label, text string) string {
	return label + ":\n" + ai.FenceUntrusted("external_agent_message", text)
}

type taskBrief struct {
	text       string
	messageIDs []int64
	childIDs   []string
}

func (e *Engine) buildBrief(ctx context.Context, t *AgentTask, owner *agentRow) taskBrief {
	store := e.tasks()
	requester := e.agentName(ctx, t.UserID, t.ParentAgentID)
	var details []string
	if t.ExpectedOutput != "" {
		details = append(details, "Expected result:\n"+t.ExpectedOutput)
	}
	if t.Context != "" {
		details = append(details, fencedNote("Context from "+requester, t.Context))
	}
	if t.ResultSummary != "" {
		details = append(details, fencedNote("Where your last run on this task stopped", t.ResultSummary))
	}
	messages := store.unreadFor(ctx, t.ID, owner.ID)
	if len(messages) > 0 {
		lines := make([]string, len(messages))
		for i, m := range messages {
			lines[i] = e.agentName(ctx, t.UserID, m.from) + ": " + m.content
		}
		details = append(details, fencedNote("Messages on this task since then", strings.Join(lines, "\n\n")))
	}
	children := store.unreportedChildren(ctx, t.ID)
	if len(children) > 0 {
		lines := make([]string, len(children))
		for i, c := range children {
			lines[i] = e.describeForRequester(ctx, c)
		}
		details = append(details, fencedNote("Agents you handed parts to", strings.Join(lines, "\n\n")))
	}
	var open []string
	for _, c := range store.openDelegatedChildren(ctx, t.ID) {
		seen := false
		for _, s := range children {
			seen = seen || s.ID == c.ID
		}
		if !seen {
			open = append(open, fmt.Sprintf("%s (%s)", e.agentName(ctx, t.UserID, c.TargetAgentID), ai.ClampRunContext(c.Task, 120)))
		}
	}
	if len(open) > 0 {
		details = append(details, "Still being worked on by others: "+strings.Join(open, "; ")+".")
	}
	ownership := requester + " stays responsible for the user's request and builds on your result."
	recipient := requester
	if t.Mode == "handoff" {
		ownership, recipient = "You own it now: finish it end to end.", "the agent that talks to the user, which passes it on"
	}
	sideEffects := "Do not send messages, make calls, or change outside systems; report what should be done instead."
	if t.AllowExternalSideEffects {
		sideEffects = "You may send messages or change outside systems where the goal needs it."
	}
	detailText := ""
	if len(details) > 0 {
		detailText = "\n" + strings.Join(details, "\n\n") + "\n"
	}
	text := prompts.Render("runtime/agent_task.md", map[string]string{"task_id": t.ID, "requester": requester, "owner": owner.Name, "ownership": ownership,
		"goal": t.Task, "details": detailText, "recipient": recipient, "side_effects": sideEffects})
	brief := taskBrief{text: text}
	for _, m := range messages {
		brief.messageIDs = append(brief.messageIDs, m.id)
	}
	for _, c := range children {
		brief.childIDs = append(brief.childIDs, c.ID)
	}
	return brief
}

func (e *Engine) dispatchTasks() {
	if e.ShuttingDown() {
		return
	}
	ctx := context.Background()
	store := e.tasks()
	for _, t := range store.many(ctx, `status = 'pending' ORDER BY created_at ASC`) {
		if store.count(ctx, `SELECT COUNT(*) FROM agent_delegations WHERE user_id = ? AND status = 'working'`, t.UserID) >= workingRunsPerUser {
			continue
		}
		e.startTaskRun(ctx, t)
	}
}

func (e *Engine) startTaskRun(ctx context.Context, t *AgentTask) {
	owner := e.agentRow(ctx, t.UserID, "id = ?", t.TargetAgentID)
	if owner == nil || owner.Status != "active" {
		name := "The agent"
		if owner != nil && owner.Name != "" {
			name = owner.Name
		}
		e.finishTask(ctx, t, "failed", "", name+" is paused or archived.")
		return
	}
	if t.Attempts >= attemptsPerTask {
		e.finishTask(ctx, t, "failed", "", "The task took too many runs without finishing.")
		return
	}
	store := e.tasks()
	runID := uuid.NewString()
	claimed := store.claimForRun(ctx, t.ID, runID)
	if claimed == nil {
		return
	}
	e.recordTaskEvent(ctx, claimed, "working")
	var parentTrust *Trust
	if requester, ok := e.RunInfo(claimed.ParentRunID); ok {
		parentTrust = requester.Trust()
	}
	brief := e.buildBrief(ctx, claimed, owner)
	conversation := ""
	if e.deps.Memory != nil {
		conversation, _ = e.deps.Memory.DefaultWebConversationID(ctx, claimed.UserID, owner.ID)
	}
	o := Options{RunID: runID, AgentID: owner.ID, Title: claimed.Task, TriggerType: "agent_delegation", TriggerSource: "agent_delegation",
		ConversationID: conversation, SkipConversationHistory: true, ParentTrust: parentTrust}
	taskID := claimed.ID
	go func() {
		result, err := e.Run(e.lifecycle, claimed.UserID, brief.text, o)
		if err != nil {
			result = Result{Status: "failed", Error: err.Error()}
		}
		e.settleOwnerRun(taskID, runID, result, brief)
	}()
}

func (e *Engine) settleOwnerRun(taskID, runID string, result Result, brief taskBrief) {
	// A restart puts it back in the queue, brief and all.
	if result.Status == "interrupted" || e.ShuttingDown() {
		return
	}
	ctx := context.Background()
	store := e.tasks()
	store.markRead(ctx, brief.messageIDs, true)
	for _, id := range brief.childIDs {
		store.claimReport(ctx, id)
	}
	t := store.byID(ctx, taskID)
	if t == nil || t.ChildRunID != runID || t.Status != "working" {
		e.dispatchTasks()
		return
	}
	switch {
	case result.Status == "stopped":
		e.finishTask(ctx, t, "cancelled", "", "Its run was stopped.")
	case result.Status != "completed":
		errText := result.Error
		if errText == "" {
			errText = "The run ended without a result."
		}
		e.finishTask(ctx, t, "failed", "", ai.ClampRunContext(errText, 1000))
	default:
		content := strings.TrimSpace(result.Content)
		waiting := t.AwaitingReply || len(store.openDelegatedChildren(ctx, t.ID)) > 0 || len(store.unreportedChildren(ctx, t.ID)) > 0 || store.hasMessagesFor(ctx, t.ID, t.TargetAgentID)
		if waiting {
			if updated := store.update(ctx, t.ID, taskUpdate{status: ptr("waiting"), result: &content}, "working"); updated != nil {
				e.recordTaskEvent(ctx, updated, "waiting")
			}
			e.resumeIfReady(ctx, t.ID)
		} else {
			if content == "" {
				content = "The agent finished without writing a result."
			}
			e.finishTask(ctx, t, "completed", content, "")
		}
	}
	e.dispatchTasks()
}

func (e *Engine) resumeIfReady(ctx context.Context, id string) {
	store := e.tasks()
	t := store.byID(ctx, id)
	if t == nil || t.Status != "waiting" || t.AwaitingReply {
		return
	}
	news := len(store.unreportedChildren(ctx, id)) > 0 || store.hasMessagesFor(ctx, id, t.TargetAgentID)
	if !news && len(store.openDelegatedChildren(ctx, id)) > 0 {
		return
	}
	resumed := store.update(ctx, id, taskUpdate{status: ptr("pending")}, "waiting")
	if resumed == nil {
		return
	}
	e.recordTaskEvent(ctx, resumed, "resumed")
	e.dispatchTasks()
}

func (e *Engine) finishTask(ctx context.Context, t *AgentTask, status, result, errText string) {
	if result == "" {
		result = t.ResultSummary
	}
	settled := e.tasks().update(ctx, t.ID, taskUpdate{status: &status, result: &result, errText: &errText, awaitingReply: ptr(false), reportPending: ptr(true)}, openTaskStatuses...)
	if settled == nil {
		return
	}
	e.recordTaskEvent(ctx, settled, status)
	if status == "completed" {
		meta, _ := json.Marshal(map[string]any{"platform": "agent_task", "agentTask": map[string]any{"id": settled.ID, "mode": settled.Mode,
			"goal": ai.ClampRunContext(settled.Task, 300), "requester": e.agentName(ctx, settled.UserID, settled.ParentAgentID)}})
		e.execDB(ctx, `INSERT INTO conversation_history (user_id, agent_id, agent_run_id, role, content, metadata) VALUES (?, ?, ?, 'assistant', ?, ?)`,
			settled.UserID, settled.TargetAgentID, nullString(settled.ChildRunID), settled.ResultSummary, string(meta))
	} else {
		e.cancelOpenChildren(ctx, settled, "The task it was part of ended.")
	}
	e.notifyRequester(ctx, settled)
}

func (e *Engine) cancelTask(ctx context.Context, t *AgentTask, reason string) bool {
	cancelled := e.tasks().update(ctx, t.ID, taskUpdate{status: ptr("cancelled"), errText: &reason, awaitingReply: ptr(false), reportPending: ptr(false)}, openTaskStatuses...)
	if cancelled == nil {
		return false
	}
	if t.Status == "working" && t.ChildRunID != "" {
		e.StopRun(t.ChildRunID, reason)
	}
	e.recordTaskEvent(ctx, cancelled, "cancelled")
	e.cancelOpenChildren(ctx, cancelled, reason)
	return true
}

func (e *Engine) cancelOpenChildren(ctx context.Context, t *AgentTask, reason string) {
	for _, child := range e.tasks().openDelegatedChildren(ctx, t.ID) {
		e.cancelTask(ctx, child, reason)
	}
}

func (e *Engine) describeForRequester(ctx context.Context, t *AgentTask) string {
	owner := e.agentName(ctx, t.UserID, t.TargetAgentID)
	head := fmt.Sprintf("Task %s for %s (%s)", t.ID, owner, ai.ClampRunContext(t.Task, 200))
	switch {
	case t.AwaitingReply && isOpenStatus(t.Status):
		return fmt.Sprintf("%s needs an answer from you before it can go on. %s asks:\n%s\nReply with agent_task (action \"message\").", head, owner, e.tasks().lastMessageFrom(ctx, t.ID, t.TargetAgentID))
	case t.Status == "completed":
		return fmt.Sprintf("%s is done. Result:\n%s", head, ai.ClampRunContext(t.ResultSummary, resultInUpdateChars))
	case isOpenStatus(t.Status):
		return fmt.Sprintf("%s is %s.", head, t.Status)
	}
	verb := "failed"
	if t.Status == "cancelled" {
		verb = "was cancelled"
	}
	errText := t.Error
	if errText == "" {
		errText = "no reason given"
	}
	return fmt.Sprintf("%s %s: %s.", head, verb, errText)
}

func (e *Engine) renderTaskUpdate(ctx context.Context, list []*AgentTask, instruction string) string {
	lines := make([]string, len(list))
	for i, t := range list {
		lines[i] = e.describeForRequester(ctx, t)
	}
	return prompts.Render("runtime/agent_task_update.md", map[string]string{
		"updates": ai.FenceUntrusted("external_agent_message", strings.Join(lines, "\n\n")), "instruction": instruction})
}

// notifyRequester tells whoever asked for a task about its latest change: a
// note in the asking run while it is still going, the parent task's next run
// when an agent asked from inside a task, otherwise a new run on the user's
// surface.
func (e *Engine) notifyRequester(ctx context.Context, t *AgentTask) {
	if requester, ok := e.RunInfo(t.ParentRunID); ok && !requester.Aborted() {
		note := e.renderTaskUpdate(ctx, []*AgentTask{t}, "Use it in what you are doing now.")
		if e.enqueueTaskSteering(t.ParentRunID, note, "agent_task", t.ID, nil) {
			e.tasks().claimReport(ctx, t.ID)
		}
		return
	}
	if t.Mode == "delegate" && t.ParentTaskID != "" {
		if parent := e.tasks().byID(ctx, t.ParentTaskID); parent != nil && isOpenStatus(parent.Status) {
			e.resumeIfReady(ctx, parent.ID)
		} else {
			e.tasks().claimReport(ctx, t.ID)
		}
		return
	}
	e.startReportRun(ctx, t)
}

func (e *Engine) enqueueTaskSteering(runID, content, reason, taskID string, messageIDs []int64) bool {
	r, ok := e.RunInfo(runID)
	if !ok {
		return false
	}
	if !e.EnqueueSystemSteering(runID, content, reason) {
		return false
	}
	r.mu.Lock()
	if n := len(r.systemSteering); n > 0 {
		r.systemSteering[n-1].metadata = map[string]any{"agentTaskId": taskID, "agentTaskMessageIds": messageIDs}
	}
	r.mu.Unlock()
	return true
}

func (e *Engine) startReportRun(ctx context.Context, t *AgentTask) {
	if e.ShuttingDown() || !e.tasks().claimReport(ctx, t.ID) {
		return
	}
	var o Options
	routeAgent := t.ParentAgentID
	if t.ReplyRoute != "" {
		var route resumeRoute
		if json.Unmarshal([]byte(t.ReplyRoute), &route) == nil {
			o = route.options()
			o.Context.RawUserMessage = ""
			o.MediaAttachments = nil
			if route.AgentID != "" {
				routeAgent = route.AgentID
			}
		}
	}
	if t.ReplyRoute == "" {
		o = Options{TriggerType: "agent_task", TriggerSource: "web", AgentID: routeAgent}
		if e.deps.Memory != nil {
			o.ConversationID, _ = e.deps.Memory.DefaultWebConversationID(ctx, t.UserID, routeAgent)
		}
	}
	owner := e.agentName(ctx, t.UserID, t.TargetAgentID)
	instruction := "Nothing new came from the user. Carry on with the request this belongs to: tell the user what matters in your own words, or act on it. Answer an agent's question yourself when you can, and ask the user only when you cannot."
	if t.Mode == "handoff" {
		instruction = owner + " took this request over from you. Pass its outcome on to the user in your own words; do not redo the work."
	}
	o.Title = "Update: " + ai.ClampRunContext(t.Task, 80)
	message := e.renderTaskUpdate(ctx, []*AgentTask{t}, instruction)
	userID, taskID := t.UserID, t.ID
	go func() {
		if _, err := e.RunOnRoute(e.lifecycle, userID, message, o); err != nil {
			e.log.Error("Reporting agent task failed", "task", taskID, "error", err)
			e.tasks().update(context.Background(), taskID, taskUpdate{reportPending: ptr(true)})
		}
	}()
}

// onAgentTaskRunEnded: notes a run never read are owed again, a run the user
// stopped takes the work it handed out with it, and anything it asked for that
// has news is reported now that it cannot read it.
func (e *Engine) onAgentTaskRunEnded(r *Run) {
	ctx := context.Background()
	store := e.tasks()
	r.mu.Lock()
	unread := r.systemSteering
	r.mu.Unlock()
	for _, item := range unread {
		if ids, ok := item.metadata["agentTaskMessageIds"].([]int64); ok {
			store.markRead(ctx, ids, false)
		}
		if id, _ := item.metadata["agentTaskId"].(string); id != "" {
			store.update(ctx, id, taskUpdate{reportPending: ptr(true)})
		}
	}
	if r.Status() == "stopped" {
		for _, t := range store.many(ctx, `parent_run_id = ?`, r.ID) {
			if t.Mode == "delegate" {
				e.cancelTask(ctx, t, "The run that asked for it was stopped.")
			}
		}
	}
	for _, t := range store.many(ctx, `parent_run_id = ?`, r.ID) {
		if t.ReportPending {
			e.notifyRequester(ctx, t)
		}
	}
}

// ResumeAgentTasks requeues the tasks a restart cut off and reports what is owed.
func (e *Engine) ResumeAgentTasks(ctx context.Context) {
	res, err := e.deps.DB.W.ExecContext(ctx, `UPDATE agent_delegations SET status = 'pending', updated_at = datetime('now') WHERE status = 'working'`)
	var requeued int64
	if err == nil {
		requeued, _ = res.RowsAffected()
	}
	for _, t := range e.tasks().many(ctx, `report_pending = 1 ORDER BY updated_at ASC`) {
		e.notifyRequester(ctx, t)
	}
	e.dispatchTasks()
	if requeued > 0 {
		e.log.Info(fmt.Sprintf("Resuming %d agent task(s) a restart interrupted.", requeued))
	}
}

func (e *Engine) describeTask(ctx context.Context, t *AgentTask) map[string]any {
	view := e.tasks().serialize(ctx, t)
	if s, _ := view["result"].(string); s != "" {
		view["result"] = ai.ClampRunContext(s, resultInUpdateChars)
	}
	all := e.tasks().messages(ctx, `SELECT id, from_agent_id, content, created_at FROM agent_task_messages WHERE task_id = ? ORDER BY id ASC`, t.ID)
	if len(all) > 6 {
		all = all[len(all)-6:]
	}
	messages := make([]map[string]any, len(all))
	for i, m := range all {
		messages[i] = map[string]any{"from": e.agentName(ctx, t.UserID, m.from), "content": ai.ClampRunContext(m.content, 600)}
	}
	view["messages"] = messages
	return view
}

func (e *Engine) sendTaskMessage(ctx context.Context, t *AgentTask, sender, text string) map[string]any {
	store := e.tasks()
	if !isOpenStatus(t.Status) {
		return map[string]any{"error": fmt.Sprintf("Task %s is %s. Start a new task with delegate_to_agent instead.", t.ID, t.Status)}
	}
	if store.count(ctx, `SELECT COUNT(*) FROM agent_task_messages WHERE task_id = ?`, t.ID) >= messagesPerTaskLimit {
		return map[string]any{"error": "This task has reached its message limit. Decide with what you have."}
	}
	store.addMessage(ctx, t.ID, sender, text)
	if sender == t.TargetAgentID {
		asking := store.update(ctx, t.ID, taskUpdate{awaitingReply: ptr(true), reportPending: ptr(true)})
		if asking != nil {
			e.recordTaskEvent(ctx, asking, "question")
			e.notifyRequester(ctx, asking)
		}
		return map[string]any{"sent": true, "note": "End your turn now; this task continues when the answer arrives."}
	}
	updated := store.update(ctx, t.ID, taskUpdate{awaitingReply: ptr(false)})
	if updated == nil {
		return map[string]any{"sent": true}
	}
	var ownerRun *Run
	if updated.Status == "working" {
		ownerRun, _ = e.RunInfo(updated.ChildRunID)
	}
	if ownerRun != nil && !ownerRun.Aborted() {
		messages := store.takeFor(ctx, updated.ID, updated.TargetAgentID)
		contents := make([]string, len(messages))
		ids := make([]int64, len(messages))
		for i, m := range messages {
			contents[i], ids[i] = m.content, m.id
		}
		note := fencedNote(fmt.Sprintf("Message on agent task %s from %s", updated.ID, e.agentName(ctx, updated.UserID, sender)), strings.Join(contents, "\n\n"))
		e.enqueueTaskSteering(updated.ChildRunID, note, "agent_task_message", "", ids)
	} else {
		e.resumeIfReady(ctx, updated.ID)
	}
	e.recordTaskEvent(ctx, updated, "message")
	return map[string]any{"sent": true}
}

// AgentTaskAction is the agent_task tool.
func (e *Engine) AgentTaskAction(ctx context.Context, userID int64, agentID, runID string, args map[string]any) map[string]any {
	store := e.tasks()
	action := strings.TrimSpace(fmtAny(args["action"]))
	taskID := strings.TrimSpace(fmtAny(args["task_id"]))
	if action == "list" || (taskID == "" && action == "status") {
		list := []map[string]any{}
		for _, t := range store.openForAgent(ctx, userID, agentID) {
			list = append(list, e.describeTask(ctx, t))
		}
		return map[string]any{"tasks": list}
	}
	t := store.get(ctx, userID, taskID)
	if t == nil || (t.ParentAgentID != agentID && t.TargetAgentID != agentID) {
		return map[string]any{"error": fmt.Sprintf(`No agent task "%s" that you asked for or own.`, taskID)}
	}
	switch action {
	case "status":
		if t.ParentAgentID == agentID && isOpenStatus(t.Status) && !t.AwaitingReply {
			seconds, _ := args["wait_seconds"].(float64)
			agentTaskChanges.wait(ctx, t.ID, min(time.Duration(max(seconds, 0)*float64(time.Second)), maxTaskWait))
		}
		fresh := store.byID(ctx, t.ID)
		// Reading the outcome here is hearing it; no update needs to follow.
		if fresh.ParentAgentID == agentID && fresh.ParentRunID == runID && fresh.ReportPending {
			store.claimReport(ctx, fresh.ID)
		}
		return map[string]any{"task": e.describeTask(ctx, fresh)}
	case "message":
		text := strings.TrimSpace(fmtAny(args["message"]))
		if text == "" {
			return map[string]any{"error": "message is required."}
		}
		return e.sendTaskMessage(ctx, t, agentID, text)
	case "handoff":
		if t.TargetAgentID != agentID {
			return map[string]any{"error": "Only the agent that owns a task can hand it on."}
		}
		current := e.agentRow(ctx, userID, "id = ?", agentID)
		next := e.findAgent(ctx, userID, fmtAny(args["agent"]))
		if next == nil || next.Status != "active" {
			return map[string]any{"error": fmt.Sprintf(`No active agent matches "%v".`, args["agent"])}
		}
		if !canDelegateTo(current, next) {
			return map[string]any{"error": fmt.Sprintf("%s may not hand work to %s.", current.Name, next.Name)}
		}
		if store.agentsOnChain(ctx, t.ID)[next.ID] {
			return map[string]any{"error": fmt.Sprintf("%s is already part of this task. Passing it back would go in circles; finish it yourself.", next.Name)}
		}
		note := strings.TrimSpace(fmtAny(args["message"]))
		if note == "" {
			note = current.Name + " handed this task to you."
		}
		store.addMessage(ctx, t.ID, agentID, note)
		moved := store.update(ctx, t.ID, taskUpdate{owner: &next.ID, status: ptr("pending"), awaitingReply: ptr(false)}, openTaskStatuses...)
		if moved == nil {
			return map[string]any{"error": fmt.Sprintf("Task %s is no longer open.", t.ID)}
		}
		e.recordTaskEvent(ctx, moved, "handed_off")
		e.dispatchTasks()
		return map[string]any{"handed_off": true, "owner": next.Name, "note": "It is no longer yours. End your turn with a one-line note."}
	case "cancel":
		if t.ParentAgentID != agentID {
			return map[string]any{"error": "Only the agent that asked for a task can cancel it."}
		}
		reason := strings.TrimSpace(fmtAny(args["message"]))
		if reason == "" {
			reason = "Cancelled by the agent that asked for it."
		}
		if e.cancelTask(ctx, t, reason) {
			return map[string]any{"cancelled": true, "task_id": t.ID}
		}
		return map[string]any{"error": fmt.Sprintf("Task %s is already %s.", t.ID, t.Status)}
	}
	return map[string]any{"error": "action must be list, status, message, handoff, or cancel."}
}

// openTasksNote is for the prompt of an agent with tasks in flight.
func (e *Engine) openTasksNote(ctx context.Context, userID int64, agentID, runID string) string {
	store := e.tasks()
	own := ""
	if t := store.forRun(ctx, runID); t != nil {
		own = t.ID
	}
	var lines []string
	for _, t := range store.openForAgent(ctx, userID, agentID) {
		if t.ID == own {
			continue
		}
		asked := t.ParentAgentID == agentID
		otherID := t.ParentAgentID
		if asked {
			otherID = t.TargetAgentID
		}
		other := e.agentName(ctx, userID, otherID)
		status := t.Status
		if t.AwaitingReply {
			status = "waiting for an answer"
		}
		who := other + " asked you"
		if asked {
			who = "you asked " + other
		}
		lines = append(lines, fmt.Sprintf("- %s: %s (%s, %s): %s", t.ID, who, t.Mode, status, ai.ClampRunContext(t.Task, 200)))
	}
	if len(lines) == 0 {
		return ""
	}
	return strings.Join(append(append([]string{"[Agent tasks in flight]"}, lines...), "Use agent_task for a fresh look or to send a message. Do not redo work another agent owns."), "\n")
}

// CancelTaskForUser lets the user cancel a task from the app.
func (e *Engine) CancelTaskForUser(ctx context.Context, userID int64, taskID string) map[string]any {
	t := e.tasks().get(ctx, userID, taskID)
	if t == nil {
		return nil
	}
	e.cancelTask(ctx, t, "Cancelled by the user.")
	return e.tasks().serialize(ctx, e.tasks().byID(ctx, t.ID))
}

// ListAgentTasks lists the account's tasks, open ones first.
func (e *Engine) ListAgentTasks(ctx context.Context, userID int64, limit int) []map[string]any {
	if limit <= 0 {
		limit = 50
	}
	placeholders, values := inList(openTaskStatuses)
	args := append([]any{userID}, values...)
	out := []map[string]any{}
	for _, t := range e.tasks().many(ctx, `user_id = ? ORDER BY CASE WHEN status IN (`+placeholders+`) THEN 0 ELSE 1 END, updated_at DESC LIMIT ?`, append(args, limit)...) {
		out = append(out, e.tasks().serialize(ctx, t))
	}
	return out
}
