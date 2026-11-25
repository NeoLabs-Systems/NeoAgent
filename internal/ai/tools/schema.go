package tools

import (
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// CompactText collapses whitespace and cuts at a sentence or clause boundary
// when the text is longer than max.
func CompactText(text string, max int) string {
	str := textx.Collapse(text)
	if textx.Len(str) <= max {
		return str
	}
	trimmed := textx.Head(str, max)
	sentenceBreak := textx.LastIndex(trimmed, ". ")
	for _, sep := range []string{"; ", ", "} {
		if i := textx.LastIndex(trimmed, sep); i > sentenceBreak {
			sentenceBreak = i
		}
	}
	if sentenceBreak > 40 {
		return textx.Trim(textx.Head(trimmed, sentenceBreak+1))
	}
	return textx.Trim(trimmed) + "..."
}

func compactProperties(properties map[string]any, includeDescriptions bool) map[string]any {
	compacted := make(map[string]any, len(properties))
	for key, value := range properties {
		compacted[key] = compactSchema(value, includeDescriptions)
	}
	return compacted
}

func compactSchema(schema any, includeDescriptions bool) any {
	object, ok := schema.(map[string]any)
	if !ok {
		return schema
	}
	compact := make(map[string]any, len(object))
	for k, v := range object {
		compact[k] = v
	}
	if description, _ := object["description"].(string); includeDescriptions && description != "" {
		compact["description"] = CompactText(description, 160)
	} else {
		delete(compact, "description")
	}
	if properties, ok := object["properties"].(map[string]any); ok {
		compact["properties"] = compactProperties(properties, includeDescriptions)
	}
	if items, ok := object["items"].(map[string]any); ok {
		compact["items"] = compactSchema(items, includeDescriptions)
	}
	return compact
}

// Telling two similar tools apart is the description's job, so the guidance
// joins it after the trim and always reaches the model.
func describeTool(tool Definition) string {
	parts := []string{CompactText(tool.Description, 320)}
	if len(tool.WhenToUse) > 0 {
		parts = append(parts, fmt.Sprintf("Use for: %s.", strings.Join(tool.WhenToUse, "; ")))
	}
	if len(tool.WhenNotToUse) > 0 {
		parts = append(parts, fmt.Sprintf("Not for: %s.", strings.Join(tool.WhenNotToUse, "; ")))
	}
	return strings.Join(parts, " ")
}

// CompactTool is what the harness hands to a provider adapter: a name, a
// description and parameters. Access, Family and Integration stay for the
// harness and are never serialised by the adapters.
type CompactTool struct {
	Name        string
	Description string
	Parameters  map[string]any
	Access      string
	Family      string
	Integration any
}

// ToLLM is the provider-facing form of the tool.
func (t CompactTool) ToLLM() llm.Tool {
	return llm.Tool{Name: t.Name, Description: t.Description, Parameters: t.Parameters}
}

// Compact is compactToolDefinition: it keeps a tool's name and parameters,
// drops the parameter descriptions unless asked for, and joins the usage
// guidance to the description. It returns false for a definition without a name.
func Compact(tool Definition, includeDescriptions bool) (CompactTool, bool) {
	if strings.TrimSpace(tool.Name) == "" {
		return CompactTool{}, false
	}
	parameters := map[string]any{"type": "object"}
	if tool.Parameters != nil {
		parameters = make(map[string]any, len(tool.Parameters)+1)
		for k, v := range tool.Parameters {
			parameters[k] = v
		}
	}
	parameters["properties"] = map[string]any{}
	compact := CompactTool{Name: tool.Name, Parameters: parameters}
	if access := strings.TrimSpace(tool.Access); access != "" {
		compact.Access = strings.ToLower(access)
	}
	if family := strings.TrimSpace(tool.Family); family != "" {
		compact.Family = family
	}
	if tool.Integration != nil && truthy(tool.Integration) {
		compact.Integration = tool.Integration
	}
	if includeDescriptions {
		compact.Description = describeTool(tool)
	}
	if properties, ok := tool.Parameters["properties"].(map[string]any); ok {
		parameters["properties"] = compactProperties(properties, includeDescriptions)
	}
	return compact, true
}
