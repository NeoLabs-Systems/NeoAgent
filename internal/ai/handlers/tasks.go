package handlers

import (
	"context"
	"database/sql"
	"errors"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

var taskHandlers = map[string]handler{
	"create_task": createTask,
	"list_tasks":  listTasks,
	"delete_task": deleteTask,
	"update_task": updateTask,
}

var cron5Field = regexp.MustCompile(`^(\S+\s+){4}\S+$`)

// coerceScheduleConfig: models pass the schedule as a JSON string, or as a bare
// cron expression or ISO date instead of an object.
func coerceScheduleConfig(input any) any {
	s, ok := input.(string)
	if !ok {
		return input
	}
	raw := trimSpaceJS(s)
	if raw == "" {
		return input
	}
	if strings.HasPrefix(raw, "{") || strings.HasPrefix(raw, "[") {
		if parsed, ok := dyn.Parse(raw); ok {
			return parsed
		}
		return input
	}
	if cron5Field.MatchString(raw) {
		return dyn.Ordered{{Key: "mode", Value: "recurring"}, {Key: "cronExpression", Value: raw}}
	}
	if _, ok := parseJSDate(raw); ok {
		return dyn.Ordered{{Key: "mode", Value: "one_time"}, {Key: "runAt", Value: raw}}
	}
	return input
}

// normalizeScheduleConfig reads the spellings of mode, cron and run time.
func normalizeScheduleConfig(input any) any {
	coerced := coerceScheduleConfig(input)
	obj, ok := orderedObject(coerced)
	if !ok {
		return coerced
	}
	var schedule dyn.Map
	if m, ok := obj.Get("schedule").(dyn.Map); ok {
		schedule = m
	}
	get := func(key string) any { return obj.Get(key) }
	pick := func(keys []string, scheduleKeys []string) any {
		for _, k := range keys {
			if dyn.Truthy(get(k)) {
				return get(k)
			}
		}
		for _, k := range scheduleKeys {
			if schedule != nil && dyn.Truthy(schedule[k]) {
				return schedule[k]
			}
		}
		return nil
	}
	modeCandidate := pick([]string{"mode", "type", "scheduleType", "schedule_type"}, nil)
	mode := ""
	if modeCandidate != nil {
		mode = dyn.String(modeCandidate)
	} else if dyn.Truthy(get("oneTime")) || dyn.Truthy(get("one_time")) {
		mode = "one_time"
	}
	mode = strings.ToLower(trimSpaceJS(mode))
	if mode == "once" {
		obj = obj.Set("mode", "one_time")
	} else if mode == "one_time" || mode == "recurring" {
		obj = obj.Set("mode", mode)
	}
	if cron := pick([]string{"cronExpression", "cron_expression", "cron"}, []string{"cronExpression", "cron_expression", "cron"}); cron != nil {
		obj = obj.Set("cronExpression", trimSpaceJS(dyn.String(cron)))
	}
	if runAt := pick([]string{"runAt", "run_at", "at", "when"}, []string{"runAt", "run_at", "at", "when"}); runAt != nil {
		obj = obj.Set("runAt", trimSpaceJS(dyn.String(runAt)))
	}
	if !dyn.Truthy(obj.Get("mode")) {
		if dyn.Truthy(obj.Get("runAt")) {
			obj = obj.Set("mode", "one_time")
		} else {
			obj = obj.Set("mode", "recurring")
		}
	}
	out := dyn.Ordered{}
	for _, kv := range obj {
		if kv.Key != "schedule" {
			out = append(out, kv)
		}
	}
	return out
}

// orderedObject reads a plain object, keeping its key order when it has one.
func orderedObject(v any) (dyn.Ordered, bool) {
	switch x := v.(type) {
	case dyn.Ordered:
		return append(dyn.Ordered{}, x...), true
	case dyn.Map:
		out := dyn.Ordered{}
		for _, k := range dyn.SortedKeys(x) {
			out = append(out, dyn.KV{Key: k, Value: x[k]})
		}
		return out, true
	}
	return nil, false
}

func normalizeTriggerInput(triggerType string, config any) any {
	if strings.TrimSpace(triggerType) != "schedule" {
		return config
	}
	if !dyn.Truthy(config) {
		config = dyn.Map{}
	}
	return normalizeScheduleConfig(config)
}

type resolvedTrigger struct {
	triggerType string
	config      any
	hasType     bool
	hasConfig   bool
	// configDefined is false where Node's config was undefined (a null
	// trigger_config is defined; trigger.config ?? ... can come out undefined).
	configDefined bool
}

// resolveTriggerArgs reads trigger.type/config or trigger_type/trigger_config.
func resolveTriggerArgs(args dyn.Map, fallbackType string) resolvedTrigger {
	triggerType := strings.TrimSpace(fallbackType)
	_, hasType := args["trigger_type"]
	if hasType {
		triggerType = strings.TrimSpace(dyn.Str(args["trigger_type"]))
	}
	config, hasConfig := args["trigger_config"]
	defined := hasConfig
	if trigger, ok := args["trigger"].(dyn.Map); ok {
		unified := firstNonNil(trigger, "type", "triggerType", "trigger_type")
		if unified != nil && strings.TrimSpace(dyn.String(unified)) != "" {
			triggerType = strings.TrimSpace(dyn.String(unified))
			hasType = true
		}
		_, a := trigger["config"]
		_, b := trigger["triggerConfig"]
		_, c := trigger["trigger_config"]
		if a || b || c {
			config = firstNonNil(trigger, "config", "triggerConfig", "trigger_config")
			hasConfig, defined = true, config != nil
		}
	}
	r := resolvedTrigger{triggerType: triggerType, hasType: hasType, hasConfig: hasConfig}
	if hasConfig {
		normalizeType := triggerType
		if normalizeType == "" {
			normalizeType = fallbackType
		}
		if normalizeType == "" {
			normalizeType = "schedule"
		}
		r.config = normalizeTriggerInput(normalizeType, config)
		r.configDefined = defined || normalizeType == "schedule"
	}
	return r
}

func firstNonNil(m dyn.Map, keys ...string) any {
	for _, k := range keys {
		if v := m[k]; v != nil {
			return v
		}
	}
	return nil
}

func (c *call) taskError(err error, triggerType string) any {
	if c.b.d.Tasks != nil {
		if hint := c.b.d.Tasks.ConfigHint(strings.TrimSpace(triggerType)); hint != "" {
			return dyn.Ordered{{Key: "error", Value: err.Error()}, {Key: "expectedConfig", Value: strings.TrimSpace(triggerType) + ": " + hint}}
		}
	}
	return errResult(err.Error())
}

func createTask(ctx context.Context, c *call) (any, error) {
	tasks := c.b.d.Tasks
	if tasks == nil {
		return errResult("Task runtime not available"), nil
	}
	r := resolveTriggerArgs(c.args, "schedule")
	if !r.hasType || r.triggerType == "" {
		return errResult("Task trigger type is required (use trigger.type or trigger_type)."), nil
	}
	config := r.config
	if !r.hasConfig || !r.configDefined {
		if r.triggerType == "manual" {
			config = dyn.Map{}
		} else {
			return errResult("Task trigger config is required (use trigger.config or trigger_config)."), nil
		}
	}
	task, err := tasks.Create(ctx, c.run.UserID, c.run.AgentID, dyn.Map{
		"name":          c.args["name"],
		"triggerType":   r.triggerType,
		"triggerConfig": config,
		"prompt":        c.args["prompt"],
		"enabled":       c.args["enabled"] != false,
		"model":         truthyOrNil(c.args["model"]),
		"agentId":       c.run.AgentID,
	})
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return c.taskError(err, r.triggerType), nil
	}
	return dyn.Ordered{{Key: "success", Value: true}, {Key: "task", Value: task}, {Key: "message", Value: `Task "` + str(c.args["name"]) + `" created.`}}, nil
}

func listTasks(ctx context.Context, c *call) (any, error) {
	tasks := c.b.d.Tasks
	if tasks == nil {
		return errResult("Task runtime not available"), nil
	}
	list, err := tasks.List(ctx, c.run.UserID, c.run.AgentID)
	if err != nil {
		return nil, err
	}
	filtered := []any{}
	for _, t := range list {
		if c.run.AgentID == "" || dyn.Get(asMap(t), "agentId") == c.run.AgentID {
			filtered = append(filtered, t)
		}
	}
	return dyn.Ordered{{Key: "tasks", Value: filtered}, {Key: "count", Value: len(filtered)}}, nil
}

// taskOwner is the agent and trigger type of a task of the user.
func (c *call) taskOwner(ctx context.Context, taskID any) (agentID, triggerType string, ok bool, err error) {
	if c.b.d.DB == nil {
		return "", "", false, errors.New("Database is unavailable.")
	}
	var agent, trigger sql.NullString
	err = c.b.d.DB.R.QueryRowContext(ctx, `SELECT agent_id, trigger_type FROM scheduled_tasks WHERE id = ? AND user_id = ?`, sqlArg(taskID), c.run.UserID).Scan(&agent, &trigger)
	if errors.Is(err, sql.ErrNoRows) {
		return "", "", false, nil
	}
	if err != nil {
		return "", "", false, err
	}
	return agent.String, trigger.String, true, nil
}

// sqlArg binds a JSON value the way better-sqlite3 did: whole numbers as
// integers.
func sqlArg(v any) any {
	if f, ok := v.(float64); ok && f == float64(int64(f)) {
		return int64(f)
	}
	return v
}

func deleteTask(ctx context.Context, c *call) (any, error) {
	tasks := c.b.d.Tasks
	if tasks == nil {
		return errResult("Task runtime not available"), nil
	}
	agentID, _, ok, err := c.taskOwner(ctx, c.args["task_id"])
	if err != nil {
		return failure(ctx, err)
	}
	if !ok || agentID != c.run.AgentID {
		return errResult("Task not found for this agent."), nil
	}
	if err := tasks.Delete(ctx, c.run.UserID, c.args["task_id"]); err != nil {
		return failure(ctx, err)
	}
	return dyn.Ordered{{Key: "success", Value: true}, {Key: "deleted", Value: c.args["task_id"]}}, nil
}

func updateTask(ctx context.Context, c *call) (any, error) {
	tasks := c.b.d.Tasks
	if tasks == nil {
		return errResult("Task runtime not available"), nil
	}
	agentID, triggerType, ok, err := c.taskOwner(ctx, c.args["task_id"])
	if err != nil {
		return failure(ctx, err)
	}
	if !ok || agentID != c.run.AgentID {
		return errResult("Task not found for this agent."), nil
	}
	if triggerType == "" {
		triggerType = "schedule"
	}
	r := resolveTriggerArgs(c.args, triggerType)
	updates := dyn.Map{}
	if v, ok := c.args["name"]; ok {
		updates["name"] = v
	}
	if r.hasType && r.triggerType != "" {
		updates["triggerType"] = r.triggerType
	}
	if r.hasConfig && r.configDefined {
		updates["triggerConfig"] = r.config
	}
	if v, ok := c.args["prompt"]; ok {
		updates["prompt"] = v
	}
	if v, ok := c.args["enabled"]; ok {
		updates["enabled"] = v
	}
	if v, ok := c.args["model"]; ok {
		updates["model"] = truthyOrNil(v)
	}
	updated, err := tasks.Update(ctx, c.run.UserID, c.args["task_id"], updates)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return c.taskError(err, r.triggerType), nil
	}
	return dyn.Ordered{{Key: "success", Value: true}, {Key: "task", Value: updated}}, nil
}
