package behavior

import (
	"bytes"
	"context"
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Vectors recorded from the Node server (server/services/behavior) on a
// temporary NEOAGENT_HOME.
type vectors struct {
	Normalized []struct {
		Input  json.RawMessage `json:"input"`
		Output json.RawMessage `json:"output"`
	} `json:"normalized"`
	Resolved []struct {
		Config   int             `json:"config"`
		Platform string          `json:"platform"`
		ChatID   string          `json:"chatId"`
		IsGroup  bool            `json:"isGroup"`
		Output   json.RawMessage `json:"output"`
	} `json:"resolved"`
	Bubbles []struct {
		Platform   string   `json:"platform"`
		Text       string   `json:"text"`
		MaxBubbles int      `json:"maxBubbles"`
		Output     []string `json:"output"`
	} `json:"bubbles"`
	Addressing []struct {
		Names   []string `json:"names"`
		Content string   `json:"content"`
		Output  bool     `json:"output"`
	} `json:"addressing"`
	Packets []struct {
		Msg         json.RawMessage `json:"msg"`
		Config      json.RawMessage `json:"config"`
		ThreadState json.RawMessage `json:"threadState"`
		RoomMsgs    []RoomMessage   `json:"roomMessages"`
		Addressing  *struct {
			AddressedByName bool     `json:"addressedByName"`
			Names           []string `json:"names"`
		} `json:"addressing"`
		Output json.RawMessage `json:"output"`
	} `json:"packets"`
	Decisions []struct {
		Raw      map[string]any  `json:"raw"`
		Fallback map[string]any  `json:"fallback"`
		Output   json.RawMessage `json:"output"`
	} `json:"decisions"`
	HoldBack json.RawMessage   `json:"holdBack"`
	Rule     []json.RawMessage `json:"rule"`
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

func canonical(t *testing.T, v any) string {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	if err := json.Compact(&buf, raw); err != nil {
		t.Fatal(err)
	}
	return buf.String()
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
	for _, q := range []string{`INSERT INTO users (id, username, password) VALUES (1, 'owner', 'x')`,
		`INSERT INTO agents (id, user_id, slug, display_name) VALUES ('a1', 1, 'helper', 'Helper')`} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	return db
}

func TestNormalizeStoredMatchesNode(t *testing.T) {
	for i, v := range load(t).Normalized {
		if got, want := canonical(t, NormalizeStored(v.Input)), canonical(t, v.Output); got != want {
			t.Errorf("case %d:\n got %s\nwant %s", i, got, want)
		}
	}
}

func TestResolveMatchesNode(t *testing.T) {
	v := load(t)
	db := testDB(t)
	store := NewStore(db)
	ctx := context.Background()
	for i, r := range v.Resolved {
		if r.Config >= 0 {
			if _, err := store.Set(ctx, 1, "a1", v.Normalized[r.Config].Input); err != nil {
				t.Fatal(err)
			}
		} else if _, err := db.W.Exec(`DELETE FROM agent_settings WHERE agent_id = 'a1'`); err != nil {
			t.Fatal(err)
		}
		got := canonical(t, store.Resolve(ctx, 1, "a1", r.Platform, r.ChatID, r.IsGroup))
		if want := canonical(t, r.Output); got != want {
			t.Errorf("case %d (config %d %s/%s group=%v):\n got %s\nwant %s", i, r.Config, r.Platform, r.ChatID, r.IsGroup, got, want)
		}
	}
}

func TestBubblesMatchNode(t *testing.T) {
	for _, v := range load(t).Bubbles {
		got := SplitIntoNaturalBubbles(v.Platform, v.Text, v.MaxBubbles)
		if canonical(t, got) != canonical(t, v.Output) {
			t.Errorf("%s %q max %d:\n got %q\nwant %q", v.Platform, v.Text[:min(len(v.Text), 40)], v.MaxBubbles, got, v.Output)
		}
	}
}

func TestAddressingMatchesNode(t *testing.T) {
	v := load(t)
	msgs := []*messaging.Message{
		{BotUsername: "neo_helper_bot", BotDisplayName: "Neo Helper", BotTag: "@neo_helper_bot"},
		{BotUsername: "ab", BotDisplayName: "Bot", BotTag: "Assistant#0001"},
		{BotDisplayName: "Jürgen-Bot"},
	}
	seen := map[string]bool{}
	for i, m := range msgs {
		names := AgentNames(context.Background(), nil, 0, "", m)
		want := v.Addressing[i*9].Names
		if canonical(t, names) != canonical(t, want) {
			t.Errorf("names %d: %q want %q", i, names, want)
		}
		seen[canonical(t, want)] = true
	}
	for _, a := range v.Addressing {
		if got := ContentAddressesAgent(a.Content, a.Names); got != a.Output {
			t.Errorf("%q in %q: %v want %v", a.Names, a.Content, got, a.Output)
		}
	}
}

func TestDecisionPacketMatchesNode(t *testing.T) {
	for i, c := range load(t).Packets {
		var m messaging.Message
		if err := json.Unmarshal(c.Msg, &m); err != nil {
			t.Fatal(err)
		}
		cfg := resolve(NormalizeStored(c.Config), true, "", "", false)
		var state ThreadState
		_ = json.Unmarshal(c.ThreadState, &state)
		var a Addressing
		if c.Addressing != nil {
			a = Addressing{Names: c.Addressing.Names, AddressedByName: c.Addressing.AddressedByName}
		}
		got := canonical(t, buildDecisionPacket(&m, cfg, state, c.RoomMsgs, a, time.Now()))
		if want := canonical(t, c.Output); got != want {
			t.Errorf("packet %d:\n got %s\nwant %s", i, got, want)
		}
	}
}

func decisionJSON(t *testing.T, d Decision) string {
	raw, _ := json.Marshal(d)
	var m map[string]any
	_ = json.Unmarshal(raw, &m)
	delete(m, "latencyMs")
	delete(m, "turnEpoch")
	return canonical(t, m)
}

func sorted(t *testing.T, raw json.RawMessage) string {
	var m map[string]any
	_ = json.Unmarshal(raw, &m)
	return canonical(t, m)
}

func reasonCodes(v any) any {
	if list, ok := v.([]any); ok {
		return list
	}
	return nil
}

func TestDecisionsMatchNode(t *testing.T) {
	v := load(t)
	for i, c := range v.Decisions {
		fb := decisionFallback{Decision: str(c.Fallback["decision"]), TokenPath: str(c.Fallback["tokenPath"]), Model: str(c.Fallback["model"]), Urgency: str(c.Fallback["urgency"])}
		fb.NeedScore, _ = c.Fallback["needScore"].(float64)
		fb.Confidence, _ = c.Fallback["confidence"].(float64)
		fb.ReasonCodes = append(fb.ReasonCodes, reasonCodesList(c.Fallback["reasonCodes"])...)
		raw := rawDecision{Decision: c.Raw["decision"], NeedScore: c.Raw["needScore"], Confidence: c.Raw["confidence"], ReasonCodes: reasonCodes(c.Raw["reasonCodes"]), Urgency: c.Raw["urgency"]}
		if u, ok := c.Raw["usage"].(float64); ok {
			raw.Usage = &u
		}
		if got, want := decisionJSON(t, normalizeDecision(raw, fb)), sorted(t, c.Output); got != want {
			t.Errorf("decision %d:\n got %s\nwant %s", i, got, want)
		}
	}
	if got, want := decisionJSON(t, holdBackDecision("model_unavailable")), sorted(t, v.HoldBack); got != want {
		t.Errorf("hold back:\n got %s\nwant %s", got, want)
	}
	rules := []Decision{ruleDecision("speak", "direct_chat", 1), ruleDecision("stay_silent", "mention_only", 0.9)}
	for i, r := range rules {
		if got, want := decisionJSON(t, r), sorted(t, v.Rule[i]); got != want {
			t.Errorf("rule %d:\n got %s\nwant %s", i, got, want)
		}
	}
}

func str(v any) string { s, _ := v.(string); return s }

func reasonCodesList(v any) []string {
	var out []string
	list, _ := reasonCodes(v).([]any)
	for _, item := range list {
		out = append(out, str(item))
	}
	return out
}

// --- Pipeline -----------------------------------------------------------------

type fakeInference struct {
	mu       sync.Mutex
	answer   map[string]any
	ready    bool
	decide   map[string]any
	requests []StructuredRequest
}

func (f *fakeInference) InferStructured(ctx context.Context, req StructuredRequest) (StructuredAnswer, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.requests = append(f.requests, req)
	return StructuredAnswer{Parsed: f.answer, Model: "judge"}, nil
}

func (f *fakeInference) Decide(ctx context.Context, req DecisionRequest) (map[string]any, error) {
	return f.decide, nil
}

func (f *fakeInference) SystemOneReady(ctx context.Context, userID int64, agentID string) (bool, error) {
	return f.ready, nil
}

type fakeSender struct {
	mu     sync.Mutex
	sent   []Outgoing
	typing []bool
	onSend func(int)
}

func (f *fakeSender) Send(ctx context.Context, out Outgoing) (Sent, error) {
	f.mu.Lock()
	f.sent = append(f.sent, out)
	n := len(f.sent)
	hook := f.onSend
	f.mu.Unlock()
	if hook != nil {
		hook(n)
	}
	return Sent{Success: true}, nil
}

func (f *fakeSender) Typing(ctx context.Context, userID int64, agentID, platform, chatID string, on bool) {
	f.mu.Lock()
	f.typing = append(f.typing, on)
	f.mu.Unlock()
}

type events struct {
	mu  sync.Mutex
	got []string
}

func (e *events) EmitToUser(userID int64, event string, payload any) {
	raw, _ := json.Marshal(payload)
	e.mu.Lock()
	e.got = append(e.got, event+" "+string(raw))
	e.mu.Unlock()
}

func groupMessage(content string) *messaging.Message {
	return &messaging.Message{AgentID: "a1", Platform: "telegram", ChatID: "-100", Sender: "7", SenderName: "Carl", Content: content, IsGroup: true,
		AccessPolicyAllowUntagged: true, Timestamp: "2026-01-01T00:00:00.000Z"}
}

func newPipeline(t *testing.T, inf *fakeInference, sender *fakeSender, ev *events) *Pipeline {
	p := &Pipeline{DB: testDB(t), Inference: inf, Sender: sender, Emitter: ev}
	p.States()
	t.Cleanup(func() { p.Shutdown(context.Background()) })
	return p
}

func TestGateHoldsSideChatterAndSpeaksWhenNeeded(t *testing.T) {
	inf := &fakeInference{answer: map[string]any{"decision": "speak", "needScore": 0.4, "confidence": 0.8, "reasonCodes": []any{"open_question"}, "urgency": "low"}}
	ev := &events{}
	p := newPipeline(t, inf, &fakeSender{}, ev)
	ctx := context.Background()

	// A judged speak below the room threshold stays silent and claims no turn.
	m := groupMessage("anyone know a good pizza place?")
	p.NoteInbound(1, "a1", m)
	res, err := p.HandleInbound(ctx, 1, "a1", m)
	if err != nil || res.Engage || !strings.Contains(strings.Join(res.Decision.ReasonCodes, ","), "below_need_threshold") {
		t.Fatalf("below threshold: %+v %v", res, err)
	}
	if p.States().Get(1, "a1", "telegram", "-100").TurnEpoch != 0 {
		t.Fatal("a silent decision claimed a turn")
	}
	if len(inf.requests) == 0 || inf.requests[0].MaxTokens != 220 || inf.requests[0].Purpose != "general" || !strings.Contains(inf.requests[0].Prompt, `"groupDefaultPosture":"hold_side_chatter"`) {
		t.Fatalf("judge request %+v", inf.requests)
	}

	inf.mu.Lock()
	inf.answer = map[string]any{"decision": "speak", "needScore": 0.9, "confidence": 0.8, "reasonCodes": []any{"open_question"}, "urgency": "medium"}
	inf.mu.Unlock()
	m = groupMessage("can someone check the weather for tomorrow?")
	p.NoteInbound(1, "a1", m)
	res, err = p.HandleInbound(ctx, 1, "a1", m)
	if err != nil || !res.Engage || res.Decision.TurnEpoch != 1 || m.BehaviorTurnEpoch != 1 {
		t.Fatalf("engage: %+v %v", res, err)
	}
	decisions := p.ListDecisions(1, "a1", "telegram").([]LoggedDecision)
	if len(decisions) != 2 || decisions[0].Decision != "speak" || decisions[1].Decision != "stay_silent" {
		t.Fatalf("decision log %+v", decisions)
	}
	if len(ev.got) != 2 || !strings.HasPrefix(ev.got[1], `behavior:decision {"platform":"telegram","chatId":"-100","agentId":"a1","isGroup":true,"decision":"speak"`) {
		t.Fatalf("events %q", ev.got)
	}
}

func TestGateRules(t *testing.T) {
	inf := &fakeInference{}
	p := newPipeline(t, inf, &fakeSender{}, &events{})
	ctx := context.Background()

	m := groupMessage("hello helper")
	res, _ := p.HandleInbound(ctx, 1, "a1", m)
	if !res.Engage || res.Decision.ReasonCodes[0] != "addressed_by_name" {
		t.Fatalf("named: %+v", res.Decision)
	}
	m = groupMessage("untagged")
	m.AccessPolicyAllowUntagged = false
	res, _ = p.HandleInbound(ctx, 1, "a1", m)
	if res.Engage || res.Decision.ReasonCodes[0] != "untagged_disabled_for_shared_space" {
		t.Fatalf("untagged: %+v", res.Decision)
	}
	direct := &messaging.Message{Platform: "telegram", ChatID: "dm_7", Content: "hi"}
	res, _ = p.HandleInbound(ctx, 1, "a1", direct)
	if !res.Engage || res.Decision.ReasonCodes[0] != "direct_chat" {
		t.Fatalf("direct: %+v", res.Decision)
	}
	if len(inf.requests) != 0 {
		t.Fatalf("rules asked the model: %+v", inf.requests)
	}
	// SystemOne on and unavailable: hold back, no model call.
	inf.ready = true
	res, _ = p.HandleInbound(ctx, 1, "a1", groupMessage("random chatter"))
	if res.Engage || res.Decision.FailureCode != "system_one_unavailable" || len(inf.requests) != 0 {
		t.Fatalf("system one outage: %+v %d", res.Decision, len(inf.requests))
	}
	// SystemOne answers with probabilities and a lower threshold.
	inf.decide = map[string]any{"speak": map[string]any{"noul": 0.8}, "for_someone_else": map[string]any{"noul": 0.35}, "urgency": map[string]any{"score": 1.4}}
	res, _ = p.HandleInbound(ctx, 1, "a1", groupMessage("what time is it in tokyo?"))
	if !res.Engage || res.Decision.TokenPath != "system_one_gate" || res.Decision.Urgency != "medium" || math.Abs(*res.Decision.NeedThreshold-0.5) > 1e-9 {
		t.Fatalf("system one: %+v", res.Decision)
	}
}

func TestDeliverReplyBubblesAndStaleTurns(t *testing.T) {
	sender := &fakeSender{}
	p := newPipeline(t, &fakeInference{}, sender, &events{})
	ctx := context.Background()
	if _, err := p.Store.Set(ctx, 1, "a1", json.RawMessage(`{"bubbleGapMs":0}`)); err != nil {
		t.Fatal(err)
	}
	m := groupMessage("helper, tell me")
	res, _ := p.HandleInbound(ctx, 1, "a1", m)
	out, err := p.DeliverReply(ctx, DeliverRequest{UserID: 1, AgentID: "a1", Message: m, Config: res.Config, Content: "One.\n\nTwo.\n\nThree.", RunID: "r1", TurnEpoch: res.Decision.TurnEpoch})
	if err != nil || !out.Delivered || len(sender.sent) != 3 || sender.sent[2].Kind != "final" || sender.sent[0].Kind != "partial" || sender.sent[1].IdempotencyKey != "r1:social:1" {
		t.Fatalf("bubbles: %+v %v %+v", out, err, sender.sent)
	}
	if sender.typing[len(sender.typing)-1] {
		t.Fatal("typing left on")
	}
	if p.States().Get(1, "a1", "telegram", "-100").LastSpokeAt == nil {
		t.Fatal("spoke not recorded")
	}

	// A newer speak turn mid-delivery stops the remaining bubbles.
	sender.sent = nil
	m2 := groupMessage("helper again")
	res, _ = p.HandleInbound(ctx, 1, "a1", m2)
	sender.onSend = func(n int) {
		if n == 1 {
			p.States().BumpTurnEpoch(1, "a1", "telegram", "-100")
		}
	}
	out, err = p.DeliverReply(ctx, DeliverRequest{UserID: 1, AgentID: "a1", Message: m2, Config: res.Config, Content: "A.\n\nB.\n\nC.", RunID: "r2", TurnEpoch: res.Decision.TurnEpoch})
	if err != nil || out.Delivered || !out.Suppressed || out.Reason != "stale_turn" || out.Delivery.DeliveredBubbles != 1 || len(sender.sent) != 1 {
		t.Fatalf("stale: %+v %v", out, err)
	}
	out, _ = p.DeliverReply(ctx, DeliverRequest{UserID: 1, AgentID: "a1", Message: m2, Config: res.Config, Content: "[NO RESPONSE]", TurnEpoch: 3})
	if !out.Suppressed || out.Reason != "no_response" {
		t.Fatalf("no response: %+v", out)
	}
}

func TestNormsRefreshInBackground(t *testing.T) {
	inf := &fakeInference{answer: map[string]any{"promptBlock": "Keep it short and playful."}}
	p := newPipeline(t, inf, &fakeSender{}, &events{})
	ctx := context.Background()
	if _, err := p.Store.Set(ctx, 1, "a1", json.RawMessage(`{"normsRefreshMessageGap":3,"modules":{"turn_taking":{"enabled":false}}}`)); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 5; i++ {
		if _, err := p.DB.W.Exec(`INSERT INTO messages (user_id, agent_id, role, content, platform, platform_chat_id, metadata, created_at) VALUES (1, 'a1', 'user', ?, 'telegram', '-100', '{"senderName":"Carl"}', ?)`,
			"line", time.Now().Add(time.Duration(i)*time.Second).UTC().Format(time.RFC3339)); err != nil {
			t.Fatal(err)
		}
	}
	for i := 0; i < 3; i++ {
		if _, err := p.HandleInbound(ctx, 1, "a1", groupMessage("chatter")); err != nil {
			t.Fatal(err)
		}
		deadline := time.Now().Add(2 * time.Second)
		for {
			p.mu.Lock()
			idle := len(p.background) == 0
			p.mu.Unlock()
			if idle || time.Now().After(deadline) {
				break
			}
			time.Sleep(5 * time.Millisecond)
		}
	}
	res, _ := p.HandleInbound(ctx, 1, "a1", groupMessage("chatter"))
	if len(res.PromptBlocks) != 1 || res.PromptBlocks[0] != "## Group norms\nKeep it short and playful." {
		t.Fatalf("prompt blocks %q", res.PromptBlocks)
	}
}
