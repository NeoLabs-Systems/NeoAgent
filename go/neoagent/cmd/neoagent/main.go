// Command neoagent is the NeoAgent server. This is the Go port in progress:
// it serves the hardened HTTP stack, sessions, health and the web clients; the
// remaining domains move over route by route (see GO_MIGRATION_PLAN.md).
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/httpserver"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/runtimecfg"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

var version = "dev"

func main() {
	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	if err := run(log); err != nil {
		log.Error("neoagent stopped", "error", err)
		os.Exit(1)
	}
}

func run(log *slog.Logger) error {
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

	handler := httpserver.New(httpserver.Deps{Config: cfg, Sessions: sessions, Log: log})
	srv := httpserver.NewHTTPServer(":"+strconv.Itoa(cfg.Port), handler, log)

	errc := make(chan error, 1)
	go func() {
		startup := cfg.PublicURL
		if startup == "" {
			startup = "http://localhost:" + strconv.Itoa(cfg.Port)
		}
		log.Info("NeoAgent running", "url", startup, "version", version)
		errc <- srv.ListenAndServe()
	}()

	select {
	case err := <-errc:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	}
	return nil
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
