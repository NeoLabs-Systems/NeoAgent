package providersignin

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
)

type savedSecret struct {
	mu         sync.Mutex
	user       int64
	agent, key string
}

func (s *savedSecret) SetProviderSecret(_ context.Context, user int64, agent, provider, key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if provider != "openrouter" {
		panic(provider)
	}
	s.user, s.agent, s.key = user, agent, key
	return nil
}
func TestOpenRouterSignInAndOwnership(t *testing.T) {
	var mu sync.Mutex
	var body map[string]any
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		_ = json.NewDecoder(r.Body).Decode(&body)
		_, _ = w.Write([]byte(`{"key":"secret-key"}`))
	}))
	defer remote.Close()
	store := &savedSecret{}
	f := NewFlows(store)
	f.Client = remote.Client()
	f.AuthURL = remote.URL + "/auth"
	f.ExchangeURL = remote.URL + "/keys"
	started, err := f.Begin(context.Background(), "openrouter", 7, "agent", "https://agent.example")
	if err != nil {
		t.Fatal(err)
	}
	state := started["state"].(string)
	u, _ := url.Parse(started["url"].(string))
	if started["mode"] != "redirect" || u.Query().Get("state") != state || u.Query().Get("code_challenge_method") != "S256" {
		t.Fatal(started)
	}
	if _, ok := f.Status(state, 8); ok {
		t.Fatal("flow visible to another user")
	}
	if _, err := f.Complete(context.Background(), state, "code", 8); err == nil {
		t.Fatal("another user completed flow")
	}
	result, err := f.Complete(context.Background(), state, "code", 7)
	if err != nil || result["status"] != "completed" {
		t.Fatal(result, err)
	}
	store.mu.Lock()
	if store.user != 7 || store.agent != "agent" || store.key != "secret-key" {
		t.Fatal(store)
	}
	store.mu.Unlock()
	mu.Lock()
	if body["code"] != "code" || body["code_verifier"] == "" || body["code_challenge_method"] != "S256" {
		t.Fatal(body)
	}
	mu.Unlock()
	if result, ok := f.Status(state, 7); !ok || result["status"] != "completed" {
		t.Fatal(result, ok)
	}
	if _, ok := f.Status(state, 7); ok {
		t.Fatal("completion consumed twice")
	}
}
func TestHeadlessFlowCanRetryFailedExchange(t *testing.T) {
	var count int
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count++
		if count == 1 {
			w.WriteHeader(400)
			_, _ = w.Write([]byte(`{"error":"bad code"}`))
			return
		}
		_, _ = w.Write([]byte(`{"key":"key"}`))
	}))
	defer remote.Close()
	f := NewFlows(&savedSecret{})
	f.Client = remote.Client()
	f.AuthURL = remote.URL
	f.ExchangeURL = remote.URL
	started, err := f.Begin(context.Background(), "openrouter", 1, "main", "http://public.example")
	if err != nil {
		t.Fatal(err)
	}
	state := started["state"].(string)
	if started["mode"] != "code" || strings.Contains(started["url"].(string), "callback_url") {
		t.Fatal(started)
	}
	if _, err = f.Complete(context.Background(), state, "bad", 1); err == nil {
		t.Fatal("expected failed exchange")
	}
	if _, err = f.Complete(context.Background(), state, "good", 1); err != nil {
		t.Fatal(err)
	}
}
