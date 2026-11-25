package agent

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// deliveryChannel is where a run's messages go.
func deliveryChannel(triggerSource string) string {
	switch strings.ToLower(strings.TrimSpace(triggerSource)) {
	case "messaging":
		return "messaging"
	case "voice_live":
		return "voice_live"
	}
	return "web"
}

func (r *Run) recipient() string {
	if deliveryChannel(r.TriggerSource) == "voice_live" {
		for _, v := range []string{r.VoiceSessionID, fmtAny(r.SessionBinding["sessionId"]), r.MessagingChatID} {
			if v = strings.TrimSpace(v); v != "" {
				return v
			}
		}
		return ""
	}
	return r.MessagingChatID
}

func fmtAny(v any) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	return fmt.Sprint(v)
}

// progressMetadata is what a progress line needs to find its way.
func (r *Run) progressMetadata() map[string]any {
	m := map[string]any{}
	if deliveryChannel(r.TriggerSource) == "messaging" {
		m["platform"], m["chatId"] = nullString(r.MessagingPlatform), nullString(r.MessagingChatID)
	}
	for k, v := range r.SessionBinding {
		m[k] = v
	}
	return m
}

// allowsProgress: progress lines describe what the run's tools do, so on
// messaging they are for the owner's own chat only; a call reports on the line
// itself.
func (r *Run) allowsProgress() bool {
	switch deliveryChannel(r.TriggerSource) {
	case "voice_live":
		return false
	case "messaging":
		audience := r.Options.Audience
		if audience == "" {
			audience = "owner"
		}
		group := r.Options.Context.Social != nil && r.Options.Context.Social.IsGroup
		return audience == "owner" && r.Options.MemoryAudience != "shared" && !group
	}
	return true
}

func (e *Engine) commitRun(r *runledger.Run) runledger.CommitRun {
	return runledger.CommitRun{ID: r.ID, UserID: r.UserID, AgentID: r.AgentID}
}

// MarkVisibleReply records that a reply in the run's own chat reached the user;
// it says nothing about work to come, so the run stays in the foreground.
func (e *Engine) MarkVisibleReply(runID string) {
	if r, ok := e.RunInfo(runID); ok {
		r.mu.Lock()
		r.lastUserVisibleAt = isoNow()
		r.mu.Unlock()
	}
}

// MarkVisibleProgress records a progress update, which moves an owner's chat
// run to the background.
func (e *Engine) MarkVisibleProgress(runID string) {
	if r, ok := e.RunInfo(runID); ok {
		r.mu.Lock()
		r.lastUserVisibleAt = isoNow()
		r.mu.Unlock()
		e.moveToBackground(r)
	}
}

// MarkFinalDelivery records the run's final answer reaching the user.
func (e *Engine) MarkFinalDelivery(runID, content string) {
	r, ok := e.RunInfo(runID)
	if !ok {
		return
	}
	r.Delivery.Lock()
	r.Delivery.FinalDelivered = true
	r.Delivery.FinalContent = strings.TrimSpace(content)
	r.Delivery.Unlock()
	r.mu.Lock()
	r.lastUserVisibleAt = isoNow()
	r.mu.Unlock()
}

// PersistMetadata merges keys into a run's stored metadata.
func (e *Engine) PersistMetadata(runID string, patch map[string]any) {
	if err := e.ledger.SetMetadata(context.Background(), runID, patch); err != nil {
		e.log.Warn("Run metadata update failed", "run", runID, "error", err)
	}
}

// RecordEvent appends to a run's ledger.
func (e *Engine) RecordEvent(userID int64, runID, agentID, eventType string, payload map[string]any) {
	e.ledger.Record(runledger.Event{RunID: runID, UserID: userID, AgentID: agentID, Type: eventType, Payload: payload})
}

type finalOutcome struct {
	ok      bool
	reason  string
	content string
	err     string
}

// requestFinalDelivery commits the run's final answer: at most one per run, by
// compare-and-swap on the run row before anything is sent.
func (e *Engine) requestFinalDelivery(ctx context.Context, r *Run, content string, totalTokens int) finalOutcome {
	run, err := e.ledger.LoadRun(ctx, r.ID)
	if err != nil || run == nil {
		return finalOutcome{reason: "not_found"}
	}
	if run.FinalDeliveryID != "" {
		entries, _ := e.ledger.EntriesForRun(ctx, r.ID)
		reason := "delivery_failed"
		for _, entry := range entries {
			if entry.ID == run.FinalDeliveryID {
				switch entry.Status {
				case "delivered", "suppressed":
					reason = "already_committed"
				case "pending", "ambiguous":
					reason = "ambiguous"
				}
			}
		}
		return finalOutcome{reason: reason}
	}
	text := strings.TrimSpace(content)
	channel := deliveryChannel(r.TriggerSource)
	metadata := map[string]any{"platform": nullString(r.MessagingPlatform), "chatId": nullString(r.MessagingChatID), "totalTokens": totalTokens, "agentId": nullString(r.AgentID)}
	for k, v := range r.SessionBinding {
		metadata[k] = v
	}
	version := run.Version
	result, err := e.ledger.CommitDelivery(ctx, runledger.Commit{
		Run: e.commitRun(run), ScopeID: r.DeliveryScopeID, Channel: channel, Recipient: r.recipient(), Purpose: "final", Slot: "final",
		Content: text, Metadata: metadata, DedupeContent: true,
		BeforeSend: func(ctx context.Context, entry *runledger.Entry) (bool, string) {
			claim, err := e.ledger.ClaimFinalDelivery(ctx, r.ID, entry.ID, &version, r.WorkerID)
			if err != nil {
				return false, "cas_failed"
			}
			return claim.OK, claim.Reason
		},
		Transmit: func(ctx context.Context, entry *runledger.Entry) (runledger.Transmission, error) {
			return e.transmit(ctx, entry, r)
		},
	})
	if err != nil {
		return finalOutcome{reason: "delivery_failed", err: err.Error()}
	}
	if result.OK && result.Duplicate && result.Reason != "not_transmitted" {
		if current, _ := e.ledger.LoadRun(ctx, r.ID); current != nil && current.FinalDeliveryID == "" {
			// The answer already reached this chat under another slot. The run still
			// has to commit and close; web clients still need their one run:complete.
			_, _ = e.ledger.ClaimFinalDelivery(ctx, r.ID, result.OutboxID, &version, r.WorkerID)
			if channel == "web" {
				e.Emit(r.UserID, "run:complete", map[string]any{"runId": r.ID, "content": text, "outboxId": result.OutboxID})
			}
		}
	}
	if result.OK {
		_, _ = e.ledger.Transition(ctx, runledger.TransitionRequest{RunID: r.ID, ToState: runledger.StateCompleted, Reason: "final_delivery_confirmed",
			WorkerID: r.WorkerID, Publish: true, Patch: runledger.Patch{FinalResponse: &text, TotalTokens: &totalTokens}})
		e.MarkFinalDelivery(r.ID, text)
		return finalOutcome{ok: true, content: text}
	}
	return finalOutcome{reason: result.Reason, err: result.Error}
}

// RequestProgressDelivery sends a progress or interim line through the run's
// channel, once per slot.
func (e *Engine) RequestProgressDelivery(ctx context.Context, runID, scopeID, channel, recipient, kind, slot, content string, metadata map[string]any) (runledger.Committed, error) {
	run, err := e.ledger.LoadRun(ctx, runID)
	if err != nil || run == nil {
		return runledger.Committed{Reason: "not_found"}, err
	}
	text := strings.TrimSpace(content)
	if text == "" {
		return runledger.Committed{Reason: "empty_content"}, nil
	}
	purpose := "interim"
	if kind == runledger.KindProgress {
		purpose = "progress"
	}
	if slot == "" {
		slot = runledger.SlotForContent(text)
	}
	r, _ := e.RunInfo(runID)
	result, err := e.ledger.CommitDelivery(ctx, runledger.Commit{
		Run: e.commitRun(run), ScopeID: scopeID, Channel: channel, Recipient: recipient, Purpose: purpose, Slot: slot, Content: text, Metadata: metadata,
		DedupeContent: true,
		Transmit: func(ctx context.Context, entry *runledger.Entry) (runledger.Transmission, error) {
			return e.transmit(ctx, entry, r)
		},
	})
	if err == nil && result.OK && !result.Duplicate {
		e.MarkVisibleProgress(runID)
	}
	return result, err
}

// transmit hands a message to the platform behind its channel.
func (e *Engine) transmit(ctx context.Context, entry *runledger.Entry, r *Run) (runledger.Transmission, error) {
	content := entry.Content()
	run, _ := e.ledger.LoadRun(ctx, entry.RunID)
	if run == nil {
		return runledger.Transmission{Error: "run_not_found"}, nil
	}
	if entry.Channel == "voice_live" && e.deps.Voice != nil {
		// A call that has ended hands the result to the chat below.
		if presented, detached := e.deps.Voice.PresentDelivery(entry); presented && !detached {
			return runledger.Transmission{OK: true, PlatformMessageID: "voice:" + entry.ID}, nil
		}
	}
	if entry.Channel == "messaging" {
		if e.deps.Messaging == nil {
			return runledger.Transmission{Error: "messaging_manager_unavailable"}, nil
		}
		meta := entry.Metadata()
		platform := fmtAny(meta["platform"])
		if platform == "" {
			platform = entry.Channel
		}
		chatID := entry.Recipient
		if chatID == "" {
			chatID = fmtAny(meta["chatId"])
		}
		// A final answer it declines to send was already visible or was silenced.
		if entry.MessageKind == runledger.KindFinal {
			sent, reason, err := e.deliverMessagingFinal(ctx, r, run, platform, chatID, content)
			if err != nil {
				return runledger.Transmission{}, err
			}
			if !sent {
				if reason == "" {
					reason = "already_visible"
				}
				return runledger.Transmission{OK: true, Skipped: true, Reason: reason}, nil
			}
			return runledger.Transmission{OK: true, PlatformMessageID: "messaging:" + entry.ID}, nil
		}
		result, err := e.deps.Messaging.Send(runCtx(ctx, r), SendRequest{UserID: run.UserID, AgentID: run.AgentID, Platform: platform, ChatID: chatID,
			Content: content, RunID: run.ID, PersistConversation: true, Metadata: ai.InterimMetadata("progress", false), Kind: "interim"})
		if err != nil {
			return runledger.Transmission{}, err
		}
		if result.Success && !result.Suppressed {
			return runledger.Transmission{OK: true, PlatformMessageID: result.PlatformMessageID}, nil
		}
		if result.Ambiguous {
			return runledger.Transmission{Ambiguous: true, Error: orText(result.Error, "ambiguous delivery")}, nil
		}
		return runledger.Transmission{Error: orText(result.Error, "send failed")}, nil
	}
	// Web: emit the content; the outbox row is the delivery record. A progress
	// line is a real message, so it goes out as an assistant interim.
	if entry.MessageKind == runledger.KindFinal {
		e.Emit(run.UserID, "run:complete", map[string]any{"runId": run.ID, "content": content, "messageKind": entry.MessageKind, "outboxId": entry.ID})
	} else {
		e.Emit(run.UserID, "run:assistant_interim", map[string]any{"runId": run.ID, "content": content, "kind": entry.MessageKind, "platform": "web", "outboxId": entry.ID})
	}
	return runledger.Transmission{OK: true, PlatformMessageID: "local:" + entry.ID}, nil
}

func runCtx(ctx context.Context, r *Run) context.Context {
	if r != nil {
		return r.Context()
	}
	return ctx
}

func orText(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

// shouldSendMessagingFinal: a reply the model sent in this chat that is still
// its last word, a question it is waiting on, or chosen silence replaces the
// final answer.
func (e *Engine) shouldSendMessagingFinal(r *Run, content, platform string) bool {
	if e.deps.Messaging.Normalize(platform, content) == "" {
		return false
	}
	if r == nil {
		return true
	}
	d := r.Delivery
	d.Lock()
	defer d.Unlock()
	return d.AwaitingReply == nil && !d.NoResponse && !d.LastWordSent && !d.FinalDelivered
}

// deliverMessagingFinal sends a messaging run's final answer in the chunks the
// platform takes, with safe retries.
func (e *Engine) deliverMessagingFinal(ctx context.Context, r *Run, run *runledger.Run, platform, chatID, content string) (bool, string, error) {
	if r == nil {
		return false, "", nil
	}
	cleaned := e.deps.Messaging.Normalize(platform, content)
	if !e.shouldSendMessagingFinal(r, cleaned, platform) {
		return false, "", nil
	}
	if e.deps.Behavior != nil && r.MessagingBehavior != nil {
		out, err := e.deps.Behavior.Deliver(r.Context(), run.UserID, run.AgentID, r.MessagingBehavior, cleaned, run.ID)
		if err != nil {
			return false, "", err
		}
		if !out.Skipped {
			if !out.Delivered {
				if !out.Suppressed {
					// Some bubbles of the reply may already be in the chat.
					return false, "", &runledger.DeliveryError{Message: orText(out.Reason, "Behavior delivery was not confirmed."), Ambiguous: out.DeliveredBubbles > 0}
				}
				r.Delivery.Lock()
				r.Delivery.NoResponse = true
				r.Delivery.Unlock()
				return false, out.Reason, nil
			}
			r.Delivery.MarkSent(out.Content)
			e.MarkFinalDelivery(run.ID, out.Content)
			return true, "", nil
		}
	}
	chunks := e.deps.Messaging.Split(platform, cleaned)
	e.log.Info("Messaging final delivery", "run", shortID(run.ID), "chunks", len(chunks))
	signal := r.Context()
	policy := llm.RetryPolicyFromEnv(e.deps.Getenv)
	policy.IsRetryable = runledger.IsSafeDeliveryRetry
	var delivered []string
	for i, chunk := range chunks {
		if i > 0 {
			e.deps.Messaging.SendTyping(signal, run.UserID, run.AgentID, platform, chatID)
			delay := time.Duration(max(1000, min(len(chunk)*30, 4000))) * time.Millisecond
			select {
			case <-signal.Done():
				return len(delivered) > 0, "", &runledger.DeliveryError{Message: "Final messaging delivery failed: aborted", Ambiguous: len(delivered) > 0}
			case <-time.After(delay):
			}
		}
		key := fmt.Sprintf("%s:final:%d", run.ID, i)
		_, err := llm.Retry(signal, policy, func(int) (SendResult, error) {
			res, err := e.deps.Messaging.Send(signal, SendRequest{UserID: run.UserID, AgentID: run.AgentID, Platform: platform, ChatID: chatID, Content: chunk,
				RunID: run.ID, IdempotencyKey: key, Kind: "final"})
			if err != nil {
				return res, err
			}
			if !res.Success || res.Suppressed {
				return res, &runledger.DeliveryError{Message: "Final messaging delivery failed: " + orText(res.Error, "the platform did not confirm delivery"),
					Safe: !res.Ambiguous && !res.Success, Ambiguous: res.Ambiguous}
			}
			return res, nil
		})
		if err != nil {
			var de *runledger.DeliveryError
			if len(delivered) > 0 && !errors.As(err, &de) {
				err = &runledger.DeliveryError{Message: err.Error(), Ambiguous: true}
			}
			return false, "", err
		}
		delivered = append(delivered, chunk)
		r.Delivery.MarkSent(chunk)
	}
	last := cleaned
	if len(delivered) > 0 {
		last = delivered[len(delivered)-1]
	}
	e.MarkFinalDelivery(run.ID, last)
	return true, "", nil
}

func shortID(id string) string {
	if len(id) > 8 {
		return id[:8]
	}
	return id
}

// InterimRequest is a send_interim_update.
type InterimRequest struct {
	RunID          string
	UserID         int64
	AgentID        string
	TriggerSource  string
	ConversationID string
	Platform       string
	ChatID         string
	Content        string
	Kind           string
	ExpectsReply   bool
	DeferFollowUp  bool
}

// InterimResult is how an interim update went.
type InterimResult struct {
	Sent          bool   `json:"sent"`
	Skipped       bool   `json:"skipped,omitempty"`
	Duplicate     bool   `json:"duplicate,omitempty"`
	Reason        string `json:"reason,omitempty"`
	Kind          string `json:"kind,omitempty"`
	ExpectsReply  bool   `json:"expectsReply"`
	DeferFollowUp bool   `json:"deferFollowUp"`
	Content       string `json:"content,omitempty"`
	Terminal      bool   `json:"terminal"`
}

// PublishInterim sends an update while the run works on.
func (e *Engine) PublishInterim(ctx context.Context, req InterimRequest) (InterimResult, error) {
	r, ok := e.RunInfo(req.RunID)
	if !ok || r.Aborted() {
		return InterimResult{Skipped: true, Reason: "Run is no longer active."}, nil
	}
	source := req.TriggerSource
	if source == "" {
		source = "web"
	}
	kind := ai.NormalizeInterimKind(req.Kind)
	platform := ""
	if source == "messaging" {
		platform = req.Platform
	}
	content := req.Content
	if e.deps.Messaging != nil {
		content = e.deps.Messaging.NormalizeInterim(platform, content)
	} else {
		content = strings.TrimSpace(content)
	}
	if content == "" || strings.ToUpper(content) == "[NO RESPONSE]" {
		return InterimResult{Skipped: true, Reason: "Interim content must be non-empty."}, nil
	}
	signaturePlatform := "web"
	if source == "messaging" {
		signaturePlatform = platform
	}
	slot := runledger.SlotForContent(ai.InterimSignature(content, kind, req.ExpectsReply, signaturePlatform))
	metadata := ai.InterimMetadata(kind, req.ExpectsReply)
	if req.DeferFollowUp {
		metadata = metadata.Set("defer_follow_up", true)
	}
	created := isoNow()
	if source == "voice_live" {
		if r.VoiceSessionID == "" {
			return InterimResult{Skipped: true, Reason: "Voice session context is not available."}, nil
		}
		meta := map[string]any{"kind": kind, "expectsReply": req.ExpectsReply}
		for k, v := range r.SessionBinding {
			meta[k] = v
		}
		result, err := e.RequestProgressDelivery(ctx, req.RunID, r.DeliveryScopeID, "voice_live", r.VoiceSessionID, runledger.KindInterim, slot, content, meta)
		if err != nil {
			return InterimResult{}, err
		}
		if result.Duplicate {
			return InterimResult{Skipped: true, Duplicate: true}, nil
		}
		if !result.OK {
			return InterimResult{Skipped: true, Reason: result.Reason}, nil
		}
	} else {
		if source == "messaging" && (req.Platform == "" || req.ChatID == "" || e.deps.Messaging == nil) {
			return InterimResult{Skipped: true, Reason: "Messaging context is not available."}, nil
		}
		run, err := e.ledger.LoadRun(ctx, req.RunID)
		if err != nil || run == nil {
			return InterimResult{Skipped: true, Reason: "Run is no longer active."}, err
		}
		channel, recipient := "web", ""
		if source == "messaging" {
			channel, recipient = "messaging", req.ChatID
		}
		result, err := e.ledger.CommitDelivery(ctx, runledger.Commit{
			Run: e.commitRun(run), ScopeID: r.DeliveryScopeID, Channel: channel, Recipient: recipient, Purpose: "interim", Slot: slot, Content: content,
			Metadata: map[string]any{"kind": kind, "expectsReply": req.ExpectsReply},
			Transmit: func(ctx context.Context, _ *runledger.Entry) (runledger.Transmission, error) {
				if source == "messaging" {
					res, err := e.deps.Messaging.Send(r.Context(), SendRequest{UserID: req.UserID, AgentID: req.AgentID, Platform: req.Platform, ChatID: req.ChatID,
						Content: content, RunID: req.RunID, PersistConversation: true, Metadata: metadata, Kind: "interim"})
					if err != nil {
						return runledger.Transmission{}, err
					}
					if !res.Success || res.Suppressed {
						return runledger.Transmission{}, &runledger.DeliveryError{Message: "Interim messaging delivery failed: " + orText(res.Error, "the platform did not confirm delivery"),
							Ambiguous: res.Ambiguous}
					}
					return runledger.Transmission{OK: true}, nil
				}
				meta := dyn.Stringify(metadata)
				e.execDB(ctx, `INSERT INTO conversation_history (user_id, agent_id, agent_run_id, conversation_id, role, content, metadata) VALUES (?, ?, ?, ?, 'assistant', ?, ?)`,
					req.UserID, nullString(req.AgentID), req.RunID, nullString(req.ConversationID), content, meta)
				if req.ConversationID != "" {
					e.execDB(ctx, `INSERT INTO conversation_messages (conversation_id, run_id, agent_id, role, content, metadata_json) VALUES (?, ?, ?, 'assistant', ?, ?)`,
						req.ConversationID, req.RunID, nullString(req.AgentID), content, meta)
				}
				return runledger.Transmission{OK: true}, nil
			},
		})
		if err != nil {
			return InterimResult{}, err
		}
		if result.Duplicate {
			return InterimResult{Skipped: true, Duplicate: true}, nil
		}
		if !result.OK {
			if result.Thrown != nil {
				return InterimResult{}, result.Thrown
			}
			return InterimResult{Skipped: true, Reason: result.Reason}, nil
		}
	}
	e.MarkVisibleProgress(req.RunID)
	if source != "voice_live" {
		e.Emit(req.UserID, "run:assistant_interim", map[string]any{"runId": req.RunID, "conversationId": nullString(req.ConversationID), "content": content,
			"kind": kind, "expectsReply": req.ExpectsReply, "deferFollowUp": req.DeferFollowUp, "triggerSource": source, "platform": signaturePlatform})
	}
	if req.ExpectsReply {
		r.Delivery.Lock()
		r.Delivery.AwaitingReply = &AwaitingReply{Kind: kind, Content: content, CreatedAt: created}
		r.Delivery.Unlock()
	}
	var terminal any
	if req.ExpectsReply {
		terminal = map[string]any{"kind": kind, "content": content, "createdAt": created}
	}
	e.PersistMetadata(req.RunID, map[string]any{
		"latestInterim":   map[string]any{"kind": kind, "expectsReply": req.ExpectsReply, "deferFollowUp": req.DeferFollowUp, "content": content, "createdAt": created},
		"terminalInterim": terminal,
	})
	return InterimResult{Sent: true, Kind: kind, ExpectsReply: req.ExpectsReply, DeferFollowUp: req.DeferFollowUp, Content: content, Terminal: req.ExpectsReply}, nil
}
