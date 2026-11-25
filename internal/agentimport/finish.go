package agentimport

import (
	"context"
	"fmt"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const (
	maxPromptChars = 14000
	maxFileChars   = 4000
	startDelay     = 2 * time.Minute
)

var secretName = regexp.MustCompile(`(?i)(key|token|secret|password|auth)`)

// redact hides secrets in an item's details, which can carry a stdio server's
// env or a job's command, so they never end up in a prompt.
func redact(v any) any {
	switch t := v.(type) {
	case []any:
		out := make([]any, len(t))
		for i, item := range t {
			out[i] = redact(item)
		}
		return out
	case *Obj:
		out := newObj()
		for _, k := range t.Keys() {
			inner := t.Get(k)
			if _, isString := inner.(string); isString && secretName.MatchString(k) {
				out.set(k, "[hidden]")
			} else {
				out.set(k, redact(inner))
			}
		}
		return out
	}
	return v
}

func (s *Session) leftoverLines() []string {
	var lines []string
	for _, e := range s.Entries {
		if (e.Status == "skipped" || e.Status == "failed") && e.Kind != "Key" {
			lines = append(lines, fmt.Sprintf(`- %s "%s": %s`, e.Kind, e.Name, e.Detail))
		}
	}
	return lines
}

// handWrittenRules are source files worth the agent's reading: operating rules
// the user wrote by hand (OpenClaw's AGENTS.md) that have no direct NeoAgent
// field.
func handWrittenRules(bundles []Bundle) []string {
	var parts []string
	for _, b := range bundles {
		for _, a := range b.Agents {
			if b.Source != "openclaw" {
				continue
			}
			text, ok := readText(filepath.Join(a.Workspace, "AGENTS.md"))
			if !ok || text == "" {
				continue
			}
			flagged := false
			for _, item := range b.Skipped {
				if item.Name == a.Key+"/AGENTS.md" {
					flagged = true
				}
			}
			if flagged {
				parts = append(parts, fmt.Sprintf("### %s (%s) AGENTS.md\n%s", a.Name, b.Label, jsSlice(text, maxFileChars)))
			}
		}
	}
	return parts
}

func bundleLabels(bundles []Bundle) string {
	var labels []string
	for _, b := range bundles {
		if !contains(labels, b.Label) {
			labels = append(labels, b.Label)
		}
	}
	return strings.Join(labels, " and ")
}

// buildFinishPrompt is the one-time automation's prompt: the imported agent
// reads what was left behind and rebuilds what it can with tools it may use
// unattended.
func buildFinishPrompt(bundles []Bundle, s *Session) string {
	labels := bundleLabels(bundles)
	var detailed []string
	for _, b := range bundles {
		for _, item := range b.Skipped {
			if item.Detail != nil {
				detailed = append(detailed, fmt.Sprintf(`- %s "%s" (%s): %s`, item.Kind, item.Name, b.Label, marshal(redact(item.Detail))))
			}
		}
	}
	left := s.leftoverLines()
	sections := []string{
		fmt.Sprintf("The user just moved from %s to NeoAgent. A script already imported keys, agents, memories, skills, automations, MCP servers and chat channels. Finish the move for the parts the script could not translate.", labels),
		"You run unattended: nobody is there to approve a tool call. Do not use execute_command, file writes or the browser. Work with memory_save, memory_update_core, create_task, list_tasks and mcp_add_server. If a tool is blocked or needs approval, do not retry it; put the exact change in your final message instead.",
		"For each item below, either recreate it the NeoAgent way or decide it is not needed (a local filesystem MCP server is not, for example: NeoAgent has its own file tools). Never invent credentials: where a token is missing, say so in your final message. Do not change anything that was imported correctly.",
	}
	if len(left) > 0 {
		sections = append(sections, "## Left behind\n"+strings.Join(left, "\n"))
	}
	if len(detailed) > 0 {
		sections = append(sections, "## Original definitions\n"+strings.Join(detailed, "\n"))
	}
	for _, part := range handWrittenRules(bundles) {
		sections = append(sections, fmt.Sprintf("## Rules the user wrote by hand\nKeep the ones that still apply as memories or core memory; ignore anything specific to %s's own tooling.\n%s", labels, part))
	}
	sections = append(sections, "End with one short notify_user message: what you set up, and what the user still needs to do themselves, with the exact place in NeoAgent to do it.")
	return jsSlice(strings.Join(sections, "\n\n"), maxPromptChars)
}

// hasLeftovers is true only after a run that brought something over: a repeat
// run has nothing new for the agent, and would queue the same work twice.
func (s *Session) hasLeftovers() bool {
	brought := false
	for _, e := range s.Entries {
		if e.Status == "imported" && e.Kind != "Key" {
			brought = true
		}
	}
	return brought && len(s.leftoverLines()) > 0
}

// queueFinishTask schedules a one-time automation for the main agent, shortly
// after the restart that loads everything the import wrote. It returns the
// automation's name.
func (s *Session) queueFinishTask(ctx context.Context, bundles []Bundle, now time.Time) (string, error) {
	name := "Finish moving in from " + bundleLabels(bundles)
	main, err := s.env.Host.EnsureMainAgent(ctx, s.userID)
	if err != nil {
		return "", err
	}
	err = s.env.Host.CreateTask(ctx, s.userID, TaskSpec{
		AgentID:       main.ID,
		Name:          name,
		TriggerConfig: map[string]any{"mode": "one_time", "runAt": isoString(now.Add(startDelay))},
		TaskConfig:    TaskConfig{Prompt: buildFinishPrompt(bundles, s)},
		Enabled:       true,
	})
	return name, err
}
