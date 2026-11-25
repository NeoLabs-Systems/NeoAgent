// Package authapi serves NeoAgent's sign-in and account-security routes:
// /api/auth/* (status, register, login, two-factor, passkey login, logout) and
// the account routes for password, two-factor, security keys and sessions.
package authapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/lockout"
	"github.com/NeoLabs-Systems/neolabs-go/oauthlogin"
	"github.com/NeoLabs-Systems/neolabs-go/pairing"
	"github.com/NeoLabs-Systems/neolabs-go/passhash"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/qrlogin"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/servicemail"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
	"github.com/NeoLabs-Systems/neolabs-go/webauthnx"
)

const (
	bodyLimit          = 10 << 20
	twoFactorWindow    = 10 * time.Minute
	wearableSessionAge = 90 * 24 * time.Hour
	fifteenMinutes     = 15 * time.Minute
)

// API holds everything the routes need.
type API struct {
	Cfg       config.Config
	Users     *accounts.Repo
	TwoFactor *accounts.TwoFactor
	Passkeys  *webauthnx.Service
	Records   *accounts.SessionRecords
	Sessions  *sessionx.Manager
	Lockout   lockout.Store
	Log       *slog.Logger

	Mail             servicemail.Mailer // nil leaves email unsent
	Tokens           servicemail.Tokens
	ResetLimiter     *servicemail.AttemptLimiter
	QR               *qrlogin.Store
	Pairing          *pairing.Store
	OAuth            *oauthlogin.Engine
	IntegrationOAuth *IntegrationCallbacks
	ModelOAuth       *ModelCallbacks

	dummyHash string // compared when no account matches, so timing does not reveal it

	authLimiter, webauthnLimiter, accountLimiter, signupKeyLimiter *ratelimit.Limiter
	qrChallengeLimiter, qrPollLimiter, qrClaimLimiter, pairLimiter *ratelimit.Limiter
	passwordResetLimiter                                           *ratelimit.Limiter
	held                                                           heldCallbacks
}

func (a *API) limiter(max int, message string) *ratelimit.Limiter {
	return ratelimit.New(ratelimit.Config{
		Window:  fifteenMinutes,
		Max:     max,
		Message: map[string]string{"error": message},
		Key:     func(r *http.Request) string { return httpx.ClientIP(r, a.Cfg.TrustProxy) },
	})
}

// Init prepares limiters and the timing-equalizing hash. Call once.
func (a *API) Init() error {
	h, err := passhash.Hash("neoagent-timing-equalizer", accounts.PasswordCost)
	if err != nil {
		return err
	}
	a.dummyHash = h
	a.authLimiter = a.limiter(20, "Too many attempts, try again later")
	a.webauthnLimiter = a.limiter(40, "Too many security key attempts, try again later")
	a.accountLimiter = a.limiter(30, "Too many account security attempts, try again later")
	a.signupKeyLimiter = a.limiter(20, "Too many sign-up key attempts, try again later")
	// Showing a sign-in QR code is not a credential attempt, so it gets its own
	// budget. A visible code rotates every two minutes; its status checks are held
	// open up to 25 seconds each, or come every five seconds from older apps.
	a.qrChallengeLimiter = a.limiter(60, "Too many QR login requests, try again shortly")
	a.qrPollLimiter = a.limiter(400, "Too many QR login status checks, try again shortly")
	a.qrClaimLimiter = a.limiter(40, "Too many QR login completion attempts, try again shortly")
	a.pairLimiter = a.limiter(30, "Too many pairing attempts, try again shortly")
	a.passwordResetLimiter = a.limiter(8, "Too many password reset attempts, try again later")
	if a.ResetLimiter == nil {
		a.ResetLimiter = &servicemail.AttemptLimiter{}
	}
	return nil
}

// IsAdmin reports whether the request's session belongs to an administrator.
// It reads the flag fresh, so revoking admin takes effect at once.
func (a *API) IsAdmin(r *http.Request) bool {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return false
	}
	id, ok := sess.Int64("userId")
	return ok && a.Users.IsAdmin(r.Context(), id)
}

// Routes registers every route on mux.
func (a *API) Routes(mux *http.ServeMux) {
	h := func(l *ratelimit.Limiter, fn http.HandlerFunc) http.Handler {
		return l.Middleware(fn)
	}
	secure := func(next http.Handler) http.Handler { return a.requireSessionTransport(next) }
	authed := func(next http.HandlerFunc) http.Handler { return a.requireAuth(next) }

	mux.HandleFunc("GET /api/auth/status", a.status)
	if a.OAuth != nil {
		mux.HandleFunc("GET /api/auth/providers", a.providersList)
		mux.Handle("POST /api/auth/providers/{provider}/begin", h(a.authLimiter, secure(http.HandlerFunc(a.providerBegin)).ServeHTTP))
		mux.Handle("POST /api/auth/providers/register", h(a.authLimiter, secure(http.HandlerFunc(a.providerRegister)).ServeHTTP))
		mux.HandleFunc("GET /api/auth/providers/complete", a.providerComplete)
	} else {
		mux.HandleFunc("GET /api/auth/providers", func(w http.ResponseWriter, r *http.Request) {
			httpx.WriteJSON(w, 200, map[string]any{"providers": []any{}})
		})
	}
	mux.HandleFunc("GET /api/integrations/oauth/callback", a.oauthCallback)
	mux.HandleFunc("GET /api/integrations/oauth/callback/confirm", a.oauthCallbackConfirm)
	mux.HandleFunc("GET /api/auth/email/confirm", a.emailConfirm)
	mux.Handle("POST /api/auth/password/forgot", h(a.authLimiter, a.passwordForgot))
	mux.HandleFunc("GET /api/auth/password/reset", a.passwordResetPage)
	mux.Handle("POST /api/auth/password/reset", h(a.passwordResetLimiter, a.passwordResetSubmit))
	mux.Handle("POST /api/auth/qr-login/challenge", h(a.qrChallengeLimiter, a.qrChallenge))
	mux.Handle("POST /api/auth/qr-login/challenge/{id}/status", h(a.qrPollLimiter, a.qrStatus))
	mux.Handle("POST /api/auth/qr-login/challenge/{id}/cancel", h(a.qrPollLimiter, a.qrCancel))
	mux.Handle("POST /api/auth/qr-login/challenge/{id}/claim", h(a.qrClaimLimiter, secure(http.HandlerFunc(a.qrClaim)).ServeHTTP))
	mux.Handle("POST /api/auth/pair", h(a.pairLimiter, secure(http.HandlerFunc(a.pair)).ServeHTTP))
	mux.Handle("POST /api/auth/signup-key/check", h(a.signupKeyLimiter, a.signupKeyCheck))
	mux.Handle("POST /api/auth/register", h(a.authLimiter, secure(http.HandlerFunc(a.register)).ServeHTTP))
	mux.Handle("POST /api/auth/login", h(a.authLimiter, secure(http.HandlerFunc(a.login)).ServeHTTP))
	mux.Handle("POST /api/auth/login/2fa", h(a.authLimiter, secure(http.HandlerFunc(a.login2FA)).ServeHTTP))
	mux.Handle("POST /api/auth/webauthn/login/options", h(a.webauthnLimiter, secure(http.HandlerFunc(a.webauthnLoginOptions)).ServeHTTP))
	mux.Handle("POST /api/auth/webauthn/login/verify", h(a.webauthnLimiter, secure(http.HandlerFunc(a.webauthnLoginVerify)).ServeHTTP))
	mux.HandleFunc("POST /api/auth/logout", a.logout)
	mux.HandleFunc("GET /api/auth/me", a.me)
	mux.HandleFunc("POST /api/auth/onboarding/complete", a.onboardingComplete)

	acct := func(l *ratelimit.Limiter, fn http.HandlerFunc) http.Handler {
		if l == nil {
			return authed(fn)
		}
		return authed(l.Middleware(fn).ServeHTTP)
	}
	mux.Handle("GET /api/account", acct(nil, a.accountGet))
	mux.Handle("PUT /api/account/display-name", acct(a.accountLimiter, a.accountDisplayName))
	mux.Handle("PUT /api/account/password", acct(a.accountLimiter, a.accountPassword))
	mux.Handle("POST /api/account/2fa/setup", acct(a.accountLimiter, a.twoFactorSetup))
	mux.Handle("POST /api/account/2fa/enable", acct(a.accountLimiter, a.twoFactorEnable))
	mux.Handle("POST /api/account/2fa/disable", acct(a.accountLimiter, a.twoFactorDisable))
	mux.Handle("POST /api/account/2fa/recovery-codes", acct(a.accountLimiter, a.twoFactorRecoveryCodes))
	mux.Handle("GET /api/account/security-keys", acct(nil, a.securityKeysList))
	mux.Handle("POST /api/account/security-keys/register/options", acct(a.accountLimiter, a.securityKeyRegisterOptions))
	mux.Handle("POST /api/account/security-keys/register/verify", acct(a.accountLimiter, a.securityKeyRegisterVerify))
	mux.Handle("PUT /api/account/security-keys/{id}", acct(a.accountLimiter, a.securityKeyRename))
	mux.Handle("DELETE /api/account/security-keys/{id}", acct(a.accountLimiter, a.securityKeyDelete))
	mux.Handle("PUT /api/account/email", acct(a.accountLimiter, a.accountEmail))
	mux.Handle("POST /api/account/qr-login/resolve", acct(a.accountLimiter, a.qrResolve))
	mux.Handle("POST /api/account/qr-login/decline", acct(a.accountLimiter, a.qrDecline))
	mux.Handle("POST /api/account/qr-login/approve", acct(a.accountLimiter, a.qrApprove))
	mux.Handle("POST /api/account/pairing", acct(a.accountLimiter, a.pairingStart))
	mux.Handle("GET /api/account/pairing/{code}", acct(nil, a.pairingStatus))
	if a.OAuth != nil {
		mux.Handle("DELETE /api/account/providers/{id}", acct(a.accountLimiter, a.providerUnlink))
	}
	mux.Handle("GET /api/account/sessions", acct(nil, a.sessionsList))
	mux.Handle("DELETE /api/account/sessions/{id}", acct(a.accountLimiter, a.sessionRevoke))
}

// ---- request and response helpers ------------------------------------------

// body is a loosely typed JSON object, read like Express' `req.body?.field`.
type body map[string]any

func readBody(r *http.Request) (body, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return body{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, &accounts.Error{Status: 413, Message: "Request body too large"}
	}
	if len(bytes.TrimSpace(raw)) == 0 {
		return body{}, nil
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var v any
	if err := dec.Decode(&v); err != nil {
		return nil, &accounts.Error{Status: 400, Message: "Invalid JSON body"}
	}
	if m, ok := v.(map[string]any); ok {
		return body(m), nil
	}
	return body{}, nil
}

// str is String(value || ”) for a body field.
func (b body) str(key string) string {
	switch v := b[key].(type) {
	case nil:
		return ""
	case string:
		return v
	case json.Number:
		return v.String()
	case bool:
		return strconv.FormatBool(v)
	}
	return "[object Object]"
}

func (b body) raw(key string) json.RawMessage {
	v, ok := b[key]
	if !ok || v == nil {
		return nil
	}
	out, _ := json.Marshal(v)
	return out
}

func (a *API) fail(w http.ResponseWriter, err error) {
	var locked *lockout.LockedError
	var ae *accounts.Error
	var we *webauthnx.Error
	switch {
	case errors.As(err, &locked):
		w.Header().Set("Retry-After", strconv.Itoa(locked.RetryAfter))
		httpx.WriteJSON(w, 429, map[string]any{"error": locked.Error(), "code": locked.Code(), "retryAfter": locked.RetryAfter})
	case errors.As(err, &ae):
		if ae.Status >= 500 {
			a.Log.Error("account route failed", "error", ae.Message)
			httpx.WriteJSON(w, ae.Status, map[string]any{"error": publicerr.Sanitize(ae.Message, "", "")})
			return
		}
		out := map[string]any{"error": ae.Message}
		if ae.Code != "" {
			out["code"] = ae.Code
		}
		httpx.WriteJSON(w, ae.Status, out)
	case errors.As(err, &we):
		httpx.WriteJSON(w, we.Status, map[string]any{"error": we.Message})
	default:
		a.Log.Error("route failed", "error", err)
		httpx.WriteJSON(w, 500, map[string]any{"error": "Something went wrong. Please try again."})
	}
}

func (a *API) session(r *http.Request) *sessionx.Session { return sessionx.FromContext(r.Context()) }

// requireSessionTransport refuses to "sign in" over plain http when the cookie
// is Secure: the browser would never send it back and the account would be
// logged out again on the next request.
func (a *API) requireSessionTransport(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !a.Cfg.SecureCookie || a.Sessions.IsSecureRequest(r) {
			next.ServeHTTP(w, r)
			return
		}
		httpsURL := "https://" + r.Host
		if strings.HasPrefix(a.Cfg.PublicURL, "https://") {
			if u, err := url.Parse(a.Cfg.PublicURL); err == nil {
				httpsURL = u.Scheme + "://" + u.Host
			}
		}
		httpx.WriteJSON(w, 400, map[string]any{
			"error":    "Sign-in needs a secure connection. Open " + httpsURL + " instead.",
			"code":     "INSECURE_TRANSPORT",
			"httpsUrl": httpsURL,
		})
	})
}

// requireAuth answers 401 JSON unless the session belongs to an account.
func (a *API) requireAuth(next http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := a.session(r).Int64("userId"); !ok {
			httpx.Error(w, 401, "Unauthorized")
			return
		}
		next(w, r)
	})
}

func (a *API) sessionUserID(r *http.Request) int64 {
	id, _ := a.session(r).Int64("userId")
	return id
}

// currentUser loads the signed-in account, dropping a session whose account is gone.
func (a *API) currentUser(r *http.Request) (*accounts.User, error) {
	sess := a.session(r)
	id, ok := sess.Int64("userId")
	if !ok {
		return nil, nil
	}
	u, err := a.Users.ByID(r.Context(), id)
	if err != nil {
		return nil, err
	}
	if u == nil {
		sess.Destroy()
	}
	return u, nil
}

// UserPayload is the account object clients read after sign-in.
type UserPayload struct {
	ID                     int64   `json:"id"`
	Username               string  `json:"username"`
	DisplayName            *string `json:"displayName"`
	DisplayNameSnake       *string `json:"display_name"`
	Email                  *string `json:"email"`
	EmailVerifiedAt        *string `json:"emailVerifiedAt"`
	CreatedAt              *string `json:"createdAt"`
	LastLogin              *string `json:"lastLogin"`
	HasPassword            bool    `json:"hasPassword"`
	HasCompletedOnboarding bool    `json:"hasCompletedOnboarding"`
	IsAdmin                bool    `json:"isAdmin"`
	SharesUsageData        bool    `json:"sharesUsageData"`
}

func ptr(valid bool, s string) *string {
	if !valid || s == "" {
		return nil
	}
	return &s
}

func (a *API) userPayload(ctx context.Context, u *accounts.User) UserPayload {
	dn := ptr(u.DisplayName.Valid, u.DisplayName.String)
	return UserPayload{
		ID: u.ID, Username: u.Username,
		DisplayName: dn, DisplayNameSnake: dn,
		Email:                  ptr(u.Email.Valid, u.Email.String),
		EmailVerifiedAt:        ptr(u.EmailVerifiedAt.Valid, u.EmailVerifiedAt.String),
		CreatedAt:              ptr(u.CreatedAt.Valid, u.CreatedAt.String),
		LastLogin:              ptr(u.LastLogin.Valid, u.LastLogin.String),
		HasPassword:            u.PasswordLoginEnabled,
		HasCompletedOnboarding: u.HasCompletedOnboarding,
		IsAdmin:                a.Users.IsAdmin(ctx, u.ID),
		SharesUsageData:        a.Users.DataSharing(ctx, u.ID).Enabled,
	}
}

// establish starts a signed-in session: a fresh id and empty state (so nothing
// from before the login survives), then the sign-in is recorded.
func (a *API) establish(w http.ResponseWriter, r *http.Request, u *accounts.User, maxAge time.Duration) {
	sess := a.session(r)
	sess.Regenerate()
	sess.Set("userId", u.ID)
	sess.Set("username", u.Username)
	if maxAge > 0 {
		sess.SetMaxAge(maxAge)
	}
	expires := time.Now().Add(a.Sessions.Lifetime(sess))
	info, err := a.Records.Record(r.Context(), sess.ID(), r, u.ID, expires, true)
	if err != nil {
		a.Log.Warn("recording session failed", "error", err)
	} else if info.Unusual {
		a.async("unusual sign-in notice", func(ctx context.Context) error { return a.sendUnusualLoginNotice(ctx, u, info) })
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true, "redirect": "/app", "user": a.userPayload(r.Context(), u)})
}

func (a *API) startTwoFactorChallenge(w http.ResponseWriter, r *http.Request, u *accounts.User) {
	sess := a.session(r)
	sess.Regenerate()
	sess.Set("pendingTwoFactorUserId", u.ID)
	sess.Set("pendingTwoFactorUsername", u.Username)
	sess.Set("pendingTwoFactorStartedAt", time.Now().UnixMilli())
	// Only the name: nothing else about the account before the second factor.
	httpx.WriteJSON(w, 200, map[string]any{"success": false, "requiresTwoFactor": true, "user": map[string]any{"username": u.Username}})
}

func (a *API) touchLastLogin(r *http.Request, id int64) {
	if err := a.Users.TouchLastLogin(r.Context(), id); err != nil {
		a.Log.Warn("last_login update failed", "error", err)
	}
}

func confirmationBlocksSignIn(a *API, u *accounts.User) bool {
	return a.Cfg.Mail.RequireSignupConfirmation && u.Email.Valid && u.Email.String != "" && !u.EmailVerifiedAt.Valid
}

func (a *API) needsConfirmation(w http.ResponseWriter) {
	httpx.WriteJSON(w, 403, map[string]any{"error": "Email confirmation required before sign in", "requiresEmailConfirmation": true})
}

func timeNowPlus(a *API, r *http.Request) time.Time {
	return time.Now().Add(a.Sessions.Lifetime(a.session(r)))
}
