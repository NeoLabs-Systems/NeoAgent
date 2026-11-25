package memory

import (
	"math"
	"regexp"
	"sort"
	"strings"
	"unicode"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Graded evidence that a memory matches a query, local and language
// independent. Word weights come from the user's own memories: a word in half
// of them says little, whatever language it is in.

var termPattern = regexp.MustCompile(`[\p{L}\p{N}_]{2,}`)

const (
	maxQueryTerms = 32
	minPrefix     = 4
	// A word that common in the corpus cannot be the only thing two texts share.
	commonShare = 0.15
	// Three letters can be "dog" or "the". Only a word the user's memories
	// almost never use can be trusted to be the former.
	shortWordShare = 0.03
	// A long message mentions more than any one memory can cover.
	longQueryTerms   = 12
	memorySideWeight = 0.8
	minNoiseSample   = 8
	smallSampleNoise = 0.25
	runMatchCoverage = 0.6
)

// WordsOf lowercases text and splits it into words of two letters or more.
func WordsOf(text string) []string { return termPattern.FindAllString(jsx.Lower(text), -1) }

func hasDigit(s string) bool { return strings.ContainsAny(s, "0123456789") }

func isStrongWord(word string) bool { return jsx.Len(word) >= minPrefix || hasDigit(word) }

// WordMatches reports whether term equals a word, or shares a prefix of at
// least minPrefix letters with one.
func WordMatches(term string, words map[string]bool) bool {
	return wordMatchesPrefix(term, words, minPrefix)
}

func wordMatchesPrefix(term string, words map[string]bool, minPrefix int) bool {
	if words[term] {
		return true
	}
	if jsx.Len(term) < minPrefix {
		return false
	}
	for word := range words {
		if jsx.Len(word) >= minPrefix && (strings.HasPrefix(word, term) || strings.HasPrefix(term, word)) {
			return true
		}
	}
	return false
}

// QueryTerm is one word of a query with the weight its rarity earns.
type QueryTerm struct {
	Term        string
	Weight      float64
	Distinctive bool
}

func wordSet(words []string) map[string]bool {
	set := make(map[string]bool, len(words))
	for _, w := range words {
		set[w] = true
	}
	return set
}

func isAcronym(raw string) bool {
	if jsx.Len(raw) < 2 || raw != jsx.Upper(raw) {
		return false
	}
	for _, r := range raw {
		if isLetter(r) {
			return true
		}
	}
	return false
}

// WeighQueryTerms weights the words of a query by how rarely the corpus uses
// them. Short words a memory never used carry no weight: they are almost
// always function words. Longer unseen words count against coverage.
func WeighQueryTerms(query string, totalDocuments float64, documentFrequency func(term string) float64) []QueryTerm {
	total := math.Max(1, totalDocuments)
	seen := map[string]int{}
	var terms []QueryTerm
	for _, raw := range termPattern.FindAllString(query, -1) {
		term := jsx.Lower(raw)
		if _, dup := seen[term]; dup || len(terms) >= maxQueryTerms {
			continue
		}
		strong := isStrongWord(term) || isAcronym(raw)
		frequency := documentFrequency(term)
		unseenWeight := 0.0
		if strong {
			unseenWeight = math.Log(total+1) / 2
		}
		var rareEnough bool
		if strong {
			rareEnough = frequency <= math.Max(2, total*commonShare)
		} else {
			rareEnough = jsx.Len(term) >= 3 && frequency <= math.Max(1, total*shortWordShare)
		}
		distinctive := frequency > 0 && rareEnough
		weight := unseenWeight
		if frequency > 0 {
			weight = math.Max(0.05, math.Log((total+1)/(frequency+0.5)))
			// In a handful of memories every word looks common. A distinctive
			// match must still outweigh a word no memory uses.
			if distinctive {
				weight = math.Max(weight, unseenWeight)
			}
		}
		seen[term] = len(terms)
		terms = append(terms, QueryTerm{Term: term, Weight: weight, Distinctive: distinctive})
	}
	return terms
}

// LexicalSignal is how much of the query's weighted terms a text covers.
func LexicalSignal(terms []QueryTerm, text string) float64 {
	if len(terms) == 0 {
		return 0
	}
	wordList := WordsOf(text)
	words := wordSet(wordList)
	matched, total := 0.0, 0.0
	distinctive := false
	for _, term := range terms {
		total += term.Weight
		if !WordMatches(term.Term, words) {
			continue
		}
		matched += term.Weight
		distinctive = distinctive || term.Distinctive
	}
	if !distinctive || total <= 0 {
		return 0
	}
	queryCoverage := matched / total
	if len(terms) <= longQueryTerms {
		return queryCoverage
	}
	queryWords := make(map[string]bool, len(terms))
	for _, term := range terms {
		queryWords[term.Term] = true
	}
	var strongWords []string
	for _, word := range uniqueInOrder(wordList) {
		if isStrongWord(word) {
			strongWords = append(strongWords, word)
		}
	}
	covered := 0
	for _, word := range strongWords {
		if WordMatches(word, queryWords) {
			covered++
		}
	}
	return math.Max(queryCoverage, memorySideWeight*(float64(covered)/math.Max(1, float64(len(strongWords)))))
}

func uniqueInOrder(items []string) []string {
	seen := make(map[string]bool, len(items))
	out := make([]string, 0, len(items))
	for _, item := range items {
		if !seen[item] {
			seen[item] = true
			out = append(out, item)
		}
	}
	return out
}

// TextCoverage is how much of a query's long words a text covers, for text
// outside the memory corpus. 0 unless at least two match, or the query has
// only one.
func TextCoverage(query, text string) float64 {
	var strong []string
	for _, word := range uniqueInOrder(WordsOf(query)) {
		if isStrongWord(word) {
			strong = append(strong, word)
		}
	}
	if len(strong) == 0 {
		return 0
	}
	words := wordSet(WordsOf(text))
	hits := 0
	for _, word := range strong {
		if WordMatches(word, words) {
			hits++
		}
	}
	if hits < min(2, len(strong)) {
		return 0
	}
	coverage := float64(hits) / float64(len(strong))
	if coverage >= runMatchCoverage {
		return coverage
	}
	return 0
}

// SemanticNoiseFloor is where unrelated text lies on the cosine scale of this
// model and query: the middle of the candidates, which are mostly unrelated.
func SemanticNoiseFloor(cosines []float64) float64 {
	sorted := make([]float64, 0, len(cosines))
	for _, c := range cosines {
		if c != 0 {
			sorted = append(sorted, c)
		}
	}
	if len(sorted) == 0 {
		return 0
	}
	sort.Float64s(sorted)
	median := sorted[len(sorted)/2]
	// A handful of memories may all be on topic, so their middle proves nothing.
	if len(sorted) >= minNoiseSample {
		return median
	}
	return math.Min(median, smallSampleNoise)
}

// CalibrateSemantic maps a cosine above the noise floor onto 0..1.
func CalibrateSemantic(cosine, noiseFloor float64) float64 {
	if !(cosine > noiseFloor) || noiseFloor >= 1 {
		return 0
	}
	return (cosine - noiseFloor) / (1 - noiseFloor)
}

func isLetter(r rune) bool { return unicode.IsLetter(r) }
