package telegram

import (
	"slices"
	"sync"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// contextBuffers keeps the last messages of the most recently active chats, so
// memory does not grow with every chat the bot meets.
type contextBuffers struct {
	mu      sync.Mutex
	order   []string // least recently active first
	buffers map[string][]messaging.ContextEntry
}

func newContextBuffers() *contextBuffers {
	return &contextBuffers{buffers: map[string][]messaging.ContextEntry{}}
}

func (c *contextBuffers) add(chatID string, entry messaging.ContextEntry) {
	c.mu.Lock()
	defer c.mu.Unlock()
	buf := append(c.buffers[chatID], entry)
	if len(buf) > contextMaxSize {
		buf = buf[1:]
	}
	c.buffers[chatID] = buf
	c.order = append(slices.DeleteFunc(c.order, func(id string) bool { return id == chatID }), chatID)
	for len(c.order) > contextMaxChats {
		delete(c.buffers, c.order[0])
		c.order = c.order[1:]
	}
}

func (c *contextBuffers) get(chatID string) []messaging.ContextEntry {
	c.mu.Lock()
	defer c.mu.Unlock()
	return slices.Clone(c.buffers[chatID])
}

func (c *contextBuffers) clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.order, c.buffers = nil, map[string][]messaging.ContextEntry{}
}

// seenSet is an insertion-ordered map of ids to labels; updating an id keeps
// its place.
type seenSet struct {
	mu    sync.Mutex
	items []seen
}

type seen struct{ key, label string }

func (s *seenSet) set(key, label string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.items {
		if s.items[i].key == key {
			s.items[i].label = label
			return
		}
	}
	s.items = append(s.items, seen{key, label})
}

func (s *seenSet) entries() []seen {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.Clone(s.items)
}

func (s *seenSet) clear() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.items = nil
}
