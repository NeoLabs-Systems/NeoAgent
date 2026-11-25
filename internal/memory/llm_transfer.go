package memory

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Moving memory in from another assistant: a prompt that makes it write an
// export, and the parser for the text it answers with.

var headingAliases = map[string]string{
	"profile":                  "identity",
	"identity":                 "identity",
	"preferences":              "preferences",
	"preference":               "preferences",
	"projects":                 "projects",
	"project":                  "projects",
	"contacts":                 "contacts",
	"contact":                  "contacts",
	"events":                   "events",
	"event":                    "events",
	"tasks":                    "tasks",
	"task":                     "tasks",
	"assistant self":           "assistant_self",
	"self":                     "assistant_self",
	"behavior notes":           "__behavior_notes",
	"assistant behavior notes": "__behavior_notes",
	"core memory":              "__core",
	"core memories":            "__core",
	"other memories":           "episodic",
	"other":                    "episodic",
	"misc":                     "episodic",
	"miscellaneous":            "episodic",
}

var sectionPriority = map[string]int{
	"identity": 8, "preferences": 7, "projects": 6, "contacts": 6,
	"events": 6, "tasks": 6, "assistant_self": 7, "episodic": 5,
}

const maxTransferMemories = 200

var (
	headingHashes = regexp.MustCompile(`^#+[` + jsx.SpaceClass + `]*`)
	headingColons = regexp.MustCompile(`:+$`)
	lineBreak     = regexp.MustCompile(`\r?\n`)
	bulletLine    = regexp.MustCompile(`^[` + jsx.SpaceClass + `]*(?:[-*]|\x{2022}|\d+\.)[` + jsx.SpaceClass + `]+([^\n\r\x{2028}\x{2029}]*)$`)
	coreBullet    = regexp.MustCompile(`^[-*][` + jsx.SpaceClass + `]*`)
)

func normalizeHeadingLabel(input string) string {
	s := headingHashes.ReplaceAllString(jsx.Trim(input), "")
	s = headingColons.ReplaceAllString(s, "")
	return jsx.Lower(jsx.ReplaceSpaceRuns(s))
}

func detectHeading(line string) (string, bool) {
	trimmed := jsx.Trim(line)
	if trimmed == "" {
		return "", false
	}
	normalized := normalizeHeadingLabel(trimmed)
	if _, ok := headingAliases[normalized]; ok {
		return normalized, true
	}
	return "", false
}

type section struct {
	heading string
	lines   []string
}

func splitSections(text string) []section {
	var sections []section
	current := section{heading: "other"}
	for _, line := range lineBreak.Split(text, -1) {
		if heading, ok := detectHeading(line); ok {
			sections = append(sections, current)
			current = section{heading: heading}
			continue
		}
		current.lines = append(current.lines, line)
	}
	return append(sections, current)
}

func collectBulletItems(lines []string) []string {
	var items []string
	for _, line := range lines {
		if m := bulletLine.FindStringSubmatch(line); m != nil && m[1] != "" {
			if value := jsx.Trim(m[1]); value != "" {
				items = append(items, value)
			}
		}
	}
	return items
}

func collapseParagraph(lines []string) string {
	var parts []string
	for _, line := range lines {
		if t := jsx.Trim(line); t != "" {
			parts = append(parts, t)
		}
	}
	return strings.Join(parts, " ")
}

// LLMTransferPrompt is the text a user pastes into another assistant to get a
// memory export NeoAgent can import.
func LLMTransferPrompt(agentLabel string) string {
	return strings.Join([]string{
		"You are preparing a memory export for " + agentLabel + ".",
		"Produce a concise, structured summary of everything you know about the user. Be specific and concrete — names, preferences, and facts matter more than vague generalizations.",
		"",
		"Rules:",
		"- Plain text only. No JSON, no code blocks, no markdown tables.",
		"- Short bullet points. One fact per bullet, at most 150 characters.",
		"- State facts, not impressions. \"Prefers Python over JavaScript\" beats \"enjoys coding\".",
		"- Omit secrets, passwords, API keys, and sensitive credentials entirely.",
		"- Omit sections with no useful data.",
		"",
		"Use these sections and formatting:",
		"# Profile",
		"- Key identity facts: name, role, location, languages, and anything stable.",
		"# Preferences",
		"- Concrete preferences, defaults, and habits. Include tool, style, and workflow choices.",
		"# Projects",
		"- Ongoing projects with their current state and goal. Include deadlines if known.",
		"# Contacts",
		"- Important people or organizations, their role, and relationship to the user.",
		"# Events",
		"- Important dates, recurring events, or deadlines. Use absolute dates where possible.",
		"# Tasks",
		"- Open tasks or commitments the user expects to be remembered.",
		"# Behavior Notes",
		"Short, specific guidance for how the assistant should behave with this user.",
		"# Core Memory",
		"key: value entries for critical facts that must always be available.",
		"# Other Memories",
		"- Anything concrete that does not fit the sections above.",
	}, "\n")
}

// TransferMemory is one memory line of an import.
type TransferMemory struct {
	Category string
	Content  string
}

// TransferImport is a parsed memory export.
type TransferImport struct {
	Memories      []TransferMemory
	CoreEntries   *jsx.Obj
	BehaviorNotes string
	Warnings      []string
}

// ParseLLMTransferText reads an export written to the LLMTransferPrompt format.
func ParseLLMTransferText(text string) TransferImport {
	var memories []TransferMemory
	core := jsx.NewObj()
	behaviorNotes := ""
	warnings := []string{}

	for _, sec := range splitSections(text) {
		heading := normalizeHeadingLabel(sec.heading)
		alias, ok := headingAliases[heading]
		if !ok {
			alias = "episodic"
		}

		switch alias {
		case "__behavior_notes":
			if notes := collapseParagraph(sec.lines); notes != "" {
				behaviorNotes = notes
			}
			continue
		case "__core":
			for _, raw := range sec.lines {
				line := jsx.Trim(raw)
				if line == "" {
					continue
				}
				cleaned := coreBullet.ReplaceAllString(line, "")
				colon := strings.Index(cleaned, ":")
				if colon <= 0 {
					continue
				}
				key, value := jsx.Trim(cleaned[:colon]), jsx.Trim(cleaned[colon+1:])
				if key == "" || value == "" || key == "active_context" {
					continue
				}
				core.Set(key, value)
			}
			continue
		}

		if items := collectBulletItems(sec.lines); len(items) > 0 {
			for _, item := range items {
				if content := jsx.Trim(item); content != "" {
					memories = append(memories, TransferMemory{Category: alias, Content: content})
				}
			}
			continue
		}
		if paragraph := jsx.Trim(collapseParagraph(sec.lines)); paragraph != "" {
			memories = append(memories, TransferMemory{Category: alias, Content: paragraph})
		}
	}

	if len(memories) > maxTransferMemories {
		warnings = append(warnings, fmt.Sprintf("Import exceeded %d items; extra entries were skipped.", maxTransferMemories))
		memories = memories[:maxTransferMemories]
	}
	return TransferImport{Memories: memories, CoreEntries: core, BehaviorNotes: behaviorNotes, Warnings: warnings}
}

// ImportanceForCategory is the importance an imported memory of a category gets.
func ImportanceForCategory(category string) int {
	if p := sectionPriority[category]; p != 0 {
		return p
	}
	return 5
}
