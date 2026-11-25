package credentials

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type step struct {
	Op       string `json:"op"`
	User     int64  `json:"user"`
	Input    any    `json:"input"`
	Binding  string `json:"binding"`
	Contains string `json:"contains"`
	Result   any    `json:"result"`
	Error    string `json:"error"`
}

type scenario struct {
	Items    map[string]Item `json:"items"`
	Steps    []step          `json:"steps"`
	Bindings []struct {
		UserID       int64  `json:"userId"`
		Alias        string `json:"alias"`
		UsageType    string `json:"usageType"`
		ConnectionID int64  `json:"connectionId"`
		ProviderKey  string `json:"providerKey"`
		ItemRef      string `json:"itemRef"`
		FieldConfig  string `json:"fieldConfig"`
		Target       string `json:"target"`
		Sealed       bool   `json:"sealed"`
	} `json:"bindings"`
	Audit []struct {
		UserID    int64   `json:"user_id"`
		RunID     *string `json:"run_id"`
		Operation string  `json:"operation"`
		Target    *string `json:"target"`
		Outcome   string  `json:"outcome"`
		ErrorCode *string `json:"error_code"`
	} `json:"audit"`
	Calls struct {
		HTTP    [][]any `json:"http"`
		Browser [][]any `json:"browser"`
	} `json:"calls"`
}

// memoryAgents gives every account its main agent, as the Node resolver did.
type memoryAgents struct{ db *dbx.DB }

func (m memoryAgents) Resolve(ctx context.Context, userID int64, _ string) (string, error) {
	var id string
	err := m.db.W.QueryRowContext(ctx, `SELECT id FROM agents WHERE user_id = ? AND slug = 'main'`, userID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		id = newUUID()
		_, err = m.db.W.ExecContext(ctx, `INSERT INTO agents (id, user_id, slug, display_name, is_default) VALUES (?, ?, 'main', 'Main', 1)`, id, userID)
	}
	return id, err
}

type fakeVault struct{ items map[string]Item }

func (fakeVault) Sync(context.Context, int64, string) error { return nil }
func (f fakeVault) ListItems(context.Context, int64, string) ([]Item, error) {
	// The Node fake lists in insertion order of its object literal.
	var out []Item
	for _, k := range []string{"login1", "nopass", "api", "short"} {
		out = append(out, f.items[k])
	}
	return out, nil
}
func (f fakeVault) GetItem(_ context.Context, _ int64, _ string, ref string) (Item, error) {
	if it, ok := f.items[ref]; ok {
		return it, nil
	}
	return nil, errors.New("Item not found.")
}

type fakeRequester struct{ calls [][]any }

func (f *fakeRequester) Do(_ context.Context, r Request) (Response, error) {
	var body any
	if r.Body != nil {
		body = *r.Body
	}
	var timeout any
	if r.Timeout != 0 {
		timeout = float64(r.Timeout / time.Millisecond)
	}
	record := []any{r.Method, r.URL, r.Headers["Authorization"], r.Headers["X-Api-Key"], body, timeout, float64(r.MaxResponseBytes)}
	f.calls = append(f.calls, record)
	secretish := r.Headers["Authorization"]
	if secretish == "" {
		secretish = r.Headers["X-Api-Key"]
	}
	var raw bytes.Buffer
	enc := json.NewEncoder(&raw)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(record)
	return Response{
		Status: 200,
		Headers: map[string]string{
			"content-type": "application/json", "set-cookie": "a=b", "x-reflect": "got " + secretish, "authorization": "x",
		},
		Body: strings.TrimSuffix(raw.String(), "\n"),
	}, nil
}

type fakeBrowser struct {
	page  *string
	calls [][]any
}

func (f *fakeBrowser) BrowserForUser(context.Context, int64) (Browser, error) { return f, nil }
func (f *fakeBrowser) PageURL(context.Context) (string, error)                { return *f.page, nil }
func (f *fakeBrowser) FillCredential(_ context.Context, r FillRequest) (string, error) {
	f.calls = append(f.calls, []any{"fill", map[string]any{
		"usernameSelector": r.UsernameSelector, "passwordSelector": r.PasswordSelector,
		"username": r.Username, "password": r.Password, "allowedOrigin": r.AllowedOrigin,
	}})
	if r.Password == "pw-secret" && r.Username != "" {
		return "pf1", nil
	}
	return "", nil
}
func (f *fakeBrowser) SubmitProtected(_ context.Context, id string) (map[string]any, error) {
	f.calls = append(f.calls, []any{"submit", id})
	return map[string]any{"url": "https://github.com/after", "title": "T"}, nil
}
func (f *fakeBrowser) CancelProtected(_ context.Context, id string) (map[string]any, error) {
	f.calls = append(f.calls, []any{"cancel", id})
	return map[string]any{"cancelled": true}, nil
}

type fixture struct {
	db     *dbx.DB
	box    *secretbox.Box
	broker *Broker
	vault  fakeVault
	req    *fakeRequester
	br     *fakeBrowser
	page   string
}

func newFixture(t *testing.T, items map[string]Item) *fixture {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "n.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New("enc:v1:", "x")
	if err != nil {
		t.Fatal(err)
	}
	f := &fixture{db: db, box: box, vault: fakeVault{items: items}, req: &fakeRequester{}, page: "https://github.com/login"}
	f.br = &fakeBrowser{page: &f.page}
	f.broker = New(Config{DB: db, Box: box, Agents: memoryAgents{db}, Vault: f.vault, Requester: f.req, Browsers: f.br})
	exec := func(q string, args ...any) {
		if _, err := db.W.ExecContext(ctx, q, args...); err != nil {
			t.Fatal(err)
		}
	}
	exec(`INSERT INTO users (id, username, password) VALUES (1, 'u1', 'x'), (2, 'u2', 'x')`)
	a1, _ := memoryAgents{db}.Resolve(ctx, 1, "")
	a2, _ := memoryAgents{db}.Resolve(ctx, 2, "")
	ins := `INSERT INTO integration_connections (user_id, agent_id, provider_key, app_key, status, account_email) VALUES (?, ?, 'bitwarden', 'default', ?, ?)`
	exec(ins, 1, a1, "connected", "a@x")
	exec(ins, 1, a1, "not_connected", "b@x")
	exec(ins, 2, a2, "connected", "c@x")
	return f
}

var uuidPattern = regexp.MustCompile(`[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`)

// normalized round-trips v through JSON, dropping timestamps and ids.
func normalized(t *testing.T, v any) any {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	var generic any
	if err := json.Unmarshal([]byte(uuidPattern.ReplaceAllString(string(raw), "<uuid>")), &generic); err != nil {
		t.Fatal(err)
	}
	return drop(generic)
}

func drop(v any) any {
	switch t := v.(type) {
	case map[string]any:
		delete(t, "createdAt")
		delete(t, "updatedAt")
		for k, e := range t {
			t[k] = drop(e)
		}
	case []any:
		for i, e := range t {
			t[i] = drop(e)
		}
	}
	return v
}

func (f *fixture) bindingID(user int64, alias string) string {
	if strings.HasPrefix(alias, "@") {
		switch alias {
		case "@missing":
			return "no-such-binding"
		case "@id1":
			if id := f.lookup(1, "gh-renamed"); id != "" {
				return id
			}
			return "gone"
		}
		return ""
	}
	if id := f.lookup(user, alias); id != "" {
		return id
	}
	return f.lookup(1, alias)
}

func (f *fixture) lookup(user int64, alias string) string {
	var id string
	_ = f.db.W.QueryRow(`SELECT id FROM credential_bindings WHERE user_id = ? AND alias = ?`, user, alias).Scan(&id)
	return id
}

func asMap(v any) map[string]any {
	m, _ := v.(map[string]any)
	return m
}

func (f *fixture) run(t *testing.T, s step) (any, error) {
	ctx := context.Background()
	b := f.broker
	switch s.Op {
	case "list":
		return b.ListBindings(ctx, s.User, "")
	case "create":
		return b.CreateBinding(ctx, s.User, "", asMap(s.Input))
	case "update":
		return b.UpdateBinding(ctx, s.User, "", f.bindingID(s.User, s.Binding), asMap(s.Input))
	case "delete":
		ok, err := b.DeleteBinding(ctx, s.User, "", f.bindingID(s.User, s.Binding))
		return map[string]any{"deleted": ok}, err
	case "vaultItems":
		return b.ListVaultItems(ctx, s.User, "")
	case "summary":
		return b.SummarizeBindings(ctx, s.User, "")
	case "http":
		in := asMap(s.Input)
		if s.Binding != "" {
			in["binding_id"] = f.bindingID(s.User, s.Binding)
		}
		return b.HTTPRequest(ctx, s.User, "", in, RunContext{})
	case "fill":
		in := asMap(s.Input)
		in["binding_id"] = f.bindingID(s.User, s.Binding)
		return b.FillBrowser(ctx, s.User, "", in, RunContext{})
	case "page":
		f.page = s.Input.(string)
		return nil, nil
	case "submit":
		return b.SubmitProtected(ctx, s.User, "", s.Input.(string), RunContext{})
	case "cancel":
		return b.CancelProtected(ctx, s.User, "", s.Input.(string), RunContext{})
	}
	t.Fatalf("unknown op %s", s.Op)
	return nil, nil
}

func TestScenarioMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/scenario.json")
	if err != nil {
		t.Fatal(err)
	}
	var sc scenario
	if err := json.Unmarshal(raw, &sc); err != nil {
		t.Fatal(err)
	}
	f := newFixture(t, sc.Items)
	for i, s := range sc.Steps {
		result, err := f.run(t, s)
		label := s.Op + " #" + strconv.Itoa(i)
		switch {
		case s.Error != "":
			if err == nil {
				t.Fatalf("%s: want error %q, got result %v", label, s.Error, result)
			}
			if s.Contains != "" {
				if !strings.Contains(err.Error(), s.Contains) {
					t.Fatalf("%s: error %q lacks %q", label, err, s.Contains)
				}
			} else if err.Error() != s.Error {
				t.Fatalf("%s: error %q, want %q", label, err, s.Error)
			}
		case err != nil:
			t.Fatalf("%s: unexpected error %v", label, err)
		default:
			if got, want := normalized(t, result), normalized(t, s.Result); !reflect.DeepEqual(got, want) {
				g, _ := json.Marshal(got)
				w, _ := json.Marshal(want)
				t.Fatalf("%s: result\n got %s\nwant %s", label, g, w)
			}
		}
	}

	rows, err := f.db.W.Query(`SELECT user_id, alias, usage_type, connection_id, provider_key, item_ref_encrypted, field_config_encrypted, target_config_json
		FROM credential_bindings ORDER BY user_id, alias`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	n := 0
	for rows.Next() {
		var user, conn int64
		var alias, usage, provider, itemRef, fields, target string
		if err := rows.Scan(&user, &alias, &usage, &conn, &provider, &itemRef, &fields, &target); err != nil {
			t.Fatal(err)
		}
		if n >= len(sc.Bindings) {
			t.Fatalf("extra binding %q", alias)
		}
		want := sc.Bindings[n]
		n++
		plainRef, err1 := f.box.OpenSealed(itemRef)
		plainFields, err2 := f.box.OpenSealed(fields)
		if err1 != nil || err2 != nil {
			t.Fatalf("binding %q is not sealed: %v %v", alias, err1, err2)
		}
		if user != want.UserID || alias != want.Alias || usage != want.UsageType || conn != want.ConnectionID ||
			provider != want.ProviderKey || plainRef != want.ItemRef || plainFields != want.FieldConfig || target != want.Target {
			t.Errorf("binding %q = %v %v %v %v %q %q %q, want %+v", alias, user, usage, conn, provider, plainRef, plainFields, target, want)
		}
	}
	if n != len(sc.Bindings) {
		t.Errorf("%d bindings, want %d", n, len(sc.Bindings))
	}

	audit, err := f.db.W.Query(`SELECT user_id, run_id, operation, target, outcome, error_code FROM credential_usage_audit ORDER BY rowid`)
	if err != nil {
		t.Fatal(err)
	}
	defer audit.Close()
	n = 0
	for audit.Next() {
		var user int64
		var run, target, code sql.NullString
		var op, outcome string
		if err := audit.Scan(&user, &run, &op, &target, &outcome, &code); err != nil {
			t.Fatal(err)
		}
		if n >= len(sc.Audit) {
			t.Fatalf("extra audit row %s", op)
		}
		want := sc.Audit[n]
		n++
		if user != want.UserID || op != want.Operation || outcome != want.Outcome || run.Valid != (want.RunID != nil) ||
			code.Valid != (want.ErrorCode != nil) || target.Valid != (want.Target != nil) || (want.Target != nil && target.String != *want.Target) {
			t.Errorf("audit row %d = %v %s %v %s, want %+v", n, user, op, target, outcome, want)
		}
	}
	if n != len(sc.Audit) {
		t.Errorf("%d audit rows, want %d", n, len(sc.Audit))
	}

	if !reflect.DeepEqual(normalized(t, f.req.calls), normalized(t, sc.Calls.HTTP)) {
		t.Errorf("http calls = %v, want %v", f.req.calls, sc.Calls.HTTP)
	}
	if !reflect.DeepEqual(normalized(t, f.br.calls), normalized(t, sc.Calls.Browser)) {
		t.Errorf("browser calls = %v, want %v", f.br.calls, sc.Calls.Browser)
	}
}

func TestProtectedFillExpires(t *testing.T) {
	raw, _ := os.ReadFile("testdata/scenario.json")
	var sc scenario
	_ = json.Unmarshal(raw, &sc)
	f := newFixture(t, sc.Items)
	now := time.Now()
	f.broker.now = func() time.Time { return now }
	ctx := context.Background()
	if _, err := f.broker.CreateBinding(ctx, 1, "", map[string]any{"alias": "gh", "usageType": "browser", "connectionId": 1.0, "itemId": "login1"}); err != nil {
		t.Fatal(err)
	}
	id := f.lookup(1, "gh")
	res, err := f.broker.FillBrowser(ctx, 1, "", map[string]any{"binding_id": id, "username_selector": "#u", "password_selector": "#p"}, RunContext{})
	if err != nil {
		t.Fatal(err)
	}
	now = now.Add(protectedFillTTL + time.Second)
	_, err = f.broker.SubmitProtected(ctx, 1, "", res.ProtectedFillID, RunContext{})
	if err == nil || err.Error() != "Protected browser fill expired and was cleared." {
		t.Fatalf("err = %v", err)
	}
	if got := f.br.calls[len(f.br.calls)-1]; got[0] != "cancel" {
		t.Fatalf("expired fill was not cancelled: %v", got)
	}
	if _, err := f.broker.SubmitProtected(ctx, 1, "", res.ProtectedFillID, RunContext{}); err == nil || err.Error() != "Protected browser fill is missing or expired." {
		t.Fatalf("second submit err = %v", err)
	}
}

func TestBrowserRuntimeUnavailable(t *testing.T) {
	raw, _ := os.ReadFile("testdata/scenario.json")
	var sc scenario
	_ = json.Unmarshal(raw, &sc)
	f := newFixture(t, sc.Items)
	f.broker.SetBrowsers(nil)
	ctx := context.Background()
	if _, err := f.broker.CreateBinding(ctx, 1, "", map[string]any{"alias": "gh", "usageType": "browser", "connectionId": 1.0, "itemId": "login1"}); err != nil {
		t.Fatal(err)
	}
	_, err := f.broker.FillBrowser(ctx, 1, "", map[string]any{"binding_id": f.lookup(1, "gh")}, RunContext{})
	if err == nil || err.Error() != "Browser runtime is unavailable." {
		t.Fatalf("err = %v", err)
	}
}
