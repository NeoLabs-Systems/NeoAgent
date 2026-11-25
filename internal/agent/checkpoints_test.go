package agent

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// localWorkspace runs checkpoint scripts with sh in a directory standing in
// for the guest workspace.
type localWorkspace struct{ dir string }

func (w localWorkspace) RunInWorkspace(ctx context.Context, userID int64, runID, deviceTarget, script string, timeout time.Duration) (dyn.Map, error) {
	cmd := exec.CommandContext(ctx, "sh", "-c", script)
	cmd.Dir = w.dir
	var stdout, stderr strings.Builder
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	code := 0
	if err := cmd.Run(); err != nil {
		exit, ok := err.(*exec.ExitError)
		if !ok {
			return nil, err
		}
		code = exit.ExitCode()
	}
	return dyn.Map{"exitCode": float64(code), "stdout": stdout.String(), "stderr": stderr.String()}, nil
}

// writingBackend writes files for write_file and also touches a file nobody
// asked for, which the checkpoint must not claim.
type writingBackend struct {
	dir   string
	mu    sync.Mutex
	repos []dyn.Map
	e     *Engine
}

func (b *writingBackend) Execute(ctx context.Context, s *ai.Session, call ai.Call, stepID string) (any, error) {
	if call.Name == "write_file" {
		p := filepath.Join(b.dir, dyn.Str(call.Arguments["path"]))
		if err := os.WriteFile(p, []byte(dyn.Str(call.Arguments["content"])), 0o644); err != nil {
			return nil, err
		}
		_ = os.WriteFile(filepath.Join(b.dir, "editor.tmp"), []byte("someone else"), 0o644)
		return map[string]any{"success": true}, nil
	}
	b.mu.Lock()
	b.repos = b.e.RunRepositories(s.RunID)
	b.mu.Unlock()
	return map[string]any{"ok": true}, nil
}

func TestCheckpointsRecordWhatTheRunChanged(t *testing.T) {
	for _, bin := range []string{"git", "python3"} {
		if _, err := exec.LookPath(bin); err != nil {
			t.Skip(bin + " is not installed")
		}
	}
	dir := t.TempDir()
	for _, args := range [][]string{{"init", "-q"}, {"config", "user.email", "t@example.com"}, {"config", "user.name", "t"}} {
		if out, err := exec.Command("git", append([]string{"-C", dir}, args...)...).CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v %s", args, err, out)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("one"), 0o644); err != nil {
		t.Fatal(err)
	}
	if out, err := exec.Command("sh", "-c", "cd "+dir+" && git add a.txt && git commit -qm init").CombinedOutput(); err != nil {
		t.Fatalf("commit: %v %s", err, out)
	}

	st := newStack(t,
		llm.Event{ToolCalls: []llm.ToolCall{toolCall("c1", "write_file", map[string]any{"path": "a.txt", "content": "two"})}},
		llm.Event{ToolCalls: []llm.ToolCall{toolCall("c2", "task_ledger", map[string]any{"goal": "check"})}},
		llm.Event{Content: "Changed a.txt."},
	)
	backend := &writingBackend{dir: dir, e: st.engine}
	st.engine.deps.Backend = backend
	st.engine.deps.Commands = localWorkspace{dir: dir}
	if _, err := st.engine.Run(context.Background(), 1, "Edit a.txt", Options{RunID: "run-cp"}); err != nil {
		t.Fatal(err)
	}
	backend.mu.Lock()
	repos := backend.repos
	backend.mu.Unlock()
	if len(repos) != 1 {
		t.Fatalf("repositories %v", repos)
	}
	paths := dyn.List(repos[0]["paths"])
	if len(paths) != 1 || dyn.Str(dyn.Get(paths[0], "path")) != "a.txt" || len(dyn.Str(dyn.Get(paths[0], "source"))) < 40 {
		t.Fatalf("paths %v", paths)
	}
	if got := st.scalar(t, `SELECT COUNT(*) FROM agent_run_events WHERE run_id = 'run-cp' AND event_type = 'checkpoint.created'`); got != "1" {
		t.Fatalf("checkpoint events %s", got)
	}
	if got := st.scalar(t, `SELECT COUNT(*) FROM agent_run_events WHERE run_id = 'run-cp' AND event_type = 'workspace.changed'`); got != "1" {
		t.Fatalf("workspace events %s", got)
	}
}

func TestCheckpointHelpersMatchNode(t *testing.T) {
	changes := parseRawDiff(":100644 100644 aaa bbb M\tsrc/a.go\n:160000 160000 ccc ddd M\tvendor/sub\n:100644 100644 eee fff M\t\"we\\tird\"\n")
	if len(changes) != 2 || changes[0].path != "src/a.go" || changes[0].gitlink || !changes[1].gitlink {
		t.Fatalf("raw diff %+v", changes)
	}
	shell := ai.Call{Name: "execute_command", Arguments: map[string]any{"command": `cd "my project" && make`}}
	if d := commandDirectory(shell, toolsMeta("shell")); d != "my project" {
		t.Fatalf("cd prefix: %q", d)
	}
	file := ai.Call{Name: "write_file", Arguments: map[string]any{"path": "/home/neo/workspace/app/main.go"}}
	if d := commandDirectory(file, toolsMeta("files")); d != "app" {
		t.Fatalf("file directory: %q", d)
	}
	if got := repositoryScript("", "x"); got != "set -e\nx" {
		t.Fatalf("script %q", got)
	}
}

func toolsMeta(group string) tools.Meta { return tools.Meta{Group: group} }
