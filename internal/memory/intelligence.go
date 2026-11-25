package memory

import (
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"math"
	"regexp"
	"sort"
	"strings"
	"sync"
	"unicode"
	"unicode/utf8"

	"golang.org/x/text/collate"
	"golang.org/x/text/language"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// calendarWordList holds the month, weekday and time zone names of every UI
// language. Node builds the same set from Intl; see gen/calendar_words.js.
//
//go:embed calendar_words.txt
var calendarWordList string

var calendarWords = sync.OnceValue(func() map[string]bool {
	words := map[string]bool{}
	for _, w := range strings.Fields(calendarWordList) {
		words[w] = true
	}
	return words
})

const ws = jsx.SpaceClass

var (
	emailPattern   = regexp.MustCompile(`[^` + ws + `@<>()"',;]+@[^` + ws + `@<>()"',;]+\.[^` + ws + `@<>()"',;]+`)
	urlPattern     = regexp.MustCompile(`(?i)https?://[^` + ws + `)]+`)
	filePattern    = regexp.MustCompile(`(?i)\b[\p{L}\p{N}_./-]+\.(?:js|ts|dart|py|json|md|yaml|yml|sql|rs|go|java|kt|swift|css|html)\b`)
	trailingDots   = regexp.MustCompile(`\.+$`)
	trailingPunct  = regexp.MustCompile(`[.,;]+$`)
	sentenceStart  = regexp.MustCompile(`(?:^|[.!?:;\n])[` + ws + `"'“„‘(\[*•>#-]*$`)
	afterClockTime = regexp.MustCompile(`\d{1,2}:\d{2}(?::\d{2})?[` + ws + `]*\(?$`)
	headerLabel    = regexp.MustCompile(`(?:^|\n)[ \t]*$`)
	timezoneLabel  = regexp.MustCompile(`^[A-Z]{2,5}$`)
	digitBefore    = regexp.MustCompile(`\d[` + ws + `,./-]*$`)
	digitAfter     = regexp.MustCompile(`^[` + ws + `,./-]*\d`)
	calendarShape  = regexp.MustCompile(`^[A-Z\d` + ws + `]+$`)
	nonEntityChars = regexp.MustCompile(`[^\p{L}\p{N}._@:/+-]+`)
	nonAlnum       = regexp.MustCompile(`[^\p{L}\p{N}]+`)
	nonAlnumEnd    = regexp.MustCompile(`[^\p{L}\p{N}]+$`)
	keywordToken   = regexp.MustCompile(`[\p{L}\p{N}_-]{5,}`)
	allDigits      = regexp.MustCompile(`^\d+$`)
	noiseStart     = regexp.MustCompile(`^[<>(\["']`)
	headerWord     = regexp.MustCompile(`^\p{L}+:[` + ws + `]`)

	entityKinds = []struct {
		kind    string
		pattern *regexp.Regexp
	}{
		{"email", regexp.MustCompile(`^[^` + ws + `@]+@[^` + ws + `@]+\.[^` + ws + `@]+$`)},
		{"url", regexp.MustCompile(`(?i)^https?://`)},
		{"version", regexp.MustCompile(`^[vV]?\d+(?:\.\d+){1,3}$`)},
		{"file", regexp.MustCompile(`(?i)\.(js|ts|dart|py|json|md|yaml|yml|sql|rs|go|java|kt|swift|css|html)$`)},
		{"domain", regexp.MustCompile(`^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$`)},
		// (?=.*[\d_]) is checked in ClassifyEntity.
		{"identifier", regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_-]{2,}$`)},
		{"acronym", regexp.MustCompile(`^[A-Z][A-Z0-9_-]{2,}$`)},
	}
)

func isCalendarWord(word string) bool {
	value := nonAlnumEnd.ReplaceAllString(word, "")
	return allDigits.MatchString(value) || calendarWords()[jsx.Lower(value)]
}

// trimCalendarWords is "" for names made only of date parts ("Fri", "12 Aug").
// Mixed names stay whole: "Jan Müller" or "Karl May" are people, not dates.
func trimCalendarWords(name string) string {
	words := jsx.Fields(name)
	for _, w := range words {
		if !isCalendarWord(w) {
			return strings.Join(words, " ")
		}
	}
	return ""
}

// IsNoiseEntityName flags structural noise: header labels ("Date: Fri"),
// bracketed mail addresses, and names made only of date parts.
func IsNoiseEntityName(name string, inSentence bool) bool {
	value := jsx.Trim(name)
	return noiseStart.MatchString(value) ||
		headerWord.MatchString(value) ||
		(!inSentence && trimCalendarWords(value) != value) ||
		jsx.Len(nonAlnum.ReplaceAllString(value, "")) < 2
}

// StableHash is the digest memories are deduplicated by.
func StableHash(value string) string {
	sum := sha256.Sum256([]byte(jsx.Lower(jsx.Trim(value))))
	return hex.EncodeToString(sum[:])
}

// CanonicalEntityKey is the lookup key of an entity name.
func CanonicalEntityKey(name string) string {
	key := nonEntityChars.ReplaceAllString(jsx.Lower(jsx.Trim(name)), " ")
	return jsx.Head(jsx.ReplaceSpaceRuns(key), 160)
}

// ClassifyEntity names the kind of an entity: email, url, version, file,
// domain, identifier, acronym or concept.
func ClassifyEntity(name string) string {
	value := jsx.Trim(name)
	for _, k := range entityKinds {
		if !k.pattern.MatchString(value) {
			continue
		}
		if k.kind == "identifier" && !strings.ContainsAny(value, "0123456789_") {
			continue
		}
		return k.kind
	}
	return "concept"
}

type span struct{ start, end int }

func isWordByte(b byte) bool {
	return b == '_' || b >= '0' && b <= '9' || b >= 'a' && b <= 'z' || b >= 'A' && b <= 'Z'
}

func isLetterOrNumber(r rune) bool { return unicode.IsLetter(r) || unicode.IsNumber(r) }

// scanCapitalizedWord reads a word that starts at raw[i], an ASCII capital:
// letters, digits and _ + / -, and a . only when a letter or digit follows.
func scanCapitalizedWord(raw string, i int) int {
	j := i + 1
	for j < len(raw) {
		r, size := utf8.DecodeRuneInString(raw[j:])
		switch {
		case isLetterOrNumber(r) || r == '_' || r == '+' || r == '/' || r == '-':
			j += size
		case r == '.':
			next, _ := utf8.DecodeRuneInString(raw[j+1:])
			if j+1 >= len(raw) || !isLetterOrNumber(next) {
				return j
			}
			j++
		default:
			return j
		}
	}
	return j
}

// capitalizedPhrases finds runs of up to five capitalized words separated by
// spaces or tabs, starting at a word boundary.
func capitalizedPhrases(raw string) []span {
	var spans []span
	for i := 0; i < len(raw); {
		if raw[i] < 'A' || raw[i] > 'Z' || (i > 0 && isWordByte(raw[i-1])) {
			i++
			continue
		}
		end := scanCapitalizedWord(raw, i)
		for n := 0; n < 4; n++ {
			j := end
			for j < len(raw) && (raw[j] == ' ' || raw[j] == '\t') {
				j++
			}
			if j == end || j >= len(raw) || raw[j] < 'A' || raw[j] > 'Z' {
				break
			}
			end = scanCapitalizedWord(raw, j)
		}
		spans = append(spans, span{i, end})
		i = end
	}
	return spans
}

// EntityCandidate is a named thing found in text. InSentence is set when at
// least one occurrence was capitalized mid-sentence (or is structurally an
// entity: email, URL, file).
type EntityCandidate struct {
	Key        string
	Name       string
	Kind       string
	InSentence bool
}

type rawEntity struct {
	name       string
	inSentence bool
}

func capitalizedCandidates(raw string) []rawEntity {
	var candidates []rawEntity
	for _, m := range capitalizedPhrases(raw) {
		phrase := raw[m.start:m.end]
		before, after := raw[:m.start], raw[m.end:]
		if strings.HasPrefix(after, ":") && headerLabel.MatchString(before) {
			continue // header label
		}
		if timezoneLabel.MatchString(phrase) && afterClockTime.MatchString(before) {
			continue // timezone
		}
		inSentence := !sentenceStart.MatchString(before)
		// Calendar abbreviations can also be names. Only treat a mid-sentence
		// name as a date part beside digits, or as an uppercase timezone label.
		hasCalendarContext := digitBefore.MatchString(before) || digitAfter.MatchString(after) || calendarShape.MatchString(phrase)
		name := phrase
		if !inSentence || hasCalendarContext {
			name = trimCalendarWords(phrase)
		}
		if jsx.Len(name) < 3 {
			continue
		}
		if inSentence {
			candidates = append(candidates, rawEntity{name, true})
			continue
		}
		// Capitalization at a sentence start says nothing about the first word,
		// so keep the phrase and its tail, both unconfirmed; another memory has
		// to mention them mid-sentence before they count as entities.
		candidates = append(candidates, rawEntity{name, false})
		if parts := strings.Split(name, " "); len(parts) > 1 {
			if tail := strings.Join(parts[1:], " "); jsx.Len(tail) >= 3 {
				candidates = append(candidates, rawEntity{tail, false})
			}
		}
	}
	return candidates
}

// ExtractEntities finds the entities a text names, at most maxEntities.
func ExtractEntities(text string, maxEntities int) []EntityCandidate {
	var candidates []rawEntity
	for _, m := range emailPattern.FindAllString(text, -1) {
		candidates = append(candidates, rawEntity{trailingDots.ReplaceAllString(m, ""), true})
	}
	for _, m := range urlPattern.FindAllString(text, -1) {
		candidates = append(candidates, rawEntity{trailingPunct.ReplaceAllString(m, ""), true})
	}
	candidates = append(candidates, capitalizedCandidates(text)...)
	for _, m := range filePattern.FindAllString(text, -1) {
		candidates = append(candidates, rawEntity{m, true})
	}

	var order []string
	byKey := map[string]*EntityCandidate{}
	for _, c := range candidates {
		name := jsx.Head(jsx.Collapse(c.name), 160)
		key := CanonicalEntityKey(name)
		if key == "" || jsx.Len(key) < 2 || IsNoiseEntityName(name, c.inSentence) {
			continue
		}
		if existing, ok := byKey[key]; ok {
			existing.InSentence = existing.InSentence || c.inSentence
			continue
		}
		byKey[key] = &EntityCandidate{Key: key, Name: name, Kind: ClassifyEntity(name), InSentence: c.inSentence}
		order = append(order, key)
	}
	out := make([]EntityCandidate, 0, len(order))
	for _, key := range order {
		out = append(out, *byKey[key])
	}
	if len(out) > maxEntities {
		out = out[:maxEntities]
	}
	return out
}

// DefaultMaxEntities is how many entities one memory keeps.
const DefaultMaxEntities = 16

// CollectLowercaseWords adds the words the texts use in lowercase form to
// words. A capitalized word whose lowercase form is in there is an ordinary
// word that happened to start a sentence.
func CollectLowercaseWords(texts []string, words map[string]bool) map[string]bool {
	if words == nil {
		words = map[string]bool{}
	}
	for _, text := range texts {
		for i := 0; i < len(text); {
			r, size := utf8.DecodeRuneInString(text[i:])
			if !unicode.Is(unicode.Ll, r) || (i > 0 && afterLetterOrNumber(text, i)) {
				i += size
				continue
			}
			j := i + size
			for j < len(text) {
				next, nextSize := utf8.DecodeRuneInString(text[j:])
				if !unicode.IsLetter(next) {
					break
				}
				j += nextSize
			}
			words[text[i:j]] = true
			i = j
		}
	}
	return words
}

func afterLetterOrNumber(text string, i int) bool {
	prev, _ := utf8.DecodeLastRuneInString(text[:i])
	return isLetterOrNumber(prev)
}

// IsConfirmedEntity: an entity counts when some mention capitalized it
// mid-sentence, or when its first word is never written in lowercase (so it is
// not a common word).
func IsConfirmedEntity(name string, hasInSentenceMention bool, lowercaseWords map[string]bool) bool {
	if hasInSentenceMention {
		return true
	}
	first := ""
	if fields := jsx.Fields(name); len(fields) > 0 {
		first = fields[0]
	}
	return !lowercaseWords[jsx.Lower(first)]
}

var (
	collatorMu sync.Mutex
	collator   = collate.New(language.English)
)

func localeCompare(a, b string) int {
	collatorMu.Lock()
	defer collatorMu.Unlock()
	return collator.CompareString(a, b)
}

// ExtractKeywords lists the most frequent long words of a text.
func ExtractKeywords(text string, maxKeywords int) []string {
	counts := map[string]int{}
	var order []string
	for _, token := range keywordToken.FindAllString(jsx.Lower(text), -1) {
		if allDigits.MatchString(token) {
			continue
		}
		if counts[token] == 0 {
			order = append(order, token)
		}
		counts[token]++
	}
	sort.SliceStable(order, func(i, j int) bool {
		if counts[order[i]] != counts[order[j]] {
			return counts[order[i]] > counts[order[j]]
		}
		return localeCompare(order[i], order[j]) < 0
	})
	if len(order) > maxKeywords {
		order = order[:maxKeywords]
	}
	return order
}

// firstSentence is the first sentence of a trimmed text: it ends where a
// sentence mark is followed by whitespace, or at a line break.
func firstSentence(text string) string {
	runes := []rune(text)
	for i := 0; i < len(runes); i++ {
		r := runes[i]
		if r == '\n' || (i > 0 && (runes[i-1] == '.' || runes[i-1] == '!' || runes[i-1] == '?') && jsx.IsSpace(r)) {
			return jsx.Trim(string(runes[:i]))
		}
	}
	return jsx.Trim(text)
}

// Fact is one subject-predicate-object statement extracted from a memory.
type Fact struct {
	Subject    string
	Predicate  string
	Object     string
	Category   string
	Confidence float64
	EventTime  string
	ValidFrom  string
	ValidTo    string
	Relation   string
	Metadata   *jsx.Obj
}

// BuildFacts is the local fallback used when no model supplied structured
// facts (manual saves, imports): one memory-level fact anchored on the
// leading entity. sourceType may be "".
func BuildFacts(content, category, sourceType string) []Fact {
	text := jsx.Trim(content)
	if text == "" {
		return nil
	}
	entities := ExtractEntities(text, DefaultMaxEntities)
	keywords := ExtractKeywords(text, 10)
	predicate := strings.ReplaceAll(orDefault(category, "episodic"), "_", " ")
	confidence := 0.68
	if sourceType == "llm_import" {
		confidence = 0.74
	}
	var source any
	if sourceType != "" {
		source = sourceType
	}
	subject := predicate
	if len(entities) > 0 && entities[0].Name != "" {
		subject = entities[0].Name
	}
	object := firstSentence(text)
	if object == "" {
		object = text
	}
	return []Fact{{
		Subject:    jsx.Head(subject, 180),
		Predicate:  predicate,
		Object:     jsx.Head(object, 900),
		Category:   category,
		Confidence: confidence,
		Metadata:   jsx.O("keywords", keywords, "sourceType", source, "extractedBy", "local_memory_intelligence"),
	}}
}

func orDefault(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

// SummarizeForPrompt is the memory text with its first entity names appended.
func SummarizeForPrompt(content string, entityNames []string) string {
	text := jsx.Collapse(content)
	suffix := ""
	if len(entityNames) > 0 {
		suffix = " (" + strings.Join(entityNames[:min(4, len(entityNames))], ", ") + ")"
	}
	return jsx.Head(text+suffix, 900)
}

// Signals is the evidence for one recall candidate.
type Signals struct {
	Signal          float64
	SecondarySignal float64
	RouteBoost      float64
	Importance      float64
	Confidence      float64
	AccessCount     float64
	Retention       float64
}

// ScoreMemoryCandidate orders the memories that matched; importance,
// confidence and use never make a memory match. A row with no evidence for
// this query scores nothing.
func ScoreMemoryCandidate(s Signals) float64 {
	if !(s.Signal > 0) {
		return 0
	}
	quality := 0.9 + clamp(s.Importance, 1, 10, 5)/50
	confidenceMultiplier := 0.7 + clamp(s.Confidence, 0, 1, 0.7)*0.3
	usage := math.Min(0.03, math.Log1p(math.Max(0, s.AccessCount))/150)
	// A second kind of evidence beats a stronger single one only by a little.
	evidence := s.Signal + 0.15*s.SecondarySignal
	return evidence*(1+s.RouteBoost)*quality*confidenceMultiplier*s.Retention + usage
}
