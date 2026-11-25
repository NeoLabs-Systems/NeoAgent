package authapi

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/oauthlogin"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const (
	boundStateTTL   = 30 * time.Minute
	heldCallbackTTL = 10 * time.Minute
	sessionStates   = "oauthStates"
)

var authStateRE = regexp.MustCompile(`^auth_[a-f0-9]{48}$`)
var integrationStateRE = regexp.MustCompile(`^[a-f0-9]{48}$`)
var modelStateRE = regexp.MustCompile(`^model_[a-f0-9]{48}$`)

type IntegrationPending struct{ ProviderLabel, AppLabel, Username, StartedAt string }
type IntegrationResult struct {
	Provider, AppID, AccountEmail string
	ConnectionID                  *int64
}
type ModelPending struct{ ProviderLabel, Username, StartedAt string }
type ModelCallbacks struct {
	Describe func(context.Context, string) (*ModelPending, error)
	Finish   func(context.Context, string, string) (string, error)
	Fail     func(string, string)
}
type IntegrationCallbacks struct {
	Describe func(context.Context, string) (*IntegrationPending, error)
	Finish   func(context.Context, string, string) (*IntegrationResult, error)
}

// BindOAuthState ties an integration authorization to its initiating session.
func BindOAuthState(sess *sessionx.Session, state string) {
	if sess != nil {
		bindState(sess, state)
	}
}

// ---- tying a flow to the browser that started it ----------------------------
//
// An OAuth state is a bearer handle: whoever finishes or polls it gets the
// result. The starting client's session records the state. When the provider
// redirects back into that same browser the callback finishes directly; native
// apps finish in the system browser, which has another session, so the callback
// is held until the person there confirms it. A link someone else started can
// therefore not complete silently in a victim's browser.

func bindState(sess *sessionx.Session, state string) {
	now := time.Now().UnixMilli()
	bound := map[string]any{}
	if v, ok := sess.Get(sessionStates); ok {
		if m, ok := v.(map[string]any); ok {
			for k, started := range m {
				if ms, ok := toInt64(started); ok && now-ms < boundStateTTL.Milliseconds() {
					bound[k] = ms
				}
			}
		}
	}
	bound[state] = now
	sess.Set(sessionStates, bound)
}

func toInt64(v any) (int64, bool) {
	switch n := v.(type) {
	case int64:
		return n, true
	case float64:
		return int64(n), true
	case json.Number:
		i, err := n.Int64()
		return i, err == nil
	}
	return 0, false
}

func isStateBound(sess *sessionx.Session, state string) bool {
	v, ok := sess.Get(sessionStates)
	if !ok {
		return false
	}
	m, ok := v.(map[string]any)
	if !ok {
		return false
	}
	ms, ok := toInt64(m[state])
	return ok && ms > 0 && time.Now().UnixMilli()-ms < boundStateTTL.Milliseconds()
}

type heldCallback struct {
	state, code string
	expires     time.Time
}

type heldCallbacks struct {
	mu sync.Mutex
	m  map[string]heldCallback
}

func (h *heldCallbacks) prune(now time.Time) {
	for k, v := range h.m {
		if !v.expires.After(now) {
			delete(h.m, k)
		}
	}
}

// hold stores the callback and returns the one-time token that releases it.
func (h *heldCallbacks) hold(state, code string) string {
	h.mu.Lock()
	defer h.mu.Unlock()
	now := time.Now()
	if h.m == nil {
		h.m = map[string]heldCallback{}
	}
	h.prune(now)
	raw := make([]byte, 24)
	if _, err := rand.Read(raw); err != nil {
		panic("authapi: crypto/rand failed: " + err.Error())
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	h.m[token] = heldCallback{state: state, code: code, expires: now.Add(heldCallbackTTL)}
	return token
}

func (h *heldCallbacks) take(token string) (heldCallback, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.prune(time.Now())
	v, ok := h.m[token]
	delete(h.m, token)
	return v, ok
}

// ---- provider routes --------------------------------------------------------

func (a *API) providersList(w http.ResponseWriter, r *http.Request) {
	httpx.WriteJSON(w, 200, map[string]any{"providers": a.OAuth.List(r.Context(), a.baseURL(r))})
}

func (a *API) providerBegin(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	mode := strings.ToLower(strings.TrimSpace(b.str("mode")))
	var userID int64
	if mode == "link" {
		userID, _ = a.session(r).Int64("userId")
	}
	started, err := a.OAuth.Begin(r.Context(), oauthBegin(r.PathValue("provider"), mode, userID, b.str("signupKey"), a.baseURL(r)))
	if err != nil {
		a.fail(w, err)
		return
	}
	bindState(a.session(r), started.State)
	httpx.WriteJSON(w, 200, started)
}

func (a *API) providerRegister(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	state := strings.TrimSpace(b.str("state"))
	if !isStateBound(a.session(r), state) {
		httpx.Error(w, 404, "Registration request was not found or has expired.")
		return
	}
	if err := a.OAuth.CompleteRegistration(r.Context(), state, b.str("username")); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"status": "completed"})
}

func (a *API) providerComplete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	state := strings.TrimSpace(r.URL.Query().Get("state"))
	if !isStateBound(a.session(r), state) {
		httpx.Error(w, 404, "Authentication request was not found or has expired.")
		return
	}
	done, err := a.OAuth.Consume(ctx, state)
	if err != nil {
		status := 400
		if ae, ok := apperr.As(err); ok {
			status = ae.Status
		}
		httpx.Error(w, status, err.Error())
		return
	}
	switch done.Status {
	case "pending":
		httpx.WriteJSON(w, 200, map[string]any{"status": "pending", "mode": done.Mode, "provider": done.Provider})
		return
	case "requires_username":
		httpx.WriteJSON(w, 200, map[string]any{"status": "requires_username", "requiresUsername": true, "provider": done.Provider})
		return
	}
	if done.Mode == "link" {
		httpx.WriteJSON(w, 200, map[string]any{"success": true, "status": "completed", "mode": done.Mode, "provider": done.Provider, "result": done.Result})
		return
	}
	uid, ok := toInt64(done.Result["userId"])
	if !ok {
		httpx.Error(w, 404, "User not found")
		return
	}
	user, err := a.Users.ByID(ctx, uid)
	if err != nil {
		httpx.Error(w, 400, "Provider sign-in failed.")
		return
	}
	if user == nil {
		httpx.Error(w, 404, "User not found")
		return
	}
	st, err := a.TwoFactor.Status(ctx, user.ID)
	if err != nil {
		httpx.Error(w, 400, "Provider sign-in failed.")
		return
	}
	if st.Enabled {
		a.startTwoFactorChallenge(w, r, user)
		return
	}
	a.touchLastLogin(r, user.ID)
	a.establish(w, r, user, 0)
}

func (a *API) providerUnlink(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if _, err := a.OAuth.Unlink(r.Context(), a.sessionUserID(r), id); err != nil {
		a.fail(w, err)
		return
	}
	a.accountPayload(w, r)
}

// ---- the provider's redirect back -------------------------------------------

const popupBase = `<!doctype html><html><head><meta charset="utf-8"><title>%s</title>
<style>
  body{margin:0;min-height:100vh;display:grid;place-items:center;font-family:system-ui,sans-serif;
    background:#0e1511;color:#ecefe5;padding:24px;text-align:center}
  p{line-height:1.5;color:#aeb7a6;max-width:28rem}
  strong{color:#ecefe5}
  a.button{display:inline-block;margin-top:8px;padding:10px 18px;border-radius:8px;
    background:#ecefe5;color:#0e1511;text-decoration:none;font-weight:600}
</style></head><body>
%s
</body></html>`

func renderOAuthPage(title, content string) string {
	return fmt.Sprintf(popupBase, escapeHTML(title), content)
}

var inlineScriptEscaper = strings.NewReplacer("<", `<`, ">", `>`, "&", `&`, " ", ` `, " ", ` `)

func jsonForInlineScript(v any) string {
	raw, _ := json.Marshal(v)
	return inlineScriptEscaper.Replace(string(raw))
}

// renderOAuthPopupResult tells the opener window (and same-browser tabs) how the
// flow ended, then closes itself.
func renderOAuthPopupResult(success bool, payload map[string]any, message string) string {
	title := "Connection failed"
	if success {
		title = "Connected"
	}
	return renderOAuthPage(title, fmt.Sprintf(`<p><strong>%s.</strong> %s</p>
<script>
(function () {
  var payload = %s;
  function notify() {
    try {
      if (typeof BroadcastChannel !== 'undefined') {
        var channel = new BroadcastChannel('neoagent_oauth');
        channel.postMessage(payload);
        channel.close();
      }
    } catch (e) {}
    try {
      if (window.opener && !window.opener.closed) {
        // Prefer the opener's origin when known; fall back to wildcard so a
        // localhost vs PUBLIC_URL mismatch cannot strand the flow.
        var target = '*';
        try {
          if (window.opener.location && window.opener.location.origin) {
            target = window.opener.location.origin;
          }
        } catch (e) {
          // Cross-origin opener: location is not readable; '*' is required.
          target = '*';
        }
        window.opener.postMessage(payload, target);
      }
    } catch (e) {}
  }
  notify();
  setTimeout(function () {
    try { window.close(); } catch (e) {}
  }, 120);
  setTimeout(function () {
    document.body.insertAdjacentHTML('beforeend',
      '<p style="margin-top:16px;font-size:13px">You can close this window and return to NeoAgent.</p>');
  }, 500);
})();
</script>`, title, escapeHTML(message), jsonForInlineScript(payload)))
}

func renderOAuthFailure(message string) string {
	return renderOAuthPopupResult(false, map[string]any{"type": "auth_oauth_error", "error": message}, message)
}

func renderOAuthConfirmPage(what, startedAt, token string) string {
	confirmURL := "callback/confirm?token=" + urlQueryEscape(token)
	return renderOAuthPage("Confirm sign-in", fmt.Sprintf(`<div>
<p><strong>Do you want to %s?</strong></p>
<p>This was started in a NeoAgent app at %s UTC. Only continue if you started it yourself.</p>
<a class="button" href="%s">Yes, continue</a>
<p style="font-size:13px">If you did not start this, close this window.</p>
</div>`, what, escapeHTML(startedAt), escapeHTML(confirmURL)))
}

func urlQueryEscape(s string) string {
	var b strings.Builder
	for _, c := range []byte(s) {
		switch {
		case c >= 'A' && c <= 'Z', c >= 'a' && c <= 'z', c >= '0' && c <= '9', strings.IndexByte("-_.!~*'()", c) >= 0:
			b.WriteByte(c)
		default:
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

// oauthCallback receives account, model provider and integration redirects.
func (a *API) oauthCallback(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	state, code, errText := q.Get("state"), q.Get("code"), q.Get("error")
	if state == "" {
		// Providers such as OpenRouter drop the state when the person declines.
		if errText != "" {
			writePage(w, 400, renderOAuthPage("Sign-in canceled", "<p><strong>Sign-in was canceled.</strong> You can close this window and return to NeoAgent.</p>"))
			return
		}
		http.Error(w, "Missing state parameter", 400)
		return
	}
	if !authStateRE.MatchString(state) && !integrationStateRE.MatchString(state) && !modelStateRE.MatchString(state) {
		http.Error(w, "Invalid OAuth state parameter", 400)
		return
	}
	if errText == "" && code == "" {
		http.Error(w, "Missing code parameter", 400)
		return
	}
	ctx := r.Context()
	if authStateRE.MatchString(state) && a.OAuth == nil {
		writePage(w, 400, renderOAuthFailure("This request has expired. Start again from NeoAgent."))
		return
	}
	if errText != "" && modelStateRE.MatchString(state) {
		if a.ModelOAuth != nil {
			a.ModelOAuth.Fail(state, errText)
		}
		writePage(w, 400, renderOAuthPopupResult(false, map[string]any{"type": "model_sign_in_error", "error": errText}, errText))
		return
	}
	if errText != "" {
		if authStateRE.MatchString(state) {
			_ = a.OAuth.Fail(ctx, state, errText)
			writePage(w, 400, renderOAuthFailure(errText))
		} else {
			writePage(w, 400, renderOAuthPopupResult(false, map[string]any{"type": "integration_oauth_error", "error": errText}, errText))
		}
		return
	}
	if modelStateRE.MatchString(state) {
		if a.ModelOAuth == nil {
			writePage(w, 400, renderOAuthPopupResult(false, map[string]any{"type": "model_sign_in_error", "error": "This request has expired. Start again from NeoAgent."}, "This request has expired. Start again from NeoAgent."))
			return
		}
		if !isStateBound(a.session(r), state) {
			pending, err := a.ModelOAuth.Describe(ctx, state)
			if err != nil || pending == nil {
				writePage(w, 400, renderOAuthPopupResult(false, map[string]any{"type": "model_sign_in_error", "error": "This request has expired. Start again from NeoAgent."}, "This request has expired. Start again from NeoAgent."))
				return
			}
			what := "connect your " + escapeHTML(pending.ProviderLabel) + " account to the NeoAgent account <strong>" + escapeHTML(pending.Username) + "</strong>"
			writePage(w, 200, renderOAuthConfirmPage(what, pending.StartedAt, a.held.hold(state, code)))
			return
		}
		a.finishCallback(w, ctx, state, code)
		return
	}
	if integrationStateRE.MatchString(state) {
		if a.IntegrationOAuth == nil {
			writePage(w, 400, renderOAuthPopupResult(false, map[string]any{"type": "integration_oauth_error", "error": "This request has expired. Start again from NeoAgent."}, "This request has expired. Start again from NeoAgent."))
			return
		}
		if !isStateBound(a.session(r), state) {
			pending, err := a.IntegrationOAuth.Describe(ctx, state)
			if err != nil || pending == nil {
				writePage(w, 400, renderOAuthPopupResult(false, map[string]any{"type": "integration_oauth_error", "error": "This request has expired. Start again from NeoAgent."}, "This request has expired. Start again from NeoAgent."))
				return
			}
			service := pending.ProviderLabel
			if pending.AppLabel != "" {
				service += " " + pending.AppLabel
			}
			what := "connect " + escapeHTML(service) + " to the NeoAgent account <strong>" + escapeHTML(pending.Username) + "</strong>"
			writePage(w, 200, renderOAuthConfirmPage(what, pending.StartedAt, a.held.hold(state, code)))
			return
		}
		a.finishCallback(w, ctx, state, code)
		return
	}
	if !isStateBound(a.session(r), state) {
		pending, err := a.OAuth.Describe(ctx, state)
		if err != nil || pending == nil {
			writePage(w, 400, renderOAuthFailure("This request has expired. Start again from NeoAgent."))
			return
		}
		provider := escapeHTML(pending.ProviderLabel)
		what := "finish signing in to NeoAgent with " + provider
		if pending.Mode == "link" {
			what = "link " + provider + " to the NeoAgent account <strong>" + escapeHTML(pending.Username) + "</strong>"
		}
		writePage(w, 200, renderOAuthConfirmPage(what, pending.StartedAt, a.held.hold(state, code)))
		return
	}
	a.finishCallback(w, r.Context(), state, code)
}

func (a *API) oauthCallbackConfirm(w http.ResponseWriter, r *http.Request) {
	held, ok := a.held.take(r.URL.Query().Get("token"))
	if !ok {
		writePage(w, 400, renderOAuthPage("Link expired", "<p><strong>This confirmation link has expired or was already used.</strong> Start again from NeoAgent.</p>"))
		return
	}
	a.finishCallback(w, r.Context(), held.state, held.code)
}

func (a *API) finishCallback(w http.ResponseWriter, ctx context.Context, state, code string) {
	if modelStateRE.MatchString(state) {
		if a.ModelOAuth == nil {
			writePage(w, 400, renderOAuthPopupResult(false, map[string]any{"type": "model_sign_in_error", "error": "This request has expired. Start again from NeoAgent."}, "This request has expired. Start again from NeoAgent."))
			return
		}
		provider, err := a.ModelOAuth.Finish(ctx, state, code)
		if err != nil {
			message := publicerr.Sanitize(err.Error(), "", "")
			writePage(w, 500, renderOAuthPopupResult(false, map[string]any{"type": "model_sign_in_error", "error": message}, message))
			return
		}
		writePage(w, 200, renderOAuthPopupResult(true, map[string]any{"type": "model_sign_in_success", "provider": provider}, "You can close this window and return to NeoAgent."))
		return
	}
	if integrationStateRE.MatchString(state) {
		if a.IntegrationOAuth == nil {
			writePage(w, 400, renderOAuthPopupResult(false, map[string]any{"type": "integration_oauth_error", "error": "This request has expired. Start again from NeoAgent."}, "This request has expired. Start again from NeoAgent."))
			return
		}
		result, err := a.IntegrationOAuth.Finish(ctx, state, code)
		if err != nil {
			message := publicerr.Sanitize(err.Error(), "", "")
			writePage(w, 500, renderOAuthPopupResult(false, map[string]any{"type": "integration_oauth_error", "error": message}, message))
			return
		}
		writePage(w, 200, renderOAuthPopupResult(true, map[string]any{"type": "integration_oauth_success", "provider": result.Provider, "appId": result.AppID, "connectionId": result.ConnectionID, "accountEmail": result.AccountEmail}, "You can close this window and return to NeoAgent."))
		return
	}
	res, err := a.OAuth.Finish(ctx, state, code)
	if err != nil {
		msg := err.Error()
		_ = a.OAuth.Fail(ctx, state, msg)
		writePage(w, 500, renderOAuthFailure(msg))
		return
	}
	message := "You can close this window and return to NeoAgent."
	if res.RequiresUsername {
		message = "Return to NeoAgent to choose your username and finish registration."
	}
	writePage(w, 200, renderOAuthPopupResult(true, map[string]any{
		"type": "auth_oauth_success", "provider": res.Provider, "mode": res.Action, "email": res.Email,
	}, message))
}

func oauthBegin(provider, mode string, userID int64, signupKey, baseURL string) oauthlogin.BeginParams {
	return oauthlogin.BeginParams{ProviderKey: provider, Mode: mode, UserID: userID, SignupKey: signupKey, BaseURL: baseURL}
}
