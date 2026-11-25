package providersignin

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

func HasSignInMethod(providerID string) bool { return providerID == "openrouter" }

const flowExpired = "This sign-in has expired. Start again from NeoAgent."

type SecretStore interface {
	SetProviderSecret(context.Context, int64, string, string, string) error
}
type flow struct {
	user                                   int64
	agent, verifier, callback, status, err string
	started                                time.Time
}
type Flows struct {
	Store                SecretStore
	Client               *http.Client
	AuthURL, ExchangeURL string
	mu                   sync.Mutex
	flows                map[string]*flow
}

func NewFlows(store SecretStore) *Flows {
	return &Flows{Store: store, Client: ssrf.NewClient(ssrf.Options{}), AuthURL: "https://openrouter.ai/auth", ExchangeURL: "https://openrouter.ai/api/v1/auth/keys", flows: map[string]*flow{}}
}
func (f *Flows) prune(now time.Time) {
	for state, item := range f.flows {
		if now.Sub(item.started) >= 10*time.Minute {
			delete(f.flows, state)
		}
	}
}
func randomBytes(n int) ([]byte, error) { b := make([]byte, n); _, err := rand.Read(b); return b, err }
func callbackURL(base string) string {
	u, err := url.Parse(base)
	if err != nil || u.Hostname() == "" || u.User != nil {
		return ""
	}
	host := strings.ToLower(u.Hostname())
	if u.Scheme != "https" && !(u.Scheme == "http" && (host == "localhost" || host == "127.0.0.1" || host == "::1")) {
		return ""
	}
	return strings.TrimRight(base, "/") + "/api/integrations/oauth/callback"
}
func (f *Flows) Begin(_ context.Context, providerID string, user int64, agent, base string) (map[string]any, error) {
	if !HasSignInMethod(providerID) {
		return nil, errors.New("Sign-in is not available for this provider.")
	}
	stateBytes, err := randomBytes(24)
	if err != nil {
		return nil, err
	}
	verifierBytes, err := randomBytes(48)
	if err != nil {
		return nil, err
	}
	state := "model_" + hex.EncodeToString(stateBytes)
	verifier := base64.RawURLEncoding.EncodeToString(verifierBytes)
	callback := callbackURL(base)
	params := oauthclient.Query{}
	mode := "code"
	if callback != "" {
		mode = "redirect"
		params = append(params, [2]string{"callback_url", callback}, [2]string{"state", state})
	}
	params = append(params, [2]string{"code_challenge", oauthclient.CodeChallenge(verifier)}, [2]string{"code_challenge_method", "S256"}, [2]string{"key_label", "NeoAgent"})
	target, err := oauthclient.SetParams(f.AuthURL, params)
	if err != nil {
		return nil, err
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.prune(time.Now())
	f.flows[state] = &flow{user: user, agent: agent, verifier: verifier, callback: callback, status: "pending", started: time.Now()}
	return map[string]any{"state": state, "mode": mode, "url": target}, nil
}
func (f *Flows) Status(state string, user int64) (map[string]any, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.prune(time.Now())
	item := f.flows[state]
	if item == nil || item.user != user {
		return nil, false
	}
	status := item.status
	if status == "exchanging" {
		status = "pending"
	}
	if status == "completed" || status == "failed" {
		delete(f.flows, state)
	}
	var message any
	if item.err != "" {
		message = item.err
	}
	return map[string]any{"status": status, "providerId": "openrouter", "error": message}, true
}
func (f *Flows) Describe(state string) (provider string, user int64, started time.Time, ok bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.prune(time.Now())
	item := f.flows[state]
	if item == nil || item.status != "pending" {
		return "", 0, time.Time{}, false
	}
	return "OpenRouter", item.user, item.started, true
}
func (f *Flows) Fail(state, message string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.prune(time.Now())
	if item := f.flows[state]; item != nil && item.status == "pending" {
		item.status = "failed"
		item.err = message
	}
}
func (f *Flows) Complete(ctx context.Context, state, code string, user int64) (map[string]any, error) {
	f.mu.Lock()
	f.prune(time.Now())
	item := f.flows[state]
	if item == nil || item.status != "pending" || user != 0 && item.user != user {
		f.mu.Unlock()
		return nil, errors.New(flowExpired)
	}
	item.status = "exchanging"
	f.mu.Unlock()
	ctx = context.WithoutCancel(ctx)
	key, _, err := f.exchange(ctx, code, item.verifier)
	if err == nil {
		err = f.Store.SetProviderSecret(ctx, item.user, item.agent, "openrouter", key)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if err != nil {
		if item.callback != "" {
			item.status = "failed"
			item.err = publicerr.Sanitize(err.Error(), "", "")
		} else {
			item.status = "pending"
		}
		return nil, err
	}
	item.status = "completed"
	return map[string]any{"status": "completed", "providerId": "openrouter"}, nil
}

// exchange trades a callback code for the API key OpenRouter minted, and the
// OpenRouter user id when it sends one.
func (f *Flows) exchange(ctx context.Context, code, verifier string) (key, userID string, err error) {
	raw, err := (&oauthclient.Client{HTTP: f.Client, Service: "OpenRouter sign-in"}).Do(ctx, oauthclient.Request{Method: "POST", URL: f.ExchangeURL,
		Header: map[string]string{"Accept": "application/json"},
		JSON:   map[string]any{"code": code, "code_verifier": verifier, "code_challenge_method": "S256"}, MaxBytes: 64 << 10})
	if err != nil {
		return "", "", err
	}
	var data map[string]any
	_ = json.Unmarshal(raw.Body, &data)
	key, _ = data["key"].(string)
	key = strings.TrimSpace(key)
	if raw.Status < 200 || raw.Status >= 300 || key == "" {
		message, _ := data["message"].(string)
		if v, ok := data["error"].(string); ok {
			message = v
		} else if v, ok := data["error"].(map[string]any); ok {
			if m, ok := v["message"].(string); ok {
				message = m
			}
		}
		if message == "" {
			message = fmt.Sprintf("OpenRouter did not return a key (HTTP %d).", raw.Status)
		}
		return "", "", errors.New(message)
	}
	userID, _ = data["user_id"].(string)
	return key, strings.TrimSpace(userID), nil
}
