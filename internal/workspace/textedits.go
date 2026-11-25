// Package workspace is the per-user file workspace the agent's file tools work
// in: path confinement, atomic writes, exact-text edits, line-range
// replacement, directory listing, text search and structured-data queries.
package workspace

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"unicode/utf16"
)

const (
	maxNearbyLines    = 5
	maxListedLocation = 5
	maxNearbyChars    = 160
	previewChars      = 50
)

// CoerceText turns a JSON value into the text a file receives: strings as they
// are, numbers and booleans spelled out, string lists joined by newlines and
// anything else as indented JSON.
func CoerceText(value any) string {
	switch v := value.(type) {
	case nil:
		return ""
	case string:
		return v
	case bool:
		return fmt.Sprint(v)
	case float64:
		return jsNumber(v)
	case json.Number:
		return v.String()
	case int:
		return fmt.Sprint(v)
	case int64:
		return fmt.Sprint(v)
	case []any:
		parts := make([]string, 0, len(v))
		allStrings := true
		for _, item := range v {
			s, ok := item.(string)
			if !ok {
				allStrings = false
				break
			}
			parts = append(parts, s)
		}
		if allStrings {
			return strings.Join(parts, "\n")
		}
	}
	out, err := marshalIndent(value)
	if err != nil {
		return ""
	}
	return out
}

func jsNumber(v float64) string {
	b, _ := json.Marshal(v)
	return string(b)
}

// marshalIndent matches JSON.stringify(value, null, 2): no HTML escaping and
// empty containers written as [] and {}.
func marshalIndent(value any) (string, error) {
	var sb strings.Builder
	enc := json.NewEncoder(&sb)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(value); err != nil {
		return "", err
	}
	return strings.TrimSuffix(sb.String(), "\n"), nil
}

// Edit is one exact-text replacement as the model sends it.
type Edit struct {
	OldText    any  `json:"oldText"`
	NewText    any  `json:"newText"`
	ReplaceAll bool `json:"replaceAll"`
}

// EditReport is the outcome of one edit. Field order is the order Node wrote.
type EditReport struct {
	Success     bool     `json:"success"`
	Replaced    int      `json:"replaced,omitempty"`
	Line        int      `json:"line,omitempty"`
	Applied     *bool    `json:"applied,omitempty"`
	Error       string   `json:"error,omitempty"`
	Edit        string   `json:"edit,omitempty"`
	NearbyLines []string `json:"nearby_lines,omitempty"`
	Locations   []string `json:"locations,omitempty"`
	Note        string   `json:"note,omitempty"`
}

// EditResult is what ApplyEdits returns: the new content, whether it differs
// from the original (all edits applied) and one report per edit.
type EditResult struct {
	Content  string
	Modified bool
	Report   []EditReport
}

// truncateUnits keeps the first n UTF-16 code units, as JS String.slice does.
func truncateUnits(s string, n int) string {
	units := utf16.Encode([]rune(s))
	if len(units) <= n {
		return s
	}
	return string(utf16.Decode(units[:n]))
}

var nonWord = regexp.MustCompile(`\W+`)

func numberedLine(lines []string, index int) string {
	return fmt.Sprintf("%d: %s", index+1, truncateUnits(lines[index], maxNearbyChars))
}

func wordsOver2(text string) []string {
	var out []string
	for _, w := range nonWord.Split(text, -1) {
		if len(w) > 2 {
			out = append(out, w)
		}
	}
	return out
}

func closestLineIndex(lines []string, oldText string) int {
	first := ""
	for _, l := range strings.Split(oldText, "\n") {
		if t := strings.TrimSpace(l); t != "" {
			first = t
			break
		}
	}
	if first == "" {
		return -1
	}
	for i, l := range lines {
		if strings.TrimSpace(l) == first {
			return i
		}
	}
	for i, l := range lines {
		if strings.Contains(l, first) {
			return i
		}
	}
	wanted := map[string]bool{}
	for _, w := range wordsOver2(first) {
		wanted[w] = true
	}
	best, bestScore := -1, 0
	for i, l := range lines {
		score := 0
		for _, w := range wordsOver2(l) {
			if wanted[w] {
				score++
			}
		}
		if score > bestScore {
			best, bestScore = i, score
		}
	}
	return best
}

func nearbyLines(content, oldText string) []string {
	lines := strings.Split(content, "\n")
	center := closestLineIndex(lines, oldText)
	if center < 0 {
		return nil
	}
	start := max(0, center-maxNearbyLines/2)
	end := min(len(lines), start+maxNearbyLines)
	var shown []string
	for i := start; i < end; i++ {
		shown = append(shown, numberedLine(lines, i))
	}
	return shown
}

func matchLocations(content string, parts []string, separatorLen int) []string {
	lines := strings.Split(content, "\n")
	var locations []string
	offset := 0
	for _, part := range parts[:min(len(parts)-1, maxListedLocation)] {
		offset += len(part)
		locations = append(locations, numberedLine(lines, strings.Count(content[:offset], "\n")))
		offset += separatorLen
	}
	return locations
}

var crlfNormalizer = regexp.MustCompile(`\r?\n`)

func toCRLF(text string) string { return crlfNormalizer.ReplaceAllString(text, "\r\n") }

// matchingTexts lets text written with plain newlines match a CRLF file and
// keeps the file's line endings.
func matchingTexts(content, oldText, newText string) (string, string) {
	if strings.Contains(content, oldText) || !strings.Contains(content, "\r\n") || !strings.Contains(oldText, "\n") {
		return oldText, newText
	}
	return toCRLF(oldText), toCRLF(newText)
}

func editProblem(e Edit) string {
	old, ok := e.OldText.(string)
	if !ok || old == "" {
		return "oldText is required."
	}
	if e.NewText == nil {
		return "newText is required; use an empty string to delete the text."
	}
	if CoerceText(e.NewText) == old {
		return "oldText and newText are the same, so this changes nothing."
	}
	return ""
}

// ApplyEdits applies edits in order, each to the result of the one before. It
// is all or nothing: when any edit cannot apply the original content comes
// back and the report says which edits need correcting.
func ApplyEdits(content string, edits []Edit) EditResult {
	if len(edits) == 0 {
		return EditResult{Content: content, Report: []EditReport{{Error: "edits must list at least one change."}}}
	}
	next := content
	var report []EditReport
	failed := false
	for _, e := range edits {
		if problem := editProblem(e); problem != "" {
			failed = true
			report = append(report, EditReport{Error: problem})
			continue
		}
		old := e.OldText.(string)
		preview := truncateUnits(old, previewChars) + "..."
		oldText, newText := matchingTexts(next, old, CoerceText(e.NewText))
		parts := strings.Split(next, oldText)
		matches := len(parts) - 1
		switch {
		case matches == 0:
			failed = true
			report = append(report, EditReport{Error: "Target text not found.", Edit: preview, NearbyLines: nearbyLines(next, old)})
		case matches > 1 && !e.ReplaceAll:
			failed = true
			report = append(report, EditReport{
				Error:     fmt.Sprintf("Target text matches %d locations. Include more surrounding context or set replace_all: true.", matches),
				Edit:      preview,
				Locations: matchLocations(next, parts, len(oldText)),
			})
		default:
			line := strings.Count(parts[0], "\n") + 1
			next = strings.Join(parts, newText)
			report = append(report, EditReport{Success: true, Replaced: matches, Line: line, Edit: preview})
		}
	}
	if !failed {
		return EditResult{Content: next, Modified: true, Report: report}
	}
	no := false
	for i, r := range report {
		if r.Success {
			report[i] = EditReport{Applied: &no, Edit: r.Edit, Note: "Valid, but not written: another edit in this call failed, and edits apply all or nothing."}
		}
	}
	return EditResult{Content: content, Report: report}
}
