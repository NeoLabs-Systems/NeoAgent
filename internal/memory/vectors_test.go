package memory

import (
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// TestMain runs the package's tests in UTC, the zone the Node vectors were
// recorded in: SQLite-style timestamps are read in the server's local zone.
func TestMain(m *testing.M) {
	time.Local = time.UTC
	os.Exit(m.Run())
}

// TestPureFunctionsMatchNode replays the outputs of the Node memory domain's
// pure functions recorded by gen/vectors.js.
func TestPureFunctionsMatchNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors []struct {
		Fn     string          `json:"fn"`
		Input  json.RawMessage `json:"input"`
		Output json.RawMessage `json:"output"`
	}
	if err := json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	failures := map[string]int{}
	for i, v := range vectors {
		in, err := jsx.Parse(string(v.Input))
		if err != nil {
			t.Fatal(err)
		}
		want, err := jsx.Parse(string(v.Output))
		if err != nil {
			t.Fatal(err)
		}
		got, ok := runVector(t, v.Fn, in)
		if !ok {
			t.Fatalf("no Go function for %s", v.Fn)
		}
		if g, w := jsx.Marshal(got), jsx.Marshal(want); g != w {
			failures[v.Fn]++
			if failures[v.Fn] <= 3 {
				t.Errorf("#%d %s(%s)\n got  %.600s\n want %.600s", i, v.Fn, truncate(string(v.Input), 200), g, w)
			}
		}
	}
	for fn, n := range failures {
		t.Logf("%s: %d mismatches", fn, n)
	}
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n] + "…"
	}
	return s
}

func str(v any) string { s, _ := v.(string); return s }

func obj(v any) *jsx.Obj {
	if o, ok := v.(*jsx.Obj); ok {
		return o
	}
	return jsx.NewObj()
}

func list[T any](items []T, conv func(T) any) []any {
	out := make([]any, 0, len(items))
	for _, it := range items {
		out = append(out, conv(it))
	}
	return out
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func routeObj(r Route) *jsx.Obj {
	boosts := jsx.NewObj()
	// Node writes the boosts in a fixed order per intent.
	order := map[string][]string{
		"procedural": {"procedural", "tasks", "episodic"},
		"episodic":   {"episodic", "events", "tasks"},
		"profile":    {"preferences", "identity", "assistant_self"},
	}[r.Intent]
	for _, k := range order {
		if v, ok := r.CategoryBoosts[k]; ok {
			boosts.Set(k, v)
		}
	}
	if len(order) == 0 && len(r.CategoryBoosts) > 0 {
		for k, v := range r.CategoryBoosts {
			boosts.Set(k, v)
		}
	}
	return jsx.O("intent", r.Intent, "confidence", r.Confidence, "categoryBoosts", boosts)
}

func routeFromObj(o *jsx.Obj) Route {
	r := Route{Intent: o.String("intent"), Confidence: jsx.ToNumber(o.Value("confidence")), CategoryBoosts: map[string]float64{}}
	b := obj(o.Value("categoryBoosts"))
	for _, k := range b.Keys() {
		r.CategoryBoosts[k] = jsx.ToNumber(b.Value(k))
	}
	return r
}

func candidateObj(c Candidate) any {
	return jsx.O("memory", c.Memory, "subject", c.Subject, "predicate", c.Predicate, "object", c.Object,
		"relation", c.Relation, "category", c.Category, "confidence", c.Confidence, "importance", c.Importance,
		"isStatic", c.IsStatic, "validFrom", nullable(c.ValidFrom), "validTo", nullable(c.ValidTo),
		"forgetAfter", nullable(c.ForgetAfter), "evidence", c.Evidence)
}

func termsOf(query string) []QueryTerm {
	// The generator's stand-in document frequency.
	return WeighQueryTerms(query, 20, func(term string) float64 { return float64(jsx.Len(term)%4 + 1) })
}

func optNumber(o *jsx.Obj, key string) *float64 {
	v, ok := o.Get(key)
	if !ok {
		return nil
	}
	f := jsx.ToNumber(v)
	return &f
}

func retentionOf(o *jsx.Obj) Retention {
	return Retention{
		Pinned: jsx.ToNumber(o.Value("pinned")), Category: jsx.StrOr(o.Value("category")),
		Importance: jsx.ToNumber(o.Value("importance")), Archived: jsx.ToNumber(o.Value("archived")),
		Strength: jsx.ToNumber(o.Value("memory_strength")), StaleAfterDays: jsx.ToNumber(o.Value("stale_after_days")),
		LastAccessedAt: jsx.StrOr(o.Value("last_accessed_at")), UpdatedAt: jsx.StrOr(o.Value("updated_at")),
		CreatedAt: jsx.StrOr(o.Value("created_at")),
	}
}

func runVector(t *testing.T, fn string, in any) (any, bool) {
	t.Helper()
	switch fn {
	case "buildFtsQuery":
		return nullable(BuildFtsQuery(str(in))), true
	case "storageDecision":
		d := MemoryStorageDecision(str(in))
		return jsx.O("allow", d.Allow, "normalized", d.Normalized, "reason", nullable(d.Reason)), true
	case "routeMemoryQuery":
		return routeObj(RouteMemoryQuery(str(in))), true
	case "routeCategoryBoost":
		o := obj(in)
		return RouteCategoryBoost(routeFromObj(obj(o.Value("route"))), o.String("category")), true
	case "extractEntities":
		return list(ExtractEntities(str(in), 16), func(e EntityCandidate) any {
			return jsx.O("key", e.Key, "name", e.Name, "kind", e.Kind, "inSentence", e.InSentence)
		}), true
	case "extractKeywords":
		return list(ExtractKeywords(str(in), 24), func(s string) any { return s }), true
	case "canonicalEntityKey":
		return CanonicalEntityKey(str(in)), true
	case "classifyEntity":
		return ClassifyEntity(str(in)), true
	case "isNoiseEntityName":
		return []any{IsNoiseEntityName(str(in), false), IsNoiseEntityName(str(in), true)}, true
	case "stableHash":
		return StableHash(str(in)), true
	case "buildFacts":
		o := obj(in)
		return list(BuildFacts(o.String("content"), o.String("category"), jsx.StrOr(o.Value("sourceType"))), func(f Fact) any {
			return jsx.O("subject", f.Subject, "predicate", f.Predicate, "object", f.Object, "category", f.Category,
				"confidence", f.Confidence, "metadata", f.Metadata)
		}), true
	case "summarizeForPrompt":
		return SummarizeForPrompt(str(in), []string{"Alice", "Bob", "C", "D", "E"}), true
	case "ownerVerification":
		return OwnerVerification(str(in)), true
	case "wordsOf":
		return list(WordsOf(str(in)), func(s string) any { return s }), true
	case "textCoverage":
		o := obj(in)
		return TextCoverage(o.String("query"), o.String("text")), true
	case "weighQueryTerms":
		return list(termsOf(str(in)), func(q QueryTerm) any {
			return jsx.O("term", q.Term, "weight", q.Weight, "distinctive", q.Distinctive)
		}), true
	case "lexicalSignal":
		o := obj(in)
		return LexicalSignal(termsOf(o.String("query")), o.String("text")), true
	case "conflict":
		o := obj(in)
		a, b := o.String("a"), o.String("b")
		return jsx.O("isValueChange", IsValueChange(a, b), "valuesDiffer", ValuesDiffer(a, b),
			"sharesContentWord", SharesContentWord(a, b), "isOneWordSwap", IsOneWordSwap(a, b)), true
	case "statementInText":
		o := obj(in)
		return StatementInText(o.String("a"), o.String("b")), true
	case "semanticNoiseFloor":
		var cos []float64
		for _, c := range in.([]any) {
			cos = append(cos, jsx.ToNumber(c))
		}
		return SemanticNoiseFloor(cos), true
	case "calibrateSemantic":
		o := obj(in)
		return CalibrateSemantic(jsx.ToNumber(o.Value("cosine")), jsx.ToNumber(o.Value("floor"))), true
	case "retention":
		r := retentionOf(obj(in))
		const now = int64(1795521600000) // 2026-11-24T12:00:00.000Z
		minAge, threshold := 1.0, 0.5
		return jsx.O("pinned", r.IsPinned(), "decayed", r.DecayedStrength(now), "multiplier", r.RetentionScoreMultiplier(now),
			"reinforced", r.ReinforcedStrength(), "archive", r.IsArchiveEligible(ArchiveOptions{NowMs: now}),
			"archiveStrict", r.IsArchiveEligible(ArchiveOptions{NowMs: now, MinAgeDays: &minAge, StrengthThreshold: &threshold})), true
	case "scoreMemoryCandidate":
		o := obj(in)
		num := func(key string, def float64) float64 {
			if p := optNumber(o, key); p != nil {
				return *p
			}
			return def
		}
		return ScoreMemoryCandidate(Signals{Signal: num("signal", 0), SecondarySignal: num("secondarySignal", 0),
			RouteBoost: num("routeBoost", 0), Importance: num("importance", 5), Confidence: num("confidence", 0.7),
			AccessCount: num("accessCount", 0), Retention: num("retention", 1)}), true
	case "normalizeMemoryCandidates":
		return list(NormalizeCandidates(in, 12), candidateObj), true
	case "consolidationInstructions":
		return ConsolidationInstructions(str(in)), true
	case "parseLlmTransferText":
		p := ParseLLMTransferText(str(in))
		warnings := list(p.Warnings, func(s string) any { return s })
		return jsx.O("memories", list(p.Memories, func(m TransferMemory) any {
			return jsx.O("category", m.Category, "content", m.Content)
		}), "coreEntries", p.CoreEntries, "behaviorNotes", p.BehaviorNotes, "warnings", warnings), true
	case "buildLlmTransferPrompt":
		return LLMTransferPrompt(str(in)), true
	case "importanceForCategory":
		return float64(ImportanceForCategory(str(in))), true
	case "chunkDocument":
		o := obj(in)
		doc := Document{SourceType: o.String("sourceType"), NormalizedType: o.String("normalizedType"),
			Title: o.String("title"), Content: o.String("content"), Payload: obj(o.Value("payload")), Metadata: obj(o.Value("metadata"))}
		return list(ChunkDocument(doc), func(c Chunk) any {
			return jsx.O("chunkIndex", float64(c.ChunkIndex), "charStart", float64(c.CharStart), "charEnd", float64(c.CharEnd),
				"content", c.Content, "contentHash", c.ContentHash, "metadata", c.Metadata)
		}), true
	}
	return nil, false
}
