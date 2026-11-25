package sockets

import (
	"encoding/json"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"
)

// events.json is the inventory of the Node server's Socket.IO events, scanned
// from its source by gen/inventory.js.
type inventory struct {
	ClientToServer []string `json:"clientToServer"`
	RateLimits     map[string]struct {
		WindowMs int `json:"windowMs"`
		Max      int `json:"max"`
	} `json:"rateLimits"`
	ServerToClient []struct {
		Event   string   `json:"event"`
		Sources []string `json:"sources"`
		Shape   *string  `json:"shape"`
	} `json:"serverToClient"`
}

func loadInventory(t *testing.T) inventory {
	t.Helper()
	raw, err := os.ReadFile("testdata/events.json")
	if err != nil {
		t.Fatal(err)
	}
	var inv inventory
	if err := json.Unmarshal(raw, &inv); err != nil {
		t.Fatal(err)
	}
	return inv
}

func keysOf[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func sameSet(t *testing.T, what string, got, want []string) {
	t.Helper()
	sort.Strings(got)
	sort.Strings(want)
	if strings.Join(got, " ") != strings.Join(want, " ") {
		missing, extra := diff(want, got), diff(got, want)
		t.Errorf("%s differ\n missing: %v\n extra:   %v", what, missing, extra)
	}
}

func diff(a, b []string) []string {
	in := map[string]bool{}
	for _, s := range b {
		in[s] = true
	}
	var out []string
	for _, s := range a {
		if !in[s] {
			out = append(out, s)
		}
	}
	return out
}

func TestEveryClientEventOfNodeHasAHandler(t *testing.T) {
	inv := loadInventory(t)
	c := &client{srv: &Server{cfg: Config{Services: Services{Voice: nil}}}}
	sameSet(t, "client events", keysOf(c.handlers()), inv.ClientToServer)
	sameSet(t, "refusal answers", keysOf(refusals), inv.ClientToServer)
}

func TestRateLimitsMatchNode(t *testing.T) {
	inv := loadInventory(t)
	sameSet(t, "rate-limited events", keysOf(eventLimits), keysOf(inv.RateLimits))
	for name, want := range inv.RateLimits {
		got := eventLimits[name]
		if got.window != time.Duration(want.WindowMs)*time.Millisecond || got.max != want.Max {
			t.Errorf("%s: %v/%d, Node has %dms/%d", name, got.window, got.max, want.WindowMs, want.Max)
		}
	}
}

// Server to client events: the ones this package emits, and the ones other
// domains emit through EmitToUser/EmitToRoom (listed with their owner).
var emittedHere = []string{
	"agent:aborted", "agent:history", "agent:run_detail", "error", "integrations:status",
	"mcp:error", "mcp:status", "mcp:tools", "memory:data", "memory:search_results",
	"messaging:connect_result", "messaging:disconnect_result", "messaging:error", "messaging:sent", "messaging:status",
	"run:complete", "run:error", "stream:error", "stream:frame", "stream:subscribed", "stream:unsubscribed",
	"voice:call_ended", "voice:error",
}

var emittedByDomains = map[string]string{
	// AI engine and run orchestration (engine.emit)
	"agent_task:update": "ai/loop", "agents:changed": "ai/tools", "behavior:decision": "behavior",
	"orchestration:complete": "ai", "orchestration:error": "ai", "orchestration:start": "ai",
	"parallel:complete": "ai", "parallel:start": "ai",
	"run:analysis": "ai", "run:assistant_interim": "ai", "run:background": "ai", "run:interim": "ai",
	"run:interrupted": "ai", "run:paused": "ai", "run:pausing": "ai", "run:phase": "ai", "run:plan": "ai",
	"run:resumed": "ai", "run:start": "ai", "run:steer_applied": "ai", "run:steer_queued": "ai",
	"run:stopped": "ai", "run:stopping": "ai", "run:stream": "ai", "run:subagent": "ai", "run:thinking": "ai",
	"run:tool_end": "ai", "run:tool_start": "ai", "run:verification": "ai",
	"tasks:task_complete": "tasks", "tasks:task_deleted": "tasks", "tasks:task_error": "tasks",
	"tasks:task_running": "tasks", "tasks:task_skipped": "tasks",
	"tool:approval_required": "security/approvals", "tool:approval_resolved": "security/approvals",
	// messaging manager
	"messaging:attention_required": "messaging", "messaging:blocked_sender": "messaging",
	"messaging:connected": "messaging", "messaging:disconnected": "messaging", "messaging:link_failed": "messaging",
	"messaging:linked": "messaging", "messaging:logged_out": "messaging", "messaging:message": "messaging",
	"messaging:qr": "messaging",
	// voice runtime and agent calls
	"voice:audio": "voice", "voice:call_cancelled": "voice", "voice:incoming_call": "voice",
	"voice:interrupted": "voice", "voice:session_ready": "voice", "voice:state": "voice",
	"voice:task": "voice", "voice:transcript": "voice",
	// others
	"computer:status": "runtime", "device_sync:wake": "integrations/phone", "memory:sweep_progress": "memory",
	"settings:changed": "ai/integrated_tools", "skill:learned": "skills", "skill:retired": "skills", "teach:status": "teach",
}

func TestEveryServerEventOfNodeIsAccountedFor(t *testing.T) {
	inv := loadInventory(t)
	var all []string
	for _, e := range inv.ServerToClient {
		all = append(all, e.Event)
	}
	known := append(append([]string(nil), emittedHere...), keysOf(emittedByDomains)...)
	sameSet(t, "server events", known, all)
}

// literals returns the string literals of the package's non-test source.
func literals(t *testing.T) map[string]bool {
	t.Helper()
	files, err := filepath.Glob("*.go")
	if err != nil {
		t.Fatal(err)
	}
	found := map[string]bool{}
	fset := token.NewFileSet()
	for _, f := range files {
		if strings.HasSuffix(f, "_test.go") {
			continue
		}
		tree, err := parser.ParseFile(fset, f, nil, 0)
		if err != nil {
			t.Fatal(err)
		}
		ast.Inspect(tree, func(n ast.Node) bool {
			if lit, ok := n.(*ast.BasicLit); ok && lit.Kind == token.STRING {
				if s, err := strconv.Unquote(lit.Value); err == nil {
					found[s] = true
				}
			}
			return true
		})
	}
	return found
}

func TestEventsEmittedHereAppearInTheSource(t *testing.T) {
	src := literals(t)
	for _, name := range emittedHere {
		if !src[name] {
			t.Errorf("%s is claimed by this package but never emitted", name)
		}
	}
	clientSent := map[string]bool{}
	for _, name := range loadInventory(t).ClientToServer {
		clientSent[name] = true // e.g. voice:audio is also a handler key here
	}
	for name := range emittedByDomains {
		if src[name] && !clientSent[name] {
			t.Errorf("%s is owned by another domain but emitted here", name)
		}
	}
}
