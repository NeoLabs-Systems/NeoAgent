package guest

import (
	"context"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/proc"
)

// cmdResult is how a finished helper command ended.
type cmdResult struct {
	Status int
	Stdout string
	Stderr string
	Err    error
}

// desktopRunner runs the helper programs of the desktop (xdotool, scrot,
// sudo ...). It is a seam so command construction can be tested without a
// display.
type desktopRunner interface {
	run(name string, args []string, timeout time.Duration, extraEnv []string) cmdResult
}

type systemRunner struct{}

func (systemRunner) run(name string, args []string, timeout time.Duration, extraEnv []string) cmdResult {
	spec := proc.Spec{Path: name, Args: args}
	if len(extraEnv) > 0 {
		spec.Env = append(osEnviron(), extraEnv...)
	}
	res, err := proc.Run(context.Background(), timeout, spec, 4<<20)
	if err != nil {
		return cmdResult{Status: -1, Err: err}
	}
	out := cmdResult{Status: res.Code, Stdout: res.Stdout, Stderr: res.Stderr}
	if res.TimedOut {
		out.Status = -1
		out.Err = context.DeadlineExceeded
	}
	return out
}
