package memory

import (
	"net/url"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// compactTextPayload shrinks a document to the text a summary should hold:
// markup stripped, long URLs shortened, repeated lines dropped, length clamped.
// It mirrors services/ai/preModelCompaction.js, which the memory code calls.

var (
	scriptBlock = regexp.MustCompile(`(?i)<script[\s\S]*?</script>`)
	styleBlock  = regexp.MustCompile(`(?i)<style[\s\S]*?</style>`)
	htmlTag     = regexp.MustCompile(`<[^>]+>`)
	htmlStart   = regexp.MustCompile(`(?i)<[a-z!/][^>]*>`)
	entityNbsp  = regexp.MustCompile(`(?i)&nbsp;`)
	entityAmp   = regexp.MustCompile(`(?i)&amp;`)
	entityLt    = regexp.MustCompile(`(?i)&lt;`)
	entityGt    = regexp.MustCompile(`(?i)&gt;`)
	linkInText  = regexp.MustCompile(`(?i)https?://[^` + jsx.SpaceClass + `)]+`)
	spaceBefore = regexp.MustCompile(`[` + jsx.SpaceClass + `]+\n`)
	blankLines  = regexp.MustCompile(`\n{3,}`)
)

func clampText(value string, maxLength int) string {
	text := jsx.Trim(value)
	if jsx.Len(text) <= maxLength {
		return text
	}
	return jsx.TrimEnd(jsx.Head(text, max(0, maxLength-1))) + "..."
}

func stripHTMLTags(input string) string {
	s := scriptBlock.ReplaceAllString(input, " ")
	s = styleBlock.ReplaceAllString(s, " ")
	s = htmlTag.ReplaceAllString(s, " ")
	s = entityNbsp.ReplaceAllString(s, " ")
	s = entityAmp.ReplaceAllString(s, "&")
	s = entityLt.ReplaceAllString(s, "<")
	s = entityGt.ReplaceAllString(s, ">")
	return jsx.Collapse(s)
}

func shortenURLText(input string) string {
	return linkInText.ReplaceAllStringFunc(input, func(match string) string {
		u, err := url.Parse(match)
		if err != nil || u.Host == "" {
			return match
		}
		host := strings.ToLower(u.Hostname())
		if strings.Contains(host, ":") {
			host = "[" + host + "]"
		}
		path := ""
		if p := u.EscapedPath(); p != "" && p != "/" {
			path = clampText(p, 40)
		}
		return host + path
	})
}

func dedupeLines(input string, maxLines int) string {
	seen := map[string]bool{}
	var result []string
	for _, rawLine := range strings.Split(input, "\n") {
		normalized := jsx.Collapse(rawLine)
		if normalized == "" || seen[normalized] {
			continue
		}
		seen[normalized] = true
		result = append(result, jsx.Trim(rawLine))
		if len(result) >= maxLines {
			break
		}
	}
	return strings.Join(result, "\n")
}

// CompactedText is the result of compactTextPayload.
type CompactedText struct {
	Text    string
	Metrics *jsx.Obj
}

func compactTextPayload(input string, maxChars, maxLines int) CompactedText {
	normalized := input
	strategies := []string{}

	if htmlStart.MatchString(normalized) {
		normalized = stripHTMLTags(normalized)
		strategies = append(strategies, "html_to_text")
	}
	if shortened := shortenURLText(normalized); shortened != normalized {
		normalized = shortened
		strategies = append(strategies, "url_shortening")
	}
	if deduped := dedupeLines(normalized, maxLines); deduped != "" && deduped != normalized {
		normalized = deduped
		strategies = append(strategies, "line_deduplication")
	}

	normalized = spaceBefore.ReplaceAllString(normalized, "\n")
	normalized = jsx.Trim(blankLines.ReplaceAllString(normalized, "\n\n"))
	finalText := clampText(normalized, maxChars)
	if jsx.Len(finalText) < jsx.Len(normalized) {
		strategies = append(strategies, "length_clamp")
	}
	inputChars, outputChars := jsx.Len(input), jsx.Len(finalText)
	return CompactedText{
		Text: finalText,
		Metrics: jsx.O(
			"inputChars", inputChars,
			"outputChars", outputChars,
			"reducedChars", max(0, inputChars-outputChars),
			"applied", finalText != input,
			"strategies", strategies,
		),
	}
}
