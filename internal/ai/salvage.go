package ai

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"regexp"
	"slices"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Some models write a tool call out as text (<invoke name="...">) instead of
// making it. These helpers recover the call, or hide the markup from the reply.

var (
	invokeOpen         = regexp.MustCompile(`(?:[A-Za-z0-9_.-]+:tool_call\s*)?<invoke\s+name="([^"]+)">`)
	paramOpen          = regexp.MustCompile(`<parameter\s+name="([^"]+)">`)
	paramClosed        = regexp.MustCompile(`(?s)<parameter\s+name="([^"]+)">(.*?)</parameter>`)
	toolWrapper        = regexp.MustCompile(`</?[A-Za-z0-9_.-]+:tool_call>`)
	completeInlineCall = regexp.MustCompile(`(?s)(?:[A-Za-z0-9_.-]+:tool_call\s*)?<invoke\s+name="[^"]+">.*?</invoke>`)
	trailingToolCall   = regexp.MustCompile(`(?:^|\s)[A-Za-z0-9_.-]+:tool_call\s*$`)
	blankRuns          = regexp.MustCompile(`\n{3,}`)
)

const invokeClose = "</invoke>"

func trimLooseControlText(text string) string {
	text = toolWrapper.ReplaceAllString(text, "")
	text = trailingToolCall.ReplaceAllString(text, "")
	return textx.Trim(text)
}

// SanitizeStreamingToolCallText hides complete and half-written inline tool
// calls from text that is being streamed to a person.
func SanitizeStreamingToolCallText(text string) string {
	visible := completeInlineCall.ReplaceAllString(text, "")
	visible = toolWrapper.ReplaceAllString(visible, "")
	partialStart := max(strings.LastIndex(visible, "<invoke"), strings.LastIndex(visible, ":tool_call"))
	if partialStart >= 0 && !strings.Contains(visible[partialStart:], invokeClose) {
		visible = visible[:partialStart]
	}
	return blankRuns.ReplaceAllString(trimLooseControlText(visible), "\n\n")
}

type paramMarker struct {
	name                  string
	valueStart, openIndex int
}

func parseParameterMap(body string) dyn.Ordered {
	var args dyn.Ordered
	closed := paramClosed.FindAllStringSubmatch(body, -1)
	if len(closed) > 0 {
		for _, m := range closed {
			args = args.Set(m[1], textx.Trim(m[2]))
		}
		return args
	}
	var markers []paramMarker
	for _, loc := range paramOpen.FindAllStringSubmatchIndex(body, -1) {
		markers = append(markers, paramMarker{name: body[loc[2]:loc[3]], valueStart: loc[1], openIndex: loc[0]})
	}
	for i, current := range markers {
		end := len(body)
		if i+1 < len(markers) {
			end = markers[i+1].openIndex
		}
		args = args.Set(current.name, textx.Trim(body[current.valueStart:end]))
	}
	return args
}

// SalvageTextToolCalls pulls tool calls out of reply text. Calls to tools that
// are not in the offered list stay in the text. The returned content has the
// recovered calls and loose control markup removed.
func SalvageTextToolCalls(content string, tools []llm.Tool) (string, []llm.ToolCall) {
	if !strings.Contains(content, "<invoke") {
		return content, nil
	}
	var allowed []string
	for _, tool := range tools {
		if tool.Name != "" {
			allowed = append(allowed, tool.Name)
		}
	}
	openings := invokeOpen.FindAllStringSubmatchIndex(content, -1)
	if len(openings) == 0 {
		return content, nil
	}
	var cleaned strings.Builder
	var calls []llm.ToolCall
	cursor := 0
	for i, loc := range openings {
		searchEnd := len(content)
		if i+1 < len(openings) {
			searchEnd = openings[i+1][0]
		}
		bodyStart := loc[1]
		blockEnd, bodyEnd := searchEnd, searchEnd
		if closeAt := strings.Index(content[bodyStart:], invokeClose); closeAt >= 0 && bodyStart+closeAt < searchEnd {
			bodyEnd = bodyStart + closeAt
			blockEnd = bodyEnd + len(invokeClose)
		}
		cleaned.WriteString(content[cursor:loc[0]])
		cursor = blockEnd
		name := content[loc[2]:loc[3]]
		if len(allowed) > 0 && !slices.Contains(allowed, name) {
			cleaned.WriteString(content[loc[0]:blockEnd])
			continue
		}
		arguments, _ := json.Marshal(parseParameterMap(content[bodyStart:bodyEnd]))
		calls = append(calls, llm.ToolCall{
			ID:       "salvaged_" + newUUID(),
			Type:     "function",
			Function: llm.FunctionCall{Name: name, Arguments: string(arguments)},
		})
	}
	cleaned.WriteString(content[cursor:])
	return trimLooseControlText(blankRuns.ReplaceAllString(cleaned.String(), "\n\n")), calls
}

func newUUID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err)
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}
