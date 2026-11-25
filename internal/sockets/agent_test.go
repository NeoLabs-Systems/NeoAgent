package sockets

import (
	"errors"
	"strings"
	"testing"
	"time"
)

type codedErr struct{ code string }

func (e codedErr) Error() string     { return "denied" }
func (e codedErr) ErrorCode() string { return e.code }

type limitedErr struct{}

func (limitedErr) Error() string  { return "too many" }
func (limitedErr) RateLimit() any { return map[string]any{"window": "4h"} }

func historyRows(st *stack) []map[string]any {
	return st.rows(`SELECT user_id, agent_id, agent_run_id, conversation_id, role, content, metadata FROM conversation_history ORDER BY id`)
}

func TestAgentRunStoresMessageRunsEngineAndStoresReply(t *testing.T) {
	st := newStack(t)
	st.fake.chatWindow = 2
	st.fake.chatRecent = []map[string]any{
		{"role": "user", "content": "old 1"},
		{"role": "assistant", "content": "old reply"},
		{"role": "user", "content": "hello"}, // the message just stored, filtered out
		{"role": "assistant", "content": "old reply 2"},
	}
	st.fake.runResult = RunResult{RunID: "r-final", Content: "hi"}
	c := st.connect(1)
	c.emit("agent:run", map[string]any{
		"task": "hello", "agentId": "other",
		"options": map[string]any{"conversationId": "c-owned", "attachments": []any{"/etc/passwd"}, "trusted": true, "agent_id": "ignored"},
	})
	// the conversation is checked before anything runs; it is not the caller's yet
	if e := c.expect("run:error"); obj(e[0])["conversationId"] != "c-owned" || obj(e[0])["runId"] != nil {
		t.Fatalf("not-owned conversation: %v", e)
	}

	st.fake.own("c-owned")
	c.emit("agent:run", map[string]any{
		"task": "hello", "agentId": "other",
		"options": map[string]any{"conversationId": "c-owned", "attachments": []any{"/etc/passwd"}, "trusted": true},
	})
	st.fake.waitFor(t, "store user=1")
	calls := strings.Join(st.fake.seen(), "\n")
	for _, want := range []string{
		`resolve user=1 candidate="other"`,
		`store user=1 agent=agent-other conv=c-owned run=r-final`,
		`"AgentID":"agent-other"`, `"ConversationID":"c-owned"`, `"TriggerSource":"web"`,
		// last 2 of the non-matching recent messages
		`"PriorMessages":[{"content":"old reply","role":"assistant"},{"content":"old reply 2","role":"assistant"}]`,
		`"PriorSummary":"summary"`,
		// only agentId, agent_id and conversationId pass through from the client
		`"Client":{"conversationId":"c-owned"}`,
	} {
		if !strings.Contains(calls, want) {
			t.Errorf("missing %s in\n%s", want, calls)
		}
	}
	if strings.Contains(calls, "passwd") || strings.Contains(calls, "trusted") {
		t.Fatalf("client options leaked: %s", calls)
	}
	rows := historyRows(st)
	if len(rows) != 1 || rows[0]["agent_id"] != "agent-other" || rows[0]["conversation_id"] != "c-owned" ||
		rows[0]["role"] != "user" || rows[0]["content"] != "hello" || rows[0]["metadata"] != `{"platform":"web"}` ||
		rows[0]["agent_run_id"] != nil || rows[0]["user_id"] != int64(1) {
		t.Fatalf("history %v", rows)
	}
}

func TestAgentRunUsesTheDefaultConversation(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)
	c.emit("agent:run", map[string]any{"task": "hi"})
	st.fake.waitFor(t, "store user=1 agent=agent-main conv=conv-default-agent-main")
}

func TestAgentRunRejectsBadTasks(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)
	for _, task := range []any{"", nil, 5, []any{"x"}} {
		c.emit("agent:run", map[string]any{"task": task})
		if got := obj(c.expect("error")[0])["message"]; got != "Task must be a non-empty string" {
			t.Fatalf("%v: %v", task, got)
		}
	}
	c.emit("agent:run", map[string]any{"task": strings.Repeat("x", 50001)})
	if got := obj(c.expect("error")[0])["message"]; got != "Message too long (max 50,000 characters)" {
		t.Fatal(got)
	}
	c.emit("agent:run", map[string]any{"task": strings.Repeat("x", 50000)}) // exactly at the limit is accepted
	st.fake.waitFor(t, "run user=1")
	if len(historyRows(st)) != 1 {
		t.Fatal("only the accepted message is stored")
	}
}

func TestAgentRunFailureCarriesRunIDCodeAndRateLimit(t *testing.T) {
	st := newStack(t)
	st.fake.admins[1] = true
	st.fake.runErr = codedErr{"MODEL_LIMIT"}
	c := st.connect(1)
	c.emit("agent:run", map[string]any{"task": "x"})
	got := obj(c.expect("run:error")[0])
	runID, _ := got["runId"].(string)
	if len(runID) != 36 || got["error"] != "denied" || got["code"] != "MODEL_LIMIT" || got["conversationId"] != nil {
		t.Fatalf("%v", got)
	}
	if _, has := got["rateLimit"]; has {
		t.Fatal("rateLimit must be absent")
	}

	st.fake.runErr = limitedErr{}
	c.emit("agent:run", map[string]any{"task": "x"})
	got = obj(c.expect("run:error")[0])
	if _, has := got["code"]; has || obj(got["rateLimit"])["window"] != "4h" {
		t.Fatalf("%v", got)
	}

	st.fake.runErr = codedErr{"ENOENT"} // a system code is not shown to clients
	c.emit("agent:run", map[string]any{"task": "x"})
	if _, has := obj(c.expect("run:error")[0])["code"]; has {
		t.Fatal("system code leaked")
	}
}

func TestAgentRunErrorTextIsRedactedForNonAdmins(t *testing.T) {
	st := newStack(t)
	st.fake.runErr = errors.New("ENOENT /Users/x/secret")
	c := st.connect(1)
	c.emit("agent:run", map[string]any{"task": "x"})
	if got := obj(c.expect("run:error")[0])["error"]; got != "Something went wrong. Please try again." {
		t.Fatalf("%v", got)
	}
}

func TestAgentRunHandlesCommandsWithoutRunningTheEngine(t *testing.T) {
	st := newStack(t)
	st.fake.command = &CommandResult{Handled: true, Content: "", Events: []CommandEvent{{Name: "agents:changed", Payload: map[string]any{"agentId": "a"}}, {Name: "x:empty"}}}
	c := st.connect(1)
	c.emit("agent:run", map[string]any{"task": "/new"})
	if got := obj(c.expect("agents:changed")[0])["agentId"]; got != "a" {
		t.Fatal(got)
	}
	if got := c.expect("x:empty"); len(got) != 1 || len(obj(got[0])) != 0 {
		t.Fatalf("event without payload sends {}: %v", got)
	}
	if got := obj(c.expect("run:complete")[0])["content"]; got != "Done." {
		t.Fatal(got)
	}
	if st.fake.has("run ") || len(historyRows(st)) != 0 {
		t.Fatal("a command must not start a run or store a message")
	}
}

func TestAgentRunSteersAnActiveRun(t *testing.T) {
	st := newStack(t)
	st.fake.steerable = &SteerableRun{RunID: "run-active", AgentID: "agent-other", ConversationID: "conv-x"}
	st.fake.steerQueued = true
	c := st.connect(1)
	c.emit("agent:run", map[string]any{"task": "change course"})
	st.fake.waitFor(t, "steer run=run-active task=change course platform=web conv=conv-x socket=true")
	deadline := time.Now().Add(2 * time.Second)
	for len(historyRows(st)) == 0 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	rows := historyRows(st)
	if len(rows) != 1 || rows[0]["agent_run_id"] != "run-active" || rows[0]["agent_id"] != "agent-other" ||
		rows[0]["conversation_id"] != "conv-x" ||
		rows[0]["metadata"] != `{"platform":"web","steering":true,"agentId":"agent-main"}` {
		t.Fatalf("%v", rows)
	}
	if st.fake.has("run ") {
		t.Fatal("a steered message must not start a second run")
	}

	// Not queued: the message becomes a normal run.
	st.fake.steerQueued = false
	c.emit("agent:run", map[string]any{"task": "second"})
	st.fake.waitFor(t, "run user=1 task=second")
}

func TestAgentAbort(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)
	c.emit("agent:abort", map[string]any{"runId": "  run-1  "})
	if got := obj(c.expect("agent:aborted")[0])["runId"]; got != "run-1" {
		t.Fatal(got)
	}
	c.emit("agent:abort")
	if got := obj(c.expect("agent:aborted")[0])["runId"]; got != nil {
		t.Fatalf("runId %v", got)
	}
	if !st.fake.has(`abort run="run-1" user=1`) || !st.fake.has(`abort run="" user=1`) {
		t.Fatal(st.fake.seen())
	}
	st.fake.abortErr = errors.New("nothing to abort")
	c.emit("agent:abort", map[string]any{})
	if got := obj(c.expect("error")[0])["message"]; got != "Something went wrong. Please try again." {
		t.Fatal(got)
	}
}

func TestAgentHistoryListsTheCallersRunsOnly(t *testing.T) {
	st := newStack(t)
	for i, r := range []struct {
		id    string
		user  int
		agent string
	}{{"run-a", 1, "agent-main"}, {"run-b", 1, "agent-main"}, {"run-c", 1, "agent-other"}, {"run-d", 2, "agent-main"}} {
		st.exec(`INSERT INTO agent_runs (id, user_id, agent_id, title, created_at) VALUES (?, ?, ?, ?, ?)`,
			r.id, r.user, r.agent, "t"+r.id, "2026-01-0"+string(rune('1'+i))+" 00:00:00")
	}
	c := st.connect(1)
	c.emit("agent:history", map[string]any{"limit": 1})
	got := obj(c.expect("agent:history")[0])
	runs := got["runs"].([]any)
	if got["agentId"] != "agent-main" || len(runs) != 1 || obj(runs[0])["id"] != "run-b" {
		t.Fatalf("%v", got)
	}
	// the row carries every column with SQLite types
	row := obj(runs[0])
	if row["user_id"] != float64(1) || row["status"] != "pending" || row["error"] != nil || row["total_tokens"] != float64(0) {
		t.Fatalf("row %v", row)
	}
	c.emit("agent:history", map[string]any{"agentId": "other", "limit": "500"})
	got = obj(c.expect("agent:history")[0])
	if got["agentId"] != "agent-other" || len(got["runs"].([]any)) != 1 {
		t.Fatalf("%v", got)
	}
	c.emit("agent:history", map[string]any{"limit": 0})
	if len(obj(c.expect("agent:history")[0])["runs"].([]any)) != 1 { // clamped up to 1
		t.Fatal("limit 0 must clamp to 1")
	}
	c.emit("agent:history", map[string]any{"limit": "junk"})
	if len(obj(c.expect("agent:history")[0])["runs"].([]any)) != 2 { // default 20
		t.Fatal("junk limit must use the default")
	}
	if !st.fake.has("redact user=1") {
		t.Fatal("records must pass through runRecordsForUser")
	}
}

func TestAgentRunDetailChecksOwnership(t *testing.T) {
	st := newStack(t)
	st.exec(`INSERT INTO agent_runs (id, user_id, agent_id) VALUES ('mine', 1, 'agent-main'), ('theirs', 2, 'agent-main')`)
	st.exec(`INSERT INTO agent_steps (id, run_id, step_index, type) VALUES ('s2', 'mine', 2, 'tool'), ('s1', 'mine', 1, 'think'), ('s9', 'theirs', 1, 'think')`)
	st.exec(`INSERT INTO conversation_history (user_id, agent_run_id, role, content) VALUES (1, 'mine', 'user', 'q'), (2, 'theirs', 'user', 'secret')`)
	c := st.connect(1)

	c.emit("agent:run_detail", map[string]any{"runId": "mine"})
	got := obj(c.expect("agent:run_detail")[0])
	steps := got["steps"].([]any)
	if obj(got["run"])["id"] != "mine" || len(steps) != 2 || obj(steps[0])["id"] != "s1" ||
		len(got["history"].([]any)) != 1 || obj(got["events"].([]any)[0])["run"] != "mine" {
		t.Fatalf("%v", got)
	}
	if _, has := got["runs"]; has {
		t.Fatal("runs must be absent")
	}

	// A run of another account: nothing about it is revealed.
	c.emit("agent:run_detail", map[string]any{"runId": "theirs"})
	got = obj(c.expect("agent:run_detail")[0])
	if got["run"] != nil || len(got["steps"].([]any)) != 0 || len(got["history"].([]any)) != 0 || len(got["events"].([]any)) != 0 {
		t.Fatalf("leaked: %v", got)
	}
	c.emit("agent:run_detail", map[string]any{"runId": "missing"})
	if obj(c.expect("agent:run_detail")[0])["run"] != nil {
		t.Fatal("missing run")
	}

	c.emit("agent:run_detail", map[string]any{})
	if got := obj(c.expect("error")[0])["message"]; got != "runId is required" {
		t.Fatal(got)
	}
}
