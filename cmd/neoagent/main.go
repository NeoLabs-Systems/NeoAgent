// Command neoagent is NeoAgent: `neoagent serve` runs the server (what the
// service, the container and a plain `neoagent` without arguments start), and
// every other subcommand manages the installation (see `neoagent help`).
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/NeoLabs-Systems/neoagent/internal/manager"
	"github.com/NeoLabs-Systems/neoagent/internal/wiring"
)

func main() {
	args := os.Args[1:]
	if len(args) == 0 || args[0] == "serve" || (args[0] == "start" && len(args) > 1 && args[1] == "--foreground") {
		log := slog.New(slog.NewTextHandler(os.Stderr, nil))
		if err := serve(log); err != nil {
			log.Error("neoagent stopped", "error", err)
			os.Exit(1)
		}
		return
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if args[0] == "healthcheck" {
		if err := manager.Healthcheck(ctx, os.Getenv); err != nil {
			os.Exit(1)
		}
		return
	}
	boot := func(_ context.Context, start bool, use func(context.Context, *wiring.App) error) error {
		log := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelWarn}))
		return withApp(log, start, func(ctx context.Context, s *stack) error { return use(ctx, s.app) })
	}
	if err := manager.Run(ctx, args, boot); err != nil {
		manager.ReportError(args, err)
		os.Exit(1)
	}
}
