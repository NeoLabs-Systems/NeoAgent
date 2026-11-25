package messaging

import (
	"bytes"
	"encoding/json"
	"regexp"
	"strings"
	"unicode/utf16"
)

// Platform text rules: how an outgoing reply is cleaned for a chat, cut to a
// platform's message limit, and described to the model.

type formattingProfile struct {
	maxMessageLength int
	markdownDocument bool
	// keepTokens matches <...> tokens the platform renders (Discord mentions,
	// emoji, timestamps) that raw-HTML stripping must leave alone.
	keepTokens    *regexp.Regexp
	extraGuidance []string
}

// discordTokenRe is a Discord user, role, or channel mention, a custom emoji, a
// timestamp, a slash-command mention, or an embed-suppressed link.
var discordTokenRe = regexp.MustCompile(`^<(?:@[!&]?\d+|#\d+|a?:\w+:\d+|t:-?\d+(?::[tTdDfFR])?|/[\w -]+:\d+|https?://[^\s>]+)>$`)

var platformFormatting = map[string]formattingProfile{
	"whatsapp": {extraGuidance: []string{"WhatsApp does not render Markdown links like [text](link). Write the bare URL instead."}},
	"telegram": {maxMessageLength: 4096},
	"discord": {maxMessageLength: 2000, keepTokens: discordTokenRe, extraGuidance: []string{
		"To mention someone on Discord, write <@user_id> with an id the platform gave you (sender_id, or the <@id> next to a participant's name). Never guess or reuse another person's id; if you have no id for someone, write their name without an @.",
	}},
	// A GitHub comment is a rendered Markdown document, not a chat bubble.
	"github": {markdownDocument: true},
}

func formattingProfileFor(platform string) formattingProfile {
	return platformFormatting[strings.ToLower(jsTrim(platform))]
}

// BuildPlatformFormattingGuide is the reply formatting guide in the prompt.
func BuildPlatformFormattingGuide(platform string, intro bool) string {
	profile := formattingProfileFor(platform)
	var lines []string
	if profile.markdownDocument {
		lines = []string{
			"Your reply is one public comment in GitHub-flavored Markdown. Every send_message in this run overwrites that same comment, so only the last message you send stays posted.",
			"Make that last message the complete answer on its own. Never end with a short follow-up, recap pointer, or sign-off, because it would replace the answer.",
			"Fenced code blocks, lists, and links render. Use them where they help the reader.",
			"Skip greetings and sign-offs; lead with the answer or the change you made.",
		}
	} else {
		lines = append([]string{
			"Prefer short paragraphs or multi-line chat bursts over document structure.",
			"Use simple single-level lists only when they genuinely improve clarity.",
			"Avoid tables, raw HTML, and formal report formatting in chat replies.",
			"A blank line may be delivered as a separate message bubble, so use one only for an intentional conversational beat. A fenced code block always stays in one message, blank lines inside it included, so never split formatted content across messages.",
			"The runtime will adapt the final text to the destination platform.",
		}, profile.extraGuidance...)
	}
	body := "- " + strings.Join(lines, "\n- ")
	if !intro {
		return body
	}
	return "Reply formatting guide:\n" + body
}

// SendMessageFormattingReference is the formatting note in send_message's
// description.
func SendMessageFormattingReference() string {
	return "Use one plain chat-style reply unless intentional bubble breaks improve it. " +
		"The runtime adapts final formatting for the destination platform. " +
		"For WhatsApp, media attachments still use media_path."
}

// JavaScript's \s: the Unicode space separators, line terminators, BOM and
// vertical tab, which Go's \s leaves out.
const jsSpaceClass = `\t\n\v\f\r \x{00a0}\x{1680}\x{2000}-\x{200a}\x{2028}\x{2029}\x{202f}\x{205f}\x{3000}\x{feff}`

const (
	s      = `[` + jsSpaceClass + `]`
	notNL  = `[^\n\r\x{2028}\x{2029}]` // JavaScript's "."
	anyRun = `(?s:.)`
)

var (
	rawHTMLRe       = regexp.MustCompile(`</?[^>]+>`)
	trailingSpaceRe = regexp.MustCompile(`[ \t]+\n`)
	blankRunRe      = regexp.MustCompile(`\n{3,}`)
	noResponseRe    = regexp.MustCompile(`(?i)\[NO RESPONSE\]`)
	fenceBlockRe    = regexp.MustCompile("```([^\\n`]*)\\n?(" + anyRun + `*?)` + "```")
	headingRe       = regexp.MustCompile(`(?m)^#{1,6}` + s + `+`)
	quoteRe         = regexp.MustCompile(`(?m)^>` + s + `?`)
	bulletRe        = regexp.MustCompile(`(?m)^` + s + `*[-*+]` + s + `+`)
	numberedRe      = regexp.MustCompile(`(?m)^` + s + `*\d+\.` + s + `+`)
	tableRuleRe     = regexp.MustCompile(`(?m)^` + s + `*\|?(?:` + s + `*:?-+:?` + s + `*\|)+` + s + `*$`)
	tableRowRe      = regexp.MustCompile(`(?m)^(` + notNL + `*\|` + notNL + `*)$`)
	boldRe          = regexp.MustCompile(`\*\*(` + notNL + `*?)\*\*`)
	underlineRe     = regexp.MustCompile(`__(` + notNL + `*?)__`)
	literalNewline  = regexp.MustCompile(`[ \t]*(\\n|/n)[ \t]*`)
)

func collapseTableRow(line string) string {
	var cells []string
	for _, cell := range strings.Split(line, "|") {
		if cell = jsTrim(cell); cell != "" {
			cells = append(cells, cell)
		}
	}
	return strings.Join(cells, " - ")
}

func normalizeVisualMarkdown(text string) string {
	text = fenceBlockRe.ReplaceAllStringFunc(text, func(m string) string {
		return "\n" + jsTrim(fenceBlockRe.FindStringSubmatch(m)[2]) + "\n"
	})
	text = headingRe.ReplaceAllString(text, "")
	text = quoteRe.ReplaceAllString(text, "")
	text = bulletRe.ReplaceAllString(text, "- ")
	text = numberedRe.ReplaceAllString(text, "- ")
	text = tableRuleRe.ReplaceAllString(text, "")
	text = tableRowRe.ReplaceAllStringFunc(text, collapseTableRow)
	text = boldRe.ReplaceAllString(text, "*$1*")
	return underlineRe.ReplaceAllString(text, "_${1}_")
}

// literalNewlinesToBreaks turns a typed "\n" or "/n" (not "/nope") into a line
// break, with the spaces around it.
func literalNewlinesToBreaks(text string) string {
	var out strings.Builder
	last := 0
	for _, m := range literalNewline.FindAllStringSubmatchIndex(text, -1) {
		marker := text[m[2]:m[3]]
		if marker == "/n" && m[3] < len(text) {
			if next := text[m[3]]; next == '_' || next >= '0' && next <= '9' || next >= 'a' && next <= 'z' || next >= 'A' && next <= 'Z' {
				continue
			}
		}
		out.WriteString(text[last:m[0]])
		out.WriteByte('\n')
		last = m[1]
	}
	out.WriteString(text[last:])
	return out.String()
}

func adaptWhatsAppFormatting(text string) string {
	text = literalNewlinesToBreaks(normalizeVisualMarkdown(text))
	text = trailingSpaceRe.ReplaceAllString(text, "\n")
	text = blankRunRe.ReplaceAllString(text, "\n\n")
	return jsTrim(text)
}

// coerceMessageContent is what the model's or a client's content becomes as
// text: strings as they are, objects by their text-like member, anything else
// as JSON.
func coerceMessageContent(content any) string {
	switch v := content.(type) {
	case nil:
		return ""
	case string:
		return v
	case bool:
		return jsStringify(v)
	case float64:
		return jsNumber(v)
	case map[string]any:
		for _, key := range []string{"text", "content", "message", "summary"} {
			if s, ok := v[key].(string); ok && jsTrim(s) != "" {
				return s
			}
		}
		if result := v["result"]; result != nil {
			return coerceMessageContent(result)
		}
	}
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(content); err != nil {
		return ""
	}
	return strings.TrimRight(buf.String(), "\n")
}

// NormalizeOutgoingMessage cleans a reply for a platform: line endings, raw
// HTML (kept where the platform renders Markdown), blank-line runs, and the
// WhatsApp dialect. stripNoResponse removes the [NO RESPONSE] marker.
func NormalizeOutgoingMessage(platform string, content any, stripNoResponse bool) string {
	text := coerceMessageContent(content)
	if stripNoResponse {
		text = noResponseRe.ReplaceAllString(text, "")
	}
	text = strings.ReplaceAll(text, "\r\n", "\n")
	// GitHub sanitizes HTML itself, and stripping tags here would eat code such
	// as `Array<string>` from the comment.
	if profile := formattingProfileFor(platform); !profile.markdownDocument {
		text = rawHTMLRe.ReplaceAllStringFunc(text, func(tag string) string {
			if profile.keepTokens != nil && profile.keepTokens.MatchString(tag) {
				return tag
			}
			return ""
		})
	}
	text = trailingSpaceRe.ReplaceAllString(text, "\n")
	text = blankRunRe.ReplaceAllString(text, "\n\n")
	text = jsTrim(text)
	if strings.ToLower(jsTrim(platform)) == "whatsapp" {
		text = adaptWhatsAppFormatting(text)
	}
	return text
}

// utf16Len is JavaScript's string length.
func utf16Len(s string) int {
	n := 0
	for _, r := range s {
		n++
		if r > 0xFFFF {
			n++
		}
	}
	return n
}

// cutToLength cuts text into pieces of at most limit UTF-16 units, never in the
// middle of a code point.
func cutToLength(text string, limit int) []string {
	var parts []string
	var current strings.Builder
	size := 0
	for _, r := range text {
		width := len(utf16.Encode([]rune{r}))
		if size+width > limit {
			parts = append(parts, current.String())
			current.Reset()
			size = 0
		}
		current.WriteRune(r)
		size += width
	}
	if current.Len() > 0 {
		parts = append(parts, current.String())
	}
	return parts
}

func packToLength(text string, limit int, separators []string) []string {
	if utf16Len(text) <= limit {
		return []string{text}
	}
	if len(separators) == 0 {
		return cutToLength(text, limit)
	}
	separator, finer := separators[0], separators[1:]
	var parts []string
	current := ""
	for _, piece := range strings.Split(text, separator) {
		joined := piece
		if current != "" {
			joined = current + separator + piece
		}
		if utf16Len(joined) <= limit {
			current = joined
			continue
		}
		if current != "" {
			parts = append(parts, current)
		}
		pieceParts := packToLength(piece, limit, finer)
		current = pieceParts[len(pieceParts)-1]
		parts = append(parts, pieceParts[:len(pieceParts)-1]...)
	}
	if current != "" {
		parts = append(parts, current)
	}
	return parts
}

// SplitToMessageLimit is the messages a text has to go out as on a platform
// that caps message length: as few as fit, broken at the largest boundary that
// still fits (paragraph, then line, then word).
func SplitToMessageLimit(platform, text string) []string {
	limit := formattingProfileFor(platform).maxMessageLength
	if limit == 0 || utf16Len(text) <= limit {
		return []string{text}
	}
	var out []string
	for _, part := range packToLength(text, limit, []string{"\n\n", "\n", " "}) {
		if part = jsTrim(part); part != "" {
			out = append(out, part)
		}
	}
	return out
}

var paragraphBreak = regexp.MustCompile(`\n{2,}`)

// SplitOutgoingMessage is the chat bubbles a reply is delivered as: one per
// paragraph, or one document on a platform that renders Markdown. A fenced code
// block stays in one bubble even when it holds blank lines.
func SplitOutgoingMessage(platform string, content any) []string {
	normalized := NormalizeOutgoingMessage(platform, content, false)
	if normalized == "" {
		return nil
	}
	if formattingProfileFor(platform).markdownDocument {
		return []string{normalized}
	}
	var chunks []string
	openFence := false
	for _, chunk := range paragraphBreak.Split(normalized, -1) {
		if openFence {
			chunks[len(chunks)-1] += "\n\n" + chunk
		} else if chunk = jsTrim(chunk); chunk != "" {
			chunks = append(chunks, chunk)
		} else {
			continue
		}
		if strings.Count(chunk, "```")%2 == 1 {
			openFence = !openFence
		}
	}
	for i := range chunks {
		chunks[i] = jsTrim(chunks[i])
	}
	if len(chunks) == 0 {
		return []string{normalized}
	}
	return chunks
}
