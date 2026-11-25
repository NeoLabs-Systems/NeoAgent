package tasks

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"regexp"
	"strings"
	"sync"
	"time"

	_ "time/tzdata" // zone names must resolve on servers without a zoneinfo directory

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/cron"
)

// Runtime owns the scheduled tasks: it stores them, schedules and runs them,
// fires them from events and polls.
type Runtime struct {
	cfg  Config
	repo repository
	log  *slog.Logger

	mu          sync.Mutex
	started     bool
	stopping    bool
	state       string
	lastError   string
	ctx         context.Context
	cancel      context.CancelFunc
	jobs        map[int64]*cron.Job
	pollers     []*cron.Job
	running     map[string]bool // userID:taskID of executions that are running or queued
	executions  sync.WaitGroup
	polls       map[string]chan struct{}
	leadTimes   map[int64]string
	queues      map[int64]*eventQueue
	polledAt    map[int64]time.Time
	adapters    map[string]*Adapter
	adapterList []*Adapter
}

// New builds the runtime. Call Start to begin scheduling.
func New(cfg Config) *Runtime {
	adapters := make(map[string]*Adapter, len(triggerAdapters))
	for _, a := range triggerAdapters {
		adapters[a.Type] = a
	}
	log := cfg.Log
	if log == nil {
		log = slog.Default()
	}
	return &Runtime{
		cfg: cfg, repo: repository{db: cfg.DB}, log: log, state: "idle",
		jobs: map[int64]*cron.Job{}, running: map[string]bool{}, polls: map[string]chan struct{}{},
		leadTimes: map[int64]string{}, queues: map[int64]*eventQueue{}, polledAt: map[int64]time.Time{},
		adapters: adapters, adapterList: triggerAdapters,
	}
}

// Adapters lists every trigger type with its label and settings hint, in
// catalog order, for the model's task tools.
func (r *Runtime) Adapters() []Adapter {
	out := make([]Adapter, len(r.adapterList))
	for i, a := range r.adapterList {
		out[i] = *a
	}
	return out
}

func (r *Runtime) adapter(triggerType string) *Adapter {
	return r.adapters[jsv.Trim(triggerType)]
}

// errors the routes show as they are written.
var (
	errTaskNotFound = errors.New("Task not found")
	errTaskName     = errors.New("Task name is required.")
	errTaskPrompt   = errors.New("Task prompt is required.")
)

// normalizeStoredString reads a chat address that may have been stored as
// JSON text (a quoted string or a bare number).
func normalizeStoredString(v any) string {
	if v == nil {
		return ""
	}
	s, ok := v.(string)
	if !ok {
		return jsv.Trim(jsv.Text(v))
	}
	current := jsv.Trim(s)
	for i := 0; i < 2; i++ {
		if current == "" {
			return ""
		}
		parsed, err := jsv.Decode([]byte(current))
		if err != nil {
			return current
		}
		switch p := parsed.(type) {
		case string:
			current = jsv.Trim(p)
			continue
		case float64:
			return current
		}
		return ""
	}
	return current
}

// notifyTargetOf is the destination a task config names, if complete.
func notifyTargetOf(platform, to any) *Target {
	p, t := normalizeStoredString(platform), normalizeStoredString(to)
	if p == "" || t == "" {
		return nil
	}
	return &Target{p, t}
}

func (r *Runtime) resolveAgent(ctx context.Context, userID int64, candidate any) (string, error) {
	text := ""
	if jsv.Truthy(candidate) {
		text = jsv.String(candidate)
	}
	return r.cfg.Agents.Resolve(ctx, userID, text)
}

func (r *Runtime) isMain(ctx context.Context, userID int64, agentID string) bool {
	ok, _ := r.cfg.Agents.IsMain(ctx, userID, agentID)
	return ok
}

// asObject is normalizeJsonObject: an object is copied, JSON text that holds
// an object is read, anything else is an empty object.
func asObject(v any) *jsv.Object {
	switch v := v.(type) {
	case *jsv.Object:
		return v.Clone()
	case map[string]any:
		o := jsv.NewObject()
		for key, value := range v {
			o.Set(key, value)
		}
		return o
	case nil:
		return jsv.NewObject()
	case string:
		if v == "" {
			return jsv.NewObject()
		}
		if o := jsv.ParseObject(v); o != nil {
			return o
		}
	case sql.NullString:
		return asObject(v.String)
	case bool, float64:
		if !jsv.Truthy(v) {
			return jsv.NewObject()
		}
		if o := jsv.ParseObject(jsv.String(v)); o != nil {
			return o
		}
	}
	return jsv.NewObject()
}

func isTaskLoopPaused(taskConfig *jsv.Object) bool {
	budget, _ := taskConfig.Val("loopBudget").(*jsv.Object)
	isTrue := func(v any) bool { return v == true || v == "true" }
	return isTrue(budget.Val("paused")) || isTrue(budget.Val("pause")) ||
		isTrue(taskConfig.Val("loopPaused")) || isTrue(taskConfig.Val("loop_paused"))
}

func finishesOnTime(triggerConfig *jsv.Object) bool {
	return triggerConfig.Val("finishOnTime") == true || triggerConfig.Val("finish_on_time") == true
}

// userZone is the user's own time zone, nil when they have not set a usable one.
func (r *Runtime) userZone(ctx context.Context, userID int64) *time.Location {
	value, ok, err := r.repo.userSetting(ctx, userID, "timezone")
	if err != nil || !ok {
		return nil
	}
	return loadZone(value)
}

var offsetZone = regexp.MustCompile(`^([+-])(\d{2}):(\d{2})$`)

// loadZone resolves an IANA name or a fixed offset such as "+05:30".
func loadZone(name string) *time.Location {
	name = jsv.Trim(name)
	if name == "" {
		return nil
	}
	if m := offsetZone.FindStringSubmatch(name); m != nil {
		hours, _ := jsv.ParseInt(m[2])
		minutes, _ := jsv.ParseInt(m[3])
		seconds := hours*3600 + minutes*60
		if m[1] == "-" {
			seconds = -seconds
		}
		return time.FixedZone(name, seconds)
	}
	loc, err := time.LoadLocation(name)
	if err != nil {
		return nil
	}
	return loc
}

func (r *Runtime) validation(ctx context.Context, userID int64, agentID string, taskID int64) *validation {
	return &validation{
		ctx: ctx, db: r.cfg.DB, userID: userID, agentID: agentID, taskID: taskID,
		hasIntegrations: r.cfg.Integrations != nil, timeZone: r.userZone(ctx, userID),
	}
}

// ---- catalog ------------------------------------------------------------------

// CatalogEntry is one trigger type a user may choose, with whether their
// agent has what it needs.
type CatalogEntry struct {
	Type        string  `json:"type"`
	Label       string  `json:"label"`
	ProviderKey *string `json:"providerKey"`
	AppKey      *string `json:"appKey"`
	Available   bool    `json:"available"`
}

func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// TriggerCatalog lists the trigger types and whether each is available to the agent.
func (r *Runtime) TriggerCatalog(ctx context.Context, userID int64, agentID string) ([]CatalogEntry, error) {
	agentID, err := r.resolveAgent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	out := make([]CatalogEntry, 0, len(r.adapterList))
	for _, a := range r.adapterList {
		available := true
		switch a.Type {
		case "schedule", "manual", "webhook":
		default:
			if available, err = r.hasConnectedApp(ctx, userID, agentID, a.ProviderKey, a.AppKey); err != nil {
				return nil, err
			}
		}
		out = append(out, CatalogEntry{a.Type, a.Label, nilIfEmpty(a.ProviderKey), nilIfEmpty(a.AppKey), available})
	}
	return out, nil
}

func (r *Runtime) hasConnectedApp(ctx context.Context, userID int64, agentID, providerKey, appKey string) (bool, error) {
	if providerKey == "" || r.cfg.Integrations == nil {
		return true, nil
	}
	rows, err := r.cfg.DB.W.QueryContext(ctx, `SELECT status, app_key FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?`, userID, agentID, providerKey)
	if err != nil {
		return false, err
	}
	defer rows.Close()
	for rows.Next() {
		var status, app sql.NullString
		if err := rows.Scan(&status, &app); err != nil {
			return false, err
		}
		if status.String == "connected" && (appKey == "" || jsv.Trim(app.String) == jsv.Trim(appKey)) {
			return true, nil
		}
	}
	return false, rows.Err()
}

// ---- saving tasks ------------------------------------------------------------------

// assertDeliveryAllowed is checked when a destination is set, not on every
// save, so a task whose saved destination stopped being allowed can still be
// renamed, paused or deleted.
func (r *Runtime) assertDeliveryAllowed(userID int64, agentID string, taskConfig *jsv.Object, previous *previousTarget) error {
	target := notifyTargetOf(taskConfig.Val("notifyPlatform"), taskConfig.Val("notifyTo"))
	if target == nil || r.cfg.Messaging == nil {
		return nil
	}
	if previous != nil && previous.agentID == agentID && previous.target != nil && *previous.target == *target {
		return nil
	}
	if r.cfg.Messaging.IsRefusedSharedRecipient(userID, agentID, *target) {
		return fmt.Errorf("The shared %s account can only deliver to your own chat. Choose your own chat or the default channel.", target.Platform)
	}
	return nil
}

type previousTarget struct {
	agentID string
	target  *Target
}

// CreateTask stores a task from a request body and schedules it.
func (r *Runtime) CreateTask(ctx context.Context, userID int64, agentID string, input *jsv.Object) (*jsv.Object, error) {
	agent, err := r.resolveAgent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	requested, _ := firstSet(input, "taskConfig", "task_config")
	if err := r.assertDeliveryAllowed(userID, agent, asObject(requested), nil); err != nil {
		return nil, err
	}
	normalized, err := r.normalizeTaskInput(ctx, userID, input, agent, nil)
	if err != nil {
		return nil, err
	}
	taskID, err := r.repo.create(ctx, userID, normalized)
	if err != nil {
		return nil, err
	}
	if poll := r.adapter(normalized.TriggerType).Poll; poll != nil && poll.InitialCheckpoint != nil {
		if err := r.repo.markTriggered(ctx, taskID, userID, poll.InitialCheckpoint()); err != nil {
			return nil, err
		}
	}
	row, err := r.repo.get(ctx, taskID, userID)
	if err != nil {
		return nil, err
	}
	if normalized.Enabled {
		r.registerTask(ctx, *row)
	}
	return r.serialize(ctx, *row, userID)
}

// firstSet is `a ?? b ?? ...` over members of the request: the first one that
// is neither missing nor null.
func firstSet(o *jsv.Object, keys ...string) (any, bool) {
	for _, k := range keys {
		if v, ok := o.Get(k); ok && v != nil {
			return v, true
		}
	}
	return nil, false
}

// UpdateTask changes a stored task and reschedules it.
func (r *Runtime) UpdateTask(ctx context.Context, taskID, userID int64, updates *jsv.Object) (*jsv.Object, error) {
	existing, err := r.repo.get(ctx, taskID, userID)
	if err != nil {
		return nil, err
	}
	if existing == nil {
		return nil, errTaskNotFound
	}
	existingConfig := asObject(existing.TaskConfig)
	existingAgent := existing.AgentID.String
	newAgent, err := r.resolveAgent(ctx, userID, orDefault(updates, existingAgent, "agentId", "agent_id"))
	if err != nil {
		return nil, err
	}
	previousAgent, err := r.resolveAgent(ctx, userID, existingAgent)
	if err != nil {
		return nil, err
	}
	nextConfig := existingConfig
	if v, ok := firstSet(updates, "taskConfig", "task_config"); ok {
		nextConfig = asObject(v)
	}
	if err := r.assertDeliveryAllowed(userID, newAgent, nextConfig, &previousTarget{
		agentID: previousAgent, target: notifyTargetOf(existingConfig.Val("notifyPlatform"), existingConfig.Val("notifyTo")),
	}); err != nil {
		return nil, err
	}

	input := jsv.NewObject()
	setFirst := func(key string, fallback any, keys ...string) {
		if v, ok := firstSet(updates, keys...); ok {
			input.Set(key, v)
		} else {
			input.Set(key, fallback)
		}
	}
	setFirst("name", existing.Name, "name")
	setFirst("triggerType", existing.TriggerType.String, "triggerType", "trigger_type")
	setFirst("triggerConfig", asObject(existing.TriggerConfig), "triggerConfig", "trigger_config")
	if v, ok := updates.Get("prompt"); ok {
		input.Set("prompt", v)
	}
	setFirst("enabled", existing.Enabled, "enabled")
	if v, ok := updates.Get("model"); ok {
		input.Set("model", v)
	}
	setFirst("taskType", existing.TaskType.String, "taskType", "task_type")
	setFirst("taskConfig", asObject(existing.TaskConfig), "taskConfig", "task_config")
	normalized, err := r.normalizeTaskInput(ctx, userID, input, newAgent, existing)
	if err != nil {
		return nil, err
	}
	if err := r.repo.update(ctx, taskID, userID, normalized); err != nil {
		return nil, err
	}
	updated, err := r.repo.get(ctx, taskID, userID)
	if err != nil {
		return nil, err
	}
	if poll := r.adapter(normalized.TriggerType).Poll; poll != nil && poll.InitialCheckpoint != nil &&
		(!updated.LastTriggerFingerprint.Valid || updated.LastTriggerFingerprint.String == "" || (!existing.Enabled && normalized.Enabled)) {
		if err := r.repo.markTriggered(ctx, taskID, userID, poll.InitialCheckpoint()); err != nil {
			return nil, err
		}
	}
	r.unregisterTask(taskID)
	row, err := r.repo.get(ctx, taskID, userID)
	if err != nil {
		return nil, err
	}
	if normalized.Enabled {
		r.registerTask(ctx, *row)
	}
	return r.serialize(ctx, *row, userID)
}

// orDefault is `updates.agentId ?? updates.agent_id ?? fallback`.
func orDefault(o *jsv.Object, fallback any, keys ...string) any {
	if v, ok := firstSet(o, keys...); ok {
		return v
	}
	return fallback
}

// DeleteTask removes a task and stops scheduling it.
func (r *Runtime) DeleteTask(ctx context.Context, taskID, userID int64) error {
	existing, err := r.repo.get(ctx, taskID, userID)
	if err != nil {
		return err
	}
	if existing == nil {
		return errTaskNotFound
	}
	r.unregisterTask(taskID)
	return r.repo.delete(ctx, taskID, userID)
}

// ListTasks lists an agent's tasks, newest first.
func (r *Runtime) ListTasks(ctx context.Context, userID int64, agentID string) ([]*jsv.Object, error) {
	agentID, err := r.resolveAgent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	rows, err := r.repo.listForAgent(ctx, userID, agentID, r.isMain(ctx, userID, agentID))
	if err != nil {
		return nil, err
	}
	out := make([]*jsv.Object, len(rows))
	for i, row := range rows {
		if out[i], err = r.serialize(ctx, row, userID); err != nil {
			return nil, err
		}
	}
	return out, nil
}

// GeofenceTasks lists the user's enabled geofence tasks on every agent.
func (r *Runtime) GeofenceTasks(ctx context.Context, userID int64) ([]GeofenceTask, error) {
	rows, err := r.repo.listEnabledEvent(ctx, userID, "", "geofence_event")
	if err != nil {
		return nil, err
	}
	out := make([]GeofenceTask, len(rows))
	for i, row := range rows {
		out[i] = GeofenceTask{ID: row.ID, TriggerConfig: row.TriggerConfig.String}
	}
	return out, nil
}

// GeofenceTask is an enabled geofence task: each task watches one place.
type GeofenceTask struct {
	ID int64
	// TriggerConfig is the task's stored trigger_config text.
	TriggerConfig string
}

// normalizeTaskInput checks a request and turns it into a stored task.
func (r *Runtime) normalizeTaskInput(ctx context.Context, userID int64, input *jsv.Object, agentID string, existing *taskRow) (normalizedTask, error) {
	name := jsv.Trim(jsv.Text(input.Val("name")))
	if name == "" && existing != nil {
		name = jsv.Trim(existing.Name)
	}
	if name == "" {
		return normalizedTask{}, errTaskName
	}
	triggerType := jsv.Trim(jsv.Text(pick(input, "triggerType", "trigger_type")))
	if triggerType == "" && existing != nil {
		triggerType = jsv.Trim(existing.TriggerType.String)
	}
	if triggerType == "" {
		triggerType = "schedule"
	}
	adapter := r.adapter(triggerType)
	if adapter == nil {
		known := make([]string, len(r.adapterList))
		for i, a := range r.adapterList {
			known[i] = a.Type
		}
		return normalizedTask{}, fmt.Errorf(`Unsupported trigger type: %s. Use one of: %s. A time, once or repeating, is "schedule" with config.mode "one_time" or "recurring".`, triggerType, strings.Join(known, ", "))
	}

	taskType := jsv.Trim(jsv.Text(pick(input, "taskType", "task_type")))
	if taskType == "" && existing != nil {
		taskType = jsv.Trim(existing.TaskType.String)
	}
	if taskType == "" {
		taskType = "agent_prompt"
	}
	// A sent config replaces the stored one, so a removed key stays removed.
	var taskConfig *jsv.Object
	if v, ok := firstSet(input, "taskConfig", "task_config"); ok {
		taskConfig = asObject(v)
	} else if existing != nil {
		taskConfig = asObject(existing.TaskConfig)
	} else {
		taskConfig = jsv.NewObject()
	}
	if v, ok := input.Get("prompt"); ok {
		taskConfig.Set("prompt", jsv.Trim(jsv.Text(v)))
	}
	taskConfig.Delete("callTo")
	taskConfig.Delete("callGreeting")
	if v, ok := input.Get("model"); ok {
		if model := jsv.Trim(jsv.Text(v)); model != "" {
			taskConfig.Set("model", jsv.Trim(jsv.String(v)))
		} else {
			taskConfig.Delete("model")
		}
	}
	if jsv.Trim(jsv.Text(taskConfig.Val("prompt"))) == "" {
		return normalizedTask{}, errTaskPrompt
	}

	var rawTrigger any
	if v, ok := firstSet(input, "triggerConfig", "trigger_config"); ok {
		rawTrigger = v
	} else if triggerType == "schedule" {
		mode := "recurring"
		if jsv.Truthy(input.Val("oneTime")) || jsv.Truthy(input.Val("one_time")) {
			mode = "one_time"
		}
		var existingCron, existingRunAt any
		if existing != nil {
			existingCron, existingRunAt = orNil(existing.CronExpression.String), orNil(existing.RunAt.String)
		}
		rawTrigger = jsv.NewObject().Set("mode", mode).
			Set("cronExpression", orElseNil(pick(input, "cronExpression", "cron_expression"), existingCron)).
			Set("runAt", orElseNil(pick(input, "runAt", "run_at"), existingRunAt))
	} else if existing != nil {
		rawTrigger = existing.TriggerConfig.String
	}
	taskID := int64(0)
	if existing != nil {
		taskID = existing.ID
	}
	triggerConfig, err := adapter.Validate(r.validation(ctx, userID, agentID, taskID), asObject(rawTrigger))
	if err != nil {
		return normalizedTask{}, err
	}
	enabled := true
	if v, ok := input.Get("enabled"); ok {
		enabled = v != false
	} else if existing != nil {
		enabled = existing.Enabled
	}
	out := normalizedTask{
		AgentID: agentID, Name: name, TriggerType: triggerType, TriggerConfig: triggerConfig, TaskType: taskType,
		TaskConfig: taskConfig, Enabled: enabled,
	}
	if triggerType == "schedule" {
		switch triggerConfig.Val("mode") {
		case "recurring":
			out.LegacyCron = triggerConfig.Val("cronExpression")
		case "one_time":
			out.LegacyRunAt = triggerConfig.Val("runAt")
			out.LegacyOneTime = true
		}
	}
	return out, nil
}

// orString is `value || fallback` for text.
func orString(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

// orElseNil is `first || second || null`.
func orElseNil(first, second any) any {
	if jsv.Truthy(first) {
		return first
	}
	return orNil(second)
}

// serialize is a task as the routes show it.
func (r *Runtime) serialize(ctx context.Context, row taskRow, userID int64) (*jsv.Object, error) {
	triggerType := jsv.Trim(row.TriggerType.String)
	if triggerType == "" {
		triggerType = "schedule"
	}
	triggerConfig := asObject(row.TriggerConfig)
	taskConfig := asObject(row.TaskConfig)
	taskConfig.Delete("callTo")
	taskConfig.Delete("callGreeting")
	agentID := row.AgentID.String
	if agentID == "" {
		var err error
		if agentID, err = r.resolveAgent(ctx, userID, nil); err != nil {
			return nil, err
		}
	}
	if target := r.configuredNotifyTarget(userID, agentID, taskConfig); target != nil {
		taskConfig.Set("notifyPlatform", target.Platform).Set("notifyTo", target.To)
	}
	var nextRun, average any
	if triggerType == "schedule" {
		nextRun = r.nextRun(ctx, triggerConfig, userID)
		if seconds, ok, err := r.repo.averageRunSeconds(ctx, row.ID, userID); err != nil {
			return nil, err
		} else if ok {
			average = math.Floor(seconds + 0.5)
		}
	}
	lastRun := orNil(row.LatestRunStartedAt.String)
	if lastRun == nil {
		lastRun = orNil(row.LastRun.String)
	}
	return jsv.NewObject().
		Set("id", float64(row.ID)).Set("name", row.Name).Set("triggerType", triggerType).Set("triggerConfig", triggerConfig).
		Set("triggerSummary", r.summarizeTrigger(triggerType, triggerConfig)).Set("nextRun", nextRun).
		Set("averageRunSeconds", average).Set("enabled", row.Enabled).Set("lastRun", lastRun).
		Set("lastRunId", orNil(row.LatestRunID.String)).Set("lastRunStatus", orNil(row.LatestRunStatus.String)).
		Set("lastRunError", orNil(row.LatestRunError.String)).Set("lastTriggeredAt", orNil(row.LastTriggeredAt.String)).
		Set("taskType", orString(row.TaskType.String, "agent_prompt")).Set("taskConfig", taskConfig).
		Set("loopPaused", isTaskLoopPaused(taskConfig)).Set("prompt", textOrEmpty(taskConfig.Val("prompt"))).
		Set("model", orNil(taskConfig.Val("model"))).Set("agentId", agentID).
		Set("connectionLabel", orNil(triggerConfig.Val("accountEmail"))), nil
}

func (r *Runtime) summarizeTrigger(triggerType string, config *jsv.Object) string {
	if a := r.adapter(triggerType); a != nil && a.Summarize != nil {
		if s := a.Summarize(config); s != "" {
			return s
		}
	}
	return triggerType
}

// nextRun is when a schedule task runs next, nil when it has no time ahead.
func (r *Runtime) nextRun(ctx context.Context, config *jsv.Object, userID int64) any {
	if config.Val("mode") == "one_time" {
		return orNil(config.Val("runAt"))
	}
	next, ok, err := findNextRun(jsv.Text(config.Val("cronExpression")), time.Now(), r.userZone(ctx, userID))
	if err != nil || !ok {
		return nil
	}
	return jsv.ISO(next)
}

// configuredNotifyTarget is the destination saved in the task config; one the
// shared account would refuse falls back to the user's own chat.
func (r *Runtime) configuredNotifyTarget(userID int64, agentID string, taskConfig *jsv.Object) *Target {
	target := notifyTargetOf(taskConfig.Val("notifyPlatform"), taskConfig.Val("notifyTo"))
	if target == nil || r.cfg.Messaging == nil {
		return target
	}
	reachable := r.cfg.Messaging.ReachableSharedTarget(userID, agentID, *target)
	return &reachable
}
