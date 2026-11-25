package authapi

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

const forgotMinimumLatency = 350 * time.Millisecond

func (a *API) emailConfirm(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimSpace(r.URL.Query().Get("token"))
	if token == "" {
		sendEmailConfirmationPage(w, false, "Confirmation link missing", "Open the full confirmation link from your NeoAgent email.")
		return
	}
	res, err := a.Users.ConsumeEmailToken(r.Context(), a.Tokens, token)
	if err != nil {
		msg := err.Error()
		if msg == "" {
			msg = "This confirmation link is invalid or expired."
		}
		sendEmailConfirmationPage(w, false, "Could not confirm email", msg)
		return
	}
	if res.Type == accounts.TokenEmailChange {
		a.async("email changed notice", func(ctx context.Context) error {
			return a.sendEmailChangedNotice(ctx, res.Username, res.PreviousEmail, res.Email)
		})
	}
	sendEmailConfirmationPage(w, true, "Email confirmed", "Your NeoAgent email is confirmed. You can return to the app and sign in.")
}

// passwordForgot always answers the same way after the same minimum time, so
// neither the text nor the latency reveals whether an account exists.
func (a *API) passwordForgot(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	b, _ := readBody(r)
	finish := func() {
		if wait := forgotMinimumLatency - time.Since(started); wait > 0 {
			time.Sleep(wait)
		}
		httpx.WriteJSON(w, 200, map[string]any{"success": true, "message": "If that account has a confirmed email, NeoAgent will send a password reset link."})
	}
	if !a.Cfg.Mail.Enabled {
		finish()
		return
	}
	ctx := r.Context()
	user, err := a.Users.ForPasswordReset(ctx, b.str("account"))
	if err != nil {
		a.Log.Error("forgot password lookup failed", "error", err)
		finish()
		return
	}
	if user != nil && user.Email != "" {
		token, _, err := a.Tokens.Create(ctx, user.UserID, accounts.TokenPasswordReset, user.Email, a.tokenTTL())
		if err == nil {
			err = a.sendPasswordResetEmail(ctx, user.Username, user.Email, token)
		}
		if err != nil {
			a.Log.Error("forgot password failed", "error", err)
		}
	}
	finish()
}

func (a *API) tokenTTL() time.Duration {
	return time.Duration(a.Cfg.Mail.TokenTTLHours * float64(time.Hour))
}

func (a *API) passwordResetPage(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimSpace(r.URL.Query().Get("token"))
	if token == "" {
		sendPasswordResetPage(w, "", "Open the full password reset link from your NeoAgent email.", false)
		return
	}
	sendPasswordResetPage(w, token, "", false)
}

// formOrJSON reads the reset form, which a browser posts url-encoded.
func formOrJSON(r *http.Request) (body, error) {
	if strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return readBody(r)
	}
	r.Body = http.MaxBytesReader(nil, r.Body, bodyLimit)
	if err := r.ParseForm(); err != nil {
		return body{}, nil
	}
	b := body{}
	for k, v := range r.PostForm {
		if len(v) > 0 {
			b[k] = v[0]
		}
	}
	return b, nil
}

func (a *API) passwordResetSubmit(w http.ResponseWriter, r *http.Request) {
	b, err := formOrJSON(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	token := strings.TrimSpace(b.str("token"))
	password, confirm := b.str("password"), b.str("confirmPassword")
	if token == "" {
		sendPasswordResetPage(w, token, "Open the full password reset link from your NeoAgent email.", false)
		return
	}
	if password != confirm {
		sendPasswordResetPage(w, token, "Passwords do not match.", false)
		return
	}
	res, err := a.Users.ConsumePasswordReset(r.Context(), a.Tokens, a.ResetLimiter, token, password)
	if err != nil {
		msg := err.Error()
		if msg == "" {
			msg = "This password reset link is invalid or expired."
		}
		if _, ok := err.(*accounts.Error); !ok {
			a.Log.Error("password reset failed", "error", err)
			msg = "This password reset link is invalid or expired."
		}
		sendPasswordResetPage(w, token, msg, false)
		return
	}
	if _, err := a.Records.RevokeAll(r.Context(), res.UserID, ""); err != nil {
		a.Log.Warn("revoking sessions after reset failed", "error", err)
	}
	a.async("password changed notice", func(ctx context.Context) error {
		return a.sendPasswordChangedNotice(ctx, res.Username, res.Email)
	})
	sendPasswordResetPage(w, "", "", true)
}

// accountEmail changes the account's email, with a confirmation round trip
// when the server requires one.
func (a *API) accountEmail(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	uid := a.sessionUserID(r)
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	email := normalizeEmail(b.str("email"))
	if !isValidEmail(email) {
		a.fail(w, &accounts.Error{Status: 400, Message: "A valid email is required"})
		return
	}
	if err := a.TwoFactor.VerifyCurrentPassword(ctx, uid, b.str("currentPassword")); err != nil {
		a.fail(w, err)
		return
	}
	user, err := a.Users.ByID(ctx, uid)
	if err != nil {
		a.fail(w, err)
		return
	}
	if user == nil {
		httpx.Error(w, 404, "User not found")
		return
	}
	previous := user.Email.String
	if previous != "" && strings.ToLower(previous) == email {
		a.accountPayload(w, r)
		return
	}
	if used, err := a.Users.EmailUsedByOther(ctx, email, uid); err != nil {
		a.fail(w, err)
		return
	} else if used {
		httpx.Error(w, 409, "Email is already in use")
		return
	}

	if a.Cfg.Mail.RequireChangeConfirmation {
		if !a.Cfg.Mail.Enabled {
			httpx.Error(w, 503, "Service email is not configured for account confirmation")
			return
		}
		token, _, err := a.Tokens.Create(ctx, uid, accounts.TokenEmailChange, email, a.tokenTTL())
		if err == nil {
			err = a.sendEmailChangeConfirmation(ctx, user.Username, email, token)
		}
		if err != nil {
			a.fail(w, err)
			return
		}
		a.async("email change requested notice", func(ctx context.Context) error {
			return a.sendEmailChangeRequestedNotice(ctx, user.Username, previous, email)
		})
		a.accountPayloadWith(w, r, map[string]any{"emailChangePending": true, "pendingEmail": email})
		return
	}
	if err := a.Users.SetEmail(ctx, uid, email); err != nil {
		a.fail(w, err)
		return
	}
	a.async("email changed notice", func(ctx context.Context) error {
		return a.sendEmailChangedNotice(ctx, user.Username, previous, email)
	})
	a.accountPayload(w, r)
}
