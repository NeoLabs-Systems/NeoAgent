package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

type stageIntegrations struct{ got dyn.Map }

func (s *stageIntegrations) Execute(_ context.Context, _ *Run, _ string, args dyn.Map) (any, bool, error) {
	s.got = args
	return dyn.Map{"ok": true}, true, nil
}

// Integration tools declare their workspace file arguments in their
// definitions (Node fileArgs); the backend stages those files first.
func TestIntegrationFileArgsAreStaged(t *testing.T) {
	raw, err := os.ReadFile("../../integrations/nextcloud/provider.json")
	if err != nil {
		t.Fatal(err)
	}
	var def tools.Definition
	var walk func(any)
	walk = func(v any) {
		switch x := v.(type) {
		case map[string]any:
			if x["name"] == "nextcloud_upload_file" {
				b, _ := json.Marshal(x)
				_ = json.Unmarshal(b, &def)
			}
			for _, child := range x {
				walk(child)
			}
		case []any:
			for _, child := range x {
				walk(child)
			}
		}
	}
	var doc any
	_ = json.Unmarshal(raw, &doc)
	walk(doc)
	if len(def.FileArgs) != 1 || def.FileArgs[0] != "file_path" {
		t.Fatalf("definition fileArgs %v", def.FileArgs)
	}
	reg, err := tools.NewRegistry(noEnv{})
	if err != nil {
		t.Fatal(err)
	}
	integ := &stageIntegrations{}
	var staged []string
	b := New(Deps{Tools: reg, Integrations: integ, StageFiles: func(_ context.Context, _ *Run, args dyn.Map, fileArgs []string) (dyn.Map, error) {
		staged = fileArgs
		if args["file_path"] == "missing.txt" {
			return nil, errors.New(`file_path "missing.txt" could not be read from your workspace: not found`)
		}
		out := dyn.Map{}
		for k, v := range args {
			out[k] = v
		}
		out["file_path"] = "/artifacts/1/x.txt"
		return out, nil
	}})
	s := &ai.Session{UserID: 1, Catalog: []tools.Definition{def}}
	got, err := b.Execute(context.Background(), s, ai.Call{Name: "nextcloud_upload_file", Arguments: dyn.Map{"file_path": "x.txt", "path": "/x.txt"}}, "")
	if err != nil || dyn.Get(got, "ok") != true || integ.got["file_path"] != "/artifacts/1/x.txt" || len(staged) != 1 {
		t.Fatalf("%v %v %v %v", got, err, integ.got, staged)
	}
	got, _ = b.Execute(context.Background(), s, ai.Call{Name: "nextcloud_upload_file", Arguments: dyn.Map{"file_path": "missing.txt"}}, "")
	if dyn.Str(dyn.Get(got, "error")) != `file_path "missing.txt" could not be read from your workspace: not found` {
		t.Fatalf("%v", got)
	}
}
