package messaging

import "context"

// CancelAgent cancels one agent's chat queues (/stop): a running chat stops
// after its current run, and waiting messages are released as cancelled.
func (q *Queues) CancelAgent(userID int64, agentID string) {
	keys := q.SummarizeAgent(userID, agentID).Keys
	q.mu.Lock()
	defer q.mu.Unlock()
	for _, key := range keys {
		queue := q.queues[key]
		if queue == nil {
			continue
		}
		queue.cancelRequested = true
		cancelPending(queue)
		if !queue.running {
			queue.pending = nil
			queue.cancelRequested = false
			delete(q.queues, key)
		}
	}
}

// QueueSummary is whether an agent's chats are working and how many messages wait.
func (m *Manager) QueueSummary(userID int64, agentID string) (bool, int) {
	s := m.queues.SummarizeAgent(userID, agentID)
	return s.Running, s.Pending
}

// CancelQueues cancels an agent's chat queues.
func (m *Manager) CancelQueues(userID int64, agentID string) { m.queues.CancelAgent(userID, agentID) }

// ReleaseAbandonedJobs puts an agent's inbound jobs that nothing works on any
// more back in line (releaseAbandonedInboundJobs).
func (m *Manager) ReleaseAbandonedJobs(ctx context.Context, userID int64, agentID string) int {
	if m.store == nil {
		return 0
	}
	f := JobFilter{UserID: &userID}
	if agentID != "" {
		f.AgentID = &agentID
	}
	abandoned, err := m.store.AbandonedProcessingJobs(ctx, f)
	if err != nil {
		return 0
	}
	released := 0
	for _, job := range abandoned {
		if m.jobs.inFlight(job.ID) != nil {
			continue
		}
		if ok, _ := m.store.RequeueReplayableJob(ctx, job.ID); ok {
			released++
		}
	}
	return released
}

// ConnectedPlatforms counts an agent's connected chat platforms.
func (m *Manager) ConnectedPlatforms(ctx context.Context, userID int64, agentID string) int {
	n := 0
	for _, status := range m.GetAllStatuses(ctx, userID, agentID) {
		if s, ok := status.(map[string]any); ok {
			if v, _ := s["status"].(string); equalFoldASCII(v, "connected") {
				n++
			}
		}
	}
	return n
}

func equalFoldASCII(a, b string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := 0; i < len(a); i++ {
		x, y := a[i], b[i]
		if 'A' <= x && x <= 'Z' {
			x += 'a' - 'A'
		}
		if x != y {
			return false
		}
	}
	return true
}
