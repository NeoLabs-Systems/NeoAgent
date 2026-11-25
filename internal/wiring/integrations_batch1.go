package wiring

import (
	"context"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/credentials"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/bitwarden"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/email"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/news"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/nextcloud"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/trello"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/weather"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

// integrationsBatch1 holds the integrations that connect without OAuth
// (Email & Calendar, Nextcloud, Trello, Bitwarden, World News, Weather) and
// the credential broker the Bitwarden vault backs.
type integrationsBatch1 struct {
	cli       *bitwarden.CLI
	bitwarden *bitwarden.Provider
	broker    *credentials.Broker
}

// addIntegrationsBatch1 registers the providers in the order the apps list
// them after the OAuth providers.
func addIntegrationsBatch1(providers *[]integrations.Provider, svc *integrations.Services, db *dbx.DB, box *secretbox.Box, dataDir string) *integrationsBatch1 {
	b := &integrationsBatch1{cli: &bitwarden.CLI{DataDir: dataDir, Sealer: box}}
	b.cli.Start()
	b.broker = credentials.New(credentials.Config{DB: db, Box: box, Agents: agentscope.Resolver{DB: db}, Vault: b.cli, Requester: safeRequester{client: ssrf.NewClient(ssrf.Options{})}})
	b.bitwarden = bitwarden.New(svc, b.cli, b.broker)
	*providers = append(*providers,
		b.bitwarden,
		email.New(svc),
		news.New(svc),
		nextcloud.New(svc),
		trello.New(svc),
		weather.New(svc),
	)
	return b
}

// routes mounts the Bitwarden vault routes next to the integrations routes.
type batch1Routes struct {
	api *integrations.API
	b   *integrationsBatch1
}

func (r batch1Routes) Routes(mux *http.ServeMux) {
	bitwarden.Routes(mux, r.api, r.b.bitwarden, r.b.broker)
}

// safeRequester sends the broker's bound requests through the SSRF-safe
// client and strips what could echo or set a credential.
type safeRequester struct{ client *http.Client }

var strippedHeaders = map[string]bool{"set-cookie": true, "set-cookie2": true, "www-authenticate": true, "proxy-authenticate": true}

const defaultBrokerResponseBytes = 1 << 20

func (s safeRequester) Do(ctx context.Context, req credentials.Request) (credentials.Response, error) {
	timeout := req.Timeout
	if timeout <= 0 {
		timeout = 30 * time.Second
	}
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	var body io.Reader
	if req.Body != nil {
		body = strings.NewReader(*req.Body)
	}
	httpReq, err := http.NewRequestWithContext(ctx, req.Method, req.URL, body)
	if err != nil {
		return credentials.Response{}, err
	}
	for k, v := range req.Headers {
		httpReq.Header.Set(k, v)
	}
	resp, err := s.client.Do(httpReq)
	if err != nil {
		return credentials.Response{}, err
	}
	defer resp.Body.Close()
	limit := req.MaxResponseBytes
	if limit <= 0 {
		limit = defaultBrokerResponseBytes
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, int64(limit)+1))
	if err != nil {
		return credentials.Response{}, err
	}
	truncated := len(data) > limit
	if truncated {
		data = data[:limit]
	}
	headers := map[string]string{}
	for k, v := range resp.Header {
		name := strings.ToLower(k)
		if !strippedHeaders[name] {
			headers[name] = strings.Join(v, ", ")
		}
	}
	return credentials.Response{Status: resp.StatusCode, Headers: headers, Body: string(data), Truncated: truncated}, nil
}

// nodeProviderDirs are the folders the Node registry loads providers from;
// it lists them in folder-name order, and the apps show that order.
var nodeProviderDirs = map[string]string{
	"google_workspace": "google", "microsoft_365": "microsoft", "whatsapp_personal": "whatsapp",
}

// sortProvidersLikeNode orders providers as the Node registry did.
func sortProvidersLikeNode(providers []integrations.Provider) {
	dir := func(p integrations.Provider) string {
		k := p.Info().Key
		if d, ok := nodeProviderDirs[k]; ok {
			return d
		}
		return k
	}
	sort.SliceStable(providers, func(i, j int) bool { return dir(providers[i]) < dir(providers[j]) })
}
