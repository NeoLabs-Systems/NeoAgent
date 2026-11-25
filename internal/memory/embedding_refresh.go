package memory

import (
	"context"
	"database/sql"
	"sync"
)

// A memory saved while embedding was failing, or embedded by a model no longer
// in use, cannot be found by meaning: its vector is missing or cannot be
// compared. These are embedded again a few at a time, newest first, until none
// are left.
const refreshBatchSize = 20

// refresher remembers which memories it already tried: each is tried once per
// process, so a router that answers with different models in turn does not
// keep the same memories cycling between them.
type refresher struct {
	m         *Manager
	mu        sync.Mutex
	attempted map[string]bool
}

func newRefresher(m *Manager) *refresher { return &refresher{m: m, attempted: map[string]bool{}} }

type embedRow struct {
	id         string
	userID     int64
	agentID    string
	content    string
	provider   string
	model      string
	dimensions int
}

func (r *refresher) wasAttempted(id string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.attempted[id]
}

func (r *refresher) mark(id string, attempted bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if attempted {
		r.attempted[id] = true
	} else {
		delete(r.attempted, id)
	}
}

func (r *refresher) memoriesToEmbed(ctx context.Context, limit int) ([]embedRow, error) {
	q := r.m.db.W
	scan := func(sc rowScanner) (embedRow, error) {
		var x embedRow
		var agent, provider, model sql.NullString
		var dims sql.NullInt64
		err := sc.Scan(&x.id, &x.userID, &agent, &x.content, &provider, &model, &dims)
		x.agentID, x.provider, x.model, x.dimensions = agent.String, provider.String, model.String, int(dims.Int64)
		return x, err
	}
	missing, err := collect(ctx, q, scan,
		`SELECT id, user_id, agent_id, content, embedding_provider, embedding_model, embedding_dimensions FROM memories
     WHERE archived = 0 AND embedding IS NULL AND trim(content) != ''
     ORDER BY updated_at DESC`)
	if err != nil {
		return nil, err
	}
	var batch []embedRow
	for _, row := range missing {
		if !r.wasAttempted(row.id) && len(batch) < limit {
			batch = append(batch, row)
		}
	}
	if len(batch) > 0 {
		return batch, nil
	}

	// The model a user's newest memory was embedded with is the one their
	// queries use.
	type space struct {
		provider, model string
		dimensions      int
	}
	type current struct {
		userID int64
		space  space
	}
	currents, err := collect(ctx, q, func(sc rowScanner) (current, error) {
		var c current
		var provider, model sql.NullString
		var dims sql.NullInt64
		var embeddedAt sql.NullString
		err := sc.Scan(&c.userID, &provider, &model, &dims, &embeddedAt)
		c.space = space{provider.String, model.String, int(dims.Int64)}
		return c, err
	}, `SELECT user_id, embedding_provider, embedding_model, embedding_dimensions, MAX(embedded_at)
     FROM memories WHERE embedded_at IS NOT NULL GROUP BY user_id`)
	if err != nil {
		return nil, err
	}
	byUser := map[int64]space{}
	for _, c := range currents {
		byUser[c.userID] = c.space
	}
	embedded, err := collect(ctx, q, scan,
		`SELECT id, user_id, agent_id, content, embedding_provider, embedding_model, embedding_dimensions FROM memories
     WHERE archived = 0 AND embedding IS NOT NULL AND trim(content) != ''
     ORDER BY updated_at DESC`)
	if err != nil {
		return nil, err
	}
	for _, row := range embedded {
		cur, ok := byUser[row.userID]
		if r.wasAttempted(row.id) || !ok || SameEmbeddingSpace(row.provider, row.model, row.dimensions, cur.provider, cur.model, cur.dimensions) {
			continue
		}
		if len(batch) < limit {
			batch = append(batch, row)
		}
	}
	return batch, nil
}

// refresh embeds one batch. It returns how many it embedded, and
// providerSilent when the provider gave nothing (with nothing embedded), so the
// caller can wait before asking again.
func (r *refresher) refresh(ctx context.Context, limit int) (embedded int, providerSilent bool, err error) {
	rows, err := r.memoriesToEmbed(ctx, limit)
	if err != nil {
		return 0, false, err
	}
	for _, row := range rows {
		r.mark(row.id, true)
		result, embedErr := r.m.embed(ctx, row.content, "document", row.userID, row.agentID)
		if embedErr != nil || result == nil || result.Vector == nil {
			r.mark(row.id, false)
			return embedded, embedded == 0, nil
		}
		serialized := SerializeEmbedding(result.Vector)
		dims := result.Dimensions
		if dims == 0 {
			dims = len(result.Vector)
		}
		if _, err := r.m.db.W.ExecContext(ctx,
			`UPDATE memories
       SET embedding = ?, embedding_provider = ?, embedding_model = ?, embedding_dimensions = ?,
           embedded_at = datetime('now')
       WHERE id = ?`, serialized, result.Provider, result.Model, dims, row.id); err != nil {
			return embedded, false, err
		}
		if err := replaceEmbeddingIndex(ctx, r.m.db.W, row.id, row.userID, row.agentID, result.Vector); err != nil {
			return embedded, false, err
		}
		embedded++
	}
	return embedded, false, nil
}
