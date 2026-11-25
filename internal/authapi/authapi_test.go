package authapi_test

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/authapi"
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/httpserver"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/lockout"
	"github.com/NeoLabs-Systems/neolabs-go/pairing"
	"github.com/NeoLabs-Systems/neolabs-go/qrlogin"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/servicemail"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
	"github.com/NeoLabs-Systems/neolabs-go/testkit"
	"github.com/NeoLabs-Systems/neolabs-go/totp"
	"github.com/NeoLabs-Systems/neolabs-go/webauthnx"
)

func TestMain(m *testing.M) {
	accounts.PasswordCost = 4 // keep bcrypt fast in tests
	os.Exit(m.Run())
}

type testLog struct{ t *testing.T }

func (l testLog) Write(p []byte) (int, error) {
	l.t.Log(strings.TrimSpace(string(p)))
	return len(p), nil
}

type stack struct {
	srv  *httptest.Server
	db   *dbx.DB
	auth *authapi.API
}

func newStack(t *testing.T, env map[string]string, mods ...func(*authapi.API)) *stack {
	t.Helper()
	ctx := context.Background()
	dir := t.TempDir()
	if env == nil {
		env = map[string]string{}
	}
	env["SESSION_SECRET"] = "integration-test-secret"
	cfg, err := config.Load(testkit.Env(env), dir, dir)
	if err != nil {
		t.Fatal(err)
	}
	db, err := dbx.Open(ctx, filepath.Join(dir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
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
	sessions, err := sessionx.NewManager(store, sessionx.Options{
		Name: config.CookieName, Secrets: []string{cfg.SessionSecret}, MaxAge: 30 * 24 * time.Hour,
		Secure: cfg.SecureCookie, TrustProxy: cfg.TrustProxy, Rolling: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New(config.SecretPrefix, "integration-encryption-key")
	if err != nil {
		t.Fatal(err)
	}
	users := &accounts.Repo{DB: db, OpenSignup: func() bool { return cfg.AllowSignup }, AdminUsers: cfg.AdminUsers}
	throttle := lockout.Store{DB: db.W}
	auth := &authapi.API{
		Cfg: cfg, Users: users,
		TwoFactor: &accounts.TwoFactor{DB: db, Box: box, Lockout: throttle, Issuer: "NeoAgent"},
		Passkeys: &webauthnx.Service{
			RPName: "NeoAgent", Origins: cfg.Origins, Store: &accounts.PasskeyStore{DB: db},
			Accounts: accounts.PasskeyAccounts{Repo: users},
		},
		Records:  &accounts.SessionRecords{DB: db, Store: store, Secret: cfg.SessionSecret},
		Sessions: sessions, Lockout: throttle,
		Log: slog.New(slog.NewTextHandler(testLog{t}, nil)),
	}
	auth.Tokens = servicemail.Tokens{DB: db.W}
	auth.QR = &qrlogin.Store{DB: db}
	auth.Pairing = &pairing.Store{DB: db, Scheme: "neoagent"}
	for _, mod := range mods {
		mod(auth)
	}
	if err := auth.Init(); err != nil {
		t.Fatal(err)
	}
	cfg.WebDir, cfg.Landing = t.TempDir(), t.TempDir()
	srv := httptest.NewServer(httpserver.New(httpserver.Deps{Config: cfg, Sessions: sessions, Auth: auth, Log: auth.Log}))
	t.Cleanup(srv.Close)
	return &stack{srv: srv, db: db, auth: auth}
}

type client struct {
	t    *testing.T
	base string
	http *http.Client
}

func (s *stack) client(t *testing.T) *client {
	jar, _ := cookiejar.New(nil)
	return &client{t: t, base: s.srv.URL, http: &http.Client{Jar: jar}}
}

func (c *client) do(method, path string, payload any) (int, map[string]any, http.Header) {
	c.t.Helper()
	var rdr io.Reader
	if payload != nil {
		raw, _ := json.Marshal(payload)
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
	var out map[string]any
	json.Unmarshal(raw, &out)
	return resp.StatusCode, out, resp.Header
}

func (c *client) mustOK(method, path string, payload any) map[string]any {
	c.t.Helper()
	status, out, _ := c.do(method, path, payload)
	if status != 200 {
		c.t.Fatalf("%s %s: %d %v", method, path, status, out)
	}
	return out
}

const goodPassword = "Tr0ub4dor&3-horse"

func register(t *testing.T, c *client, name string) map[string]any {
	t.Helper()
	return c.mustOK("POST", "/api/auth/register", map[string]any{
		"username": name, "email": name + "@example.com", "password": goodPassword,
	})
}

func TestRegisterLoginLogoutFlow(t *testing.T) {
	s := newStack(t, nil)
	c := s.client(t)

	_, st, _ := c.do("GET", "/api/auth/status", nil)
	if st["hasUser"] != false || st["registrationOpen"] != true || st["authenticated"] != false || st["user"] != nil {
		t.Fatalf("fresh status: %v", st)
	}

	// Weak and incomplete sign-ups are refused with stable codes.
	for _, tc := range []struct {
		body map[string]any
		code string
	}{
		{map[string]any{"username": "neo", "email": "neo@example.com", "password": "short"}, "PASSWORD_TOO_SHORT"},
		{map[string]any{"username": "neo", "email": "neo@example.com", "password": "password123"}, "PASSWORD_WEAK"},
		{map[string]any{"username": "ab", "email": "neo@example.com", "password": goodPassword}, "USERNAME_TOO_SHORT"},
		{map[string]any{"username": "neo", "email": "not-an-email", "password": goodPassword}, "INVALID_EMAIL"},
		{map[string]any{"username": "neo", "password": goodPassword}, "MISSING_FIELDS"},
	} {
		if status, out, _ := c.do("POST", "/api/auth/register", tc.body); status != 400 || out["code"] != tc.code {
			t.Errorf("%v: %d %v", tc.body, status, out)
		}
	}

	out := register(t, c, "neo")
	user := out["user"].(map[string]any)
	if out["success"] != true || out["redirect"] != "/app" || user["username"] != "neo" ||
		user["isAdmin"] != true || user["hasPassword"] != true || user["hasCompletedOnboarding"] != false {
		t.Fatalf("register: %v", out)
	}
	if user["displayName"] != nil || user["display_name"] != nil || user["lastLogin"] != nil {
		t.Fatalf("unset fields must be null: %v", user)
	}

	if _, me, _ := c.do("GET", "/api/auth/me", nil); me["user"].(map[string]any)["username"] != "neo" {
		t.Fatalf("me: %v", me)
	}

	// Taken names and emails.
	other := s.client(t)
	if status, out, _ := other.do("POST", "/api/auth/register", map[string]any{"username": "NEO", "email": "x@example.com", "password": goodPassword}); status != 409 || out["code"] != "USERNAME_TAKEN" {
		t.Fatalf("duplicate username: %d %v", status, out)
	}
	if status, out, _ := other.do("POST", "/api/auth/register", map[string]any{"username": "other", "email": "NEO@example.com", "password": goodPassword}); status != 409 || out["code"] != "EMAIL_TAKEN" {
		t.Fatalf("duplicate email: %d %v", status, out)
	}

	c.mustOK("POST", "/api/auth/logout", nil)
	if status, out, _ := c.do("GET", "/api/auth/me", nil); status != 401 || out["error"] != "Not authenticated" {
		t.Fatalf("after logout: %d %v", status, out)
	}

	// Login: wrong password, unknown account and a locked-out sign-in all look alike.
	for _, creds := range []map[string]any{
		{"username": "neo", "password": "wrong-password-1"},
		{"username": "ghost", "password": goodPassword},
	} {
		if status, out, _ := c.do("POST", "/api/auth/login", creds); status != 401 || out["code"] != "INVALID_CREDENTIALS" {
			t.Errorf("%v: %d %v", creds, status, out)
		}
	}
	if status, out, _ := c.do("POST", "/api/auth/login", map[string]any{"username": "neo"}); status != 400 || out["code"] != "MISSING_FIELDS" {
		t.Fatalf("missing password: %d %v", status, out)
	}
	// By email, any case.
	c.mustOK("POST", "/api/auth/login", map[string]any{"username": "NEO@Example.com", "password": goodPassword})
	// Like the Node server, the sign-in answer shows the account as it was loaded
	// (lastLogin still empty on the first sign-in); the update is visible after.
	if _, me, _ := c.do("GET", "/api/auth/me", nil); me["user"].(map[string]any)["lastLogin"] == nil {
		t.Fatalf("lastLogin must be set after sign-in: %v", me)
	}
	c.mustOK("POST", "/api/auth/onboarding/complete", nil)
	if _, me, _ := c.do("GET", "/api/auth/me", nil); me["user"].(map[string]any)["hasCompletedOnboarding"] != true {
		t.Fatalf("onboarding: %v", me)
	}
}

func TestSessionFixationDefence(t *testing.T) {
	s := newStack(t, nil)
	c := s.client(t)
	register(t, c, "neo")
	c.mustOK("POST", "/api/auth/logout", nil)

	before := cookieValue(c, s.srv.URL)
	c.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})
	after := cookieValue(c, s.srv.URL)
	if after == "" || after == before {
		t.Fatal("a new session id must be issued at sign-in")
	}
}

func cookieValue(c *client, base string) string {
	u, _ := http.NewRequest("GET", base, nil)
	for _, ck := range c.http.Jar.Cookies(u.URL) {
		if ck.Name == "neoagent.sid" {
			return ck.Value
		}
	}
	return ""
}

func TestTwoFactorLifecycle(t *testing.T) {
	s := newStack(t, nil)
	c := s.client(t)
	register(t, c, "neo")

	// Setup needs the current password and counts wrong tries.
	if status, out, _ := c.do("POST", "/api/account/2fa/setup", map[string]any{"currentPassword": "nope"}); status != 401 || out["error"] != "Current password is incorrect" {
		t.Fatalf("setup with wrong password: %d %v", status, out)
	}
	setup := c.mustOK("POST", "/api/account/2fa/setup", map[string]any{"currentPassword": goodPassword})
	secret := setup["manualKey"].(string)
	if !strings.HasPrefix(setup["otpauthUrl"].(string), "otpauth://totp/NeoAgent:neo%40example.com?secret="+secret) {
		t.Fatalf("uri: %v", setup["otpauthUrl"])
	}
	if setup["status"].(map[string]any)["pending"] != true {
		t.Fatalf("status: %v", setup["status"])
	}

	if status, out, _ := c.do("POST", "/api/account/2fa/enable", map[string]any{"code": "000000"}); status != 401 || out["error"] != "Invalid 2FA code" {
		t.Fatalf("wrong enable code: %d %v", status, out)
	}
	code, _ := totp.Code(secret, time.Now())
	enabled := c.mustOK("POST", "/api/account/2fa/enable", map[string]any{"code": code})
	recovery := enabled["recoveryCodes"].([]any)
	if enabled["success"] != true || len(recovery) != 10 || enabled["status"].(map[string]any)["enabled"] != true ||
		enabled["status"].(map[string]any)["recoveryCodesRemaining"].(float64) != 10 {
		t.Fatalf("enable: %v", enabled)
	}

	// The secret is sealed at rest.
	var stored string
	s.db.R.QueryRow(`SELECT secret FROM user_two_factor`).Scan(&stored)
	if !strings.HasPrefix(stored, "enc:v1:") || strings.Contains(stored, secret) {
		t.Fatalf("2FA secret must be stored sealed: %q", stored)
	}

	// Sign in again: password alone gives no session.
	c.mustOK("POST", "/api/auth/logout", nil)
	out := c.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})
	if out["requiresTwoFactor"] != true || out["success"] != false || len(out["user"].(map[string]any)) != 1 {
		t.Fatalf("challenge: %v", out)
	}
	if status, _, _ := c.do("GET", "/api/auth/me", nil); status != 401 {
		t.Fatal("a half-finished sign-in must not be a session")
	}
	if status, out, _ := c.do("POST", "/api/auth/login/2fa", map[string]any{"code": "123456"}); status != 401 || out["error"] != "Invalid 2FA code" {
		t.Fatalf("wrong code: %d %v", status, out)
	}
	if status, out, _ := c.do("POST", "/api/auth/login/2fa", map[string]any{}); status != 400 {
		t.Fatalf("missing code: %d %v", status, out)
	}
	code, _ = totp.Code(secret, time.Now())
	if out = c.mustOK("POST", "/api/auth/login/2fa", map[string]any{"code": code}); out["success"] != true {
		t.Fatalf("2fa login: %v", out)
	}
	c.mustOK("GET", "/api/auth/me", nil)

	// A recovery code works exactly once.
	use := recovery[0].(string)
	c.mustOK("POST", "/api/auth/logout", nil)
	c.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})
	c.mustOK("POST", "/api/auth/login/2fa", map[string]any{"code": strings.ToLower(use)})
	c.mustOK("POST", "/api/auth/logout", nil)
	c.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})
	if status, _, _ := c.do("POST", "/api/auth/login/2fa", map[string]any{"code": use}); status != 401 {
		t.Fatal("a recovery code must not work twice")
	}

	// Disable needs password and a code.
	c.mustOK("POST", "/api/auth/logout", nil)
	c.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})
	code, _ = totp.Code(secret, time.Now())
	c.mustOK("POST", "/api/auth/login/2fa", map[string]any{"code": code})
	dis := c.mustOK("POST", "/api/account/2fa/disable", map[string]any{"currentPassword": goodPassword, "code": recovery[1]})
	if dis["status"].(map[string]any)["enabled"] != false || dis["status"].(map[string]any)["recoveryCodesRemaining"].(float64) != 0 {
		t.Fatalf("disable: %v", dis)
	}
}

func TestTwoFactorLoginIsThrottledPerAccount(t *testing.T) {
	s := newStack(t, nil)
	c := s.client(t)
	register(t, c, "neo")
	setup := c.mustOK("POST", "/api/account/2fa/setup", map[string]any{"currentPassword": goodPassword})
	code, _ := totp.Code(setup["manualKey"].(string), time.Now())
	c.mustOK("POST", "/api/account/2fa/enable", map[string]any{"code": code})
	c.mustOK("POST", "/api/auth/logout", nil)

	c.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})
	var last int
	var out map[string]any
	var hdr http.Header
	for i := 0; i < 7; i++ {
		last, out, hdr = c.do("POST", "/api/auth/login/2fa", map[string]any{"code": "111111"})
	}
	if last != 429 || out["code"] != "LOGIN_LOCKED" || hdr.Get("Retry-After") == "" || out["retryAfter"] == nil {
		t.Fatalf("guessing codes must be throttled: %d %v", last, out)
	}
	// Even the right code waits while throttled.
	code, _ = totp.Code(setup["manualKey"].(string), time.Now())
	if status, _, _ := c.do("POST", "/api/auth/login/2fa", map[string]any{"code": code}); status != 429 {
		t.Fatalf("right code during backoff: %d", status)
	}
}

func TestExpiredTwoFactorChallenge(t *testing.T) {
	s := newStack(t, nil)
	c := s.client(t)
	if status, out, _ := c.do("POST", "/api/auth/login/2fa", map[string]any{"code": "123456"}); status != 401 || out["error"] != "Two-factor challenge expired" {
		t.Fatalf("no challenge: %d %v", status, out)
	}
}

// A hash written by the Node server's bcrypt package must keep working.
func TestNodeBcryptHashesStillSignIn(t *testing.T) {
	s := newStack(t, nil)
	raw, err := readFile("../../../neolabs-go/passhash/testdata/vectors.json")
	if err != nil {
		t.Skip("passhash vectors not available next to this checkout")
	}
	var v struct {
		Cases []struct{ Plain, Hash string }
	}
	json.Unmarshal(raw, &v)
	hash := v.Cases[0]
	if _, err := s.db.W.Exec(`INSERT INTO users (username, email, password) VALUES ('legacy', 'legacy@example.com', ?)`, hash.Hash); err != nil {
		t.Fatal(err)
	}
	c := s.client(t)
	if out := c.mustOK("POST", "/api/auth/login", map[string]any{"username": "legacy", "password": hash.Plain}); out["success"] != true {
		t.Fatalf("%v", out)
	}
}

func TestSignupKeysWhenRegistrationIsClosed(t *testing.T) {
	s := newStack(t, map[string]string{"NEOAGENT_ALLOW_SIGNUP": "false"})
	owner := s.client(t)
	register(t, owner, "owner") // the first account never needs a key

	c := s.client(t)
	_, st, _ := c.do("GET", "/api/auth/status", nil)
	if st["signupKeyRequired"] != true || st["registrationOpen"] != false {
		t.Fatalf("status: %v", st)
	}
	body := map[string]any{"username": "guest", "email": "guest@example.com", "password": goodPassword}
	if status, out, _ := c.do("POST", "/api/auth/register", body); status != 403 || out["code"] != "SIGNUP_KEY_REQUIRED" {
		t.Fatalf("no key: %d %v", status, out)
	}
	body["signupKey"] = "AAAA-BBBB-CCCC"
	if status, out, _ := c.do("POST", "/api/auth/register", body); status != 403 || out["code"] != "SIGNUP_KEY_INVALID" {
		t.Fatalf("bad key: %d %v", status, out)
	}
	// A refused sign-up leaves no account behind.
	if n, _ := s.auth.Users.Count(context.Background()); n != 1 {
		t.Fatalf("accounts: %d", n)
	}

	if _, err := s.db.W.Exec(`INSERT INTO signup_keys (code) VALUES ('0123456789AB')`); err != nil {
		t.Fatal(err)
	}
	// Typed any way: lowercase, dashes, look-alike letters.
	if status, out, _ := c.do("POST", "/api/auth/signup-key/check", map[string]any{"key": "o123-4567-89ab"}); status != 200 || out["valid"] != true {
		t.Fatalf("check: %d %v", status, out)
	}
	body["signupKey"] = "0123-4567-89AB"
	register := func() (int, map[string]any) {
		st, o, _ := s.client(t).do("POST", "/api/auth/register", body)
		return st, o
	}
	if status, out := register(); status != 200 {
		t.Fatalf("with key: %d %v", status, out)
	}
	body["username"], body["email"] = "guest2", "guest2@example.com"
	if status, out := register(); status != 403 || out["code"] != "SIGNUP_KEY_USED" {
		t.Fatalf("reused key: %d %v", status, out)
	}
}

func TestPasswordChangeEndsOtherSessions(t *testing.T) {
	s := newStack(t, nil)
	a, b := s.client(t), s.client(t)
	register(t, a, "neo")
	b.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})
	b.mustOK("GET", "/api/auth/me", nil)

	list := a.mustOK("GET", "/api/account/sessions", nil)["sessions"].([]any)
	if len(list) != 2 {
		t.Fatalf("sessions: %v", list)
	}
	current := 0
	for _, e := range list {
		if e.(map[string]any)["current"] == true {
			current++
		}
	}
	if current != 1 {
		t.Fatalf("exactly one current session expected: %v", list)
	}

	// Wrong current password is refused and counted.
	if status, out, _ := a.do("PUT", "/api/account/password", map[string]any{"currentPassword": "bad", "newPassword": "An0ther&Strong-pass"}); status != 401 {
		t.Fatalf("%d %v", status, out)
	}
	if status, out, _ := a.do("PUT", "/api/account/password", map[string]any{"currentPassword": goodPassword, "newPassword": "short"}); status != 400 || out["error"] != "Password min 8 chars" {
		t.Fatalf("%d %v", status, out)
	}
	a.mustOK("PUT", "/api/account/password", map[string]any{"currentPassword": goodPassword, "newPassword": "An0ther&Strong-pass"})

	a.mustOK("GET", "/api/auth/me", nil)
	if status, _, _ := b.do("GET", "/api/auth/me", nil); status != 401 {
		t.Fatal("the other device must be signed out after a password change")
	}
	if status, _, _ := s.client(t).do("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword}); status != 401 {
		t.Fatal("the old password must stop working")
	}
	s.client(t).mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": "An0ther&Strong-pass"})
}

func TestSessionListAndRevoke(t *testing.T) {
	s := newStack(t, nil)
	a, b := s.client(t), s.client(t)
	register(t, a, "neo")
	b.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})

	list := a.mustOK("GET", "/api/account/sessions", nil)["sessions"].([]any)
	var otherID, currentID float64
	for _, e := range list {
		m := e.(map[string]any)
		if m["current"] == true {
			currentID = m["id"].(float64)
		} else {
			otherID = m["id"].(float64)
		}
	}
	if status, out, _ := a.do("DELETE", "/api/account/sessions/"+itoa(currentID), nil); status != 400 || out["error"] != "Use logout to end the current session" {
		t.Fatalf("revoking the current session: %d %v", status, out)
	}
	if status, _, _ := a.do("DELETE", "/api/account/sessions/abc", nil); status != 400 {
		t.Fatal("bad id")
	}
	if status, _, _ := a.do("DELETE", "/api/account/sessions/99999", nil); status != 404 {
		t.Fatal("unknown id")
	}
	out := a.mustOK("DELETE", "/api/account/sessions/"+itoa(otherID), nil)
	if out["success"] != true || len(out["sessions"].([]any)) != 1 {
		t.Fatalf("%v", out)
	}
	if status, _, _ := b.do("GET", "/api/auth/me", nil); status != 401 {
		t.Fatal("revoked session must be signed out")
	}
}

func itoa(f float64) string {
	b, _ := json.Marshal(int64(f))
	return string(b)
}

func TestAccountRoutesNeedASession(t *testing.T) {
	s := newStack(t, nil)
	c := s.client(t)
	for _, tc := range [][2]string{
		{"GET", "/api/account"}, {"PUT", "/api/account/password"}, {"POST", "/api/account/2fa/setup"},
		{"GET", "/api/account/security-keys"}, {"GET", "/api/account/sessions"},
	} {
		if status, out, _ := c.do(tc[0], tc[1], nil); status != 401 || out["error"] != "Unauthorized" {
			t.Errorf("%s %s: %d %v", tc[0], tc[1], status, out)
		}
	}
}

func TestAccountPayloadAndDisplayName(t *testing.T) {
	s := newStack(t, nil)
	c := s.client(t)
	register(t, c, "neo")
	out := c.mustOK("PUT", "/api/account/display-name", map[string]any{"displayName": "  Neo Anderson "})
	user := out["user"].(map[string]any)
	if user["display_name"] != "Neo Anderson" || user["username"] != "neo" || user["isAdmin"] != true {
		t.Fatalf("%v", user)
	}
	for _, k := range []string{"twoFactor", "securityKeys", "authProviders", "dataSharing"} {
		if _, ok := out[k]; !ok {
			t.Errorf("account payload missing %s: %v", k, out)
		}
	}
	if status, _, _ := c.do("PUT", "/api/account/display-name", map[string]any{"displayName": strings.Repeat("x", 65)}); status != 400 {
		t.Fatal("over-long display name")
	}
	if out = c.mustOK("PUT", "/api/account/display-name", map[string]any{"displayName": ""}); out["user"].(map[string]any)["display_name"] != nil {
		t.Fatal("blank clears the display name")
	}
}

func TestPasskeyEndpointsShape(t *testing.T) {
	s := newStack(t, nil)
	c := s.client(t)
	// WebAuthn needs a real host name (browsers refuse IP addresses).
	c.base = strings.Replace(c.base, "127.0.0.1", "localhost", 1)
	// With no key registered anywhere, passkey sign-in says so instead of hanging the browser.
	if status, out, _ := c.do("POST", "/api/auth/webauthn/login/options", map[string]any{}); status != 409 || !strings.Contains(out["error"].(string), "No security keys") {
		t.Fatalf("%d %v", status, out)
	}
	register(t, c, "neo")
	out := c.mustOK("POST", "/api/account/security-keys/register/options", nil)
	opts := out["options"].(map[string]any)
	if opts["challenge"] == nil || opts["rp"] == nil || opts["pubKeyCredParams"] == nil {
		t.Fatalf("options: %v", opts)
	}
	if status, out, _ := c.do("POST", "/api/account/security-keys/register/verify", map[string]any{"response": map[string]any{}}); status != 400 {
		t.Fatalf("garbage response: %d %v", status, out)
	}
	if keys := c.mustOK("GET", "/api/account/security-keys", nil)["securityKeys"].([]any); len(keys) != 0 {
		t.Fatalf("%v", keys)
	}
}

func TestMalformedBodiesAndLimits(t *testing.T) {
	s := newStack(t, nil)
	req, _ := http.NewRequest("POST", s.srv.URL+"/api/auth/login", strings.NewReader("{not json"))
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != 400 {
		t.Fatalf("malformed JSON: %d", resp.StatusCode)
	}
}

func TestLoginRateLimit(t *testing.T) {
	s := newStack(t, nil)
	c := s.client(t)
	var status int
	var hdr http.Header
	for i := 0; i < 21; i++ {
		status, _, hdr = c.do("POST", "/api/auth/login", map[string]any{"username": "x", "password": "y"})
	}
	if status != 429 || hdr.Get("RateLimit-Policy") != "20;w=900" || hdr.Get("Retry-After") == "" {
		t.Fatalf("21st attempt in the window must be limited: %d %v", status, hdr)
	}
}

func TestSecureCookieNeedsHTTPS(t *testing.T) {
	s := newStack(t, map[string]string{"PUBLIC_URL": "https://agent.example.com"})
	c := s.client(t)
	status, out, _ := c.do("POST", "/api/auth/login", map[string]any{"username": "a", "password": "b"})
	if status != 400 || out["code"] != "INSECURE_TRANSPORT" || out["httpsUrl"] != "https://agent.example.com" {
		t.Fatalf("%d %v", status, out)
	}
}

func readFile(p string) ([]byte, error) { return os.ReadFile(p) }
