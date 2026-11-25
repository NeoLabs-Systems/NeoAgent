package security

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

type env struct{}

func (env) HostTerminal() bool           { return false }
func (env) WebSharingEnabled(int64) bool { return true }

type vectors struct {
	Categories []struct {
		Name     string         `json:"name"`
		Args     map[string]any `json:"args"`
		Category *string        `json:"category"`
		Safe     bool           `json:"safe"`
	} `json:"categories"`
	Reviews []struct {
		Label  string         `json:"label"`
		Name   string         `json:"name"`
		Args   map[string]any `json:"args"`
		Review *struct {
			Kind         string            `json:"kind"`
			Reason       string            `json:"reason"`
			ReasonKey    string            `json:"reasonKey"`
			ReasonParams map[string]string `json:"reasonParams"`
		} `json:"review"`
	} `json:"reviews"`
	Copies []struct {
		Language, AgentName, Title, Action, Detail, Reason string
	} `json:"copies"`
	Options []struct {
		ID, Label, Word, Emoji, Decision, Scope string
	} `json:"options"`
	Hint, Note, TimedOut string
}

func load(t *testing.T) vectors {
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func registry(t *testing.T) *tools.Registry {
	r, err := tools.NewRegistry(env{})
	if err != nil {
		t.Fatal(err)
	}
	return r
}

func testDB(t *testing.T) *dbx.DB {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "t.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'owner', 'x')`); err != nil {
		t.Fatal(err)
	}
	return db
}

func TestCategoriesMatchNode(t *testing.T) {
	c := NewCatalog(registry(t))
	for _, v := range load(t).Categories {
		want := ""
		if v.Category != nil {
			want = *v.Category
		}
		if got := c.CategoryFor(v.Name, v.Args); got != want {
			t.Errorf("%s %v: category %q, want %q", v.Name, v.Args, got, want)
		}
		if c.Safe(v.Name) != v.Safe {
			t.Errorf("%s: safe %v, want %v", v.Name, c.Safe(v.Name), v.Safe)
		}
	}
}

func TestTrustReviewMatchesNode(t *testing.T) {
	reg := registry(t)
	c := NewCatalog(reg)
	owner := agent.NewTrust("owner", false, "web", []llm.Message{{Role: "user", Content: "email bob@example.com please, my number is +49 151 1234567"}}, nil, nil)
	tainted := agent.NewTrust("owner", false, "web", []llm.Message{{Role: "user", Content: "email bob@example.com please"}}, nil, nil)
	tainted.RecordToolOutput(reg, "web_search", nil)
	shared := agent.NewTrust("shared", false, "messaging", []llm.Message{{Role: "user", Content: "hi"}},
		&agent.TrustOrigin{Platform: "telegram", ChatID: "g1", SenderID: "u1", IsGroup: true}, []string{"/m/a.png"})
	trusts := map[string]*agent.Trust{"owner": owner}
	for _, v := range load(t).Reviews {
		trust := trusts[v.Label]
		switch {
		case len(v.Label) >= 7 && v.Label[:7] == "tainted":
			trust = tainted
		case len(v.Label) >= 6 && v.Label[:6] == "shared":
			trust = shared
		}
		got := ReviewCall(reg, v.Name, v.Args, c.CategoryFor(v.Name, v.Args), trust)
		if v.Review == nil {
			if got != nil {
				t.Errorf("%s: review %+v, want none", v.Label, got)
			}
			continue
		}
		if got == nil || got.Kind != v.Review.Kind || got.Reason != v.Review.Reason || got.ReasonKey != v.Review.ReasonKey ||
			(len(v.Review.ReasonParams) > 0 && !reflect.DeepEqual(got.ReasonParams, v.Review.ReasonParams)) {
			t.Errorf("%s: review %+v, want %+v", v.Label, got, v.Review)
		}
	}
}

func TestApprovalCopyMatchesNode(t *testing.T) {
	v := load(t)
	d := Describer{DB: testDB(t)}
	ctx := context.Background()
	got := d.Describe(ctx, 1, "", "execute_command", map[string]any{"command": "rm   -rf  /tmp/x\nnow"}, []string{"command"}, "shell",
		"You did not name eve as a recipient", "newRecipient", map[string]string{"recipient": "eve"})
	if want := v.Copies[0]; got.Title != want.Title || got.Action != want.Action || got.Detail != want.Detail || got.Reason != want.Reason {
		t.Errorf("copy %+v, want %+v", got, want)
	}
	long := ""
	for i := 0; i < 300; i++ {
		long += "x"
	}
	got = d.Describe(ctx, 1, "", "mcp_tool", map[string]any{"foo": long}, []string{"foo"}, "external", "", "", nil)
	if want := v.Copies[1]; got.Action != want.Action || got.Detail != want.Detail || got.Reason != want.Reason {
		t.Errorf("copy %+v, want %+v", got, want)
	}
	for i, o := range Options("de") {
		w := v.Options[i]
		if o.ID != w.ID || o.Label != w.Label || o.Word != w.Word || o.Decision != w.Decision || o.Scope != w.Scope {
			t.Errorf("option %+v, want %+v", o, w)
		}
	}
	if ReplyHint("de") != v.Hint || TimeLimitNote("en", 5) != v.Note || TimedOutNotice("fr", "Run a command") != v.TimedOut {
		t.Error("prompt texts differ from Node")
	}
}

type recorder struct{ events []string }

func (r *recorder) EmitToUser(_ int64, event string, _ any) { r.events = append(r.events, event) }

func TestGateWaitsForTheOwner(t *testing.T) {
	db := testDB(t)
	rec := &recorder{}
	policies := &Policies{DB: db, Catalog: NewCatalog(registry(t))}
	gate := NewGate(db, rec, policies, nil)
	if _, err := db.W.Exec(`INSERT INTO agent_runs (id, user_id, title, status) VALUES ('r1', 1, 'x', 'running')`); err != nil {
		t.Fatal(err)
	}
	done := make(chan string, 1)
	go func() {
		done <- gate.Request(context.Background(), ApprovalRequest{UserID: 1, RunID: "r1", ToolName: "execute_command", Args: map[string]any{"command": "ls"}})
	}()
	var id string
	for deadline := time.Now().Add(3 * time.Second); id == ""; {
		_ = db.R.QueryRow(`SELECT id FROM pending_approvals WHERE status = 'pending'`).Scan(&id)
		if time.Now().After(deadline) {
			t.Fatal("no approval was asked for")
		}
		time.Sleep(10 * time.Millisecond)
	}
	if gate.Decide(context.Background(), id, 2, "approved", "once") != nil {
		t.Fatal("another user decided")
	}
	if gate.Decide(context.Background(), id, 1, "approved", "always") == nil {
		t.Fatal("decision refused")
	}
	if got := <-done; got != "approved" {
		t.Fatalf("decision = %s", got)
	}
	if !gate.HasSessionGrant(1, "r1", "execute_command") {
		t.Fatal("always did not grant the run")
	}
	if policies.CategoryPolicy(context.Background(), 1, "shell") != "allow" {
		t.Fatal("always did not save the policy")
	}
	var logged int
	_ = db.R.QueryRow(`SELECT COUNT(*) FROM tool_approval_log WHERE decision = 'approved' AND scope = 'session'`).Scan(&logged)
	if logged != 1 || len(rec.events) != 2 || rec.events[0] != "tool:approval_required" || rec.events[1] != "tool:approval_resolved" {
		t.Fatalf("logged=%d events=%v", logged, rec.events)
	}
}

func TestPermissionsFollowTheManagerChain(t *testing.T) {
	db := testDB(t)
	for _, id := range []int{2, 3} {
		if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (?, ?, 'x')`, id, "u"+string(rune('0'+id))); err != nil {
			t.Fatal(err)
		}
	}
	// 3 manages 2 and allows shell; 2 manages 1 and allows shell and file_write.
	_, _ = db.W.Exec(`INSERT INTO user_delegations (managed_user_id, manager_user_id, allowed_permissions_json) VALUES (2, 3, '["shell"]'), (1, 2, '["shell","file_write"]')`)
	ctx := context.Background()
	p := ResolvePermissions(ctx, db, 1)
	if !p["shell"].Allowed || p["shell"].SetBy != 2 {
		t.Fatalf("shell = %+v", p["shell"])
	}
	if p["file_write"].Allowed || p["file_write"].SetBy != 3 {
		t.Fatalf("file_write = %+v", p["file_write"])
	}
	if Permitted(ctx, db, 1, "network_write") {
		t.Fatal("network_write allowed")
	}
}

func TestGuardAsksAndBlocksOnDenial(t *testing.T) {
	db := testDB(t)
	reg := registry(t)
	policies := &Policies{DB: db, Catalog: NewCatalog(reg)}
	gate := NewGate(db, &recorder{}, policies, nil)
	if _, err := db.W.Exec(`INSERT INTO agent_runs (id, user_id, title, status) VALUES ('r1', 1, 'x', 'running')`); err != nil {
		t.Fatal(err)
	}
	guard := &Guard{DB: db, Policies: policies, Approvals: gate, Registry: reg}
	g := guard.Gate(&agent.Run{ID: "r1", UserID: 1})
	ctx := context.Background()
	// A safe tool never asks.
	if block, _ := g.BeforeToolCall(ctx, nil, aiCall("send_message", map[string]any{"to": "x"}), reg.Meta("send_message", nil)); block {
		t.Fatal("send_message blocked")
	}
	go func() {
		for {
			var id string
			if db.R.QueryRow(`SELECT id FROM pending_approvals WHERE status = 'pending'`).Scan(&id) == nil {
				gate.Decide(ctx, id, 1, "denied", "once")
				return
			}
			time.Sleep(10 * time.Millisecond)
		}
	}()
	block, reason := g.BeforeToolCall(ctx, nil, aiCall("execute_command", map[string]any{"command": "ls"}), reg.Meta("execute_command", nil))
	if !block || reason != `The user denied the use of "execute_command". Do not retry this tool call in this run.` {
		t.Fatalf("block=%v reason=%q", block, reason)
	}
	// A denied category is refused without asking; allow_all lifts it.
	if err := policies.SetPolicy(ctx, 1, "shell", "deny"); err != nil {
		t.Fatal(err)
	}
	if block, _ := g.BeforeToolCall(ctx, nil, aiCall("execute_command", map[string]any{"command": "ls"}), reg.Meta("execute_command", nil)); !block {
		t.Fatal("denied category ran")
	}
	if err := policies.SetMode(ctx, 1, "allow_all"); err != nil {
		t.Fatal(err)
	}
	if block, _ := g.BeforeToolCall(ctx, nil, aiCall("execute_command", map[string]any{"command": "ls"}), reg.Meta("execute_command", nil)); block {
		t.Fatal("allow_all still blocked")
	}
	// Delegation holds whatever the mode.
	_, _ = db.W.Exec(`INSERT INTO users (id, username, password) VALUES (9, 'boss', 'x')`)
	_, _ = db.W.Exec(`INSERT INTO user_delegations (managed_user_id, manager_user_id, allowed_permissions_json) VALUES (1, 9, '[]')`)
	if block, reason := g.BeforeToolCall(ctx, nil, aiCall("execute_command", map[string]any{"command": "ls"}), reg.Meta("execute_command", nil)); !block || reason == "" {
		t.Fatal("delegation did not block")
	}
}

func aiCall(name string, args map[string]any) ai.Call {
	raw, _ := json.Marshal(args)
	return ai.Call{Name: name, Arguments: args, Raw: llm.ToolCall{Function: llm.FunctionCall{Name: name, Arguments: string(raw)}}}
}
