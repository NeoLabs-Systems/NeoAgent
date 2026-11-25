package agent

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/memory"
)

// Vectors recorded from Node's document_facts.js on a temporary NEOAGENT_HOME.
func TestDocumentFactsMatchNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/document_facts.json")
	if err != nil {
		t.Fatal(err)
	}
	var v struct {
		Batches     [][]string     `json:"batches"`
		Prompt      string         `json:"prompt"`
		PromptEmpty string         `json:"promptEmpty"`
		Raw         map[string]any `json:"raw"`
		Facts       []struct {
			Memory string `json:"memory"`
			Doc    string `json:"doc"`
		} `json:"facts"`
	}
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	docs := []memory.Document{
		{SourceType: "gmail_thread", Title: "Offer accepted", Content: "Hi, I accept the offer from Acme GmbH. Start 1 March.", SourceTimestamp: "2026-02-10T09:00:00.000Z", ExternalObjectID: "t1"},
		{SourceType: "outlook_message", Title: "Newsletter", Content: "Big sale this week!", ExternalObjectID: "m2"},
		{SourceType: "gmail_thread", Title: "Long", Content: strings.Repeat("x", 11000), SourceTimestamp: "2026-01-01T00:00:00.000Z", ExternalObjectID: "t3"},
	}
	units := buildExtractionUnits(docs)
	var batches [][]string
	for _, b := range batchUnits(units, factsBatchChars) {
		var row []string
		for _, u := range b {
			row = append(row, fmt.Sprintf("%s:%d", u.document.ExternalObjectID, len(u.content)))
		}
		batches = append(batches, row)
	}
	if fmt.Sprint(batches) != fmt.Sprint(v.Batches) {
		t.Fatalf("batches %v want %v", batches, v.Batches)
	}
	now := time.Date(2026, 11, 25, 10, 0, 0, 0, time.UTC)
	if got := buildDocumentFactsPrompt(memory.Owner{Name: "Ada", Email: "ada@example.com"}, units[:2], []string{"User lives in Berlin."}, now); got != v.Prompt {
		t.Errorf("prompt differs:\n%s\n---\n%s", got, v.Prompt)
	}
	if got := buildDocumentFactsPrompt(memory.Owner{}, units[1:2], nil, now); got != v.PromptEmpty {
		t.Errorf("empty prompt differs:\n%s\n---\n%s", got, v.PromptEmpty)
	}
	facts := normalizeDocumentFacts(toJSX(v.Raw), units)
	if len(facts) != len(v.Facts) {
		t.Fatalf("facts %+v want %+v", facts, v.Facts)
	}
	for i, f := range facts {
		if f.candidate.Memory != v.Facts[i].Memory || f.document.ExternalObjectID != v.Facts[i].Doc {
			t.Errorf("fact %d: %q/%s want %+v", i, f.candidate.Memory, f.document.ExternalObjectID, v.Facts[i])
		}
	}
}
