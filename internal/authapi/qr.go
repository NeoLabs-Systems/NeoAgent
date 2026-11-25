package authapi

import (
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/qrlogin"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// baseURL is how clients reach this server: PUBLIC_URL when configured,
// otherwise the address the request came in on.
func (a *API) baseURL(r *http.Request) string {
	if a.Cfg.PublicURL != "" {
		return strings.TrimRight(a.Cfg.PublicURL, "/")
	}
	scheme := "http"
	if a.Sessions.IsSecureRequest(r) {
		scheme = "https"
	}
	return scheme + "://" + r.Host
}

func (a *API) qrChallenge(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	ip := httpx.ClientIP(r, a.Cfg.TrustProxy)
	label, data := accounts.Locate(ip)
	c, err := a.QR.Create(r.Context(), qrlogin.Request{
		UserAgent: truncate(r.Header.Get("User-Agent"), 500), IPAddress: ip,
		LocationLabel: label, LocationJSON: data, Metadata: b["requestMetadata"],
	})
	if err != nil {
		a.fail(w, err)
		return
	}
	base := a.baseURL(r)
	q := "v=1&backend=" + url.QueryEscape(base) + "&challenge=" + url.QueryEscape(c.ChallengeID) + "&secret=" + url.QueryEscape(c.ApproveSecret)
	httpx.WriteJSON(w, 200, map[string]any{
		"challengeId": c.ChallengeID, "pollToken": c.PollToken, "expiresAt": c.ExpiresAt, "status": c.Status,
		"qrPayload": "neoagent://qr-login?" + q, "backendUrl": base,
	})
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}

func (a *API) qrStatus(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	token := strings.TrimSpace(b.str("token"))
	if token == "" {
		httpx.Error(w, 400, "QR login poll token is required.")
		return
	}
	known := strings.TrimSpace(b.str("knownStatus"))
	id := r.PathValue("id")
	var p *qrlogin.Poll
	if known == "" {
		p, err = a.QR.PollStatus(r.Context(), id, token)
	} else {
		// Held open until the status changes, so the signing-in screen hears of
		// a scan or approval at once. r.Context() ends if the client goes away.
		p, err = a.QR.WaitForChange(r.Context(), id, token, known, qrlogin.LongPollMax)
	}
	if err != nil {
		a.fail(w, err)
		return
	}
	if r.Context().Err() != nil {
		return
	}
	httpx.WriteJSON(w, 200, p)
}

func (a *API) qrCancel(w http.ResponseWriter, r *http.Request) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	token := strings.TrimSpace(b.str("token"))
	if token == "" {
		httpx.Error(w, 400, "QR login poll token is required.")
		return
	}
	if err := a.QR.Cancel(r.Context(), r.PathValue("id"), token); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

func (a *API) qrClaim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	token := strings.TrimSpace(b.str("token"))
	if token == "" {
		httpx.Error(w, 400, "QR login poll token is required.")
		return
	}
	claimed, err := a.QR.Claim(ctx, r.PathValue("id"), token)
	if err != nil {
		a.fail(w, err)
		return
	}
	user, err := a.Users.ByID(ctx, claimed.UserID)
	if err != nil {
		a.fail(w, err)
		return
	}
	if user == nil {
		httpx.Error(w, 404, "The approving account is no longer available.")
		return
	}
	a.touchLastLogin(r, user.ID)
	var age time.Duration
	if md, _ := claimed.Challenge.RequestedDevice.Metadata["platform"].(string); md == "esp32-s3-amoled" {
		age = wearableSessionAge
	}
	a.establish(w, r, user, age)
}

// ---- the signed-in phone ----------------------------------------------------

func (a *API) qrIDs(w http.ResponseWriter, r *http.Request) (b body, id, secret string, ok bool) {
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return nil, "", "", false
	}
	id, secret = strings.TrimSpace(b.str("challengeId")), strings.TrimSpace(b.str("secret"))
	if id == "" || secret == "" {
		httpx.Error(w, 400, "Challenge id and QR secret are required.")
		return nil, "", "", false
	}
	return b, id, secret, true
}

func (a *API) qrResolve(w http.ResponseWriter, r *http.Request) {
	b, id, secret, ok := a.qrIDs(w, r)
	if !ok {
		return
	}
	c, err := a.QR.MarkScanned(r.Context(), id, secret, b["scannerMetadata"])
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, c)
}

func (a *API) qrDecline(w http.ResponseWriter, r *http.Request) {
	_, id, secret, ok := a.qrIDs(w, r)
	if !ok {
		return
	}
	if err := a.QR.Decline(r.Context(), id, secret); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

func (a *API) qrApprove(w http.ResponseWriter, r *http.Request) {
	b, id, secret, ok := a.qrIDs(w, r)
	if !ok {
		return
	}
	sess := sessionx.FromContext(r.Context())
	c, err := a.QR.Approve(r.Context(), id, secret, a.sessionUserID(r), sessionx.HashID(a.Cfg.SessionSecret, sess.ID()), b["approvalMetadata"])
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, c)
}

// ---- pairing ---------------------------------------------------------------

func (a *API) pairingStart(w http.ResponseWriter, r *http.Request) {
	st, err := a.Pairing.Start(r.Context(), a.sessionUserID(r), a.baseURL(r))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, st)
}

func (a *API) pairingStatus(w http.ResponseWriter, r *http.Request) {
	st, err := a.Pairing.Status(r.Context(), a.sessionUserID(r), r.PathValue("code"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, st)
}

// pair is the phone's swap of a code for a session.
func (a *API) pair(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	b, err := readBody(r)
	if err != nil {
		a.fail(w, err)
		return
	}
	code, _ := b["code"].(string)
	uid, err := a.Pairing.Redeem(ctx, code, b.str("name"))
	if err != nil {
		a.fail(w, err)
		return
	}
	user, err := a.Users.ByID(ctx, uid)
	if err != nil || user == nil {
		httpx.ErrorCode(w, 410, "The account that showed this code is no longer available.", "EXPIRED_TOKEN")
		return
	}
	a.touchLastLogin(r, user.ID)
	a.establish(w, r, user, 0)
}
