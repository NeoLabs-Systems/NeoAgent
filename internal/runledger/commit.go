package runledger

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net"
	"strings"
	"syscall"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// KindForPurpose is the outbox kind a delivery purpose is stored as.
func KindForPurpose(purpose string) string {
	switch purpose {
	case "final":
		return KindFinal
	case "progress":
		return KindProgress
	}
	return KindInterim
}

// Transmission is how handing a message to its platform went.
type Transmission struct {
	OK bool
	// Ambiguous: the message may have reached the platform.
	Ambiguous bool
	Error     string
	// Skipped: the transmit step decided nothing needed sending (already
	// visible, silenced).
	Skipped           bool
	Reason            string
	PlatformMessageID string
	Result            any
}

// RetryInfo is what a delivery error can tell about itself.
type RetryInfo interface {
	// SafeToRetry: the platform provably did not take the message.
	SafeToRetry() bool
}

// AmbiguousDelivery marks an error after which the message may have landed.
type AmbiguousDelivery interface {
	DeliveryAmbiguous() bool
}

// DeliveryError is a send the platform did not confirm.
type DeliveryError struct {
	Message   string
	Safe      bool
	Ambiguous bool
}

func (e *DeliveryError) Error() string           { return e.Message }
func (e *DeliveryError) SafeToRetry() bool       { return e.Safe && !e.Ambiguous }
func (e *DeliveryError) DeliveryAmbiguous() bool { return e.Ambiguous }
func (e *DeliveryError) Code() string            { return "MESSAGING_DELIVERY_FAILED" }

// IsSafeDeliveryRetry says whether a failed send provably happened before the
// platform could accept the message. A rate-limit rejection and DNS or connect
// failures qualify; timeouts, resets and generic 5xx do not, because the
// message may already have been accepted.
func IsSafeDeliveryRetry(err error) bool {
	if err == nil {
		return false
	}
	var amb AmbiguousDelivery
	if errors.As(err, &amb) && amb.DeliveryAmbiguous() {
		return false
	}
	var info RetryInfo
	if errors.As(err, &info) {
		return info.SafeToRetry()
	}
	if e := llm.AsError(err); e != nil && e.Status == 429 {
		return true
	}
	var dns *net.DNSError
	if errors.As(err, &dns) {
		return true
	}
	for _, code := range []error{syscall.ECONNREFUSED, syscall.ENETUNREACH, syscall.EHOSTUNREACH} {
		if errors.Is(err, code) {
			return true
		}
	}
	return false
}

// CommitRun is the run a delivery belongs to.
type CommitRun struct {
	ID      string
	UserID  int64
	AgentID string
}

// Commit is one message to show a user.
type Commit struct {
	Run       CommitRun
	ScopeID   string
	Channel   string
	Recipient string
	Purpose   string
	Slot      string
	Content   string
	Metadata  map[string]any
	// DedupeContent suppresses text that already reached this recipient.
	DedupeContent     bool
	AllowEmptyContent bool
	Transmit          func(ctx context.Context, entry *Entry) (Transmission, error)
	// BeforeSend may refuse the send after the slot is reserved.
	BeforeSend func(ctx context.Context, entry *Entry) (ok bool, reason string)
}

// Committed is the outcome of a commit; Reason names why it did not send.
type Committed struct {
	OK, Duplicate     bool
	Reason, Status    string
	OutboxID          string
	Content           string
	PlatformMessageID string
	Error             string
	Result            any
	Thrown            error
}

func recipientDigest(recipient string) any {
	if recipient == "" {
		return nil
	}
	sum := sha256.Sum256([]byte(recipient))
	return hex.EncodeToString(sum[:])[:16]
}

func (l *Ledger) recordDelivery(run CommitRun, eventType string, entry *Entry, extra map[string]any) {
	payload := map[string]any{"outbox_id": nil, "channel": nil, "purpose": nil, "slot": nil, "recipient_digest": nil}
	if entry != nil {
		payload["outbox_id"], payload["channel"], payload["purpose"], payload["slot"] = entry.ID, entry.Channel, orNil(entry.Purpose), orNil(entry.Slot)
		payload["recipient_digest"] = recipientDigest(entry.Recipient)
	}
	for k, v := range extra {
		payload[k] = v
	}
	l.Record(Event{RunID: run.ID, UserID: run.UserID, AgentID: run.AgentID, Type: eventType, Payload: payload})
}

// CommitDelivery is the single commit point for anything a run shows a user.
// Every path (final answer, send_message, interim update, progress heartbeat,
// task result) reserves its slot here before transmitting, so "the same answer
// twice" is a state the outbox cannot enter. A send that may have reached the
// platform is never retried.
func (l *Ledger) CommitDelivery(ctx context.Context, c Commit) (Committed, error) {
	started := l.now()
	text := strings.TrimSpace(c.Content)
	if ai.IsRawToolCall(text) {
		return Committed{Reason: "raw_tool_call"}, nil
	}
	if text == "" && !c.AllowEmptyContent {
		return Committed{Reason: "empty_content"}, nil
	}
	scope := c.ScopeID
	if scope == "" {
		scope = c.Run.ID
	}
	entry, fresh, err := l.Reserve(ctx, Reservation{
		RunID: c.Run.ID, ScopeID: scope, Channel: c.Channel, Recipient: c.Recipient,
		MessageKind: KindForPurpose(c.Purpose), Purpose: c.Purpose, Slot: c.Slot, Content: text, Metadata: c.Metadata,
	})
	if err != nil {
		return Committed{}, err
	}
	if !fresh {
		l.recordDelivery(c.Run, EventDeliverySuppressed, entry, map[string]any{"reason": "slot_" + entry.Status})
		reason := "duplicate_slot"
		if entry.Status == "ambiguous" || entry.Status == "pending" {
			reason = "ambiguous"
		}
		return Committed{OK: entry.Status == "delivered" || entry.Status == "suppressed", Duplicate: true, Reason: reason, Status: entry.Status, OutboxID: entry.ID, Content: text}, nil
	}
	l.recordDelivery(c.Run, EventDeliveryReserved, entry, nil)

	if c.DedupeContent {
		previous, err := l.FindDeliveredContent(ctx, entry.ScopeID, c.Recipient, text, entry.ID)
		if err != nil {
			return Committed{}, err
		}
		if previous != nil && previous.Status == "ambiguous" {
			_ = l.MarkFailed(ctx, entry.ID, true)
			l.recordDelivery(c.Run, EventDeliveryFailed, entry, map[string]any{"ambiguous": true})
			return Committed{Reason: "ambiguous", OutboxID: entry.ID}, nil
		}
		if previous != nil {
			_ = l.MarkSuppressed(ctx, entry.ID)
			l.recordDelivery(c.Run, EventDeliverySuppressed, entry, map[string]any{"reason": "same_content"})
			return Committed{OK: true, Duplicate: true, Reason: "same_content", OutboxID: entry.ID, Content: text}, nil
		}
	}

	if c.BeforeSend != nil {
		if ok, reason := c.BeforeSend(ctx, entry); !ok {
			_ = l.MarkFailed(ctx, entry.ID, false)
			return Committed{Reason: reason, OutboxID: entry.ID}, nil
		}
	}

	sent, terr := c.Transmit(ctx, entry)
	if terr != nil {
		sent = Transmission{Ambiguous: !IsSafeDeliveryRetry(terr), Error: terr.Error()}
	}
	elapsed := l.now().Sub(started).Milliseconds()
	if sent.OK && sent.Skipped {
		_ = l.MarkSuppressed(ctx, entry.ID)
		reason := sent.Reason
		if reason == "" {
			reason = "not_transmitted"
		}
		l.recordDelivery(c.Run, EventDeliverySuppressed, entry, map[string]any{"reason": reason})
		return Committed{OK: true, Duplicate: true, Reason: reason, OutboxID: entry.ID, Content: text}, nil
	}
	if sent.OK {
		_ = l.MarkDelivered(ctx, entry.ID, sent.PlatformMessageID)
		_ = l.RecordAttempt(ctx, entry.ID, "delivered", sent.PlatformMessageID, "")
		l.recordDelivery(c.Run, EventDeliverySent, entry, map[string]any{"duration_ms": elapsed})
		return Committed{OK: true, OutboxID: entry.ID, Content: text, PlatformMessageID: sent.PlatformMessageID, Result: sent.Result}, nil
	}
	_ = l.MarkFailed(ctx, entry.ID, sent.Ambiguous)
	status := "failed"
	if sent.Ambiguous {
		status = "ambiguous"
	}
	_ = l.RecordAttempt(ctx, entry.ID, status, "", sent.Error)
	l.recordDelivery(c.Run, EventDeliveryFailed, entry, map[string]any{"duration_ms": elapsed, "ambiguous": sent.Ambiguous})
	reason := "delivery_failed"
	if sent.Ambiguous {
		reason = "ambiguous"
	}
	return Committed{Reason: reason, OutboxID: entry.ID, Error: sent.Error, Thrown: terr}, nil
}

var _ = time.Second
