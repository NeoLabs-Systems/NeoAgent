package agent

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
)

// Tool retrieval (tool_retrieval.js): finds tools by what a request means, in
// whatever language it is in, with the memory system's embedding provider.
// Without one, or when it is slow or failing, matching words is what is left.

const (
	retrievalQueryBudget = 800 * time.Millisecond
	rankedTools          = 12
	maxToolDocumentChars = 2000
	warmConcurrency      = 3
	warmRetry            = 10 * time.Minute
	minEmbeddedShare     = 0.8
)

// One embedding space, as its provider declares it: "provider:model:dimensions:digest".
var vectorKeyPattern = regexp.MustCompile(`^[^:]+:[^:]+:\d+:[0-9a-f]{64}$`)

// toolVectors are the embedded tool documents. They change rarely and cost a
// call each, so they outlive a restart in tool_vectors.json.
type toolVectors struct {
	path       string
	once       sync.Once
	mu         sync.Mutex
	vectors    map[string][]float32
	warming    map[string]bool
	warmFailed map[string]time.Time
}

func newToolVectors(dataDir string) *toolVectors {
	v := &toolVectors{vectors: map[string][]float32{}, warming: map[string]bool{}, warmFailed: map[string]time.Time{}}
	if dataDir != "" {
		v.path = filepath.Join(dataDir, "tool_vectors.json")
	}
	return v
}

func (v *toolVectors) load() {
	v.once.Do(func() {
		if v.path == "" {
			return
		}
		raw, err := os.ReadFile(v.path)
		if err != nil {
			return
		}
		var stored map[string]string
		if json.Unmarshal(raw, &stored) != nil {
			return
		}
		for key, encoded := range stored {
			if !vectorKeyPattern.MatchString(key) {
				continue
			}
			bytes, err := base64.StdEncoding.DecodeString(encoded)
			if err != nil || len(bytes)%4 != 0 {
				continue
			}
			vector := make([]float32, len(bytes)/4)
			for i := range vector {
				vector[i] = math.Float32frombits(binary.LittleEndian.Uint32(bytes[i*4:]))
			}
			v.vectors[key] = vector
		}
	})
}

func (v *toolVectors) save() {
	if v.path == "" {
		return
	}
	v.mu.Lock()
	stored := make(map[string]string, len(v.vectors))
	for key, vector := range v.vectors {
		bytes := make([]byte, len(vector)*4)
		for i, f := range vector {
			binary.LittleEndian.PutUint32(bytes[i*4:], math.Float32bits(f))
		}
		stored[key] = base64.StdEncoding.EncodeToString(bytes)
	}
	v.mu.Unlock()
	raw, _ := json.Marshal(stored)
	temporary := fmt.Sprintf("%s.%d.tmp", v.path, os.Getpid())
	if err := os.WriteFile(temporary, raw, 0o600); err != nil {
		_ = os.Remove(temporary)
		return
	}
	if err := os.Rename(temporary, v.path); err != nil {
		_ = os.Remove(temporary)
	}
}

func toolDocument(registry *tools.Registry, tool *tools.Definition) string {
	meta := registry.Meta(tool.Name, tool)
	var parts []string
	for _, p := range []string{strings.ReplaceAll(tool.Name, "_", " "), tool.Description, strings.Join(meta.Capabilities, " "), strings.Join(meta.WhenToUse, " ")} {
		if p != "" {
			parts = append(parts, p)
		}
	}
	return utf16Head(strings.Join(parts, "\n"), maxToolDocumentChars)
}

func utf16Head(s string, units int) string {
	n := 0
	for i, r := range s {
		size := 1
		if r > 0xFFFF {
			size = 2
		}
		if n+size > units {
			return s[:i]
		}
		n += size
	}
	return s
}

func vectorKey(e *memory.Embedding, document string) string {
	digest := sha256.Sum256([]byte(document))
	dimensions := e.Dimensions
	if dimensions == 0 {
		dimensions = len(e.Vector)
	}
	return fmt.Sprintf("%s:%s:%d:%s", e.Provider, e.Model, dimensions, hex.EncodeToString(digest[:]))
}

func cosine(a, b []float32) float64 {
	var dot, an, bn float64
	for i := range a {
		dot += float64(a[i]) * float64(b[i])
		an += float64(a[i]) * float64(a[i])
		bn += float64(b[i]) * float64(b[i])
	}
	if an == 0 || bn == 0 {
		return 0
	}
	return dot / math.Sqrt(an*bn)
}

// warm embeds the tool documents in the background; a run never waits for it,
// and the next one has them. A failing provider is left alone for a while.
func (v *toolVectors) warm(embedder memory.Embedder, registry *tools.Registry, all []tools.Definition, query *memory.Embedding, userID int64, agentID string) {
	warmKey := query.Provider + ":" + query.Model
	v.mu.Lock()
	var pending []string
	for i := range all {
		document := toolDocument(registry, &all[i])
		if _, ok := v.vectors[vectorKey(query, document)]; document != "" && !ok {
			pending = append(pending, document)
		}
	}
	if len(pending) == 0 || v.warming[warmKey] || time.Since(v.warmFailed[warmKey]) < warmRetry {
		v.mu.Unlock()
		return
	}
	v.warming[warmKey] = true
	v.mu.Unlock()
	go func() {
		jobs := make(chan string)
		var wg sync.WaitGroup
		var failedMu sync.Mutex
		failed := 0
		for range warmConcurrency {
			wg.Add(1)
			go func() {
				defer wg.Done()
				for document := range jobs {
					e, err := embedder.Embed(context.Background(), memory.EmbedRequest{Text: document, InputType: "document", UserID: userID, AgentID: agentID})
					if err != nil || e == nil || len(e.Vector) == 0 {
						failedMu.Lock()
						failed++
						failedMu.Unlock()
						continue
					}
					v.mu.Lock()
					v.vectors[vectorKey(e, document)] = e.Vector
					v.mu.Unlock()
				}
			}()
		}
		for _, document := range pending {
			jobs <- document
		}
		close(jobs)
		wg.Wait()
		v.save()
		v.mu.Lock()
		if failed > 0 {
			v.warmFailed[warmKey] = time.Now()
		} else {
			delete(v.warmFailed, warmKey)
		}
		delete(v.warming, warmKey)
		v.mu.Unlock()
	}()
}

// retrieveTools returns the tools closest to a request, best first; which of
// them get activated is the selector's call.
func (e *Engine) retrieveTools(ctx context.Context, registry *tools.Registry, all []tools.Definition, request string, userID int64, agentID string) []Retrieved {
	text := strings.TrimSpace(request)
	if text == "" {
		return nil
	}
	if embedder := e.deps.Embedder; embedder != nil {
		e.vectors.load()
		budget, cancel := context.WithTimeout(ctx, retrievalQueryBudget)
		query, err := embedder.Embed(budget, memory.EmbedRequest{Text: text, InputType: "query", UserID: userID, AgentID: agentID})
		cancel()
		if err == nil && query != nil && len(query.Vector) > 0 {
			e.vectors.warm(embedder, registry, all, query, userID, agentID)
			var ranked []Retrieved
			e.vectors.mu.Lock()
			for i := range all {
				vector := e.vectors.vectors[vectorKey(query, toolDocument(registry, &all[i]))]
				if len(vector) == len(query.Vector) {
					ranked = append(ranked, Retrieved{Name: all[i].Name, Similarity: math.Round(cosine(query.Vector, vector)*1000) / 1000})
				}
			}
			e.vectors.mu.Unlock()
			sort.SliceStable(ranked, func(i, j int) bool { return ranked[i].Similarity > ranked[j].Similarity })
			// Part of the list is no ranking at all: a tool not embedded yet could not win.
			if float64(len(ranked)) >= float64(len(all))*minEmbeddedShare {
				if len(ranked) > rankedTools {
					ranked = ranked[:rankedTools]
				}
				return ranked
			}
		}
	}
	// Sharing a common word with a description says nothing: it takes a word of the tool's own name.
	var out []Retrieved
	for _, hit := range (selector{registry}).searchMin(all, text, rankedTools, 7, nil, nil) {
		out = append(out, Retrieved{Name: hit.Name, Similarity: math.NaN()})
	}
	return out
}
