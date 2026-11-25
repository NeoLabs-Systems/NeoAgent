package agentimport

import (
	"regexp"
	"strings"
)

// NeoAgent keeps memories short; longer entries are split into pieces.
const maxFactChars = 150

var (
	wsRun        = regexp.MustCompile(ws + `+`)
	boldSpan     = regexp.MustCompile(`\*\*(.+?)\*\*`)
	sectionSplit = regexp.MustCompile(`(?m)\n?^§$\n?`)
	headingLine  = regexp.MustCompile(`^#{1,6}\s+(.*)$`)
	ruleLine     = regexp.MustCompile(`^(-{3,}|\*{3,})$`)
	bulletLine   = regexp.MustCompile(`^(?:[-*+]|\d+[.)])\s+(.*)$`)
)

func init() {
	// Go's \s is ASCII only; JavaScript's covers the Unicode spaces.
	headingLine = regexp.MustCompile(`^#{1,6}` + ws + `+(.*)$`)
	bulletLine = regexp.MustCompile(`^(?:[-*+]|\d+[.)])` + ws + `+(.*)$`)
}

// memoryEntry is one entry of a Markdown memory file with the heading it sat
// under.
type memoryEntry struct {
	Text    string
	Heading string
}

// collapse removes bold markers and folds whitespace runs.
func collapse(text string) string {
	return trim(wsRun.ReplaceAllString(boldSpan.ReplaceAllString(text, "$1"), " "))
}

// splitMemoryEntries turns Markdown memory into entries: Hermes separates
// entries with a line holding only "§"; OpenClaw writes bullets and paragraphs
// under headings.
func splitMemoryEntries(source string) []memoryEntry {
	if strings.Contains("\n"+source+"\n", "\n§\n") {
		var out []memoryEntry
		for _, part := range sectionSplit.Split(source, -1) {
			if part = trim(part); part != "" {
				out = append(out, memoryEntry{Text: collapse(part)})
			}
		}
		return out
	}

	var entries []memoryEntry
	heading := ""
	var paragraph []string
	flush := func() {
		if joined := collapse(strings.Join(paragraph, " ")); joined != "" {
			entries = append(entries, memoryEntry{Text: joined, Heading: heading})
		}
		paragraph = nil
	}
	for _, raw := range strings.Split(source, "\n") {
		line := trim(raw)
		if m := headingLine.FindStringSubmatch(line); m != nil {
			flush()
			heading = trim(m[1])
			continue
		}
		if line == "" || ruleLine.MatchString(line) {
			flush()
			continue
		}
		if m := bulletLine.FindStringSubmatch(line); m != nil {
			flush()
			paragraph = append(paragraph, m[1])
			flush()
			continue
		}
		paragraph = append(paragraph, line)
	}
	flush()

	kept := entries[:0]
	for _, e := range entries {
		if !isPlaceholder(e.Text) {
			kept = append(kept, e)
		}
	}
	return kept
}

var (
	placeholderLabel = regexp.MustCompile(`^[^:]{1,40}:` + ws + `*$`)
	placeholderHint  = regexp.MustCompile(`^_?\(.*\)_?$`)
	markupChars      = strings.NewReplacer("*", "", "_", "", "`", "")
)

// isPlaceholder spots template lines left untouched: "- **Name:**" with nothing
// after it, or "(optional)" hints from an agent's starter files.
func isPlaceholder(text string) bool {
	value := trim(markupChars.Replace(text))
	return value == "" || placeholderLabel.MatchString(value) || placeholderHint.MatchString(value)
}

var headingCategories = []struct {
	pattern  *regexp.Regexp
	category string
}{
	{regexp.MustCompile(`(?i)\b(people|family|friends?|contacts?|relationships?)\b`), "contacts"},
	{regexp.MustCompile(`(?i)\b(prefers?|preferences?|likes?|tastes?|style|habits?)\b`), "preferences"},
	{regexp.MustCompile(`(?i)\b(projects?|work|job|career|goals?)\b`), "projects"},
	{regexp.MustCompile(`(?i)\b(events?|dates?|birthdays?|appointments?|schedule)\b`), "events"},
	{regexp.MustCompile(`(?i)\b(tasks?|todos?|to-dos?)\b`), "tasks"},
	{regexp.MustCompile(`(?i)\b(how to|procedures?|workflows?|process|lessons?|steps)\b`), "procedural"},
	{regexp.MustCompile(`(?i)\b(about|identity|profile|bio)\b`), "identity"},
}

func categoryFor(heading, fallback string) string {
	for _, h := range headingCategories {
		if h.pattern.MatchString(heading) {
			return h.category
		}
	}
	return fallback
}

var (
	factLead   = regexp.MustCompile(`^([^:.!?]{2,32}):` + ws + `+`)
	sentenceRe = regexp.MustCompile(`[^.!?;]+[.!?;]*` + ws + `*`)
)

// toShortFacts turns one entry into memories that fit maxFactChars. Sentences
// are packed together; a short lead like "Home automation:" is repeated on
// each piece so every memory still says what it is about.
func toShortFacts(text string) []string {
	value := collapse(text)
	if jsLen(value) <= maxFactChars {
		if value == "" {
			return nil
		}
		return []string{value}
	}

	lead, body := "", value
	if m := factLead.FindString(value); m != "" {
		lead = factLead.FindStringSubmatch(value)[1] + ": "
		body = value[len(m):]
	}
	room := maxFactChars - jsLen(lead)
	var pieces []string
	current := ""
	sentences := sentenceRe.FindAllString(body, -1)
	if sentences == nil {
		sentences = []string{body}
	}
	for _, sentence := range sentences {
		for _, part := range wrapWords(trim(sentence), room) {
			candidate := part
			if current != "" {
				candidate = current + " " + part
			}
			if jsLen(candidate) <= room {
				current = candidate
			} else {
				if current != "" {
					pieces = append(pieces, current)
				}
				current = part
			}
		}
	}
	if current != "" {
		pieces = append(pieces, current)
	}
	for i, piece := range pieces {
		pieces[i] = lead + piece
	}
	return pieces
}

func wrapWords(text string, max int) []string {
	if jsLen(text) <= max {
		return []string{text}
	}
	var parts []string
	current := ""
	for _, word := range wsRun.Split(text, -1) {
		candidate := word
		if current != "" {
			candidate = current + " " + word
		}
		if jsLen(candidate) <= max {
			current = candidate
		} else {
			if current != "" {
				parts = append(parts, current)
			}
			current = jsSlice(word, max)
		}
	}
	if current != "" {
		parts = append(parts, current)
	}
	return parts
}
