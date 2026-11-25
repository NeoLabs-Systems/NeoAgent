package manager

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
)

func (a *App) commands() []cli.Command {
	return []cli.Command{
		{Name: "install", Usage: "install [--quick|--full]", Summary: "Set NeoAgent up and start it with this computer", Run: a.cmdInstall},
		{Name: "setup", Usage: "setup [--quick|--full|--resume]", Summary: "Change settings (address, AI, integrations, voice)", Run: a.cmdSetup},
		{Name: "start", Usage: "start", Summary: "Start NeoAgent", Run: a.cmdStart},
		{Name: "stop", Usage: "stop", Summary: "Stop NeoAgent", Run: a.cmdStop},
		{Name: "restart", Usage: "restart", Summary: "Restart NeoAgent", Run: a.cmdRestart},
		{Name: "status", Usage: "status [--details]", Summary: "Show whether everything works", Run: a.cmdStatus},
		{Name: "doctor", Usage: "doctor", Summary: "Find problems and offer to fix them", Run: a.cmdDoctor},
		{Name: "repair", Aliases: []string{"fix"}, Usage: "repair", Summary: "Back up, check and restart everything", Run: a.cmdRepair},
		{Name: "logs", Usage: "logs", Summary: "Watch what NeoAgent is doing", Run: a.cmdLogs},
		{Name: "update", Usage: "update [stable|beta] [--notes]", Summary: "Get the latest version (your data is kept)", Run: a.cmdUpdate},
		{Name: "channel", Usage: "channel [stable|beta]", Summary: "Show or switch the update channel", Run: a.cmdChannel},
		{Name: "env", Usage: "env [list|get|set|unset]", Summary: "Read and change settings in the .env file", Run: a.cmdEnv},
		{Name: "admin", Usage: "admin [list|grant|revoke] <user>", Summary: "Manage who can open the Admin tab", Run: a.cmdAdmin},
		{Name: "account", Usage: "account create --username --password", Summary: "Create the first account (headless setups)", Run: a.cmdAccount},
		{Name: "reset-password", Usage: "reset-password <username>", Summary: "Set a new password and sign the account out", Run: a.cmdResetPassword},
		{Name: "backup", Usage: "backup", Summary: "Save settings, chats and the agent's computer", Run: a.cmdBackup},
		{Name: "restore", Usage: "restore <backup folder>", Summary: "Put a backup back (current data is saved first)", Run: a.cmdRestore},
		{Name: "login", Usage: "login [claude-code|openai-codex|github-copilot|grok-oauth]", Summary: "Connect an AI account you already have", Run: a.cmdLogin},
		{Name: "messaging", Usage: "messaging [list|setup|disconnect|remove]", Summary: "One shared Telegram bot or WhatsApp number for everyone", Run: a.cmdMessaging},
		{Name: "exec", Usage: `exec [--model M] [--agent A] [--cwd DIR] "<task>"`, Summary: "Run one task without the app", Run: a.cmdExec},
		{Name: "migrate", Usage: "migrate [--yes]", Summary: "Bring over an OpenClaw or Hermes Agent setup", Run: a.cmdMigrate},
		{Name: "rebuild-web", Usage: "rebuild-web", Summary: "Rebuild the browser app from flutter_app (developers)", Run: a.cmdRebuildWeb},
		{Name: "uninstall", Usage: "uninstall", Summary: "Stop starting with this computer (data stays)", Run: a.cmdUninstall},
		{Name: "serve", Usage: "serve", Summary: "Run the server in the foreground"},
		{Name: "healthcheck", Usage: "healthcheck", Summary: "Exit 0 when the server answers (containers)"},
		{Name: "version", Aliases: []string{"--version", "-V"}, Usage: "version", Summary: "Print the version", Run: func(context.Context, []string) error {
			fmt.Fprintln(a.Out, version())
			return nil
		}},
		{Name: "update-runner", Hidden: true, Run: a.cmdUpdateRunner},
		{Name: "repair-runtime", Hidden: true, Run: func(ctx context.Context, _ []string) error { return a.ensureComputerRuntime(ctx, false, false) }},
		{Name: "help", Aliases: []string{"--help", "-h"}, Usage: "help", Summary: "Show this list", Run: func(_ context.Context, args []string) error {
			a.printHelp(cli.HasFlag(args, "--all"))
			return nil
		}},
	}
}

// Run executes one CLI command. The caller handles serve and healthcheck,
// and passes how to build the application for exec and migrate.
func Run(ctx context.Context, args []string, boot Booter) error {
	a, err := New(args)
	if err != nil {
		return err
	}
	a.boot = boot
	if len(args) > 0 && (args[0] == "install" || args[0] == "setup") {
		if o, perr := ParseSetupArguments(args[1:]); perr == nil && o.Profile != "" {
			a.Events.Profile = o.Profile
		}
	}
	if err := a.Paths.Ensure(); err != nil {
		return err
	}
	if len(args) == 0 {
		return a.cmdDefault(ctx)
	}
	cmd := cli.Find(a.commands(), args[0])
	if cmd == nil || cmd.Run == nil {
		return fmt.Errorf("%q isn't a neoagent command. Run `neoagent help` to see what you can do.", args[0])
	}
	return cmd.Run(ctx, args[1:])
}

// ReportError prints a failed command: a JSON failure event when --json is
// set and none was emitted yet, otherwise what happened and what to try.
func ReportError(args []string, err error) {
	if cli.HasFlag(args, "--json") {
		var emitted eventEmitted
		if errors.As(err, &emitted) {
			return
		}
		code := cli.CodeOf(err, "SETUP_FAILED")
		argumentError := code == "SETUP_PROFILE_CONFLICT" || code == "SETUP_REQUIRED_VALUE_MISSING"
		action := "retry"
		if argumentError {
			action = "fix-input"
		}
		profile := "quick"
		if cli.HasFlag(args, "--full") {
			profile = "full"
		}
		_ = cli.WriteJSONLine(os.Stdout, cli.Event{
			SchemaVersion: setupcontract.C.SchemaVersion, RunID: cli.NewUUID(), Profile: profile, Stage: "prepare", State: "failed",
			Error: &cli.EventError{Code: code, Retryable: !argumentError, Action: action, Detail: err.Error()},
		})
		return
	}
	printError(cli.NewUI(false), err, cli.HasFlag(args, "--details"))
}

// cmdDefault is plain `neoagent`: it finishes or starts setup, and otherwise
// shows how NeoAgent is doing and a menu of what to do next.
func (a *App) cmdDefault(ctx context.Context) error {
	if st := a.readState(); st != nil && st.Status != "completed" {
		a.UI.Blank()
		a.UI.Note("Picking up the setup you started earlier.")
		return a.cmdInstall(ctx, []string{"--resume"})
	}
	if !a.installed() {
		if exists(a.Paths.EnvFile) {
			a.UI.Info("Your existing settings in " + a.Paths.EnvFile + " are kept.")
		}
		return a.cmdInstall(ctx, nil)
	}
	f := a.collectStatusFacts(ctx, a.UI.Interactive())
	// Running state and updates are in the header and the menu already.
	var problems []statusCheck
	for _, c := range statusChecks(f) {
		if c.ID != "server" && c.ID != "version" && needsAttention(c) {
			problems = append(problems, c)
		}
	}
	a.printHomeHeader(f, problems)
	a.UI.Blank()
	return a.UI.HomeMenu("neoagent", cli.HomeActions{
		AppName: "NeoAgent", Running: f.Running, UpdateVersion: f.Update,
		SettingsHint: "AI, address, integrations",
		Open:         func() error { openInBrowser(f.URL); return nil },
		Start:        func() error { return a.cmdStart(ctx, nil) },
		Status:       func() error { return a.cmdStatus(ctx, nil) },
		Restart:      func() error { return a.cmdRestart(ctx, nil) },
		Update:       func() error { return a.cmdUpdate(ctx, nil) },
		Settings:     func() error { return a.cmdSetup(ctx, nil) },
		Doctor:       func() error { return a.cmdDoctor(ctx, nil) },
		Help:         func() error { a.printHelp(false); return nil },
	})
}

// installed reports evidence of an existing installation: its data, its
// service definition or a running server.
func (a *App) installed() bool {
	return exists(a.dbPath()) || a.Service.Installed() || len(a.serverProcesses()) > 0
}
