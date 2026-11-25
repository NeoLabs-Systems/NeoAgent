package admin

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

func TestMain(m *testing.M) {
	accounts.PasswordCost = 4 // keep bcrypt fast in tests
	os.Exit(m.Run())
}

// ---- Node vectors -----------------------------------------------------------

type vErr struct {
	Status  int     `json:"status"`
	Message string  `json:"message"`
	Code    *string `json:"code"`
}

type vOut struct {
	Value json.RawMessage `json:"value"`
	Error *vErr           `json:"error"`
}

type vAudit struct {
	Action  string `json:"action"`
	Actor   *int64 `json:"actor"`
	Subject *int64 `json:"subject"`
	Detail  string `json:"detail"`
}

type settingsCase struct {
	Input json.RawMessage    `json:"input"`
	Value json.RawMessage    `json:"value"`
	Error *vErr              `json:"error"`
	Env   map[string]*string `json:"env"`
	File  string             `json:"file"`
}

type vectors struct {
	Seed   []string `json:"seed"`
	UserID []struct {
		Input string   `json:"input"`
		ID    *float64 `json:"id"`
		Error *vErr    `json:"error"`
	} `json:"userId"`
	List []struct {
		Q   string          `json:"q"`
		Out json.RawMessage `json:"out"`
	} `json:"list"`
	Keys       json.RawMessage `json:"keys"`
	UserLimits []struct {
		Body json.RawMessage `json:"body"`
		vOut
	} `json:"userLimits"`
	Grants []struct {
		ModelIDs json.RawMessage `json:"modelIds"`
		vOut
		Stored *string  `json:"stored"`
		Audit  []vAudit `json:"audit"`
		Read   vOut     `json:"read"`
	} `json:"grants"`
	GrantsRead []struct {
		ID int64 `json:"id"`
		vOut
	} `json:"grantsRead"`
	CreateKeys []struct {
		Count   json.RawMessage `json:"count"`
		Label   json.RawMessage `json:"label"`
		Error   *vErr           `json:"error"`
		Created int             `json:"created"`
		Sample  *struct {
			Label       string  `json:"label"`
			Status      string  `json:"status"`
			CreatedBy   *string `json:"createdBy"`
			UsedAt      *string `json:"usedAt"`
			UsedBy      any     `json:"usedBy"`
			RevokedAt   *string `json:"revokedAt"`
			CodePattern bool    `json:"codePattern"`
		} `json:"sample"`
		Audit []vAudit `json:"audit"`
	} `json:"createKeys"`
	RevokeKeys []struct {
		ID int64 `json:"id"`
		vOut
		Audit []vAudit `json:"audit"`
	} `json:"revokeKeys"`
	SQL []struct {
		Query string `json:"query"`
		vOut
	} `json:"sql"`
	SQLRaw []struct {
		Body json.RawMessage `json:"body"`
		vOut
	} `json:"sqlRaw"`
	AdminFlow []struct {
		Op    string          `json:"op"`
		Arg   json.RawMessage `json:"arg"`
		Value json.RawMessage `json:"value"`
		Error *vErr           `json:"error"`
		Audit []vAudit        `json:"audit"`
	} `json:"adminFlow"`
	General           []settingsCase `json:"general"`
	DefaultLimits     []settingsCase `json:"defaultLimits"`
	DefaultLimitParse []struct {
		Raw string `json:"raw"`
		Now struct {
			FourHour float64 `json:"rate_limit_4h"`
			Weekly   float64 `json:"rate_limit_weekly"`
		} `json:"now"`
	} `json:"defaultLimitParse"`
	Signup      []settingsCase `json:"signup"`
	SignupParse []struct {
		Raw string `json:"raw"`
		Now struct {
			Required bool `json:"signupKeyRequired"`
		} `json:"now"`
	} `json:"signupParse"`
	Models        []settingsCase             `json:"models"`
	Email         []settingsCase             `json:"email"`
	EmailDefaults map[string]json.RawMessage `json:"emailDefaults"`
}

func loadVectors(t *testing.T) *vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/node_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return &v
}

func sameJSON(t *testing.T, label string, got []byte, want json.RawMessage) {
	t.Helper()
	var g, w any
	if err := json.Unmarshal(got, &g); err != nil {
		t.Fatalf("%s: response is not JSON: %s", label, got)
	}
	if err := json.Unmarshal(want, &w); err != nil {
		t.Fatalf("%s: bad vector: %v", label, err)
	}
	if !reflect.DeepEqual(g, w) {
		t.Errorf("%s:\n got  %s\n want %s", label, got, want)
	}
}

// ---- stack ------------------------------------------------------------------

type stack struct {
	t       *testing.T
	db      *dbx.DB
	api     *API
	srv     *httptest.Server
	records *accounts.SessionRecords
	envFile string
	catalog []string
}

func newStack(t *testing.T, seed ...string) *stack {
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
	for _, statement := range seed {
		if _, err := db.W.Exec(statement); err != nil {
			t.Fatalf("seed %q: %v", statement, err)
		}
	}
	sdb, err := dbx.Open(ctx, filepath.Join(dir, "sessions.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { sdb.Close() })
	store, err := sessionx.NewStore(ctx, sdb.W)
	if err != nil {
		t.Fatal(err)
	}
	const secret = "admin-test-secret"
	sessions, err := sessionx.NewManager(store, sessionx.Options{
		Name: "neoagent.sid", Secrets: []string{secret}, MaxAge: 24 * time.Hour, Rolling: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	records := &accounts.SessionRecords{DB: db, Store: store, Secret: secret}
	s := &stack{t: t, db: db, records: records, envFile: filepath.Join(dir, ".env"), catalog: []string{"m1", "m2", "m3", "m4", "x y"}}
	s.api = New(Deps{
		DB: db, Records: records, EnvFile: s.envFile,
		Log:          slog.New(slog.NewTextHandler(testLog{t}, nil)),
		ModelCatalog: func(context.Context) ([]string, error) { return s.catalog, nil },
	})
	mux := http.NewServeMux()
	s.api.Routes(mux)
	mux.HandleFunc("POST /test/login/{id}", func(w http.ResponseWriter, r *http.Request) {
		id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
		sess := sessionx.FromContext(r.Context())
		sess.Regenerate()
		sess.Set("userId", id)
		if _, err := records.Record(r.Context(), sess.ID(), r, id, time.Now().Add(time.Hour), true); err != nil {
			t.Error(err)
		}
		w.WriteHeader(http.StatusNoContent)
	})
	s.srv = httptest.NewServer(sessions.Middleware(mux))
	t.Cleanup(s.srv.Close)
	return s
}

type testLog struct{ t *testing.T }

func (l testLog) Write(p []byte) (int, error) {
	l.t.Log(strings.TrimSpace(string(p)))
	return len(p), nil
}

type client struct {
	t    *testing.T
	base string
	http *http.Client
}

func (s *stack) client() *client {
	jar, _ := cookiejar.New(nil)
	return &client{t: s.t, base: s.srv.URL, http: &http.Client{Jar: jar}}
}

// login signs the client in as the account (the session cookie lands in the jar).
func (s *stack) login(id int64) *client {
	c := s.client()
	if status, _ := c.do("POST", "/test/login/"+strconv.FormatInt(id, 10), nil); status != http.StatusNoContent {
		s.t.Fatalf("login as %d: status %d", id, status)
	}
	return c
}

// do sends payload as JSON (a json.RawMessage is sent as it is, nil sends no body).
func (c *client) do(method, path string, payload any) (int, []byte) {
	c.t.Helper()
	var rdr io.Reader
	if payload != nil {
		raw, ok := payload.(json.RawMessage)
		if !ok {
			var err error
			if raw, err = json.Marshal(payload); err != nil {
				c.t.Fatal(err)
			}
		}
		rdr = bytes.NewReader(raw)
	}
	req, _ := http.NewRequest(method, c.base+path, rdr)
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.http.Do(req)
	if err != nil {
		c.t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, raw
}

// expectError checks an error response against what Node answered.
func expectError(t *testing.T, label string, status int, body []byte, want *vErr) {
	t.Helper()
	var got struct {
		Error string  `json:"error"`
		Code  *string `json:"code"`
	}
	if err := json.Unmarshal(body, &got); err != nil {
		t.Fatalf("%s: not JSON: %s", label, body)
	}
	if status != want.Status || got.Error != want.Message || (got.Code == nil) != (want.Code == nil) || (got.Code != nil && *got.Code != *want.Code) {
		t.Errorf("%s: got %d %s, want %d %q code=%v", label, status, body, want.Status, want.Message, want.Code)
	}
}

func (s *stack) auditRows() []vAudit {
	rows, err := s.db.W.Query(`SELECT action, actor_user_id, subject_user_id, detail_json FROM access_audit_log ORDER BY id`)
	if err != nil {
		s.t.Fatal(err)
	}
	defer rows.Close()
	var out []vAudit
	for rows.Next() {
		var a vAudit
		if err := rows.Scan(&a.Action, &a.Actor, &a.Subject, &a.Detail); err != nil {
			s.t.Fatal(err)
		}
		out = append(out, a)
	}
	return out
}

// sameAudit compares audit rows: the stored text exactly, except where Node
// escaped half of a split emoji, which Go can only store as U+FFFD (the JSON
// then means the same).
func sameAudit(t *testing.T, label string, got, want []vAudit) {
	t.Helper()
	if len(got) != len(want) {
		t.Errorf("%s: %d audit rows, want %d (%v)", label, len(got), len(want), got)
		return
	}
	for i := range got {
		g, w := got[i], want[i]
		if g.Action != w.Action || !reflect.DeepEqual(g.Actor, w.Actor) || !reflect.DeepEqual(g.Subject, w.Subject) {
			t.Errorf("%s: audit %d = %+v, want %+v", label, i, g, w)
			continue
		}
		if g.Detail != w.Detail && !strings.Contains(w.Detail, `\ud`) {
			t.Errorf("%s: audit %d detail %s, want %s", label, i, g.Detail, w.Detail)
		}
		sameJSON(t, label+" audit detail", []byte(g.Detail), json.RawMessage(w.Detail))
	}
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }

func urlEscape(s string) string { return url.QueryEscape(s) }
