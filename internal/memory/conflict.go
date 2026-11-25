package memory

import (
	"regexp"
	"sort"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Two statements with one value swapped read almost the same to an embedding
// and to a keyword match, yet the newer one replaces the older one. These
// checks look only at the shape of the text, so they work the same in every
// language.

const (
	sp  = jsx.SpaceClass
	nsp = `[^` + sp + `]`
)

var (
	valueToken = regexp.MustCompile(`(?i)^(?:v?\d[\d.,:/-]*[\p{L}%]{0,3}|[^` + sp + `@]+@[^` + sp + `@]+\.[^` + sp + `@]+|https?://` + nsp + `+)$`)
	// "in Rome in 2019" and "in Rome in 2021" are usually both true.
	yearToken      = regexp.MustCompile(`^(?:19|20)\d{2}$`)
	edgeTokenChars = regexp.MustCompile(`^[` + sp + `"'„“”‘’(\[]+|[` + sp + `"'“”‘’)\],.;:!?]+$`)
	upperStart     = regexp.MustCompile(`^\p{Lu}`)
)

const minSharedContext = 0.6

func tokensOf(text string) []string {
	var tokens []string
	for _, field := range jsx.Fields(text) {
		if token := edgeTokenChars.ReplaceAllString(field, ""); token != "" {
			tokens = append(tokens, token)
		}
	}
	return tokens
}

func isValueToken(token string) bool { return valueToken.MatchString(token) }

// namesOf: capitalized words after the first name what a statement is about.
func namesOf(tokens []string) string {
	var names []string
	for _, token := range tokens[min(1, len(tokens)):] {
		if !isValueToken(token) && upperStart.MatchString(token) {
			names = append(names, jsx.Lower(token))
		}
	}
	sort.Strings(names)
	return strings.Join(names, "\x00")
}

func contextWords(tokens []string) map[string]bool {
	words := map[string]bool{}
	for _, token := range tokens {
		if !isValueToken(token) && jsx.Len(token) >= 3 {
			words[jsx.Lower(token)] = true
		}
	}
	return words
}

func contextOverlap(left, right []string) float64 {
	a, b := contextWords(left), contextWords(right)
	if len(a) == 0 || len(b) == 0 {
		return 0
	}
	shared := 0
	for word := range a {
		if b[word] {
			shared++
		}
	}
	return float64(shared) / float64(min(len(a), len(b)))
}

// followingWord is the lowercased token after value; like the JavaScript it
// replaces, a value that is not found reads the first token.
func followingWord(tokens []string, value string) (string, bool) {
	index := -1
	for i, token := range tokens {
		if jsx.Lower(token) == value {
			index = i
			break
		}
	}
	if index+1 >= len(tokens) {
		return "", false
	}
	word := jsx.Lower(tokens[index+1])
	return word, word != ""
}

func valueSet(tokens []string) map[string]bool {
	values := map[string]bool{}
	for _, token := range tokens {
		if isValueToken(token) {
			values[jsx.Lower(token)] = true
		}
	}
	return values
}

func valueList(tokens []string) []string {
	var list []string
	seen := map[string]bool{}
	for _, token := range tokens {
		if isValueToken(token) {
			if v := jsx.Lower(token); !seen[v] {
				seen[v] = true
				list = append(list, v)
			}
		}
	}
	return list
}

func without(values []string, set map[string]bool) []string {
	var out []string
	for _, v := range values {
		if !set[v] {
			out = append(out, v)
		}
	}
	return out
}

// IsValueChange is true when both statements say the same thing except for one
// number, address or similar value: "port 5544" and "port 5600". Names are
// left out on purpose, because "Neo's sister is Anna" and "Neo's sister is
// Maria" can both be true.
func IsValueChange(nextText, previousText string) bool {
	next, previous := tokensOf(nextText), tokensOf(previousText)
	added := without(valueList(next), valueSet(previous))
	removed := without(valueList(previous), valueSet(next))
	if len(added) != 1 || len(removed) != 1 {
		return false
	}
	if yearToken.MatchString(added[0]) || yearToken.MatchString(removed[0]) {
		return false
	}
	if namesOf(next) != namesOf(previous) {
		return false
	}
	if contextOverlap(next, previous) < minSharedContext {
		return false
	}
	// "has 2 cats" and "has 3 dogs" count different things.
	nextFollowing, nextOK := followingWord(next, added[0])
	previousFollowing, previousOK := followingWord(previous, removed[0])
	return !nextOK || !previousOK || nextFollowing == previousFollowing
}

// ValuesDiffer is true when the statements disagree on a value: a reworded
// copy keeps its numbers.
func ValuesDiffer(left, right string) bool {
	a, b := valueSet(tokensOf(left)), valueSet(tokensOf(right))
	if len(a) == 0 || len(b) == 0 {
		return false
	}
	return hasMissing(a, b) && hasMissing(b, a)
}

func hasMissing(from, in map[string]bool) bool {
	for v := range from {
		if !in[v] {
			return true
		}
	}
	return false
}

// SharesContentWord: a reworded copy still shares a real word with the
// original, and merging two facts destroys one of them.
func SharesContentWord(left, right string) bool {
	words := func(text string) map[string]bool {
		set := map[string]bool{}
		for _, token := range tokensOf(text) {
			if jsx.Len(token) >= 4 && !isValueToken(token) {
				set[jsx.Lower(token)] = true
			}
		}
		return set
	}
	a, b := words(left), words(right)
	for word := range b {
		if a[word] {
			return true
		}
	}
	return false
}

// IsOneWordSwap: "prefers dark mode" and "prefers light mode" embed as near
// duplicates. A single swapped word cannot prove a replacement, but it does
// prove they are not the same statement.
func IsOneWordSwap(left, right string) bool {
	lower := func(text string) []string {
		tokens := tokensOf(text)
		for i, t := range tokens {
			tokens[i] = jsx.Lower(t)
		}
		return tokens
	}
	a, b := lower(left), lower(right)
	if len(a) != len(b) || len(a) < 3 {
		return false
	}
	remaining := append([]string(nil), b...)
	unmatched := 0
	for _, word := range a {
		found := -1
		for i, r := range remaining {
			if r == word {
				found = i
				break
			}
		}
		if found >= 0 {
			remaining = append(remaining[:found], remaining[found+1:]...)
		} else {
			unmatched++
		}
	}
	return unmatched == 1
}
