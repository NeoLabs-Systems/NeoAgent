// Package memory is NeoAgent's memory domain: the memories table with its
// entities, facts, relations and embedding bands, recall ranking, core memory,
// ingested source documents, conversation history search and the /api/memory
// routes. It reads and writes the same rows as the Node server's
// services/memory and routes/memory.js.
package memory

import (
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

var ftsToken = regexp.MustCompile(`[\p{L}\p{N}_]{2,}`)

// BuildFtsQuery turns user text into a prefix-matched FTS5 AND query (for
// example `covid* AND 19*`), or "" when the text holds no usable word.
//
// Hyphens split words, because inside MATCH a `-` is the NOT operator.
// Every token is lowercased so AND, OR, NOT and NEAR cannot read as operators.
func BuildFtsQuery(query string) string {
	tokens := ftsToken.FindAllString(query, -1)
	if len(tokens) == 0 {
		return ""
	}
	parts := make([]string, len(tokens))
	for i, token := range tokens {
		parts[i] = strings.ReplaceAll(jsx.Lower(token), `"`, "") + "*"
	}
	return strings.Join(parts, " AND ")
}
