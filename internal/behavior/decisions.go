package behavior

import (
	"encoding/json"
	"fmt"
	"math"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

var urgencyLevels = []string{"low", "medium", "high"}

// SystemOneScores are SystemOne's probabilities, its whole explanation.
type SystemOneScores struct {
	Speak          float64 `json:"speak"`
	ForSomeoneElse float64 `json:"forSomeoneElse"`
}

// Decision is the turn-taking gate's verdict on one message.
type Decision struct {
	Decision        string           `json:"decision"`
	NeedScore       float64          `json:"needScore"`
	Confidence      float64          `json:"confidence"`
	ReasonCodes     []string         `json:"reasonCodes"`
	Urgency         string           `json:"urgency"`
	TokenPath       string           `json:"tokenPath"`
	Model           *string          `json:"model,omitempty"`
	Usage           *float64         `json:"usage,omitempty"`
	FailureCode     string           `json:"failureCode,omitempty"`
	SystemOneScores *SystemOneScores `json:"systemOneScores,omitempty"`
	NeedThreshold   *float64         `json:"needThreshold,omitempty"`
	LatencyMs       int64            `json:"latencyMs"`
	TurnEpoch       int64            `json:"turnEpoch"`
	// normalized decisions always name their model, even as null.
	normalized bool
}

// MarshalJSON writes the decision in the Node server's key order.
func (d Decision) MarshalJSON() ([]byte, error) {
	out := dyn.Ordered{{Key: "decision", Value: d.Decision}, {Key: "needScore", Value: d.NeedScore}, {Key: "confidence", Value: d.Confidence},
		{Key: "reasonCodes", Value: nonNil(d.ReasonCodes)}, {Key: "urgency", Value: d.Urgency}, {Key: "tokenPath", Value: d.TokenPath}}
	if d.normalized || d.Model != nil {
		out = append(out, dyn.KV{Key: "model", Value: d.Model})
	}
	if d.Usage != nil {
		out = append(out, dyn.KV{Key: "usage", Value: *d.Usage})
	}
	if d.FailureCode != "" {
		out = append(out, dyn.KV{Key: "failureCode", Value: d.FailureCode})
	}
	if d.SystemOneScores != nil {
		out = append(out, dyn.KV{Key: "systemOneScores", Value: d.SystemOneScores})
	}
	if d.NeedThreshold != nil {
		out = append(out, dyn.KV{Key: "needThreshold", Value: *d.NeedThreshold})
	}
	out = append(out, dyn.KV{Key: "latencyMs", Value: d.LatencyMs}, dyn.KV{Key: "turnEpoch", Value: d.TurnEpoch})
	return json.Marshal(out)
}

// Speaks reports whether the gate let the agent speak.
func (d *Decision) Speaks() bool { return d != nil && d.Decision == "speak" }

// ruleDecision is a turn settled by a rule, with no model involved.
func ruleDecision(decision, reasonCode string, confidence float64) Decision {
	speak := decision == "speak"
	d := Decision{Decision: decision, Confidence: confidence, ReasonCodes: []string{reasonCode}, Urgency: "low", TokenPath: "gate_skip"}
	if speak {
		d.NeedScore, d.Urgency = 1, "medium"
	}
	return d
}

// rawDecision is what a judge answered, before normalizing.
type rawDecision struct {
	Decision    any
	NeedScore   any
	Confidence  any
	ReasonCodes any
	Urgency     any
	Model       string
	Usage       *float64
}

type decisionFallback struct {
	Decision    string
	NeedScore   float64
	Confidence  float64
	ReasonCodes []string
	Urgency     string
	TokenPath   string
	Model       string
	Usage       *float64
}

func score(v any, fallback float64) float64 {
	n, ok := jsNumber(v, v != nil)
	if !ok || math.IsNaN(n) || math.IsInf(n, 0) {
		n = fallback
	}
	return math.Max(0, math.Min(1, n))
}

func normalizeDecision(raw rawDecision, fb decisionFallback) Decision {
	decision := strings.ToLower(strings.TrimSpace(jsTruthyString(raw.Decision)))
	if decision == "" {
		decision = strings.ToLower(strings.TrimSpace(fb.Decision))
	}
	if decision == "" {
		decision = "stay_silent"
	}
	if decision != "speak" {
		decision = "stay_silent"
	}
	d := Decision{Decision: decision, NeedScore: score(raw.NeedScore, fb.NeedScore), Confidence: score(raw.Confidence, fb.Confidence), normalized: true}
	if list, ok := raw.ReasonCodes.([]any); ok {
		d.ReasonCodes = []string{}
		for _, item := range list {
			s := ""
			if item != nil && item != false && item != "" && item != float64(0) {
				s = strings.TrimSpace(dyn.String(item))
			}
			if s != "" && len(d.ReasonCodes) < 8 {
				d.ReasonCodes = append(d.ReasonCodes, s)
			}
		}
	} else if list, ok := raw.ReasonCodes.([]string); ok {
		d.ReasonCodes = []string{}
		for _, s := range list {
			if s = strings.TrimSpace(s); s != "" && len(d.ReasonCodes) < 8 {
				d.ReasonCodes = append(d.ReasonCodes, s)
			}
		}
	} else {
		d.ReasonCodes = append([]string{}, fb.ReasonCodes...)
	}
	d.Urgency = fb.Urgency
	if d.Urgency == "" {
		d.Urgency = "low"
	}
	if u := jsTruthyString(raw.Urgency); u == "low" || u == "medium" || u == "high" {
		d.Urgency = u
	}
	d.TokenPath = fb.TokenPath
	if d.TokenPath == "" {
		d.TokenPath = "gate_only"
	}
	model := raw.Model
	if model == "" {
		model = fb.Model
	}
	if model != "" {
		d.Model = &model
	}
	if raw.Usage != nil {
		d.Usage = raw.Usage
	} else if fb.Usage != nil {
		d.Usage = fb.Usage
	}
	return d
}

// holdBackDecision: the gate holds back when no judge could answer.
func holdBackDecision(failureCode string) Decision {
	d := normalizeDecision(rawDecision{Decision: "stay_silent", NeedScore: 0.0, Confidence: 0.7, ReasonCodes: []string{"prefer_hold_back", failureCode}, Urgency: "low"},
		decisionFallback{TokenPath: "gate_fallback"})
	d.FailureCode = failureCode
	return d
}

// --- Rules ------------------------------------------------------------------

// bypassDecision: direct chats and switched-off gates need no reading of the room.
func bypassDecision(m *messaging.Message, cfg *Effective) *Decision {
	if !m.IsGroup {
		d := ruleDecision("speak", "direct_chat", 1)
		return &d
	}
	if !cfg.ModuleEnabled("turn_taking") || !cfg.Enabled {
		d := ruleDecision("speak", "turn_taking_disabled", 1)
		return &d
	}
	return nil
}

// addressDecision: turns settled by how the message reached the agent and the
// room's participation mode; nil when the room has to be judged.
func addressDecision(m *messaging.Message, cfg *Effective, a Addressing) *Decision {
	var d Decision
	switch {
	case a.StructurallyAddressed:
		code := "addressed"
		if m.RepliedToAgent {
			code = "reply_to_agent"
		}
		d = ruleDecision("speak", code, 1)
	case cfg.ParticipationMode == "always":
		d = ruleDecision("speak", "participation_always", 1)
	case cfg.ParticipationMode == "mention_only":
		d = ruleDecision("stay_silent", "mention_only", 1)
	case a.AddressedByName:
		d = ruleDecision("speak", "addressed_by_name", 0.9)
	default:
		return nil
	}
	return &d
}

// --- Decision log -----------------------------------------------------------

const (
	maxDecisionsPerPlatform = 30
	maxPreviewChars         = 160
)

// LoggedDecision is one entry of the per-platform decision log.
type LoggedDecision struct {
	At              string           `json:"at"`
	ChatID          string           `json:"chatId"`
	ChatName        *string          `json:"chatName"`
	ServerName      *string          `json:"serverName"`
	SenderName      *string          `json:"senderName"`
	Preview         string           `json:"preview"`
	WasMentioned    bool             `json:"wasMentioned"`
	RepliedToAgent  bool             `json:"repliedToAgent"`
	Decision        string           `json:"decision"`
	ReasonCodes     []string         `json:"reasonCodes"`
	NeedScore       float64          `json:"needScore"`
	NeedThreshold   *float64         `json:"needThreshold"`
	SystemOneScores *SystemOneScores `json:"systemOneScores"`
	Confidence      float64          `json:"confidence"`
	TokenPath       *string          `json:"tokenPath"`
	Model           *string          `json:"model"`
	LatencyMs       int64            `json:"latencyMs"`
}

type decisionLog struct {
	mu      sync.Mutex
	entries map[string][]LoggedDecision
}

var whitespace = regexp.MustCompile(`\s+`)

func preview(content string, limit int) string {
	text := strings.TrimSpace(whitespace.ReplaceAllString(content, " "))
	if utf16Len(text) > limit {
		return utf16Slice(text, limit-1) + "…"
	}
	return text
}

func optional(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func logKey(userID int64, agentID, platform string) string {
	if agentID == "" {
		agentID = "main"
	}
	return fmt.Sprintf("%d::%s::%s", userID, agentID, platform)
}

func (l *decisionLog) record(userID int64, agentID string, m *messaging.Message, d Decision, now time.Time) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.entries == nil {
		l.entries = map[string][]LoggedDecision{}
	}
	key := logKey(userID, agentID, m.Platform)
	chatName := firstText(string(m.GroupName), string(m.ChannelName), string(m.RoomName))
	entry := LoggedDecision{At: isoTime(now), ChatID: m.ChatID, ChatName: optional(chatName), ServerName: optional(string(m.GuildName)),
		SenderName: optional(string(m.SenderName)), Preview: preview(m.Content, maxPreviewChars), WasMentioned: m.WasMentioned, RepliedToAgent: m.RepliedToAgent,
		Decision: d.Decision, ReasonCodes: append([]string{}, d.ReasonCodes...), NeedScore: d.NeedScore, NeedThreshold: d.NeedThreshold,
		SystemOneScores: d.SystemOneScores, Confidence: d.Confidence, TokenPath: optional(d.TokenPath), Model: d.Model, LatencyMs: d.LatencyMs}
	entries := append([]LoggedDecision{entry}, l.entries[key]...)
	if len(entries) > maxDecisionsPerPlatform {
		entries = entries[:maxDecisionsPerPlatform]
	}
	l.entries[key] = entries
}

func (l *decisionLog) list(userID int64, agentID, platform string) []LoggedDecision {
	l.mu.Lock()
	defer l.mu.Unlock()
	return append([]LoggedDecision{}, l.entries[logKey(userID, agentID, platform)]...)
}

func firstText(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func utf16Len(s string) int {
	n := 0
	for _, r := range s {
		if r > 0xFFFF {
			n += 2
		} else {
			n++
		}
	}
	return n
}

func utf16Slice(s string, units int) string {
	n := 0
	for i, r := range s {
		size := 1
		if r > 0xFFFF {
			size = 2
		}
		if n+size > units {
			return s[:i]
		}
		n += size
	}
	return s
}
