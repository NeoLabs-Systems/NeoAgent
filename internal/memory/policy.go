package memory

import (
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// MaxMemoryChars is the longest a memory may be: one short fact. Longer text
// is source material, not memory.
const MaxMemoryChars = 150

// StorageDecision says whether a text may be stored as a memory.
type StorageDecision struct {
	Allow      bool
	Normalized string
	Reason     string
}

// NormalizeMemoryText trims a text and unifies its line breaks.
func NormalizeMemoryText(content string) string {
	return jsx.Trim(strings.ReplaceAll(content, "\r\n", "\n"))
}

// MemoryStorageDecision applies the length policy to a candidate text.
func MemoryStorageDecision(content string) StorageDecision {
	normalized := NormalizeMemoryText(content)
	switch {
	case normalized == "":
		return StorageDecision{Normalized: normalized, Reason: "empty"}
	case jsx.Len(normalized) > MaxMemoryChars:
		return StorageDecision{Normalized: normalized, Reason: "too_long"}
	}
	return StorageDecision{Allow: true, Normalized: normalized}
}
