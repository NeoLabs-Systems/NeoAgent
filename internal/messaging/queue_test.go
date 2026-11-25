package messaging

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"reflect"
	"sync"
	"testing"
	"time"
)

func queueMessage(t *testing.T, m map[string]any) *Message {
	t.Helper()
	raw, _ := json.Marshal(m)
	var msg Message
	if err := json.Unmarshal(raw, &msg); err != nil {
		t.Fatal(err)
	}
	var extra struct {
		BehaviorTurnEpoch int64 `json:"behaviorTurnEpoch"`
	}
	_ = json.Unmarshal(raw, &extra)
	msg.BehaviorTurnEpoch = extra.BehaviorTurnEpoch
	return &msg
}

func discardLog() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

func TestQueueMergingMatchesNode(t *testing.T) {
	for _, scenario := range loadVectors(t).Queue {
		t.Run(scenario.Name, func(t *testing.T) {
			queues := NewQueues(discardLog())
			var mu sync.Mutex
			var executed []*Message
			release := make(chan struct{})
			firstRunning := make(chan struct{})
			execute := func(_ context.Context, msg *Message) Outcome {
				mu.Lock()
				executed = append(executed, msg)
				n := len(executed)
				mu.Unlock()
				if n == 1 {
					close(firstRunning)
					<-release
				}
				return Outcome{RunID: "run" + formatInt(int64(n))}
			}
			ctx := context.Background()
			done := make(chan QueueResult, 1)
			go func() {
				done <- queues.Process(ctx, ProcessRequest{UserID: 1, Message: queueMessage(t, scenario.Steps[0]), Execute: execute})
			}()
			<-firstRunning
			var queued []QueueResult
			for _, step := range scenario.Steps[1:] {
				queued = append(queued, queues.Process(ctx, ProcessRequest{UserID: 1, Message: queueMessage(t, step), Execute: execute}))
			}
			close(release)
			first := <-done
			for _, q := range queued {
				if _, err := q.Wait(ctx); err != nil {
					t.Fatal(err)
				}
			}
			if first.Outcome.RunID != "run1" {
				t.Errorf("first outcome %+v", first.Outcome)
			}
			if len(executed) != len(scenario.Executed) {
				t.Fatalf("ran %d messages, Node ran %d", len(executed), len(scenario.Executed))
			}
			for i, want := range scenario.Executed {
				assertMergedLike(t, i, executed[i], want)
			}
		})
	}
}

func assertMergedLike(t *testing.T, i int, got *Message, want map[string]any) {
	t.Helper()
	str := func(key string) string { s, _ := want[key].(string); return s }
	boolean := func(key string) bool { b, _ := want[key].(bool); return b }
	if got.Content != str("content") || string(got.MessageID) != str("messageId") || got.Timestamp != str("timestamp") ||
		got.WasMentioned != boolean("wasMentioned") || got.RepliedToAgent != boolean("repliedToAgent") {
		t.Errorf("run %d: got content=%q id=%q ts=%q mentioned=%v replied=%v; Node %v", i, got.Content, got.MessageID, got.Timestamp, got.WasMentioned, got.RepliedToAgent, want)
	}
	epoch, _ := want["behaviorTurnEpoch"].(float64)
	if got.BehaviorTurnEpoch != int64(epoch) {
		t.Errorf("run %d: epoch %d, Node %v", i, got.BehaviorTurnEpoch, epoch)
	}
	var wantIDs []string
	ids, _ := want["inboundJobIds"].([]any)
	for _, id := range ids {
		wantIDs = append(wantIDs, id.(string))
	}
	if !reflect.DeepEqual(got.InboundJobIDs, wantIDs) {
		t.Errorf("run %d: job ids %v, Node %v", i, got.InboundJobIDs, wantIDs)
	}
	if reply, ok := want["replyTo"].(map[string]any); ok {
		if got.ReplyTo == nil || got.ReplyTo.Content != reply["content"] || string(got.ReplyToMessageID) != str("replyToMessageId") {
			t.Errorf("run %d: reply %+v", i, got.ReplyTo)
		}
	}
	batch, _ := json.Marshal(got.MessageBatch)
	wantBatch, _ := json.Marshal(want["messageBatch"])
	if got.MessageBatch == nil {
		batch = []byte("null")
	}
	var g, w any
	_ = json.Unmarshal(batch, &g)
	_ = json.Unmarshal(wantBatch, &w)
	if !reflect.DeepEqual(g, w) {
		t.Errorf("run %d: batch %s, Node %s", i, batch, wantBatch)
	}
}

func TestQueueKeysMatchNode(t *testing.T) {
	for _, c := range loadVectors(t).QueueKeys {
		raw, _ := json.Marshal(c.Msg)
		var in struct{ AgentID, Platform, ChatID string }
		_ = json.Unmarshal(raw, &in)
		// A numeric chatId is read as its text, as join() does.
		if n, ok := c.Msg["chatId"].(float64); ok {
			in.ChatID = jsNumber(n)
		}
		msg := &Message{AgentID: in.AgentID, Platform: in.Platform, ChatID: in.ChatID}
		if got := QueueKey(c.UserID, msg); got != c.Key {
			t.Errorf("got %q want %q", got, c.Key)
		}
	}
}

func TestQueueCancelReleasesWaitersAndStopsTheChat(t *testing.T) {
	queues := NewQueues(discardLog())
	ctx := context.Background()
	running := make(chan struct{})
	release := make(chan struct{})
	var once sync.Once
	execute := func(_ context.Context, msg *Message) Outcome {
		if msg.ChatID == "c" {
			once.Do(func() { close(running) })
			<-release
		}
		return Outcome{RunID: "r"}
	}
	done := make(chan QueueResult, 1)
	go func() {
		done <- queues.Process(ctx, ProcessRequest{UserID: 1, Message: &Message{Platform: "p", ChatID: "c", Sender: "s"}, Execute: execute})
	}()
	<-running
	queued := queues.Process(ctx, ProcessRequest{UserID: 1, Message: &Message{Platform: "p", ChatID: "c2", Sender: "s"}, Execute: execute})
	if queued.Queued {
		t.Fatal("a different chat must not queue behind a running one")
	}
	summary := queues.SummarizeAgent(1, "main")
	if !summary.Running || len(summary.Keys) != 1 {
		t.Fatalf("summary %+v", summary)
	}
	waiting := queues.Process(ctx, ProcessRequest{UserID: 1, Message: &Message{Platform: "p", ChatID: "c", Sender: "other"}, Execute: execute})
	if !waiting.Queued {
		t.Fatal("message for a busy chat must queue")
	}
	queues.CancelAll()
	got, err := waiting.Wait(ctx)
	if err != nil || !got.Cancelled {
		t.Fatalf("waiter got %+v, %v", got, err)
	}
	close(release)
	first := <-done
	if !first.Cancelled || first.Outcome.RunID != "r" || !first.Outcome.Cancelled {
		t.Fatalf("first %+v", first)
	}
	if queues.SummarizeAgent(1, "main").Running {
		t.Fatal("queue must be released")
	}
}

func TestQueueReportsFailuresAndBatchesGroupMessages(t *testing.T) {
	queues := NewQueues(discardLog())
	ctx := context.Background()
	var reported []Outcome
	var runs int
	execute := func(_ context.Context, msg *Message) Outcome {
		runs++
		if msg.Content == "boom" {
			return Outcome{RunID: "bad", Err: io.ErrUnexpectedEOF}
		}
		return Outcome{RunID: "ok"}
	}
	onError := func(_ context.Context, o Outcome, _ *Message) { reported = append(reported, o) }
	res := queues.Process(ctx, ProcessRequest{UserID: 1, Message: &Message{Platform: "p", ChatID: "c", Content: "boom"}, Execute: execute, OnError: onError})
	if res.FailedCount != 1 || len(reported) != 1 || reported[0].RunID != "bad" || runs != 1 {
		t.Fatalf("result %+v reported %+v", res, reported)
	}

	// A group message waits for the batch window, and a second one arriving in
	// that window rides along instead of starting a run of its own.
	group := &Message{Platform: "p", ChatID: "g", Sender: "a", IsGroup: true, Content: "one"}
	runs = 0
	go func() {
		time.Sleep(20 * time.Millisecond)
		queues.Process(ctx, ProcessRequest{UserID: 1, Message: &Message{Platform: "p", ChatID: "g", Sender: "b", IsGroup: true, Content: "two"}, Execute: execute})
	}()
	queues.Process(ctx, ProcessRequest{UserID: 1, Message: group, Execute: execute, BatchWindow: 200 * time.Millisecond})
	if runs != 1 || group.Content != "[a]: one\n[b]: two" {
		t.Fatalf("runs=%d content=%q", runs, group.Content)
	}
}
