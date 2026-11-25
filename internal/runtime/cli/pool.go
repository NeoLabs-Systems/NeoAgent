package cli

import (
	"context"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neolabs-go/proc"
)

const (
	maxPoolStdoutChars = 50_000
	maxPoolStderrChars = 10_000
	poolBufferLimit    = 500_000
	poolBufferKeep     = 250_000
	shutdownMessage    = "Server shutting down"
)

// DefaultWorkerEnvKeys are the environment variables a shell command inherits
// from the server. Everything else, the server's secrets above all, stays out.
var DefaultWorkerEnvKeys = []string{
	"HOME", "PATH", "SHELL", "TMPDIR", "TMP", "TEMP", "TERM", "LANG", "LC_ALL", "LC_CTYPE",
	"USER", "LOGNAME", "COLORTERM", "SystemRoot", "ComSpec", "PATHEXT", "WINDIR",
}

// WorkerEnv filters base ("KEY=value" entries) down to the default allowlist
// plus extraKeys, which may also come from a comma separated string such as
// NEOAGENT_SHELL_WORKER_ENV_ALLOWLIST.
func WorkerEnv(base []string, extraKeys string) []string {
	allowed := map[string]bool{}
	for _, key := range DefaultWorkerEnvKeys {
		allowed[key] = true
	}
	for _, key := range strings.Split(extraKeys, ",") {
		if key = strings.TrimSpace(key); key != "" {
			allowed[key] = true
		}
	}
	var out []string
	for _, kv := range base {
		if key, _, ok := strings.Cut(kv, "="); ok && allowed[key] {
			out = append(out, kv)
		}
	}
	return out
}

// PoolResult is what a pool command reports.
type PoolResult struct {
	ExitCode   *int   `json:"exitCode"`
	Stdout     string `json:"stdout"`
	Stderr     string `json:"stderr"`
	Killed     bool   `json:"killed"`
	TimedOut   bool   `json:"timedOut"`
	DurationMs int64  `json:"durationMs"`
	Command    string `json:"command,omitempty"`
	Cwd        string `json:"cwd,omitempty"`
	Error      string `json:"error,omitempty"`
}

// PoolOptions describe one pooled command.
type PoolOptions struct {
	Cwd        string
	TimeoutMs  float64
	StdinInput string
	Env        map[string]string
}

// Pool runs shell commands with a limited number running at once, in process
// and with only an allowlisted environment. It replaces the pool of forked
// Node workers: a command that misbehaves can only hurt its own process group.
type Pool struct {
	shell     string
	baseEnv   []string
	slots     chan struct{}
	sup       *proc.Supervisor
	mu        sync.Mutex
	closing   bool
	closedCh  chan struct{}
	closeOnce sync.Once
}

// NewPool starts a pool allowing size concurrent commands (default 4). The
// environment commands inherit is WorkerEnv(os.Environ(), extraEnvKeys).
func NewPool(size int, extraEnvKeys string) *Pool {
	if size <= 0 {
		size = 4
	}
	shell := ResolveDefaultShell()
	if shell == "" {
		shell = "/bin/sh"
	}
	return &Pool{
		shell: shell, baseEnv: WorkerEnv(os.Environ(), extraEnvKeys),
		slots: make(chan struct{}, size), sup: proc.NewSupervisor(), closedCh: make(chan struct{}),
	}
}

func shutdownResult() PoolResult {
	return PoolResult{ExitCode: intPtr(-1), Stderr: shutdownMessage, Killed: true}
}

// Execute runs command, waiting for a free slot first. It never fails: every
// problem is part of the result.
func (p *Pool) Execute(ctx context.Context, command string, o PoolOptions) PoolResult {
	select {
	case p.slots <- struct{}{}:
		defer func() { <-p.slots }()
	case <-p.closedCh:
		return shutdownResult()
	case <-ctx.Done():
		return PoolResult{ExitCode: intPtr(-1), Stderr: "Command aborted before it started.", Killed: true}
	}
	p.mu.Lock()
	closing := p.closing
	p.mu.Unlock()
	if closing {
		return shutdownResult()
	}
	return p.run(ctx, command, o)
}

func (p *Pool) run(ctx context.Context, command string, o PoolOptions) PoolResult {
	cwd := resolveCwd(o.Cwd)
	started := time.Now()
	out, errOut := &capped{}, &capped{}
	env := append([]string(nil), p.baseEnv...)
	for k, v := range o.Env {
		env = append(env, k+"="+v)
	}
	spec := proc.Spec{Path: p.shell, Args: []string{"-l", "-c", WrapForShell(command, p.shell)}, Dir: cwd, Env: env, Stdout: out, Stderr: errOut}
	if o.StdinInput != "" {
		spec.Stdin = strings.NewReader(o.StdinInput)
	}
	process, err := p.sup.Start(spec)
	if err != nil {
		return PoolResult{ExitCode: intPtr(-1), Stderr: err.Error(), DurationMs: time.Since(started).Milliseconds(), Command: command, Cwd: cwd, Error: err.Error()}
	}
	watch := make(chan struct{})
	go func() {
		timer := time.NewTimer(clampTimeout(o.TimeoutMs, defaultTimeout))
		defer timer.Stop()
		select {
		case <-timer.C:
			process.Terminate("timeout")
		case <-ctx.Done():
			process.Terminate("aborted")
		case <-watch:
		}
	}()
	exit := process.Wait()
	close(watch)
	res := PoolResult{
		ExitCode: exitCodeOf(exit), Stdout: truncateChars(strings.TrimSpace(out.String()), maxPoolStdoutChars),
		Stderr: truncateChars(strings.TrimSpace(errOut.String()), maxPoolStderrChars),
		Killed: exit.Reason != "", TimedOut: exit.Reason == "timeout",
		DurationMs: time.Since(started).Milliseconds(), Command: command, Cwd: cwd,
	}
	p.mu.Lock()
	closing := p.closing
	p.mu.Unlock()
	if closing && exit.Reason == shutdownMessage {
		return shutdownResult()
	}
	return res
}

// Shutdown ends running commands and refuses new ones.
func (p *Pool) Shutdown() {
	p.closeOnce.Do(func() {
		p.mu.Lock()
		p.closing = true
		p.mu.Unlock()
		close(p.closedCh)
		p.sup.KillAll(shutdownMessage)
	})
}

// capped keeps the end of a stream: past 500000 characters only the last
// 250000 are kept.
type capped struct {
	mu  sync.Mutex
	buf []byte
}

func (c *capped) Write(p []byte) (int, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.buf = append(c.buf, p...)
	if len(c.buf) > poolBufferLimit {
		c.buf = append([]byte(nil), c.buf[len(c.buf)-poolBufferKeep:]...)
	}
	return len(p), nil
}

func (c *capped) String() string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return string(c.buf)
}

// truncateChars keeps the first max UTF-16 code units, as the Node worker did,
// and notes how long the text was.
func truncateChars(s string, max int) string {
	units := utf16.Encode([]rune(s))
	if len(units) <= max {
		return s
	}
	return string(utf16.Decode(units[:max])) + "\n...[truncated, " + strconv.Itoa(len(units)) + " total chars]"
}

func intPtr(n int) *int { return &n }
