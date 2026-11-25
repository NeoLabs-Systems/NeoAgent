package android

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
)

// State is the emulator record kept per account in
// <data>/android/state/<userId>.json, the same file the Node server wrote.
type State struct {
	UserID         string  `json:"userId"`
	Bootstrapped   bool    `json:"bootstrapped"`
	Starting       bool    `json:"starting"`
	StartupPhase   *string `json:"startupPhase"`
	LastStartError *string `json:"lastStartError"`
	PID            *int    `json:"pid"`
	AdbSerial      *string `json:"adbSerial"`
}

func ptr[T any](v T) *T { return &v }

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

// stateStore reads and writes State files; writes of one account serialise.
type stateStore struct {
	dir string
	mu  sync.Mutex
}

func (s *stateStore) file(userID string) string { return filepath.Join(s.dir, userID+".json") }

// read returns the stored state, or the empty state when the file is missing
// or unreadable.
func (s *stateStore) read(userID string) State {
	raw, err := os.ReadFile(s.file(userID))
	if err == nil {
		var st State
		if json.Unmarshal(raw, &st) == nil {
			return st
		}
	}
	return State{UserID: userID}
}

// update applies change to the current state and stores the result atomically.
func (s *stateStore) update(userID string, change func(*State)) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	st := s.read(userID)
	change(&st)
	raw, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(s.dir, 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(s.dir, userID+".json.*.tmp")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if err := tmp.Chmod(0o600); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write(raw); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), s.file(userID))
}
