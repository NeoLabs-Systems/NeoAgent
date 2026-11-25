package ai

import (
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Model-free helpers for shaping outgoing messages, plus the instructions for
// the two side turns the runtime asks the model for: progress pings and the
// wrap-up after a runaway guard stops a run. The text the user sees is always
// written by the model; nothing here produces a reply on its own.

var (
	noResponseMarker = regexp.MustCompile(`(?i)\[NO RESPONSE\]`)
	rawHTMLTag       = regexp.MustCompile(`</?[^>]+>`)
	trailingBlanks   = regexp.MustCompile(`[ \t]+\n`)
)

// coerceMessageContent reads a message payload as text the way the messaging
// layer does: strings as they are, structured values by their text field.
func coerceMessageContent(content any) string {
	switch v := content.(type) {
	case nil:
		return ""
	case string:
		return v
	case map[string]any:
		for _, key := range []string{"text", "content", "message", "summary"} {
			if s, ok := v[key].(string); ok && textx.Trim(s) != "" {
				return s
			}
		}
		if v["result"] != nil {
			return coerceMessageContent(v["result"])
		}
		return dyn.StringifyIndent(v)
	case []any:
		return dyn.StringifyIndent(v)
	}
	return dyn.String(content)
}

// normalizeOutgoingDefault is the platform-independent normalisation of a
// message: [NO RESPONSE] markers, raw HTML and stray blank lines removed, then
// whitespace collapsed to single spaces.
func normalizeOutgoingDefault(content any, collapseWhitespace bool) string {
	text := coerceMessageContent(content)
	text = noResponseMarker.ReplaceAllString(text, "")
	text = strings.ReplaceAll(text, "\r\n", "\n")
	text = rawHTMLTag.ReplaceAllString(text, "")
	text = trailingBlanks.ReplaceAllString(text, "\n")
	text = blankRuns.ReplaceAllString(text, "\n\n")
	text = textx.Trim(text)
	if !collapseWhitespace {
		return text
	}
	return textx.Collapse(text)
}

// ClampRunContext shortens a text for the run record or a prompt.
func ClampRunContext(text any, maxChars int) string {
	value := normalizeOutgoingDefault(text, true)
	if value == "" {
		return ""
	}
	if textx.Len(value) <= maxChars {
		return value
	}
	return textx.Head(value, maxChars) + "..."
}

// WrapUpReasons tell the model, for its last turn, what each runaway guard meant.
var wrapUpReasons = map[string]string{
	"token_budget":     "it used all the tokens it was allowed",
	"malformed_output": "the model kept writing tool calls as text instead of making them",
	"turn_limit":       "the run reached its emergency turn limit",
	"no_progress":      "the last several steps changed nothing and found nothing new",
	"tool_failures":    "every tool call in the last several steps failed",
	"context_overflow": "the conversation grew too large to continue",
	"blank_output":     "the model kept returning empty turns",
}

// Formatting is what the harness needs of the messaging layer's per-platform
// rules.
type Formatting interface {
	// Guide is the reply formatting guide for a platform ("" for none).
	Guide(platform string) string
}

// BuildWrapUpPrompt is the instruction for the model's last turn after a guard
// stopped the run.
func BuildWrapUpPrompt(reason, platform string, formatting Formatting) string {
	why, ok := wrapUpReasons[reason]
	if !ok {
		why = reason
	}
	return prompts.Render("runtime/wrap_up.md", map[string]string{"why": why}) + "\n\n" + formatting.Guide(platform)
}

// BuildProgressUpdatePrompt carries no voice or formatting rules of its own:
// this prompt runs with the run's real system prompt as context, so the update
// inherits the same voice as every other message.
func BuildProgressUpdatePrompt() string {
	return prompts.Render("runtime/progress_update.md", nil)
}
