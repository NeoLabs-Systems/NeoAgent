package neorouterapi

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

// EnvStore reads and persists server-wide environment settings.
type EnvStore interface {
	Get(key string) string
	Set(key, value string) error
}

// SettingsStore reads and updates per-user/agent NeoRouter and voice settings.
type SettingsStore interface {
	NeoRouter(ctx context.Context, userID int64, agentID string) (apiKey, baseURL string, roles any, err error)
	SaveUserNeoRouter(ctx context.Context, userID int64, agentID, baseURL, apiKey string, roles []string, enableSystemOne bool) error
	ClearUserNeoRouter(ctx context.Context, userID int64, agentID string) error
	UpdateUserRoles(ctx context.Context, userID int64, agentID string, roles []string) error
	GetVoiceLiveProvider(ctx context.Context, userID int64, agentID string) (string, error)
	SetVoiceLiveProvider(ctx context.Context, userID int64, agentID, provider string) error
	IsLiveProviderUsable(ctx context.Context, scope string, userID int64, agentID, provider string) (bool, error)
}

// Accounts provides user admin status and agent ID resolution.
type Accounts interface {
	IsAdmin(ctx context.Context, userID int64) bool
	ResolveAgentID(ctx context.Context, userID int64, rawAgentID string) string
}

// Config configures the NeoRouter service.
type Config struct {
	Env        EnvStore
	Settings   SettingsStore
	Accounts   Accounts
	HTTPClient *http.Client
	Checker    *cloudsec.Checker
	Now        func() time.Time
	Hostname   func() (string, error)
	Log        *slog.Logger
}

// Service manages NeoRouter connections, offers, device sign-in, and API calls.
type Service struct {
	env         EnvStore
	settings    SettingsStore
	accounts    Accounts
	http        *http.Client
	trustedHTTP *http.Client
	checker     *cloudsec.Checker
	now         func() time.Time
	hostname    func() (string, error)
	log         *slog.Logger

	offerMu    sync.Mutex
	offerCache map[string]cachedOffer

	flowMu sync.Mutex
	flows  map[string]*signInFlow

	ctxMu  sync.Mutex
	ctx    context.Context
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

type nopEnv struct{}

func (nopEnv) Get(string) string        { return "" }
func (nopEnv) Set(string, string) error { return nil }

// New creates a NeoRouter Service.
func New(cfg Config) *Service {
	env := cfg.Env
	if env == nil {
		env = nopEnv{}
	}
	httpClient := cfg.HTTPClient
	if httpClient == nil {
		httpClient = ssrf.NewClient(ssrf.Options{Timeout: 30 * time.Second})
	}
	trustedHTTP := cfg.HTTPClient
	if trustedHTTP == nil {
		trustedHTTP = ssrf.NewClient(ssrf.Options{Timeout: 30 * time.Second, AllowPrivate: true})
	}
	checker := cfg.Checker
	if checker == nil {
		checker = &cloudsec.Checker{}
	}
	now := cfg.Now
	if now == nil {
		now = time.Now
	}
	hostname := cfg.Hostname
	if hostname == nil {
		hostname = os.Hostname
	}
	log := cfg.Log
	if log == nil {
		log = slog.Default()
	}
	ctx, cancel := context.WithCancel(context.Background())
	return &Service{
		env:         env,
		settings:    cfg.Settings,
		accounts:    cfg.Accounts,
		http:        httpClient,
		trustedHTTP: trustedHTTP,
		checker:     checker,
		now:         now,
		hostname:    hostname,
		log:         log,
		offerCache:  make(map[string]cachedOffer),
		flows:       make(map[string]*signInFlow),
		ctx:         ctx,
		cancel:      cancel,
	}
}

// Start satisfies the optional lifecycle contract.
func (s *Service) Start(ctx context.Context) error {
	s.ctxMu.Lock()
	defer s.ctxMu.Unlock()
	if s.ctx == nil || s.ctx.Err() != nil {
		s.ctx, s.cancel = context.WithCancel(ctx)
	}
	return nil
}

// Stop cancels any in-flight device-flow pollers and waits for them to exit.
func (s *Service) Stop() {
	s.ctxMu.Lock()
	cancel := s.cancel
	s.ctxMu.Unlock()
	if cancel != nil {
		cancel()
	}
	s.wg.Wait()
}

func (s *Service) bgContext() context.Context {
	s.ctxMu.Lock()
	defer s.ctxMu.Unlock()
	return s.ctx
}
