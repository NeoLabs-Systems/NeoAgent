package updatestatus

import (
	"os"
	"path/filepath"
	"testing"
)

func TestWriteReadAndDeadRunner(t *testing.T) {
	path := File(t.TempDir())
	if st := Read(path); st["state"] != "idle" || st["phase"] != "idle" {
		t.Fatalf("default = %v", st)
	}
	if _, err := Write(path, map[string]any{"state": "running", "runnerPid": os.Getpid(), "phase": "backup"}); err != nil {
		t.Fatal(err)
	}
	if st := Read(path); st["state"] != "running" || st["phase"] != "backup" {
		t.Fatalf("live runner = %v", st)
	}
	if info, _ := os.Stat(path); info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %v", info.Mode())
	}
	if _, err := Write(path, map[string]any{"runnerPid": 0x7ffffffe}); err != nil {
		t.Fatal(err)
	}
	st := Read(path)
	if st["state"] != "failed" || st["message"] != "The update stopped unexpectedly. Nothing was lost; you can try again." || st["runnerPid"] != nil {
		t.Fatalf("dead runner = %v", st)
	}
	if err := AppendLog(path, "hello"); err != nil {
		t.Fatal(err)
	}
	if logs, _ := Read(path)["logs"].([]any); len(logs) != 1 {
		t.Fatalf("logs = %v", logs)
	}
	if _, err := os.Stat(filepath.Dir(path)); err != nil {
		t.Fatal(err)
	}
}
