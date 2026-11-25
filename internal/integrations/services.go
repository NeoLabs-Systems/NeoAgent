package integrations

import (
	"context"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

const defaultPort = 3333

// Services are the dependencies every provider and the Manager share.
type Services struct {
	DB  *dbx.DB
	Box *secretbox.Box
	// Getenv reads the environment; nil is os.Getenv.
	Getenv func(string) string
	// HTTP reaches the providers; nil is an SSRF-safe client.
	HTTP *http.Client
	// SelfHosted reaches servers the person runs themselves (a Nextcloud or
	// DAV server, often on the local network); nil is NewSelfHostedClient.
	// It never follows redirects.
	SelfHosted *http.Client
	Now        func() time.Time

	once   sync.Once
	agents agentscope.Resolver
}

// NewServices fills in the defaults.
func NewServices(db *dbx.DB, box *secretbox.Box) *Services {
	return &Services{DB: db, Box: box}
}

// init fills in the defaults on first use; the fields are final from then on.
func (s *Services) init() {
	s.once.Do(func() {
		if s.Getenv == nil {
			s.Getenv = os.Getenv
		}
		if s.HTTP == nil {
			s.HTTP = ssrf.NewClient(ssrf.Options{})
		}
		if s.SelfHosted == nil {
			s.SelfHosted = NewSelfHostedClient()
		}
		if s.Now == nil {
			s.Now = time.Now
		}
		s.agents = agentscope.Resolver{DB: s.DB}
	})
}

// Client is the bounded JSON client providers report errors through under
// service.
func (s *Services) Client(service string) *oauthclient.Client {
	s.init()
	return &oauthclient.Client{
		HTTP: s.HTTP, Service: service,
		TimeoutCode: "INTEGRATION_HTTP_TIMEOUT", TooLargeCode: "INTEGRATION_RESPONSE_TOO_LARGE",
	}
}

// SelfHostedClient is Client over the self-hosted transport.
func (s *Services) SelfHostedClient(service string) *oauthclient.Client {
	s.init()
	return &oauthclient.Client{
		HTTP: s.SelfHosted, Service: service,
		TimeoutCode: "INTEGRATION_HTTP_TIMEOUT", TooLargeCode: "INTEGRATION_RESPONSE_TOO_LARGE",
	}
}

// Env reads an environment variable as it is.
func (s *Services) Env(name string) string {
	s.init()
	return s.Getenv(name)
}

func (s *Services) env(name string) string {
	s.init()
	return strings.TrimSpace(s.Getenv(name))
}

// PublicBaseURL is how browsers reach this server: PUBLIC_URL, or localhost.
func (s *Services) PublicBaseURL() string {
	if explicit := s.env("PUBLIC_URL"); explicit != "" {
		return strings.TrimSuffix(explicit, "/")
	}
	scheme := strings.ToLower(s.env("PUBLIC_URL_SCHEME"))
	if scheme == "" {
		scheme = "https"
		if s.env("NODE_ENV") == "development" {
			scheme = "http"
		}
	}
	port := s.env("PORT")
	if port == "" {
		port = strconv.Itoa(defaultPort)
	}
	return scheme + "://localhost:" + port
}

// ResolveAgent maps a requested agent (id, slug or empty) to one of the
// account's agents.
func (s *Services) ResolveAgent(ctx context.Context, userID int64, candidate string) (string, error) {
	s.init()
	return s.agents.Resolve(ctx, userID, candidate)
}

// Seal and Open store credentials the way Node's secrets.js does.
func (s *Services) Seal(plain string) (string, error) { return s.Box.Seal(plain) }

func (s *Services) Open(stored string) (string, error) { return s.Box.Open(stored) }

// OAuthConfig is the OAuth client an integration signs accounts in with.
type OAuthConfig struct {
	ClientID     string
	ClientSecret string
	RedirectURI  string
	Configured   bool
	Missing      []string
	// Source is "server" (environment) or "user" (the account's own app).
	Source string
	// Fields are the extra settings of the provider (a Microsoft tenant).
	Fields map[string]string
}

// serverOAuthConfig reads <PREFIX>_OAUTH_CLIENT_ID / _CLIENT_SECRET / _REDIRECT_URI.
func (s *Services) serverOAuthConfig(prefix string) OAuthConfig {
	prefix = strings.ToUpper(strings.TrimSpace(prefix))
	cfg := OAuthConfig{
		ClientID:     s.env(prefix + "_OAUTH_CLIENT_ID"),
		ClientSecret: s.env(prefix + "_OAUTH_CLIENT_SECRET"),
		RedirectURI:  s.env(prefix + "_OAUTH_REDIRECT_URI"),
		Missing:      []string{},
	}
	if cfg.RedirectURI == "" {
		cfg.RedirectURI = s.PublicBaseURL() + "/api/integrations/oauth/callback"
	}
	if cfg.ClientID == "" {
		cfg.Missing = append(cfg.Missing, prefix+"_OAUTH_CLIENT_ID")
	}
	if cfg.ClientSecret == "" {
		cfg.Missing = append(cfg.Missing, prefix+"_OAUTH_CLIENT_SECRET")
	}
	cfg.Configured = len(cfg.Missing) == 0
	return cfg
}
