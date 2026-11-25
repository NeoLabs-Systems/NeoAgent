package gitproxy

import (
	"crypto/rand"
	"encoding/base64"
	"sync"
	"time"
)

const capabilityGrace = 5 * time.Minute

// Grant is who a capability speaks for.
type Grant struct {
	UserID  int64
	AgentID string
	RunID   string
}

type capabilityEntry struct {
	grant     Grant
	expiresAt time.Time
}

// capabilities are the live per-command tokens. They exist only in memory: a
// restart ends every command that was running, as in Node.
type capabilities struct {
	mu      sync.Mutex
	now     func() time.Time
	entries map[string]capabilityEntry
}

func newCapabilities(now func() time.Time) *capabilities {
	return &capabilities{now: now, entries: map[string]capabilityEntry{}}
}

func (c *capabilities) mint(g Grant, ttl time.Duration) (string, error) {
	var raw [32]byte
	if _, err := rand.Read(raw[:]); err != nil {
		return "", err
	}
	token := base64.RawURLEncoding.EncodeToString(raw[:])
	c.mu.Lock()
	defer c.mu.Unlock()
	now := c.now()
	for t, e := range c.entries {
		if !e.expiresAt.After(now) {
			delete(c.entries, t)
		}
	}
	c.entries[token] = capabilityEntry{grant: g, expiresAt: now.Add(ttl + capabilityGrace)}
	return token, nil
}

func (c *capabilities) resolve(token string) (Grant, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.entries[token]
	if !ok || !e.expiresAt.After(c.now()) {
		return Grant{}, false
	}
	return e.grant, true
}
