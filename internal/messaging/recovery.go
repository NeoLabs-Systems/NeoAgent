package messaging

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

// Durable inbound handling and replay (manager.js _dispatchInboundJob,
// _processInboundJob, recoverPendingInbound): every inbound message is a job
// that is claimed before its run and settled after it. Jobs that no run
// started on stay pending, and are replayed when their platform is connected
// again, after a restart or a reconnect.

const (
	jobPending    = "pending"
	jobProcessing = "processing"
	jobCompleted  = "completed"
	jobFailed     = "failed"

	interruptedRunNotice = "The server stopped after this inbound agent run began; it will not be replayed automatically."
	invalidPayloadNotice = "Stored inbound message payload is invalid."
)

// jobTracker remembers the jobs being handled in this process.
type jobTracker struct {
	mu         sync.Mutex
	active     map[string]chan struct{}
	recoveries map[string]*recovery
	reconciled bool
}

type recovery struct {
	done               chan struct{}
	recovered, skipped int
	err                error
}

func (t *jobTracker) init() {
	if t.active == nil {
		t.active = map[string]chan struct{}{}
		t.recoveries = map[string]*recovery{}
	}
}

// track marks a job as handled here; tracked=false when it already is, with
// the channel that closes when that handling ends.
func (t *jobTracker) track(id string) (done chan struct{}, finish func(), tracked bool) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.init()
	if ch, ok := t.active[id]; ok {
		return ch, func() {}, false
	}
	ch := make(chan struct{})
	t.active[id] = ch
	return ch, func() {
		t.mu.Lock()
		if t.active[id] == ch {
			delete(t.active, id)
		}
		t.mu.Unlock()
		close(ch)
	}, true
}

func (t *jobTracker) inFlight(id string) chan struct{} {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.init()
	return t.active[id]
}

func (m *Manager) shuttingDown() bool {
	m.ctxMu.Lock()
	defer m.ctxMu.Unlock()
	return m.ctx == nil || m.ctx.Err() != nil
}

// dispatchJob handles a job unless it is done or another run owns it, and
// reports whether it is completed.
func (m *Manager) dispatchJob(ctx context.Context, job *Job, payload *Message) bool {
	if job == nil {
		return false
	}
	if ch := m.jobs.inFlight(job.ID); ch != nil {
		select {
		case <-ch:
		case <-ctx.Done():
			return false
		}
	}
	if fresh, err := m.store.Job(ctx, job.ID); err == nil && fresh != nil {
		job = fresh
	}
	if job.RunID == "" && (job.Status == jobProcessing || job.Status == jobFailed) {
		_, _ = m.store.RequeueReplayableJob(ctx, job.ID)
		if fresh, err := m.store.Job(ctx, job.ID); err == nil && fresh != nil {
			job = fresh
		}
	}
	if job.Status == jobPending {
		return m.processJob(ctx, job, payload)
	}
	if job.Status != jobCompleted {
		m.log.Warn("duplicate message has a durable status; skipping replay", "platform", job.Platform, "user", job.UserID, "status", job.Status)
	}
	return job.Status == jobCompleted
}

// processJob claims a job, runs the agent on it and settles it.
func (m *Manager) processJob(ctx context.Context, job *Job, payload *Message) bool {
	if m.shuttingDown() {
		return false
	}
	if m.cfg.Engine == nil {
		// The message is stored and shows up in chat, but nothing answers it.
		m.log.Warn("stored a message with no automation handler; the agent will not reply until messaging automation is running", "platform", job.Platform)
		return false
	}
	done, finish, tracked := m.jobs.track(job.ID)
	if !tracked {
		select {
		case <-done:
		case <-ctx.Done():
			return false
		}
		fresh, err := m.store.Job(ctx, job.ID)
		return err == nil && fresh != nil && fresh.Status == jobCompleted
	}
	defer finish()
	claimed, err := m.store.ClaimJob(ctx, job.ID)
	if err != nil || !claimed {
		return false
	}
	var window time.Duration
	if o, ok := m.cfg.Engine.(InboundObserver); ok {
		window = o.NoteInbound(ctx, job.UserID, job.AgentID, payload)
	}
	result := m.queues.Process(ctx, ProcessRequest{
		UserID:      job.UserID,
		BatchWindow: window,
		Message:     payload,
		Execute: func(runCtx context.Context, queued *Message) Outcome {
			return m.cfg.Engine.HandleMessage(runCtx, job.UserID, job.AgentID, queued)
		},
	})
	completion, waitErr := result.Wait(ctx)
	status, failure := jobCompleted, ""
	switch {
	case waitErr != nil || completion.Cancelled || result.Cancelled:
		if completion.RunID != "" {
			status, failure = jobFailed, interruptedRunNotice
		} else {
			status = jobPending
		}
	case completion.Err != nil:
		if m.shuttingDown() || errors.Is(completion.Err, context.Canceled) {
			if completion.RunID != "" {
				status, failure = jobFailed, interruptedRunNotice
			} else {
				status = jobPending
			}
		} else {
			status, failure = jobFailed, completion.Err.Error()
		}
	}
	if err := m.store.SettleJob(context.WithoutCancel(ctx), job.ID, status, failure); err != nil {
		m.log.Error("settle inbound job failed", "error", err)
		return false
	}
	return status == jobCompleted
}

// platformReady reports a connected platform for a job.
func (m *Manager) platformReady(job *Job) bool {
	m.mu.Lock()
	mc := m.conns[connKey{userID: job.UserID, agentID: job.AgentID, platform: job.Platform}]
	m.mu.Unlock()
	return mc != nil && mc.platform != nil && mc.platform.Status() == StatusConnected
}

func (f JobFilter) key() string {
	part := func(s *string) string {
		if s == nil {
			return "*"
		}
		return *s
	}
	user := "*"
	if f.UserID != nil {
		user = fmt.Sprint(*f.UserID)
	}
	return user + "|" + part(f.AgentID) + "|" + part(f.Platform)
}

// RecoverPending replays the pending jobs whose platform is connected; one
// recovery per filter runs at a time.
func (m *Manager) RecoverPending(ctx context.Context, f JobFilter) (recovered, skipped int, err error) {
	if m.shuttingDown() || m.cfg.Engine == nil || m.store == nil || m.cfg.DB == nil {
		return 0, 0, nil
	}
	key := f.key()
	m.jobs.mu.Lock()
	m.jobs.init()
	if r, ok := m.jobs.recoveries[key]; ok {
		m.jobs.mu.Unlock()
		<-r.done
		return r.recovered, r.skipped, r.err
	}
	r := &recovery{done: make(chan struct{})}
	m.jobs.recoveries[key] = r
	reconcile := !m.jobs.reconciled
	m.jobs.reconciled = true
	m.jobs.mu.Unlock()
	defer func() {
		m.jobs.mu.Lock()
		if m.jobs.recoveries[key] == r {
			delete(m.jobs.recoveries, key)
		}
		m.jobs.mu.Unlock()
		close(r.done)
	}()

	if reconcile {
		if _, err := m.store.ReconcileInterruptedJobs(ctx); err != nil {
			r.err = err
			return 0, 0, err
		}
	}
	abandoned, err := m.store.AbandonedProcessingJobs(ctx, f)
	if err != nil {
		r.err = err
		return 0, 0, err
	}
	for _, job := range abandoned {
		if m.jobs.inFlight(job.ID) == nil {
			_, _ = m.store.RequeueReplayableJob(ctx, job.ID)
		}
	}
	pending, err := m.store.PendingJobs(ctx, f)
	if err != nil {
		r.err = err
		return 0, 0, err
	}
	for _, job := range pending {
		if m.shuttingDown() {
			break
		}
		if !m.platformReady(job) {
			r.skipped++
			continue
		}
		payload := job.Payload()
		if payload == nil {
			_ = m.store.SettleJob(ctx, job.ID, jobFailed, invalidPayloadNotice)
			continue
		}
		if m.dispatchJob(ctx, job, payload) {
			r.recovered++
		}
	}
	return r.recovered, r.skipped, nil
}

// recoverInBackground replays what waited for a platform that just connected.
func (m *Manager) recoverInBackground(f JobFilter) {
	m.ctxMu.Lock()
	ctx := m.ctx
	m.ctxMu.Unlock()
	if ctx == nil || ctx.Err() != nil {
		return
	}
	m.wg.Add(1)
	go func() {
		defer m.wg.Done()
		if _, _, err := m.RecoverPending(ctx, f); err != nil && !m.shuttingDown() {
			m.log.Error("inbound recovery failed", "error", err)
		}
	}()
}
