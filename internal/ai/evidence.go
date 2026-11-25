package ai

import (
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

// Classifies tool executions into run evidence: what changed, what failed, and
// what is relevant to the user's answer. The runaway guards and progress
// narration read it. It holds no engine state, so the rules are pure.

// ToolExecution is one finished tool call as the guards read it.
type ToolExecution struct {
	ToolName       string
	OK             bool
	Error          string
	EvidenceSource string
	// Any successful, substantive tool result can advance the run. This default
	// is deliberate: MCP, skills, and newly added integrations must not become
	// invisible to the churn guard. Repetition detection still rejects
	// unchanged retries.
	EvidenceRelevant bool
	StateChanged     bool
	Summary          string
}

// ClassifyToolExecution turns a finished call into evidence.
func (s *Shaper) ClassifyToolExecution(toolName string, toolArgs dyn.Map, result any, errorMessage string, definition *tools.Definition) ToolExecution {
	meta := s.Tools.Meta(toolName, definition)
	normalizedError := textx.Trim(errorMessage)
	if normalizedError == "" {
		normalizedError = textx.Trim(s.inferToolFailureMessage(toolName, result))
	}
	summarized := result
	if !dyn.Truthy(result) {
		if errorMessage == "" {
			errorMessage = "Tool failed"
		}
		summarized = dyn.Map{"error": errorMessage}
	}
	return ToolExecution{
		ToolName:         toolName,
		OK:               normalizedError == "",
		Error:            normalizedError,
		EvidenceSource:   meta.Group,
		EvidenceRelevant: s.isSubstantiveProgressToolName(toolName),
		StateChanged:     tools.ChangesState(meta, toolArgs) && normalizedError == "",
		Summary:          s.CompactToolResult(toolName, toolArgs, summarized, ResultOptions{SoftLimit: 500, HardLimit: 900}),
	}
}

// SummarizeToolExecutions lists the last executions, one line each.
func SummarizeToolExecutions(executions []ToolExecution, maxItems int) string {
	if len(executions) > maxItems {
		executions = executions[len(executions)-maxItems:]
	}
	lines := make([]string, len(executions))
	for i, item := range executions {
		status := "ok"
		if !item.OK {
			status = "error=" + item.Error
		}
		lines[i] = fmt.Sprintf("%d. %s [%s] %s :: %s", i+1, item.ToolName, item.EvidenceSource, status, ClampRunContext(item.Summary, 220))
	}
	return strings.Join(lines, "\n")
}

// GatheredNewEvidence: a read-only turn that pulls in NEW information is real
// progress, even though it changes no state. Research, browsing, reading and
// searching are how an agent makes headway on "find out X" tasks; treating them
// as "no progress" (and force-wrapping the run) is what guillotines legitimate
// research. Genuine churn (failed calls, or re-running an identical call that
// returns an unchanged result) is excluded, so the read-only guard still fires
// on real spinning.
func GatheredNewEvidence(execution *ToolExecution, repetition *UnchangedObservation) bool {
	if execution == nil || !execution.OK || !execution.EvidenceRelevant {
		return false
	}
	return repetition == nil || repetition.UnchangedCount < 2
}

// Talking to the user and managing the run's own tools report progress or set
// it up; neither is progress on the task.
func (s *Shaper) isSubstantiveProgressToolName(toolName string) bool {
	name := textx.Trim(toolName)
	if name == "" {
		return false
	}
	meta := s.Tools.Meta(name, nil)
	return meta.Group != "control" && meta.SideEffect != "message"
}

// IsSubstantiveProgressEvidence reports whether an execution counts as progress on the task.
func (s *Shaper) IsSubstantiveProgressEvidence(item ToolExecution) bool {
	if !s.isSubstantiveProgressToolName(item.ToolName) || item.EvidenceSource == "messaging" {
		return false
	}
	return item.EvidenceRelevant || item.StateChanged || item.Error != ""
}

// SummarizeProgressToolExecutions lists the executions that count as progress.
func (s *Shaper) SummarizeProgressToolExecutions(executions []ToolExecution, maxItems int) string {
	var progress []ToolExecution
	for _, item := range executions {
		if s.IsSubstantiveProgressEvidence(item) {
			progress = append(progress, item)
		}
	}
	return SummarizeToolExecutions(progress, maxItems)
}

func (s *Shaper) inferToolFailureMessage(toolName string, result any) string {
	if explicit := normalizeOutgoingDefault(or(dyn.Get(result, "error"), ""), true); explicit != "" {
		return explicit
	}
	m := dyn.Obj(result)
	if m == nil {
		return ""
	}
	// Choosing to say nothing is an answer, not a failed send.
	if m["reason"] == "no_response" {
		return ""
	}
	nested := dyn.Obj(m["result"])
	var failedReport dyn.Map
	for _, entry := range dyn.List(m["report"]) {
		if dyn.Get(entry, "success") == false {
			failedReport = dyn.Obj(entry)
			break
		}
	}
	if m["success"] == false || nested["success"] == false || m["sent"] == false || nested["sent"] == false || failedReport != nil {
		message := or(m["reason"], m["message"], nested["error"], nested["reason"], failedReport["error"], failedReport["note"], "Tool reported an unsuccessful outcome.")
		return SummarizeForLog(dyn.String(message), 240)
	}
	if m["skipped"] == true || nested["skipped"] == true {
		return dyn.String(or(m["reason"], m["message"], "Tool reported skipped outcome."))
	}
	if s.Tools.Meta(toolName, nil).Group == "shell" {
		return commandFailureMessage(result)
	}
	if status, ok := m["status"].(float64); toolName == "http_request" && ok && status >= 400 {
		snippet := normalizeOutgoingDefault(or(m["body"], ""), true)
		text := fmt.Sprintf("HTTP request returned status %s", dyn.Number(status))
		if snippet != "" {
			text += ": " + snippet
		}
		return SummarizeForLog(text, 240)
	}
	return ""
}
