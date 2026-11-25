package memory

import (
	"context"
	"regexp"
	"strings"
	"sync"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/replay"
)

// hashEmbedder is the stand-in embedding model of gen/semantic.js.
type hashEmbedder struct {
	mu    sync.Mutex
	calls []string
}

var embedWord = regexp.MustCompile(`[a-z0-9]+`)

func (e *hashEmbedder) Embed(_ context.Context, req EmbedRequest) (*Embedding, error) {
	if strings.TrimSpace(req.Text) == "" {
		return nil, nil
	}
	e.mu.Lock()
	e.calls = append(e.calls, req.InputType)
	e.mu.Unlock()
	const dims = 16
	vector := make([]float32, dims)
	for _, word := range embedWord.FindAllString(strings.ToLower(req.Text), -1) {
		h := 0
		for i := 0; i < len(word); i++ {
			h = (h*31 + int(word[i])) % 65521
		}
		vector[h%dims]++
		vector[int(word[0])%dims] += 0.25
	}
	return &Embedding{Vector: vector, Provider: "test", Model: "hash-16", Dimensions: dims}, nil
}

// TestReplaysNodeSemanticConversation plays gen/semantic.js: recall,
// duplicate detection and the embedding index on vectors.
func TestReplaysNodeSemanticConversation(t *testing.T) {
	sc := replay.Load(t, "testdata/semantic.json")
	var extra struct {
		EmbedCalls []string `json:"embedCalls"`
	}
	replay.Unmarshal(t, replay.Raw(t, "testdata/semantic.json"), &extra)
	embedder := &hashEmbedder{}
	db, srv, _ := newReplayStack(t, nil, embedder, false)
	play(t, sc, db, srv)
	compareSnapshot(t, sc, db, [][2]string{
		{"memories", `SELECT id, content, category, importance, access_count, memory_strength, confidence, embedding, embedding_provider, embedding_model, embedding_dimensions FROM memories ORDER BY id`},
		{"memory_embedding_bands", `SELECT memory_id, dimension, index_version, band_index, band_value FROM memory_embedding_bands ORDER BY memory_id, band_index`},
		{"memory_relations", `SELECT from_memory_id, to_memory_id, relation_type, confidence, metadata_json FROM memory_relations ORDER BY from_memory_id, to_memory_id`},
	})
	if got, want := strings.Join(embedder.calls, ","), strings.Join(extra.EmbedCalls, ","); got != want {
		t.Errorf("embedding requests\n got  %s\n want %s", got, want)
	}
}

// TestReplaysNodeIngestion plays gen/ingestion.js: documents stored through a
// running ingestion service, and the coverage of seeded connections.
func TestReplaysNodeIngestion(t *testing.T) {
	sc := replay.Load(t, "testdata/ingestion.json")
	db, srv, _ := newReplayStack(t, nil, nil, true)
	play(t, sc, db, srv)
	compareSnapshot(t, sc, db, [][2]string{
		{"memory_ingestion_documents", `SELECT id, agent_id, source_type, normalized_type, provider_key, connection_id, external_object_id, source_account, title, content, summary, salience, source_timestamp, metadata_json, payload_json FROM memory_ingestion_documents ORDER BY id`},
		{"memory_source_chunks", `SELECT id, document_id, chunk_index, char_start, char_end, content, content_hash, metadata_json FROM memory_source_chunks ORDER BY document_id, chunk_index`},
		{"memory_ingestion_jobs", `SELECT id, agent_id, source_type, provider_key, connection_id, status, summary_json, metadata_json, document_count, error_text, completed_at IS NOT NULL AS completed FROM memory_ingestion_jobs ORDER BY id`},
	})
}
