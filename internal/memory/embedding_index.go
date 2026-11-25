package memory

import (
	"context"
	"sort"
)

// Embedding bands are a locality-sensitive index over stored vectors: each
// vector gets bandCount bands of bitsPerBand sign bits, sampled at fixed
// coordinates. A query probes every band value within two flipped bits, and
// memories that share the most bands are the vector candidates.
const (
	bandCount             = 10
	bitsPerBand           = 14
	indexVersion          = 3
	defaultCandidateLimit = 600
)

// Band is one band of one vector.
type Band struct {
	Index     int
	Value     int
	Dimension int
}

func sampledCoordinate(dimension, bandIndex, bitIndex int) int {
	// Math.imul and the unsigned shifts of the Node code are 32-bit wraparound.
	value := uint32(bandIndex+1)*0x9e3779b1 ^ uint32(bitIndex+1)*0x85ebca6b
	value ^= value >> 16
	value *= 0x7feb352d
	value ^= value >> 15
	return int(value % uint32(dimension))
}

// CreateEmbeddingBands computes the bands of a vector; none for a short one.
func CreateEmbeddingBands(vector []float32) []Band {
	if len(vector) < bitsPerBand {
		return nil
	}
	bands := make([]Band, 0, bandCount)
	for bandIndex := 0; bandIndex < bandCount; bandIndex++ {
		value := 0
		for bitIndex := 0; bitIndex < bitsPerBand; bitIndex++ {
			coordinate := sampledCoordinate(len(vector), bandIndex, bitIndex)
			if vector[coordinate] >= 0 {
				value |= 1 << bitIndex
			}
		}
		bands = append(bands, Band{Index: bandIndex, Value: value, Dimension: len(vector)})
	}
	return bands
}

func replaceEmbeddingIndex(ctx context.Context, q queryer, memoryID string, userID int64, agentID string, vector []float32) error {
	bands := CreateEmbeddingBands(vector)
	return atomically(ctx, q, func(q queryer) error {
		if _, err := q.ExecContext(ctx, `DELETE FROM memory_embedding_bands WHERE memory_id = ?`, memoryID); err != nil {
			return err
		}
		for _, band := range bands {
			if _, err := q.ExecContext(ctx,
				`INSERT INTO memory_embedding_bands (
				   memory_id, user_id, agent_id, dimension, index_version, band_index, band_value, updated_at
				 ) VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
				memoryID, userID, agentID, band.Dimension, indexVersion, band.Index, band.Value); err != nil {
				return err
			}
		}
		return nil
	})
}

// bandProbes lists, per band, the value itself and every value one or two bits
// away from it.
func bandProbes(vector []float32) (probes [][]int, bandIndexes []int) {
	for _, band := range CreateEmbeddingBands(vector) {
		values := []int{band.Value}
		for bit := 0; bit < bitsPerBand; bit++ {
			values = append(values, band.Value^(1<<bit))
			for second := bit + 1; second < bitsPerBand; second++ {
				values = append(values, band.Value^(1<<bit)^(1<<second))
			}
		}
		probes = append(probes, values)
		bandIndexes = append(bandIndexes, band.Index)
	}
	return probes, bandIndexes
}

// EmbeddingCandidate is a memory whose bands match a query vector.
type EmbeddingCandidate struct {
	MemoryID    string
	BandMatches int
}

// CandidateSearch narrows findEmbeddingCandidates.
type CandidateSearch struct {
	UserID   int64
	AgentID  string
	Vector   []float32
	Provider string // restrict to memories embedded by this provider and model
	Model    string
	Limit    int
}

func findEmbeddingCandidates(ctx context.Context, q queryer, s CandidateSearch) ([]EmbeddingCandidate, error) {
	probes, bandIndexes := bandProbes(s.Vector)
	if len(probes) == 0 {
		return nil, nil
	}
	space := ""
	if s.Provider != "" && s.Model != "" {
		space = s.Provider + ":" + s.Model
	}
	var order []string
	matches := map[string]int{}
	for i, values := range probes {
		args := []any{s.UserID, s.AgentID, len(s.Vector), indexVersion, bandIndexes[i]}
		args = append(args, anySlice(values)...)
		args = append(args, space, space)
		ids, err := collect(ctx, q, scanString,
			`SELECT bands.memory_id
			 FROM memory_embedding_bands bands
			 JOIN memories memory ON memory.id = bands.memory_id
			 WHERE bands.user_id = ?
			   AND bands.agent_id = ?
			   AND bands.dimension = ?
			   AND bands.index_version = ?
			   AND bands.band_index = ?
			   AND bands.band_value IN (`+placeholders(len(values))+`)
			   AND (
			     ? = ''
			     OR (memory.embedding_provider || ':' || memory.embedding_model) = ?
			   )`, args...)
		if err != nil {
			return nil, err
		}
		for _, id := range ids {
			if matches[id] == 0 {
				order = append(order, id)
			}
			matches[id]++
		}
	}
	sort.SliceStable(order, func(i, j int) bool { return matches[order[i]] > matches[order[j]] })
	limit := s.Limit
	if limit == 0 {
		limit = defaultCandidateLimit
	}
	limit = max(1, min(limit, 2000))
	if len(order) > limit {
		order = order[:limit]
	}
	out := make([]EmbeddingCandidate, len(order))
	for i, id := range order {
		out[i] = EmbeddingCandidate{MemoryID: id, BandMatches: matches[id]}
	}
	return out, nil
}

// BackfillEmbeddingIndex indexes up to limit memories that have an embedding
// but no bands yet, newest first. It returns how many it indexed.
func BackfillEmbeddingIndex(ctx context.Context, q queryer, limit int) (int, error) {
	if limit == 0 {
		limit = 500
	}
	type row struct {
		id        string
		userID    int64
		agentID   string
		embedding string
	}
	rows, err := collect(ctx, q, func(r rowScanner) (row, error) {
		var x row
		var agent *string
		err := r.Scan(&x.id, &x.userID, &agent, &x.embedding)
		if agent != nil {
			x.agentID = *agent
		}
		return x, err
	}, `SELECT m.id, m.user_id, m.agent_id, m.embedding
	    FROM memories m
	    LEFT JOIN memory_embedding_bands idx
	      ON idx.memory_id = m.id AND idx.index_version = ?
	    WHERE m.archived = 0
	      AND m.embedding IS NOT NULL
	      AND idx.memory_id IS NULL
	    ORDER BY m.updated_at DESC
	    LIMIT ?`, indexVersion, max(1, min(limit, 5000)))
	if err != nil {
		return 0, err
	}
	for _, r := range rows {
		if err := replaceEmbeddingIndex(ctx, q, r.id, r.userID, r.agentID, DeserializeEmbedding(r.embedding)); err != nil {
			return 0, err
		}
	}
	return len(rows), nil
}
