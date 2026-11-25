package handlers

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

type fakeDelivery struct {
	target                           [2]string
	sent                             []string
	staged                           *StagedMessage
	silent, lastWord, finalDelivered bool
}

func (d *fakeDelivery) NotifyTarget() (string, string, bool) {
	return d.target[0], d.target[1], d.target[0] != ""
}
func (d *fakeDelivery) SentCount() int          { return len(d.sent) }
func (d *fakeDelivery) Staged() bool            { return d.staged != nil }
func (d *fakeDelivery) Stage(m StagedMessage)   { d.staged = &m }
func (d *fakeDelivery) ChooseSilence()          { d.silent = true }
func (d *fakeDelivery) MarkLastWordSent()       { d.lastWord = true }
func (d *fakeDelivery) MarkFinalDelivered()     { d.finalDelivered = true }
func (d *fakeDelivery) MarkSent(content string) { d.sent = append(d.sent, content) }

type fakeMessaging struct {
	Messaging
	sends []string
}

func (m *fakeMessaging) FormatOutgoing(_, content string) string { return content }
func (m *fakeMessaging) Send(_ context.Context, _ int64, _, platform, to, content, _, _ string, _ bool) (dyn.Map, error) {
	m.sends = append(m.sends, platform+":"+to+":"+content)
	return dyn.Map{"success": true, "result": dyn.Map{"messageId": "m1"}}, nil
}

type fakeEngine struct {
	Engine
	run       *Run
	visible   int
	commits   []DeliveryCommit
	duplicate bool
}

func (e *fakeEngine) Run(string) *Run            { return e.run }
func (e *fakeEngine) MarkRunVisibleReply(string) { e.visible++ }
func (e *fakeEngine) CommitDelivery(ctx context.Context, _ string, c DeliveryCommit) (DeliveryOutcome, error) {
	e.commits = append(e.commits, c)
	if e.duplicate {
		return DeliveryOutcome{OK: true, Duplicate: true, Reason: "same_content"}, nil
	}
	r := c.Transmit(ctx)
	return DeliveryOutcome{OK: r.OK, Error: r.Error}, nil
}

func TestSendMessageInTheRunsChatIsALastWordReply(t *testing.T) {
	d := &fakeDelivery{}
	run := &Run{UserID: 1, AgentID: "a", RunID: "r", TriggerSource: "messaging", Source: "telegram", ChatID: "100", Delivery: d, Persisted: true}
	e := &fakeEngine{run: run}
	m := &fakeMessaging{}
	got, err := New(Deps{Engine: e, Messaging: m}).ExecuteFor(context.Background(), run, "send_message", dyn.Map{"platform": "telegram", "to": "100", "content": "hi"}, "")
	if err != nil {
		t.Fatal(err)
	}
	same(t, "result", got, json.RawMessage(`{"success":true,"result":{"messageId":"m1"},"originDelivery":true,"redirectedFromDirect":false,"platform":"telegram","to":"100"}`))
	if len(e.commits) != 1 || e.commits[0].Recipient != "100" || e.commits[0].Purpose != "reply" || !e.commits[0].DedupeContent {
		t.Fatalf("commit %+v", e.commits)
	}
	if !d.lastWord || e.visible != 1 || d.finalDelivered || len(d.sent) != 1 {
		t.Fatalf("delivery %+v visible %d", d, e.visible)
	}
}

func TestSendMessageDuplicateIsNotSentAgain(t *testing.T) {
	d := &fakeDelivery{}
	run := &Run{UserID: 1, RunID: "r", TriggerSource: "web", Delivery: d, Persisted: true}
	e := &fakeEngine{run: run, duplicate: true}
	m := &fakeMessaging{}
	got, _ := New(Deps{Engine: e, Messaging: m}).ExecuteFor(context.Background(), run, "send_message", dyn.Map{"platform": "slack", "to": "C1", "content": "x"}, "")
	same(t, "dup", got, json.RawMessage(`{"success":true,"sent":false,"duplicate":true,"note":"This exact message already reached this recipient in this run, so it was not sent again.","originDelivery":true,"redirectedFromDirect":false,"platform":"slack","to":"C1"}`))
	if len(m.sends) != 0 || len(d.sent) != 0 || !d.finalDelivered {
		t.Fatalf("sends %v delivery %+v", m.sends, d)
	}
}

func TestTaskMessagesAreValidatedAndStaged(t *testing.T) {
	ctx := context.Background()
	d := &fakeDelivery{target: [2]string{"telegram", "42"}}
	run := &Run{UserID: 1, RunID: "r", TaskID: "7", TriggerSource: "schedule", StageProactiveMessages: true, Delivery: d}
	b := New(Deps{Messaging: &fakeMessaging{}})
	got, _ := b.ExecuteFor(ctx, run, "send_message", dyn.Map{"to": "x", "content": "done"}, "")
	same(t, "purpose", got, json.RawMessage(`{"error":"Background send_message requires purpose=final_result, blocker, or no_response."}`))
	got, _ = b.ExecuteFor(ctx, run, "send_message", dyn.Map{"to": "x", "content": "[NO RESPONSE]", "purpose": "no_response"}, "")
	same(t, "silence", got, json.RawMessage(`{"sent":false,"suppressed":true,"skipped":true,"reason":"no_response"}`))
	if !d.silent {
		t.Fatal("silence not chosen")
	}
	got, _ = b.ExecuteFor(ctx, run, "send_message", dyn.Map{"platform": "whatsapp", "to": "x", "content": " done ", "purpose": "final_result"}, "")
	same(t, "staged", got, json.RawMessage(`{"success":true,"staged":true,"purpose":"final_result","platform":"telegram","to":"42","content":" done "}`))
	if d.staged == nil || d.staged.Content != "done" || d.staged.To != "42" {
		t.Fatalf("staged %+v", d.staged)
	}
	got, _ = b.ExecuteFor(ctx, run, "send_message", dyn.Map{"to": "x", "content": "again", "purpose": "final_result"}, "")
	same(t, "second", got, json.RawMessage(`{"sent":false,"skipped":true,"reason":"A proactive message was already sent in this task run; duplicate send_message was suppressed."}`))
}
