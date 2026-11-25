package tasks

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/cron"
)

const (
	// maxRecurringStartDelay is how late a recurring run may start and still
	// run: a run that waited longer (a busy or sleeping server) is skipped.
	maxRecurringStartDelay = 90 * time.Second
	// maxAutonomousRetries is how many times a failed run is tried again.
	maxAutonomousRetries = 1
	everyMinute          = "* * * * *"
)

// Status describes the runtime's scheduling.
type Status struct {
	State         string
	Started       bool
	Stopping      bool
	ScheduledJobs int
	ActivePolls   []string
	LastError     string
}

// Status reports what the runtime is doing.
func (r *Runtime) Status() Status {
	r.mu.Lock()
	defer r.mu.Unlock()
	polls := make([]string, 0, len(r.polls))
	for name := range r.polls {
		polls = append(polls, name)
	}
	return Status{r.state, r.started, r.stopping, len(r.jobs), polls, r.lastError}
}

func (r *Runtime) context() context.Context {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.ctx == nil || r.ctx.Err() != nil && !r.stopping {
		r.ctx, r.cancel = context.WithCancel(context.Background())
	}
	return r.ctx
}

func (r *Runtime) isStopping() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.stopping
}

func (r *Runtime) clock() cron.Clock { return r.cfg.Clock }

// Start loads the stored tasks, schedules them and starts the pollers.
func (r *Runtime) Start(ctx context.Context) error {
	r.mu.Lock()
	if r.started {
		r.mu.Unlock()
		return nil
	}
	if r.stopping {
		r.mu.Unlock()
		return errors.New("Task runtime cannot start while shutdown is in progress.")
	}
	if r.ctx == nil || r.ctx.Err() != nil {
		r.ctx, r.cancel = context.WithCancel(context.Background())
	}
	r.started, r.state, r.lastError = true, "starting", ""
	r.mu.Unlock()

	if err := r.load(ctx); err != nil {
		r.mu.Lock()
		r.lastError, r.started, r.state = err.Error(), false, "error"
		r.mu.Unlock()
		r.stopScheduling()
		return err
	}
	for _, p := range []struct {
		name string
		run  func(ctx context.Context) error
	}{{"one_time", r.runDueOneTimeTasks}, {"lead_time", r.runDueLeadTimeTasks}, {"integration", r.pollIntegrations}} {
		job, err := cron.Schedule(everyMinute, func(cron.Execution) { r.runPoll(p.name, p.run) }, cron.Options{Clock: r.clock(), Logger: r.log})
		if err != nil {
			r.mu.Lock()
			r.lastError, r.started, r.state = err.Error(), false, "error"
			r.mu.Unlock()
			r.stopScheduling()
			return err
		}
		r.mu.Lock()
		r.pollers = append(r.pollers, job)
		r.mu.Unlock()
	}
	r.mu.Lock()
	r.state = "running"
	r.mu.Unlock()
	r.log.Info("tasks started")
	return nil
}

func (r *Runtime) load(ctx context.Context) error {
	tasks, err := r.repo.listEnabled(ctx)
	if err != nil {
		return err
	}
	for _, task := range tasks {
		r.registerTask(ctx, task)
	}
	return nil
}

func (r *Runtime) stopScheduling() {
	r.mu.Lock()
	jobs, pollers := r.jobs, r.pollers
	r.jobs, r.pollers = map[int64]*cron.Job{}, nil
	r.leadTimes = map[int64]string{}
	r.mu.Unlock()
	for _, job := range jobs {
		job.Stop()
	}
	for _, job := range pollers {
		job.Stop()
	}
}

// Stop ends scheduling, cancels running tasks and waits for them to finish.
func (r *Runtime) Stop() {
	r.mu.Lock()
	if r.stopping {
		r.mu.Unlock()
		r.executions.Wait()
		return
	}
	r.started, r.stopping, r.state = false, true, "stopping"
	if r.cancel != nil {
		r.cancel()
	}
	r.mu.Unlock()
	r.stopScheduling()
	for {
		r.mu.Lock()
		busy := len(r.polls) > 0
		r.mu.Unlock()
		r.executions.Wait()
		if !busy {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	r.mu.Lock()
	r.stopping, r.state = false, "stopped"
	r.mu.Unlock()
	r.log.Info("tasks stopped")
}

// Wait returns when every run that is in progress has finished.
func (r *Runtime) Wait() { r.executions.Wait() }

// spawn runs fn as one of the runtime's tracked runs, which Stop waits for.
func (r *Runtime) spawn(fn func()) {
	r.executions.Add(1)
	go func() {
		defer r.executions.Done()
		fn()
	}()
}

// runPoll runs one poll unless the previous one of the same name is still going.
func (r *Runtime) runPoll(name string, fn func(ctx context.Context) error) {
	r.mu.Lock()
	if _, active := r.polls[name]; active || r.stopping {
		r.mu.Unlock()
		return
	}
	done := make(chan struct{})
	r.polls[name] = done
	r.executions.Add(1)
	r.mu.Unlock()
	defer func() {
		r.mu.Lock()
		delete(r.polls, name)
		r.mu.Unlock()
		close(done)
		r.executions.Done()
	}()
	if err := fn(r.context()); err != nil && !errors.Is(err, context.Canceled) {
		r.mu.Lock()
		r.lastError = err.Error()
		r.mu.Unlock()
		r.log.Error("task poll failed", "poll", name, "error", err)
	}
}

// ---- schedules ----------------------------------------------------------------------

// RescheduleUserTasks rebuilds a user's cron jobs: recurring schedules fire on
// the user's wall clock, so a time zone change moves them.
func (r *Runtime) RescheduleUserTasks(ctx context.Context, userID int64) error {
	r.mu.Lock()
	started := r.started
	r.mu.Unlock()
	if !started {
		return nil
	}
	tasks, err := r.repo.listEnabled(ctx)
	if err != nil {
		return err
	}
	for _, task := range tasks {
		if task.UserID == userID {
			r.registerTask(ctx, task)
		}
	}
	return nil
}

func (r *Runtime) registerTask(ctx context.Context, task taskRow) {
	r.unregisterTask(task.ID)
	if !task.Enabled || orString(task.TriggerType.String, "schedule") != "schedule" {
		return
	}
	config := asObject(task.TriggerConfig)
	// The expression is in the structured config, or in the legacy column an
	// older migration may have left it in. One-time runs have none and belong to
	// the one-time poller; tasks that start early to finish on time belong to
	// the lead-time poller, and registering them here too would run them twice.
	expression := jsv.Trim(jsv.Text(pick(config, "cronExpression")))
	if expression == "" {
		expression = jsv.Trim(task.CronExpression.String)
	}
	if expression == "" || finishesOnTime(config) {
		return
	}
	userID, taskID := task.UserID, task.ID
	job, err := cron.Schedule(expression, func(e cron.Execution) {
		r.spawnExecution(taskID, userID, execMeta{scheduledAt: jsv.ISO(e.Slot), triggerType: "schedule", triggerSource: "schedule"})
	}, cron.Options{
		// A tick that starts late is let through: lateness is judged by the
		// start-delay check, which measures it from the slot the tick was for.
		MissedTolerance: maxRecurringStartDelay, Location: r.userZone(ctx, userID), Clock: r.clock(), Logger: r.log,
	})
	if err != nil {
		r.log.Error("could not schedule task", "task", taskID, "error", err)
		return
	}
	r.mu.Lock()
	r.jobs[taskID] = job
	r.mu.Unlock()
}

func (r *Runtime) unregisterTask(taskID int64) {
	r.mu.Lock()
	job := r.jobs[taskID]
	delete(r.jobs, taskID)
	delete(r.leadTimes, taskID)
	delete(r.polledAt, taskID)
	r.mu.Unlock()
	if job != nil {
		job.Stop()
	}
}

// spawnExecution runs a task in the background and logs what goes wrong.
func (r *Runtime) spawnExecution(taskID, userID int64, meta execMeta) {
	r.spawn(func() { r.executeTask(r.context(), taskID, userID, meta) })
}

// runDueOneTimeTasks launches every one-time task whose time has come. Runs
// are launched, not awaited: the poll must finish every tick, or one hung run
// would hold it open and no later one-time task would ever fire.
func (r *Runtime) runDueOneTimeTasks(ctx context.Context) error {
	tasks, err := r.repo.listDueOneTime(ctx)
	if err != nil {
		return err
	}
	for _, task := range tasks {
		if ctx.Err() != nil {
			break
		}
		if r.isRunning(task.UserID, task.ID) {
			continue
		}
		r.unregisterTask(task.ID)
		r.spawn(func() { r.runOneTimeTask(ctx, task) })
	}
	return nil
}

func (r *Runtime) runOneTimeTask(ctx context.Context, task taskRow) {
	runAt := task.RunAt.String
	if runAt == "" {
		runAt = jsv.ISO(time.Now())
	}
	result := r.executeTask(ctx, task.ID, task.UserID, execMeta{scheduledAt: runAt, oneTime: true, triggerType: "schedule", triggerSource: "schedule"})
	// A skipped run never started, so the task stays and the next poll retries
	// it. Completed or failed, the run happened: a one-time task is done either way.
	if skipped, _, _ := resultFields(result); skipped {
		return
	}
	if err := r.repo.delete(ctx, task.ID, task.UserID); err != nil {
		r.log.Error("one-time task could not be removed", "task", task.ID, "error", err)
		return
	}
	r.emit(task.UserID, "tasks:task_deleted", jsv.NewObject().Set("taskId", float64(task.ID)))
}

// runDueLeadTimeTasks starts the tasks that compensate for their own run
// duration: cron can only fire at the configured time, while these start a
// computed head start earlier so the run ends at it.
func (r *Runtime) runDueLeadTimeTasks(ctx context.Context) error {
	now := r.now()
	tasks, err := r.repo.listEnabledByTriggerTypes(ctx, []string{"schedule"})
	if err != nil {
		return err
	}
	for _, task := range tasks {
		if ctx.Err() != nil {
			break
		}
		config := asObject(task.TriggerConfig)
		if !finishesOnTime(config) {
			continue
		}
		expression := jsv.Trim(jsv.Text(pick(config, "cronExpression")))
		if expression == "" {
			expression = jsv.Trim(task.CronExpression.String)
		}
		if expression == "" {
			continue
		}
		// Look ahead from the previous minute so that the occurrence falling in
		// the current minute still counts: a task with no history yet has a zero
		// head start and must fire exactly at its configured time.
		occurrence, ok, err := findNextRun(expression, now.Add(-minute), r.userZone(ctx, task.UserID))
		if err != nil {
			r.log.Error("lead-time task has an unusable cron expression", "task", task.ID, "error", err)
			continue
		}
		if !ok {
			continue
		}
		iso := jsv.ISO(occurrence)
		r.mu.Lock()
		seen := r.leadTimes[task.ID] == iso
		r.mu.Unlock()
		if seen {
			continue
		}
		average, _, err := r.repo.averageRunSeconds(ctx, task.ID, task.UserID)
		if err != nil {
			return err
		}
		windowStart := occurrence.Add(-leadTime(average))
		if windowStart.After(now) {
			continue
		}
		r.mu.Lock()
		r.leadTimes[task.ID] = iso
		r.mu.Unlock()
		// A restart clears the bookkeeping above, so the recorded last run tells
		// whether this occurrence was already started before the restart.
		if ran, err := r.repo.ranSince(ctx, task.ID, task.UserID, now.Sub(windowStart).Seconds()); err != nil {
			return err
		} else if ran {
			continue
		}
		// Not awaited: a head start is only accurate if every due task is launched
		// on this tick rather than after the previous one has finished running.
		r.spawnExecution(task.ID, task.UserID, execMeta{scheduledAt: iso, triggerType: "schedule", triggerSource: "schedule"})
	}
	return nil
}

func (r *Runtime) isRunning(userID, taskID int64) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.running[fmt.Sprintf("%d:%d", userID, taskID)]
}

// ---- running a task ----------------------------------------------------------------------

// execMeta says why and for when a task runs.
type execMeta struct {
	scheduledAt   string
	manual        bool
	oneTime       bool
	triggerType   string
	triggerSource string
	// triggerPayload is the event that fired the task, nil for schedules.
	triggerPayload   *jsv.Object
	runID            string
	resumedFromRunID string
	resumeNote       string
}

// RunTaskNow starts a task in the background, as the Run button does.
func (r *Runtime) RunTaskNow(ctx context.Context, taskID, userID int64) (*jsv.Object, error) {
	task, err := r.repo.get(ctx, taskID, userID)
	if err != nil {
		return nil, err
	}
	if task == nil {
		return nil, errTaskNotFound
	}
	if r.isStopping() {
		return jsv.NewObject().Set("running", false).Set("skipped", true).Set("reason", "runtime_stopping"), nil
	}
	r.spawnExecution(taskID, userID, execMeta{
		scheduledAt: jsv.ISO(time.Now()), manual: true,
		triggerType: orString(task.TriggerType.String, "schedule"), triggerSource: "manual",
	})
	return jsv.NewObject().Set("running", true), nil
}

// ResumeInterruptedTask starts again a run that a restart cut off, for the
// same occurrence. It started on time, so it is not a late start.
func (r *Runtime) ResumeInterruptedTask(ctx context.Context, taskID, userID int64, scheduledAt, triggerSource, runID, resumedFromRunID, note string) any {
	return r.executeTask(ctx, taskID, userID, execMeta{
		scheduledAt: scheduledAt, manual: triggerSource == "manual", triggerType: "schedule", triggerSource: triggerSource,
		runID: runID, resumedFromRunID: resumedFromRunID, resumeNote: note,
	})
}

func skippedResult(reason string) *jsv.Object {
	return jsv.NewObject().Set("skipped", true).Set("reason", reason)
}

// resultFields reads what the runtime needs to know of a run's outcome.
func resultFields(result any) (skipped bool, errText, runID string) {
	o, ok := result.(*jsv.Object)
	if !ok {
		return false, "", ""
	}
	return jsv.Truthy(o.Val("skipped")), jsv.Text(o.Val("error")), jsv.Text(o.Val("runId"))
}

func (r *Runtime) emit(userID int64, event string, payload any) {
	if r.cfg.Emitter != nil {
		r.cfg.Emitter.EmitToUser(userID, event, payload)
	}
}

func (r *Runtime) executeTask(ctx context.Context, taskID, userID int64, meta execMeta) any {
	if ctx.Err() != nil || r.isStopping() {
		return skippedResult("runtime_stopping")
	}
	key := fmt.Sprintf("%d:%d", userID, taskID)
	r.mu.Lock()
	if r.running[key] {
		r.mu.Unlock()
		name, agent := fmt.Sprintf("Task %d", taskID), ""
		if task, _ := r.repo.get(ctx, taskID, userID); task != nil {
			name, agent = task.Name, task.AgentID.String
		}
		r.record(ctx, lifecycle{userID: userID, taskID: taskID, name: name, agentID: agent, kind: "task_skipped",
			reason: "already_running_or_queued", meta: meta})
		r.emit(userID, "tasks:task_skipped", jsv.NewObject().Set("taskId", float64(taskID)).
			Set("reason", "already_running_or_queued").Set("timestamp", jsv.ISO(time.Now())))
		return skippedResult("already_running_or_queued")
	}
	r.running[key] = true
	r.mu.Unlock()
	defer func() {
		r.mu.Lock()
		delete(r.running, key)
		r.mu.Unlock()
	}()
	result := r.executeSerial(ctx, taskID, userID, meta)
	r.publishRunFinished(ctx, taskID, userID, meta, result)
	return result
}

// publishRunFinished announces a finished run to the tasks that wait for it.
// Chained tasks carry how many runs led to them, so a loop of tasks that
// trigger each other stops instead of running forever.
func (r *Runtime) publishRunFinished(ctx context.Context, taskID, userID int64, meta execMeta, result any) {
	skipped, errText, runID := resultFields(result)
	if result == nil || (skipped && errText == "") {
		return
	}
	task, _ := r.repo.get(ctx, taskID, userID)
	chainDepth := 0.0
	if meta.triggerSource == "task_run_finished" {
		chainDepth = jsv.Number(dig(meta.triggerPayload, "triggerEvent", "chainDepth"))
		if chainDepth != chainDepth { // NaN reads as 0
			chainDepth = 0
		}
	}
	name, agent := fmt.Sprintf("Task %d", taskID), any(nil)
	if task != nil {
		name, agent = orString(task.Name, name), orNil(task.AgentID.String)
	}
	outcome, text := "succeeded", jsv.Slice(stringifyResult(result), 2000)
	if errText != "" {
		outcome, text = "failed", ""
	}
	r.PublishEvent("task_run_finished", map[string]any{
		"userId": userID, "agentId": agent, "taskId": taskID, "taskName": name, "outcome": outcome,
		"error": orNil(errText), "result": text, "runId": orNil(runID), "chainDepth": chainDepth + 1,
		"finishedAt": jsv.ISO(time.Now()),
	})
}

// stringifyResult is the text of a run's result.
func stringifyResult(result any) string {
	switch v := result.(type) {
	case nil:
		return ""
	case string:
		return v
	case *jsv.Object:
		for _, key := range []string{"content", "message", "text", "summary", "finalResponse", "final_response"} {
			if s, ok := v.Val(key).(string); ok && jsv.Trim(s) != "" {
				return s
			}
		}
		if nested := v.Val("result"); nested != nil && nested != any(v) {
			if s := stringifyResult(nested); s != "" {
				return s
			}
		}
		return ""
	}
	return jsv.String(result)
}

// lifecycle describes an entry for the timeline.
type lifecycle struct {
	userID  int64
	taskID  int64
	name    string
	agentID string
	kind    string
	runID   string
	reason  string
	err     string
	meta    execMeta
}

func (r *Runtime) record(ctx context.Context, l lifecycle) {
	if r.cfg.Timeline == nil {
		return
	}
	if _, err := r.cfg.Timeline.RecordTaskLifecycle(ctx, timelineEntry(l)); err != nil {
		r.log.Error("timeline entry failed", "task", l.taskID, "error", err)
	}
}

var _ = slog.Default
var _ = strings.TrimSpace
