package messaging

import (
	"context"
	"log/slog"
	"strings"
	"sync"
	"time"
)

// The per-chat inbound queue. One run per chat at a time: a message that
// arrives while a run is going waits, and consecutive messages from the same
// sender (or in the same group) merge into a single run. Port of
// inbound_queue.js.

// Outcome is what handling one message produced.
type Outcome struct {
	RunID  string
	Result any
	Err    error
}

// Completion is an Outcome once its waiters were released; Cancelled is set when
// the queue was cancelled while it waited.
type Completion struct {
	RunID     string
	Result    any
	Err       error
	Cancelled bool
}

func completionOf(o *Outcome, cancelled bool) Completion {
	if o == nil {
		return Completion{Cancelled: cancelled}
	}
	return Completion{RunID: o.RunID, Result: o.Result, Err: o.Err, Cancelled: cancelled}
}

// QueueResult is what submitting a message returned. A message that joined a
// running chat has Queued set and Completion fires when its run ends; otherwise
// this call ran the queue and Outcome is the first message's.
type QueueResult struct {
	Queued         bool
	Completion     <-chan Completion
	ProcessedCount int
	FailedCount    int
	Cancelled      bool
	Outcome        Completion
}

// Wait returns the outcome of the message submitted, waiting for its run when it
// was queued behind another.
func (r QueueResult) Wait(ctx context.Context) (Completion, error) {
	if !r.Queued {
		return r.Outcome, nil
	}
	select {
	case c := <-r.Completion:
		return c, nil
	case <-ctx.Done():
		return Completion{}, ctx.Err()
	}
}

type queueItem struct {
	msg     *Message
	waiters []chan Completion
}

type chatQueue struct {
	running         bool
	collecting      bool
	cancelRequested bool
	pending         []*queueItem
	active          *queueItem
}

// Queues holds the chat queues of one server.
type Queues struct {
	mu     sync.Mutex
	queues map[string]*chatQueue
	log    *slog.Logger
}

// NewQueues returns an empty set of chat queues.
func NewQueues(log *slog.Logger) *Queues {
	return &Queues{queues: map[string]*chatQueue{}, log: log}
}

// QueueKey identifies a chat's queue.
func QueueKey(userID int64, msg *Message) string {
	agent := msg.AgentID
	if agent == "" {
		agent = "main"
	}
	return strings.Join([]string{formatInt(userID), agent, msg.Platform, msg.ChatID}, ":")
}

// AgentQueueSummary is what an agent has running and waiting across its chats.
type AgentQueueSummary struct {
	Running bool
	Pending int
	Keys    []string
}

// SummarizeAgent reports the queues of one agent.
func (q *Queues) SummarizeAgent(userID int64, agentID string) AgentQueueSummary {
	if agentID == "" {
		agentID = "main"
	}
	user := formatInt(userID)
	prefix := user + ":" + agentID + ":"
	q.mu.Lock()
	defer q.mu.Unlock()
	var out AgentQueueSummary
	for key, queue := range q.queues {
		if key != user && key != user+":"+agentID && !strings.HasPrefix(key, prefix) {
			continue
		}
		out.Keys = append(out.Keys, key)
		out.Running = out.Running || queue.running
		out.Pending += len(queue.pending)
	}
	return out
}

// CancelAll cancels every queue: running chats stop after their current run and
// waiting messages are released as cancelled.
func (q *Queues) CancelAll() {
	q.mu.Lock()
	defer q.mu.Unlock()
	for _, queue := range q.queues {
		queue.cancelRequested = true
		cancelPending(queue)
	}
}

func cancelPending(queue *chatQueue) {
	for _, item := range queue.pending {
		settleWaiters(item, Completion{Cancelled: true})
	}
	queue.pending = nil
}

func settleWaiters(item *queueItem, c Completion) {
	if item == nil {
		return
	}
	for _, w := range item.waiters {
		w <- c
	}
	item.waiters = nil
}

func batchEntryOf(m *Message) BatchEntry {
	return BatchEntry{
		Sender:         nstr(m.Sender),
		SenderName:     nstr(firstNonEmpty(string(m.SenderDisplayName), string(m.SenderName), string(m.SenderUsername))),
		Content:        m.Content,
		MessageID:      m.MessageID,
		Timestamp:      nstr(m.Timestamp),
		WasMentioned:   m.WasMentioned,
		RepliedToAgent: m.RepliedToAgent,
	}
}

// mergeMessage folds msg into the queued target: the content becomes the batch
// (prefixed with who spoke in a group), and the newest message's identifiers win.
func mergeMessage(target, msg *Message) {
	batch := target.MessageBatch
	if batch == nil {
		batch = []BatchEntry{batchEntryOf(target)}
	}
	batch = append(append([]BatchEntry{}, batch...), batchEntryOf(msg))
	target.MessageBatch = batch
	lines := make([]string, len(batch))
	for i, e := range batch {
		lines[i] = e.Content
		if target.IsGroup {
			lines[i] = "[" + firstNonEmpty(string(e.SenderName), string(e.Sender), "participant") + "]: " + e.Content
		}
	}
	target.Content = strings.Join(lines, "\n")
	target.MessageID = nstr(firstNonEmpty(string(msg.MessageID), string(target.MessageID)))
	target.Timestamp = firstNonEmpty(msg.Timestamp, target.Timestamp)
	target.WasMentioned = target.WasMentioned || msg.WasMentioned
	target.RepliedToAgent = target.RepliedToAgent || msg.RepliedToAgent
	if msg.ReplyTo != nil && msg.ReplyTo.Content != "" {
		target.ReplyTo = msg.ReplyTo
		target.ReplyToMessageID = msg.ReplyToMessageID
	}
	target.BehaviorTurnEpoch = max(target.BehaviorTurnEpoch, msg.BehaviorTurnEpoch)
	ids := append(append(append([]string{}, target.InboundJobIDs...), target.InboundJobID), msg.InboundJobIDs...)
	target.InboundJobIDs = uniqueIDs(append(ids, msg.InboundJobID))
}

func (q *Queues) queuedResult(queue *chatQueue, msg *Message) QueueResult {
	waiter := make(chan Completion, 1)
	last := queue.active
	if !queue.collecting || last == nil {
		last = nil
		if n := len(queue.pending); n > 0 {
			last = queue.pending[n-1]
		}
	}
	if last != nil && last.msg.Platform == msg.Platform && last.msg.ChatID == msg.ChatID &&
		(last.msg.IsGroup || last.msg.Sender == msg.Sender) {
		mergeMessage(last.msg, msg)
		last.waiters = append(last.waiters, waiter)
	} else {
		copied := *msg
		queue.pending = append(queue.pending, &queueItem{msg: &copied, waiters: []chan Completion{waiter}})
	}
	return QueueResult{Queued: true, Completion: waiter}
}

// ProcessRequest is one message to run through its chat's queue.
type ProcessRequest struct {
	UserID  int64
	Message *Message
	Execute func(ctx context.Context, msg *Message) Outcome
	// OnError reports a failed run (not a cancelled one). Nil logs it.
	OnError func(ctx context.Context, failed Outcome, msg *Message)
	// BatchWindow is how long a group message waits for more to merge into it.
	BatchWindow time.Duration
}

// Process submits a message. When its chat is idle the call runs the chat's
// queue until it is empty and returns the first message's outcome; when a run is
// going the message joins it and the result's Completion fires when it is done.
func (q *Queues) Process(ctx context.Context, req ProcessRequest) (result QueueResult) {
	key := QueueKey(req.UserID, req.Message)
	q.mu.Lock()
	queue := q.queues[key]
	if queue == nil {
		queue = &chatQueue{}
		q.queues[key] = queue
	}
	if queue.cancelRequested && !queue.running {
		cancelPending(queue)
		queue.cancelRequested = false
	}
	if queue.running {
		result := q.queuedResult(queue, req.Message)
		q.mu.Unlock()
		return result
	}
	queue.running = true
	q.mu.Unlock()

	var first *Completion
	current := &queueItem{msg: req.Message}
	defer func() {
		q.mu.Lock()
		queue.running, queue.collecting, queue.active = false, false, nil
		cancelPending(queue)
		queue.cancelRequested = false
		if q.queues[key] == queue {
			delete(q.queues, key)
		}
		q.mu.Unlock()
		if first == nil {
			c := completionOf(nil, result.Cancelled)
			first = &c
		}
		result.Outcome = *first
	}()

	for current != nil {
		q.mu.Lock()
		queue.active = current
		if delay := batchDelay(current.msg, req.BatchWindow); delay > 0 {
			queue.collecting = true
			q.mu.Unlock()
			sleep(ctx, delay)
			q.mu.Lock()
			queue.collecting = false
		}
		q.mu.Unlock()

		outcome := req.Execute(ctx, current.msg)

		q.mu.Lock()
		result.ProcessedCount++
		cancelled := queue.cancelRequested
		c := completionOf(&outcome, cancelled)
		if first == nil {
			first = &c
		}
		settleWaiters(current, c)
		failed := outcome.Err != nil && !cancelled
		if failed {
			result.FailedCount++
		}
		if cancelled {
			cancelPending(queue)
			result.Cancelled = true
			q.mu.Unlock()
			if failed {
				q.reportError(ctx, req, outcome, current.msg)
			}
			break
		}
		var next *queueItem
		if len(queue.pending) > 0 {
			next, queue.pending = queue.pending[0], queue.pending[1:]
		}
		q.mu.Unlock()
		if failed {
			q.reportError(ctx, req, outcome, current.msg)
		}
		current = next
	}
	return result
}

func batchDelay(msg *Message, window time.Duration) time.Duration {
	if !msg.IsGroup {
		return 0
	}
	return max(0, min(5*time.Second, window))
}

func sleep(ctx context.Context, d time.Duration) {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
	case <-ctx.Done():
	}
}

func (q *Queues) reportError(ctx context.Context, req ProcessRequest, failed Outcome, msg *Message) {
	if req.OnError == nil {
		q.log.Error("agent run failed", "platform", msg.Platform, "user", req.UserID, "error", failed.Err)
		return
	}
	req.OnError(ctx, failed, msg)
}
