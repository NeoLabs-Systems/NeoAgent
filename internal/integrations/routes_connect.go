package integrations

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"net/http"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

// InteractiveStart answers a connect request of a provider with its own
// connect page; the URL carries the agent because the popup has no agent
// context of its own.
type InteractiveStart struct {
	Provider  string `json:"provider"`
	AppID     string `json:"appId"`
	Status    string `json:"status"`
	SessionID string `json:"sessionId"`
	LoginURL  string `json:"loginUrl,omitempty"`
	URL       string `json:"url"`
}

// BeginConnection starts a connection of a Connector provider; ok is false
// for providers that connect through OAuth.
func (m *Manager) BeginConnection(ctx context.Context, userID int64, providerKey, appKey, candidateAgent string) (*InteractiveStart, bool, error) {
	p := m.Provider(providerKey)
	connector, isConnector := p.(Connector)
	if p == nil || !isConnector {
		return nil, false, nil
	}
	agentID, err := m.agent(ctx, userID, candidateAgent)
	if err != nil {
		return nil, true, err
	}
	info := p.Info()
	appKey = strings.TrimSpace(appKey)
	if _, ok := p.App(appKey); !ok {
		missing := appKey
		if missing == "" {
			missing = "missing app key"
		}
		return nil, true, fmt.Errorf("Unknown %s app: %s", info.Label, missing)
	}
	scope := Scope{UserID: userID, AgentID: agentID}
	if env := p.EnvStatus(scope); !env.Configured {
		return nil, true, errors.New(env.Summary)
	}
	started, err := connector.BeginConnection(ctx, scope, appKey)
	if err != nil {
		return nil, true, err
	}
	target := strings.TrimSpace(started.URL)
	if !strings.HasPrefix(target, "http") {
		if !strings.HasPrefix(target, "/") {
			target = "/" + target
		}
		sep := "?"
		if strings.Contains(target, "?") {
			sep = "&"
		}
		target = m.svc.PublicBaseURL() + target + sep + "agentId=" + url.QueryEscape(agentID)
	}
	return &InteractiveStart{Provider: info.Key, AppID: appKey, Status: started.Status, SessionID: started.SessionID, LoginURL: started.LoginURL, URL: target}, true, nil
}

// connectionSession finds the signed-in account's session of a provider.
func (a *API) connectionSession(r *http.Request, req request) (Provider, *ConnectionSession) {
	p := a.m.Provider(r.PathValue("provider"))
	sessions, ok := p.(ConnectionSessions)
	if !ok {
		return p, nil
	}
	s, found := sessions.ConnectionSession(req.scope(), strings.TrimSpace(r.PathValue("sessionId")))
	if !found {
		return p, nil
	}
	return p, s
}

func (a *API) connectStatus(w http.ResponseWriter, r *http.Request, req request) {
	_, s := a.connectionSession(r, req)
	if s == nil {
		httpx.Error(w, http.StatusNotFound, "Connection session not found.")
		return
	}
	httpx.WriteJSON(w, http.StatusOK, s)
}

func (a *API) connectCancel(w http.ResponseWriter, r *http.Request, req request) {
	canceler, ok := a.m.Provider(r.PathValue("provider")).(ConnectionCanceler)
	if !ok {
		httpx.Error(w, http.StatusNotFound, "Connection cancellation is not supported.")
		return
	}
	if err := canceler.CancelConnectionSession(r.Context(), req.scope(), r.PathValue("sessionId")); err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"canceled": true})
}

// inlineJSON is a value as a JavaScript literal safe inside <script>:
// encoding/json escapes <, >, &, U+2028 and U+2029.
func inlineJSON(v any) string {
	raw, _ := json.Marshal(v)
	return string(raw)
}

func (a *API) connectPage(w http.ResponseWriter, r *http.Request, req request) {
	p, s := a.connectionSession(r, req)
	if s == nil {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte("Connection session not found."))
		return
	}
	providerKey := r.PathValue("provider")
	providerLabel := p.Info().Label
	appLabel := s.AppID
	if app, ok := p.App(s.AppID); ok {
		appLabel = app.Label
	}
	if appLabel == "" {
		appLabel = "account"
	}
	trustedOrigin := ""
	if u, err := url.Parse(a.m.svc.PublicBaseURL()); err == nil && u.Scheme != "" && u.Host != "" {
		trustedOrigin = u.Scheme + "://" + u.Host
	}
	statusURL := fmt.Sprintf("/api/integrations/%s/connect/%s/status?agentId=%s",
		url.PathEscape(providerKey), url.PathEscape(r.PathValue("sessionId")), url.QueryEscape(req.agentID))
	label := escapeHTML(providerLabel)
	page := strings.NewReplacer(
		"{{label}}", label,
		"{{appLabel}}", escapeHTML(appLabel),
		"{{statusUrl}}", inlineJSON(statusURL),
		"{{trustedOrigin}}", inlineJSON(trustedOrigin),
		"{{provider}}", inlineJSON(providerKey),
		"{{appId}}", inlineJSON(s.AppID),
		"{{loginUrl}}", inlineJSON(strings.TrimSpace(s.LoginURL)),
	).Replace(connectPageTemplate)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(page))
}

// escapeHTML is the Node route's escapeHtml (it also escapes the quote).
func escapeHTML(s string) string {
	return strings.ReplaceAll(html.EscapeString(s), "&#34;", "&quot;")
}

const connectPageTemplate = `
      <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>Connect {{label}}</title>
          <style>
            body { font-family: ui-sans-serif, system-ui, sans-serif; background: #0b1220; color: #f8fafc; margin: 0; padding: 24px; }
            .card { max-width: 560px; margin: 0 auto; background: #111827; border: 1px solid #1f2937; border-radius: 20px; padding: 24px; }
            .muted { color: #94a3b8; }
            .pill { display: inline-block; padding: 6px 10px; border-radius: 999px; background: #1f2937; font-size: 12px; }
            img { display: block; margin: 24px auto; background: white; padding: 12px; border-radius: 16px; max-width: min(320px, 100%); }
            code { background: #0f172a; padding: 2px 6px; border-radius: 6px; }
            .actions { margin: 20px 0 8px; }
            a.button { display: inline-block; background: #0082c9; color: #fff; text-decoration: none; font-weight: 650; padding: 10px 14px; border-radius: 12px; }
            a.button:hover { filter: brightness(1.08); }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="pill">Official integration</div>
            <h1>Connect {{label}}</h1>
            <p class="muted">Complete connection for {{appLabel}}. This window closes automatically when linking is finished.</p>
            <div id="status" class="muted">Starting connection…</div>
            <div id="loginActions" class="actions" style="display:none;">
              <a id="loginLink" class="button" target="_blank" rel="noopener noreferrer">Open {{label}} login</a>
            </div>
            <img id="qr" alt="Integration QR code" style="display:none;" />
            <p id="hint" class="muted">If this flow needs QR scan approval, the code will appear below.</p>
          </div>
          <script>
            const statusEl = document.getElementById('status');
            const qrEl = document.getElementById('qr');
            const hintEl = document.getElementById('hint');
            const loginActions = document.getElementById('loginActions');
            const loginLink = document.getElementById('loginLink');
            const statusUrl = {{statusUrl}};
            const trustedOrigin = {{trustedOrigin}};
            const provider = {{provider}};
            const appId = {{appId}};
            const initialLoginUrl = {{loginUrl}};
            let loginOpened = false;

            function notifyOpener(payload) {
              try {
                if (typeof BroadcastChannel !== 'undefined') {
                  const channel = new BroadcastChannel('neoagent_oauth');
                  channel.postMessage(payload);
                  channel.close();
                }
              } catch (error) {}
              if (!window.opener) return;
              window.opener.postMessage(payload, trustedOrigin);
            }

            function openLogin(url) {
              if (!url) return;
              loginLink.href = url;
              loginActions.style.display = 'block';
              hintEl.textContent = 'Sign in to {{label}} in the window that opened. This page waits until you approve access.';
              if (loginOpened) return;
              loginOpened = true;
              window.open(url, 'neoagent_integration_login', 'noopener,width=720,height=800');
            }

            if (initialLoginUrl) openLogin(initialLoginUrl);

            async function refresh() {
              const response = await fetch(statusUrl, { credentials: 'same-origin' });
              if (!response.ok) {
                statusEl.textContent = 'Connection session expired or is no longer available.';
                return;
              }
              const data = await response.json();
              const status = String(data.status || 'connecting');
              if (data.loginUrl) openLogin(String(data.loginUrl));
              if (status === 'awaiting_qr' && data.qr) {
                statusEl.textContent = 'Scan this QR code to continue linking.';
                qrEl.src = '/api/integrations/qr-image?data=' + encodeURIComponent(data.qr);
                qrEl.style.display = 'block';
              } else if (status === 'connected') {
                qrEl.style.display = 'none';
                loginActions.style.display = 'none';
                statusEl.textContent = 'Connected as ' + (data.accountEmail || 'your account') + '. Closing…';
                notifyOpener({
                  type: 'integration_oauth_success',
                  provider,
                  appId,
                  connectionId: data.connectionId || null,
                  accountEmail: data.accountEmail || null,
                });
                setTimeout(() => window.close(), 800);
                return;
              } else if (status === 'failed' || status === 'logged_out' || status === 'disconnected') {
                qrEl.style.display = 'none';
                statusEl.textContent = data.error || ('Connection ended with status: ' + status + '.');
                notifyOpener({
                  type: 'integration_oauth_error',
                  provider,
                  appId,
                  error: data.error || ('Connection ended with status: ' + status + '.'),
                });
                return;
              } else if (data.loginUrl) {
                statusEl.textContent = 'Waiting for you to sign in and approve access…';
              } else {
                statusEl.textContent = 'Waiting for the integration to finish linking…';
              }
              setTimeout(refresh, 1500);
            }
            refresh().catch((error) => {
              statusEl.textContent = error?.message || 'Could not load connection status.';
            });
          </script>
        </body>
      </html>
    `
