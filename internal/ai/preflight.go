package ai

import (
	"net/url"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

var (
	scriptBlock    = regexp.MustCompile(`(?is)<script.*?</script>`)
	styleBlock     = regexp.MustCompile(`(?is)<style.*?</style>`)
	anyTag         = regexp.MustCompile(`<[^>]+>`)
	htmlLikeTag    = regexp.MustCompile(`(?i)<[a-z!/][^>]*>`)
	nbsp           = regexp.MustCompile(`(?i)&nbsp;`)
	ampEntity      = regexp.MustCompile(`(?i)&amp;`)
	ltEntity       = regexp.MustCompile(`(?i)&lt;`)
	gtEntity       = regexp.MustCompile(`(?i)&gt;`)
	urlInText      = regexp.MustCompile(`(?i)https?://[^\s)]+`)
	trailingSpaces = regexp.MustCompile(`[` + textx.SpaceClass + `]+\n`)
)

// clampTrim is clampText of the text-compaction helpers: trimmed, cut with an ellipsis.
func clampTrim(value string, maxLength int) string {
	text := textx.Trim(value)
	if textx.Len(text) <= maxLength {
		return text
	}
	return textx.TrimEnd(textx.Head(text, max(0, maxLength-1))) + "..."
}

// StripHTMLTags reduces markup to its text.
func StripHTMLTags(input string) string {
	input = scriptBlock.ReplaceAllString(input, " ")
	input = styleBlock.ReplaceAllString(input, " ")
	input = anyTag.ReplaceAllString(input, " ")
	input = nbsp.ReplaceAllString(input, " ")
	input = ampEntity.ReplaceAllString(input, "&")
	input = ltEntity.ReplaceAllString(input, "<")
	input = gtEntity.ReplaceAllString(input, ">")
	return textx.Collapse(input)
}

func shortenURLText(input string) string {
	return urlInText.ReplaceAllStringFunc(input, func(match string) string {
		parsed, err := url.Parse(match)
		if err != nil || parsed.Host == "" {
			return match
		}
		path := ""
		if parsed.EscapedPath() != "" && parsed.EscapedPath() != "/" {
			path = clampTrim(parsed.EscapedPath(), 40)
		}
		return parsed.Hostname() + path
	})
}

func dedupeLines(input string, maxLines int) string {
	seen := map[string]bool{}
	var result []string
	for _, raw := range strings.Split(input, "\n") {
		normalized := textx.Collapse(raw)
		if normalized == "" || seen[normalized] {
			continue
		}
		seen[normalized] = true
		result = append(result, textx.Trim(raw))
		if len(result) >= maxLines {
			break
		}
	}
	return strings.Join(result, "\n")
}

// TextPayloadMetrics describe what compaction did to a payload.
type TextPayloadMetrics struct {
	InputChars, OutputChars, ReducedChars int
	Applied                               bool
	Strategies                            []string
}

// CompactTextPayload shrinks a text for a pre-model pass: markup to text, URLs
// to host and path, repeated lines dropped, then clamped. maxLines and maxChars
// default to 30 and 1800.
func CompactTextPayload(input string, maxLines, maxChars int) (string, TextPayloadMetrics) {
	if maxLines == 0 {
		maxLines = 30
	}
	if maxChars == 0 {
		maxChars = 1800
	}
	normalized := input
	strategies := []string{}
	if htmlLikeTag.MatchString(normalized) {
		normalized = StripHTMLTags(normalized)
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
	normalized = trailingSpaces.ReplaceAllString(normalized, "\n")
	normalized = textx.Trim(blankRuns.ReplaceAllString(normalized, "\n\n"))
	final := clampTrim(normalized, maxChars)
	if textx.Len(final) < textx.Len(normalized) {
		strategies = append(strategies, "length_clamp")
	}
	return final, TextPayloadMetrics{
		InputChars:   textx.Len(input),
		OutputChars:  textx.Len(final),
		ReducedChars: max(0, textx.Len(input)-textx.Len(final)),
		Applied:      final != input,
		Strategies:   strategies,
	}
}
