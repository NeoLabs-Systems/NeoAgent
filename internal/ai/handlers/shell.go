package handlers

import (
	"context"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace/repotools"
)

var shellHandlers = map[string]handler{"execute_command": executeCommand}

// executeCommand runs a command in the user's computer. Short by default, so a
// command that hangs costs minutes; a long job says so.
func executeCommand(ctx context.Context, c *call) (any, error) {
	rt := c.b.d.Runtime
	if rt == nil {
		return errResult("Command execution is unavailable. No runtime manager found."), nil
	}
	timeout := 3 * time.Minute
	if c.args["pty"] == true {
		timeout = 20 * time.Minute
	}
	if dyn.Truthy(c.args["timeout"]) {
		if ms := jsNumber(c.args["timeout"]); ms == ms && ms > 0 {
			timeout = time.Duration(ms) * time.Millisecond
		}
	}
	opts := CommandOptions{
		Cwd:          orString(c.args["cwd"], repotools.GuestWorkspaceDir),
		Timeout:      timeout,
		StdinInput:   c.args["stdin_input"],
		PTY:          c.args["pty"] == true,
		Inputs:       dyn.List(c.args["inputs"]),
		RunID:        c.run.RunID,
		StepID:       c.stepID,
		DeviceTarget: c.run.DeviceTarget,
	}
	if opts.Inputs == nil {
		opts.Inputs = []any{}
	}
	if guestHost := rt.GuestHostAddress(c.run.UserID, c.run.DeviceTarget); guestHost != "" && c.b.d.GitEnv != nil {
		env, err := c.b.d.GitEnv(ctx, c.run, guestHost, timeout)
		if err != nil {
			return commandFailure(ctx, err)
		}
		opts.Env = env
	}
	result, err := rt.ExecuteCommand(ctx, c.run.UserID, str(c.args["command"]), opts)
	if err != nil {
		return commandFailure(ctx, err)
	}
	return result, nil
}

func commandFailure(ctx context.Context, err error) (any, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	msg := err.Error()
	return dyn.Ordered{
		{Key: "error", Value: msg},
		{Key: "stderr", Value: msg},
		{Key: "stdout", Value: ""},
		{Key: "exitCode", Value: nil},
		{Key: "timedOut", Value: false},
		{Key: "killed", Value: false},
	}, nil
}
