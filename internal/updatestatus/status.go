// Package updatestatus is the file through which the admin UI and the update
// runner talk: the runner is a separate process because it outlives the server
// it restarts.
package updatestatus

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

const maxLogLines = 220

// File is the status file in a data directory.
func File(dataDir string) string { return filepath.Join(dataDir, "update-status.json") }

func defaults() map[string]any {
	return map[string]any{
		"state": "idle", "progress": 0, "phase": "idle", "message": "",
		"startedAt": nil, "completedAt": nil, "versionBefore": nil, "versionAfter": nil,
		"targetBranch": nil, "runnerPid": nil, "changelog": []any{}, "logs": []any{},
	}
}

// Read returns the status. A runner that died without saying so reads as
// failed, so the UI never waits forever.
func Read(path string) map[string]any {
	st := defaults()
	if raw, err := os.ReadFile(path); err == nil {
		var saved map[string]any
		if json.Unmarshal(raw, &saved) == nil {
			for k, v := range saved {
				st[k] = v
			}
		}
	}
	return normalize(st)
}

func normalize(st map[string]any) map[string]any {
	if st["state"] != "running" || runnerAlive(st["runnerPid"]) {
		return st
	}
	st["state"], st["progress"], st["phase"] = "failed", 100, "failed"
	st["message"] = "The update stopped unexpectedly. Nothing was lost; you can try again."
	if st["completedAt"] == nil {
		st["completedAt"] = now()
	}
	st["runnerPid"] = nil
	return st
}

func runnerAlive(v any) bool {
	var pid int
	switch n := v.(type) {
	case float64:
		pid = int(n)
		if float64(pid) != n {
			return false
		}
	case int:
		pid = n
	}
	return pid > 0 && processAlive(pid)
}

// Write merges patch into the status and saves it atomically (0600).
func Write(path string, patch map[string]any) (map[string]any, error) {
	st := Read(path)
	for k, v := range patch {
		st[k] = v
	}
	st["updatedAt"] = now()
	st = normalize(st)
	raw, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".update-status-*")
	if err != nil {
		return nil, err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(raw); err != nil {
		tmp.Close()
		return nil, err
	}
	if err := tmp.Chmod(0o600); err != nil {
		tmp.Close()
		return nil, err
	}
	if err := tmp.Close(); err != nil {
		return nil, err
	}
	return st, os.Rename(tmp.Name(), path)
}

// AppendLog adds a timestamped line to the status log.
func AppendLog(path, message string) error {
	logs, _ := Read(path)["logs"].([]any)
	logs = append(logs, now()+" "+message)
	if len(logs) > maxLogLines {
		logs = logs[len(logs)-maxLogLines:]
	}
	_, err := Write(path, map[string]any{"logs": logs})
	return err
}

func now() string { return time.Now().UTC().Format("2006-01-02T15:04:05.000Z") }
