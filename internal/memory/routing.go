package memory

import (
	"regexp"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Route is what a query looks like it is asking for.
type Route struct {
	Intent         string
	Confidence     float64
	CategoryBoosts map[string]float64
}

var (
	proceduralPatterns = []*regexp.Regexp{
		regexp.MustCompile(`\bhow (?:do|did|should|can) (?:i|we|you)\b`),
		regexp.MustCompile(`\b(?:workflow|procedure|runbook|playbook|steps?|checklist|process)\b`),
		regexp.MustCompile(`\b(?:repeat|reusable|again|same way|tool[- ]use|command sequence)\b`),
	}
	episodicPatterns = []*regexp.Regexp{
		regexp.MustCompile(`\b(?:when|what happened|last time|previously|yesterday|today|last week|last month)\b`),
		regexp.MustCompile(`\b(?:meeting|event|conversation|session|incident|task run)\b`),
	}
	profilePatterns = []*regexp.Regexp{
		regexp.MustCompile(`\b(?:prefer|preference|likes?|dislikes?|my name|who am i|about me)\b`),
		regexp.MustCompile(`\b(?:profile|personality|standing instruction|how should you)\b`),
	}
)

func hasAny(text string, patterns []*regexp.Regexp) bool {
	for _, pattern := range patterns {
		if pattern.MatchString(text) {
			return true
		}
	}
	return false
}

// RouteMemoryQuery guesses the intent of a recall query.
func RouteMemoryQuery(query string) Route {
	text := jsx.Lower(query)
	switch {
	case jsx.Trim(text) == "":
		return Route{Intent: "broad", CategoryBoosts: map[string]float64{}}
	case hasAny(text, proceduralPatterns):
		return Route{Intent: "procedural", Confidence: 0.76, CategoryBoosts: map[string]float64{"procedural": 0.26, "tasks": 0.08, "episodic": 0.04}}
	case hasAny(text, episodicPatterns):
		return Route{Intent: "episodic", Confidence: 0.7, CategoryBoosts: map[string]float64{"episodic": 0.18, "events": 0.16, "tasks": 0.1}}
	case hasAny(text, profilePatterns):
		return Route{Intent: "profile", Confidence: 0.72, CategoryBoosts: map[string]float64{"preferences": 0.2, "identity": 0.16, "assistant_self": 0.12}}
	}
	return Route{Intent: "broad", Confidence: 0.35, CategoryBoosts: map[string]float64{}}
}

// RouteCategoryBoost is how much a route favours a memory category. Only a
// confident, non-broad route boosts anything.
func RouteCategoryBoost(route Route, category string) float64 {
	if route.Intent == "broad" || route.Confidence < 0.6 {
		return 0
	}
	return route.CategoryBoosts[category]
}
