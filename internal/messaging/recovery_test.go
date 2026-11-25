package messaging

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

type offlinePlatform struct {
	mu     sync.Mutex
	status string
	ev     Events
}

func (p *offlinePlatform) Connect(context.Context) error {
	p.mu.Lock()
	p.status = StatusConnected
	p.mu.Unlock()
	p.ev.Connected()
	return nil
}
func (p *offlinePlatform) Disconnect(context.Context) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.status = StatusDisconnected
	return nil
}
func (p *offlinePlatform) Status() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.status
}
func (p *offlinePlatform) AuthInfo() map[string]any     { return nil }
func (p *offlinePlatform) SetAccessPolicy(AccessPolicy) {}
func (p *offlinePlatform) AccessPolicy() AccessPolicy   { return AccessPolicy{} }
func (p *offlinePlatform) SendMessage(context.Context, string, string, SendOptions) (SendResult, error) {
	return SendResult{}, nil
}

type oneAgent struct{}

func (oneAgent) Resolve(context.Context, int64, string) (string, error) { return "a1", nil }
func (oneAgent) IsMain(context.Context, int64, string) (bool, error)    { return true, nil }

// replayLog collects what the agent handled and what reached the app.
type replayLog struct {
	mu      sync.Mutex
	handled [][]any
	emitted [][]any
}

func (l *replayLog) take() (handled, emitted [][]any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	handled, emitted = append([][]any{}, l.handled...), append([][]any{}, l.emitted...)
	l.handled, l.emitted = nil, nil
	return
}

func (l *replayLog) EmitToUser(_ int64, event string, payload any) {
	if event != "messaging:message" {
		return
	}
	m := payload.(*Message)
	l.mu.Lock()
	l.emitted = append(l.emitted, []any{string(m.MessageID), m.Content})
	l.mu.Unlock()
}

func (l *replayLog) HandleMessage(_ context.Context, userID int64, _ string, m *Message) Outcome {
	l.mu.Lock()
	l.handled = append(l.handled, []any{userID, m.Platform, string(m.MessageID), m.Content})
	l.mu.Unlock()
	switch m.Content {
	case "boom":
		return Outcome{Err: errors.New("boom failed")}
	case "cancel":
		return Outcome{Err: context.Canceled}
	}
	return Outcome{}
}

// TestRecoveryMatchesNode replays messages stored while WhatsApp was offline,
// as Node's recoverPendingInbound did (testdata/gen_recovery.js): nothing runs
// before the platform connects, the connection replays the pending jobs, and
// redeliveries only rerun jobs that failed before a run began.
func TestRecoveryMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/recovery_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors struct {
		Setup  []string
		States []string
		Seeds  []struct{ Platform, MessageID, Content, ChatID, Sender, Timestamp string }
		Steps  []struct {
			Label   string
			Result  json.RawMessage
			Handled json.RawMessage
			Emitted json.RawMessage
			Jobs    json.RawMessage
		}
	}
	if err := json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	dir := t.TempDir()
	db, err := dbx.Open(ctx, filepath.Join(dir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, q := range vectors.Setup {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	log := &replayLog{}
	var platform *offlinePlatform
	m := NewManager(ManagerConfig{DB: db, Agents: oneAgent{}, Emitter: log, Engine: log, DataDir: dir,
		Factories: map[string]Factory{"whatsapp": func(_ Config, ev Events) (Platform, error) {
			platform = &offlinePlatform{status: StatusDisconnected, ev: ev}
			return platform, nil
		}}})
	defer m.Stop()
	for _, s := range vectors.Seeds {
		msg := Message{AgentID: "a1", Platform: s.Platform, ChatID: s.ChatID, MessageID: nstr(s.MessageID),
			Sender: s.Sender, Content: s.Content, Timestamp: s.Timestamp}
		if _, err := m.store.EnqueueInbound(ctx, 1, "a1", msg, map[string]any{}); err != nil {
			t.Fatal(err)
		}
	}
	for _, q := range vectors.States {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}

	jobs := func() string {
		rows, err := db.R.Query(`SELECT platform_msg_id, status, attempts, run_id, last_error
			FROM messaging_inbound_jobs ORDER BY created_at, platform_msg_id`)
		if err != nil {
			t.Fatal(err)
		}
		defer rows.Close()
		var list []map[string]any
		for rows.Next() {
			var id, status string
			var attempts int
			var runID, lastErr *string
			if err := rows.Scan(&id, &status, &attempts, &runID, &lastErr); err != nil {
				t.Fatal(err)
			}
			list = append(list, map[string]any{"id": id, "status": status, "attempts": attempts, "run_id": runID, "last_error": lastErr})
		}
		return canon(list)
	}
	// settle waits until the jobs reach Node's state and nothing is in flight.
	settle := func(want string) {
		deadline := time.Now().Add(5 * time.Second)
		for time.Now().Before(deadline) {
			m.jobs.mu.Lock()
			busy := len(m.jobs.active) + len(m.jobs.recoveries)
			m.jobs.mu.Unlock()
			if busy == 0 && jobs() == want {
				return
			}
			time.Sleep(5 * time.Millisecond)
		}
	}
	inbound := func(id, content string, i int) Inbound {
		return Inbound{ChatID: "chat-whatsapp", MessageID: id, Sender: "ann", Content: content,
			Timestamp: "2026-11-01T11:00:0" + string(rune('0'+i)) + ".000Z"}
	}

	for _, s := range vectors.Steps {
		var result any
		want := canon(json.RawMessage(s.Jobs))
		switch s.Label {
		case "offline recovery":
			recovered, skipped, err := m.RecoverPending(ctx, JobFilter{})
			if err != nil {
				t.Fatal(err)
			}
			result = map[string]int{"recovered": recovered, "skipped": skipped}
		case "reconnected":
			if _, err := m.ConnectPlatform(ctx, 1, "a1", "whatsapp", map[string]any{}, true); err != nil {
				t.Fatal(err)
			}
		case "redelivered completed":
			m.ingest(1, "a1", "whatsapp", inbound("w1", "first", 0))
		case "redelivered failed":
			m.ingest(1, "a1", "whatsapp", inbound("w2", "boom", 1))
		case "new message":
			m.ingest(1, "a1", "whatsapp", inbound("w8", "fresh", 2))
		case "scoped recovery":
			uid, agent, plat := int64(1), "a1", "whatsapp"
			recovered, skipped, err := m.RecoverPending(ctx, JobFilter{UserID: &uid, AgentID: &agent, Platform: &plat})
			if err != nil {
				t.Fatal(err)
			}
			result = map[string]int{"recovered": recovered, "skipped": skipped}
		default:
			t.Fatalf("unknown step %q", s.Label)
		}
		settle(want)
		handled, emitted := log.take()
		if got := jobs(); got != want {
			t.Errorf("%s jobs:\n got %s\nwant %s", s.Label, got, want)
		}
		if got, want := canon(result), canon(json.RawMessage(s.Result)); got != want {
			t.Errorf("%s result: got %s want %s", s.Label, got, want)
		}
		if got, want := canon(handled), canon(json.RawMessage(s.Handled)); got != want {
			t.Errorf("%s handled:\n got %s\nwant %s", s.Label, got, want)
		}
		if got, want := canon(emitted), canon(json.RawMessage(s.Emitted)); got != want {
			t.Errorf("%s emitted: got %s want %s", s.Label, got, want)
		}
	}
	if platform == nil {
		t.Fatal("whatsapp never connected")
	}
}
