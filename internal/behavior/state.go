package behavior

import (
	"container/list"
	"fmt"
	"sync"
	"time"
)

const (
	maxThreadStates = 1000
	threadStateTTL  = 7 * 24 * time.Hour
)

// Signal is one recorded room event.
type Signal struct {
	Type    string         `json:"type"`
	At      string         `json:"at"`
	Sender  *string        `json:"sender"`
	Details map[string]any `json:"details"`
}

// ObservabilitySummary is the last audit of how the agent lands in a room.
type ObservabilitySummary struct {
	HealthScore     float64 `json:"healthScore"`
	Summary         string  `json:"summary"`
	Findings        []any   `json:"findings"`
	Recommendations []any   `json:"recommendations"`
	At              string  `json:"at"`
}

// ThreadState is what the pipeline remembers about one chat. It lives in
// memory only, like the Node server's.
type ThreadState struct {
	TurnEpoch                      int64                 `json:"turnEpoch"`
	LastDecision                   *string               `json:"lastDecision"`
	LastDecisionAt                 *string               `json:"lastDecisionAt"`
	LastSpokeAt                    *string               `json:"lastSpokeAt"`
	MessageCountSinceNorms         int                   `json:"messageCountSinceNorms"`
	NormsPromptBlock               string                `json:"normsPromptBlock"`
	NormsUpdatedAt                 *string               `json:"normsUpdatedAt"`
	LastObservabilityAt            *string               `json:"lastObservabilityAt"`
	LastObservabilitySummary       *ObservabilitySummary `json:"lastObservabilitySummary"`
	MessageCountSinceObservability int                   `json:"messageCountSinceObservability"`
	RecentSilenceCount             int                   `json:"recentSilenceCount"`
	RecentSignals                  []Signal              `json:"recentSignals"`
}

func defaultThreadState() ThreadState { return ThreadState{RecentSignals: []Signal{}} }

type stateEntry struct {
	key     string
	value   ThreadState
	touched time.Time
}

// States holds thread states, least recently used first, evicting after a
// week or past a thousand chats.
type States struct {
	Now   func() time.Time
	mu    sync.Mutex
	order *list.List
	index map[string]*list.Element
}

// NewStates creates an empty state table.
func NewStates() *States {
	return &States{Now: time.Now, order: list.New(), index: map[string]*list.Element{}}
}

func stateKey(userID int64, agentID, platform, chatID string) string {
	if agentID == "" {
		agentID = "main"
	}
	return fmt.Sprintf("%d::%s::%s::%s", userID, agentID, platform, chatID)
}

func (s *States) get(key string) ThreadState {
	el := s.index[key]
	if el == nil {
		return defaultThreadState()
	}
	s.order.MoveToBack(el)
	entry := el.Value.(*stateEntry)
	entry.touched = s.Now()
	v := entry.value
	v.RecentSignals = append([]Signal{}, v.RecentSignals...)
	return v
}

// Get returns a copy of a chat's state.
func (s *States) Get(userID int64, agentID, platform, chatID string) ThreadState {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.get(stateKey(userID, agentID, platform, chatID))
}

// Update applies a change to a chat's state and returns the new state.
func (s *States) Update(userID int64, agentID, platform, chatID string, change func(*ThreadState)) ThreadState {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := stateKey(userID, agentID, platform, chatID)
	next := s.get(key)
	change(&next)
	if el := s.index[key]; el != nil {
		s.order.Remove(el)
	}
	stored := next
	stored.RecentSignals = append([]Signal{}, next.RecentSignals...)
	s.index[key] = s.order.PushBack(&stateEntry{key: key, value: stored, touched: s.Now()})
	s.evict()
	return next
}

func (s *States) evict() {
	cutoff := s.Now().Add(-threadStateTTL)
	for el := s.order.Front(); el != nil; {
		next := el.Next()
		if entry := el.Value.(*stateEntry); entry.touched.Before(cutoff) {
			s.order.Remove(el)
			delete(s.index, entry.key)
		}
		el = next
	}
	for s.order.Len() > maxThreadStates {
		el := s.order.Front()
		s.order.Remove(el)
		delete(s.index, el.Value.(*stateEntry).key)
	}
}

// BumpTurnEpoch claims a new speak turn in a chat.
func (s *States) BumpTurnEpoch(userID int64, agentID, platform, chatID string) ThreadState {
	return s.Update(userID, agentID, platform, chatID, func(t *ThreadState) { t.TurnEpoch++ })
}

// IsTurnCurrent reports whether no newer speak turn was claimed.
func (s *States) IsTurnCurrent(userID int64, agentID, platform, chatID string, epoch int64) bool {
	return s.Get(userID, agentID, platform, chatID).TurnEpoch == epoch
}

// MarkSpoke records that the agent just spoke in a chat.
func (s *States) MarkSpoke(userID int64, agentID, platform, chatID string) ThreadState {
	now := isoTime(s.Now())
	return s.Update(userID, agentID, platform, chatID, func(t *ThreadState) {
		t.LastSpokeAt = &now
		t.RecentSilenceCount = 0
	})
}

func isoTime(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }
