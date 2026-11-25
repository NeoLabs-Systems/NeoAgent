package github

import "sync"

// orderedSet remembers the most recent keys up to a limit, dropping the oldest.
type orderedSet struct {
	mu    sync.Mutex
	limit int
	order []string
	set   map[string]bool
}

func newOrderedSet(limit int) *orderedSet {
	return &orderedSet{limit: limit, set: map[string]bool{}}
}

func (s *orderedSet) has(key string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.set[key]
}

func (s *orderedSet) add(key string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.set[key] {
		return
	}
	s.set[key] = true
	s.order = append(s.order, key)
	if len(s.order) > s.limit {
		delete(s.set, s.order[0])
		s.order = s.order[1:]
	}
}

// runComments maps "runId|thread" to the comment the run posted there.
type runComments struct {
	mu    sync.Mutex
	order []string
	ids   map[string]int64
}

func newRunComments() *runComments { return &runComments{ids: map[string]int64{}} }

func (r *runComments) get(key string) int64 {
	if key == "" {
		return 0
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.ids[key]
}

func (r *runComments) set(key string, id int64) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.ids[key]; !ok {
		r.order = append(r.order, key)
	}
	r.ids[key] = id
	if len(r.order) > maxTrackedRunComments {
		delete(r.ids, r.order[0])
		r.order = r.order[1:]
	}
}
