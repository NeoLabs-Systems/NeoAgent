package agentimport

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

// scanVectors is what the Node importers read from testdata/fixtures
// (regenerate with testdata/gen_vectors.js).
type scanVectors struct {
	OpenClaw json.RawMessage `json:"openclaw"`
	Hermes   json.RawMessage `json:"hermes"`
	Contents struct {
		OpenClaw json.RawMessage `json:"openclaw"`
		Hermes   json.RawMessage `json:"hermes"`
	} `json:"contents"`
	Selected struct {
		OpenClaw json.RawMessage `json:"openclaw"`
		Hermes   json.RawMessage `json:"hermes"`
	} `json:"selected"`
	Homes struct {
		OpenClaw []string `json:"openclaw"`
		Hermes   []string `json:"hermes"`
	} `json:"homes"`
	Providers []struct{ ID, Label, EnvKey string } `json:"providers"`
}

func fixtures(t *testing.T) string {
	t.Helper()
	abs, err := filepath.Abs("testdata/fixtures")
	if err != nil {
		t.Fatal(err)
	}
	return abs
}

func loadScan(t *testing.T) scanVectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/scan.json")
	if err != nil {
		t.Fatal(err)
	}
	var v scanVectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func providers(v scanVectors) []AIProvider {
	var out []AIProvider
	for _, p := range v.Providers {
		out = append(out, AIProvider(p))
	}
	return out
}

// nilIfEmpty makes optional strings null, as Node has them.
func nilIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func listOrEmpty[T any](in []T, f func(T) any) []any {
	out := []any{}
	for _, v := range in {
		out = append(out, f(v))
	}
	return out
}

// nodeShape renders a bundle the way JSON.stringify renders Node's.
func nodeShape(b Bundle) map[string]any {
	keys := map[string]any{}
	for _, n := range b.Keys.names {
		keys[n] = b.Keys.get(n)
	}
	headers := func(h []header) any {
		m := map[string]any{}
		for _, x := range h {
			m[x.Name] = x.Value
		}
		return m
	}
	return map[string]any{
		"source": b.Source, "label": b.Label, "path": b.Path, "home": b.Home,
		"agents": listOrEmpty(b.Agents, func(a Agent) any {
			return map[string]any{
				"key": a.Key, "name": a.Name, "isDefault": a.IsDefault, "instructions": nilIfEmpty(a.Instructions),
				"memories":    listOrEmpty(a.Memories, func(m Memory) any { return map[string]any{"text": m.Text, "category": m.Category} }),
				"userProfile": nilIfEmpty(a.UserProfile),
				"dailyLogs":   listOrEmpty(a.DailyLogs, func(l DailyLog) any { return map[string]any{"date": l.Date, "content": l.Content} }),
				"workspace":   a.Workspace, "model": nilIfEmpty(a.Model),
			}
		}),
		"skills": listOrEmpty(b.Skills, func(s Skill) any {
			return map[string]any{"name": s.Name, "description": s.Description, "body": s.Body, "dir": s.Dir, "origin": s.Origin,
				"files": listOrEmpty(s.Files, func(f string) any { return f })}
		}),
		"keys": keys, "ignoredKeys": listOrEmpty(b.IgnoredKeys, func(s string) any { return s }),
		"sourceModel": nilIfEmpty(b.SourceModel), "model": nilIfEmpty(b.Model),
		"mcp": listOrEmpty(b.MCP, func(m MCPServer) any {
			var token any
			if m.Token != nil {
				token = *m.Token
			}
			return map[string]any{"name": m.Name, "url": m.URL, "token": token, "headers": headers(m.Headers), "transport": m.Transport, "enabled": m.Enabled}
		}),
		"tasks": listOrEmpty(b.Tasks, func(task Task) any {
			trigger := map[string]any{"mode": task.Trigger.Mode}
			if task.Trigger.Mode == "recurring" {
				trigger["cronExpression"] = task.Trigger.CronExpression
				trigger["note"] = nilIfEmpty(task.Trigger.Note)
			} else {
				trigger["runAt"] = task.Trigger.RunAt
			}
			var notify any
			if task.Notify != nil {
				notify = map[string]any{"platform": task.Notify.Platform, "to": nilIfEmpty(task.Notify.To)}
			}
			return map[string]any{"name": task.Name, "agentKey": task.AgentKey, "prompt": task.Prompt, "trigger": trigger,
				"enabled": task.Enabled, "tz": nilIfEmpty(task.TZ), "notify": notify, "model": nilIfEmpty(task.Model), "note": nilIfEmpty(task.Note)}
		}),
		"channels": listOrEmpty(b.Channels, func(c Channel) any {
			var config any
			if c.Config != nil {
				config = headers(c.Config)
			}
			return map[string]any{"platform": c.Platform, "config": config, "allow": listOrEmpty(c.Allow, func(s string) any { return s })}
		}),
		"timezone": nilIfEmpty(b.Timezone),
		"skipped": listOrEmpty(b.Skipped, func(s Skipped) any {
			m := map[string]any{"kind": s.Kind, "name": s.Name, "reason": s.Reason}
			if s.Detail != nil {
				m["detail"] = jsonValue(s.Detail)
			}
			return m
		}),
	}
}

// jsonValue turns ordered objects into plain maps for comparison.
func jsonValue(v any) any {
	switch t := v.(type) {
	case *Obj:
		m := map[string]any{}
		for _, k := range t.Keys() {
			m[k] = jsonValue(t.Get(k))
		}
		return m
	case []any:
		out := []any{}
		for _, x := range t {
			out = append(out, jsonValue(x))
		}
		return out
	}
	return v
}

func sameAsNode(t *testing.T, label string, got any, want json.RawMessage, root string) {
	t.Helper()
	raw, _ := json.Marshal(got)
	text := strings.ReplaceAll(string(raw), strings.ReplaceAll(root, `\`, `\\`), "<ROOT>")
	var g, w any
	if err := json.Unmarshal([]byte(text), &g); err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(want, &w); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(g, w) {
		gj, _ := json.MarshalIndent(g, "", " ")
		wj, _ := json.MarshalIndent(w, "", " ")
		t.Errorf("%s differs from Node.\n--- got\n%s\n--- want\n%s", label, gj, wj)
	}
}

var fixedNow = func() time.Time { return time.Date(2026, 11, 24, 12, 0, 0, 0, time.UTC) }

func TestScanMatchesNode(t *testing.T) {
	v := loadScan(t)
	root := fixtures(t)
	s := Scanner{HomeDir: root, Now: fixedNow}

	oc := s.ScanOpenClaw(filepath.Join(root, "openclaw", ".openclaw"))
	sameAsNode(t, "openclaw bundle", nodeShape(oc), v.OpenClaw, root)
	hm := s.ScanHermes(filepath.Join(root, "hermes", ".hermes"))
	sameAsNode(t, "hermes bundle", nodeShape(hm), v.Hermes, root)

	sameAsNode(t, "openclaw contents", bundleContents(oc, providers(v)), v.Contents.OpenClaw, root)
	sameAsNode(t, "hermes contents", bundleContents(hm, providers(v)), v.Contents.Hermes, root)

	sameAsNode(t, "openclaw selection", nodeShape(selectParts(oc, []string{"memories", "skills"})), v.Selected.OpenClaw, root)
	sameAsNode(t, "hermes selection", nodeShape(selectParts(hm, []string{"keys", "tasks"})), v.Selected.Hermes, root)
}

func TestFindHomes(t *testing.T) {
	v := loadScan(t)
	root := fixtures(t)
	got := Scanner{HomeDir: filepath.Join(root, "openclaw")}.FindOpenClawHomes()
	if !reflect.DeepEqual(strings.ReplaceAll(strings.Join(got, ","), root, "<ROOT>"), strings.Join(v.Homes.OpenClaw, ",")) {
		t.Errorf("openclaw homes %v want %v", got, v.Homes.OpenClaw)
	}
	got = Scanner{HomeDir: filepath.Join(root, "hermes")}.FindHermesHomes()
	if !reflect.DeepEqual(strings.ReplaceAll(strings.Join(got, ","), root, "<ROOT>"), strings.Join(v.Homes.Hermes, ",")) {
		t.Errorf("hermes homes %v want %v", got, v.Homes.Hermes)
	}
}

func mustRead(t *testing.T, path string) []byte {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}
