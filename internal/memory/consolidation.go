package memory

import (
	"fmt"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

var (
	memoryRelations  = map[string]bool{"new": true, "updates": true, "extends": true, "derives": true}
	memoryCategories = map[string]bool{
		"identity": true, "preferences": true, "projects": true, "contacts": true, "events": true,
		"tasks": true, "episodic": true, "procedural": true, "assistant_self": true,
	}
)

// Candidate is a durable fact a model proposed from a thread or a document.
type Candidate struct {
	Memory      string
	Subject     string
	Predicate   string
	Object      string
	Relation    string
	Category    string
	Confidence  float64
	Importance  float64
	IsStatic    bool
	ValidFrom   string // ISO timestamp, "" when none
	ValidTo     string
	ForgetAfter string
	Evidence    string
}

func cleanText(value any, maxLength int) string {
	return jsx.Head(jsx.Collapse(jsx.StrOr(value)), maxLength)
}

func normalizeDate(value any) string {
	text := cleanText(value, 80)
	if text == "" {
		return ""
	}
	ms, ok := jsx.ParseDate(text, time.Local)
	if !ok {
		return ""
	}
	return jsx.ISO(time.UnixMilli(ms))
}

func normalizeConfidence(value any) float64 {
	c := jsx.ToNumber(value)
	if !jsx.IsFinite(c) {
		return 0.7
	}
	return max(0, min(1, c))
}

// NormalizeCandidate validates one model-proposed candidate; ok is false
// when it is not usable. A fact over the length limit is dropped, never cut
// off mid-sentence.
func NormalizeCandidate(candidate any) (Candidate, bool) {
	raw, isObj := candidate.(*jsx.Obj)
	if !isObj || raw == nil {
		return Candidate{}, false
	}
	subject := cleanText(raw.Lookup("subject"), 180)
	predicate := jsx.Lower(cleanText(raw.Lookup("predicate"), 120))
	object := cleanText(raw.Lookup("object"), 900)
	memory := cleanText(raw.Lookup("memory"), MaxMemoryChars+1)
	if subject == "" || predicate == "" || object == "" || memory == "" || jsx.Len(memory) > MaxMemoryChars {
		return Candidate{}, false
	}

	relation := jsx.Lower(cleanText(raw.Lookup("relation"), 24))
	category := jsx.Lower(cleanText(raw.Lookup("category"), 40))
	if !memoryRelations[relation] {
		relation = "new"
	}
	confidence := normalizeConfidence(raw.Lookup("confidence"))
	if relation == "derives" {
		confidence = min(confidence, 0.6)
	}
	if !memoryCategories[category] {
		category = "episodic"
	}
	importance := jsx.ToNumber(raw.Lookup("importance"))
	if !jsx.IsFinite(importance) || importance == 0 {
		importance = 5
	}
	return Candidate{
		Memory:      memory,
		Subject:     subject,
		Predicate:   predicate,
		Object:      object,
		Relation:    relation,
		Category:    category,
		Confidence:  confidence,
		Importance:  max(1, min(10, importance)),
		IsStatic:    raw.Lookup("is_static") == true || raw.Lookup("isStatic") == true,
		ValidFrom:   normalizeDate(jsx.Or(raw.Lookup("valid_from"), raw.Lookup("validFrom"))),
		ValidTo:     normalizeDate(jsx.Or(raw.Lookup("valid_to"), raw.Lookup("validTo"))),
		ForgetAfter: normalizeDate(jsx.Or(raw.Lookup("forget_after"), raw.Lookup("forgetAfter"))),
		Evidence:    cleanText(raw.Lookup("evidence"), 500),
	}, true
}

// NormalizeCandidates keeps up to limit distinct usable candidates.
func NormalizeCandidates(value any, limit int) []Candidate {
	items, ok := value.([]any)
	if !ok {
		return nil
	}
	var candidates []Candidate
	seen := map[string]bool{}
	for _, item := range items {
		candidate, ok := NormalizeCandidate(item)
		if !ok {
			continue
		}
		key := strings.Join([]string{jsx.Lower(candidate.Subject), candidate.Predicate, jsx.Lower(candidate.Object)}, "\x00")
		if seen[key] {
			continue
		}
		seen[key] = true
		candidates = append(candidates, candidate)
		if len(candidates) >= limit {
			break
		}
	}
	return candidates
}

// ConsolidationInstructions is the memory-extraction part of the thread
// summary prompt.
func ConsolidationInstructions(currentDateTime string) string {
	return strings.Join([]string{
		"Also extract durable memory candidates from the thread.",
		"Current date/time: " + currentDateTime + ". Resolve relative dates against this value.",
		"A memory candidate must be an atomic fact that will improve a future conversation.",
		fmt.Sprintf("Write each memory as one self-contained sentence of at most %d characters.", MaxMemoryChars),
		"Only store what the user said or what a tool result showed. Never store something only the assistant said: its guesses, suggestions, questions, plans, and summaries are not facts, even when the user did not object.",
		"Set evidence to the exact words from the thread that state the fact, copied unchanged and untranslated. Evidence is checked against the thread; a fact only the assistant stated is discarded.",
		"Exclude secrets, credentials, private tokens, raw tool output, routine task narration, and facts useful only inside this thread.",
		"Use relation=\"updates\" when a fact replaces an older value for the same subject and predicate. When \"Known facts\" lists that fact, reuse its subject and predicate exactly.",
		"Use relation=\"extends\" when it adds compatible detail without replacing the prior fact, including a further value that can be true at the same time (a second sister, another pet).",
		"Use relation=\"derives\" only for a strongly supported inference and lower its confidence.",
		"Use is_static=true only for stable identity or durable preference facts.",
		"Use category=\"procedural\" only for reusable workflows or repeatable tool-use procedures, not one-off task status.",
		"Use category=\"assistant_self\" when the user clearly trains how the assistant should write or behave with them (tone, length, language mix, humor, casing preferences, etc.). Prefer freeform memory text over rigid labels. Only store this when explicit or repeatedly reinforced — not from one joke.",
		"Set valid_from, valid_to, or forget_after as ISO-8601 timestamps when the thread provides temporal boundaries.",
		"Return an empty memory_candidates array when nothing is worth retaining.",
	}, " ")
}
