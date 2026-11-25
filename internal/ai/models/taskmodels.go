package models

import (
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// TaskKinds are the kinds of work a user can pin a model to, and the tools that
// show a run is doing that work. A tool matches by exact name or by `prefix*`.
// This is the only place the two are tied together; routing reads what a run
// actually calls, never what the task text says.
var taskKinds = []struct {
	Kind     string
	Patterns []string
}{
	{"coding", []string{"edit_file", "write_file", "replace_file_range", "code_navigate"}},
	{"computer_use", []string{"browser_*", "desktop_*"}},
	{"android_use", []string{"android_*"}},
	{"research", []string{"web_*", "search_web"}},
}

// TaskModelKinds lists the kinds a model can be pinned to.
func TaskModelKinds() []string {
	kinds := make([]string, len(taskKinds))
	for i, k := range taskKinds {
		kinds[i] = k.Kind
	}
	return kinds
}

func matchesTool(pattern, toolName string) bool {
	if prefix, ok := strings.CutSuffix(pattern, "*"); ok {
		return strings.HasPrefix(toolName, prefix)
	}
	return toolName == pattern
}

// NormalizeTaskModels keeps the pinned models that are valid selection ids.
func NormalizeTaskModels(raw map[string]any) map[string]string {
	normalized := map[string]string{}
	for _, k := range taskKinds {
		value, _ := raw[k.Kind].(string)
		selection := textx.Trim(value)
		if _, ok := ParseSelectionID(selection); ok {
			normalized[k.Kind] = selection
		}
	}
	return normalized
}

// InferTaskKind is the kind of work a set of tool calls belongs to: the kind most
// of the recognised calls fall under (the first kind wins a tie), or "" when none
// are recognised.
func InferTaskKind(toolNames []string) string {
	counts := map[string]int{}
	var order []string
	for _, name := range toolNames {
		for _, k := range taskKinds {
			matched := false
			for _, pattern := range k.Patterns {
				matched = matched || matchesTool(pattern, name)
			}
			if matched {
				if counts[k.Kind] == 0 {
					order = append(order, k.Kind)
				}
				counts[k.Kind]++
				break
			}
		}
	}
	best := ""
	for _, kind := range order {
		if best == "" || counts[kind] > counts[best] {
			best = kind
		}
	}
	return best
}
