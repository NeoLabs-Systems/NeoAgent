package memory

import (
	"context"
	"encoding/json"
	"math"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Embedding is a vector with the model that made it.
type Embedding struct {
	Vector     []float32
	Provider   string
	Model      string
	Dimensions int
}

// EmbedRequest asks for the embedding of one text. InputType is "query" for a
// recall query and "document" for text that is stored.
type EmbedRequest struct {
	Text      string
	InputType string
	UserID    int64
	AgentID   string
}

// Embedder turns text into vectors; the AI provider layer implements it and
// picks the model for the account and agent. A nil result with a nil error
// means no embedding provider is available: memory then works on keywords
// alone, as it does in Node without an API key.
type Embedder interface {
	Embed(ctx context.Context, req EmbedRequest) (*Embedding, error)
}

// SameEmbeddingSpace is true when the same model made both vectors at the same
// size. The identity is what the provider declares for the space, never
// inferred from a name: a guessed match returns wrong memories while recall
// looks healthy.
func SameEmbeddingSpace(leftProvider, leftModel string, leftDims int, rightProvider, rightModel string, rightDims int) bool {
	return leftProvider != "" && leftModel != "" &&
		leftProvider == rightProvider && leftModel == rightModel &&
		leftDims > 0 && leftDims == rightDims
}

// Cosine is the cosine similarity of two vectors: 0 for vectors that cannot be
// compared. Products are summed in float64, as JavaScript does.
func Cosine(a, b []float32) float64 {
	if a == nil || b == nil || len(a) != len(b) {
		return 0
	}
	var dot, magA, magB float64
	for i := range a {
		x, y := float64(a[i]), float64(b[i])
		dot += x * y
		magA += x * x
		magB += y * y
	}
	denom := math.Sqrt(magA) * math.Sqrt(magB)
	if denom == 0 {
		return 0
	}
	return dot / denom
}

// SerializeEmbedding is the JSON text stored in memories.embedding.
func SerializeEmbedding(vec []float32) string {
	var b strings.Builder
	b.Grow(len(vec) * 12)
	b.WriteByte('[')
	for i, v := range vec {
		if i > 0 {
			b.WriteByte(',')
		}
		b.WriteString(jsx.FormatNumber(float64(v)))
	}
	b.WriteByte(']')
	return b.String()
}

// DeserializeEmbedding reads stored embedding text; nil when it is empty or
// not a list of numbers.
func DeserializeEmbedding(text string) []float32 {
	if text == "" {
		return nil
	}
	var values []float64
	if err := json.Unmarshal([]byte(text), &values); err != nil {
		return nil
	}
	vec := make([]float32, len(values))
	for i, v := range values {
		vec[i] = float32(v)
	}
	return vec
}

var nonWord = regexp.MustCompile(`[^\p{L}\p{N}_]+`)

// KeywordSimilarity is the fallback similarity when embeddings are unavailable:
// term overlap between 0 and 1.
func KeywordSimilarity(query, text string) float64 {
	if query == "" || text == "" {
		return 0
	}
	tokens := func(s string) []string {
		var out []string
		for _, t := range nonWord.Split(jsx.Lower(s), -1) {
			if jsx.Len(t) > 2 {
				out = append(out, t)
			}
		}
		return out
	}
	queryTokens := map[string]bool{}
	for _, t := range tokens(query) {
		queryTokens[t] = true
	}
	textTokens := tokens(text)
	if len(queryTokens) == 0 || len(textTokens) == 0 {
		return 0
	}
	hits := 0
	for _, t := range textTokens {
		if queryTokens[t] {
			hits++
		}
	}
	return float64(hits) / float64(max(len(queryTokens), len(textTokens)))
}
