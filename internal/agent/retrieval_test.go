package agent

import (
	"context"
	"math"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
)

// keywordEmbedder puts a text on the "weather" axis or the "mail" axis.
type keywordEmbedder struct {
	mu    sync.Mutex
	calls int
}

func (k *keywordEmbedder) Embed(_ context.Context, req memory.EmbedRequest) (*memory.Embedding, error) {
	k.mu.Lock()
	k.calls++
	k.mu.Unlock()
	text := strings.ToLower(req.Text)
	v := []float32{0.01, 0.01}
	if strings.Contains(text, "wetter") || strings.Contains(text, "web search") {
		v[0] = 1
	}
	if strings.Contains(text, "mail") {
		v[1] = 1
	}
	return &memory.Embedding{Vector: v, Provider: "fake", Model: "m", Dimensions: 2}, nil
}

func TestRetrieveToolsByMeaningThenWords(t *testing.T) {
	registry, err := tools.NewRegistry(registryEnv{})
	if err != nil {
		t.Fatal(err)
	}
	all := registry.Definitions()
	dir := t.TempDir()

	// Without an embedder, a word of a tool's own name finds it.
	e := &Engine{vectors: newToolVectors(dir)}
	words := e.retrieveTools(context.Background(), registry, all, "web search for news", 1, "a")
	if len(words) == 0 || !math.IsNaN(words[0].Similarity) {
		t.Fatalf("word retrieval %+v", words)
	}

	emb := &keywordEmbedder{}
	e = &Engine{vectors: newToolVectors(dir), deps: Deps{Embedder: emb, DataDir: dir}}
	// The first run warms the vectors in the background.
	e.retrieveTools(context.Background(), registry, all, "wie wird das wetter", 1, "a")
	deadline := time.Now().Add(5 * time.Second)
	for {
		e.vectors.mu.Lock()
		done := len(e.vectors.warming) == 0 && len(e.vectors.vectors) >= len(all)
		e.vectors.mu.Unlock()
		if done || time.Now().After(deadline) {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	ranked := e.retrieveTools(context.Background(), registry, all, "wie wird das wetter", 1, "a")
	if len(ranked) != rankedTools || math.IsNaN(ranked[0].Similarity) || ranked[0].Similarity < 0.9 {
		t.Fatalf("ranked %+v", ranked)
	}
	// The vectors outlive a restart.
	reloaded := newToolVectors(dir)
	reloaded.load()
	if len(reloaded.vectors) < len(all) {
		t.Fatalf("reloaded %d of %d", len(reloaded.vectors), len(all))
	}
}
