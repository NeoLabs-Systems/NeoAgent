package ai

import (
	"encoding/json"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// InterimKinds are the kinds of update the agent can send while it works.
var InterimKinds = []string{"ack", "progress", "question", "blocker"}

// NormalizeInterimKind maps anything unknown to "progress".
func NormalizeInterimKind(value any) string {
	kind := strings.ToLower(textx.Trim(dyn.Str(value)))
	for _, k := range InterimKinds {
		if k == kind {
			return kind
		}
	}
	return "progress"
}

// InterimMetadata is what an interim assistant message stores as its metadata.
func InterimMetadata(kind string, expectsReply bool) dyn.Ordered {
	return dyn.Ordered{
		{Key: "interim", Value: true},
		{Key: "interim_kind", Value: NormalizeInterimKind(kind)},
		{Key: "expects_reply", Value: expectsReply},
	}
}

// ParsedInterim is stored interim metadata, read back.
type ParsedInterim struct {
	Interim      bool
	Kind         string
	ExpectsReply bool
}

// ParseInterimMetadata reads metadata stored as JSON text or as a value.
func ParseInterimMetadata(value any) ParsedInterim {
	if !dyn.Truthy(value) {
		return ParsedInterim{}
	}
	if text, ok := value.(string); ok {
		var parsed any
		if err := json.Unmarshal([]byte(text), &parsed); err != nil {
			return ParsedInterim{}
		}
		value = parsed
	}
	m := dyn.Obj(value)
	if m == nil {
		return ParsedInterim{}
	}
	return ParsedInterim{
		Interim:      m["interim"] == true,
		Kind:         NormalizeInterimKind(or(m["interim_kind"], m["kind"])),
		ExpectsReply: m["expects_reply"] == true || m["expectsReply"] == true,
	}
}

// IsInterimAssistantMetadata reports whether stored metadata marks an interim message.
func IsInterimAssistantMetadata(value any) bool { return ParseInterimMetadata(value).Interim }

// InterimSignature identifies an update so the same one is not sent twice.
func InterimSignature(content, kind string, expectsReply bool, platform string) string {
	return dyn.Stringify(dyn.Ordered{
		{Key: "content", Value: textx.Collapse(content)},
		{Key: "kind", Value: NormalizeInterimKind(kind)},
		{Key: "expectsReply", Value: expectsReply},
		{Key: "platform", Value: strings.ToLower(textx.Trim(platform))},
	})
}
