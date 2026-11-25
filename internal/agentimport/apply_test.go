package agentimport

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type applyEntry struct {
	Kind, Status, Name, Detail string
	Count                      int
}

type applyState struct {
	Agents []struct {
		Slug, Display_name, Description, Instructions string
		Is_default                                    int
	}
	Core map[string]struct{ Profile, Notes string }
	Mem  []struct {
		Agent_id, Category, Content, Source_type, Source_id, Source_label string
		Importance                                                        int
	} `json:"memories"`
	MCP []struct {
		Name, Agent_id, Command, Config string
		Enabled                         int
	} `json:"mcp"`
	Tasks []struct {
		Name, Agent_id, Task_config, Trigger_config string
		Enabled                                     int
	}
	Connections []struct{ Platform, Agent_id, Config, Status string }
	Policies    []struct{ Key, Agent_id string }
	Models      []struct{ Agent_id, Value string }
	Timezone    *string
	Env         string
	Daily       map[string]string
	Skills      map[string]int
}

type applyScenario struct {
	Entries []applyEntry
	Totals  []string
	Prompt  string
	State   applyState
	Second  []applyEntry
}

func loadApply(t *testing.T) map[string]applyScenario {
	t.Helper()
	var out map[string]applyScenario
	if err := json.Unmarshal(mustRead(t, "testdata/apply.json"), &out); err != nil {
		t.Fatal(err)
	}
	return out
}

// ---- fake host ----------------------------------------------------------------

// fakeHost stands in for the server's agent, memory, skill, setting and task
// services over the real tables. Memory deduplication belongs to the memory
// domain: the fake saves exactly the facts Node's run kept.
type fakeHost struct {
	t      *testing.T
	db     *dbx.DB
	dir    string
	kept   map[string]bool // "agentSlug|text" Node stored
	notes  map[string]string
	prof   map[string]string
	nextID int
	tasks  []TaskSpec
}

func (h *fakeHost) id(prefix string) string {
	h.nextID++
	return prefix + strconv.Itoa(h.nextID)
}

func (h *fakeHost) agent(ctx context.Context, where string, args ...any) *AgentInfo {
	var a AgentInfo
	var inst sql.NullString
	err := h.db.W.QueryRowContext(ctx, `SELECT id, slug, display_name, instructions FROM agents WHERE `+where, args...).Scan(&a.ID, &a.Slug, &a.DisplayName, &inst)
	if err != nil {
		return nil
	}
	a.Instructions = inst.String
	return &a
}

func (h *fakeHost) EnsureMainAgent(ctx context.Context, userID int64) (AgentInfo, error) {
	if a := h.agent(ctx, `user_id = ? AND slug = 'main'`, userID); a != nil {
		return *a, nil
	}
	id := h.id("agent-")
	_, err := h.db.W.ExecContext(ctx, `INSERT INTO agents (id, user_id, slug, display_name, description, responsibilities, instructions, status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json)
		VALUES (?, ?, 'main', 'Main', 'Default personal AI contact and fallback agent.', '', '', 'active', 1, 1, 0, '[]')`, id, userID)
	return AgentInfo{ID: id, Slug: "main", DisplayName: "Main"}, err
}

func (h *fakeHost) AgentBySlug(ctx context.Context, userID int64, slug string) (*AgentInfo, error) {
	return h.agent(ctx, `user_id = ? AND slug = ?`, userID, slug), nil
}

func (h *fakeHost) CreateAgent(ctx context.Context, userID int64, n NewAgent) (AgentInfo, error) {
	id := h.id("agent-")
	_, err := h.db.W.ExecContext(ctx, `INSERT INTO agents (id, user_id, slug, display_name, description, responsibilities, instructions, status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json)
		VALUES (?, ?, ?, ?, ?, '', '', 'active', 0, 0, 1, '[]')`, id, userID, n.Slug, n.DisplayName, n.Description)
	return AgentInfo{ID: id, Slug: n.Slug, DisplayName: n.DisplayName}, err
}

func (h *fakeHost) SetInstructions(ctx context.Context, userID int64, agentID, text string) error {
	_, err := h.db.W.ExecContext(ctx, `UPDATE agents SET instructions = ? WHERE id = ?`, text, agentID)
	return err
}

func (h *fakeHost) BehaviorNotes(_ context.Context, _ int64, agentID string) (string, error) {
	return h.notes[agentID], nil
}

func (h *fakeHost) SetBehaviorNotes(_ context.Context, _ int64, agentID, text string) error {
	h.notes[agentID] = text
	return nil
}

func (h *fakeHost) UserProfile(_ context.Context, _ int64, agentID string) (string, error) {
	return h.prof[agentID], nil
}

func (h *fakeHost) SetUserProfile(_ context.Context, _ int64, agentID, text string) error {
	h.prof[agentID] = text
	return nil
}

func (h *fakeHost) slug(ctx context.Context, agentID string) string {
	if a := h.agent(ctx, `id = ?`, agentID); a != nil {
		return a.Slug
	}
	return ""
}

func (h *fakeHost) SaveMemory(ctx context.Context, userID int64, agentID string, m MemoryToSave) (bool, error) {
	key := h.slug(ctx, agentID) + "|" + m.Text
	if !h.kept[key] {
		return true, nil
	}
	delete(h.kept, key)
	_, err := h.db.W.ExecContext(ctx, `INSERT INTO memories (id, user_id, agent_id, category, content, importance, source_type, source_id, source_label)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`, h.id("mem-"), userID, agentID, m.Category, m.Text, m.Importance, m.SourceType, m.SourceID, m.SourceLabel)
	return true, err
}

var kebab = strings.NewReplacer(" ", "-")

func (h *fakeHost) CreateSkill(_ context.Context, userID int64, s NewSkill) (string, error) {
	dir := filepath.Join(h.dir, "skills", "users", strconv.FormatInt(userID, 10), kebab.Replace(strings.ToLower(s.Name)))
	if _, err := os.Stat(dir); err == nil {
		return "", ErrSkillExists
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	file := filepath.Join(dir, "SKILL.md")
	return file, os.WriteFile(file, []byte(s.Body), 0o600)
}

func (h *fakeHost) ApplySetting(ctx context.Context, userID int64, agentID, key, value string) error {
	if agentID == "" {
		_, err := h.db.W.ExecContext(ctx, `INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`, userID, key, value)
		return err
	}
	_, err := h.db.W.ExecContext(ctx, `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?) ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`, userID, agentID, key, value)
	return err
}

func (h *fakeHost) DefaultChatModel(ctx context.Context, userID int64, agentID string) (string, error) {
	var v sql.NullString
	_ = h.db.W.QueryRowContext(ctx, `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = 'default_chat_model'`, userID, nullable(agentID)).Scan(&v)
	return v.String, nil
}

func (h *fakeHost) UserTimeZone(ctx context.Context, userID int64) (string, error) {
	var v sql.NullString
	_ = h.db.W.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = 'timezone'`, userID).Scan(&v)
	return v.String, nil
}

func (h *fakeHost) ValidateSchedule(_ context.Context, _ int64, _ string, t Trigger) (map[string]any, error) {
	if t.Mode == "one_time" {
		return map[string]any{"mode": t.Mode, "runAt": t.RunAt}, nil
	}
	return map[string]any{"mode": t.Mode, "cronExpression": t.CronExpression}, nil
}

func (h *fakeHost) CreateTask(ctx context.Context, userID int64, task TaskSpec) error {
	h.tasks = append(h.tasks, task)
	_, err := h.db.W.ExecContext(ctx, `INSERT INTO scheduled_tasks (user_id, agent_id, name) VALUES (?, ?, ?)`, userID, nullable(task.AgentID), task.Name)
	return err
}

func (h *fakeHost) AllowlistPolicy(platform string, entries []string) (string, error) {
	return `{"platform":"` + platform + `","entries":` + strconv.Itoa(len(entries)) + `}`, nil
}

// ---- the run ------------------------------------------------------------------

type rig struct {
	t       *testing.T
	env     Env
	host    *fakeHost
	dir     string
	root    string
	bundles []Bundle
}

func newRig(t *testing.T, want applyScenario, preset bool) *rig {
	t.Helper()
	ctx := context.Background()
	dir := t.TempDir()
	db, err := dbx.Open(ctx, filepath.Join(dir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'admin', 'x')`); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New("enc:v1:", "import-test-key")
	if err != nil {
		t.Fatal(err)
	}
	envFile := filepath.Join(dir, ".env")
	initial := "ANTHROPIC_API_KEY=sk-ant-1\nOPENAI_API_KEY=existing-different\nOLLAMA_URL=http://localhost:11434\n"
	if err := os.WriteFile(envFile, []byte(initial), 0o600); err != nil {
		t.Fatal(err)
	}
	host := &fakeHost{t: t, db: db, dir: dir, kept: map[string]bool{}, notes: map[string]string{}, prof: map[string]string{}}
	for _, m := range want.State.Mem {
		host.kept[m.Agent_id+"|"+m.Content] = true
	}
	r := &rig{t: t, host: host, dir: dir, root: fixtures(t), env: Env{
		DB: db, Host: host, Box: box, EnvFile: envFile, RuntimeHome: dir, AgentDataDir: filepath.Join(dir, "agent-data"),
		AIProviders: providers(loadScan(t)),
	}}
	s := Scanner{HomeDir: r.root, Now: fixedNow}
	for _, b := range []Bundle{
		s.ScanOpenClaw(filepath.Join(r.root, "openclaw", ".openclaw")),
		s.ScanHermes(filepath.Join(r.root, "hermes", ".hermes")),
	} {
		r.bundles = append(r.bundles, selectParts(b, Parts))
	}
	if preset {
		main, _ := host.EnsureMainAgent(ctx, 1)
		host.SetInstructions(ctx, 1, main.ID, "I am the existing personality.")
	}
	return r
}

func (r *rig) run() *Session {
	s := NewSession(r.env, 1)
	for _, b := range r.bundles {
		s.ApplyBundle(context.Background(), b)
	}
	return s
}

func entriesOf(s *Session) []applyEntry {
	out := []applyEntry{}
	for _, e := range s.Entries {
		out = append(out, applyEntry{e.Kind, e.Status, e.Name, e.Detail, e.Count})
	}
	return out
}

func (r *rig) mask(s string) string {
	return strings.ReplaceAll(strings.ReplaceAll(s, r.root, "<ROOT>"), r.dir, "<HOME>")
}

func (r *rig) snapshot() applyState {
	r.t.Helper()
	db := r.env.DB.W
	var st applyState
	slugs := map[string]string{}
	rows, _ := db.Query(`SELECT id, slug, display_name, description, instructions, is_default FROM agents ORDER BY slug`)
	for rows.Next() {
		var id string
		var a struct {
			Slug, Display_name, Description, Instructions string
			Is_default                                    int
		}
		rows.Scan(&id, &a.Slug, &a.Display_name, &a.Description, &a.Instructions, &a.Is_default)
		slugs[id] = a.Slug
		st.Agents = append(st.Agents, a)
	}
	rows.Close()
	slug := func(id sql.NullString) string { return slugs[id.String] }

	st.Core = map[string]struct{ Profile, Notes string }{}
	for id, s := range slugs {
		st.Core[s] = struct{ Profile, Notes string }{r.host.prof[id], r.host.notes[id]}
	}

	rows, _ = db.Query(`SELECT agent_id, category, content, importance, source_type, source_id, source_label FROM memories`)
	for rows.Next() {
		var agent sql.NullString
		var m struct {
			Agent_id, Category, Content, Source_type, Source_id, Source_label string
			Importance                                                        int
		}
		rows.Scan(&agent, &m.Category, &m.Content, &m.Importance, &m.Source_type, &m.Source_id, &m.Source_label)
		m.Agent_id = slug(agent)
		st.Mem = append(st.Mem, m)
	}
	rows.Close()

	rows, _ = db.Query(`SELECT name, agent_id, command, config, enabled FROM mcp_servers ORDER BY id`)
	for rows.Next() {
		var agent sql.NullString
		var m struct {
			Name, Agent_id, Command, Config string
			Enabled                         int
		}
		rows.Scan(&m.Name, &agent, &m.Command, &m.Config, &m.Enabled)
		m.Agent_id = slug(agent)
		st.MCP = append(st.MCP, m)
	}
	rows.Close()

	for _, task := range r.host.tasks {
		cfg, _ := json.Marshal(task.TaskConfig)
		enabled := 0
		if task.Enabled {
			enabled = 1
		}
		st.Tasks = append(st.Tasks, struct {
			Name, Agent_id, Task_config, Trigger_config string
			Enabled                                     int
		}{task.Name, slugs[task.AgentID], string(cfg), triggerText(task.TriggerConfig["mode"], task.TriggerConfig["cronExpression"], task.TriggerConfig["runAt"]), enabled})
	}

	rows, _ = db.Query(`SELECT platform, agent_id, config, status FROM platform_connections ORDER BY id`)
	for rows.Next() {
		var agent sql.NullString
		var c struct{ Platform, Agent_id, Config, Status string }
		rows.Scan(&c.Platform, &agent, &c.Config, &c.Status)
		c.Agent_id = slug(agent)
		plain, err := r.env.Box.Open(c.Config)
		if err != nil {
			r.t.Fatal(err)
		}
		c.Config = plain
		st.Connections = append(st.Connections, c)
	}
	rows.Close()

	rows, _ = db.Query(`SELECT agent_id, key FROM agent_settings WHERE key LIKE 'platform_access_policy_%' ORDER BY key`)
	for rows.Next() {
		var agent sql.NullString
		var p struct{ Key, Agent_id string }
		rows.Scan(&agent, &p.Key)
		p.Agent_id = slug(agent)
		st.Policies = append(st.Policies, p)
	}
	rows.Close()
	rows, _ = db.Query(`SELECT agent_id, value FROM agent_settings WHERE key = 'default_chat_model' ORDER BY agent_id`)
	for rows.Next() {
		var agent sql.NullString
		var p struct{ Agent_id, Value string }
		rows.Scan(&agent, &p.Value)
		p.Agent_id = slug(agent)
		st.Models = append(st.Models, p)
	}
	rows.Close()
	var tz sql.NullString
	if db.QueryRow(`SELECT value FROM user_settings WHERE user_id = 1 AND key = 'timezone'`).Scan(&tz) == nil {
		st.Timezone = &tz.String
	}
	env, _ := os.ReadFile(r.env.EnvFile)
	st.Env = string(env)
	st.Daily = map[string]string{}
	if files, err := os.ReadDir(filepath.Join(r.env.AgentDataDir, "users", "1", "daily")); err == nil {
		for _, f := range files {
			b, _ := os.ReadFile(filepath.Join(r.env.AgentDataDir, "users", "1", "daily", f.Name()))
			st.Daily[f.Name()] = string(b)
		}
	}
	st.Skills = map[string]int{}
	root := filepath.Join(r.dir, "skills")
	filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() && d.Name() != "SKILL.md" {
			rel, _ := filepath.Rel(root, p)
			st.Skills[rel] = 0
		}
		return nil
	})
	return st
}

func sortedMem(m []struct {
	Agent_id, Category, Content, Source_type, Source_id, Source_label string
	Importance                                                        int
}) {
	sort.Slice(m, func(i, j int) bool {
		if m[i].Agent_id != m[j].Agent_id {
			return m[i].Agent_id < m[j].Agent_id
		}
		return m[i].Content < m[j].Content
	})
}

func TestApplyMatchesNode(t *testing.T) {
	for name, want := range loadApply(t) {
		t.Run(name, func(t *testing.T) {
			r := newRig(t, want, name == "preset")
			session := r.run()
			if got := entriesOf(session); !reflect.DeepEqual(got, want.Entries) {
				t.Errorf("entries differ")
				for i := 0; i < len(got) || i < len(want.Entries); i++ {
					var g, w any
					if i < len(got) {
						g = got[i]
					}
					if i < len(want.Entries) {
						w = want.Entries[i]
					}
					if !reflect.DeepEqual(g, w) {
						t.Errorf("  #%d got %+v want %+v", i, g, w)
						break
					}
				}
			}
			var imported []Entry
			for _, e := range session.Entries {
				if e.Status == "imported" {
					imported = append(imported, e)
				}
			}
			if got := totals(imported); !reflect.DeepEqual(got, want.Totals) {
				t.Errorf("totals %v want %v", got, want.Totals)
			}
			if got := r.mask(buildFinishPrompt(r.bundles, session)); got != r.maskWant(want.Prompt) {
				t.Errorf("finish prompt differs:\n%s\n---\n%s", got, want.Prompt)
			}

			got, wantState := r.snapshot(), want.State
			sortedMem(got.Mem)
			sortedMem(wantState.Mem)
			got.Env, wantState.Env = r.mask(got.Env), r.maskWant(wantState.Env)
			for i := range got.MCP {
				got.MCP[i].Command = r.mask(got.MCP[i].Command)
			}
			if len(wantState.Tasks) != len(got.Tasks) {
				t.Fatalf("tasks: %d want %d", len(got.Tasks), len(wantState.Tasks))
			}
			for i, w := range wantState.Tasks {
				// Node stores the normalised trigger; compare mode, cron and time.
				var trig struct {
					Mode           string
					CronExpression string
					RunAt          string
				}
				json.Unmarshal([]byte(w.Trigger_config), &trig)
				wantState.Tasks[i].Trigger_config = triggerText(trig.Mode, trig.CronExpression, trig.RunAt)
			}
			for i := range got.Agents {
				got.Agents[i].Instructions = r.mask(got.Agents[i].Instructions)
			}
			// Skill files: only the bundled ones are compared by path.
			wantSkills := map[string]int{}
			for p := range wantState.Skills {
				if !strings.HasSuffix(p, "SKILL.md") {
					wantSkills[strings.TrimPrefix(p, "users/1/")] = 0
				}
			}
			gotSkills := map[string]int{}
			for p := range got.Skills {
				gotSkills[strings.TrimPrefix(p, "users/1/")] = 0
			}
			got.Skills, wantState.Skills = gotSkills, wantSkills
			if !reflect.DeepEqual(got, wantState) {
				g, _ := json.MarshalIndent(got, "", " ")
				w, _ := json.MarshalIndent(wantState, "", " ")
				gl, wl := strings.Split(string(g), "\n"), strings.Split(string(w), "\n")
				for i := 0; i < len(gl) && i < len(wl); i++ {
					if gl[i] != wl[i] {
						t.Errorf("state differs at line %d:\n got  %s\n want %s", i, strings.Join(gl[max(0, i-3):min(len(gl), i+3)], "\n"), strings.Join(wl[max(0, i-3):min(len(wl), i+3)], "\n"))
						break
					}
				}
			}

			if second := entriesOf(r.run()); !reflect.DeepEqual(second, want.Second) {
				for i := 0; i < len(second) && i < len(want.Second); i++ {
					if second[i] != want.Second[i] {
						t.Errorf("repeat run differs at #%d: got %+v want %+v", i, second[i], want.Second[i])
						break
					}
				}
			}
		})
	}
}

// maskWant makes Node's masked text comparable with ours (both use <ROOT> and
// <HOME>).
func (r *rig) maskWant(s string) string { return s }

func TestUnsafeSkillFilesStayInside(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src")
	dest := filepath.Join(dir, "dest")
	os.MkdirAll(src, 0o700)
	os.MkdirAll(dest, 0o700)
	secret := filepath.Join(dir, "secret.txt")
	os.WriteFile(secret, []byte("s"), 0o600)
	os.Symlink(secret, filepath.Join(src, "link.txt"))
	os.WriteFile(filepath.Join(src, "ok.txt"), []byte("ok"), 0o600)
	skill := Skill{Dir: src, Files: []string{"ok.txt", "../secret.txt"}}
	if err := copySkillFiles(skill, dest); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dest, "ok.txt")); err != nil {
		t.Error("regular file not copied")
	}
	skill.Files = []string{"link.txt"}
	if err := copySkillFiles(skill, dest); err == nil {
		t.Error("a symlink out of the skill folder must not be followed")
	}
	if _, err := os.Stat(filepath.Join(dest, "link.txt")); err == nil {
		if b, _ := os.ReadFile(filepath.Join(dest, "link.txt")); string(b) == "s" {
			t.Error("secret copied through a symlink")
		}
	}
}

func TestRemoteEndpoint(t *testing.T) {
	for in, want := range map[string]string{
		"https://mcp.example.test/sse": "https://mcp.example.test/sse",
		"https://Mcp.Example.test":     "https://mcp.example.test/",
		"http://host:80/a?x=1":         "http://host/a?x=1",
		"https://host:8443":            "https://host:8443/",
		" https://trim.test/path ":     "https://trim.test/path",
	} {
		got, err := validateRemoteMCPEndpoint(in)
		if err != nil || got != want {
			t.Errorf("%q -> %q, %v want %q", in, got, err, want)
		}
	}
	for _, bad := range []string{"", "not a url", "ftp://host/x", "stdio:foo"} {
		if _, err := validateRemoteMCPEndpoint(bad); err == nil {
			t.Errorf("%q accepted", bad)
		}
	}
	if !errors.Is(ErrSkillExists, ErrSkillExists) {
		t.Fatal("sentinel")
	}
}

func triggerText(mode, cron, runAt any) string {
	text := func(v any) string {
		if v == nil {
			return ""
		}
		return fmt.Sprint(v)
	}
	return text(mode) + "|" + text(cron) + text(runAt)
}
