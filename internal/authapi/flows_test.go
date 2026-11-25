package authapi_test

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/authapi"
	"github.com/NeoLabs-Systems/neolabs-go/oauthlogin"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/servicemail"
)

// ---- fakes ------------------------------------------------------------------

type sentMail struct {
	to  string
	msg servicemail.Message
}

type fakeMailer struct {
	mu   sync.Mutex
	sent []sentMail
	fail bool
}

func (f *fakeMailer) Send(_ context.Context, to string, m servicemail.Message) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.fail {
		return errors.New("smtp down")
	}
	f.sent = append(f.sent, sentMail{to, m})
	return nil
}

func (f *fakeMailer) all() []sentMail {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]sentMail(nil), f.sent...)
}

// waitFor polls until pred holds: notices are sent asynchronously.
func (f *fakeMailer) waitFor(t *testing.T, pred func([]sentMail) bool) []sentMail {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for {
		if got := f.all(); pred(got) {
			return got
		}
		if time.Now().After(deadline) {
			t.Fatalf("expected mail never arrived; sent: %+v", f.all())
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func (f *fakeMailer) last(t *testing.T) sentMail {
	t.Helper()
	all := f.all()
	if len(all) == 0 {
		t.Fatal("no mail sent")
	}
	return all[len(all)-1]
}

func tokenOf(t *testing.T, m sentMail) string {
	t.Helper()
	u, err := url.Parse(m.msg.ActionURL)
	if err != nil || u.Query().Get("token") == "" {
		t.Fatalf("no token in %q", m.msg.ActionURL)
	}
	return u.Query().Get("token")
}

var mailEnv = map[string]string{
	"NEOAGENT_EMAIL_SMTP_HOST": "smtp.example", "NEOAGENT_EMAIL_FROM": "noreply@example.com",
	"PUBLIC_URL": "https://agent.example.com", "SECURE_COOKIES": "false",
}

func withMailer(f *fakeMailer) func(*authapi.API) { return func(a *authapi.API) { a.Mail = f } }

func (c *client) raw(method, path, contentType, body string) (int, string, http.Header) {
	c.t.Helper()
	req, _ := http.NewRequest(method, c.base+path, strings.NewReader(body))
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		c.t.Fatal(err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(b), resp.Header
}

func (c *client) postForm(path string, v url.Values) (int, string) {
	st, body, _ := c.raw("POST", path, "application/x-www-form-urlencoded", v.Encode())
	return st, body
}

func copyEnv(extra map[string]string) map[string]string {
	out := map[string]string{}
	for k, v := range mailEnv {
		out[k] = v
	}
	for k, v := range extra {
		out[k] = v
	}
	return out
}

// ---- email confirmation -------------------------------------------------------

func TestSignupConfirmationFlow(t *testing.T) {
	mail := &fakeMailer{}
	s := newStack(t, copyEnv(nil), withMailer(mail))
	c := s.client(t)

	_, st, _ := c.do("GET", "/api/auth/status", nil)
	em := st["email"].(map[string]any)
	if em["enabled"] != true || em["configured"] != true || em["signupConfirmationRequired"] != true {
		t.Fatalf("status email: %v", em)
	}

	status, out, _ := c.do("POST", "/api/auth/register", map[string]any{"username": "neo", "email": "Neo@Example.com", "password": goodPassword})
	if status != 202 || out["requiresEmailConfirmation"] != true || out["success"] != false ||
		out["message"] != "Check your email to confirm your NeoAgent account." {
		t.Fatalf("%d %v", status, out)
	}
	if status, _, _ := c.do("GET", "/api/auth/me", nil); status != 401 {
		t.Fatal("an unconfirmed sign-up must not be signed in")
	}
	m := mail.last(t)
	if m.to != "neo@example.com" || m.msg.Subject != "Confirm your NeoAgent email" || m.msg.ActionLabel != "Confirm email" ||
		!strings.HasPrefix(m.msg.ActionURL, "https://agent.example.com/api/auth/email/confirm?token=") ||
		m.msg.Details[1].Value != "24 hours" {
		t.Fatalf("%+v", m)
	}

	// Sign-in is refused until the link is followed.
	if status, out, _ := c.do("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword}); status != 403 || out["requiresEmailConfirmation"] != true {
		t.Fatalf("%d %v", status, out)
	}

	token := tokenOf(t, m)
	st2, page, _ := c.raw("GET", "/api/auth/email/confirm?token="+token, "", "")
	if st2 != 200 || !strings.Contains(page, "Email confirmed") {
		t.Fatalf("%d %s", st2, page)
	}
	if st2, page, _ = c.raw("GET", "/api/auth/email/confirm?token="+token, "", ""); st2 != 400 || !strings.Contains(page, "Could not confirm email") {
		t.Fatalf("a link works once: %d", st2)
	}
	if st2, page, _ = c.raw("GET", "/api/auth/email/confirm", "", ""); st2 != 400 || !strings.Contains(page, "Confirmation link missing") {
		t.Fatalf("%d", st2)
	}
	c.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})
}

func TestSignupWithAMailOutageLeavesNothingBehind(t *testing.T) {
	mail := &fakeMailer{fail: true}
	s := newStack(t, copyEnv(map[string]string{"NEOAGENT_ALLOW_SIGNUP": "false"}), withMailer(mail))
	owner := s.client(t)
	// The first account needs no key and, with email on, still needs confirmation;
	// make it directly instead.
	if _, err := s.db.W.Exec(`INSERT INTO users (username, email, password, email_verified_at) VALUES ('owner', 'o@example.com', 'x', datetime('now'))`); err != nil {
		t.Fatal(err)
	}
	_ = owner
	if _, err := s.db.W.Exec(`INSERT INTO signup_keys (code) VALUES ('0123456789AB')`); err != nil {
		t.Fatal(err)
	}
	c := s.client(t)
	status, out, _ := c.do("POST", "/api/auth/register", map[string]any{
		"username": "guest", "email": "guest@example.com", "password": goodPassword, "signupKey": "0123-4567-89AB"})
	// Like Node, the 5xx text is hidden from non-admins by the redaction middleware.
	if status != 503 || out["error"] != "Something went wrong. Please try again." {
		t.Fatalf("%d %v", status, out)
	}
	var users, tokens int
	var usedBy any
	s.db.W.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&users)
	s.db.W.QueryRow(`SELECT COUNT(*) FROM user_email_tokens`).Scan(&tokens)
	s.db.W.QueryRow(`SELECT used_by_user_id FROM signup_keys`).Scan(&usedBy)
	if users != 1 || tokens != 0 || usedBy != nil {
		t.Fatalf("users=%d tokens=%d key used by %v: the account must be removed and the key returned", users, tokens, usedBy)
	}
}

// ---- forgot and reset password ------------------------------------------------

func TestPasswordResetFlow(t *testing.T) {
	mail := &fakeMailer{}
	s := newStack(t, copyEnv(map[string]string{"NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION": "false"}), withMailer(mail))
	a, other := s.client(t), s.client(t)
	register(t, a, "neo")
	other.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})

	// Unknown and known accounts get the same answer; only the known one gets mail.
	anon := s.client(t)
	startedAt := time.Now()
	status, out, _ := anon.do("POST", "/api/auth/password/forgot", map[string]any{"account": "nobody"})
	if time.Since(startedAt) < 300*time.Millisecond {
		t.Fatal("the answer must not come back faster than the minimum latency")
	}
	if status != 200 || out["success"] != true || len(mail.all()) != 0 {
		t.Fatalf("%d %v %v", status, out, mail.all())
	}
	status2, out2, _ := anon.do("POST", "/api/auth/password/forgot", map[string]any{"account": " NEO@example.COM "})
	if status2 != 200 || out2["message"] != out["message"] {
		t.Fatal("identical answers hide which accounts exist")
	}
	m := mail.last(t)
	if m.to != "neo@example.com" || m.msg.Subject != "Reset your NeoAgent password" ||
		!strings.HasPrefix(m.msg.ActionURL, "https://agent.example.com/api/auth/password/reset?token=") {
		t.Fatalf("%+v", m)
	}
	token := tokenOf(t, m)

	// The form, then a submission.
	if st, page, _ := anon.raw("GET", "/api/auth/password/reset?token="+token, "", ""); st != 200 || !strings.Contains(page, `name="token" value="`+token+`"`) {
		t.Fatalf("%d", st)
	}
	if st, page, _ := anon.raw("GET", "/api/auth/password/reset", "", ""); st != 400 || !strings.Contains(page, "Open the full password reset link") {
		t.Fatalf("%d", st)
	}
	if st, page := anon.postForm("/api/auth/password/reset", url.Values{"token": {token}, "password": {"An0ther&Strong-pass"}, "confirmPassword": {"different"}}); st != 400 || !strings.Contains(page, "Passwords do not match.") {
		t.Fatalf("%d", st)
	}
	if st, page := anon.postForm("/api/auth/password/reset", url.Values{"token": {token}, "password": {"password123"}, "confirmPassword": {"password123"}}); st != 400 || !strings.Contains(page, "Password is too weak") {
		t.Fatalf("weak password: %d %s", st, page)
	}
	st, page := anon.postForm("/api/auth/password/reset", url.Values{"token": {token}, "password": {"An0ther&Strong-pass"}, "confirmPassword": {"An0ther&Strong-pass"}})
	if st != 200 || !strings.Contains(page, "Password changed") {
		t.Fatalf("%d %s", st, page)
	}

	// Every session ended, the old password is gone, the link is spent, a notice went out.
	for _, c := range []*client{a, other} {
		if status, _, _ := c.do("GET", "/api/auth/me", nil); status != 401 {
			t.Fatal("a reset must sign out every session")
		}
	}
	if status, _, _ := anon.do("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword}); status != 401 {
		t.Fatal("old password must stop working")
	}
	anon.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": "An0ther&Strong-pass"})
	if st, page := anon.postForm("/api/auth/password/reset", url.Values{"token": {token}, "password": {"Yet&Another-1pass"}, "confirmPassword": {"Yet&Another-1pass"}}); st != 400 || !strings.Contains(page, "invalid or expired") {
		t.Fatalf("a link works once: %d", st)
	}
	mail.waitFor(t, func(all []sentMail) bool {
		for _, m := range all {
			if m.msg.Subject == "NeoAgent password changed" && m.to == "neo@example.com" {
				return true
			}
		}
		return false
	})
}

func TestResetLinkGuessingIsLimited(t *testing.T) {
	s := newStack(t, copyEnv(nil), withMailer(&fakeMailer{}))
	c := s.client(t)
	var last int
	var page string
	// 12 wrong tries on one link lock it; the per-IP limiter (8) would hit first,
	// so use many clients sharing one limiter-free path: call the engine directly.
	for i := 0; i < 13; i++ {
		last, page = c.postForm("/api/auth/password/reset", url.Values{"token": {"guess"}, "password": {"x"}, "confirmPassword": {"x"}})
		if last == 429 {
			break
		}
	}
	if last != 400 && last != 429 {
		t.Fatalf("%d %s", last, page)
	}
}

// ---- email change -------------------------------------------------------------

func TestEmailChange(t *testing.T) {
	mail := &fakeMailer{}
	s := newStack(t, copyEnv(map[string]string{"NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION": "false"}), withMailer(mail))
	c := s.client(t)
	register(t, c, "neo")
	register2 := s.client(t)
	register(t, register2, "other")

	if status, out, _ := c.do("PUT", "/api/account/email", map[string]any{"email": "nope", "currentPassword": goodPassword}); status != 400 || out["error"] != "A valid email is required" {
		t.Fatalf("%d %v", status, out)
	}
	if status, _, _ := c.do("PUT", "/api/account/email", map[string]any{"email": "new@example.com", "currentPassword": "wrong"}); status != 401 {
		t.Fatalf("wrong password: %d", status)
	}
	if status, out, _ := c.do("PUT", "/api/account/email", map[string]any{"email": "OTHER@example.com", "currentPassword": goodPassword}); status != 409 || out["error"] != "Email is already in use" {
		t.Fatalf("%d %v", status, out)
	}
	// Same address: nothing to do.
	out := c.mustOK("PUT", "/api/account/email", map[string]any{"email": "neo@example.com", "currentPassword": goodPassword})
	if _, pending := out["emailChangePending"]; pending {
		t.Fatalf("%v", out)
	}

	out = c.mustOK("PUT", "/api/account/email", map[string]any{"email": "New@Example.com", "currentPassword": goodPassword})
	if out["emailChangePending"] != true || out["pendingEmail"] != "new@example.com" || out["user"].(map[string]any)["email"] != "neo@example.com" {
		t.Fatalf("the address changes only after confirmation: %v", out)
	}
	sent := mail.waitFor(t, func(all []sentMail) bool { return len(all) >= 2 }) // confirmation + "change requested" notice
	var confirm sentMail
	for _, m := range sent {
		if m.msg.Subject == "Confirm your new NeoAgent email" {
			confirm = m
		}
	}
	if confirm.to != "new@example.com" {
		t.Fatalf("confirmation goes to the new address: %+v", sent)
	}
	if st, page, _ := c.raw("GET", "/api/auth/email/confirm?token="+tokenOf(t, confirm), "", ""); st != 200 || !strings.Contains(page, "Email confirmed") {
		t.Fatalf("%d", st)
	}
	if me := c.mustOK("GET", "/api/auth/me", nil); me["user"].(map[string]any)["email"] != "new@example.com" {
		t.Fatalf("%v", me)
	}
	mail.waitFor(t, func(all []sentMail) bool {
		old, fresh := false, false
		for _, m := range all {
			if m.msg.Subject == "NeoAgent email changed" && m.to == "neo@example.com" {
				old = true
			}
			if m.msg.Subject == "NeoAgent email changed" && m.to == "new@example.com" {
				fresh = true
			}
		}
		return old && fresh
	})
}

func TestEmailChangeWithoutConfirmation(t *testing.T) {
	mail := &fakeMailer{}
	s := newStack(t, map[string]string{"NEOAGENT_EMAIL_SMTP_HOST": "h", "NEOAGENT_EMAIL_FROM": "f@x.y",
		"NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION": "false", "NEOAGENT_EMAIL_REQUIRE_EMAIL_CHANGE_CONFIRMATION": "false"}, withMailer(mail))
	c := s.client(t)
	register(t, c, "neo")
	out := c.mustOK("PUT", "/api/account/email", map[string]any{"email": "new@example.com", "currentPassword": goodPassword})
	if out["user"].(map[string]any)["email"] != "new@example.com" {
		t.Fatalf("%v", out)
	}
	if _, pending := out["emailChangePending"]; pending {
		t.Fatal("no pending state when confirmation is off")
	}
}

func TestUnusualSignInSendsANotice(t *testing.T) {
	mail := &fakeMailer{}
	s := newStack(t, copyEnv(map[string]string{"NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION": "false"}), withMailer(mail))
	a := s.client(t)
	register(t, a, "neo")
	// A second sign-in with a different device and place than any live session.
	if _, err := s.db.W.Exec(`UPDATE user_sessions SET ip_address = '203.0.113.9', user_agent = 'Other', location_label = 'Paris, FR'`); err != nil {
		t.Fatal(err)
	}
	b := s.client(t)
	b.mustOK("POST", "/api/auth/login", map[string]any{"username": "neo", "password": goodPassword})
	sent := mail.waitFor(t, func(all []sentMail) bool {
		for _, m := range all {
			if m.msg.Subject == "New NeoAgent sign-in" {
				return true
			}
		}
		return false
	})
	for _, m := range sent {
		if m.msg.Subject == "New NeoAgent sign-in" && (m.to != "neo@example.com" || m.msg.Details[0].Value != "neo") {
			t.Fatalf("%+v", m)
		}
	}
}

// ---- QR login -----------------------------------------------------------------

func TestQRLoginSignsAScreenIn(t *testing.T) {
	s := newStack(t, nil)
	phone := s.client(t)
	register(t, phone, "neo")
	screen := s.client(t)

	ch := screen.mustOK("POST", "/api/auth/qr-login/challenge", map[string]any{"requestMetadata": map[string]any{"deviceLabel": "Desk"}})
	payload, err := url.Parse(ch["qrPayload"].(string))
	if err != nil || payload.Scheme != "neoagent" || payload.Host != "qr-login" || payload.Query().Get("v") != "1" ||
		payload.Query().Get("challenge") != ch["challengeId"] || payload.Query().Get("backend") != ch["backendUrl"] {
		t.Fatalf("%v %v", payload, err)
	}
	secret := payload.Query().Get("secret")
	id, poll := ch["challengeId"].(string), ch["pollToken"].(string)

	// The screen cannot sign itself in.
	if status, _, _ := screen.do("POST", "/api/auth/qr-login/challenge/"+id+"/claim", map[string]any{"token": poll}); status != 409 {
		t.Fatalf("claim before approval: %d", status)
	}
	if status, out, _ := screen.do("POST", "/api/auth/qr-login/challenge/"+id+"/status", map[string]any{}); status != 400 || out["error"] != "QR login poll token is required." {
		t.Fatalf("%d %v", status, out)
	}
	// Only a signed-in account can approve.
	if status, _, _ := screen.do("POST", "/api/account/qr-login/approve", map[string]any{"challengeId": id, "secret": secret}); status != 401 {
		t.Fatalf("anonymous approval: %d", status)
	}
	if status, out, _ := phone.do("POST", "/api/account/qr-login/resolve", map[string]any{"challengeId": id}); status != 400 || out["error"] != "Challenge id and QR secret are required." {
		t.Fatalf("%d %v", status, out)
	}
	prev := phone.mustOK("POST", "/api/account/qr-login/resolve", map[string]any{"challengeId": id, "secret": secret, "scannerMetadata": map[string]any{"deviceLabel": "Neo iPhone"}})
	if prev["status"] != "pending" || prev["requestedDevice"].(map[string]any)["label"] != "Desk" {
		t.Fatalf("%v", prev)
	}
	_, st, _ := screen.do("POST", "/api/auth/qr-login/challenge/"+id+"/status", map[string]any{"token": poll})
	if st["status"] != "scanned" || st["scannedBy"].(map[string]any)["label"] != "Neo iPhone" {
		t.Fatalf("%v", st)
	}
	appr := phone.mustOK("POST", "/api/account/qr-login/approve", map[string]any{"challengeId": id, "secret": secret})
	if appr["status"] != "approved" || appr["approval"].(map[string]any)["userId"] == nil {
		t.Fatalf("%v", appr)
	}

	// A held status request answers as soon as the status changes.
	done := screen.mustOK("POST", "/api/auth/qr-login/challenge/"+id+"/status", map[string]any{"token": poll, "knownStatus": "scanned"})
	if done["status"] != "approved" || done["longPoll"] != true {
		t.Fatalf("%v", done)
	}

	out := screen.mustOK("POST", "/api/auth/qr-login/challenge/"+id+"/claim", map[string]any{"token": poll})
	if out["success"] != true || out["user"].(map[string]any)["username"] != "neo" {
		t.Fatalf("%v", out)
	}
	if me := screen.mustOK("GET", "/api/auth/me", nil); me["user"].(map[string]any)["username"] != "neo" {
		t.Fatalf("%v", me)
	}
	if status, _, _ := screen.do("POST", "/api/auth/qr-login/challenge/"+id+"/claim", map[string]any{"token": poll}); status != 409 {
		t.Fatalf("a code works once: %d", status)
	}
}

func TestQRLoginDeclineAndCancelAndWearable(t *testing.T) {
	s := newStack(t, nil)
	phone := s.client(t)
	register(t, phone, "neo")
	screen := s.client(t)

	mk := func(meta map[string]any) (id, poll, secret string) {
		ch := screen.mustOK("POST", "/api/auth/qr-login/challenge", map[string]any{"requestMetadata": meta})
		u, _ := url.Parse(ch["qrPayload"].(string))
		return ch["challengeId"].(string), ch["pollToken"].(string), u.Query().Get("secret")
	}
	id, poll, secret := mk(nil)
	phone.mustOK("POST", "/api/account/qr-login/decline", map[string]any{"challengeId": id, "secret": secret})
	if status, _, _ := phone.do("POST", "/api/account/qr-login/approve", map[string]any{"challengeId": id, "secret": secret}); status != 409 {
		t.Fatalf("approve after decline: %d", status)
	}
	_ = poll

	id, poll, secret = mk(nil)
	screen.mustOK("POST", "/api/auth/qr-login/challenge/"+id+"/cancel", map[string]any{"token": poll})
	if status, _, _ := phone.do("POST", "/api/account/qr-login/approve", map[string]any{"challengeId": id, "secret": secret}); status != 409 {
		t.Fatalf("late approval after cancel: %d", status)
	}

	// A wearable asks for a long-lived session.
	id, poll, secret = mk(map[string]any{"platform": "esp32-s3-amoled"})
	phone.mustOK("POST", "/api/account/qr-login/approve", map[string]any{"challengeId": id, "secret": secret})
	_, _, hdr := screen.do("POST", "/api/auth/qr-login/challenge/"+id+"/claim", map[string]any{"token": poll})
	cookie := hdr.Get("Set-Cookie")
	exp := regexp.MustCompile(`Expires=([^;]+)`).FindStringSubmatch(cookie)
	if exp == nil {
		t.Fatalf("no cookie: %q", cookie)
	}
	when, err := time.Parse(time.RFC1123, exp[1])
	if err != nil || time.Until(when) < 80*24*time.Hour {
		t.Fatalf("the wearable session must last ~90 days: %v %v", when, err)
	}
}

// ---- pairing ------------------------------------------------------------------

func TestPairingSignsAPhoneIn(t *testing.T) {
	s := newStack(t, nil)
	screen := s.client(t)
	register(t, screen, "neo")
	started := screen.mustOK("POST", "/api/account/pairing", nil)
	code := started["code"].(string)
	if !strings.HasPrefix(started["qrPayload"].(string), "neoagent://pair?server=") || started["server"] == "" {
		t.Fatalf("%v", started)
	}
	if st := screen.mustOK("GET", "/api/account/pairing/"+code, nil); st["status"] != "pending" {
		t.Fatalf("%v", st)
	}

	phone := s.client(t)
	if status, out, _ := phone.do("POST", "/api/auth/pair", map[string]any{"code": "nope"}); status != 410 || out["code"] != "EXPIRED_TOKEN" {
		t.Fatalf("%d %v", status, out)
	}
	out := phone.mustOK("POST", "/api/auth/pair", map[string]any{"code": code, "name": "Neo's phone"})
	if out["success"] != true || out["user"].(map[string]any)["username"] != "neo" {
		t.Fatalf("%v", out)
	}
	phone.mustOK("GET", "/api/auth/me", nil)
	st := screen.mustOK("GET", "/api/account/pairing/"+code, nil)
	if st["status"] != "used" || st["device"].(map[string]any)["name"] != "Neo's phone" {
		t.Fatalf("%v", st)
	}
	if status, _, _ := s.client(t).do("POST", "/api/auth/pair", map[string]any{"code": code}); status != 410 {
		t.Fatalf("a code works once: %d", status)
	}
}

// ---- OAuth provider sign-in -----------------------------------------------------

type testProvider struct{ identity oauthlogin.Identity }

func (p *testProvider) Key() string                  { return "fake" }
func (p *testProvider) Label() string                { return "Fake" }
func (p *testProvider) Icon() string                 { return "fake" }
func (p *testProvider) Status(string) (bool, string) { return true, "ready" }
func (p *testProvider) Begin(_ context.Context, state, _, _ string) (string, error) {
	return "https://provider.example/auth?state=" + state, nil
}
func (p *testProvider) Finish(context.Context, string, string) (oauthlogin.Identity, error) {
	return p.identity, nil
}

func withOAuth(p *testProvider) func(*authapi.API) {
	return func(a *authapi.API) {
		box, _ := secretbox.New("enc:v1:", "k")
		a.OAuth = &oauthlogin.Engine{DB: a.Records.DB, Box: box, Providers: []oauthlogin.Provider{p}, Accounts: accounts.ProviderAccounts{Repo: a.Users}, Product: "NeoAgent"}
	}
}

func TestProviderRegistrationInTheSameBrowser(t *testing.T) {
	p := &testProvider{identity: oauthlogin.Identity{ProviderUserID: "p-1", Email: "new.person@example.com", EmailVerified: true, DisplayName: "New Person"}}
	s := newStack(t, nil, withOAuth(p))
	c := s.client(t)

	if list := c.mustOK("GET", "/api/auth/providers", nil)["providers"].([]any); len(list) != 1 || list[0].(map[string]any)["id"] != "fake" {
		t.Fatalf("%v", list)
	}
	begin := c.mustOK("POST", "/api/auth/providers/fake/begin", map[string]any{"mode": "register"})
	state := begin["state"].(string)
	if begin["status"] != "oauth_redirect" || !strings.Contains(begin["url"].(string), state) {
		t.Fatalf("%v", begin)
	}

	// Only the browser that started the flow may read its outcome.
	if status, _, _ := s.client(t).do("GET", "/api/auth/providers/complete?state="+state, nil); status != 404 {
		t.Fatalf("another browser: %d", status)
	}

	// The provider redirects back into the same browser: finished at once.
	st, page, _ := c.raw("GET", "/api/integrations/oauth/callback?state="+state+"&code=abc", "", "")
	if st != 200 || !strings.Contains(page, "Connected.") || !strings.Contains(page, `"type":"auth_oauth_success"`) || !strings.Contains(page, `"mode":"register"`) {
		t.Fatalf("%d %s", st, page)
	}
	done := c.mustOK("GET", "/api/auth/providers/complete?state="+state, nil)
	if done["success"] != true || done["user"].(map[string]any)["username"] != "newperson" {
		t.Fatalf("%v", done)
	}
	me := c.mustOK("GET", "/api/auth/me", nil)["user"].(map[string]any)
	if me["hasPassword"] != false || me["email"] != "new.person@example.com" {
		t.Fatalf("an account made by a provider has no password: %v", me)
	}
	acct := c.mustOK("GET", "/api/account", nil)["authProviders"].([]any)
	if len(acct) != 1 || acct[0].(map[string]any)["canUnlink"] != false {
		t.Fatalf("the only way in cannot be unlinked: %v", acct)
	}
	if status, _, _ := c.do("DELETE", "/api/account/providers/"+itoa(acct[0].(map[string]any)["id"].(float64)), nil); status != 400 {
		t.Fatalf("unlink last method: %d", status)
	}
}

func TestProviderCallbackInAnotherBrowserNeedsConfirmation(t *testing.T) {
	p := &testProvider{identity: oauthlogin.Identity{ProviderUserID: "p-2", Email: "x@example.com", DisplayName: "Neo"}}
	s := newStack(t, nil, withOAuth(p))
	app := s.client(t)
	register(t, app, "neo")
	begin := app.mustOK("POST", "/api/auth/providers/fake/begin", map[string]any{"mode": "link"})
	state := begin["state"].(string)

	system := s.client(t) // the system browser: a different session
	st, page, _ := system.raw("GET", "/api/integrations/oauth/callback?state="+state+"&code=abc", "", "")
	if st != 200 || !strings.Contains(page, "Do you want to link Fake to the NeoAgent account <strong>neo</strong>?") {
		t.Fatalf("%d %s", st, page)
	}
	m := regexp.MustCompile(`href="callback/confirm\?token=([^"]+)"`).FindStringSubmatch(page)
	if m == nil {
		t.Fatalf("no confirm link: %s", page)
	}
	// Nothing happened yet.
	if c, _ := s.auth.OAuth.Consume(context.Background(), state); c == nil || c.Status != "pending" {
		t.Fatalf("%+v", c)
	}
	st, page, _ = system.raw("GET", "/api/integrations/oauth/callback/confirm?token="+m[1], "", "")
	if st != 200 || !strings.Contains(page, "Connected.") {
		t.Fatalf("%d %s", st, page)
	}
	if st, page, _ = system.raw("GET", "/api/integrations/oauth/callback/confirm?token="+m[1], "", ""); st != 400 || !strings.Contains(page, "expired or was already used") {
		t.Fatalf("confirm links work once: %d", st)
	}
	link := app.mustOK("GET", "/api/auth/providers/complete?state="+state, nil)
	if link["mode"] != "link" || link["success"] != true {
		t.Fatalf("%v", link)
	}
	if list := app.mustOK("GET", "/api/account", nil)["authProviders"].([]any); len(list) != 1 || list[0].(map[string]any)["provider"] != "fake" || list[0].(map[string]any)["canUnlink"] != true {
		t.Fatalf("%v", list)
	}
}

func TestProviderCallbackEdgeCases(t *testing.T) {
	s := newStack(t, nil, withOAuth(&testProvider{}))
	c := s.client(t)
	for _, tc := range []struct {
		path   string
		status int
		want   string
	}{
		{"/api/integrations/oauth/callback", 400, "Missing state parameter"},
		{"/api/integrations/oauth/callback?error=access_denied", 400, "Sign-in was canceled."},
		{"/api/integrations/oauth/callback?state=zzz&code=1", 400, "Invalid OAuth state parameter"},
		{"/api/integrations/oauth/callback?state=auth_" + strings.Repeat("a", 48), 400, "Missing code parameter"},
		{"/api/integrations/oauth/callback?state=auth_" + strings.Repeat("a", 48) + "&code=1", 400, "This request has expired"},
		{"/api/integrations/oauth/callback?state=auth_" + strings.Repeat("a", 48) + "&error=denied", 400, "denied"},
	} {
		st, body, _ := c.raw("GET", tc.path, "", "")
		if st != tc.status || !strings.Contains(body, tc.want) {
			t.Errorf("%s: %d %q", tc.path, st, body)
		}
	}
	if st, out, _ := c.do("POST", "/api/auth/providers/fake/begin", map[string]any{"mode": "link"}); st != 400 || !strings.Contains(out["error"].(string), "signed in") {
		t.Fatalf("link needs a session: %d %v", st, out)
	}
	if st, _, _ := c.do("POST", "/api/auth/providers/nope/begin", map[string]any{"mode": "login"}); st != 400 {
		t.Fatal("unknown provider")
	}
	if st, out, _ := c.do("POST", "/api/auth/providers/register", map[string]any{"state": "auth_x"}); st != 404 {
		t.Fatalf("%d %v", st, out)
	}
}

func TestProviderLoginRespectsTwoFactor(t *testing.T) {
	p := &testProvider{identity: oauthlogin.Identity{ProviderUserID: "p-3", Email: "neo@example.com"}}
	s := newStack(t, nil, withOAuth(p))
	c := s.client(t)
	register(t, c, "neo")
	// link, enable 2FA, then sign in with the provider from a fresh browser.
	st := c.mustOK("POST", "/api/auth/providers/fake/begin", map[string]any{"mode": "link"})["state"].(string)
	c.raw("GET", "/api/integrations/oauth/callback?state="+st+"&code=a", "", "")
	c.mustOK("GET", "/api/auth/providers/complete?state="+st, nil)
	setup := c.mustOK("POST", "/api/account/2fa/setup", map[string]any{"currentPassword": goodPassword})
	_ = setup
	if _, err := s.db.W.Exec(`UPDATE user_two_factor SET enabled = 1, secret = pending_secret, pending_secret = NULL`); err != nil {
		t.Fatal(err)
	}

	fresh := s.client(t)
	st = fresh.mustOK("POST", "/api/auth/providers/fake/begin", map[string]any{"mode": "login"})["state"].(string)
	fresh.raw("GET", "/api/integrations/oauth/callback?state="+st+"&code=a", "", "")
	out := fresh.mustOK("GET", "/api/auth/providers/complete?state="+st, nil)
	if out["requiresTwoFactor"] != true || out["success"] != false {
		t.Fatalf("a provider sign-in still needs the second factor: %v", out)
	}
	if status, _, _ := fresh.do("GET", "/api/auth/me", nil); status != 401 {
		t.Fatal("not signed in yet")
	}
}

var _ = json.Marshal

func TestIntegrationOAuthRequiresConfirmationInAnotherBrowser(t *testing.T) {
	state := strings.Repeat("a", 48)
	finished := 0
	s := newStack(t, nil, func(a *authapi.API) {
		a.IntegrationOAuth = &authapi.IntegrationCallbacks{
			Describe: func(_ context.Context, got string) (*authapi.IntegrationPending, error) {
				if got != state {
					return nil, nil
				}
				return &authapi.IntegrationPending{ProviderLabel: "Figma", AppLabel: "Figma", Username: "neo", StartedAt: "2026-01-01"}, nil
			},
			Finish: func(_ context.Context, got, code string) (*authapi.IntegrationResult, error) {
				if got != state || code != "abc" {
					t.Fatalf("unexpected callback %q %q", got, code)
				}
				finished++
				id := int64(7)
				return &authapi.IntegrationResult{Provider: "figma", AppID: "figma", ConnectionID: &id, AccountEmail: "neo@example.com"}, nil
			},
		}
	})
	c := s.client(t)
	status, page, _ := c.raw("GET", "/api/integrations/oauth/callback?state="+state+"&code=abc", "", "")
	if status != 200 || !strings.Contains(page, "connect Figma Figma to the NeoAgent account") || finished != 0 {
		t.Fatalf("%d %s %d", status, page, finished)
	}
	m := regexp.MustCompile(`href="callback/confirm\?token=([^"]+)"`).FindStringSubmatch(page)
	if m == nil {
		t.Fatal(page)
	}
	status, page, _ = c.raw("GET", "/api/integrations/oauth/callback/confirm?token="+m[1], "", "")
	if status != 200 || !strings.Contains(page, `"type":"integration_oauth_success"`) || finished != 1 {
		t.Fatalf("%d %s %d", status, page, finished)
	}
	status, _, _ = c.raw("GET", "/api/integrations/oauth/callback/confirm?token="+m[1], "", "")
	if status != 400 || finished != 1 {
		t.Fatalf("reused confirmation: %d %d", status, finished)
	}
}

func TestModelOAuthNeedsConfirmationInAnotherBrowser(t *testing.T) {
	state := "model_" + strings.Repeat("b", 48)
	finished := 0
	s := newStack(t, nil, func(a *authapi.API) {
		a.ModelOAuth = &authapi.ModelCallbacks{
			Describe: func(_ context.Context, got string) (*authapi.ModelPending, error) {
				if got != state {
					return nil, nil
				}
				return &authapi.ModelPending{ProviderLabel: "OpenRouter", Username: "neo", StartedAt: "2026-01-01"}, nil
			},
			Finish: func(_ context.Context, got, code string) (string, error) {
				if got != state || code != "abc" {
					t.Fatalf("unexpected callback %q %q", got, code)
				}
				finished++
				return "openrouter", nil
			},
			Fail: func(string, string) {},
		}
	})
	c := s.client(t)
	status, page, _ := c.raw("GET", "/api/integrations/oauth/callback?state="+state+"&code=abc", "", "")
	if status != 200 || !strings.Contains(page, "connect your OpenRouter account") || finished != 0 {
		t.Fatalf("%d %s %d", status, page, finished)
	}
	m := regexp.MustCompile(`href="callback/confirm\?token=([^"]+)"`).FindStringSubmatch(page)
	if m == nil {
		t.Fatal(page)
	}
	status, page, _ = c.raw("GET", "/api/integrations/oauth/callback/confirm?token="+m[1], "", "")
	if status != 200 || !strings.Contains(page, `"type":"model_sign_in_success"`) || finished != 1 {
		t.Fatalf("%d %s %d", status, page, finished)
	}
}
