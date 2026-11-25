package tasks

import (
	"context"
	"slices"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

const pollTickSlack = 5 * time.Second

func (r *Runtime) polledTriggerTypes() []string {
	var types []string
	for _, a := range r.adapterList {
		if a.Poll != nil {
			types = append(types, a.Type)
		}
	}
	return types
}

func (r *Runtime) pollInterval(p *Poll, config *jsv.Object) time.Duration {
	var mins float64
	if p.IntervalMinutes != nil {
		mins = p.IntervalMinutes(config)
	}
	if mins <= 0 {
		mins = 1
	}
	return time.Duration(mins * float64(time.Minute))
}

func (r *Runtime) claimPoll(taskID int64, p *Poll, config *jsv.Object, now time.Time) bool {
	interval := r.pollInterval(p, config)
	r.mu.Lock()
	defer r.mu.Unlock()
	if last, ok := r.polledAt[taskID]; ok && now.Sub(last) < interval-pollTickSlack {
		return false
	}
	r.polledAt[taskID] = now
	return true
}

// FetchTriggerRows runs a polled adapter's FetchRows for the given task config.
func (r *Runtime) FetchTriggerRows(ctx context.Context, userID int64, agentID, triggerType string, config *jsv.Object, checkpoint string, now time.Time) ([]Row, error) {
	a := r.adapter(triggerType)
	if a == nil || a.Poll == nil || r.cfg.Integrations == nil {
		return nil, nil
	}
	scopedAgent, err := r.resolveAgent(ctx, userID, agentID)
	if err != nil {
		scopedAgent = agentID
	}
	connID := config.Val("connectionId")
	accountEmail := config.Val("accountEmail")
	tool := func(name string, args *jsv.Object) (any, error) {
		merged := jsv.NewObject()
		if connID != nil && connID != "" {
			merged.Set("connection_id", connID)
		}
		if jsv.Truthy(accountEmail) {
			merged.Set("account_email", accountEmail)
		}
		if args != nil {
			for _, k := range args.Keys() {
				merged.Set(k, args.Val(k))
			}
		}
		return r.cfg.Integrations.ExecuteTool(ctx, userID, scopedAgent, name, merged)
	}
	return a.Poll.FetchRows(tool, config, checkpoint, now)
}

func (r *Runtime) pendingRows(ctx context.Context, task taskRow, p *Poll, rows []Row, now time.Time) []Row {
	checkpoint := task.LastTriggerFingerprint.String
	mark := func(fp string) {
		if err := r.repo.markTriggered(ctx, task.ID, task.UserID, fp); err != nil {
			r.log.Error("mark trigger checkpoint failed", "task", task.ID, "error", err)
		}
	}

	if p.Cursor == "ordered" {
		if checkpoint != "" {
			var out []Row
			for _, row := range rows {
				if row.Fingerprint > checkpoint {
					out = append(out, row)
				}
			}
			return out
		}
		if p.Baseline == "now" {
			start := jsv.ISO(now)
			mark(start)
			var out []Row
			for _, row := range rows {
				if row.Fingerprint > start {
					out = append(out, row)
				}
			}
			return out
		}
		if len(rows) > 0 {
			mark(rows[len(rows)-1].Fingerprint)
		} else {
			mark("0")
		}
		return nil
	}

	if len(rows) == 0 {
		return nil
	}
	if checkpoint == "" {
		mark(rows[len(rows)-1].Fingerprint)
		return nil
	}
	idx := slices.IndexFunc(rows, func(row Row) bool { return row.Fingerprint == checkpoint })
	if idx >= 0 {
		return rows[idx+1:]
	}
	return rows[len(rows)-1:]
}

func (r *Runtime) pollTriggerTask(ctx context.Context, task taskRow, now time.Time) {
	a := r.adapter(task.TriggerType.String)
	if a == nil || a.Poll == nil {
		return
	}
	config := asObject(task.TriggerConfig)
	if !r.claimPoll(task.ID, a.Poll, config, now) {
		return
	}
	rows, err := r.FetchTriggerRows(ctx, task.UserID, task.AgentID.String, task.TriggerType.String, config, task.LastTriggerFingerprint.String, now)
	if err != nil {
		r.log.Error("integration trigger poll failed", "task", task.ID, "triggerType", task.TriggerType.String, "error", err)
		return
	}
	for _, row := range r.pendingRows(ctx, task, a.Poll, rows, now) {
		if ctx.Err() != nil || r.isStopping() {
			break
		}
		if row.Silent {
			_ = r.repo.markTriggered(ctx, task.ID, task.UserID, row.Fingerprint)
			continue
		}
		res, err := r.fireTaskFromTrigger(ctx, task.ID, task.UserID, Payload{
			Fingerprint: row.Fingerprint,
			Timestamp:   row.Timestamp,
			Context:     row.Context,
		})
		if err != nil {
			break
		}
		skipped, errText, _ := resultFields(res)
		if errText != "" {
			break
		}
		if skipped {
			if o, ok := res.(*jsv.Object); ok && o.Val("reason") != "duplicate_trigger" {
				break
			}
		}
	}
}

func (r *Runtime) pollIntegrations(ctx context.Context) error {
	types := r.polledTriggerTypes()
	if len(types) == 0 || r.cfg.Integrations == nil {
		return nil
	}
	tasks, err := r.repo.listEnabledByTriggerTypes(ctx, types)
	if err != nil {
		return err
	}
	now := r.now()
	for _, task := range tasks {
		if ctx.Err() != nil || r.isStopping() {
			break
		}
		r.pollTriggerTask(ctx, task, now)
	}
	return nil
}
