package agent

import (
	"context"
	"database/sql"
	"errors"
	"log/slog"
	"os"
	"sort"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
)

// ErrShuttingDown refuses new runs once shutdown began.
var ErrShuttingDown = &codedError{msg: "Agent engine is shutting down.", code: "AGENT_ENGINE_SHUTTING_DOWN"}

type codedError struct {
	msg, code string
	status    int
}

func (e *codedError) Error() string   { return e.msg }
func (e *codedError) Code() string    { return e.code }
func (e *codedError) StatusCode() int { return e.status }

// Engine runs agents. One per process.
type Engine struct {
	deps    Deps
	ledger  *runledger.Ledger
	vectors *toolVectors
	log     *slog.Logger
	// IsAdmin decides what an account may read of a failure; nil treats every
	// account as a non-admin.
	IsAdmin func(ctx context.Context, userID int64) bool
	// StoreWebReply writes a web run's answer into the chat transcript for runs
	// no caller waits on (resumed runs, agent task reports).
	StoreWebReply StoreWebReply

	mu   sync.Mutex
	runs map[string]*Run

	lifecycle    context.Context
	stopAll      context.CancelFunc
	shuttingDown bool
	work         sync.WaitGroup

	queueMu sync.Mutex
	queues  map[string]chan struct{}

	subagents *subagentRegistry
}

// New creates the engine.
func New(deps Deps) *Engine {
	log := deps.Log
	if log == nil {
		log = slog.Default()
	}
	if deps.Getenv == nil {
		deps.Getenv = os.Getenv
	}
	ctx, cancel := context.WithCancel(context.Background())
	e := &Engine{
		deps:      deps,
		vectors:   newToolVectors(deps.DataDir),
		ledger:    &runledger.Ledger{DB: deps.DB, Log: log},
		log:       log,
		runs:      map[string]*Run{},
		lifecycle: ctx,
		stopAll:   cancel,
		queues:    map[string]chan struct{}{},
	}
	e.subagents = newSubagentRegistry(e)
	return e
}

// Ledger is the run ledger the engine writes.
func (e *Engine) Ledger() *runledger.Ledger { return e.ledger }

// SetBackend installs the tool backend (built after the engine, since tool
// handlers call back into it).
func (e *Engine) SetBackend(b ai.ToolBackend) { e.deps.Backend = b }

// RunInfo is the active run with that id.
func (e *Engine) RunInfo(runID string) (*Run, bool) {
	e.mu.Lock()
	defer e.mu.Unlock()
	r, ok := e.runs[runID]
	return r, ok
}

func (e *Engine) activeRuns() []*Run {
	e.mu.Lock()
	defer e.mu.Unlock()
	out := make([]*Run, 0, len(e.runs))
	for _, r := range e.runs {
		out = append(out, r)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].StartedAt.Before(out[j].StartedAt) })
	return out
}

func (e *Engine) isAdmin(userID int64) bool {
	return e.IsAdmin != nil && e.IsAdmin(context.Background(), userID)
}

// NonAdminError is what a non-admin may read of an error text.
func NonAdminError(text string) string {
	message := publicerr.Sanitize(text, "", "")
	if message == "" || publicerr.LooksTechnical(message) {
		return publicerr.Generic
	}
	return message
}

// Emit sends a run event to the user's clients. Events naming a run carry its
// conversation; failures reach non-admins redacted.
func (e *Engine) Emit(userID int64, event string, payload map[string]any) {
	if e.deps.Emitter == nil {
		return
	}
	out := make(map[string]any, len(payload)+2)
	for k, v := range payload {
		out[k] = v
	}
	if runID, _ := out["runId"].(string); runID != "" && out["conversationId"] == nil {
		conversation, device := "", ""
		if r, ok := e.RunInfo(runID); ok {
			conversation, device = r.ConversationID, r.DeviceTarget
		} else if e.deps.DB != nil {
			var c, d sql.NullString
			_ = e.deps.DB.R.QueryRow(`SELECT conversation_id, device_target FROM agent_runs WHERE id = ?`, runID).Scan(&c, &d)
			conversation, device = c.String, d.String
		}
		if conversation != "" {
			out["conversationId"] = conversation
			if device != "" {
				out["deviceTarget"] = device
			} else {
				out["deviceTarget"] = nil
			}
		}
	}
	if text, ok := out["error"].(string); ok && text != "" && !e.isAdmin(userID) {
		if event == "run:tool_end" {
			// A failed tool's own output is the same raw text as its error.
			out["error"] = publicerr.Generic
			out["result"] = nil
		} else {
			out["error"] = NonAdminError(text)
		}
	}
	e.deps.Emitter.EmitToUser(userID, event, out)
}

// Background runs task as tracked engine work, after any earlier task with the
// same key. Shutdown waits for it. With coalesce, a task whose key is already
// queued is dropped.
func (e *Engine) Background(key string, coalesce bool, task func(ctx context.Context) error) error {
	e.mu.Lock()
	if e.shuttingDown {
		e.mu.Unlock()
		return ErrShuttingDown
	}
	e.work.Add(1)
	e.mu.Unlock()

	e.queueMu.Lock()
	previous := e.queues[key]
	if key != "" && previous != nil && coalesce {
		e.queueMu.Unlock()
		e.work.Done()
		return nil
	}
	done := make(chan struct{})
	if key != "" {
		e.queues[key] = done
	}
	e.queueMu.Unlock()

	go func() {
		defer e.work.Done()
		defer func() {
			close(done)
			e.queueMu.Lock()
			if e.queues[key] == done {
				delete(e.queues, key)
			}
			e.queueMu.Unlock()
		}()
		if previous != nil {
			select {
			case <-previous:
			case <-e.lifecycle.Done():
				return
			}
		}
		if e.lifecycle.Err() != nil {
			return
		}
		if err := task(e.lifecycle); err != nil && e.lifecycle.Err() == nil {
			e.log.Warn("Background agent work failed", "key", key, "error", err)
		}
	}()
	return nil
}

// Shutdown interrupts every active run and waits up to timeout for runs and
// background work to finish. It reports whether the wait timed out.
func (e *Engine) Shutdown(reason string, timeout time.Duration) bool {
	if reason == "" {
		reason = "Server shutting down while agent work was in progress."
	}
	if timeout < 100*time.Millisecond {
		timeout = 10 * time.Second
	}
	e.mu.Lock()
	e.shuttingDown = true
	e.mu.Unlock()
	e.InterruptAll(reason)
	e.stopAll()
	done := make(chan struct{})
	go func() {
		e.work.Wait()
		close(done)
	}()
	select {
	case <-done:
		return false
	case <-time.After(timeout):
		return true
	}
}

// ShuttingDown says whether shutdown began.
func (e *Engine) ShuttingDown() bool {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.shuttingDown
}

func (e *Engine) execDB(ctx context.Context, query string, args ...any) {
	if _, err := e.deps.DB.W.ExecContext(ctx, query, args...); err != nil && !errors.Is(err, context.Canceled) {
		e.log.Warn("Run bookkeeping write failed", "error", err)
	}
}
