package admin

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/passhash"
)

const (
	adminID int64 = 1
	userID2 int64 = 2
)

var accountSeed = []string{
	`INSERT INTO users (username, password) VALUES ('alice', 'x')`, // first account: admin by trigger
	`INSERT INTO users (username, password) VALUES ('bob', 'x')`,
}

// every route this package serves, with a body that is valid for it
var allRoutes = []struct{ method, path, body string }{
	{"GET", "/api/admin/users", ""},
	{"DELETE", "/api/admin/users/2/sessions", ""},
	{"POST", "/api/admin/users/2/password", `{"password":"Correct-Horse-Battery-9"}`},
	{"GET", "/api/admin/users/2/rate-limits", ""},
	{"PUT", "/api/admin/users/2/rate-limits", `{}`},
	{"GET", "/api/admin/users/2/allowed-models", ""},
	{"PUT", "/api/admin/users/2/allowed-models", `{"modelIds":[]}`},
	{"GET", "/api/admin/config/rate-limits", ""},
	{"PUT", "/api/admin/config/rate-limits", `{}`},
	{"POST", "/api/admin/sql", `{"query":"SELECT 1"}`},
	{"GET", "/api/admin/access", ""},
	{"PUT", "/api/admin/access/signup", `{"keyRequired":false}`},
	{"GET", "/api/admin/signup-keys", ""},
	{"POST", "/api/admin/signup-keys", `{"count":1}`},
	{"DELETE", "/api/admin/signup-keys/999", ""},
	{"PUT", "/api/admin/models/config", `{"disabledModels":[]}`},
	{"GET", "/api/admin/config/general", ""},
	{"PUT", "/api/admin/config/general", `{"secureCookies":false}`},
	{"GET", "/api/admin/config/email", ""},
}

func raw(body string) any {
	if body == "" {
		return nil
	}
	return json.RawMessage(body)
}

func clearEnv(t *testing.T, keys ...string) {
	t.Helper()
	for _, key := range keys {
		t.Setenv(key, "")
		os.Unsetenv(key)
	}
}

// clearSettingsEnv starts a test from an unconfigured process environment and
// restores it afterwards: the settings routes write to it.
func clearSettingsEnv(t *testing.T) {
	t.Helper()
	keys := []string{
		envAllowSignup, envRateLimit4h, envRateLimitWeekly, envDisabledModels, envAutoEnableNew,
		"PUBLIC_URL", "SECURE_COOKIES", "ALLOWED_ORIGINS", envEmailPort, envEmailTokenHours, envEmailPassword,
	}
	for _, f := range emailStringFields {
		keys = append(keys, f.key)
	}
	for _, f := range emailBoolFields {
		keys = append(keys, f.key)
	}
	clearEnv(t, keys...)
}

func TestEveryRouteNeedsAnAdmin(t *testing.T) {
	s := newStack(t, accountSeed...)
	clearSettingsEnv(t)
	anonymous, member, admin := s.client(), s.login(userID2), s.login(adminID)

	for _, r := range allRoutes {
		label := r.method + " " + r.path
		status, body := anonymous.do(r.method, r.path, raw(r.body))
		if status != http.StatusUnauthorized || string(body) != `{"error":"Unauthorized"}` {
			t.Errorf("%s without a session: %d %s", label, status, body)
		}
		status, body = member.do(r.method, r.path, raw(r.body))
		if status != http.StatusForbidden || string(body) != `{"error":"Admin access required","code":"ADMIN_REQUIRED"}` {
			t.Errorf("%s as a plain account: %d %s", label, status, body)
		}
	}
	for _, r := range allRoutes {
		if status, body := admin.do(r.method, r.path, raw(r.body)); status >= 400 && !(r.method == "DELETE" && strings.HasSuffix(r.path, "/999")) {
			t.Errorf("%s as admin: %d %s", r.method+" "+r.path, status, body)
		}
	}
	// only the admin pass wrote anything: the refused calls left no trace
	if rows := s.auditRows(); len(rows) != 2 || rows[0].Action != "account.password_reset" || rows[1].Action != "signup_keys.create" {
		t.Errorf("audit after the admin pass: %+v", rows)
	}
}

func TestAdminFlagIsReadOnEveryRequest(t *testing.T) {
	s := newStack(t, accountSeed...)
	admin := s.login(adminID)
	if status, _ := admin.do("GET", "/api/admin/users", nil); status != http.StatusOK {
		t.Fatalf("first account is not admin: %d", status)
	}
	if _, err := s.api.Store.RevokeAdmin(context.Background(), "alice", "cli"); err != nil {
		t.Fatal(err)
	}
	status, body := admin.do("GET", "/api/admin/users", nil)
	if status != http.StatusForbidden || !strings.Contains(string(body), "ADMIN_REQUIRED") {
		t.Errorf("after revoke, the same session got %d %s", status, body)
	}
	if _, err := s.api.Store.GrantAdmin(context.Background(), "alice", "cli"); err != nil {
		t.Fatal(err)
	}
	if status, _ := admin.do("GET", "/api/admin/users", nil); status != http.StatusOK {
		t.Errorf("after grant, the same session got %d", status)
	}
	if _, err := s.db.W.Exec(`DELETE FROM users WHERE id = 1`); err != nil {
		t.Fatal(err)
	}
	if status, _ := admin.do("GET", "/api/admin/users", nil); status != http.StatusForbidden {
		t.Errorf("a deleted account kept admin access: %d", status)
	}
}

func TestFirstAccountTrigger(t *testing.T) {
	flags := func(s *stack) []int {
		rows, err := s.db.W.Query(`SELECT is_admin FROM users ORDER BY id`)
		if err != nil {
			t.Fatal(err)
		}
		defer rows.Close()
		var out []int
		for rows.Next() {
			var f int
			rows.Scan(&f)
			out = append(out, f)
		}
		return out
	}
	exec := func(s *stack, statement string) {
		t.Helper()
		if _, err := s.db.W.Exec(statement); err != nil {
			t.Fatal(err)
		}
	}
	cases := []struct {
		name  string
		steps []string
		want  []int
	}{
		{"first account without email", []string{
			`INSERT INTO users (username, password) VALUES ('a', 'x')`,
			`INSERT INTO users (username, password) VALUES ('b', 'x')`,
		}, []int{1, 0}},
		{"first account with a confirmed email", []string{
			`INSERT INTO users (username, password, email, email_verified_at) VALUES ('a', 'x', 'a@x.io', datetime('now'))`,
			`INSERT INTO users (username, password) VALUES ('b', 'x')`,
		}, []int{1, 0}},
		{"unconfirmed first account is not admin, the first confirmed one is", []string{
			`INSERT INTO users (username, password, email) VALUES ('a', 'x', 'a@x.io')`,
			`INSERT INTO users (username, password, email, email_verified_at) VALUES ('b', 'x', 'b@x.io', datetime('now'))`,
			`UPDATE users SET email_verified_at = datetime('now') WHERE username = 'a'`,
		}, []int{0, 1}},
		{"confirming the only account promotes it", []string{
			`INSERT INTO users (username, password, email) VALUES ('a', 'x', 'a@x.io')`,
			`UPDATE users SET email_verified_at = datetime('now')`,
		}, []int{1}},
		{"a later account never becomes admin by itself", []string{
			`INSERT INTO users (username, password) VALUES ('a', 'x')`,
			`DELETE FROM users`,
			`INSERT INTO users (username, password) VALUES ('b', 'x')`,
			`INSERT INTO users (username, password) VALUES ('c', 'x')`,
		}, []int{1, 0}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			s := newStack(t)
			for _, step := range c.steps {
				exec(s, step)
			}
			got := flags(s)
			if len(got) != len(c.want) {
				t.Fatalf("flags %v, want %v", got, c.want)
			}
			for i := range got {
				if got[i] != c.want[i] {
					t.Errorf("flags %v, want %v", got, c.want)
				}
			}
			if rows := s.auditRows(); len(rows) != 0 {
				t.Errorf("the trigger must not write audit rows: %+v", rows)
			}
		})
	}
}

func TestResetPassword(t *testing.T) {
	s := newStack(t, accountSeed...)
	admin, member := s.login(adminID), s.login(userID2)
	for _, statement := range []string{
		`INSERT INTO user_email_tokens (user_id, type, email, token_hash, expires_at) VALUES (2, 'password_reset', 'b@x.io', 'h1', datetime('now', '+1 day'))`,
		`INSERT INTO user_email_tokens (user_id, type, email, token_hash, expires_at) VALUES (2, 'email_change', 'b@x.io', 'h2', datetime('now', '+1 day'))`,
		`INSERT INTO user_email_tokens (user_id, type, email, token_hash, expires_at) VALUES (1, 'password_reset', 'a@x.io', 'h3', datetime('now', '+1 day'))`,
	} {
		if _, err := s.db.W.Exec(statement); err != nil {
			t.Fatal(err)
		}
	}

	failures := []struct {
		name, path, body string
		status           int
		code             string
	}{
		{"id is not a number", "/api/admin/users/abc/password", `{"password":"Correct-Horse-Battery-9"}`, 400, "INVALID_USER_ID"},
		{"unknown account", "/api/admin/users/99/password", `{"password":"Correct-Horse-Battery-9"}`, 404, "USER_NOT_FOUND"},
		{"no password", "/api/admin/users/2/password", `{}`, 400, "PASSWORD_TOO_SHORT"},
		{"falsy password", "/api/admin/users/2/password", `{"password":0}`, 400, "PASSWORD_TOO_SHORT"},
		{"too short", "/api/admin/users/2/password", `{"password":"abc"}`, 400, "PASSWORD_TOO_SHORT"},
		{"numeric password", "/api/admin/users/2/password", `{"password":123456789}`, 400, "PASSWORD_WEAK"},
		{"common password", "/api/admin/users/2/password", `{"password":"password"}`, 400, "PASSWORD_WEAK"},
		{"contains the username", "/api/admin/users/2/password", `{"password":"bobbobbob-bob"}`, 400, "PASSWORD_WEAK"},
	}
	for _, c := range failures {
		status, body := admin.do("POST", c.path, json.RawMessage(c.body))
		var out struct{ Error, Code string }
		json.Unmarshal(body, &out)
		if status != c.status || out.Code != c.code || out.Error == "" {
			t.Errorf("%s: %d %s", c.name, status, body)
		}
	}
	if rows := s.auditRows(); len(rows) != 0 {
		t.Fatalf("refused resets were audited: %+v", rows)
	}
	var consumed int
	s.db.W.QueryRow(`SELECT COUNT(*) FROM user_email_tokens WHERE consumed_at IS NOT NULL`).Scan(&consumed)
	if consumed != 0 {
		t.Fatalf("refused reset consumed %d tokens", consumed)
	}

	status, body := admin.do("POST", "/api/admin/users/2/password", json.RawMessage(`{"password":"Correct-Horse-Battery-9"}`))
	if status != 200 || string(body) != `{"success":true}` {
		t.Fatalf("reset: %d %s", status, body)
	}
	var hash string
	var enabled int
	s.db.W.QueryRow(`SELECT password, password_login_enabled FROM users WHERE id = 2`).Scan(&hash, &enabled)
	if !passhash.Verify(hash, "Correct-Horse-Battery-9") || enabled != 1 {
		t.Errorf("password not stored (enabled=%d)", enabled)
	}
	rows, _ := s.db.W.Query(`SELECT token_hash FROM user_email_tokens WHERE consumed_at IS NOT NULL`)
	var voided []string
	for rows.Next() {
		var h string
		rows.Scan(&h)
		voided = append(voided, h)
	}
	rows.Close()
	if len(voided) != 1 || voided[0] != "h1" {
		t.Errorf("voided tokens %v, want only the account's reset link", voided)
	}
	audit := s.auditRows()
	one, two := adminID, userID2
	if len(audit) != 1 || audit[0].Action != "account.password_reset" || *audit[0].Actor != one || *audit[0].Subject != two || audit[0].Detail != "{}" {
		t.Errorf("audit: %+v", audit)
	}
	if status, _ := member.do("GET", "/api/admin/users", nil); status != http.StatusUnauthorized {
		t.Errorf("the account's session survived the reset: %d", status)
	}
	if status, _ := admin.do("GET", "/api/admin/users", nil); status != http.StatusOK {
		t.Errorf("the admin's own session ended: %d", status)
	}
}

func TestRevokeSessions(t *testing.T) {
	s := newStack(t, accountSeed...)
	admin, first, second := s.login(adminID), s.login(userID2), s.login(userID2)
	status, body := admin.do("DELETE", "/api/admin/users/2/sessions", nil)
	if status != 200 || string(body) != `{"ok":true}` {
		t.Fatalf("revoke: %d %s", status, body)
	}
	for i, c := range []*client{first, second} {
		if status, _ := c.do("GET", "/api/admin/users", nil); status != http.StatusUnauthorized {
			t.Errorf("session %d survived: %d", i, status)
		}
	}
	var active int
	s.db.W.QueryRow(`SELECT COUNT(*) FROM user_sessions WHERE user_id = 2 AND revoked_at IS NULL`).Scan(&active)
	if active != 0 {
		t.Errorf("%d session records still active", active)
	}
	if status, _ := admin.do("GET", "/api/admin/users", nil); status != http.StatusOK {
		t.Errorf("the admin's own session ended: %d", status)
	}
	if status, body := admin.do("DELETE", "/api/admin/users/0/sessions", nil); status != 400 || !strings.Contains(string(body), "INVALID_USER_ID") {
		t.Errorf("bad id: %d %s", status, body)
	}
}

func TestSettingsRoutes(t *testing.T) {
	s := newStack(t, accountSeed...)
	clearSettingsEnv(t)
	admin := s.login(adminID)
	expect := func(label, method, path, payload string, wantStatus int, wantBody string) {
		t.Helper()
		status, body := admin.do(method, path, raw(payload))
		if status != wantStatus || string(body) != wantBody {
			t.Errorf("%s: %d %s\n want %d %s", label, status, body, wantStatus, wantBody)
		}
	}

	expect("signup default", "GET", "/api/admin/access", "", 200, `{"signupKeyRequired":false}`)
	expect("signup on", "PUT", "/api/admin/access/signup", `{"keyRequired":true}`, 200, `{"ok":true,"signupKeyRequired":true}`)
	expect("signup read back", "GET", "/api/admin/access", "", 200, `{"signupKeyRequired":true}`)
	expect("signup type", "PUT", "/api/admin/access/signup", `{"keyRequired":"yes"}`, 400, `{"error":"keyRequired must be a boolean."}`)

	expect("limits default", "GET", "/api/admin/config/rate-limits", "", 200, `{"rate_limit_4h":2500000,"rate_limit_weekly":10000000}`)
	expect("limits set", "PUT", "/api/admin/config/rate-limits", `{"rate_limit_4h":10,"rate_limit_weekly":"20"}`, 200, `{"ok":true}`)
	expect("limits read back", "GET", "/api/admin/config/rate-limits", "", 200, `{"rate_limit_4h":10,"rate_limit_weekly":20}`)
	expect("limits invalid", "PUT", "/api/admin/config/rate-limits", `{"rate_limit_4h":-3}`, 400, `{"error":"rate_limit_4h must be a whole number ≥ 0, or null."}`)

	expect("general default", "GET", "/api/admin/config/general", "", 200, `{"settings":{"publicUrl":"","secureCookies":false,"allowedOrigins":""}}`)
	expect("general set", "PUT", "/api/admin/config/general", `{"publicUrl":"https://a.example","allowedOrigins":"https://b.example","secureCookies":true}`, 200, `{"ok":true}`)
	expect("general read back", "GET", "/api/admin/config/general", "", 200, `{"settings":{"publicUrl":"https://a.example","secureCookies":true,"allowedOrigins":"https://b.example"}}`)
	expect("general invalid", "PUT", "/api/admin/config/general", `{"publicUrl":"nope","secureCookies":true}`, 400, `{"error":"publicUrl must be a valid URL."}`)

	expect("models set", "PUT", "/api/admin/models/config", `{"disabledModels":["a","b"],"autoEnableNewModels":false}`, 200, `{"ok":true,"disabledModels":["a","b"],"autoEnableNewModels":false}`)
	expect("models invalid", "PUT", "/api/admin/models/config", `{"disabledModels":"a"}`, 400, `{"error":"disabledModels must be an array"}`)

	status, body := admin.do("GET", "/api/admin/config/email", nil)
	if status != 200 || !strings.HasPrefix(string(body), `{"configured":false,"missing":["Sender address","SMTP host"],"settings":{"smtpPort":587,"tokenTtlHours":24,"smtpPasswordConfigured":false,`) {
		t.Errorf("email default: %d %s", status, body)
	}
	expect("email invalid", "PUT", "/api/admin/config/email", `{}`, 400, `{"error":"SMTP port must be an integer from 1 to 65535."}`)
	good := `{"from":"neo@example.com","smtpHost":"smtp.example.com","smtpUser":"","replyTo":"","brandName":"","supportUrl":"","publicUrl":"","smtpPort":587,"tokenTtlHours":24,` +
		`"smtpSecure":false,"smtpRequireTls":true,"smtpRejectUnauthorized":true,"requireSignupConfirmation":true,"requireEmailChangeConfirmation":true,` +
		`"notifyUnusualLogin":true,"notifyAccountChanges":true,"smtpPassword":"secret"}`
	status, body = admin.do("PUT", "/api/admin/config/email", json.RawMessage(good))
	if status != 200 || !strings.HasPrefix(string(body), `{"ok":true,"configured":true,"missing":[],"settings":{"smtpPort":587,`) || strings.Contains(string(body), "secret") {
		t.Errorf("email set: %d %s", status, body)
	}

	file, _ := os.ReadFile(s.envFile)
	for _, line := range []string{"NEOAGENT_ALLOW_SIGNUP=false", "NEOAGENT_RATE_LIMIT_4H=10", "PUBLIC_URL=https://a.example", "SECURE_COOKIES=true",
		"NEOAGENT_DISABLED_MODELS=a,b", "NEOAGENT_AUTO_ENABLE_NEW_MODELS=false", `NEOAGENT_EMAIL_SMTP_PASS="secret"`, `NEOAGENT_EMAIL_FROM="neo@example.com"`} {
		if !strings.Contains(string(file), line+"\n") {
			t.Errorf(".env lacks %s:\n%s", line, file)
		}
	}
	if info, err := os.Stat(s.envFile); err != nil || info.Mode().Perm() != 0o600 {
		t.Errorf(".env mode: %v %v", info, err)
	}
}

func TestEnvFileKeepsOtherLines(t *testing.T) {
	file := filepath.Join(t.TempDir(), "conf", ".env")
	store := &EnvStore{File: file}
	if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(file, []byte("# keep me\nA=1\nSESSION_SECRET=abc\nB=2\n"), 0o600)
	clearEnv(t, "A", "NEW_KEY")
	if err := store.Persist("A", "9\r\nINJECTED=1"); err != nil {
		t.Fatal(err)
	}
	if err := store.Persist("NEW_KEY", "v"); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(file)
	// a new key lands after the file's trailing newline, as it does on the Node
	// server, so a blank line separates it from the old ones
	if want := "# keep me\nA=9INJECTED=1\nSESSION_SECRET=abc\nB=2\n\nNEW_KEY=v\n"; string(got) != want {
		t.Errorf("file:\n%q\nwant\n%q", got, want)
	}
	// the file never holds a line break; the environment keeps the value as given
	if os.Getenv("A") != "9\r\nINJECTED=1" {
		t.Errorf("process env A = %q", os.Getenv("A"))
	}
	if err := store.Persist("A", ""); err != nil {
		t.Fatal(err)
	}
	if _, set := os.LookupEnv("A"); set {
		t.Error("an empty value must unset the variable")
	}
	if got, _ := os.ReadFile(file); !strings.Contains(string(got), "\nA=\n") {
		t.Errorf("file after clearing:\n%s", got)
	}
}

func TestBadRequestBodies(t *testing.T) {
	s := newStack(t, accountSeed...)
	admin := s.login(adminID)
	status, body := admin.do("PUT", "/api/admin/users/2/rate-limits", json.RawMessage(`{not json`))
	if status != 400 || string(body) != `{"error":"Invalid JSON body"}` {
		t.Errorf("invalid JSON: %d %s", status, body)
	}
	// a body that is not a JSON object reads as empty, like Express' `req.body?.x`
	status, body = admin.do("PUT", "/api/admin/users/2/rate-limits", json.RawMessage(`[1]`))
	if status != 200 {
		t.Errorf("array body: %d %s", status, body)
	}
	status, body = admin.do("POST", "/api/admin/sql", json.RawMessage(`"SELECT 1"`))
	if status != 400 || string(body) != `{"error":"No query provided"}` {
		t.Errorf("string body: %d %s", status, body)
	}
}

// The keyword check is Node's guard; the console also runs on the read-only
// pool, so even a statement that got past the check could not write.
func TestSQLConsoleRunsOnTheReadOnlyPool(t *testing.T) {
	s := newStack(t, accountSeed...)
	if _, err := s.api.Store.DB.R.Exec(`UPDATE users SET is_admin = 1`); err == nil {
		t.Fatal("the read pool accepts writes")
	}
	admin := s.login(adminID)
	for _, query := range []string{"DELETE FROM users", "SELECT 1; UPDATE users SET is_admin = 1", "WITH x AS (SELECT 1) UPDATE users SET is_admin = 1"} {
		if status, _ := admin.do("POST", "/api/admin/sql", map[string]string{"query": query}); status != http.StatusBadRequest {
			t.Errorf("%q: status %d", query, status)
		}
	}
	var flag int
	s.db.W.QueryRow(`SELECT is_admin FROM users WHERE id = 2`).Scan(&flag)
	if flag != 0 {
		t.Fatal("the SQL console wrote to the database")
	}
}

func TestSettingsAndSQLAreRateLimited(t *testing.T) {
	s := newStack(t, accountSeed...)
	admin := s.login(adminID)
	// the settings budget is shared by every route that changes a setting
	for i := 1; i <= 21; i++ {
		path, payload := "/api/admin/config/general", `{}`
		if i%2 == 0 {
			path, payload = "/api/admin/access/signup", `{}`
		}
		status, body := admin.do("PUT", path, json.RawMessage(payload))
		if i <= 20 && status != 400 {
			t.Fatalf("request %d: %d %s", i, status, body)
		}
		if i == 21 && (status != 429 || strings.TrimSpace(string(body)) != `{"error":"Too many settings changes, slow down"}`) {
			t.Fatalf("request 21: %d %s", status, body)
		}
	}
	for i := 1; i <= 61; i++ {
		status, body := admin.do("POST", "/api/admin/sql", map[string]string{"query": "SELECT 1"})
		if i <= 60 && status != 200 {
			t.Fatalf("query %d: %d %s", i, status, body)
		}
		if i == 61 && (status != 429 || strings.TrimSpace(string(body)) != `{"error":"Too many SQL queries, slow down"}`) {
			t.Fatalf("query 61: %d %s", status, body)
		}
	}
	// refused callers never reach the budget
	member := s.login(userID2)
	if status, _ := member.do("PUT", "/api/admin/config/general", json.RawMessage(`{}`)); status != http.StatusForbidden {
		t.Errorf("member got %d", status)
	}
}

func TestModelGrantRouteNeedsACatalog(t *testing.T) {
	s := newStack(t, accountSeed...)
	bare := New(Deps{DB: s.db, Records: s.records, EnvFile: s.envFile, Log: s.api.log})
	mux := http.NewServeMux()
	bare.Routes(mux)
	if _, pattern := mux.Handler(mustRequest(t, "PUT", "/api/admin/users/2/allowed-models")); pattern != "" {
		t.Errorf("PUT allowed-models is registered without a catalog: %q", pattern)
	}
	if _, pattern := mux.Handler(mustRequest(t, "GET", "/api/admin/users/2/allowed-models")); pattern == "" {
		t.Error("GET allowed-models must always be served")
	}
}

func mustRequest(t *testing.T, method, path string) *http.Request {
	t.Helper()
	r, err := http.NewRequest(method, path, nil)
	if err != nil {
		t.Fatal(err)
	}
	return r
}
