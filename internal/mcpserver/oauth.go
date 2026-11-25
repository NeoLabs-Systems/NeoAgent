package mcpserver

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"sync"
	"time"

	"github.com/modelcontextprotocol/go-sdk/auth"
	"github.com/modelcontextprotocol/go-sdk/oauthex"
	"golang.org/x/oauth2"
)

// oauthFlow carries one browser authorization between the connection attempt
// that needs it and the callback route that completes it. The SDK's handler
// blocks in its fetcher until the user's browser comes back, so the attempt
// runs in the background: the start request gets the authorization URL, the
// callback delivers the code and waits for the outcome.
type oauthFlow struct {
	urlCh  chan string
	codeCh chan authCallback
	done   chan error // outcome of the whole connection, read by the callback
	once   sync.Once
}

type authCallback struct{ code, iss string }

func newFlow() *oauthFlow {
	return &oauthFlow{urlCh: make(chan string, 1), codeCh: make(chan authCallback, 1), done: make(chan error, 1)}
}

func (f *oauthFlow) finish(err error) { f.once.Do(func() { f.done <- err }) }

// fetcher is the auth.AuthorizationCodeFetcher of a server. It swaps the SDK's
// state for one in NeoAgent's `<serverId>::<32 hex>` format, remembers its
// digest, hands the URL to the start request and waits for the callback.
func (m *Manager) fetcher(serverID int64, flow *oauthFlow) auth.AuthorizationCodeFetcher {
	return func(ctx context.Context, args *auth.AuthorizationArgs) (*auth.AuthorizationResult, error) {
		u, err := url.Parse(args.URL)
		if err != nil {
			return nil, err
		}
		q := u.Query()
		sdkState := q.Get("state")
		ours := newState(serverID)
		if err := m.store.SaveAuthState(ctx, serverID, ours); err != nil {
			return nil, err
		}
		q.Set("state", ours)
		u.RawQuery = q.Encode()
		flow.urlCh <- u.String()
		select {
		case cb := <-flow.codeCh:
			return &auth.AuthorizationResult{Code: cb.code, State: sdkState, Iss: cb.iss}, nil
		case <-ctx.Done():
			return nil, errors.New("OAuth authorization was not completed in time")
		}
	}
}

// oauthHandler builds the SDK handler for a server whose auth type is oauth.
func (m *Manager) oauthHandler(serverID int64, cfg map[string]any, flow *oauthFlow) (*auth.AuthorizationCodeHandler, error) {
	authCfg, _ := cfg["auth"].(map[string]any)
	clientID, _ := authCfg["clientId"].(string)
	hc := &auth.AuthorizationCodeHandlerConfig{
		RedirectURL:              m.redirectURL,
		AuthorizationCodeFetcher: m.fetcher(serverID, flow),
		Client:                   m.httpClient,
	}
	if clientID != "" {
		hc.PreregisteredClient = &oauthex.ClientCredentials{ClientID: clientID}
	} else {
		hc.DynamicClientRegistrationConfig = &auth.DynamicClientRegistrationConfig{Metadata: &oauthex.ClientRegistrationMetadata{
			RedirectURIs: []string{m.redirectURL},
			ClientName:   "NeoAgent",
		}}
	}
	if tokens, _ := authCfg["tokens"].(map[string]any); tokens != nil {
		if access, _ := tokens["access_token"].(string); access != "" {
			refresh, _ := tokens["refresh_token"].(string)
			kind, _ := tokens["token_type"].(string)
			hc.InitialTokenSource = oauth2.StaticTokenSource(&oauth2.Token{AccessToken: access, RefreshToken: refresh, TokenType: kind})
		}
	}
	return auth.NewAuthorizationCodeHandler(hc)
}

// persistTokens keeps the tokens the handler obtained so a restart does not ask
// the user to sign in again.
func (m *Manager) persistTokens(ctx context.Context, serverID int64, h *auth.AuthorizationCodeHandler) {
	src, err := h.TokenSource(ctx)
	if err != nil || src == nil {
		return
	}
	tok, err := src.Token()
	if err != nil || tok.AccessToken == "" {
		return
	}
	out := map[string]any{"access_token": tok.AccessToken, "token_type": tok.Type()}
	if tok.RefreshToken != "" {
		out["refresh_token"] = tok.RefreshToken
	}
	if !tok.Expiry.IsZero() {
		out["expires_in"] = int64(time.Until(tok.Expiry).Seconds())
	}
	if err := m.store.SaveTokens(ctx, serverID, out); err != nil {
		m.log.Error("saving MCP OAuth tokens failed", "server", serverID, "error", err)
	}
}

// FinishOAuth hands the authorization code of a callback to the waiting
// connection and returns once that connection is up (or has failed).
func (m *Manager) FinishOAuth(ctx context.Context, serverID int64, code, iss string) (map[string]any, error) {
	m.mu.Lock()
	srv := m.servers[serverID]
	var flow *oauthFlow
	if srv != nil {
		flow = srv.flow
	}
	m.mu.Unlock()
	if flow == nil {
		return nil, fmt.Errorf("Server %d transport not initialized", serverID)
	}
	select {
	case flow.codeCh <- authCallback{code: code, iss: iss}:
	default:
		return nil, errors.New("OAuth already completed for this server")
	}
	select {
	case err := <-flow.done:
		if err != nil {
			return nil, err
		}
		return map[string]any{"status": "running"}, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}
