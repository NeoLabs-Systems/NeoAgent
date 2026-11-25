package voice

import (
	"context"
	"crypto/rand"
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
)

const (
	maxSpokenRequestChars = 160
	maxStatusStepChars    = 160
)

// Message kinds of an outbox delivery.
const (
	KindAck     = "ack"
	KindInterim = "interim"
	KindFinal   = "final"
)

// Delivery is an outbox entry for a voice-originated run. Instead of a chat
// channel it arrives on the call.
type Delivery struct {
	// Recipient is the id of the voice session that started the run.
	Recipient   string
	RunID       string
	MessageKind string
	Content     string
	// Kind is the payload metadata's kind ("ack" for an opening line).
	Kind string
	// ExpectsReply and LivenessStatus come from the payload metadata.
	ExpectsReply   bool
	LivenessStatus string
}

func clampRequest(request string) string { return clampText(request, maxSpokenRequestChars) }

type runRecord struct {
	handle    string
	request   string
	delivered bool
	cancelled bool
}

// taskBridge maps the runs a call hands off to the live model's hand-off
// handles and feeds their progress and results back into the call. Everything
// the live model hands off runs as an ordinary agent run: same orchestrator,
// tools, memory, approvals, verification and outbox delivery as a chat or
// WhatsApp message.
//
// Each hand-off is a run of its own, so the owner can start more work while
// earlier work is running. The live model checks on, changes or stops tasks
// with its task tools, which reach every task the owner has running with this
// agent: this call's, an earlier call's and the chat's.
//
// Only runs this call started report into it. The run that placed an
// agent-initiated call is not its work: it finishes on its own, so treating it
// as the call's task showed the call as busy and fed what the owner said into a
// run that was already wrapping up, where nothing answered it.
type taskBridge struct {
	engine    Engine
	render    Renderer
	sanitize  func(error) string
	log       *slog.Logger
	session   *livevoice.Session
	userID    int64
	agentID   string
	sessionID string
	// conversationID is the thread hand-offs run in.
	conversationID string

	mu   sync.Mutex
	runs map[string]*runRecord
	// order lists run ids oldest first, as a Map keeps its keys.
	order []string
	// taskIDs are short ids the live model can repeat back, by run id.
	taskIDs map[string]string
}

func newTaskBridge(engine Engine, render Renderer, sanitize func(error) string, log *slog.Logger) *taskBridge {
	return &taskBridge{
		engine: engine, render: render, sanitize: sanitize, log: log,
		runs: map[string]*runRecord{}, taskIDs: map[string]string{},
	}
}

func (b *taskBridge) records() (ids []string, records []runRecord) {
	b.mu.Lock()
	defer b.mu.Unlock()
	for _, id := range b.order {
		ids = append(ids, id)
		records = append(records, *b.runs[id])
	}
	return ids, records
}

// Running lists this call's tasks that are still running, oldest first.
func (b *taskBridge) Running() []livevoice.RunningTask {
	ids, records := b.records()
	var tasks []livevoice.RunningTask
	for i, id := range ids {
		if meta, ok := b.engine.RunMeta(id); ok && !meta.Aborted && meta.Status == "running" {
			tasks = append(tasks, livevoice.RunningTask{RunID: id, Request: records[i].request})
		}
	}
	return tasks
}

// ActiveRunID is the newest running task of this call.
func (b *taskBridge) ActiveRunID() string {
	if tasks := b.Running(); len(tasks) > 0 {
		return tasks[len(tasks)-1].RunID
	}
	return ""
}

// HasRunningWork reports whether any of this call's tasks is running.
func (b *taskBridge) HasRunningWork() bool { return len(b.Running()) > 0 }

// HasRuns is true while a run of this call has not settled.
func (b *taskBridge) HasRuns() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.runs) > 0
}

func newRunID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

// Delegate registers a new task. It reports false when there was no request.
func (b *taskBridge) Delegate(handle, request string) (livevoice.Delegation, bool) {
	text := livevoice.TrimJS(request)
	if text == "" {
		return livevoice.Delegation{}, false
	}
	runID := newRunID()
	b.mu.Lock()
	b.runs[runID] = &runRecord{handle: handle, request: text}
	b.order = append(b.order, runID)
	taskID := b.taskIDLocked(runID)
	b.mu.Unlock()
	return livevoice.Delegation{TaskID: taskID, RunID: runID, Start: func() { go b.run(runID, text) }}, true
}

func (b *taskBridge) run(runID, request string) {
	result, err := b.engine.Run(context.Background(), b.userID, request, RunOptions{
		RunID: runID, AgentID: b.agentID, ConversationID: b.conversationID,
		TriggerSource: "voice_live", Source: "voice_live", ChatID: b.sessionID, VoiceSessionID: b.sessionID,
		LatencyPriority: "interactive", RawUserMessage: request,
	})
	if err != nil {
		b.log.Warn("Voice task failed", "runId", runID, "error", err.Error())
		b.settle(runID, "failed", "", err)
		return
	}
	status := result.Status
	if status == "" {
		status = "completed"
	}
	b.settle(runID, status, result.Content, nil)
}

func (b *taskBridge) settle(runID, status, content string, runErr error) {
	b.mu.Lock()
	record := b.runs[runID]
	var snapshot runRecord
	if record != nil {
		snapshot = *record
	}
	delete(b.runs, runID)
	b.dropOrder(runID)
	b.mu.Unlock()

	b.session.PublishTask(runID, status, "")
	if record == nil || snapshot.delivered || snapshot.cancelled {
		b.session.ReleaseIfIdle()
		return
	}
	reply := ""
	if status == "completed" {
		reply = livevoice.TrimJS(content)
	}
	request := b.request(runID, &snapshot)
	var outcome string
	if reply != "" {
		outcome = b.render("voice/task_finished.md", map[string]string{"request": request, "outcome": reply})
	} else {
		var details []string
		if runErr != nil {
			details = append(details, "Reported error: "+b.sanitize(runErr))
		}
		if content != "" {
			details = append(details, "Partial output: "+livevoice.TrimJS(content))
		}
		outcome = b.render("voice/task_failed.md", map[string]string{
			"request": request, "status": status, "details": strings.Join(details, "\n"),
		})
	}
	b.session.DeliverTaskOutcome(snapshot.handle, runID, outcome, reply)
}

func (b *taskBridge) dropOrder(runID string) {
	for i, id := range b.order {
		if id == runID {
			b.order = append(b.order[:i], b.order[i+1:]...)
			return
		}
	}
}

func (b *taskBridge) ownerRuns() []BackgroundRun {
	return b.engine.BackgroundRuns(b.userID, b.agentID)
}

// CheckTasks lists every task the owner has running with this agent.
func (b *taskBridge) CheckTasks() map[string]any {
	runs := b.ownerRuns()
	tasks := make([]map[string]any, len(runs))
	for i, run := range runs {
		tasks[i] = b.describe(run)
	}
	if len(tasks) == 0 {
		return map[string]any{"tasks": tasks, "note": "No task is running."}
	}
	return map[string]any{"tasks": tasks}
}

func (b *taskBridge) describe(run BackgroundRun) map[string]any {
	var seconds any
	if started, err := time.Parse(time.RFC3339Nano, run.StartedAt); err == nil {
		seconds = int(time.Since(started).Seconds() + 0.5)
	}
	steps := run.RecentSteps
	if steps == nil {
		steps = []RunStep{}
	}
	return map[string]any{
		"task_id": b.taskID(run.RunID), "request": run.Request, "status": run.Status,
		"started_in": b.origin(run), "running_for_seconds": seconds, "recent_steps": steps,
	}
}

func (b *taskBridge) origin(run BackgroundRun) string {
	b.mu.Lock()
	_, mine := b.runs[run.RunID]
	b.mu.Unlock()
	switch {
	case mine:
		return "this call"
	case run.Channel == "voice_live":
		return "an earlier call"
	case run.Channel == "web":
		return "the chat"
	}
	return run.Channel
}

// RunTool answers the live model's task tools.
func (b *taskBridge) RunTool(name string, args map[string]any) map[string]any {
	switch name {
	case "check_tasks":
		return b.CheckTasks()
	case "update_task":
		return b.act("instruct", args["task_id"], map[string]any{"instruction": args["instruction"]})
	case "cancel_task":
		return b.act("cancel", args["task_id"], nil)
	}
	return map[string]any{"error": "There is no tool named " + name + "."}
}

func (b *taskBridge) act(action string, taskID any, extra map[string]any) map[string]any {
	runs := b.ownerRuns()
	runID := b.runIDFor(taskID, runs)
	if runID == "" {
		message := "No task is running."
		if len(runs) > 0 {
			message = fmt.Sprintf("No running task has task_id %q. Use one of these.", jsString(taskID))
		}
		tasks := make([]map[string]any, len(runs))
		for i, run := range runs {
			tasks[i] = b.describe(run)
		}
		return map[string]any{"error": message, "tasks": tasks}
	}
	args := map[string]any{"action": action, "run_id": runID}
	for k, v := range extra {
		args[k] = v
	}
	result := b.engine.ApplyBackgroundAction(b.userID, b.agentID, runs, b.sessionID, args)
	// The live model stopped it and has already said so.
	if cancelled, _ := result["cancelled"].(bool); action == "cancel" && cancelled {
		b.mu.Lock()
		if record := b.runs[runID]; record != nil {
			record.cancelled = true
		}
		b.mu.Unlock()
	}
	out := map[string]any{"task_id": b.taskID(runID)}
	for k, v := range result {
		if k != "run_id" && k != "background_tasks" {
			out[k] = v
		}
	}
	return out
}

// runIDFor finds the run a task id names. A single running task needs no id.
func (b *taskBridge) runIDFor(taskID any, runs []BackgroundRun) string {
	wanted := livevoice.TrimJS(jsString(taskID))
	if wanted == "" {
		if len(runs) == 1 {
			return runs[0].RunID
		}
		return ""
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	for _, run := range runs {
		if run.RunID == wanted || b.taskIDs[run.RunID] == wanted {
			return run.RunID
		}
	}
	return ""
}

func (b *taskBridge) taskID(runID string) string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.taskIDLocked(runID)
}

func (b *taskBridge) taskIDLocked(runID string) string {
	if id, ok := b.taskIDs[runID]; ok {
		return id
	}
	id := strconv.Itoa(len(b.taskIDs) + 1)
	b.taskIDs[runID] = id
	return id
}

func (b *taskBridge) request(runID string, record *runRecord) string {
	request := ""
	if record != nil {
		request = record.request
	}
	if request == "" {
		if meta, ok := b.engine.RunMeta(runID); ok {
			request = meta.Request
		}
	}
	return clampRequest(request)
}

// label is text the live model speaks from; it carries no task number it could
// read out.
func (b *taskBridge) label(runID string, record *runRecord) string {
	return `the task "` + b.request(runID, record) + `"`
}

// Present handles an outbox delivery for a run this session started: it
// arrives on the call instead of a chat channel.
func (b *taskBridge) Present(entry Delivery) {
	content := livevoice.TrimJS(entry.Content)
	if content == "" {
		return
	}
	b.mu.Lock()
	record := b.runs[entry.RunID]
	var snapshot *runRecord
	handle := ""
	if record != nil {
		copied := *record
		snapshot = &copied
		handle = record.handle
	}
	b.mu.Unlock()
	task := b.label(entry.RunID, snapshot)

	if entry.MessageKind == KindFinal {
		if record != nil {
			b.mu.Lock()
			record.delivered = true
			b.mu.Unlock()
		}
		b.session.TellOutcome(handle, b.render("voice/task_finished.md", map[string]string{
			"request": b.request(entry.RunID, snapshot), "outcome": content,
		}), entry.RunID, content)
		return
	}
	// The live model already acknowledged the hand-off in its own words.
	if entry.MessageKind == KindAck || entry.Kind == "ack" {
		b.session.Inform(handle, task+" started: "+content, nil)
		return
	}
	if entry.ExpectsReply || entry.LivenessStatus == "blocked" || entry.LivenessStatus == "waiting" {
		b.session.Tell(handle, task+" needs the owner:\n"+content, livevoice.TellOpts{})
		return
	}
	// The task chose to say this, unlike the heartbeat's progress lines.
	if entry.MessageKind == KindInterim {
		b.session.Tell(handle, "News from "+task+":\n"+content, livevoice.TellOpts{})
		return
	}
	// Once the task has answered, an update still waiting for the line is out of date.
	stillTrue := func() bool {
		b.mu.Lock()
		defer b.mu.Unlock()
		current := b.runs[entry.RunID]
		return current != nil && !current.delivered && !current.cancelled
	}
	b.session.OfferProgress(handle, "Progress on "+task+":\n"+content, stillTrue)
}

// StatusReport is what this call's running work is doing right now, from the
// run's own steps, or nil when there is nothing to report: a task waiting for
// the owner's answer already asked its question.
func (b *taskBridge) StatusReport() *livevoice.StatusReport {
	owned := b.ownerRuns()
	var runs []BackgroundRun
	b.mu.Lock()
	for _, run := range owned {
		if record, ok := b.runs[run.RunID]; ok && !record.delivered && run.Status == "running" {
			runs = append(runs, run)
		}
	}
	lastHandle := ""
	if len(runs) > 0 {
		if record := b.runs[runs[len(runs)-1].RunID]; record != nil {
			lastHandle = record.handle
		}
	}
	b.mu.Unlock()
	if len(runs) == 0 {
		return nil
	}
	facts := make([]string, len(runs))
	steps := make([]string, len(runs))
	for i, run := range runs {
		line := `- "` + clampRequest(run.Request) + `"`
		if started, err := time.Parse(time.RFC3339Nano, run.StartedAt); err == nil {
			line += fmt.Sprintf(", running for %d seconds", int(time.Since(started).Seconds()+0.5))
		}
		if len(run.RecentSteps) > 0 {
			latest := run.RecentSteps[len(run.RecentSteps)-1]
			line += fmt.Sprintf(", latest step (%s): %s", latest.Status, truncateUnits(latest.Step, maxStatusStepChars))
			steps[i] = latest.Step
		} else {
			line += ", no step recorded yet"
		}
		facts[i] = line
	}
	return &livevoice.StatusReport{Handle: lastHandle, Facts: strings.Join(facts, "\n"), LatestStep: strings.Join(steps, "\n")}
}

// CancelFromScreen is the call screen's stop button; without a run id it stops
// this call's newest task. The live model is told, since it did not do this
// itself.
func (b *taskBridge) CancelFromScreen(runID string) map[string]any {
	b.mu.Lock()
	_, known := b.runs[runID]
	b.mu.Unlock()
	target := runID
	if runID == "" || !known {
		target = b.ActiveRunID()
	}
	if target == "" {
		return map[string]any{"cancelled": false}
	}
	cancelled := b.engine.Abort(target, b.userID, "voice_user_cancelled")
	if cancelled {
		b.mu.Lock()
		record := b.runs[target]
		var snapshot runRecord
		if record != nil {
			record.cancelled = true
			snapshot = *record
		}
		b.mu.Unlock()
		b.session.Inform(snapshot.handle, "The owner stopped "+b.label(target, &snapshot)+" from the call screen.", nil)
	}
	return map[string]any{"cancelled": cancelled, "runId": target}
}

// AbortAll stops every run of this call.
func (b *taskBridge) AbortAll(reason string) {
	ids, _ := b.records()
	for _, id := range ids {
		b.engine.Abort(id, b.userID, reason)
	}
}

func truncateUnits(s string, max int) string {
	if u := utf16Units(s); len(u) > max {
		return string(utf16Decode(u[:max]))
	}
	return s
}

// runningTasksForPrompt describes what the owner has running as a call
// connects, for the opening prompt.
func (b *taskBridge) runningTasksForPrompt() []map[string]any {
	tasks, _ := b.CheckTasks()["tasks"].([]map[string]any)
	return tasks
}
