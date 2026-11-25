package agent

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math"
	"regexp"
	"slices"
	"sort"
	"strings"

	"golang.org/x/text/unicode/norm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
)

// Tool selection: full schemas are capped per model turn because several
// providers limit the schema count. The stable search_tools control surface
// discovers the rest of the registry without putting the whole catalog into
// every prompt.

type aiDefinition = tools.Definition

const (
	maxTools       = 20
	retrievedTools = 3
)

var candidateScores = map[string]float64{"control": 1, "named": 0.9, "conversation": 0.85, "run_setup": 0.8, "default": 0.7, "retrieved": 0.65}

// Candidate is a tool a run starts with and why.
type Candidate struct {
	Name       string
	Source     string
	Score      float64
	Similarity *float64
	Rank       int
}

// Retrieved is a tool found by what the request means.
type Retrieved struct {
	Name       string
	Similarity float64
}

type selector struct{ registry *tools.Registry }

func (s selector) requiredNames(includeCoreFileTools bool) []string {
	names := s.registry.NamesWithSelection("always")
	if includeCoreFileTools {
		names = append(append(names, s.registry.NamesWithSelection("coding")...), "execute_command")
	}
	return names
}

func expandByFamily(names []string, all []tools.Definition) []string {
	var requested []string
	for _, n := range names {
		if n = strings.TrimSpace(n); n != "" && !slices.Contains(requested, n) {
			requested = append(requested, n)
		}
	}
	families := map[string]bool{}
	for _, name := range requested {
		for _, t := range all {
			if t.Name == name && strings.TrimSpace(t.Family) != "" {
				families[strings.TrimSpace(t.Family)] = true
			}
		}
	}
	if len(families) == 0 {
		return requested
	}
	expanded := append([]string(nil), requested...)
	for _, t := range all {
		name := strings.TrimSpace(t.Name)
		if name != "" && !slices.Contains(expanded, name) && families[strings.TrimSpace(t.Family)] {
			expanded = append(expanded, name)
		}
	}
	return expanded
}

var whitespaceRun = regexp.MustCompile(`\s+`)

func compactDescription(value string, maxChars int) string {
	text := strings.TrimSpace(whitespaceRun.ReplaceAllString(value, " "))
	units := []rune(text)
	if len(units) <= maxChars {
		return text
	}
	return strings.TrimRight(string(units[:maxChars-3]), " \t\n") + "..."
}

var nonWord = regexp.MustCompile(`[^\p{L}\p{N}]+`)
var underscoreDash = regexp.MustCompile(`[_-]+`)

func searchTerms(value string) []string {
	text := norm.NFC.String(strings.ToLower(value))
	text = underscoreDash.ReplaceAllString(text, " ")
	var out []string
	for _, term := range nonWord.Split(text, -1) {
		term = strings.TrimSpace(term)
		if len([]rune(term)) > 1 && !slices.Contains(out, term) {
			out = append(out, term)
		}
	}
	return out
}

// SearchResult is one search_tools hit.
type SearchResult struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Source      string `json:"source"`
	Active      bool   `json:"active"`
}

func (s selector) search(catalog []tools.Definition, query string, limit int, activeNames, alsoNames []string) []SearchResult {
	return s.searchMin(catalog, query, limit, 1, activeNames, alsoNames)
}

// searchMin keeps only hits scoring at least minScore.
func (s selector) searchMin(catalog []tools.Definition, query string, limit, minScore int, activeNames, alsoNames []string) []SearchResult {
	terms := searchTerms(query)
	if len(terms) == 0 && len(alsoNames) == 0 {
		return []SearchResult{}
	}
	if limit <= 0 {
		limit = 8
	}
	limit = max(1, min(limit, 12))
	type scored struct {
		SearchResult
		score int
	}
	var hits []scored
	for i := range catalog {
		tool := &catalog[i]
		name := strings.TrimSpace(tool.Name)
		if name == "" {
			continue
		}
		nameTerms := searchTerms(name)
		description := compactDescription(tool.Description, 260)
		descTerms := searchTerms(description)
		capabilities := s.registry.Meta(name, tool).Capabilities
		score := 0
		for _, term := range terms {
			if strings.ToLower(name) == term {
				score += 12
			}
			if slices.Contains(nameTerms, term) {
				score += 7
			} else if slices.ContainsFunc(nameTerms, func(c string) bool { return strings.HasPrefix(c, term) || strings.HasPrefix(term, c) }) {
				score += 4
			}
			if slices.Contains(capabilities, term) {
				score += 5
			}
			if slices.Contains(descTerms, term) {
				score += 2
			}
		}
		if rank := slices.Index(alsoNames, name); rank != -1 {
			score += max(1, 6-rank)
		}
		if score < minScore {
			continue
		}
		source := "built-in"
		if tool.ServerID != "" {
			source = "mcp:" + tool.ServerID
		}
		hits = append(hits, scored{SearchResult{Name: name, Description: description, Source: source, Active: slices.Contains(activeNames, name)}, score})
	}
	sort.SliceStable(hits, func(i, j int) bool {
		if hits[i].score != hits[j].score {
			return hits[i].score > hits[j].score
		}
		return hits[i].Name < hits[j].Name
	})
	out := []SearchResult{}
	for i := 0; i < len(hits) && i < limit; i++ {
		out = append(out, hits[i].SearchResult)
	}
	return out
}

func (s selector) catalogGroup(tool *tools.Definition) string {
	meta := s.registry.Meta(tool.Name, tool)
	if tool.ServerID != "" {
		return "mcp:" + tool.ServerID
	}
	if meta.Group == "integration" || meta.Group == "external" {
		if prefix := strings.Split(tool.Name, "_")[0]; prefix != "" {
			return prefix
		}
		return "other"
	}
	return meta.Group
}

func (s selector) summarizeCatalog(list []tools.Definition) string {
	var order []string
	groups := map[string][]string{}
	for i := range list {
		name := strings.TrimSpace(list[i].Name)
		if name == "" {
			continue
		}
		group := s.catalogGroup(&list[i])
		if _, ok := groups[group]; !ok {
			order = append(order, group)
		}
		entry := name
		if list[i].ServerID != "" {
			if d := compactDescription(list[i].Description, 72); d != "" {
				entry = fmt.Sprintf("%s (%s)", name, d)
			}
		}
		groups[group] = append(groups[group], entry)
	}
	lines := make([]string, 0, len(order))
	for _, g := range order {
		lines = append(lines, g+": "+strings.Join(groups[g], ", "))
	}
	return strings.Join(lines, "\n")
}

// discoverySummary lists the inactive catalog by name, so the model can
// activate what it needs without a search turn first.
func (s selector) discoverySummary(all, active []tools.Definition) string {
	activeNames := map[string]bool{}
	for _, t := range active {
		activeNames[t.Name] = true
	}
	var inactive []tools.Definition
	for _, t := range all {
		if !activeNames[t.Name] {
			inactive = append(inactive, t)
		}
	}
	if summary := s.summarizeCatalog(inactive); summary != "" {
		return "Inactive tools by group:\n" + summary
	}
	return ""
}

func (s selector) ensureRequired(selected, all []tools.Definition, includeCoreFileTools bool) []tools.Definition {
	required := s.requiredNames(includeCoreFileTools)
	out := append([]tools.Definition(nil), selected...)
	for _, name := range required {
		if slices.ContainsFunc(out, func(t tools.Definition) bool { return t.Name == name }) {
			continue
		}
		index := slices.IndexFunc(all, func(t tools.Definition) bool { return t.Name == name })
		if index < 0 {
			continue
		}
		if len(out) < maxTools {
			out = append(out, all[index])
			continue
		}
		replaced := false
		for i := len(out) - 1; i >= 0; i-- {
			if !slices.Contains(required, out[i].Name) {
				out[i], replaced = all[index], true
				break
			}
		}
		if !replaced && len(out) > 0 {
			out[len(out)-1] = all[index]
		}
	}
	return out
}

var wordSplit = regexp.MustCompile(`[^\p{L}\p{N}_]+`)

func (s selector) namedTools(request string, all []tools.Definition) []string {
	text := strings.ToLower(request)
	if text == "" {
		return nil
	}
	words := map[string]bool{}
	for _, w := range wordSplit.Split(text, -1) {
		if len([]rune(w)) >= 4 {
			words[w] = true
		}
	}
	var named []string
	for i := range all {
		name := all[i].Name
		if words[strings.ToLower(name)] {
			named = append(named, name)
			continue
		}
		meta := s.registry.Meta(name, &all[i])
		if meta.Known || meta.Group == "mcp" {
			continue
		}
		if words[strings.ToLower(strings.Split(name, "_")[0])] {
			named = append(named, name)
		}
	}
	if len(named) > 8 {
		named = named[:8]
	}
	return named
}

// selectCandidates picks the tools a run starts with, and says why. A catalog
// within the schema cap is simply all active.
func (s selector) selectCandidates(all []tools.Definition, request string, conversationTools, preferred []string, retrieved []Retrieved) ([]tools.Definition, []Candidate) {
	if len(all) <= maxTools {
		candidates := make([]Candidate, len(all))
		for i, t := range all {
			candidates[i] = Candidate{Name: t.Name, Source: "all", Score: 1}
		}
		return append([]tools.Definition(nil), all...), candidates
	}
	byName := map[string]tools.Definition{}
	for _, t := range all {
		byName[t.Name] = t
	}
	var ranked []*Candidate
	seen := map[string]*Candidate{}
	add := func(names []string, source string) {
		for _, name := range expandByFamily(names, all) {
			if _, ok := byName[name]; ok && seen[name] == nil {
				c := &Candidate{Name: name, Source: source, Score: candidateScores[source]}
				seen[name] = c
				ranked = append(ranked, c)
			}
		}
	}
	add(s.requiredNames(false), "control")
	add(s.registry.NamesWithSelection("default"), "default")
	add(preferred, "run_setup")
	add(s.namedTools(request, all), "named")
	add(conversationTools, "conversation")
	coding := s.registry.NamesWithSelection("coding")
	similarity := map[string]float64{}
	var missing []string
	for _, r := range retrieved {
		// A word match has no similarity (NaN).
		if !math.IsNaN(r.Similarity) {
			similarity[r.Name] = r.Similarity
		}
		if _, ok := byName[r.Name]; ok && seen[r.Name] == nil {
			missing = append(missing, r.Name)
		}
	}
	if len(missing) > retrievedTools {
		missing = missing[:retrievedTools]
	}
	add(missing, "retrieved")
	if slices.ContainsFunc(missing, func(n string) bool { return slices.Contains(coding, n) }) {
		add(coding, "retrieved")
	}
	for _, c := range ranked {
		if c.Source == "retrieved" {
			if v, ok := similarity[c.Name]; ok {
				v := v
				c.Similarity = &v
			}
		}
	}
	sorted := append([]*Candidate(nil), ranked...)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].Score > sorted[j].Score })
	kept := map[string]bool{}
	for i := 0; i < len(sorted) && i < maxTools; i++ {
		kept[sorted[i].Name] = true
	}
	var chosen []tools.Definition
	var candidates []Candidate
	for _, c := range ranked {
		if kept[c.Name] {
			chosen = append(chosen, byName[c.Name])
			candidates = append(candidates, *c)
		}
	}
	return chosen, candidates
}

func (s selector) expandGroups(names []string, all []tools.Definition) []string {
	known := map[string]bool{}
	for _, t := range all {
		known[t.Name] = true
	}
	var out []string
	for _, name := range names {
		if known[name] {
			out = append(out, name)
			continue
		}
		var members []string
		for i := range all {
			if s.catalogGroup(&all[i]) == name {
				members = append(members, all[i].Name)
			}
		}
		if len(members) == 0 {
			members = []string{name}
		}
		out = append(out, members...)
	}
	return out
}

// Activation is what activate_tools did.
type Activation struct {
	Tools                                  []tools.Definition
	Activated, Evicted, Unknown, NotActive []string
}

func (s selector) activate(current, all []tools.Definition, requestedNames []string, includeCoreFileTools bool) Activation {
	required := s.requiredNames(includeCoreFileTools)
	next := s.ensureRequired(current, all, includeCoreFileTools)
	result := Activation{Activated: []string{}, Evicted: []string{}, Unknown: []string{}, NotActive: []string{}}
	requested := expandByFamily(s.expandGroups(requestedNames, all), all)
	for _, name := range requested {
		index := slices.IndexFunc(all, func(t tools.Definition) bool { return t.Name == name })
		if index < 0 {
			result.Unknown = append(result.Unknown, name)
			continue
		}
		if slices.ContainsFunc(next, func(t tools.Definition) bool { return t.Name == name }) {
			continue
		}
		if len(next) >= maxTools {
			replace := slices.IndexFunc(next, func(t tools.Definition) bool {
				return !slices.Contains(required, t.Name) && !slices.Contains(requested, t.Name)
			})
			if replace == -1 {
				result.NotActive = append(result.NotActive, name)
				continue
			}
			result.Evicted = append(result.Evicted, next[replace].Name)
			next = slices.Delete(next, replace, replace+1)
		}
		next = append(next, all[index])
		result.Activated = append(result.Activated, name)
	}
	next = s.ensureRequired(next, all, includeCoreFileTools)
	if len(next) > maxTools {
		next = next[:maxTools]
	}
	result.Tools = next
	return result
}

func digestText(text string) string {
	sum := sha256.Sum256([]byte(text))
	return "sha256:" + hex.EncodeToString(sum[:])[:24]
}

func (r *Run) selectionFor(name string) (Candidate, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	c, ok := r.selection[name]
	return c, ok
}

func (r *Run) lastModelEvent() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.modelEventID
}

func names(list []tools.Definition) []string {
	out := make([]string, len(list))
	for i, t := range list {
		out[i] = t.Name
	}
	return out
}

// refreshCatalog rebuilds a run's eligible catalog from the registered
// services, never from a model-proposed name.
func (e *Engine) refreshCatalog(r *Run) []tools.Definition {
	ctx := r.Context()
	builtIn := e.deps.Tools.Available(ctx, CatalogRequest{UserID: r.UserID, AgentID: r.AgentID, TriggerType: r.TriggerType, TriggerSource: r.TriggerSource, Public: r.Public})
	var external []tools.Definition
	if r.Public == nil {
		external = e.deps.Tools.External(ctx, r.UserID, r.AgentID)
	}
	registry := e.deps.Tools.Registry()
	var catalog []tools.Definition
	for _, t := range append(builtIn, external...) {
		if registry.RunToolRefusal([]tools.Definition{t}, r.Options.toolOptions(), t.Name, nil) == "" {
			catalog = append(catalog, t)
		}
	}
	r.mu.Lock()
	r.toolCatalog = catalog
	r.mu.Unlock()
	return catalog
}

// DescribeIntegrations is the usage notes of the integrations behind tools,
// each integration at most once per run.
func (e *Engine) DescribeIntegrations(runID string, list []tools.Definition) string {
	r, ok := e.RunInfo(runID)
	if !ok || e.deps.Integrations == nil || r.Public != nil {
		return ""
	}
	var keys []string
	r.mu.Lock()
	if r.describedIntegr == nil {
		r.describedIntegr = map[string]bool{}
	}
	for _, t := range list {
		key := fmt.Sprint(t.Integration)
		if t.Integration == nil || key == "" || r.describedIntegr[key] || slices.Contains(keys, key) {
			continue
		}
		keys = append(keys, key)
	}
	for _, k := range keys {
		r.describedIntegr[k] = true
	}
	r.mu.Unlock()
	if len(keys) == 0 {
		return ""
	}
	return e.deps.Integrations.SummarizeConnectedProviders(r.Context(), r.UserID, r.AgentID, keys)
}

// SearchTools is search_tools for a run.
func (e *Engine) SearchTools(runID, query string, limit int, alsoNames []string) (map[string]any, error) {
	r, ok := e.RunInfo(runID)
	if !ok {
		return nil, fmt.Errorf("Run is not active.")
	}
	catalog := e.refreshCatalog(r)
	sel := selector{e.deps.Tools.Registry()}
	results := sel.search(catalog, query, limit, names(r.ActiveTools()), alsoNames)
	resultNames := make([]string, len(results))
	hit := map[string]bool{}
	for i, res := range results {
		resultNames[i] = res.Name
		hit[res.Name] = true
	}
	e.ledger.Record(runledger.Event{RunID: runID, UserID: r.UserID, AgentID: r.AgentID, Type: runledger.EventToolsSelected,
		Payload: map[string]any{"kind": "search", "query_digest": digestText(query), "result_names": resultNames}})
	var found []tools.Definition
	for _, t := range catalog {
		if hit[t.Name] {
			found = append(found, t)
		}
	}
	out := map[string]any{"success": true, "query": query, "results": results}
	if notes := e.DescribeIntegrations(runID, found); notes != "" {
		out["integration_notes"] = notes
	}
	if len(results) > 0 {
		out["instruction"] = "Activate the exact tools you need with activate_tools."
	} else {
		out["instruction"] = "No matching tool was found. Try a broader capability description."
	}
	return out, nil
}

// ActivateTools is activate_tools for a run.
func (e *Engine) ActivateTools(runID string, requested []string) (map[string]any, error) {
	r, ok := e.RunInfo(runID)
	if !ok {
		return nil, fmt.Errorf("Run is not active.")
	}
	catalog := e.refreshCatalog(r)
	sel := selector{e.deps.Tools.Registry()}
	result := sel.activate(r.ActiveTools(), catalog, requested, false)
	r.mu.Lock()
	r.activeTools = result.Tools
	r.mu.Unlock()
	active := names(result.Tools)
	e.ledger.Record(runledger.Event{RunID: runID, UserID: r.UserID, AgentID: r.AgentID, Type: runledger.EventToolsSelected,
		Payload: map[string]any{"kind": "activate", "activated": result.Activated, "evicted": result.Evicted, "unknown": result.Unknown,
			"not_activated": result.NotActive, "active_tool_names": active}})
	var problems []string
	if len(result.Unknown) > 0 {
		problems = append(problems, fmt.Sprintf("There is no tool called %s; search_tools finds tools by what they do.", strings.Join(result.Unknown, ", ")))
	}
	if len(result.NotActive) > 0 {
		problems = append(problems, fmt.Sprintf("%s could not be turned on in this run.", strings.Join(result.NotActive, ", ")))
	}
	out := map[string]any{"success": len(problems) == 0, "activated": result.Activated, "evicted": result.Evicted, "unknown": result.Unknown,
		"not_activated": result.NotActive, "active_tools": active}
	if len(problems) > 0 {
		out["reason"] = strings.Join(problems, " ")
	}
	return out, nil
}
