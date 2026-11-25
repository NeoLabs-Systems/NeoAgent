package behavior

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// Outgoing is one message the pipeline sends.
type Outgoing struct {
	UserID                    int64
	AgentID, Platform, ChatID string
	Content, MediaPath, RunID string
	// Kind is "final" or "partial".
	Kind           string
	IdempotencyKey string
	Metadata       map[string]any
}

// Sent is what the platform did with a message.
type Sent struct {
	Success, Suppressed bool
	Reason, Error       string
	Result              any
}

// Sender reaches the chats.
type Sender interface {
	Send(ctx context.Context, out Outgoing) (Sent, error)
	Typing(ctx context.Context, userID int64, agentID, platform, chatID string, on bool)
}

// SplitIntoNaturalBubbles cuts a reply into the chat bubbles a person would
// send: the platform's paragraph chunks, at most maxBubbles of them.
func SplitIntoNaturalBubbles(platform, content string, maxBubbles int) []string {
	normalized := messaging.NormalizeOutgoingMessage(platform, content, false)
	if normalized == "" {
		return []string{}
	}
	if strings.ToUpper(normalized) == "[NO RESPONSE]" {
		return []string{normalized}
	}
	var limited []string
	for _, chunk := range messaging.SplitOutgoingMessage(platform, normalized) {
		bubble := strings.TrimSpace(chunk)
		if bubble == "" {
			continue
		}
		if len(limited) < maxBubbles {
			limited = append(limited, bubble)
		} else {
			limited[len(limited)-1] = strings.TrimSpace(limited[len(limited)-1] + " " + bubble)
		}
	}
	if len(limited) == 0 {
		return []string{normalized}
	}
	return limited
}

// Delivered is the delivery module's outcome.
type Delivered struct {
	Success          bool   `json:"success"`
	Suppressed       bool   `json:"suppressed,omitempty"`
	Reason           string `json:"reason,omitempty"`
	Error            string `json:"error,omitempty"`
	Bubbled          bool   `json:"bubbled,omitempty"`
	BubbleCount      int    `json:"bubbleCount,omitempty"`
	DeliveredBubbles int    `json:"deliveredBubbles,omitempty"`
	TurnEpoch        int64  `json:"turnEpoch,omitempty"`
	Result           any    `json:"result,omitempty"`
}

type deliverRequest struct {
	userID                    int64
	agentID, platform, chatID string
	content, runID, mediaPath string
	cfg                       *Effective
	turnEpoch                 int64
	beforeBubble              func(int) bool
}

func idempotencyKey(runID string, index int) string {
	if runID == "" {
		return ""
	}
	return fmt.Sprintf("%s:social:%d", runID, index)
}

func fromSent(s Sent) Delivered {
	return Delivered{Success: s.Success, Suppressed: s.Suppressed, Reason: s.Reason, Error: s.Error, Result: s.Result}
}

// deliverSocialReply sends a reply as one message or as natural bubbles with
// typing between them, stopping when a newer turn makes it stale.
func deliverSocialReply(ctx context.Context, sender Sender, r deliverRequest) (Delivered, error) {
	stale := Delivered{Suppressed: true, Reason: "stale_turn", TurnEpoch: r.turnEpoch}
	style := r.cfg.DeliveryStyle
	if style != "single" {
		style = "natural_bubbles"
	}
	single := func(content, mediaPath string) (Delivered, error) {
		if r.beforeBubble != nil && !r.beforeBubble(0) {
			return stale, nil
		}
		sent, err := sender.Send(ctx, Outgoing{UserID: r.userID, AgentID: r.agentID, Platform: r.platform, ChatID: r.chatID, Content: content,
			MediaPath: mediaPath, RunID: r.runID, Kind: "final", IdempotencyKey: idempotencyKey(r.runID, 0)})
		if err != nil {
			return Delivered{}, err
		}
		return fromSent(sent), nil
	}
	if style == "single" || r.mediaPath != "" {
		return single(r.content, r.mediaPath)
	}
	maxBubbles := r.cfg.MaxBubbles
	if maxBubbles <= 0 {
		maxBubbles = 4
	}
	bubbles := SplitIntoNaturalBubbles(r.platform, r.content, maxBubbles)
	if len(bubbles) <= 1 {
		content := r.content
		if len(bubbles) == 1 && bubbles[0] != "" {
			content = bubbles[0]
		}
		return single(content, "")
	}
	defer sender.Typing(context.WithoutCancel(ctx), r.userID, r.agentID, r.platform, r.chatID, false)
	gap := time.Duration(r.cfg.BubbleGapMs) * time.Millisecond
	var last Sent
	for i, bubble := range bubbles {
		if err := ctx.Err(); err != nil {
			return Delivered{}, err
		}
		if i > 0 && gap > 0 {
			select {
			case <-ctx.Done():
				return Delivered{}, ctx.Err()
			case <-time.After(gap):
			}
		}
		if r.beforeBubble != nil && !r.beforeBubble(i) {
			out := stale
			out.DeliveredBubbles = i
			return out, nil
		}
		sender.Typing(ctx, r.userID, r.agentID, r.platform, r.chatID, true)
		kind := "partial"
		if i == len(bubbles)-1 {
			kind = "final"
		}
		sent, err := sender.Send(ctx, Outgoing{UserID: r.userID, AgentID: r.agentID, Platform: r.platform, ChatID: r.chatID, Content: bubble, RunID: r.runID,
			Kind: kind, IdempotencyKey: idempotencyKey(r.runID, i), Metadata: map[string]any{"socialDelivery": true, "bubbleIndex": i, "bubbleCount": len(bubbles)}})
		if err != nil {
			return Delivered{}, err
		}
		if !sent.Success || sent.Suppressed {
			reason := firstText(sent.Error, sent.Reason, "Messaging platform rejected delivery.")
			return Delivered{Error: reason, Result: sent.Result, DeliveredBubbles: i}, nil
		}
		last = sent
	}
	return Delivered{Success: true, Bubbled: true, BubbleCount: len(bubbles), Result: last.Result}, nil
}
