package ai

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Kinds of decision a model turn amounts to.
const (
	DecisionAct    = "act"
	DecisionAnswer = "answer"
	DecisionBlank  = "blank"
)

// Call is a tool call in the harness's stable shape: arguments parsed, and the
// OpenAI wire form kept for the transcript.
type Call struct {
	ID        string
	Name      string
	Arguments dyn.Map
	Raw       llm.ToolCall
}

// Decision is what one model turn amounts to: work, the answer, or nothing.
type Decision struct {
	Kind                  string
	Content               string
	ToolCalls             []Call
	ReasoningState        map[string]any
	ProviderContentBlocks []any
}

// NormalizeToolCalls parses each call's arguments. Arguments that are not valid
// JSON become a short preview instead: the full string can be tens of KB of
// runaway output, and everything stored here is replayed into later prompts.
func NormalizeToolCalls(calls []llm.ToolCall) []Call {
	var out []Call
	for i, call := range calls {
		name := textx.Trim(call.Function.Name)
		if name == "" {
			continue
		}
		args := dyn.Map{}
		if raw := call.Function.Arguments; raw != "" {
			var parsed any
			if err := json.Unmarshal([]byte(raw), &parsed); err != nil {
				args = dyn.Map{"_raw_preview": textx.Head(raw, 400), "_raw_length": float64(textx.Len(raw)), "_parse_error": err.Error()}
			} else if m, ok := parsed.(map[string]any); ok {
				args = m
			}
		}
		id := call.ID
		if id == "" {
			id = fmt.Sprintf("call_%d", i+1)
		}
		wireArgs, _ := json.Marshal(args)
		out = append(out, Call{
			ID: id, Name: name, Arguments: args,
			Raw: llm.ToolCall{ID: id, Type: "function", Function: llm.FunctionCall{Name: name, Arguments: string(wireArgs)}},
		})
	}
	return out
}

// DecisionFromResponse: tool calls are work; text without tool calls is the
// final answer, written for the user; an empty turn is neither and the loop
// recovers it.
func DecisionFromResponse(content string, calls []llm.ToolCall, reasoning map[string]any, blocks []any) Decision {
	content = textx.Trim(content)
	if normalized := NormalizeToolCalls(calls); len(normalized) > 0 {
		return Decision{Kind: DecisionAct, Content: content, ToolCalls: normalized, ReasoningState: reasoning, ProviderContentBlocks: blocks}
	}
	if content != "" {
		return Decision{Kind: DecisionAnswer, Content: content}
	}
	return Decision{Kind: DecisionBlank}
}

// BuildBlankOutputGuidance is what a model is told after a turn that returned
// neither text nor a tool call. When a failed tool caused it, the failure itself
// is the most useful context; otherwise the model just needs to be told the turn
// was empty and that the task is not finished.
func BuildBlankOutputGuidance(executions []ToolExecution) string {
	for i := len(executions) - 1; i >= 0; i-- {
		item := executions[i]
		if item.OK {
			continue
		}
		name := item.ToolName
		if name == "" {
			name = "the previous tool"
		}
		failure := item.Error
		if failure == "" {
			failure = item.Summary
		}
		if failure == "" {
			failure = "unknown failure"
		}
		return strings.Join([]string{
			fmt.Sprintf("The previous tool %q failed with: %s.", name, SummarizeForLog(failure, 240)),
			"The latest assistant turn returned no user-facing answer and no tool call, so the task is not terminal.",
			"Continue with the next safe recovery action now: retry with corrected arguments, use another available tool, verify from existing evidence, or report a real blocker only if no autonomous path remains.",
			"Do not invent a finished result. Prefer a concrete recovery step or a truthful partial answer over silence.",
		}, " ")
	}
	return strings.Join([]string{
		"The latest assistant turn returned no user-facing answer and no tool call, so the task is not terminal.",
		"Take the next concrete action now: call the tool you need, or give a complete final answer if the work is already evidenced.",
		"Do not repeat an empty turn and do not claim a result you have not produced.",
	}, " ")
}
