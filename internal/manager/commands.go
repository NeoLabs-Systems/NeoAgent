package manager

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

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
		{Name: "help", Aliases: []string{"--help", "-h"}, Usage: "help", Summary: "Show this list", Run: func(context.Context, []string) error {
			a.printHelp(a.Out)
			return nil
		}},
	}
}

func (a *App) printHelp(w io.Writer) {
	fmt.Fprintf(w, "\n  %s %s\n\n  Usage: neoagent <command>\n\n%s\n", appName, version(), cli.Help(a.commands()))
}

// Run executes one CLI command. The caller handles serve and healthcheck,
// and passes how to build the application for exec and migrate.
func Run(ctx context.Context, args []string, boot Booter) error {
	a, err := New(args)
	if err != nil {
		return err
	}
	a.boot = boot
	if len(args) == 0 {
		a.printHelp(a.Out)
		return nil
	}
	if o, perr := ParseSetupArguments(args[1:]); (args[0] == "install" || args[0] == "setup") && perr == nil && o.Profile != "" {
		a.Events.Profile = o.Profile
	}
	if err := a.Paths.Ensure(); err != nil {
		return err
	}
	cmd := cli.Find(a.commands(), args[0])
	if cmd == nil || cmd.Run == nil {
		return fmt.Errorf("%q isn't a neoagent command. Run `neoagent help` to see what you can do.", args[0])
	}
	return cmd.Run(ctx, args[1:])
}

// ReportError prints a failed command: a JSON failure event when --json is
// set and none was emitted yet, otherwise a readable message.
func ReportError(args []string, err error) {
	var emitted eventEmitted
	if errors.As(err, &emitted) {
		if !cli.HasFlag(args, "--json") {
			fmt.Fprintln(os.Stderr, "\n  ✕ "+strings.ReplaceAll(err.Error(), "\n", "\n    "))
		}
		return
	}
	if cli.HasFlag(args, "--json") {
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
	if errors.Is(err, cli.ErrCancelled) {
		fmt.Fprintln(os.Stderr, "  Cancelled. Nothing was changed.")
		return
	}
	fmt.Fprintln(os.Stderr, "\n  ✕ "+strings.ReplaceAll(err.Error(), "\n", "\n    ")+"\n")
}
