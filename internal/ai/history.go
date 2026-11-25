package ai

import (
	"encoding/json"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Keys and limits of the web chat summary.
const (
	WebSummaryKey       = "web_chat_summary"
	WebSummaryCountKey  = "web_chat_summary_count"
	SummaryTriggerCount = 12
	MaxSummaryChars     = 6000
)

// ClampSummary trims a conversation summary to its maximum length.
func ClampSummary(text string) string {
	str := textx.Trim(text)
	if str == "" {
		return ""
	}
	if textx.Len(str) <= MaxSummaryChars {
		return str
	}
	return textx.Head(str, MaxSummaryChars) + "\n...[summary trimmed]"
}

// SummaryCarrier is the system message that carries a summary into a prompt,
// or nil when there is none.
func SummaryCarrier(summary string) *llm.Message {
	if summary == "" {
		return nil
	}
	return &llm.Message{Role: "system", Content: "[Conversation summary]\n" + ClampSummary(summary)}
}

// StoredUserContent is what history keeps of a live turn from an external
// message. The live turn carries the routing envelope: sender identity,
// platform formatting guide, reply and progress instructions. Those are restated
// on every new turn, so replaying them from history only pays for the same
// static text once per stored message. What history has to keep is who spoke, on
// which platform, and that the text is untrusted external content.
func StoredUserContent(userMessage, rawUserMessage, platform, speaker string, isGroup bool) string {
	raw := textx.Trim(rawUserMessage)
	if raw == "" {
		return userMessage
	}
	kind := "message"
	if isGroup {
		kind = "group message"
	}
	origin := []string{}
	for _, part := range []string{textx.Trim(platform), kind} {
		if part != "" {
			origin = append(origin, part)
		}
	}
	if s := textx.Trim(speaker); s != "" {
		origin = append(origin, "from "+s)
	}
	return "[" + strings.Join(origin, " ") + "]\n" + FenceUntrusted("external_message", raw)
}

// SanitizeConversationMessages drops what a provider would reject: tool results
// without their call, and tool calls whose results are incomplete.
func SanitizeConversationMessages(messages []llm.Message) []llm.Message {
	var sanitized []llm.Message
	var pending *struct {
		messages   []llm.Message
		pendingIDs map[string]bool
	}
	flush := func() {
		if pending != nil && len(pending.pendingIDs) == 0 {
			sanitized = append(sanitized, pending.messages...)
		}
		pending = nil
	}
	for _, msg := range messages {
		if msg.Role == "" {
			continue
		}
		if msg.Role == "assistant" && len(msg.ToolCalls) > 0 {
			ids := map[string]bool{}
			for _, call := range msg.ToolCalls {
				if call.ID != "" {
					ids[call.ID] = true
				}
			}
			pending = nil
			if len(ids) == 0 {
				sanitized = append(sanitized, msg)
				continue
			}
			pending = &struct {
				messages   []llm.Message
				pendingIDs map[string]bool
			}{messages: []llm.Message{msg}, pendingIDs: ids}
			continue
		}
		if msg.Role == "tool" {
			if pending != nil && msg.ToolCallID != "" && pending.pendingIDs[msg.ToolCallID] {
				pending.messages = append(pending.messages, msg)
				delete(pending.pendingIDs, msg.ToolCallID)
				if len(pending.pendingIDs) == 0 {
					flush()
				}
			}
			continue
		}
		pending = nil
		sanitized = append(sanitized, msg)
	}
	flush()
	return sanitized
}

// StoredMessageRow is a message as the conversation tables keep it.
type StoredMessageRow struct {
	Role       string
	Content    string
	ToolCalls  string
	ToolCallID string
	Name       string
}

// NormalizeHistoryRows turns stored rows into transcript messages.
func NormalizeHistoryRows(rows []StoredMessageRow) []llm.Message {
	out := make([]llm.Message, len(rows))
	for i, row := range rows {
		msg := llm.Message{Role: row.Role, Content: row.Content, ToolCallID: row.ToolCallID, Name: row.Name}
		if row.ToolCalls != "" {
			var calls []llm.ToolCall
			if err := json.Unmarshal([]byte(row.ToolCalls), &calls); err == nil {
				msg.ToolCalls = calls
			}
		}
		out[i] = msg
	}
	return out
}

// SerializeHistoryForSummary renders messages for the conversation summariser.
func SerializeHistoryForSummary(messages []llm.Message) string {
	parts := make([]string, len(messages))
	for i, msg := range messages {
		content := dyn.Str(msg.Content)
		switch {
		case msg.Role == "tool":
			name := msg.Name
			if name == "" {
				name = "tool"
			}
			parts[i] = "tool:" + name + " " + textx.Head(content, 320)
		case msg.Role == "assistant" && len(msg.ToolCalls) > 0:
			var names []string
			for _, call := range msg.ToolCalls {
				if call.Function.Name != "" {
					names = append(names, call.Function.Name)
				}
			}
			parts[i] = "assistant(tool_calls:" + strings.Join(names, ", ") + ") " + textx.Head(content, 320)
		default:
			parts[i] = msg.Role + ": " + textx.Head(content, 400)
		}
	}
	return strings.Join(parts, "\n")
}

// SummaryRefreshMessages is the request that folds new messages into the
// conversation summary.
func SummaryRefreshMessages(existingSummary string, messages []llm.Message, label string) []llm.Message {
	if label == "" {
		label = "conversation"
	}
	existing := "Existing summary: none"
	if existingSummary != "" {
		existing = "Existing summary:\n" + ClampSummary(existingSummary)
	}
	return []llm.Message{
		{Role: "system", Content: "Compress conversation context. Preserve user goals, constraints, preferences, decisions, promised follow-ups, recurring schedules, important facts, tool outcomes, unresolved issues, and any user-stated communication preferences. Keep concrete details (names, dates, times, statuses) and avoid vague wording. Output plain text only."},
		{Role: "user", Content: strings.Join([]string{
			existing,
			"New " + label + " messages:\n" + SerializeHistoryForSummary(messages),
			"Write an updated summary in under 420 words. Include a short section for \"Open commitments\" when applicable.",
		}, "\n\n")},
	}
}
