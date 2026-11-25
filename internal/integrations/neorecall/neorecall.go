// Package neorecall implements the NeoRecall integration: a self-hosted
// NeoRecall server connected through the companion OAuth contract, with
// read-only tools over the person's memories, summaries and transcripts.
package neorecall

import (
	"context"
	_ "embed"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/companion"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

//go:embed provider.json
var specJSON []byte

var scopes = []string{"search:read", "memories:read", "recordings:read"}

// Options are the seams; the zero value is production.
type Options struct {
	// HTTP reaches the server; nil allows private addresses, as NeoRecall is
	// usually self-hosted on the person's own network.
	HTTP *http.Client
	Now  func() time.Time
}

type provider struct {
	*companion.Provider
	server companion.Server
}

// New builds the provider.
func New(svc *integrations.Services, o Options) integrations.Provider {
	client := o.HTTP
	if client == nil {
		client = ssrf.NewClient(ssrf.Options{AllowPrivate: true})
	}
	p := &provider{server: companion.Server{Label: "NeoRecall", URLLabel: "NeoRecall backend URL", HTTP: client, Now: o.Now}}
	p.Provider = companion.NewProvider(svc, companion.Product{
		Spec:           integrations.LoadSpec(specJSON),
		Server:         p.server,
		ReadySummary:   "NeoRecall is ready for account connections.",
		MissingSummary: "Add the NeoRecall backend URL to enable personal recall tools.",
		HealthCheck:    healthCheck,
		// Bootstrap may narrow the scopes it hands out.
		AuthorizeScope: func(boot map[string]any) string {
			if list, ok := boot["scopes"].([]any); ok {
				parts := make([]string, len(list))
				for i, s := range list {
					parts[i] = integrations.Str(s)
				}
				return strings.Join(parts, " ")
			}
			return strings.Join(scopes, " ")
		},
		GrantedScopes: func(issued, _ map[string]any) ([]string, string, error) {
			return companion.SplitScopes(issued["scope"]), companion.Text(issued["scope"]), nil
		},
		Execute:   p.execute,
		Summarize: summarize,
	})
	return p
}

func healthCheck(ctx context.Context, s companion.Server, baseURL string) error {
	health, _, err := s.Fetch(ctx, "NeoRecall health check", oauthclient.Request{Method: "GET", URL: baseURL + "/health"})
	if err != nil {
		return err
	}
	if companion.Text(health["status"]) != "ok" || companion.Text(health["process"]) != "http" {
		return errors.New("The configured endpoint did not identify itself as a healthy NeoRecall HTTP service.")
	}
	return nil
}

func summarize(s integrations.Snapshot) string {
	switch {
	case !s.Env.Configured:
		return "NeoRecall: setup is not complete yet."
	case !s.Connection.Connected:
		return "NeoRecall: setup is ready, but no recall account is connected."
	}
	return strings.Join([]string{
		"NeoRecall: connected. Treat it as the source of truth for the user's lived day,",
		"conversations, people, promises, and personal facts captured by NeoRecall.",
		"When the user asks what happened today/yesterday/this week, what they discussed,",
		"who they met, or any personal recall question, use NeoRecall tools before guessing.",
		"Start with neorecall_list_daily_summaries for calendar-day questions,",
		"neorecall_list_conversations or neorecall_list_memories with from/to for a date window,",
		"and neorecall_search for open-ended recall. Pull transcript evidence with",
		"neorecall_get_conversation or neorecall_get_memory when detail is needed.",
	}, " ")
}

// filtered is the named arguments the person gave (null, absent and empty
// strings are left out), in the order named.
func filtered(args map[string]any, names ...string) companion.Ordered {
	out := companion.Ordered{}
	for _, n := range names {
		v, ok := args[n]
		if !ok || v == nil || v == "" {
			continue
		}
		out = append(out, [2]any{n, v})
	}
	return out
}

func apiPath(name string, args map[string]any) (string, error) {
	switch name {
	case "neorecall_search":
		var kinds any
		if list, ok := args["kinds"].([]any); ok {
			var parts []string
			for _, k := range list {
				if t := companion.Text(k); t != "" {
					parts = append(parts, t)
				}
			}
			kinds = strings.Join(parts, ",")
		}
		q, err := companion.Required(args["query"], "query")
		if err != nil {
			return "", err
		}
		return companion.AppendQuery("/api/v1/search", companion.Ordered{{"q", q}, {"kinds", kinds}, {"limit", args["limit"]}}), nil
	case "neorecall_list_memories":
		return companion.AppendQuery("/api/v1/memories", filtered(args, "type", "topic", "from", "to", "pinned", "archived", "limit")), nil
	case "neorecall_get_memory":
		id, err := companion.Required(args["memory_id"], "memory_id")
		return "/api/v1/memories/" + companion.EncodeComponent(id), err
	case "neorecall_list_mini_memories":
		return companion.AppendQuery("/api/v1/mini-memories", filtered(args, "kind", "status", "limit")), nil
	case "neorecall_list_daily_summaries":
		return companion.AppendQuery("/api/v1/daily-summaries", filtered(args, "from", "to", "limit")), nil
	case "neorecall_list_conversations":
		return companion.AppendQuery("/api/v1/conversations", filtered(args, "state", "from", "to", "limit")), nil
	case "neorecall_get_conversation":
		id, err := companion.Required(args["conversation_id"], "conversation_id")
		return "/api/v1/conversations/" + companion.EncodeComponent(id), err
	}
	return "", fmt.Errorf("Unsupported NeoRecall tool: %s", name)
}

func (p *provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	path, err := apiPath(name, args)
	if err != nil {
		return nil, err
	}
	auth, err := p.server.Authenticate(ctx, tc.Credentials)
	if err != nil {
		return nil, err
	}
	_, value, err := p.server.Fetch(ctx, "NeoRecall API", oauthclient.Request{
		URL: auth.BaseURL + path, Header: map[string]string{"Authorization": "Bearer " + auth.AccessToken},
	})
	if err != nil {
		return nil, err
	}
	if auth.Refreshed {
		tc.UpdateCredentials(auth.Credentials)
	}
	return value, nil
}
