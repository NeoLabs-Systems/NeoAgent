package integrations

import "context"

// Run says what started the agent run a tool call belongs to. Calendar tools
// behave differently inside scheduled reminders.
type Run struct {
	TriggerSource string // "schedule", "tasks", ...
	TaskID        string // empty when not a task
	ScheduledAt   string // ISO time the task was due
}

// Automatic reports whether the run is a scheduled task acting on its own.
func (r Run) Automatic() bool {
	return (r.TriggerSource == "schedule" || r.TriggerSource == "tasks") && r.TaskID != ""
}

type runKey struct{}

// WithRun attaches the run to a tool call's context.
func WithRun(ctx context.Context, r Run) context.Context {
	return context.WithValue(ctx, runKey{}, r)
}

// RunFrom is the run a tool call belongs to; the zero Run for none.
func RunFrom(ctx context.Context) Run {
	r, _ := ctx.Value(runKey{}).(Run)
	return r
}
