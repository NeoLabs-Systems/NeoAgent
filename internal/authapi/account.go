package authapi

import (
	"context"
	"database/sql"
	"net/http"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/passhash"
	"github.com/NeoLabs-Systems/neolabs-go/pwpolicy"
)

func nullString(s string) sql.NullString { return sql.NullString{String: s, Valid: s != ""} }

// accountPayload is what the account page loads. Opening it also refreshes the
// record of the current session.
func (a *API) accountPayload(w http.ResponseWriter, r *http.Request) {
	a.accountPayloadWith(w, r, nil)
}

// accountPayloadWith is accountPayload plus extra top-level fields.
func (a *API) accountPayloadWith(w http.ResponseWriter, r *http.Request, extra map[string]any) {
	ctx := r.Context()
	uid := a.sessionUserID(r)
	sess := a.session(r)
	expires := timeNowPlus(a, r)
	if _, err := a.Records.Record(ctx, sess.ID(), r, uid, expires, false); err != nil {
		a.Log.Warn("recording session failed", "error", err)
	}
	user, err := a.Users.ByID(ctx, uid)
	if err != nil {
		a.fail(w, err)
		return
	}
	var userOut any
	if user != nil {
		userOut = map[string]any{
			"id": user.ID, "username": user.Username,
			"display_name":      ptr(user.DisplayName.Valid, user.DisplayName.String),
			"email":             ptr(user.Email.Valid, user.Email.String),
			"email_verified_at": ptr(user.EmailVerifiedAt.Valid, user.EmailVerifiedAt.String),
			"created_at":        ptr(user.CreatedAt.Valid, user.CreatedAt.String),
			"last_login":        ptr(user.LastLogin.Valid, user.LastLogin.String),
			"hasPassword":       user.PasswordLoginEnabled,
			"isAdmin":           a.Users.IsAdmin(ctx, user.ID),
		}
	}
	twoFactor, err := a.TwoFactor.Status(ctx, uid)
	if err != nil {
		a.fail(w, err)
		return
	}
	keys, err := a.Passkeys.List(ctx, strconv.FormatInt(uid, 10))
	if err != nil {
		a.fail(w, err)
		return
	}
	var providers any = []any{}
	if a.OAuth != nil {
		list, err := a.OAuth.ListForUser(ctx, uid)
		if err != nil {
			a.fail(w, err)
			return
		}
		providers = list
	}
	out := map[string]any{
		"user":          userOut,
		"twoFactor":     twoFactor,
		"securityKeys":  keys,
		"authProviders": providers,
		"dataSharing":   a.Users.DataSharing(ctx, uid),
	}
	for k, v := range extra {
		out[k] = v
	}
	httpx.WriteJSON(w, 200, out)
}

func (a *API) accountGet(w http.ResponseWriter, r *http.Request) { a.accountPayload(w, r) }

func (a *API) accountDisplayName(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	name := strings.TrimSpace(b.str("displayName"))
	if len([]rune(name)) > 64 {
		a.fail(w, &accounts.Error{Status: 400, Message: "Display name must be 64 characters or fewer."})
		return
	}
	if err := a.Users.SetDisplayName(r.Context(), a.sessionUserID(r), name); err != nil {
		a.fail(w, err)
		return
	}
	a.accountPayload(w, r)
}

func (a *API) accountPassword(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	uid := a.sessionUserID(r)
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	current, next := b.str("currentPassword"), b.str("newPassword")
	user, err := a.Users.ByID(ctx, uid)
	if err != nil {
		a.fail(w, err)
		return
	}
	var pctx pwpolicy.Context
	if user != nil {
		pctx = pwpolicy.Context{Username: user.Username, Email: user.Email.String}
	}
	strength := pwpolicy.Evaluate(next, pctx)
	if !strength.HasMinimumLength {
		httpx.Error(w, 400, "Password min 8 chars")
		return
	}
	if !strength.IsAcceptable {
		httpx.Error(w, 400, pwpolicy.Error(strength))
		return
	}
	if user == nil {
		httpx.Error(w, 404, "User not found")
		return
	}
	if user.PasswordLoginEnabled {
		if err := a.TwoFactor.VerifyCurrentPassword(ctx, uid, current); err != nil {
			a.fail(w, err)
			return
		}
	}
	hash, err := passhash.Hash(next, accounts.PasswordCost)
	if err != nil {
		a.fail(w, err)
		return
	}
	if err := a.Users.SetPassword(ctx, uid, hash); err != nil {
		a.fail(w, err)
		return
	}
	// A new password ends every other sign-in of the account: whoever knew the
	// old one must not stay signed in.
	if _, err := a.Records.RevokeAll(ctx, uid, a.session(r).ID()); err != nil {
		a.Log.Warn("revoking other sessions failed", "error", err)
	}
	a.async("password changed notice", func(ctx context.Context) error {
		return a.sendPasswordChangedNotice(ctx, user.Username, user.Email.String)
	})
	a.accountPayload(w, r)
}

func (a *API) twoFactorSetup(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	out, err := a.TwoFactor.BeginSetup(r.Context(), a.sessionUserID(r), b.str("currentPassword"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (a *API) twoFactorEnable(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	out, err := a.TwoFactor.Enable(r.Context(), a.sessionUserID(r), b.str("code"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (a *API) twoFactorDisable(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	out, err := a.TwoFactor.Disable(r.Context(), a.sessionUserID(r), b.str("currentPassword"), b.str("code"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (a *API) twoFactorRecoveryCodes(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	out, err := a.TwoFactor.RegenerateRecoveryCodes(r.Context(), a.sessionUserID(r), b.str("currentPassword"), b.str("code"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (a *API) securityKeysList(w http.ResponseWriter, r *http.Request) {
	keys, err := a.Passkeys.List(r.Context(), strconv.FormatInt(a.sessionUserID(r), 10))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"securityKeys": keys})
}

func (a *API) securityKeyRegisterOptions(w http.ResponseWriter, r *http.Request) {
	options, pending, err := a.Passkeys.BeginRegistration(r.Context(), r, strconv.FormatInt(a.sessionUserID(r), 10))
	if err != nil {
		a.fail(w, err)
		return
	}
	a.session(r).Set("pendingWebAuthnRegistration", pending)
	httpx.WriteJSON(w, 200, map[string]any{"options": options})
}

func (a *API) securityKeyRegisterVerify(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	uid := strconv.FormatInt(a.sessionUserID(r), 10)
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	sess := a.session(r)
	pending := readPending(sess, "pendingWebAuthnRegistration")
	if err := a.Passkeys.CompleteRegistration(ctx, r, uid, b.raw("response"), b.str("label"), pending); err != nil {
		a.fail(w, err)
		return
	}
	sess.Delete("pendingWebAuthnRegistration")
	keys, err := a.Passkeys.List(ctx, uid)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true, "credentials": keys})
}

func (a *API) keyRowID(r *http.Request) int64 {
	n, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	return n
}

func (a *API) securityKeyRename(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	keys, err := a.Passkeys.Rename(r.Context(), strconv.FormatInt(a.sessionUserID(r), 10), a.keyRowID(r), b.str("label"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true, "credentials": keys})
}

func (a *API) securityKeyDelete(w http.ResponseWriter, r *http.Request) {
	keys, err := a.Passkeys.Delete(r.Context(), strconv.FormatInt(a.sessionUserID(r), 10), a.keyRowID(r))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true, "credentials": keys})
}

func (a *API) sessionsList(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	uid := a.sessionUserID(r)
	sess := a.session(r)
	_, _ = a.Records.Record(ctx, sess.ID(), r, uid, timeNowPlus(a, r), false)
	list, err := a.Records.List(ctx, uid, sess.ID())
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"sessions": list})
}

func (a *API) sessionRevoke(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	uid := a.sessionUserID(r)
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		httpx.Error(w, 400, "Invalid session id")
		return
	}
	sess := a.session(r)
	if err := a.Records.Revoke(ctx, uid, id, sess.ID()); err != nil {
		a.fail(w, err)
		return
	}
	list, err := a.Records.List(ctx, uid, sess.ID())
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true, "sessions": list})
}
