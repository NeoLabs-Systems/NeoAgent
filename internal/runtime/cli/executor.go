package cli

import (
	"context"
	"errors"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/proc"
	"github.com/NeoLabs-Systems/neolabs-go/ptyx"
)

const (
	defaultTimeout            = 15 * time.Minute
	defaultInteractiveTimeout = 20 * time.Minute
	forceKillGrace            = 5 * time.Second
	interactiveWindow         = 20_000
	interactiveInputDelay     = 200 * time.Millisecond
	abortedStderr             = "Command aborted before it started."
)

var ansiEscape = regexp.MustCompile(`\x1B\[[0-9;]*[a-zA-Z]`)

// ErrNoShell is returned when no usable shell exists on the machine.
var ErrNoShell = errors.New("No usable shell found for CLI execution.")

// Options describe one command.
type Options struct {
	Cwd string
	// TimeoutMs is the limit in milliseconds; zero or less uses the default.
	TimeoutMs  float64
	StdinInput string
	// Env is added to the base environment for this command.
	Env     map[string]string
	OnSpawn func(pid int)
}

// Input is one scripted answer for an interactive command. An empty WaitFor
// sends the input shortly after the previous one.
type Input struct {
	Input   string
	WaitFor string
}

// Executor runs shell commands and tracks them so they can be killed by pid.
type Executor struct {
	shell string
	// BaseEnvironment is what a command inherits. In the guest the environment
	// is its own; on the server it must be told what to pass on, because the
	// server's environment holds the server's secrets. Nil means os.Environ.
	BaseEnvironment func() []string

	sup *proc.Supervisor

	loginOnce sync.Once
	login     string
}

// NewExecutor finds a shell and returns an executor, or ErrNoShell.
func NewExecutor() (*Executor, error) {
	shell := ResolveDefaultShell()
	if shell == "" {
		return nil, ErrNoShell
	}
	return &Executor{shell: shell, sup: proc.NewSupervisor()}, nil
}

// Shell is the shell commands run in.
func (e *Executor) Shell() string { return e.shell }

func clampTimeout(ms float64, fallback time.Duration) time.Duration {
	if !(ms > 0) || ms > 1e15 {
		return fallback
	}
	return time.Duration(int64(ms)) * time.Millisecond
}

func (e *Executor) buildEnv(extra map[string]string) []string {
	e.loginOnce.Do(func() { e.login = loginPath(e.shell) })
	base := os.Environ
	if e.BaseEnvironment != nil {
		base = e.BaseEnvironment
	}
	env := map[string]string{}
	var order []string
	set := func(key, value string) {
		if _, ok := env[key]; !ok {
			order = append(order, key)
		}
		env[key] = value
	}
	for _, kv := range base() {
		if k, v, ok := strings.Cut(kv, "="); ok {
			set(k, v)
		}
	}
	set("PATH", mergePaths(e.login, os.Getenv("PATH")))
	for k, v := range extra {
		set(k, v)
	}
	out := make([]string, 0, len(order))
	for _, k := range order {
		out = append(out, k+"="+env[k])
	}
	return out
}

func abortedResult(command, cwd string, started time.Time) Result {
	return Result{
		variant: variantAborted, Killed: true, Aborted: true, Command: command, Cwd: cwd,
		outputResult: outputResult{Stderr: abortedStderr, StderrBytes: len(abortedStderr)},
		DurationMs:   time.Since(started).Milliseconds(),
	}
}

func startFailed(err error, command, cwd string, started time.Time, pid *int, interactive bool) Result {
	code := -1
	return Result{
		variant: variantStartFailed, ExitCode: &code, Command: command, Cwd: cwd, PID: pid, Error: err.Error(),
		outputResult: outputResult{Stderr: err.Error(), StderrBytes: len(err.Error())},
		DurationMs:   time.Since(started).Milliseconds(), Interactive: interactive,
	}
}

// Execute runs a command to completion with stdin at end of file (or the given
// input), killing its process group on timeout or when ctx ends.
func (e *Executor) Execute(ctx context.Context, command string, o Options) Result {
	cwd := resolveCwd(o.Cwd)
	started := time.Now()
	if ctx.Err() != nil {
		return abortedResult(command, cwd, started)
	}
	out, err := NewAccumulator(AccumulatorOptions{})
	if err != nil {
		return startFailed(err, command, cwd, started, nil, false)
	}
	var outMu sync.Mutex
	stdout := &streamWriter{acc: out, stream: "stdout", mu: &outMu}
	stderr := &streamWriter{acc: out, stream: "stderr", mu: &outMu}
	var stdin *strings.Reader
	if o.StdinInput != "" {
		stdin = strings.NewReader(o.StdinInput)
	}
	spec := proc.Spec{
		Path: e.shell, Args: ShellArgs(e.shell, WrapForShell(command, e.shell)),
		Dir: cwd, Env: e.buildEnv(o.Env), Stdout: stdout, Stderr: stderr,
	}
	if stdin != nil {
		spec.Stdin = stdin
	}
	p, err := e.sup.Start(spec)
	if err != nil {
		out.Discard()
		return startFailed(err, command, cwd, started, nil, false)
	}
	pid := p.PID()
	if o.OnSpawn != nil {
		o.OnSpawn(pid)
	}
	watch := e.watch(ctx, p, clampTimeout(o.TimeoutMs, defaultTimeout))
	exit := p.Wait()
	watch.stop()

	res, ferr := out.Finalize()
	if ferr != nil {
		return startFailed(ferr, command, cwd, started, &pid, false)
	}
	return Result{
		ExitCode: exitCodeOf(exit), outputResult: res,
		Killed: exit.Reason != "", TimedOut: exit.Reason == "timeout", Aborted: exit.Reason == "aborted",
		Signal: exit.Signal, DurationMs: time.Since(started).Milliseconds(), PID: &pid, Command: command, Cwd: cwd,
	}
}

func exitCodeOf(exit proc.Exit) *int {
	if exit.Signal != "" {
		return nil
	}
	code := exit.Code
	return &code
}

type watcher struct{ stopped chan struct{} }

func (w watcher) stop() { close(w.stopped) }

// watch ends p when ctx is cancelled ("aborted") or the timeout passes
// ("timeout"). The first reason wins. Stopping the watch is a separate
// signal: one derived from ctx would be ready at the same moment as ctx and
// could win the select, ignoring the abort.
func (e *Executor) watch(ctx context.Context, p *proc.Process, timeout time.Duration) watcher {
	w := watcher{stopped: make(chan struct{})}
	go func() {
		timer := time.NewTimer(timeout)
		defer timer.Stop()
		select {
		case <-timer.C:
			p.Terminate("timeout")
		case <-ctx.Done():
			p.Terminate("aborted")
		case <-w.stopped:
		}
	}()
	return w
}

// streamWriter feeds one stream of a process into the accumulator. Stdout and
// stderr share a mutex because the accumulator is not concurrency safe.
type streamWriter struct {
	acc    *Accumulator
	stream string
	mu     *sync.Mutex
}

func (w *streamWriter) Write(p []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.acc.Append(w.stream, p)
	return len(p), nil
}

// ExecuteInteractive runs a command on a pseudo-terminal and answers its
// prompts from inputs.
func (e *Executor) ExecuteInteractive(ctx context.Context, command string, inputs []Input, o Options) Result {
	cwd := resolveCwd(o.Cwd)
	started := time.Now()
	if ctx.Err() != nil {
		return abortedResult(command, cwd, started)
	}
	out, err := NewAccumulator(AccumulatorOptions{StderrPreviewBytes: 50_000})
	if err != nil {
		return startFailed(err, command, cwd, started, nil, true)
	}
	env := append(e.buildEnv(o.Env), "TERM=xterm-256color")
	session, err := ptyx.Start(ptyx.Config{
		Path: e.shell, Args: ShellArgs(e.shell, WrapForShell(command, e.shell)),
		Dir: cwd, Env: env, Cols: 120, Rows: 30,
	})
	if err != nil {
		out.Discard()
		return startFailed(err, command, cwd, started, nil, true)
	}
	pid := session.PID()
	e.sup.Track(pid, func(reason string) { session.Close(reason, forceKillGrace) }, session.Done())
	if o.OnSpawn != nil {
		o.OnSpawn(pid)
	}

	feeder := newInputFeeder(session, inputs)
	unsubscribe := session.Subscribe(func(data []byte) {
		out.Append("stdout", data)
		feeder.onData(data)
	})
	timeout := clampTimeout(o.TimeoutMs, defaultInteractiveTimeout)
	timer := time.AfterFunc(timeout, func() { session.Close("timeout", forceKillGrace) })
	stopAbort := context.AfterFunc(ctx, func() { session.Close("aborted", forceKillGrace) })

	exit := session.Wait()
	timer.Stop()
	stopAbort()
	feeder.stop()
	unsubscribe()

	res, ferr := out.Finalize()
	if ferr != nil {
		return startFailed(ferr, command, cwd, started, &pid, true)
	}
	res.Stdout = strings.TrimSpace(ansiEscape.ReplaceAllString(res.Stdout, ""))
	var code *int
	if exit.Signal == "" {
		c := exit.Code
		code = &c
	}
	return Result{
		ExitCode: code, outputResult: res, Killed: exit.Reason != "", TimedOut: exit.Reason == "timeout", Aborted: exit.Reason == "aborted",
		Signal: exit.Signal, DurationMs: time.Since(started).Milliseconds(), PID: &pid, Command: command, Cwd: cwd, Interactive: true,
	}
}

// inputFeeder answers an interactive command's prompts in order: an input with
// WaitFor is sent once that text has appeared in the recent output, a plain
// input shortly after the previous one.
type inputFeeder struct {
	session *ptyx.Session
	inputs  []Input
	mu      sync.Mutex
	index   int
	window  string
	pending *time.Timer
}

func newInputFeeder(session *ptyx.Session, inputs []Input) *inputFeeder {
	return &inputFeeder{session: session, inputs: inputs}
}

func (f *inputFeeder) onData(data []byte) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.window += string(data)
	if len(f.window) > interactiveWindow {
		f.window = f.window[len(f.window)-interactiveWindow:]
	}
	if f.index >= len(f.inputs) || f.pending != nil {
		return
	}
	item := f.inputs[f.index]
	if item.WaitFor != "" {
		if strings.Contains(f.window, item.WaitFor) {
			f.index++
			_, _ = f.session.Write([]byte(item.Input + "\r"))
		}
		return
	}
	index := f.index
	f.pending = time.AfterFunc(interactiveInputDelay, func() {
		f.mu.Lock()
		defer f.mu.Unlock()
		if f.pending == nil || f.index != index {
			return
		}
		f.pending = nil
		f.index++
		_, _ = f.session.Write([]byte(item.Input + "\r"))
	})
}

func (f *inputFeeder) stop() {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.pending != nil {
		f.pending.Stop()
		f.pending = nil
	}
}

// Kill ends a command this executor started. It reports whether pid is one.
func (e *Executor) Kill(pid int, reason string) bool { return e.sup.Kill(pid, reason) }

// IsManaged reports whether pid is a running command of this executor.
func (e *Executor) IsManaged(pid int) bool { return e.sup.Managed(pid) }

// KillAll ends every running command.
func (e *Executor) KillAll(reason string) { e.sup.KillAll(reason) }
