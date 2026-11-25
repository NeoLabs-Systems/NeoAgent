package runtime

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/proc"
	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

// Computer states reported to clients.
const (
	StateStarting     = "starting"
	StateReady        = "ready"
	StateError        = "error"
	StateStopping     = "stopping"
	StateStopped      = "stopped"
	StateSleeping     = "sleeping"
	StateCapacityWait = "capacity_wait"
)

// Session is one running computer: a QEMU guest or a Docker container whose
// guest agent answers on loopback.
type Session struct {
	InstanceDir string
	BaseURL     string
	GuestToken  string
	// Process is the qemu process, or the attached `docker run`.
	Process *proc.Process
	// ContainerName is set for Docker computers.
	ContainerName string
	Resources     Allocation
	Accelerator   string
	// Display is where the guest's VNC server listens (QEMU only).
	Display    vm.Address
	QMP        vm.Address
	StartedAt  time.Time
	DirectBoot bool
	// LogTail reads the guest's own log for failure messages.
	LogTail func() string

	mu                sync.Mutex
	state             string
	lastError         string
	startupDurationMs *int64
	desktop           *omap
}

// NewSession is a computer that is starting.
func NewSession() *Session { return &Session{state: StateStarting} }

// State is the session's state.
func (s *Session) State() string { s.mu.Lock(); defer s.mu.Unlock(); return s.state }

// SetState changes the session's state.
func (s *Session) SetState(state string) { s.mu.Lock(); s.state = state; s.mu.Unlock() }

// MarkReadyIfStarting moves a starting session to ready.
func (s *Session) MarkReadyIfStarting() {
	s.mu.Lock()
	if s.state == StateStarting {
		s.state = StateReady
	}
	s.mu.Unlock()
}

// LastError is the failure recorded for the session.
func (s *Session) LastError() string { s.mu.Lock(); defer s.mu.Unlock(); return s.lastError }

// SetLastError records a failure.
func (s *Session) SetLastError(message string) { s.mu.Lock(); s.lastError = message; s.mu.Unlock() }

// FailWith marks the session failed unless it is being stopped on purpose.
func (s *Session) FailWith(message string) {
	s.mu.Lock()
	if s.state != StateStopping {
		s.state = StateError
		s.lastError = message
	}
	s.mu.Unlock()
}

// FailureDetail is the recorded error followed by the guest's own log, when
// the log says something the error does not.
func (s *Session) FailureDetail() string {
	log := ""
	if s.LogTail != nil {
		log = s.LogTail()
	}
	last := s.LastError()
	if log != "" && last != "" && !strings.Contains(log, last) {
		return last + "\n" + log
	}
	if log != "" {
		return log
	}
	return last
}

// Desktop is the last known state of the guest's graphical session.
func (s *Session) Desktop() *omap { s.mu.Lock(); defer s.mu.Unlock(); return s.desktop }

// SetDesktop records the state of the guest's graphical session.
func (s *Session) SetDesktop(desktop *omap) { s.mu.Lock(); s.desktop = desktop; s.mu.Unlock() }

// StartupDurationMs is how long the computer took to become usable, if known.
func (s *Session) StartupDurationMs() *int64 {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.startupDurationMs
}

// RecordStartup stores the startup duration once.
func (s *Session) RecordStartup() (ms int64, first bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.startupDurationMs != nil {
		return *s.startupDurationMs, false
	}
	ms = time.Since(s.StartedAt).Milliseconds()
	s.startupDurationMs = &ms
	return ms, true
}

// Alive reports whether the computer's process is running.
func (s *Session) Alive() bool { return s != nil && s.Process != nil && s.Process.Alive() }

// UserDirectoryKey names a user's directory and container from a hash, so a
// user ID never leaks into a filesystem path or a Docker object name.
func UserDirectoryKey(userKey string) string {
	sum := sha256.Sum256([]byte(userKey))
	return hex.EncodeToString(sum[:])[:24]
}

func isQueueableCapacityError(err error) bool {
	var coded *CodedError
	return errors.As(err, &coded) && coded.Code == CodeCapacity
}

type pendingStart struct {
	done    chan struct{}
	session *Session
	err     error
}

// startTracker tracks in-flight starts and the state of users whose guest is
// not running, so the UI can tell starting, sleeping, waiting for capacity,
// and failed apart.
type startTracker struct {
	mu        sync.Mutex
	pending   map[string]*pendingStart
	transient map[string]*omap
}

func newStartTracker() *startTracker {
	return &startTracker{pending: map[string]*pendingStart{}, transient: map[string]*omap{}}
}

// begin runs startGuest once per user, sharing the outcome with concurrent
// callers and recording it as transient status. The start keeps going when a
// caller stops waiting.
func (t *startTracker) begin(ctx context.Context, key string, startGuest func() (*Session, error)) (*Session, error) {
	t.mu.Lock()
	p, running := t.pending[key]
	if !running {
		p = &pendingStart{done: make(chan struct{})}
		t.pending[key] = p
		t.transient[key] = obj("state", StateStarting, "startedAt", isoNow())
	}
	t.mu.Unlock()
	if !running {
		go func() {
			p.session, p.err = startGuest()
			t.mu.Lock()
			if p.err != nil {
				t.failLocked(key, p.err)
			} else {
				delete(t.transient, key)
			}
			delete(t.pending, key)
			t.mu.Unlock()
			close(p.done)
		}()
	}
	select {
	case <-p.done:
		return p.session, p.err
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

// status is the state of a user with no live session, or nil.
func (t *startTracker) status(key string) *omap {
	t.mu.Lock()
	defer t.mu.Unlock()
	transient := t.transient[key]
	if transient == nil {
		return nil
	}
	out := transient.Clone()
	if last := transient.String("lastError"); last != "" {
		out.Set("error", last)
	} else {
		out.Set("error", nil)
	}
	return out
}

func (t *startTracker) fail(key string, err error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.failLocked(key, err)
}

func (t *startTracker) failLocked(key string, err error) {
	message := "Cloud computer failed."
	if err != nil && err.Error() != "" {
		message = err.Error()
	}
	state := StateError
	if isQueueableCapacityError(err) {
		state = StateCapacityWait
	}
	var code any
	var coded *CodedError
	if errors.As(err, &coded) {
		code = coded.Code
	}
	t.transient[key] = obj("state", state, "lastError", message, "error", message, "errorCode", code)
}

func (t *startTracker) sleep(key string) {
	t.mu.Lock()
	t.transient[key] = obj("state", StateSleeping)
	t.mu.Unlock()
}

func (t *startTracker) clear(key string) {
	t.mu.Lock()
	delete(t.transient, key)
	t.mu.Unlock()
}

func (t *startTracker) clearAll() {
	t.mu.Lock()
	t.transient = map[string]*omap{}
	t.mu.Unlock()
}

// settled waits for every in-flight start.
func (t *startTracker) settled() {
	t.mu.Lock()
	waits := make([]*pendingStart, 0, len(t.pending))
	for _, p := range t.pending {
		waits = append(waits, p)
	}
	t.mu.Unlock()
	for _, p := range waits {
		<-p.done
	}
}

// isoNow formats the current time like JavaScript's toISOString.
func isoNow() string { return isoTime(time.Now()) }

func isoTime(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }
