package tasks

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

// eventQueue serialises event-triggered runs for a single task so back-to-back
// events (e.g. two members joining at once) run one after another instead of
// being skipped as already_running_or_queued.
type eventQueue struct {
	mu   sync.Mutex
	tail chan struct{}
}

func (r *Runtime) enqueueEventTask(ctx context.Context, task taskRow, payload Payload) {
	r.mu.Lock()
	q := r.queues[task.ID]
	if q == nil {
		q = &eventQueue{}
		r.queues[task.ID] = q
	}
	r.mu.Unlock()

	q.mu.Lock()
	prev := q.tail
	done := make(chan struct{})
	q.tail = done
	q.mu.Unlock()

	r.spawn(func() {
		defer close(done)
		if prev != nil {
			select {
			case <-prev:
			case <-ctx.Done():
				return
			}
		}
		if ctx.Err() != nil || r.isStopping() {
			return
		}
		_, _ = r.fireTaskFromTrigger(ctx, task.ID, task.UserID, payload)
	})
}

// PublishEvent dispatches a runtime-internal event (such as task_run_finished)
// to matching event-triggered tasks.
func (r *Runtime) PublishEvent(name string, event map[string]any) {
	r.HandleEvent("runtime", name, event)
}

// FireWebhookTask runs the task a webhook delivery is for, once the caller has
// authenticated it, and returns the run's result and whether the run failed.
func (r *Runtime) FireWebhookTask(taskID, userID int64, requestID string, at time.Time, payload any) (any, bool) {
	r.executions.Add(1)
	defer r.executions.Done()
	// Not the request's context: a sender that hangs up must not stop the run.
	result, err := r.fireTaskFromTrigger(r.context(), taskID, userID, Payload{
		Fingerprint: requestID,
		Timestamp:   jsv.ISO(at),
		Context:     jsv.NewObject().Set("webhook", payload),
	})
	if err != nil {
		return jsv.NewObject().Set("error", err.Error()), true
	}
	_, errText, _ := resultFields(result)
	return result, errText != ""
}

// HandleEvent dispatches an event from source (e.g. "messaging", "mcp",
// "wearable", "whatsapp_personal", "runtime") to matching enabled tasks.
func (r *Runtime) HandleEvent(source, name string, event map[string]any) {
	if r.isStopping() || event == nil {
		return
	}
	// The phone's routes report what happened to the server itself.
	if source == "mobile" || source == "mobilesync" {
		source = "runtime"
	}
	userID := int64(jsv.Number(event["userId"]))
	if userID <= 0 {
		return
	}
	agentID := jsv.Trim(jsv.Text(event["agentId"]))
	ctx := r.context()
	if ctx.Err() != nil {
		return
	}

	for _, a := range r.adapterList {
		if a.Event == nil || a.Event.Source != source || a.Event.Name != name {
			continue
		}
		tasks, err := r.repo.listEnabledEvent(ctx, userID, agentID, a.Type)
		if err != nil {
			r.log.Error("event task query failed", "triggerType", a.Type, "error", err)
			continue
		}
		for _, task := range tasks {
			config := asObject(task.TriggerConfig)
			if a.Event.Matches != nil && !a.Event.Matches(config, event, task) {
				continue
			}
			payload := a.Event.ToPayload(event, config)
			r.enqueueEventTask(ctx, task, payload)
		}
	}
}

// fireTaskFromTrigger runs a task for a trigger event/poll row unless it was
// already fired with the same fingerprint.
func (r *Runtime) fireTaskFromTrigger(ctx context.Context, taskID, userID int64, payload Payload) (any, error) {
	task, err := r.repo.get(ctx, taskID, userID)
	if err != nil {
		return nil, err
	}
	if task == nil || !task.Enabled {
		return skippedResult("missing_or_disabled"), nil
	}
	fp := jsv.Trim(payload.Fingerprint)
	if fp == "" {
		return nil, errors.New("Trigger fingerprint is required.")
	}
	if jsv.Trim(task.LastTriggerFingerprint.String) == fp {
		return skippedResult("duplicate_trigger"), nil
	}
	scheduledAt := payload.Timestamp
	if scheduledAt == "" {
		scheduledAt = jsv.ISO(r.now())
	}
	triggerType := orString(task.TriggerType.String, "schedule")
	result := r.executeTask(ctx, taskID, userID, execMeta{
		scheduledAt:    scheduledAt,
		triggerType:    triggerType,
		triggerSource:  triggerType,
		triggerPayload: payload.Context,
	})
	skipped, errText, _ := resultFields(result)
	if !skipped && errText == "" {
		if err := r.repo.markTriggered(ctx, taskID, userID, fp); err != nil {
			r.log.Error("mark task triggered failed", "task", taskID, "error", err)
		}
	}
	return result, nil
}
