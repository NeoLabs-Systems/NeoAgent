package ai

import (
	"regexp"
	"slices"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

var (
	hanChar      = regexp.MustCompile(`\p{Han}`)
	latinChar    = regexp.MustCompile(`\p{Latin}`)
	letterChar   = regexp.MustCompile(`\p{L}`)
	hanRun       = regexp.MustCompile(`[\p{Han}\x{3000}-\x{303F}]+`)
	hanBetween   = regexp.MustCompile(`([\p{L}\p{N}])[\p{Han}\x{3000}-\x{303F}]+([\p{L}\p{N}])`)
	codeSpan     = regexp.MustCompile("(?s)(```.*?```|`[^`\\n]+`)")
	multiSpace   = regexp.MustCompile(`[ \t]{2,}`)
	spaceBefore  = regexp.MustCompile(`[ \t]+\n`)
	spaceAfter   = regexp.MustCompile(`\n[ \t]+`)
	spaceInFront = regexp.MustCompile(`[ \t]+([,.;:!?)\]}])`)
	spaceInside  = regexp.MustCompile(`([(\[{])[` + textx.SpaceClass + `]+`)

	thinkAnyTag     = regexp.MustCompile(`(?i)</?think(?:ing)?>`)
	thinkBlock      = regexp.MustCompile(`(?is)[ \t]*<think>.*?</think>[ \t]*`)
	thinkingBlock   = regexp.MustCompile(`(?is)[ \t]*<thinking>.*?</thinking>[ \t]*`)
	thinkLeadingEnd = regexp.MustCompile(`(?is)^.*</think(?:ing)?>[ \t]*`)
	thinkOpenTail   = regexp.MustCompile(`(?is)[ \t]*<think(?:ing)?>.*$`)
	leadingNewlines = regexp.MustCompile(`^\n+`)
	trailingNewline = regexp.MustCompile(`\n+$`)

	rawToolMarkup = regexp.MustCompile(`(?:^|\n)\s*(?:assistant\s+to=\S+|</?(?:tool_call|function_call|tool_use|invoke)\b|<function=|\[TOOL_CALLS\]|<\|tool)|</\w+:parameter>`)
	rawToolJSON   = regexp.MustCompile("^\\s*(?:```(?:json)?\\s*)?\\{\\s*\"(?:name|tool|tool_name|function)\"\\s*:\\s*\"[\\w.-]+\"\\s*,\\s*\"(?:arguments|parameters|args|input)\"\\s*:")
	rawToolStart  = regexp.MustCompile("^\\s*(?:```(?:json)?\\s*)?[{<]")
)

// SanitizeOptions say which model wrote the text. HanModels lists the models
// whose stray Chinese characters are removed (NEOAGENT_INCIDENTAL_HAN_SANITIZER_MODELS);
// empty means the MiniMax models.
type SanitizeOptions struct {
	Model     string
	HanModels []string
}

func (o SanitizeOptions) appliesHanSanitizer() bool {
	model := strings.ToLower(textx.Trim(o.Model))
	if model == "" {
		return false
	}
	var configured []string
	for _, name := range o.HanModels {
		if name = strings.ToLower(textx.Trim(name)); name != "" {
			configured = append(configured, name)
		}
	}
	if len(configured) == 0 {
		return strings.Contains(model, "minimax")
	}
	return slices.Contains(configured, model)
}

func (o SanitizeOptions) shouldStripIncidentalHan(text string) bool {
	if !o.appliesHanSanitizer() {
		return false
	}
	han := len(hanChar.FindAllStringIndex(text, -1))
	if han == 0 || han > 24 {
		return false
	}
	if len(latinChar.FindAllStringIndex(text, -1)) < 20 {
		return false
	}
	letters := len(letterChar.FindAllStringIndex(text, -1))
	return !(letters > 0 && float64(han)/float64(letters) > 0.18)
}

func sanitizePlainText(text string) string {
	text = hanBetween.ReplaceAllString(text, "${1} ${2}")
	text = hanRun.ReplaceAllString(text, "")
	text = multiSpace.ReplaceAllString(text, " ")
	text = spaceBefore.ReplaceAllString(text, "\n")
	text = spaceAfter.ReplaceAllString(text, "\n")
	text = spaceInFront.ReplaceAllString(text, "${1}")
	return spaceInside.ReplaceAllString(text, "${1}")
}

func sanitizeMarkdownAware(text string) string {
	var out strings.Builder
	last := 0
	for _, loc := range codeSpan.FindAllStringIndex(text, -1) {
		out.WriteString(sanitizePlainText(text[last:loc[0]]))
		out.WriteString(text[loc[0]:loc[1]])
		last = loc[1]
	}
	out.WriteString(sanitizePlainText(text[last:]))
	return out.String()
}

// StripThoughtBlocks removes reasoning written into the reply as tags. A stream
// cut short leaves a block unclosed, and some chat templates drop the opening
// tag; either way everything on the thought side of the tag stays out of the
// reply.
func StripThoughtBlocks(text string) string {
	if !thinkAnyTag.MatchString(text) {
		return text
	}
	text = thinkBlock.ReplaceAllString(text, "")
	text = thinkingBlock.ReplaceAllString(text, "")
	text = thinkLeadingEnd.ReplaceAllString(text, "")
	text = thinkOpenTail.ReplaceAllString(text, "")
	text = blankRuns.ReplaceAllString(text, "\n\n")
	text = leadingNewlines.ReplaceAllString(text, "")
	return trailingNewline.ReplaceAllString(text, "")
}

// SanitizeModelOutput cleans a model's reply of reasoning tags, inline tool
// call markup and (for the configured models) incidental Chinese characters.
func SanitizeModelOutput(text string, options SanitizeOptions) string {
	if text == "" {
		return text
	}
	sanitized := StripThoughtBlocks(text)
	if options.appliesHanSanitizer() && (strings.Contains(sanitized, "<invoke") || strings.Contains(sanitized, ":tool_call")) {
		sanitized = SanitizeStreamingToolCallText(sanitized)
	}
	if !options.shouldStripIncidentalHan(sanitized) {
		return sanitized
	}
	return sanitizeMarkdownAware(sanitized)
}

// IsRawToolCall reports a tool call a model wrote out as text instead of
// making it. It must never reach a person as if it were the answer.
func IsRawToolCall(text string) bool {
	return rawToolMarkup.MatchString(text) || rawToolJSON.MatchString(text)
}

// MayBeRawToolCall is for streaming, where only the start is known and a tool
// call starts like one of these.
func MayBeRawToolCall(text string) bool {
	return rawToolStart.MatchString(text) || IsRawToolCall(text)
}
