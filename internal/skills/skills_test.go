package skills

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"github.com/NeoLabs-Systems/neoagent/internal/jsrules"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

type testLog struct{ t *testing.T }

func (l testLog) Write(p []byte) (int, error) {
	l.t.Log(strings.TrimSpace(string(p)))
	return len(p), nil
}

func newLogger(t *testing.T) *slog.Logger { return slog.New(slog.NewTextHandler(testLog{t}, nil)) }

func openDB(t *testing.T) *dbx.DB {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	return db
}

func readJSON(t *testing.T, file string, into any) {
	t.Helper()
	raw, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(raw, into); err != nil {
		t.Fatal(err)
	}
}

// ---- vectors from the Node parsers -------------------------------------------

type vectors struct {
	Documents []struct{ Content, Parsed string } `json:"documents"`
	SkillFile []struct {
		Content string  `json:"content"`
		Parsed  *string `json:"parsed"`
	} `json:"skillFiles"`
	Names []struct {
		Input      any    `json:"input"`
		Normalized string `json:"normalized"`
	} `json:"names"`
	Frontmatters []struct{ Content, Parsed string } `json:"frontmatters"`
	Refs         []struct{ Input, Parsed string }   `json:"refs"`
	Featured     []struct{ HTML, Parsed string }    `json:"featured"`
	Notes        []struct{ Body, Result string }    `json:"notes"`
	Templates    []struct {
		Template string `json:"template"`
		Valid    bool   `json:"valid"`
	} `json:"templates"`
	Prompts []struct {
		Options struct {
			UserID          int64 `json:"userId"`
			MaxTotalChars   int   `json:"maxTotalChars"`
			MaxDescription  int   `json:"maxDescriptionChars"`
			MaxTriggerChars int   `json:"maxTriggerChars"`
		} `json:"options"`
		Prompt string `json:"prompt"`
	} `json:"prompts"`
	EmptyPrompt     string `json:"emptyPrompt"`
	ToolDefinitions []struct {
		UserID int64  `json:"userId"`
		Tools  string `json:"tools"`
	} `json:"toolDefinitions"`
	Execution []struct {
		Tool   string  `json:"tool"`
		Args   string  `json:"args"`
		UserID any     `json:"userId"`
		Result *string `json:"result"`
	} `json:"execution"`
	ExecutionNoRuntime string           `json:"executionNoRuntime"`
	Metrics            []map[string]any `json:"metrics"`
}

func loadVectors(t *testing.T) vectors {
	var v vectors
	readJSON(t, "testdata/vectors.json", &v)
	return v
}

func TestParseDocumentMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Documents {
		doc, problem := ParseDocument(c.Content)
		var got any = workspace.Obj{{Key: "error", Value: problem}}
		if problem == "" {
			got = workspace.Obj{
				{Key: "name", Value: doc.Name}, {Key: "description", Value: doc.Description},
				{Key: "instructions", Value: doc.Instructions}, {Key: "metadata", Value: doc.Metadata},
			}
		}
		if text := jsrules.JSON(got); text != c.Parsed {
			t.Errorf("%q\n  got  %s\n  node %s", c.Content, text, c.Parsed)
		}
	}
}

func TestSkillFileParsingMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).SkillFile {
		parsed, ok := parseSkillFile(c.Content)
		if !ok {
			if c.Parsed != nil {
				t.Errorf("%q: Node parsed it, Go did not: %s", c.Content, *c.Parsed)
			}
			continue
		}
		meta := parsed.Metadata.Merge(Meta{{Key: "extra", Value: 1.0}, {Key: "category", Value: "over"}}).With("enabled", true)
		got := jsrules.JSON(workspace.Obj{
			{Key: "name", Value: parsed.Name}, {Key: "description", Value: parsed.Description},
			{Key: "metadata", Value: meta}, {Key: "instructions", Value: parsed.Instructions},
			{Key: "key", Value: skillKey(ownerUser, 3, parsed.Name)},
		})
		if c.Parsed == nil || got != *c.Parsed {
			t.Errorf("%q\n  got  %s\n  node %v", c.Content, got, c.Parsed)
		}
	}
}

func TestNormalizeNameMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Names {
		input := ""
		switch v := c.Input.(type) {
		case string:
			if v != "__undefined__" {
				input = v
			}
		case float64:
			input = strconv.FormatFloat(v, 'f', -1, 64)
		case bool:
			input = strconv.FormatBool(v)
		}
		if got := NormalizeName(input); got != c.Normalized {
			t.Errorf("%#v: got %q, node %q", c.Input, got, c.Normalized)
		}
	}
}

func asJSON(t *testing.T, v any) any {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func TestFrontmatterParsingMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Frontmatters {
		var want any
		if err := json.Unmarshal([]byte(c.Parsed), &want); err != nil {
			t.Fatal(err)
		}
		var got any
		if parsed, ok := ParseFrontmatter(c.Content); ok {
			got = asJSON(t, map[string]any{"data": parsed.Data, "body": parsed.Body})
		}
		if !reflect.DeepEqual(got, want) {
			t.Errorf("%q\n  got  %v\n  node %v", c.Content, got, want)
		}
	}
}

func TestSkillsShReferencesMatchNode(t *testing.T) {
	for _, c := range loadVectors(t).Refs {
		got := "null"
		if ref, ok := ParseRef(c.Input); ok {
			got = jsrules.JSON(ref)
		}
		if got != c.Parsed {
			t.Errorf("%q: got %s, node %s", c.Input, got, c.Parsed)
		}
	}
}

func TestFeaturedPageMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Featured {
		listings := []workspace.Obj{}
		for _, l := range parseFeaturedPage(c.HTML) {
			listings = append(listings, workspace.Obj{
				{Key: "id", Value: l.ID}, {Key: "source", Value: l.Source}, {Key: "skillId", Value: l.SkillID},
				{Key: "name", Value: l.Name}, {Key: "installs", Value: *l.Installs}, {Key: "official", Value: *l.Official},
			})
		}
		if got := jsrules.JSON(listings); got != c.Parsed {
			t.Errorf("got  %.300s\nnode %.300s", got, c.Parsed)
		}
	}
}

func TestNeoAgentNotesAndTemplatesMatchNode(t *testing.T) {
	v := loadVectors(t)
	for _, c := range v.Notes {
		if got := PrependNeoAgentNotes(c.Body); got != c.Result {
			t.Errorf("%q: got %q, node %q", c.Body, got, c.Result)
		}
	}
	for _, c := range v.Templates {
		if got := IsValidCommandTemplate(c.Template); got != c.Valid {
			t.Errorf("%q: got %v, node %v", c.Template, got, c.Valid)
		}
	}
}

// fixtureSkills are the skills the prompt vectors were recorded with.
func fixtureRunner(t *testing.T, db *dbx.DB, commands CommandRunner) *Runner {
	t.Helper()
	r := NewRunner(RunnerConfig{DB: db, Dir: t.TempDir(), Log: newLogger(t), Commands: commands})
	long := strings.Repeat("word ", 80)
	type spec struct {
		name, description string
		owner             string
		userID            int64
		meta              Meta
	}
	toolParams, _ := workspace.DecodeJSON([]byte(`{"type":"object","properties":{"q":{"type":"string"}}}`))
	for _, s := range []spec{
		{"zeta", "Last one", "", 0, Meta{{Key: "category", Value: "ops"}, {Key: "source", Value: "builtin"}, {Key: "trigger", Value: "when zeta"}}},
		{"alpha", long, "", 0, Meta{{Key: "category", Value: "ops"}, {Key: "trigger", Value: long}}},
		{"beta", "x  y\n z", "", 0, Meta{{Key: "source", Value: "user"}}},
		{"gamma", "disabled", "", 0, Meta{{Key: "enabled", Value: false}}},
		{"delta", "A tool", "", 0, Meta{{Key: "tool", Value: true}, {Key: "parameters", Value: toolParams}}},
		{"epsilon", "Tool without parameters", "", 0, Meta{{Key: "tool", Value: true}, {Key: "category", Value: "Dev"}}},
		{"mine", "owned", ownerUser, 7, Meta{{Key: "category", Value: "ops"}}},
		{"theirs", "owned by 8", ownerUser, 8, nil},
		{"emoji", strings.Repeat("\U0001F600", 150), "", 0, Meta{{Key: "category", Value: "zz"}}},
	} {
		r.addForTest(s.name, s.description, s.owner, s.userID, s.meta)
	}
	return r
}

// addForTest registers a skill the way the vectors' generator did: a file's
// front matter plus metadata given alongside.
func (r *Runner) addForTest(name, description, owner string, userID int64, meta Meta) {
	if owner == "" {
		owner = ownerGlobal
	}
	parsed, _ := parseSkillFile("---\nname: " + name + "\ndescription: " + description + "\n---\nbody")
	skill := &Skill{
		Key: skillKey(owner, userID, parsed.Name), Name: parsed.Name, Description: parsed.Description,
		Metadata: parsed.Metadata.Merge(meta), Instructions: parsed.Instructions,
		FilePath: "/skills/" + name + "/SKILL.md", OwnerType: owner, UserID: userID, ReadOnly: owner != ownerUser,
	}
	r.skills[skill.Key] = skill
	r.order = append(r.order, skill.Key)
}

func TestPromptAndToolDefinitionsMatchNode(t *testing.T) {
	v := loadVectors(t)
	r := fixtureRunner(t, openDB(t), nil)
	for _, c := range v.Prompts {
		got := r.SkillsForPrompt(PromptOptions{
			UserID: c.Options.UserID, MaxTotalChars: c.Options.MaxTotalChars,
			MaxDescriptionChars: c.Options.MaxDescription, MaxTriggerChars: c.Options.MaxTriggerChars,
		})
		if got != c.Prompt {
			t.Errorf("options %+v\n  got  %q\n  node %q", c.Options, got, c.Prompt)
		}
	}
	if got := NewRunner(RunnerConfig{Dir: t.TempDir()}).SkillsForPrompt(PromptOptions{UserID: 1}); got != v.EmptyPrompt {
		t.Errorf("empty prompt: %q", got)
	}
	for _, c := range v.ToolDefinitions {
		tools := r.ToolDefinitions(c.UserID)
		if tools == nil {
			tools = []workspace.Obj{}
		}
		if got := jsrules.JSON(tools); got != c.Tools {
			t.Errorf("user %d\n  got  %s\n  node %s", c.UserID, got, c.Tools)
		}
	}
}

type recordingCommands struct{ t *testing.T }

func (c recordingCommands) ExecuteCommand(_ context.Context, userID int64, command string) (workspace.Obj, error) {
	exit := 0.0
	if strings.Contains(command, "FAIL") {
		exit = 2
	}
	return workspace.Obj{{Key: "received", Value: command}, {Key: "userId", Value: float64(userID)}, {Key: "exitCode", Value: exit}}, nil
}

func TestToolExecutionMatchesNode(t *testing.T) {
	v := loadVectors(t)
	db := openDB(t)
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (7, 'u7', 'x'), (8, 'u8', 'x')`); err != nil {
		t.Fatal(err)
	}
	r := NewRunner(RunnerConfig{DB: db, Dir: t.TempDir(), Log: newLogger(t), Commands: recordingCommands{t}})
	for _, s := range []struct {
		name string
		meta Meta
	}{
		{"say", Meta{{Key: "command", Value: "echo {text} {text} {other}"}}},
		{"bad", Meta{{Key: "command", Value: "echo {x}; rm -rf /"}}},
		{"doc", Meta{}},
		{"off", Meta{{Key: "command", Value: "echo hi"}, {Key: "enabled", Value: false}}},
		{"fail", Meta{{Key: "command", Value: "echo FAIL {x}"}}},
	} {
		r.addForTest(s.name, "", "", 0, s.meta)
	}
	for _, c := range v.Execution {
		args, err := workspace.DecodeJSON([]byte(c.Args))
		if err != nil {
			t.Fatal(err)
		}
		var userID int64
		if f, ok := c.UserID.(float64); ok {
			userID = int64(f)
		}
		result, handled := r.Execute(context.Background(), c.Tool, ToolCall{UserID: userID, Args: args.(workspace.Obj)})
		got := "null"
		if handled {
			got = jsrules.JSON(result)
		}
		want := "null"
		if c.Result != nil {
			want = *c.Result
		}
		if got != want {
			t.Errorf("%s %s\n  got  %s\n  node %s", c.Tool, c.Args, got, want)
		}
	}

	noRuntime := NewRunner(RunnerConfig{DB: db, Dir: t.TempDir(), Log: newLogger(t)})
	noRuntime.addForTest("say", "", "", 0, Meta{{Key: "command", Value: "echo {text} {text} {other}"}})
	result, _ := noRuntime.Execute(context.Background(), "say", ToolCall{UserID: 7, Args: workspace.Obj{{Key: "text", Value: "x"}}})
	if got := jsrules.JSON(result); got != v.ExecutionNoRuntime {
		t.Errorf("without runtime: got %s, node %s", got, v.ExecutionNoRuntime)
	}

	rows, err := db.W.Query(`SELECT user_id, agent_id, skill_name, invocation_count, success_count, failure_count FROM skill_metrics`)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for rows.Next() {
		var user int64
		var agent sql.NullString
		var name string
		var inv, ok, fail int64
		if err := rows.Scan(&user, &agent, &name, &inv, &ok, &fail); err != nil {
			t.Fatal(err)
		}
		got = append(got, jsrules.JSON(workspace.Obj{
			{Key: "user_id", Value: user}, {Key: "agent_id", Value: nil}, {Key: "skill_name", Value: name},
			{Key: "invocation_count", Value: inv}, {Key: "success_count", Value: ok}, {Key: "failure_count", Value: fail},
		}))
	}
	rows.Close()
	var want []string
	for _, m := range v.Metrics {
		raw, _ := json.Marshal(workspace.Obj{
			{Key: "user_id", Value: m["user_id"]}, {Key: "agent_id", Value: nil}, {Key: "skill_name", Value: m["skill_name"]},
			{Key: "invocation_count", Value: m["invocation_count"]}, {Key: "success_count", Value: m["success_count"]}, {Key: "failure_count", Value: m["failure_count"]},
		})
		want = append(want, string(raw))
	}
	sort.Strings(got)
	sort.Strings(want)
	if !reflect.DeepEqual(got, want) {
		t.Errorf("metrics rows\n  got  %v\n  node %v", got, want)
	}
}

// ---- the routes, replayed from the Node server ---------------------------------

type step struct {
	Name      string `json:"name"`
	Method    string `json:"method"`
	Path      string `json:"path"`
	User      int    `json:"user"`
	Body      string `json:"body"`
	SQL       string `json:"sql"`
	Multipart *struct {
		Zip      string            `json:"zip"`
		Filename string            `json:"filename"`
		Field    string            `json:"field"`
		Fields   map[string]string `json:"fields"`
	} `json:"multipart"`
	Expect *struct {
		Status   int      `json:"status"`
		Raw      string   `json:"raw"`
		Outbound []string `json:"outbound"`
	} `json:"expect"`
}

type scenario struct {
	Seed   []struct{ Path, Text string } `json:"seed"`
	Remote map[string]struct {
		Status int    `json:"status"`
		Text   string `json:"text"`
		Base64 string `json:"base64"`
	} `json:"remote"`
	Outbound []struct {
		URL           string `json:"url"`
		UserAgent     string `json:"userAgent"`
		Accept        string `json:"accept"`
		Authorization string `json:"authorization"`
	} `json:"outbound"`
	Steps    []step `json:"steps"`
	Snapshot struct {
		Skills    []map[string]any  `json:"skills"`
		Overrides []map[string]any  `json:"overrides"`
		Versions  []map[string]any  `json:"versions"`
		Files     map[string]string `json:"files"`
	} `json:"snapshot"`
}

var (
	uuidRE  = regexp.MustCompile(`[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}`)
	stampRE = regexp.MustCompile(`\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z`)
)

type roundTripper func(*http.Request) (*http.Response, error)

func (f roundTripper) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

type fixedAudit struct{}

func (fixedAudit) AuditSkills() any {
	return workspace.Obj{
		{Key: "total", Value: 2}, {Key: "issues", Value: []any{workspace.Obj{{Key: "skill", Value: "a"}, {Key: "problem", Value: "x"}}}},
		{Key: "ok", Value: true},
	}
}

func TestRoutesMatchNode(t *testing.T) {
	var sc scenario
	readJSON(t, "testdata/scenario.json", &sc)
	home := t.TempDir()
	skillsDir := filepath.Join(home, "agent-data", "skills")
	for _, f := range sc.Seed {
		target := filepath.Join(skillsDir, f.Path)
		if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(target, []byte(f.Text), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	normalize := func(text string) string {
		return stampRE.ReplaceAllString(uuidRE.ReplaceAllString(strings.ReplaceAll(text, home, "<home>"), "<uuid>"), "<ts>")
	}

	db := openDB(t)
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`); err != nil {
		t.Fatal(err)
	}

	// skills.sh and GitHub: answered from what Node saw, and every request
	// is recorded for comparison.
	type seen struct{ url, userAgent, accept, authorization string }
	var requests []seen
	remote := roundTripper(func(r *http.Request) (*http.Response, error) {
		full := r.URL.String()
		requests = append(requests, seen{full, r.Header.Get("User-Agent"), r.Header.Get("Accept"), r.Header.Get("Authorization")})
		answer, ok := sc.Remote[full]
		if !ok {
			return nil, errors.New("fetch failed")
		}
		var payload io.Reader = strings.NewReader(answer.Text)
		if answer.Base64 != "" {
			data, _ := base64.StdEncoding.DecodeString(answer.Base64)
			payload = bytes.NewReader(data)
		}
		return &http.Response{StatusCode: answer.Status, Body: io.NopCloser(payload), Header: http.Header{}, Request: r}, nil
	})

	runner := NewRunner(RunnerConfig{DB: db, Dir: skillsDir, Log: newLogger(t)})
	if err := runner.Load(context.Background()); err != nil {
		t.Fatal(err)
	}
	api := New(Config{
		DB: db, Runner: runner, Log: newLogger(t), Audit: fixedAudit{},
		SkillsSh: NewSkillsSh(SkillsShConfig{Client: &http.Client{Transport: remote}}),
		UserID: func(r *http.Request) (int64, bool) {
			id, err := strconv.ParseInt(r.Header.Get("X-Test-User"), 10, 64)
			return id, err == nil
		},
	})
	mux := http.NewServeMux()
	api.Routes(mux)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)

	compared := 0
	for _, st := range sc.Steps {
		if st.SQL != "" {
			if _, err := db.W.Exec(st.SQL); err != nil {
				t.Fatalf("%s: %v", st.Name, err)
			}
			continue
		}
		compared++
		var body io.Reader
		contentType := ""
		switch {
		case st.Multipart != nil:
			var buf bytes.Buffer
			mw := multipart.NewWriter(&buf)
			for k, v := range st.Multipart.Fields {
				mw.WriteField(k, v)
			}
			if st.Multipart.Zip != "" {
				data, err := os.ReadFile(filepath.Join("testdata", "zips", st.Multipart.Zip))
				if err != nil {
					t.Fatal(err)
				}
				part, _ := mw.CreateFormFile(st.Multipart.Field, st.Multipart.Filename)
				part.Write(data)
			}
			mw.Close()
			body, contentType = &buf, mw.FormDataContentType()
		case st.Body != "":
			body, contentType = strings.NewReader(st.Body), "application/json"
		}
		req, _ := http.NewRequest(st.Method, srv.URL+st.Path, body)
		if contentType != "" {
			req.Header.Set("Content-Type", contentType)
		}
		if st.User != 0 {
			req.Header.Set("X-Test-User", strconv.Itoa(st.User))
		}
		before := len(requests)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("%s: %v", st.Name, err)
		}
		raw, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		got := normalize(string(raw))
		var urls []string
		for _, r := range requests[before:] {
			urls = append(urls, r.url)
		}
		if !reflect.DeepEqual(urls, st.Expect.Outbound) && !(len(urls) == 0 && len(st.Expect.Outbound) == 0) {
			t.Errorf("%s: outbound requests\n  got  %v\n  node %v", st.Name, urls, st.Expect.Outbound)
		}
		// A request nothing answers fails with a transport error whose text is
		// the HTTP client's own.
		if st.Expect.Raw == `{"error":"fetch failed"}` {
			if resp.StatusCode != 500 {
				t.Errorf("%s: status %d, node 500", st.Name, resp.StatusCode)
			}
			continue
		}
		if resp.StatusCode != st.Expect.Status || got != st.Expect.Raw {
			t.Errorf("%s: %s %s\n  got  %d %.400s\n  node %d %.400s", st.Name, st.Method, st.Path, resp.StatusCode, got, st.Expect.Status, st.Expect.Raw)
		}
	}
	if compared < 140 {
		t.Fatalf("only %d requests replayed", compared)
	}

	var wantRequests []string
	for _, o := range sc.Outbound {
		wantRequests = append(wantRequests, o.URL)
		if o.UserAgent != "NeoAgent" || o.Authorization != "" {
			t.Fatalf("unexpected recorded header %+v", o)
		}
	}
	if len(requests) != len(wantRequests) {
		t.Fatalf("%d outbound requests, node made %d", len(requests), len(wantRequests))
	}
	for i, r := range requests {
		if r.url != wantRequests[i] || r.userAgent != "NeoAgent" || r.authorization != "" || r.accept != sc.Outbound[i].Accept {
			t.Errorf("request %d: got %+v, node %+v", i, r, sc.Outbound[i])
		}
	}

	checkRows := func(name, query string, want []map[string]any) {
		rows, err := db.W.Query(query)
		if err != nil {
			t.Fatal(err)
		}
		defer rows.Close()
		cols, _ := rows.Columns()
		var got []map[string]any
		for rows.Next() {
			values := make([]any, len(cols))
			ptrs := make([]any, len(cols))
			for i := range values {
				ptrs[i] = &values[i]
			}
			if err := rows.Scan(ptrs...); err != nil {
				t.Fatal(err)
			}
			row := map[string]any{}
			for i, c := range cols {
				if b, ok := values[i].([]byte); ok {
					values[i] = string(b)
				}
				row[c] = values[i]
			}
			raw, _ := json.Marshal(row)
			var normalized map[string]any
			json.Unmarshal([]byte(normalize(string(raw))), &normalized)
			got = append(got, normalized)
		}
		if !reflect.DeepEqual(got, want) {
			t.Errorf("%s rows differ\n  got  %.1500v\n  node %.1500v", name, got, want)
		}
	}
	checkRows("skills", `SELECT id, user_id, name, description, file_path, metadata, enabled, auto_created FROM skills ORDER BY id`, sc.Snapshot.Skills)
	checkRows("overrides", `SELECT user_id, skill_name, enabled, hidden FROM user_skill_overrides ORDER BY user_id, skill_name`, sc.Snapshot.Overrides)
	checkRows("versions", `SELECT skill_id, version, name, content_md, metadata_json, status FROM agent_skill_versions ORDER BY skill_id, version`, sc.Snapshot.Versions)

	files := map[string]string{}
	err := filepath.WalkDir(skillsDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		data, _ := os.ReadFile(path)
		rel, _ := filepath.Rel(skillsDir, path)
		if text := string(data); bytes.Equal([]byte(text), data) && validUTF8(data) {
			files[rel] = normalize(text)
		} else {
			files[rel] = "base64:" + base64.StdEncoding.EncodeToString(data)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	for rel, want := range sc.Snapshot.Files {
		if got, ok := files[rel]; !ok || got != want {
			t.Errorf("file %s: got %.200q (present %v)\n  node %.200q", rel, got, ok, want)
		}
	}
	for rel := range files {
		if _, ok := sc.Snapshot.Files[rel]; !ok {
			t.Errorf("file %s exists only in Go", rel)
		}
	}
}

func validUTF8(data []byte) bool {
	return strings.ToValidUTF8(string(data), "\x00") == string(data)
}
