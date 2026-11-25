package skills

import (
	"context"
	"github.com/NeoLabs-Systems/neoagent/internal/jsrules"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
)

var (
	shellMetaRE   = regexp.MustCompile("[;&|`$\n\r(){}\\\\<>]")
	placeholderRE = regexp.MustCompile(`\{[^{}]*\}`)
)

// IsValidCommandTemplate reports whether a skill's command template is free
// of shell metacharacters once its {placeholders} are taken out.
func IsValidCommandTemplate(template string) bool {
	return !shellMetaRE.MatchString(placeholderRE.ReplaceAllString(template, ""))
}

// shellQuote wraps a value in single quotes for a POSIX shell.
func shellQuote(value string) string {
	if value == "" {
		return "''"
	}
	return "'" + strings.ReplaceAll(value, "'", `'\''`) + "'"
}

// clampText squeezes whitespace and cuts the text to max UTF-16 units, the
// last of them being the ellipsis.
func clampText(value string, max int) string {
	text := collapseSpaces(value)
	if text == "" || jsrules.Len(text) <= max {
		return text
	}
	keep := max - 1
	if keep < 0 {
		keep = 0
	}
	cut := string(utf16.Decode(utf16.Encode([]rune(text))[:keep]))
	return strings.TrimRightFunc(cut, jsrules.IsSpace) + "..."
}

// PromptOptions bound the skills section of the system prompt. Zero values
// take the defaults.
type PromptOptions struct {
	UserID              int64
	MaxTotalChars       int
	MaxDescriptionChars int
	MaxTriggerChars     int
}

// SkillsForPrompt is the "Installed Skills" section of the system prompt, or
// the empty string when the user has no enabled skill.
func (r *Runner) SkillsForPrompt(o PromptOptions) string {
	if o.MaxTotalChars == 0 {
		o.MaxTotalChars = 9000
	}
	if o.MaxDescriptionChars == 0 {
		o.MaxDescriptionChars = 220
	}
	if o.MaxTriggerChars == 0 {
		o.MaxTriggerChars = 120
	}
	var skills []Skill
	for _, s := range r.GetAll(o.UserID) {
		if s.Enabled() {
			skills = append(skills, s)
		}
	}
	if len(skills) == 0 {
		return ""
	}
	category := func(s Skill) string {
		return jsrules.String(jsrules.OrDefault(s.Metadata.Value("category"), "general"))
	}
	sort.SliceStable(skills, func(i, j int) bool {
		if ci, cj := category(skills[i]), category(skills[j]); ci != cj {
			return localeLess(ci, cj)
		}
		return localeLess(skills[i].Name, skills[j].Name)
	})

	lines := []string{
		"## Installed Skills",
		"These are reusable local workflows loaded into NeoAgent. Use a matching skill when it clearly fits the task: load its full instructions by passing its name to `list_skills`, then follow them.",
	}
	for _, s := range skills {
		parts := []string{"- `" + s.Name + "`"}
		var tags []string
		for _, key := range []string{"category", "source"} {
			if v := s.Metadata.Value(key); jsrules.Truthy(v) {
				tags = append(tags, jsrules.String(v))
			}
		}
		if len(tags) > 0 {
			parts = append(parts, "["+strings.Join(tags, " / ")+"]")
		}
		if d := clampText(s.Description, o.MaxDescriptionChars); d != "" {
			parts = append(parts, d)
		}
		if t := clampText(jsrules.OrEmpty(s.Metadata.Value("trigger")), o.MaxTriggerChars); t != "" {
			parts = append(parts, "Trigger: "+t)
		}
		next := strings.Join(parts, " ")
		if jsrules.Len(strings.Join(lines, "\n")+"\n"+next) > o.MaxTotalChars {
			more := len(skills) - (len(lines) - 2)
			lines = append(lines, "- ...and "+strconv.Itoa(more)+" more skills. Use `list_skills` if you need the full catalog.")
			break
		}
		lines = append(lines, next)
	}
	return "\n" + strings.Join(lines, "\n")
}

// ToolDefinitions lists the enabled skills that declare themselves a tool.
func (r *Runner) ToolDefinitions(userID int64) []workspace.Obj {
	var tools []workspace.Obj
	for _, s := range r.GetAll(userID) {
		if !s.Enabled() || !jsrules.Truthy(s.Metadata.Value("tool")) {
			continue
		}
		params := jsrules.OrDefault(s.Metadata.Value("parameters"), workspace.Obj{
			{Key: "type", Value: "object"}, {Key: "properties", Value: workspace.Obj{}},
		})
		tools = append(tools, workspace.Obj{
			{Key: "name", Value: s.Name}, {Key: "description", Value: s.Description}, {Key: "parameters", Value: params},
		})
	}
	return tools
}

// ToolCall is a model's call of a skill.
type ToolCall struct {
	UserID  int64
	AgentID *string
	Args    workspace.Obj
}

// Execute runs a skill the model called as a tool. It reports false when no
// skill has that name. A skill with a command runs it in the user's computer;
// a documentation-only skill answers with its instructions.
func (r *Runner) Execute(ctx context.Context, toolName string, call ToolCall) (workspace.Obj, bool) {
	skill, ok := r.GetSkill(toolName, call.UserID)
	if !ok {
		return nil, false
	}
	record := func(m Metric) {
		if err := r.RecordMetric(ctx, call.UserID, call.AgentID, toolName, m); err != nil {
			r.log.Error("record skill metric failed", "skill", toolName, "error", err)
		}
	}
	failure := func(fields ...workspace.Field) (workspace.Obj, bool) {
		record(Metric{Failure: 1})
		return fields, true
	}
	record(Metric{Invocation: 1})
	fail := func(message string) (workspace.Obj, bool) {
		return failure(workspace.Field{Key: "error", Value: message})
	}
	if !skill.Enabled() {
		return fail("Skill '" + toolName + "' is disabled")
	}

	command := skill.Metadata.Value("command")
	if !jsrules.Truthy(command) {
		return failure(
			workspace.Field{Key: "error", Value: "Skill '" + toolName + "' is documentation-only and cannot execute directly."},
			workspace.Field{Key: "skill", Value: skill.Name},
			workspace.Field{Key: "instructions", Value: skill.Instructions},
			workspace.Field{Key: "args", Value: call.Args},
		)
	}
	template := jsrules.String(command)
	if !IsValidCommandTemplate(template) {
		return fail("Skill '" + toolName + "' has an invalid command template")
	}
	for _, f := range call.Args {
		value := ""
		if f.Value != nil {
			value = jsrules.String(f.Value)
		}
		template = strings.ReplaceAll(template, "{"+f.Key+"}", shellQuote(value))
	}
	if call.UserID <= 0 {
		return fail("Missing or invalid userId")
	}
	if r.commands == nil {
		return fail("VM runtime is required")
	}
	result, err := r.commands.ExecuteCommand(ctx, call.UserID, template)
	if err != nil {
		r.log.Error("skill command execution failed", "user", call.UserID, "skill", skill.Name, "error", err)
		return failure(
			workspace.Field{Key: "error", Value: "Skill command execution failed"},
			workspace.Field{Key: "details", Value: err.Error()},
		)
	}
	failed := jsrules.Truthy(result.Value("error"))
	if code, ok := result.Value("exitCode").(float64); ok && code != 0 {
		failed = true
	}
	if failed {
		record(Metric{Failure: 1})
	} else {
		record(Metric{Success: 1})
	}
	return result, true
}
