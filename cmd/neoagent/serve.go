package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/admin"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/authapi"
	"github.com/NeoLabs-Systems/neoagent/internal/buildinfo"
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/httpserver"
	"github.com/NeoLabs-Systems/neoagent/internal/providersignin"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neoagent/internal/wiring"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/lockout"
	"github.com/NeoLabs-Systems/neolabs-go/oauthlogin"
	"github.com/NeoLabs-Systems/neolabs-go/pairing"
	"github.com/NeoLabs-Systems/neolabs-go/qrlogin"
	"github.com/NeoLabs-Systems/neolabs-go/runtimecfg"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/servicemail"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
	"github.com/NeoLabs-Systems/neolabs-go/webauthnx"
)

// stack is the running application without its HTTP listener.
type stack struct {
	cfg      config.Config
	sessions *sessionx.Manager
	auth     *authapi.API
	app      *wiring.App
	log      *slog.Logger
}

// withApp builds everything the server runs (config, databases, domains;
// with start also the background services) and hands it to use until
// SIGINT/SIGTERM or use returns. serve adds the HTTP listener; `neoagent
// exec` runs one task and `neoagent migrate` imports without starting.
func withApp(log *slog.Logger, start bool, use func(ctx context.Context, s *stack) error) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("find home directory: %w", err)
	}
	cwd, err := os.Getwd()
	if err != nil {
		return err
	}
	// The env file fills in what the real environment does not set.
	preliminary := runtimecfg.Resolve("NEOAGENT", ".neoagent", os.Getenv, home)
	if err := runtimecfg.LoadEnvFile(preliminary.EnvFile, os.LookupEnv, os.Setenv); err != nil {
		return fmt.Errorf("load %s: %w", preliminary.EnvFile, err)
	}

	cfg, err := config.Load(os.Getenv, home, cwd)
	if err != nil {
		return err
	}
	if err := cfg.Paths.Ensure(); err != nil {
		return err
	}
	if cfg.EphemeralSessionSecret {
		log.Warn("SESSION_SECRET is not set; using a random secret, so sign-ins end on restart")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	sessionsDB, err := dbx.Open(ctx, filepath.Join(cfg.Paths.DataDir, "sessions.db"), dbx.Options{})
	if err != nil {
		return err
	}
	defer sessionsDB.Close()
	store, err := sessionx.NewStore(ctx, sessionsDB.W)
	if err != nil {
		return err
	}
	sessions, err := sessionx.NewManager(store, sessionx.Options{
		Name:       config.CookieName,
		Secrets:    []string{cfg.SessionSecret},
		MaxAge:     30 * 24 * time.Hour,
		Secure:     cfg.SecureCookie,
		TrustProxy: cfg.TrustProxy,
		Rolling:    true,
	})
	if err != nil {
		return err
	}
	go sweepSessions(ctx, store, log)

	mainDB, err := dbx.Open(ctx, filepath.Join(cfg.Paths.DataDir, "neoagent.db"), dbx.Options{})
	if err != nil {
		return err
	}
	defer mainDB.Close()
	if err := schema.Ensure(ctx, mainDB.W); err != nil {
		return err
	}

	// Stored credentials need an encryption key; without one two-factor
	// enrolment refuses, everything else works.
	box, boxErr := config.SecretBox(os.Getenv)
	if boxErr != nil {
		log.Warn("no encryption key configured; two-factor enrolment is unavailable", "reason", boxErr)
	}
	users := &accounts.Repo{DB: mainDB, OpenSignup: func() bool { return !admin.SignupKeyRequired() }, AdminUsers: cfg.AdminUsers}
	throttle := lockout.Store{DB: mainDB.W}
	auth := &authapi.API{
		Cfg:       cfg,
		Users:     users,
		TwoFactor: &accounts.TwoFactor{DB: mainDB, Box: box, Lockout: throttle, Issuer: "NeoAgent"},
		Passkeys: &webauthnx.Service{
			RPName: "NeoAgent", Origins: cfg.Origins, TrustProxy: cfg.TrustProxy,
			Store: &accounts.PasskeyStore{DB: mainDB}, Accounts: accounts.PasskeyAccounts{Repo: users},
		},
		Records:  &accounts.SessionRecords{DB: mainDB, Store: store, Secret: cfg.SessionSecret, TrustProxy: cfg.TrustProxy},
		Sessions: sessions,
		Lockout:  throttle,
		Log:      log,
	}
	auth.Tokens = servicemail.Tokens{DB: mainDB.W}
	auth.Mail = servicemail.Sender{Cfg: cfg.Mail}
	auth.QR = &qrlogin.Store{DB: mainDB}
	auth.Pairing = &pairing.Store{DB: mainDB, Scheme: "neoagent"}
	if box != nil {
		auth.OAuth = &oauthlogin.Engine{
			DB: mainDB, Box: box, Product: "NeoAgent",
			Providers: []oauthlogin.Provider{oauthlogin.Google{Cfg: cfg.Google}, openRouterSignIn(mainDB, box)},
			Accounts:  accounts.ProviderAccounts{Repo: users},
		}
	}
	if err := auth.Init(); err != nil {
		return err
	}

	app, err := wiring.Build(ctx, wiring.Deps{
		Cfg:            cfg,
		DB:             mainDB,
		Sessions:       sessions,
		Store:          store,
		Box:            box,
		Users:          users,
		Records:        auth.Records,
		BindOAuthState: authapi.BindOAuthState,
		Version:        buildinfo.Version,
		Log:            log,
	})
	if err != nil {
		return err
	}
	auth.IntegrationOAuth = app.IntegrationOAuth
	auth.ModelOAuth = app.ModelOAuth
	applyAdminGrants(ctx, app.Admin, cfg.AdminUsers, log)
	if start {
		if err := app.Start(ctx); err != nil {
			return err
		}
		defer app.Stop()
	}
	return use(ctx, &stack{cfg: cfg, sessions: sessions, auth: auth, app: app, log: log})
}

// serve runs the server until SIGINT/SIGTERM.
// The background services start after the listener is up (as the Node server
// did), so the server answers at once even when reconnecting chats, MCP
// servers and interrupted runs takes a while.
func serve(log *slog.Logger) error { return withApp(log, false, serveHTTP) }

func serveHTTP(ctx context.Context, s *stack) error {
	cfg, sessions, auth, app, log := s.cfg, s.sessions, s.auth, s.app, s.log

	handler := httpserver.New(httpserver.Deps{
		Config: cfg, Sessions: sessions, Auth: auth, Log: log,
		Routes: app.Routes, RuntimeValidation: app.RuntimeValidation, Front: app.Front,
	})
	srv := httpserver.NewHTTPServer(":"+strconv.Itoa(cfg.Port), handler, log)
	ln, err := net.Listen("tcp", srv.Addr)
	if err != nil {
		return err
	}
	errc := make(chan error, 1)
	go func() { errc <- srv.Serve(ln) }()
	startup := cfg.PublicURL
	if startup == "" {
		startup = "http://localhost:" + strconv.Itoa(cfg.Port)
	}
	log.Info("NeoAgent running", "url", startup, "version", buildinfo.Version)

	startCtx, cancelStart := context.WithCancel(ctx)
	defer cancelStart()
	started := make(chan error, 1)
	go func() { started <- app.Start(startCtx) }()
	running := false
	// stop ends the services once their start has returned; App.Start cleans up
	// after itself when it fails.
	stop := func() {
		cancelStart()
		if !running {
			running = <-started == nil
		}
		if running {
			app.Stop()
		}
	}
	shutdown := func() error {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	}
	for {
		select {
		case err := <-started:
			if err != nil {
				_ = shutdown()
				return fmt.Errorf("starting services: %w", err)
			}
			running = true
			started = nil
		case err := <-errc:
			stop()
			if errors.Is(err, http.ErrServerClosed) {
				return nil
			}
			return err
		case <-ctx.Done():
			err := shutdown()
			stop()
			return err
		}
	}
}

// applyAdminGrants grants admin to the accounts named in NEOAGENT_ADMIN_USERS on
// every start, and says what an operator needs to know.
func applyAdminGrants(ctx context.Context, a *admin.API, names []string, log *slog.Logger) {
	got, err := a.Store.ApplyEnvAdminGrants(ctx, names)
	if err != nil {
		log.Error("applying NEOAGENT_ADMIN_USERS failed", "error", err)
		return
	}
	if len(got.Granted) > 0 {
		log.Info("granted admin from NEOAGENT_ADMIN_USERS", "accounts", got.Granted)
	}
	if len(got.Missing) > 0 {
		log.Warn("NEOAGENT_ADMIN_USERS names accounts that do not exist; those names are reserved, remove them to let someone register them", "accounts", got.Missing)
	}
	if len(got.Revoked) > 0 {
		log.Warn("NEOAGENT_ADMIN_USERS lists accounts revoked with the CLI, left as they are; use `neoagent admin grant <username>` to restore them", "accounts", got.Revoked)
	}
	if needs, err := a.Store.NeedsAdminGrant(ctx); err == nil && needs {
		log.Warn("no account is an admin, so nobody can open the Admin tab; run `neoagent admin grant <username>`")
	}
}

// sweepSessions removes expired session rows every 15 minutes.
func sweepSessions(ctx context.Context, store *sessionx.Store, log *slog.Logger) {
	t := time.NewTicker(15 * time.Minute)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if err := store.ClearExpired(ctx); err != nil {
				log.Warn("session sweep failed", "error", err)
			}
		}
	}
}

// openRouterSignIn lets people sign in with OpenRouter; the key it mints
// becomes the account's own OpenRouter key on its main agent.
func openRouterSignIn(db *dbx.DB, box *secretbox.Box) oauthlogin.Provider {
	store := &settings.Store{DB: db, Box: box, Agents: agentscope.Resolver{DB: db}}
	return providersignin.OpenRouterAccount{
		Flows: providersignin.NewFlows(store),
		SaveKey: func(ctx context.Context, userID int64, apiKey string) error {
			agentID, err := store.Agents.Resolve(ctx, userID, "")
			if err != nil {
				return err
			}
			return store.SetProviderSecret(ctx, userID, agentID, "openrouter", apiKey)
		},
	}
}
