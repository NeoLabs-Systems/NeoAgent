package authapi

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/lockout"
	"github.com/NeoLabs-Systems/neolabs-go/passhash"
	"github.com/NeoLabs-Systems/neolabs-go/pwpolicy"
	"github.com/NeoLabs-Systems/neolabs-go/webauthnx"
)

func (a *API) status(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	count, err := a.Users.Count(ctx)
	if err != nil {
		a.fail(w, err)
		return
	}
	keyRequired, err := a.Users.SignupKeyRequired(ctx)
	if err != nil {
		a.fail(w, err)
		return
	}
	user, err := a.currentUser(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	out := map[string]any{
		"hasUser": count > 0,
		// Clients from before sign-up keys read registrationOpen; newer ones
		// read signupKeyRequired.
		"registrationOpen":  !keyRequired,
		"signupKeyRequired": keyRequired,
		"authenticated":     user != nil,
		"user":              nil,
		"email": map[string]any{
			"enabled":                    a.Cfg.Mail.Enabled,
			"configured":                 a.Cfg.Mail.Enabled,
			"signupConfirmationRequired": a.Cfg.Mail.RequireSignupConfirmation,
		},
		"providers": []any{},
	}
	if a.OAuth != nil {
		out["providers"] = a.OAuth.List(ctx, a.baseURL(r))
	}
	if user != nil {
		out["user"] = a.userPayload(ctx, user)
	}
	httpx.WriteJSON(w, 200, out)
}

// signupKeyCheck lets the sign-up form confirm a key before asking for account
// details. The key is only spent when the account is created.
func (a *API) signupKeyCheck(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	if _, err := a.Users.AssertSignupKeyUsable(r.Context(), b.str("key")); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"valid": true})
}

func normalizeEmail(v string) string { return strings.ToLower(strings.TrimSpace(v)) }

func isValidEmail(v string) bool {
	e := normalizeEmail(v)
	if len(e) > 320 || strings.Contains(e, "..") {
		return false
	}
	at := strings.Index(e, "@")
	if at <= 0 || strings.ContainsAny(e, " \t\r\n") || strings.Count(e, "@") != 1 {
		return false
	}
	domain := e[at+1:]
	dot := strings.LastIndex(domain, ".")
	return dot > 0 && dot < len(domain)-1
}

func (a *API) register(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	username := strings.TrimSpace(b.str("username"))
	password := b.str("password")
	email := normalizeEmail(b.str("email"))
	if username == "" || password == "" || email == "" {
		a.fail(w, &accounts.Error{Status: 400, Message: "Username, email, and password required", Code: "MISSING_FIELDS"})
		return
	}
	if !isValidEmail(email) {
		a.fail(w, &accounts.Error{Status: 400, Message: "A valid email is required", Code: "INVALID_EMAIL"})
		return
	}
	if err := a.Users.ValidateNewUsername(ctx, username); err != nil {
		a.fail(w, err)
		return
	}
	if err := accounts.ValidateNewPassword(password, pwpolicy.Context{Username: username, Email: email}); err != nil {
		a.fail(w, err)
		return
	}
	confirmationRequired := a.Cfg.Mail.RequireSignupConfirmation
	if confirmationRequired && !a.Cfg.Mail.Enabled {
		httpx.Error(w, 503, "Service email is not configured for account confirmation")
		return
	}
	hash, err := passhash.Hash(password, accounts.PasswordCost)
	if err != nil {
		a.fail(w, err)
		return
	}
	id, err := a.Users.Create(ctx, accounts.NewUser{
		Username: username, Email: email, PasswordHash: hash, SignupKey: b.str("signupKey"), NeedsConfirm: confirmationRequired,
	})
	if err != nil {
		a.fail(w, err)
		return
	}
	if confirmationRequired {
		token, _, err := a.Tokens.Create(ctx, id, accounts.TokenSignupConfirmation, email, a.tokenTTL())
		if err == nil {
			err = a.sendSignupConfirmation(ctx, username, email, token)
		}
		if err != nil {
			// An account nobody can confirm is removed and its key given back.
			if derr := a.Users.Discard(ctx, id); derr != nil {
				a.Log.Error("discarding unconfirmable account failed", "error", derr)
			}
			a.Log.Error("signup confirmation email failed", "error", err)
			httpx.Error(w, 503, "Could not send confirmation email")
			return
		}
		httpx.WriteJSON(w, 202, map[string]any{
			"success": false, "requiresEmailConfirmation": true,
			"message": "Check your email to confirm your NeoAgent account.",
		})
		return
	}
	now := time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
	nowStr := now
	a.establish(w, r, &accounts.User{
		ID: id, Username: username,
		Email:                nullString(email),
		EmailVerifiedAt:      nullString(nowStr),
		PasswordLoginEnabled: true,
		CreatedAt:            nullString(nowStr),
	}, 0)
}

func (a *API) login(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	// `username` also accepts the account email; both ignore case.
	account := strings.TrimSpace(b.str("username"))
	password := b.str("password")
	if account == "" || password == "" {
		httpx.ErrorCode(w, 400, "Username and password required", "MISSING_FIELDS")
		return
	}
	user, err := a.Users.ForSignIn(ctx, account)
	if err != nil {
		a.Log.Error("login lookup failed", "error", err)
		httpx.Error(w, 500, "Login failed")
		return
	}
	// A password is always checked, even for an unknown account, so response
	// time does not reveal which accounts exist.
	hash := a.dummyHash
	passwordLogin := user != nil && user.PasswordLoginEnabled
	if passwordLogin {
		hash = user.Password
	}
	if !passhash.Verify(hash, password) || !passwordLogin {
		httpx.ErrorCode(w, 401, "Invalid credentials", "INVALID_CREDENTIALS")
		return
	}
	if confirmationBlocksSignIn(a, user) {
		a.needsConfirmation(w)
		return
	}
	status, err := a.TwoFactor.Status(ctx, user.ID)
	if err != nil {
		a.Log.Error("login 2fa status failed", "error", err)
		httpx.Error(w, 500, "Login failed")
		return
	}
	if status.Enabled {
		a.startTwoFactorChallenge(w, r, user)
		return
	}
	a.touchLastLogin(r, user.ID)
	a.establish(w, r, user, 0)
}

func (a *API) login2FA(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	sess := a.session(r)
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	pendingID, ok := sess.Int64("pendingTwoFactorUserId")
	startedAt, _ := sess.Int64("pendingTwoFactorStartedAt")
	if !ok || startedAt == 0 || time.Now().UnixMilli()-startedAt > twoFactorWindow.Milliseconds() {
		httpx.Error(w, 401, "Two-factor challenge expired")
		return
	}
	code := b.str("code")
	if code == "" {
		httpx.Error(w, 400, "Two-factor code required")
		return
	}

	// A six-digit code can be guessed, so wrong tries are counted per account
	// (not per address) and back off, the same policy as the confirmations on
	// the account page.
	key := lockout.ConfirmKey(strconv.FormatInt(pendingID, 10)) + ":login"
	if err := a.Lockout.Check(ctx, key); err != nil {
		a.fail(w, err)
		return
	}
	if err := a.Lockout.Record(ctx, key, "second_factor"); err != nil {
		a.Log.Error("recording failure failed", "error", err)
		httpx.Error(w, 500, "Two-factor login failed")
		return
	}
	valid, err := a.TwoFactor.VerifyLoginCode(ctx, pendingID, code)
	if err != nil {
		a.Log.Error("2fa verification failed", "error", err)
		httpx.Error(w, 500, "Two-factor login failed")
		return
	}
	if !valid {
		httpx.Error(w, 401, "Invalid 2FA code")
		return
	}
	_ = a.Lockout.Clear(ctx, key, "second_factor")

	user, err := a.Users.ByID(ctx, pendingID)
	if err != nil {
		httpx.Error(w, 500, "Two-factor login failed")
		return
	}
	if user == nil {
		httpx.Error(w, 401, "User not found")
		return
	}
	if confirmationBlocksSignIn(a, user) {
		a.needsConfirmation(w)
		return
	}
	a.touchLastLogin(r, user.ID)
	a.establish(w, r, user, 0)
}

func (a *API) webauthnLoginOptions(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	options, pending, err := a.Passkeys.BeginLogin(r.Context(), r, b.str("username"))
	if err != nil {
		a.passkeyFail(w, err, "Security key sign-in could not be started.")
		return
	}
	a.session(r).Set("pendingWebAuthnLogin", pending)
	httpx.WriteJSON(w, 200, map[string]any{"options": options})
}

func (a *API) webauthnLoginVerify(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	sess := a.session(r)
	pending := readPending(sess, "pendingWebAuthnLogin")
	result, err := a.Passkeys.CompleteLogin(ctx, r, b.raw("response"), pending)
	if err != nil {
		a.passkeyFail(w, err, "Security key sign-in failed.")
		return
	}
	sess.Delete("pendingWebAuthnLogin")

	id, perr := strconv.ParseInt(result.UserID, 10, 64)
	if perr != nil {
		httpx.Error(w, 401, "User not found")
		return
	}
	user, err := a.Users.ByID(ctx, id)
	if err != nil {
		httpx.Error(w, 500, "Security key sign-in failed.")
		return
	}
	if user == nil {
		httpx.Error(w, 401, "User not found")
		return
	}
	if confirmationBlocksSignIn(a, user) {
		a.needsConfirmation(w)
		return
	}
	// A user-verified key already proves possession plus a PIN or biometric, so
	// it stands in for the second factor. A key that only confirmed presence
	// still needs the authenticator app code.
	if !result.UserVerified {
		st, err := a.TwoFactor.Status(ctx, user.ID)
		if err != nil {
			httpx.Error(w, 500, "Security key sign-in failed.")
			return
		}
		if st.Enabled {
			a.startTwoFactorChallenge(w, r, user)
			return
		}
	}
	a.touchLastLogin(r, user.ID)
	a.establish(w, r, user, 0)
}

// passkeyFail mirrors sendWebAuthnError: 5xx hides the cause behind a fixed text.
func (a *API) passkeyFail(w http.ResponseWriter, err error, fallback string) {
	if we, ok := err.(*webauthnx.Error); ok {
		httpx.Error(w, we.Status, we.Message)
		return
	}
	a.Log.Error("webauthn error", "error", err)
	httpx.Error(w, 500, fallback)
}

func readPending(sess interface{ Get(string) (any, bool) }, key string) *webauthnx.Pending {
	v, ok := sess.Get(key)
	if !ok {
		return nil
	}
	if p, ok := v.(*webauthnx.Pending); ok {
		return p
	}
	raw, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	var p webauthnx.Pending
	if json.Unmarshal(raw, &p) != nil {
		return nil
	}
	return &p
}

func (a *API) logout(w http.ResponseWriter, r *http.Request) {
	a.session(r).Destroy()
	http.SetCookie(w, &http.Cookie{
		Name: "neoagent.sid", Value: "", Path: "/", HttpOnly: true,
		SameSite: http.SameSiteLaxMode, Secure: a.Cfg.SecureCookie,
		Expires: time.Unix(0, 0), MaxAge: -1,
	})
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

func (a *API) me(w http.ResponseWriter, r *http.Request) {
	user, err := a.currentUser(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	if user == nil {
		httpx.Error(w, 401, "Not authenticated")
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"user": a.userPayload(r.Context(), user)})
}

func (a *API) onboardingComplete(w http.ResponseWriter, r *http.Request) {
	user, err := a.currentUser(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	if user == nil {
		httpx.Error(w, 401, "Not authenticated")
		return
	}
	if err := a.Users.CompleteOnboarding(r.Context(), user.ID); err != nil {
		a.Log.Error("onboarding update failed", "error", err)
		httpx.Error(w, 500, "Failed to update onboarding status")
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}
