package ai

import (
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// SummaryPrefix opens the system message that carries a conversation summary.
const SummaryPrefix = "[Previous conversation summary]"

// contentText is a message content as text: a string, the text of each part, or JSON.
func contentText(value any) string {
	switch v := value.(type) {
	case string:
		return v
	case []any:
		parts := make([]string, len(v))
		for i, part := range v {
			if s, ok := part.(string); ok {
				parts[i] = s
				continue
			}
			parts[i] = dyn.Str(or(dyn.Get(part, "text"), dyn.Get(part, "content"), dyn.Stringify(or(part, dyn.Map{}))))
		}
		return strings.Join(parts, "\n")
	case nil:
		return ""
	}
	return dyn.Stringify(value)
}

func estimateValueTokens(value any) int {
	if value == nil {
		return 0
	}
	text, ok := value.(string)
	if !ok {
		text = dyn.Stringify(value)
	}
	return (len(text) + 3) / 4
}

// EstimateMessageTokens is the cheap length-based estimate of a message.
func EstimateMessageTokens(m llm.Message) int {
	total := 4 + estimateValueTokens(m.Role)
	if m.Name != "" {
		total += estimateValueTokens(m.Name)
	}
	total += estimateValueTokens(m.Content)
	if len(m.ToolCalls) > 0 {
		total += estimateValueTokens(m.ToolCalls)
	}
	if m.ToolCallID != "" {
		total += estimateValueTokens(m.ToolCallID)
	}
	return total
}

// EstimateTokenCount estimates a whole request: its messages and tool schemas.
func EstimateTokenCount(messages []llm.Message, tools []llm.Tool) int {
	total := 0
	for _, m := range messages {
		total += EstimateMessageTokens(m)
	}
	// An empty tool list still serialises as "[]", and the Node estimate counts it.
	if tools == nil {
		tools = []llm.Tool{}
	}
	return total + estimateValueTokens(tools)
}

func isSummaryMessage(m llm.Message) bool {
	return m.Role == "system" && strings.HasPrefix(dyn.Str(m.Content), SummaryPrefix)
}

func splitLeadingSystemMessages(messages []llm.Message) (leading, body []llm.Message, previousSummary string) {
	index := 0
	for index < len(messages) && messages[index].Role == "system" {
		if !isSummaryMessage(messages[index]) {
			leading = append(leading, messages[index])
		}
		index++
	}
	for _, m := range messages {
		if isSummaryMessage(m) {
			previousSummary = textx.Trim(dyn.Str(m.Content)[len(SummaryPrefix):])
			break
		}
	}
	for _, m := range messages[index:] {
		if !isSummaryMessage(m) {
			body = append(body, m)
		}
	}
	return leading, body, previousSummary
}

// Cut says which part of a transcript can be summarised.
type Cut struct {
	Compactable     bool
	SplitTurn       bool
	Leading         []llm.Message
	PreviousSummary string
	Compacted       []llm.Message
	Retained        []llm.Message
	ProjectedTokens int
	Reason          string
}

// CutRequest describes the transcript to cut.
type CutRequest struct {
	Messages            []llm.Message
	FixedMessages       []llm.Message
	Tools               []llm.Tool
	TargetTokens        int
	SummaryReserveToken int
}

// SelectTurnSafeCut finds where to cut a transcript so that what is kept fits
// the target. Whole-turn boundaries are the best cut: they never split a turn's
// reasoning from the request that started it. A long autonomous run is a single
// turn, one request followed by hundreds of tool iterations; it is cut inside
// the turn at an assistant message so no tool result is separated from its call,
// and the request itself stays verbatim so the task instruction never survives
// as summary prose alone.
func SelectTurnSafeCut(req CutRequest) Cut {
	reserve := req.SummaryReserveToken
	if reserve == 0 {
		reserve = 1800
	}
	leading, body, previousSummary := splitLeadingSystemMessages(req.Messages)
	var turnStarts []int
	for i, m := range body {
		if m.Role == "user" {
			turnStarts = append(turnStarts, i)
		}
	}
	fixed := EstimateTokenCount(append(append([]llm.Message{}, leading...), req.FixedMessages...), req.Tools)
	project := func(retained []llm.Message) int { return fixed + EstimateTokenCount(retained, nil) + reserve }

	for turn := 1; turn < len(turnStarts)-1; turn++ {
		cutIndex := turnStarts[turn]
		retained := body[cutIndex:]
		if projected := project(retained); projected <= req.TargetTokens {
			return Cut{Compactable: true, Leading: leading, PreviousSummary: previousSummary, Compacted: body[:cutIndex], Retained: retained, ProjectedTokens: projected}
		}
	}

	turnStart := -1
	if len(turnStarts) > 0 {
		turnStart = turnStarts[len(turnStarts)-1]
	}
	var anchor []llm.Message
	if turnStart >= 0 {
		anchor = []llm.Message{body[turnStart]}
	}
	for cutIndex := turnStart + 1; cutIndex < len(body); cutIndex++ {
		if body[cutIndex].Role != "assistant" {
			continue
		}
		if cutIndex-len(anchor) < 1 { // nothing would be removed
			continue
		}
		retained := append(append([]llm.Message{}, anchor...), body[cutIndex:]...)
		projected := project(retained)
		if projected > req.TargetTokens {
			continue
		}
		return Cut{Compactable: true, SplitTurn: true, Leading: leading, PreviousSummary: previousSummary, Compacted: body[:cutIndex], Retained: retained, ProjectedTokens: projected}
	}

	reason := "no_safe_cut_point"
	if len(turnStarts) < 3 {
		reason = "no_complete_historical_turn"
	}
	return Cut{Reason: reason}
}

// SerializeForSummary renders messages as the text a summariser reads.
func SerializeForSummary(messages []llm.Message) string {
	parts := make([]string, len(messages))
	for i, m := range messages {
		role := m.Role
		if role == "" {
			role = "unknown"
		}
		switch {
		case role == "assistant" && len(m.ToolCalls) > 0:
			names := make([]string, len(m.ToolCalls))
			for j, call := range m.ToolCalls {
				names[j] = call.Function.Name
				if names[j] == "" {
					names[j] = "tool"
				}
			}
			parts[i] = "assistant [tool calls: " + strings.Join(names, ", ") + "]\n" + contentText(m.Content)
		case role == "tool":
			label := m.Name
			if label == "" {
				label = m.ToolCallID
			}
			parts[i] = "tool " + label + "\n" + contentText(m.Content)
		default:
			parts[i] = role + "\n" + contentText(m.Content)
		}
	}
	return strings.Join(parts, "\n\n")
}

// BuildSummaryMessages is the request that merges turns into a summary.
func BuildSummaryMessages(previousSummary, source string) []llm.Message {
	var user []string
	if previousSummary != "" {
		user = append(user, "Existing summary:\n"+previousSummary)
	}
	user = append(user, "Turns to merge:\n"+source)
	return []llm.Message{
		{Role: "system", Content: prompts.Render("runtime/compaction.md", nil)},
		{Role: "user", Content: strings.Join(user, "\n\n")},
	}
}

// ApplyCompaction replaces the compacted part of a transcript with its summary.
func ApplyCompaction(cut Cut, summary string) []llm.Message {
	out := append([]llm.Message{}, cut.Leading...)
	out = append(out, llm.Message{Role: "system", Content: SummaryPrefix + "\n" + textx.Trim(summary)})
	return append(out, cut.Retained...)
}
