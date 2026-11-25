package tasks

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/reqx"
	"github.com/NeoLabs-Systems/neoagent/internal/timeline"
)

// taskOutputDefaults is the default delivery style for every background task.
// The task prompt and the user's memory/preferences win wherever they say
// otherwise.
const taskOutputDefaults = "Default output rules (the task instructions below and the user's memory/preferences override these wherever they say otherwise):\n" +
	"- Report only what actually changed or needs attention. Never mention checks that found nothing (e.g. if the task checks mail and calendar and only mail has something new, say nothing about the calendar).\n" +
	"- Do not explain why or when the task ran, what you checked, or how you did it. No preamble, no sign-off.\n" +
	"- Say each thing once. No repetition, no restating the task, no summary of a summary.\n" +
	"- Be brief and token-efficient: do the minimum tool calls needed and keep the message as short as the content allows.\n" +
	"- Format user-facing messages for easy reading on the target platform (short lines, lists or bold for key items where it helps).\n" +
	"- If nothing is relevant, answer exactly [NO RESPONSE] and nothing else.\n" +
	"- Treat the task instructions as intent, not a rigid script. If context shows something else would serve the user better, do that instead."

func (r *Runtime) now() time.Time {
	if r.cfg.Clock != nil {
		return r.cfg.Clock.Now()
	}
	return time.Now()
}

func timelineEntry(l lifecycle) timeline.TaskLifecycle {
	return timeline.TaskLifecycle{
		UserID:        l.userID,
		AgentID:       l.agentID,
		TaskID:        l.taskID,
		TaskName:      l.name,
		EventKind:     l.kind,
		RunID:         l.runID,
		Reason:        l.reason,
		Error:         l.err,
		TriggerType:   l.meta.triggerType,
		TriggerSource: l.meta.triggerSource,
	}
}

func fenceUntrusted(tag, body string) string {
	return "<" + tag + ">\n" + body + "\n</" + tag + ">"
}

func (r *Runtime) executeSerial(ctx context.Context, taskID, userID int64, meta execMeta) any {
	if ctx.Err() != nil || r.isStopping() {
		return skippedResult("runtime_stopping")
	}
	task, err := r.repo.get(ctx, taskID, userID)
	if err != nil {
		r.log.Error("load task failed", "task", taskID, "error", err)
		return jsv.NewObject().Set("error", err.Error())
	}
	if task == nil || !task.Enabled {
		return skippedResult("missing_or_disabled")
	}

	taskConfig := asObject(task.TaskConfig)
	triggerConfig := asObject(task.TriggerConfig)
	agentID := jsv.Trim(task.AgentID.String)
	if agentID == "" {
		if resolved, err := r.resolveAgent(ctx, userID, pick(taskConfig, "agentId", "agent_id")); err == nil {
			agentID = resolved
		} else {
			agentID = "main"
		}
	}

	if !meta.manual && !meta.oneTime && meta.resumedFromRunID == "" && meta.triggerType == "schedule" && meta.scheduledAt != "" {
		if scheduledAt, err := time.Parse(time.RFC3339Nano, meta.scheduledAt); err == nil {
			if r.now().Sub(scheduledAt) > maxRecurringStartDelay {
				r.record(ctx, lifecycle{userID: userID, taskID: taskID, name: orString(task.Name, fmt.Sprintf("Task %d", taskID)),
					agentID: agentID, kind: "task_skipped", reason: "stale_start_delay", meta: meta})
				r.emit(userID, "tasks:task_skipped", jsv.NewObject().Set("taskId", float64(taskID)).
					Set("reason", "stale_start_delay").Set("scheduledAt", meta.scheduledAt).Set("timestamp", jsv.ISO(r.now())))
				return skippedResult("stale_start_delay")
			}
		}
	}

	if isTaskLoopPaused(taskConfig) {
		r.record(ctx, lifecycle{userID: userID, taskID: taskID, name: orString(task.Name, fmt.Sprintf("Task %d", taskID)),
			agentID: agentID, kind: "task_skipped", reason: "loop_paused", meta: meta})
		r.emit(userID, "tasks:task_skipped", jsv.NewObject().Set("taskId", float64(taskID)).
			Set("reason", "loop_paused").Set("timestamp", jsv.ISO(r.now())))
		return skippedResult("loop_paused")
	}

	if err := r.repo.markRun(ctx, taskID, userID); err != nil {
		r.log.Error("mark task run failed", "task", taskID, "error", err)
	}
	r.emit(userID, "tasks:task_running", jsv.NewObject().Set("taskId", float64(taskID)).Set("timestamp", jsv.ISO(r.now())))
	taskName := orString(task.Name, fmt.Sprintf("Task %d", taskID))
	r.record(ctx, lifecycle{userID: userID, taskID: taskID, name: taskName, agentID: agentID, kind: "task_started", meta: meta})

	// Drop legacy call config keys if present.
	if _, hasTo := taskConfig.Get("callTo"); hasTo || func() bool { _, ok := taskConfig.Get("callGreeting"); return ok }() {
		taskConfig.Delete("callTo")
		taskConfig.Delete("callGreeting")
		_ = r.repo.updateConfig(ctx, taskID, userID, taskConfig)
	}

	delivery := &Delivery{}
	notifyTarget := r.resolveNotifyTarget(ctx, userID, agentID, *task, taskConfig, meta.triggerPayload)
	delivery.NotifyTarget = notifyTarget

	triggerSummary := r.summarizeTrigger(orString(task.TriggerType.String, "schedule"), triggerConfig)
	var notifyHint string
	if notifyTarget != nil {
		notifyHint = fmt.Sprintf("\n\nYour final answer is delivered to the user on platform=%q to=%q when this run ends; do not send it yourself with send_message. If nothing is worth telling them, answer exactly [NO RESPONSE] and nothing else: it is a control token, never translated or combined with other text. When a tool result already gives you summary fields or flags that answer the task, decide from that evidence instead of re-running nearby variants of the same lookup.",
			notifyTarget.Platform, notifyTarget.To)
	}

	var triggerPayloadText string
	if meta.triggerPayload != nil {
		raw, _ := json.MarshalIndent(meta.triggerPayload, "", "  ")
		triggerPayloadText = "\nTrigger event context (untrusted data from the event source):\n" + fenceUntrusted("external_event", string(raw)) + "\n"
	}

	executionInstant := meta.scheduledAt
	if executionInstant == "" {
		executionInstant = jsv.ISO(r.now())
	}
	var temporalAccuracyHint string
	if orString(task.TriggerType.String, "schedule") == "schedule" {
		temporalAccuracyHint = fmt.Sprintf("Execution instant: %s. For any requested lead time before a calendar event, derive the target event-start time from this instant plus that lead time and use an explicit, bounded start window around that target. An event is eligible only from its actual start timestamp; never notify for an event that has already started, merely overlaps the window, or is all-day unless the task explicitly asks for those cases.",
			executionInstant)
	}

	var promptBody string
	if orString(task.TaskType.String, "agent_prompt") == "agent_prompt" {
		promptBody = orString(jsv.Trim(jsv.Text(taskConfig.Val("prompt"))), fmt.Sprintf("You have been triggered to run the background task %q.", taskName))
	}

	lastRunRow, _ := r.repo.lastTaskRun(ctx, userID, taskID, meta.resumedFromRunID)
	parts := []string{
		"[SYSTEM: Executing Background Task]",
		"Task Name: " + taskName,
		"Trigger: " + triggerSummary,
	}
	if temporalAccuracyHint != "" {
		parts = append(parts, temporalAccuracyHint)
	}
	parts = append(parts, taskOutputDefaults)
	if promptBody != "" {
		parts = append(parts, promptBody)
	}
	if note := buildLastRunNote(lastRunRow); note != "" {
		parts = append(parts, note)
	}
	if meta.resumeNote != "" {
		parts = append(parts, meta.resumeNote)
	}
	if trimmed := strings.TrimSpace(triggerPayloadText); trimmed != "" {
		parts = append(parts, trimmed)
	}
	if notifyHint != "" {
		parts = append(parts, notifyHint)
	}
	basePrompt := strings.Join(parts, "\n\n")

	convID := r.getOrCreateTaskConversation(ctx, userID, taskID, taskName, agentID)
	var chatCtx ChatContext
	if notifyTarget != nil && r.cfg.Messaging != nil {
		if c, err := r.cfg.Messaging.ChatContext(ctx, userID, agentID, *notifyTarget); err == nil {
			chatCtx = c
		}
	}

	triggerSource := orString(meta.triggerSource, orString(task.TriggerType.String, "schedule"))
	model := jsv.Trim(jsv.Text(taskConfig.Val("model")))
	allowMultiple := taskConfig.Val("allowMultipleMessages") == true || taskConfig.Val("allow_multiple_messages") == true

	var completedRunID string
	var recoveryNote string
	var lastErr error

	for attempt := 0; attempt <= maxAutonomousRetries; attempt++ {
		if r.cfg.Engine == nil {
			lastErr = errors.New("task engine is not configured")
			break
		}
		req := RunRequest{
			UserID:                         userID,
			AgentID:                        agentID,
			Prompt:                         basePrompt + recoveryNote,
			Model:                          model,
			Title:                          taskName,
			TriggerType:                    orString(task.TriggerType.String, "schedule"),
			TriggerSource:                  triggerSource,
			ConversationID:                 convID,
			TaskID:                         taskID,
			ScheduledAt:                    executionInstant,
			AllowMultipleProactiveMessages: allowMultiple,
			PriorMessages:                  chatCtx.PriorMessages,
			PriorSummary:                   chatCtx.PriorSummary,
			Context:                        meta.triggerPayload,
			ResumedFromRunID:               meta.resumedFromRunID,
			Delivery:                       delivery,
		}
		if attempt == 0 && meta.runID != "" {
			req.RunID = meta.runID
		}
		if !meta.oneTime && meta.triggerPayload == nil && (meta.triggerType == "schedule" || meta.manual) {
			req.Resumable = &ResumableTask{TaskID: taskID, ScheduledAt: executionInstant, TriggerSource: triggerSource}
		}

		res, err := r.cfg.Engine.RunTask(ctx, req)
		completedRunID = res.RunID
		if err == nil {
			if r.isStopping() || ctx.Err() != nil {
				return skippedResult("runtime_stopping").Set("runId", completedRunID)
			}
			deliveryErr := r.deliverTaskResultIfNeeded(ctx, userID, agentID, taskID, res.Result, delivery)
			if deliveryErr != nil {
				lastErr = deliveryErr
				break
			}
			if len(delivery.Sent) == 0 && !delivery.NoResponse && strings.TrimSpace(stringifyResult(res.Result)) == "" {
				err = errors.New("Background task completed without producing a result or an explicit no-response decision.")
			} else {
				r.emit(userID, "tasks:task_complete", jsv.NewObject().Set("taskId", float64(taskID)).Set("result", res.Result))
				r.record(ctx, lifecycle{userID: userID, taskID: taskID, name: taskName, agentID: agentID,
					kind: "task_completed", runID: completedRunID, meta: meta})
				return res.Result
			}
		}

		if (errors.Is(err, context.Canceled) || ctx.Err() != nil) && r.isStopping() {
			return skippedResult("runtime_stopping").Set("runId", completedRunID)
		}
		transient := r.cfg.Failures != nil && r.cfg.Failures.IsTransient(err)
		if completedRunID != "" && !transient {
			_ = r.repo.markRunFailed(ctx, completedRunID, userID, err.Error())
		}
		if transient {
			r.record(ctx, lifecycle{userID: userID, taskID: taskID, name: taskName, agentID: agentID,
				kind: "task_skipped", runID: completedRunID, reason: "transient_rate_limit", err: err.Error(), meta: meta})
			r.emit(userID, "tasks:task_skipped", jsv.NewObject().Set("taskId", float64(taskID)).
				Set("reason", "transient_rate_limit").Set("timestamp", jsv.ISO(r.now())))
			return skippedResult("transient_rate_limit").Set("runId", completedRunID).Set("error", err.Error())
		}

		lastErr = err
		if attempt >= maxAutonomousRetries {
			break
		}
		completedRunID = ""
		recoveryNote = "\n\n[SYSTEM: Previous task attempt failed]\nError: " + err.Error() +
			"\nContinue autonomously end-to-end, retrying failed steps safely and using alternate tools when appropriate."
		r.emit(userID, "tasks:task_running", jsv.NewObject().Set("taskId", float64(taskID)).
			Set("timestamp", jsv.ISO(r.now())).Set("retry", float64(attempt+1)))
	}

	if lastErr == nil {
		lastErr = errors.New("Task execution failed.")
	}
	r.log.Error("task execution failed", "task", taskID, "error", lastErr)
	if !errors.Is(lastErr, errDeliveryFailed) {
		if msg := r.buildTaskFailureMessage(taskName, lastErr); msg != "" {
			_ = r.deliverTaskResultIfNeeded(ctx, userID, agentID, taskID, jsv.NewObject().Set("content", msg), delivery)
		}
	}
	r.emit(userID, "tasks:task_skipped", jsv.NewObject().Set("taskId", float64(taskID)).
		Set("reason", "execution_failed").Set("error", lastErr.Error()).Set("timestamp", jsv.ISO(r.now())))
	r.record(ctx, lifecycle{userID: userID, taskID: taskID, name: taskName, agentID: agentID,
		kind: "task_failed", runID: completedRunID, err: lastErr.Error(), meta: meta})
	return jsv.NewObject().Set("error", lastErr.Error()).Set("runId", orNil(completedRunID))
}

var errDeliveryFailed = errors.New("task delivery failed")

func (r *Runtime) resolveNotifyTarget(ctx context.Context, userID int64, agentID string, task taskRow, taskConfig, triggerPayload *jsv.Object) *Target {
	if target := r.configuredNotifyTarget(userID, agentID, taskConfig); target != nil {
		return target
	}
	if triggerPayload != nil {
		if a := r.adapter(task.TriggerType.String); a != nil && a.ReplyTarget != nil {
			if raw, ok := triggerPayload.Val("triggerEvent").(map[string]any); ok {
				if p, to, ok := a.ReplyTarget(raw); ok && p != "" && to != "" {
					return &Target{Platform: p, To: to}
				}
			}
		}
	}
	if r.cfg.Messaging == nil {
		return nil
	}
	recent, _ := r.repo.recentMessageTargets(ctx, userID, agentID, 20)
	for _, t := range recent {
		if r.cfg.Messaging.PlatformConnected(userID, agentID, t.Platform) &&
			!r.cfg.Messaging.IsRefusedSharedRecipient(userID, agentID, t) {
			copyT := t
			return &copyT
		}
	}
	return nil
}

func (r *Runtime) deliverTaskResultIfNeeded(ctx context.Context, userID int64, agentID string, taskID int64, result any, delivery *Delivery) error {
	if delivery == nil || delivery.NotifyTarget == nil || r.cfg.Messaging == nil {
		return nil
	}
	if delivery.NoResponse || delivery.FinalDelivered || len(delivery.Sent) > 0 {
		return nil
	}
	text := strings.TrimSpace(stringifyResult(result))
	if text == "" {
		return nil
	}
	formatted := r.cfg.Messaging.FormatOutgoing(delivery.NotifyTarget.Platform, text)
	if strings.TrimSpace(formatted) == "[NO RESPONSE]" {
		delivery.NoResponse = true
		return nil
	}
	var runID string
	if o, ok := result.(*jsv.Object); ok {
		runID = jsv.Text(o.Val("runId"))
	}
	if _, err := r.cfg.Messaging.Send(ctx, SendRequest{
		UserID:  userID,
		AgentID: agentID,
		Target:  *delivery.NotifyTarget,
		Message: formatted,
		RunID:   runID,
		TaskID:  taskID,
	}); err != nil {
		return fmt.Errorf("%w: %v", errDeliveryFailed, err)
	}
	delivery.FinalDelivered = true
	delivery.Sent = append(delivery.Sent, formatted)
	return nil
}

func (r *Runtime) buildTaskFailureMessage(taskName string, err error) string {
	if err == nil {
		return ""
	}
	if r.cfg.Failures != nil {
		if r.cfg.Failures.IsTransient(err) || r.cfg.Failures.IsProviderHealthIssue(err) {
			return ""
		}
		if r.cfg.Failures.IsModelsUnavailable(err) {
			return fmt.Sprintf("Task \"%s\" could not run because no AI model is currently available.", taskName)
		}
		if msg := r.cfg.Failures.EnvelopeMessage(err); msg != "" {
			return fmt.Sprintf("Task \"%s\" failed: %s", taskName, msg)
		}
	}
	return fmt.Sprintf("Task \"%s\" failed: %s", taskName, err.Error())
}

// buildLastRunNote tells the next run what the previous run of the task
// delivered, so it reports only what is new since then.
func buildLastRunNote(last *lastRun) string {
	if last == nil {
		return ""
	}
	final := last.Final.String
	if final == "" {
		final = "(empty)"
	}
	outcome := "It sent nothing. Its result:\n" + final
	switch {
	case len(last.SentMessages) > 0:
		outcome = "It sent the user:\n" + strings.Join(last.SentMessages, "\n---\n")
	case last.Error.String != "":
		outcome = "It failed: " + last.Error.String
	}
	return strings.Join([]string{
		fmt.Sprintf("[Previous run of this task: %s UTC, %s]", last.CreatedAt, last.Status),
		outcome,
		"Do not repeat what that run already delivered; report only what is new since then.",
	}, "\n")
}

func (r *Runtime) getOrCreateTaskConversation(ctx context.Context, userID, taskID int64, taskName, agentID string) string {
	chatID := fmt.Sprintf("task:%d", taskID)
	if id, err := r.repo.taskConversation(ctx, userID, agentID, "tasks", chatID); err == nil && id != "" {
		return id
	}
	id, err := reqx.NewUUID()
	if err != nil {
		return ""
	}
	if taskName == "" {
		taskName = fmt.Sprintf("Task %d", taskID)
	}
	if err := r.repo.createTaskConversation(ctx, id, userID, agentID, "tasks", chatID, "Task — "+taskName); err != nil {
		return ""
	}
	return id
}
