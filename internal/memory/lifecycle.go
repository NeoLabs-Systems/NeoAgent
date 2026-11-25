package memory

import (
	"context"
	"time"
)

const (
	indexBackfillBatch           = 500
	indexBackfillPause           = 25 * time.Millisecond
	embeddingRefreshGap          = time.Minute
	embeddingRetryAfter          = 10 * time.Minute
	reconcileEvery               = 6 * time.Hour
	defaultMinimumFactConfidence = 0.35
)

// Start runs the memory upkeep in the background until Stop or ctx ends: it
// indexes embeddings that have no bands, embeds memories that have no
// comparable vector (a batch a minute, done when a batch finds nothing, and
// retried later when the provider gave nothing), and reconciles every agent's
// facts every six hours.
func (m *Manager) Start(ctx context.Context) {
	ctx, m.stop = context.WithCancel(ctx)
	m.wg.Add(3)
	go func() { defer m.wg.Done(); m.runIndexBackfill(ctx) }()
	go func() { defer m.wg.Done(); m.runEmbeddingRefresh(ctx) }()
	go func() { defer m.wg.Done(); m.runReconcile(ctx) }()
}

// Stop ends the background upkeep and waits for it.
func (m *Manager) Stop() {
	if m.stop != nil {
		m.stop()
	}
	m.wg.Wait()
}

func sleep(ctx context.Context, d time.Duration) bool {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-t.C:
		return true
	}
}

func (m *Manager) runIndexBackfill(ctx context.Context) {
	for {
		n, err := BackfillEmbeddingIndex(ctx, m.db.W, indexBackfillBatch)
		if err != nil {
			m.log.Error("memory: embedding index backfill failed", "error", err)
			return
		}
		if n == 0 || !sleep(ctx, indexBackfillPause) {
			return
		}
	}
}

func (m *Manager) runEmbeddingRefresh(ctx context.Context) {
	var pausedUntil time.Time
	for sleep(ctx, embeddingRefreshGap) {
		if m.clock().Before(pausedUntil) {
			continue
		}
		embedded, silent, err := m.refresher.refresh(ctx, refreshBatchSize)
		switch {
		case err != nil:
			m.log.Error("memory: embedding refresh failed", "error", err)
			pausedUntil = m.clock().Add(embeddingRetryAfter)
		case silent:
			pausedUntil = m.clock().Add(embeddingRetryAfter)
		case embedded == 0:
			return
		}
	}
}

func (m *Manager) runReconcile(ctx context.Context) {
	for sleep(ctx, reconcileEvery) {
		m.reconcileAll(ctx)
	}
}

func (m *Manager) reconcileAll(ctx context.Context) {
	type target struct {
		userID  int64
		agentID string
	}
	targets, err := collect(ctx, m.db.R, func(r rowScanner) (target, error) {
		var t target
		err := r.Scan(&t.userID, &t.agentID)
		return t, err
	}, `SELECT user_id, id FROM agents WHERE status = 'active' AND user_id IN (SELECT id FROM users)`)
	if err != nil {
		m.log.Warn("memory: fact reconciliation failed", "error", err)
		return
	}
	for _, t := range targets {
		if _, err := m.ReconcileFacts(ctx, t.userID, t.agentID, defaultMinimumFactConfidence); err != nil {
			m.log.Warn("memory: fact reconciliation failed", "error", err)
		}
	}
}
