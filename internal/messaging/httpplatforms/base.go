package httpplatforms

import (
	"context"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// base is the state every platform here shares.
type base struct {
	name  string
	s     Settings
	guard *messaging.AccessGuard
	ev    messaging.Events
	deps  Deps

	mu     sync.Mutex
	status string
}

func newBase(name string, cfg messaging.Config, ev messaging.Events, deps Deps) *base {
	return &base{
		name: name, s: Settings(cfg.Settings), ev: ev, deps: deps,
		guard:  messaging.NewAccessGuard(name, cfg, ev),
		status: messaging.StatusDisconnected,
	}
}

func (b *base) Status() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.status
}

func (b *base) setStatus(s string) {
	b.mu.Lock()
	b.status = s
	b.mu.Unlock()
}

func (b *base) SetAccessPolicy(p messaging.AccessPolicy) { b.guard.SetPolicy(p) }
func (b *base) AccessPolicy() messaging.AccessPolicy     { return b.guard.Policy() }

// connected marks the platform connected and tells the manager.
func (b *base) connected() {
	b.setStatus(messaging.StatusConnected)
	b.ev.Connected()
}

func (b *base) stopped() {
	b.setStatus(messaging.StatusDisconnected)
	b.ev.Disconnected(messaging.Disconnect{Manual: true})
}

// admit runs the access check for one inbound message.
func (b *base) admit(c messaging.AccessContext, o messaging.BlockedOptions) bool {
	c.Platform = b.name
	if c.RoleIDs == nil {
		c.RoleIDs = []string{}
	}
	return b.guard.Check(c, o).Allowed
}

// poller runs fn first after firstDelay and then every interval until stop is
// called, while the platform stays connected.
type poller struct {
	cancel context.CancelFunc
	done   chan struct{}
}

func (b *base) startPoller(firstDelay, interval time.Duration, fn func(context.Context)) *poller {
	ctx, cancel := context.WithCancel(context.Background())
	p := &poller{cancel: cancel, done: make(chan struct{})}
	go func() {
		defer close(p.done)
		delay := firstDelay
		for {
			select {
			case <-ctx.Done():
				return
			case <-time.After(delay):
			}
			if b.Status() != messaging.StatusConnected {
				return
			}
			fn(ctx)
			delay = interval
		}
	}()
	return p
}

func (p *poller) stop() {
	if p == nil {
		return
	}
	p.cancel()
	<-p.done
}

func requireText(value, label string) (string, error) {
	t := trimSpace(value)
	if t == "" {
		return "", &requiredError{label}
	}
	return t, nil
}

type requiredError struct{ label string }

func (e *requiredError) Error() string { return e.label + " is required." }
