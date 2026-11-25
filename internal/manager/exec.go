package manager

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/wiring"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
)

// Booter builds NeoAgent without its HTTP listener and hands it to use;
// start also runs its background services. cmd/neoagent provides it, since it
// owns the server's construction.
type Booter func(ctx context.Context, start bool, use func(ctx context.Context, app *wiring.App) error) error

func (a *App) command(ctx context.Context, rt installedRuntime, args ...string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, rt.binary(), args...)
	cmd.Dir = rt.appDir()
	cmd.Env = append(os.Environ(), "NEOAGENT_HOME="+a.Paths.Home, "NEOAGENT_APP_DIR="+rt.appDir())
	return cmd
}

type execOptions struct {
	Instruction, Model, Provider, Agent, Cwd string
	AllowAllTools, Yes                       bool
}

func parseExecArguments(args []string) (execOptions, error) {
	var o execOptions
	valued := map[string]*string{"--model": &o.Model, "--provider": &o.Provider, "--agent": &o.Agent, "--cwd": &o.Cwd}
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--json":
		case arg == "--allow-all-tools":
			o.AllowAllTools = true
		case arg == "--yes" || arg == "-y":
			o.Yes = true
		case valued[arg] != nil:
			if i+1 >= len(args) || strings.HasPrefix(args[i+1], "--") {
				return o, fmt.Errorf("Usage: neoagent exec %s <value> \"<instruction>\"", arg)
			}
			*valued[arg] = args[i+1]
			i++
		case strings.HasPrefix(arg, "--"):
			return o, fmt.Errorf("Unknown option: %s. Run \"neoagent help\" for usage.", arg)
		case o.Instruction != "":
			return o, fmt.Errorf("Usage: neoagent exec [options] \"<instruction>\"")
		default:
			o.Instruction = arg
		}
	}
	if o.Instruction == "" {
		return o, fmt.Errorf("Usage: neoagent exec [options] \"<instruction>\"")
	}
	return o, nil
}

// confirmLocalExecution says once that exec runs the agent's shell and file
// tools on this computer when TERMINAL_ENV=host.
func (a *App) confirmLocalExecution(skip bool) error {
	ack := filepath.Join(a.Paths.Home, "exec-acknowledged")
	if skip || exists(ack) {
		return nil
	}
	warning := "neoagent exec runs commands and edits files directly on this computer, with no virtual machine in between."
	if !a.UI.Interactive() {
		return fmt.Errorf("%s Re-run with --yes to confirm.", warning)
	}
	a.UI.Warn(warning)
	ok, err := a.UI.Confirm("Continue and remember this choice?", false)
	if err != nil {
		return err
	}
	if !ok {
		return cli.ErrCancelled
	}
	return os.WriteFile(ack, []byte(cli.ISOTime(time.Now())+"\n"), 0o600)
}

func (a *App) cmdExec(ctx context.Context, args []string) error {
	o, err := parseExecArguments(args)
	if err != nil {
		return err
	}
	if a.boot == nil {
		return fmt.Errorf("neoagent exec is not available in this build")
	}
	if err := a.confirmLocalExecution(o.Yes); err != nil {
		return err
	}
	// Nobody is there to answer an approval, so a headless run opts out of
	// the approval gate explicitly or blocks on it. Only for this process.
	if o.AllowAllTools {
		os.Setenv("NEOAGENT_TOOL_SECURITY_MODE", "allow_all")
	}
	root := o.Cwd
	if root == "" {
		root, _ = os.Getwd()
	}
	if root, err = filepath.Abs(root); err != nil {
		return err
	}
	var result agent.Result
	err = a.boot(ctx, true, func(ctx context.Context, app *wiring.App) (err error) {
		result, err = app.RunHeadless(ctx, wiring.HeadlessRequest{
			Instruction: o.Instruction, Model: o.Model, Provider: o.Provider, AgentSlug: o.Agent, WorkspaceRoot: root,
			Log: func(line string) { fmt.Fprintln(os.Stderr, line) },
		})
		return err
	})
	if err != nil {
		return err
	}
	if a.JSON {
		if err := cli.WriteJSONLine(a.Out, result); err != nil {
			return err
		}
	} else if result.Content != "" {
		fmt.Fprintln(a.Out, result.Content)
	}
	if result.Status != "completed" {
		status := orDefault(result.Status, "failed")
		if result.Error != "" {
			return fmt.Errorf("Run %s: %s", status, result.Error)
		}
		return fmt.Errorf("Run %s", status)
	}
	return nil
}
