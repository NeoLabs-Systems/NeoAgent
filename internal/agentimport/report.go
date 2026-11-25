package agentimport

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/runtimecfg"
)

var statusOrder = []string{"imported", "exists", "skipped", "failed"}

var statusTitles = map[string]string{
	"imported": "Brought over",
	"exists":   "Already in NeoAgent",
	"skipped":  "Left behind",
	"failed":   "Could not be imported",
}

// writeReport records every item as a Markdown file, for later. Names only: no
// key values. It returns the file's path.
func (s *Session) writeReport(bundles []Bundle, now time.Time) (string, error) {
	dir := filepath.Join(s.env.RuntimeHome, "imports")
	if err := runtimecfg.EnsurePrivateDir(dir); err != nil {
		return "", err
	}
	stamp := strings.ReplaceAll(now.UTC().Format("2006-01-02T15:04:05Z"), ":", "-")
	file := filepath.Join(dir, "import-"+stamp+".md")

	var sources []string
	for _, b := range bundles {
		sources = append(sources, fmt.Sprintf("%s (%s)", b.Label, b.Path))
	}
	lines := []string{"# Import from " + strings.Join(sources, ", "), "", now.Format("Mon Jan 02 2006 15:04:05 GMT-0700 (MST)"), ""}
	for _, status := range statusOrder {
		var entries []Entry
		for _, e := range s.Entries {
			if e.Status == status {
				entries = append(entries, e)
			}
		}
		if len(entries) == 0 {
			continue
		}
		lines = append(lines, fmt.Sprintf("## %s (%d)", statusTitles[status], len(entries)), "")
		for _, e := range entries {
			line := fmt.Sprintf("- **%s** %s", e.Kind, e.Name)
			if e.Detail != "" {
				line += " — " + e.Detail
			}
			lines = append(lines, line)
		}
		lines = append(lines, "")
	}
	return file, os.WriteFile(file, []byte(strings.Join(lines, "\n")), 0o600)
}

var kindNames = map[string][2]string{
	"Key":         {"key", "keys"},
	"Agent":       {"agent", "agents"},
	"Memory":      {"memory", "memories"},
	"Daily notes": {"day of notes", "days of notes"},
	"Skill":       {"skill", "skills"},
	"Model":       {"model choice", "model choices"},
	"MCP server":  {"MCP server", "MCP servers"},
	"Automation":  {"automation", "automations"},
	"Channel":     {"chat setting", "chat settings"},
	"Setting":     {"setting", "settings"},
}

// totals turns report lines into "12 memories", "3 skills": one total per kind.
func totals(entries []Entry) []string {
	var order []string
	byKind := map[string]int{}
	for _, e := range entries {
		if _, ok := byKind[e.Kind]; !ok {
			order = append(order, e.Kind)
		}
		byKind[e.Kind] += e.Count
	}
	out := []string{}
	for _, kind := range order {
		names, ok := kindNames[kind]
		if !ok {
			lower := strings.ToLower(kind)
			names = [2]string{lower, lower + "s"}
		}
		n := byKind[kind]
		name := names[1]
		if n == 1 {
			name = names[0]
		}
		out = append(out, fmt.Sprintf("%d %s", n, name))
	}
	return out
}
