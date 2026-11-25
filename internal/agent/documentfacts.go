package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Document fact extraction (memory_writer.js extractDocumentFacts,
// document_facts.js): ingested documents (mail threads, notes) become a few
// durable facts about the user, checked against what memory already holds.
// Source text never becomes memory itself.

const (
	// About eight emails fit, which keeps a mailbox sweep to a dozen or so calls.
	factsBatchChars  = 12000
	maxKnownMemories = 40
)

type extractionUnit struct {
	document memory.Document
	content  string
}

// buildExtractionUnits: long documents are read in chunks; a short email stays one unit.
func buildExtractionUnits(documents []memory.Document) []extractionUnit {
	var units []extractionUnit
	for _, d := range documents {
		for _, chunk := range memory.ChunkDocument(d) {
			units = append(units, extractionUnit{document: d, content: chunk.Content})
		}
	}
	return units
}

func batchUnits(units []extractionUnit, budget int) [][]extractionUnit {
	var batches [][]extractionUnit
	var current []extractionUnit
	size := 0
	for _, u := range units {
		n := utf16Units(u.content)
		if len(current) > 0 && size+n > budget {
			batches = append(batches, current)
			current, size = nil, 0
		}
		current = append(current, u)
		size += n
	}
	if len(current) > 0 {
		batches = append(batches, current)
	}
	return batches
}

func utf16Units(s string) int {
	n := 0
	for _, r := range s {
		if r > 0xFFFF {
			n += 2
		} else {
			n++
		}
	}
	return n
}

func describeOwner(o memory.Owner) string {
	var parts []string
	if o.Name != "" {
		parts = append(parts, o.Name)
	}
	if o.Email != "" {
		parts = append(parts, "<"+o.Email+">")
	}
	if len(parts) == 0 {
		return "the account owner"
	}
	return strings.Join(parts, " ")
}

func formatUnit(u extractionUnit, index int) string {
	head := fmt.Sprintf("[%d] %s", index+1, u.document.SourceType)
	if u.document.SourceTimestamp != "" {
		head += " · " + u.document.SourceTimestamp
	}
	return head + "\n" + u.content
}

const factsSchema = `{
  "facts": [
    {
      "memory": "User works at Acme GmbH as a data engineer since March 2026.",
      "subject": "User",
      "predicate": "works at",
      "object": "Acme GmbH",
      "relation": "new | updates | extends",
      "category": "identity | preferences | projects | contacts | events | tasks | episodic",
      "importance": 7,
      "confidence": 0.9,
      "is_static": false,
      "valid_from": "2026-03-01",
      "valid_to": null,
      "source": 1
    }
  ]
}`

func buildDocumentFactsPrompt(owner memory.Owner, units []extractionUnit, knownMemories []string, now time.Time) string {
	known := knownMemories
	if len(known) > maxKnownMemories {
		known = known[:maxKnownMemories]
	}
	who := describeOwner(owner)
	knownText := "(nothing yet)"
	if len(known) > 0 {
		lines := make([]string, len(known))
		for i, m := range known {
			lines[i] = "- " + m
		}
		knownText = strings.Join(lines, "\n")
	}
	sources := make([]string, len(units))
	for i, u := range units {
		sources[i] = formatUnit(u, i)
	}
	return strings.Join([]string{
		"Return JSON only.",
		fmt.Sprintf(`You keep the long-term memory of a personal assistant for %s, called "the user" below.`, who),
		fmt.Sprintf("Today is %s. Read the numbered sources from the user's accounts and write down only what about the user's life will still matter in months and helps the assistant serve them.", now.UTC().Format("2006-01-02")),
		"",
		"Worth remembering, when a source clearly shows it: where the user works or studies and in what role, a job they accepted, started or left, a business they run, where they live or are moving, the people who matter to them and who those people are, major upcoming events and commitments with their dates, long-running projects, contracts and memberships they rely on, and preferences or habits they state. These are examples; judge any other case by the same standard.",
		"Not worth remembering: newsletters, marketing, receipts and shipping notices for everyday purchases, password resets, verification codes, security alerts, social media notifications, automated reports, scheduling back-and-forth, small talk, anything that stops mattering within weeks, and facts about other people that say nothing about the user.",
		"Never store secrets: passwords, codes, card, account or ID numbers, tokens.",
		"",
		"Rules:",
		fmt.Sprintf(`- One fact per memory: a complete sentence about the user, at most %d characters, in the third person starting with "User" (e.g. "User accepted a job offer from Acme GmbH (March 2026).").`, memory.MaxMemoryChars),
		"- Only what the source states. Do not guess: a job offer received is not a job, an interview invitation is not employment, a mail from a company does not make the user its customer.",
		fmt.Sprintf("- Read each source from the user's side: a source sent by %s shows what the user said or did; anything else shows what someone told the user.", who),
		"- Give absolute dates (month and year at least) when timing matters; resolve relative dates against the source date.",
		"- One memory per topic: when several sources are about the same thing (an offer accepted, then the welcome mail), write one memory that combines them.",
		`- Do not repeat anything in "Already known", not even reworded. If a source shows a known fact has changed (new employer, new address), write the new fact with relation "updates" and the same subject and predicate. The memory text states only the current fact, never the old value.`,
		`- Write in the language of "Already known"; if it is empty, write in English.`,
		"- Most sources hold nothing worth remembering. An empty list is the right answer then; never pad it with weak facts.",
		`- "source" is the number of the source the fact comes from.`,
		"",
		"Already known:",
		knownText,
		"",
		"Sources:",
		strings.Join(sources, "\n\n"),
		"",
		"Schema:\n" + factsSchema,
	}, "\n")
}

type documentFact struct {
	candidate memory.Candidate
	document  memory.Document
}

// normalizeDocumentFacts keeps facts that pass the memory rules and point at a real source.
func normalizeDocumentFacts(raw *jsx.Obj, units []extractionUnit) []documentFact {
	var out []documentFact
	if raw == nil {
		return out
	}
	items, _ := raw.Value("facts").([]any)
	seen := map[string]bool{}
	for _, item := range items {
		obj, _ := item.(*jsx.Obj)
		index := -1
		if obj != nil {
			if n := jsx.ToNumber(obj.Value("source")); jsx.IsFinite(n) && n == float64(int(n)) {
				index = int(n) - 1
			}
		}
		candidate, ok := memory.NormalizeCandidate(item)
		if index < 0 || index >= len(units) || !ok {
			continue
		}
		key := strings.ToLower(candidate.Memory)
		if seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, documentFact{candidate: candidate, document: units[index].document})
	}
	return out
}

// toJSX turns a decoded JSON value into the memory package's ordered values.
func toJSX(v any) *jsx.Obj {
	raw, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	return jsx.ParseObject(string(raw))
}

// ExtractDocumentFacts is the memory ingestion's fact extractor.
func (e *Engine) ExtractDocumentFacts(ctx context.Context, userID int64, agentID string, req memory.ExtractRequest) ([]string, error) {
	if e.deps.Memory == nil {
		return nil, errors.New("memory is not available")
	}
	progress := req.OnProgress
	if progress == nil {
		progress = func(int, int) {}
	}
	units := buildExtractionUnits(req.Documents)
	batches := batchUnits(units, factsBatchChars)
	done := 0
	progress(done, len(units))
	ids := []string{}
	if len(batches) == 0 {
		return ids, nil
	}
	seenIDs := map[string]bool{}
	// Facts from earlier batches count as known, so a later mail about the same
	// thing does not add it again.
	var learned []string
	failed := 0
	var lastErr error
	for _, batch := range batches {
		if err := ctx.Err(); err != nil {
			return nil, errors.New("Memory extraction aborted.")
		}
		err := func() error {
			titles := make([]string, len(batch))
			for i, u := range batch {
				titles[i] = u.document.Title
			}
			known, err := e.deps.Memory.KnownMemories(ctx, userID, agentID, strings.Join(titles, "\n"))
			if err != nil {
				return err
			}
			answer, err := e.InferStructured(ctx, StructuredRequest{UserID: userID, AgentID: agentID, Purpose: "general",
				Prompt: buildDocumentFactsPrompt(req.Owner, batch, append(append([]string{}, learned...), known...), time.Now()),
				// Thinking models spend most of it on reasoning; the facts themselves are short.
				MaxTokens: 8000, Phase: "document_extraction"})
			if err != nil {
				return err
			}
			for _, f := range normalizeDocumentFacts(toJSX(answer.Parsed), batch) {
				d := f.document
				meta := jsx.NewObj()
				if req.Metadata != nil {
					meta = req.Metadata.Clone()
				}
				meta.Set("trustLevel", "external_source")
				saved, err := e.deps.Memory.ConsolidateMemoryCandidates(ctx, userID, []memory.Candidate{f.candidate}, memory.ConsolidateOptions{AgentID: agentID,
					SourceRef: &memory.SourceRef{Type: strPtr(d.SourceType), ID: strPtr(d.ExternalObjectID), Label: strPtr(d.Title)}, Metadata: meta})
				if err != nil {
					return err
				}
				for _, id := range saved {
					if !seenIDs[id] {
						seenIDs[id] = true
						ids = append(ids, id)
					}
				}
				learned = append(learned, f.candidate.Memory)
			}
			return nil
		}()
		if err != nil {
			if ctx.Err() != nil {
				return nil, errors.New("Memory extraction aborted.")
			}
			failed++
			lastErr = err
			e.log.Warn("Document fact extraction failed", "error", err)
		}
		done += len(batch)
		progress(done, len(units))
	}
	if failed == len(batches) {
		return nil, lastErr
	}
	return ids, nil
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
