package ai

import (
	"fmt"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// SummarizeForLog is a one-line, length-bounded rendering of any value.
func SummarizeForLog(value any, maxChars int) string {
	if value == nil {
		return ""
	}
	text, ok := value.(string)
	if !ok {
		text = dyn.Stringify(value)
	}
	normalized := textx.Collapse(text)
	if textx.Len(normalized) <= maxChars {
		return normalized
	}
	return textx.Head(normalized, maxChars) + "..."
}

// commandFailureMessage: exit status is execution evidence even when a program
// prints no stderr. A caller may interpret grep's no-match as useful, but it is
// not exit success.
func commandFailureMessage(result any) string {
	m := dyn.Obj(result)
	if m == nil {
		return ""
	}
	if dyn.Truthy(m["error"]) {
		return SummarizeForLog(dyn.String(m["error"]), 220)
	}
	if dyn.Truthy(m["timedOut"]) {
		duration := dyn.Str(m["durationMs"])
		if duration == "" {
			duration = "unknown"
		}
		return fmt.Sprintf("Command timed out after %s ms", duration)
	}
	if dyn.Truthy(m["killed"]) || dyn.Truthy(m["signal"]) {
		return "Command was killed before it finished"
	}
	stderr := textx.Trim(dyn.Str(m["stderr"]))
	if code, ok := m["exitCode"].(float64); ok && code != 0 {
		if stderr == "" {
			stderr = fmt.Sprintf("Command exited with status %s.", dyn.Number(code))
		}
		return SummarizeForLog(stderr, 220)
	}
	return ""
}
