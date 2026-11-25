package repotools

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

type vector struct {
	Tool         string                `json:"tool"`
	Args         dyn.Map               `json:"args"`
	Responses    []dyn.Map             `json:"responses"`
	Repositories []dyn.Map             `json:"repositories"`
	Store        *struct{ Log string } `json:"store"`
	Calls        []struct {
		Script  string  `json:"script"`
		Timeout float64 `json:"timeout"`
	} `json:"calls"`
	Result json.RawMessage `json:"result"`
}

type fakeShell struct {
	responses []dyn.Map
	scripts   []string
	timeouts  []time.Duration
}

func (f *fakeShell) Run(_ context.Context, script string, timeout time.Duration) (dyn.Map, error) {
	f.scripts = append(f.scripts, script)
	f.timeouts = append(f.timeouts, timeout)
	if len(f.responses) == 0 {
		return dyn.Map{"stdout": "", "exitCode": float64(0)}, nil
	}
	next := f.responses[0]
	f.responses = f.responses[1:]
	return next, nil
}

type fakeLogs struct {
	saveID, saveErr, log string
}

func (f fakeLogs) SaveLog(context.Context, []byte, string, string) (string, error) {
	if f.saveErr != "" {
		return "", errors.New(f.saveErr)
	}
	return f.saveID, nil
}

func (f fakeLogs) ReadLog(context.Context, string, int64) (string, bool) {
	return f.log, f.log != ""
}

func canonical(t *testing.T, v any) string {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	var back any
	if err := json.Unmarshal(raw, &back); err != nil {
		t.Fatal(err)
	}
	return dyn.Stringify(back)
}

func TestToolsMatchNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/node_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors []vector
	if err := json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	for i, v := range vectors {
		shell := &fakeShell{responses: append([]dyn.Map(nil), v.Responses...)}
		var got any
		var runErr error
		ctx := context.Background()
		switch v.Tool {
		case "search":
			got, runErr = Search(ctx, shell, v.Args)
		case "overview":
			got, runErr = Overview(ctx, shell, v.Args)
		case "diff":
			var repos []Repository
			for _, r := range v.Repositories {
				repo := Repository{Root: dyn.Str(r["root"])}
				for _, p := range dyn.List(r["paths"]) {
					repo.Paths = append(repo.Paths, RepositoryPath{Path: dyn.Str(dyn.Get(p, "path")), Source: dyn.Str(dyn.Get(p, "source"))})
				}
				repos = append(repos, repo)
			}
			got, runErr = Diff(ctx, shell, v.Args, repos)
		case "tests":
			var expected dyn.Map
			_ = json.Unmarshal(v.Result, &expected)
			var logs LogStore
			switch {
			case expected["log_error"] != nil:
				logs = fakeLogs{saveErr: dyn.Str(expected["log_error"])}
			case v.Store != nil:
				logs = fakeLogs{log: v.Store.Log}
			case expected["log_artifact_id"] == "art-1":
				logs = fakeLogs{saveID: "art-1"}
			}
			got, runErr = RunTests(ctx, shell, v.Args, logs, "", "")
		}
		if runErr != nil {
			got = dyn.Map{"thrown": runErr.Error()}
		}
		if len(shell.scripts) != len(v.Calls) {
			t.Errorf("#%d %s: %d shell calls, want %d", i, v.Tool, len(shell.scripts), len(v.Calls))
			continue
		}
		for j, call := range v.Calls {
			if shell.scripts[j] != call.Script {
				t.Errorf("#%d %s call %d script differs:\n got: %q\nwant: %q", i, v.Tool, j, shell.scripts[j], call.Script)
			}
			if want := time.Duration(call.Timeout) * time.Millisecond; shell.timeouts[j] != want {
				t.Errorf("#%d %s call %d timeout %v want %v", i, v.Tool, j, shell.timeouts[j], want)
			}
		}
		var want any
		_ = json.Unmarshal(v.Result, &want)
		if g, w := canonical(t, got), dyn.Stringify(want); g != w {
			t.Errorf("#%d %s result differs:\n got: %.600s\nwant: %.600s", i, v.Tool, g, w)
		}
	}
}
