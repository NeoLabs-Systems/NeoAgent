package manager

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	agentruntime "github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

// ensureStartPort settles a port another program holds before starting:
// interactively by moving NeoAgent to the next free port.
func (a *App) ensureStartPort(ctx context.Context) (int, error) {
	port := a.Port()
	if !a.portHeldByOther(ctx, port) {
		return port, nil
	}
	if !a.UI.Interactive() {
		return 0, portInUseError(port)
	}
	a.UI.Blank()
	a.UI.Item("error", a.UI.Bold("NeoAgent couldn't start"), "Nothing is broken — your data is safe.")
	a.UI.Print("  Another app on this computer is already using the address NeoAgent wants (port %d).", port)
	for {
		choice, err := a.UI.Select("What would you like to do?", []cli.Choice{
			{Value: "move", Label: "Use a free address instead", Hint: "NeoAgent moves to the next free port"},
			{Value: "show", Label: "Show me which app is using it"},
			{Value: "cancel", Label: "Cancel"},
		})
		if err != nil {
			return 0, err
		}
		switch choice {
		case "cancel":
			return 0, cli.ErrCancelled
		case "show":
			if pid, command := portOwner(port); pid > 0 {
				a.UI.Info(fmt.Sprintf("%s (process %d) is using port %d.", command, pid, port))
			} else {
				a.UI.Info("This computer can't tell which app it is.")
			}
			continue
		}
		next, err := cli.FindAvailablePort(port+1, port+1)
		if err != nil {
			return 0, err
		}
		if err := a.setEnv("PORT", fmt.Sprint(next)); err != nil {
			return 0, err
		}
		a.UI.OK(fmt.Sprintf("NeoAgent will use port %d", next))
		if strings.TrimSpace(a.env()["PUBLIC_URL"]) != "" {
			a.UI.Warn("If a proxy forwards your public address to NeoAgent, point it at the new port too.")
		}
		return next, nil
	}
}

func (a *App) printRunning(headline string) {
	a.UI.Blank()
	a.UI.Item("ok", a.UI.Bold(headline), "")
	a.UI.Print("    %s", a.UI.Accent(a.url()))
}

func (a *App) cmdStart(ctx context.Context, _ []string) error {
	if err := a.ensureSecrets(); err != nil {
		return err
	}
	port, err := a.ensureStartPort(ctx)
	if err != nil {
		return err
	}
	if err := a.UI.Step("Starting NeoAgent", "Started NeoAgent", a.Service.Launch); err != nil {
		return err
	}
	if err := a.UI.Step("Checking it's answering", "It's answering", func() error { return a.waitForServerReady(ctx, port, 30*time.Second) }); err != nil {
		return err
	}
	a.printRunning(appName + " is running.")
	return nil
}

func (a *App) cmdStop(ctx context.Context, _ []string) error {
	if err := a.UI.Step("Stopping NeoAgent", "Stopped NeoAgent", func() error { return a.stopAndWait(ctx) }); err != nil {
		return err
	}
	a.UI.OK(appName + " stopped")
	return nil
}

func (a *App) cmdRestart(ctx context.Context, _ []string) error {
	started := time.Now()
	if err := a.ensureSecrets(); err != nil {
		return err
	}
	port, err := a.ensureStartPort(ctx)
	if err != nil {
		return err
	}
	for _, s := range []struct {
		doing, done string
		fn          func() error
	}{
		{"Stopping NeoAgent", "Stopped NeoAgent", func() error { return a.stopAndWait(ctx) }},
		{"Starting it again", "Started it again", a.Service.Launch},
		{"Checking it's answering", "It's answering", func() error { return a.waitForServerReady(ctx, port, 30*time.Second) }},
	} {
		if err := a.UI.Step(s.doing, s.done, s.fn); err != nil {
			return err
		}
	}
	a.printRunning("Back online in " + cli.FormatDuration(time.Since(started)) + ".")
	return nil
}

// computerReadiness reports the computer runtime the way status and doctor
// show it: ready, image downloaded, isolated.
func (a *App) computerReadiness() (ready, imageReady, isolated bool, detail string) {
	vmm := agentruntime.NewComputerVMManager(agentruntime.Dirs{AppDir: a.AppDir, RuntimeHome: a.Paths.Home, DataDir: a.Paths.DataDir}, agentruntime.Env{Getenv: os.Getenv}, a.Port())
	if vmm == nil {
		return true, true, false, "Runs directly on this computer"
	}
	r := vmm.Readiness()
	ready, imageReady = r.Bool("ready"), r.Bool("imageReady")
	switch {
	case !ready:
		detail = "Needs to be prepared"
	case !imageReady:
		detail = "Ready — downloads its system on first use"
	default:
		detail = "Ready for tasks that need a desktop"
	}
	return ready, imageReady, true, detail
}

func (a *App) cmdStatus(ctx context.Context, args []string) error {
	port := a.Port()
	running := cli.PortOpen(port)
	var runningVersion any
	if running {
		if h := fetchHandshake(ctx, port); h != nil {
			runningVersion = h.ServerVersion
		}
	}
	processes := a.serverProcesses()
	webClient := exists(filepath.Join(a.AppDir, "public", "index.html"))
	configPresent := exists(a.Paths.EnvFile)
	channel := a.channel()
	if a.JSON {
		msg := "NeoAgent is not reachable"
		if running {
			msg = "NeoAgent is reachable"
		}
		a.Events.Ready("status", msg, struct {
			Running          bool   `json:"running"`
			BackendURL       string `json:"backendUrl"`
			ConfigPresent    bool   `json:"configPresent"`
			WebClientPresent bool   `json:"webClientPresent"`
			Version          string `json:"version"`
			RunningVersion   any    `json:"runningVersion"`
			ReleaseChannel   string `json:"releaseChannel"`
			ProcessCount     int    `json:"processCount"`
		}{running, a.url(), configPresent, webClient, version(), runningVersion, channel, len(processes)})
		return nil
	}
	ready, _, _, computer := a.computerReadiness()
	tone := func(ok bool) string {
		if ok {
			return "ok"
		}
		return "warn"
	}
	a.UI.Title(appName+" "+version(), a.url())
	state := "Not running"
	if running {
		state = "Running"
		if v, ok := runningVersion.(string); ok && v != "" {
			state += " (" + v + ")"
		}
	}
	a.UI.Item(tone(running), "Server", state)
	a.UI.Item(tone(a.Service.Active()), "Starts with this computer", map[bool]string{true: "Yes", false: "No"}[a.Service.Installed()])
	a.UI.Item(tone(configPresent), "Settings", a.Paths.EnvFile)
	a.UI.Item(tone(webClient), "App in your browser", map[bool]string{true: "Installed", false: "Missing"}[webClient])
	a.UI.Item(tone(ready), "Agent's computer", computer)
	a.UI.Item("info", "Updates", release.ChannelLabel(channel)+" channel")
	if cli.HasFlag(args, "--details") {
		a.UI.Item("info", "Binary", a.Exe)
		a.UI.Item("info", "App files", a.AppDir)
		a.UI.Item("info", "Data", a.Paths.Home)
		for _, p := range processes {
			a.UI.Item("info", fmt.Sprintf("Process %d", p.PID), p.Command)
		}
	}
	a.UI.Blank()
	return nil
}

type doctorCheck struct {
	ID      string  `json:"id"`
	Label   string  `json:"label"`
	OK      bool    `json:"ok"`
	Code    *string `json:"code"`
	Message string  `json:"message"`
	Action  *string `json:"action"`
}

func (a *App) doctorChecks() ([]doctorCheck, int) {
	port := a.Port()
	state := a.readState()
	setupPending := state != nil && state.Status != "completed"
	writable := true
	if f, err := os.CreateTemp(a.Paths.Home, ".doctor-*"); err != nil {
		writable = false
	} else {
		f.Close()
		os.Remove(f.Name())
	}
	ready, imageReady, isolated, _ := a.computerReadiness()
	image := "Downloads on first use"
	switch {
	case !isolated:
		image = "Not needed — tasks run on this computer"
	case imageReady:
		image = "Downloaded"
	}
	stage := ""
	if state != nil {
		stage = state.Stage
	}
	check := func(id, label string, ok bool, code string, messages [2]string, action string) doctorCheck {
		c := doctorCheck{ID: id, Label: label, OK: ok, Message: messages[1]}
		if ok {
			c.Message = messages[0]
		} else {
			c.Code = &code
		}
		if action != "" {
			c.Action = &action
		}
		return c
	}
	return []doctorCheck{
		check("runtime-access", "NeoAgent's data folder", writable, "DOCTOR_RUNTIME_NOT_WRITABLE", [2]string{"Can be read and changed", "NeoAgent can't write to " + a.Paths.Home + " — check your user owns it"}, ""),
		check("configuration", "Settings", exists(a.Paths.EnvFile), "DOCTOR_CONFIG_MISSING", [2]string{"Saved", "Not set up yet"}, "neoagent setup --quick"),
		check("dependencies", "NeoAgent's files", exists(a.Exe), "DOCTOR_RUNTIME_INCOMPLETE", [2]string{"All there", "Some are missing"}, "neoagent repair"),
		check("web-client", "App in your browser", exists(filepath.Join(a.AppDir, "public", "index.html")), "DOCTOR_WEB_CLIENT_MISSING", [2]string{"Installed", "Missing"}, "neoagent repair"),
		check("computer-runtime", "Agent's computer", ready, "DOCTOR_COMPUTER_RUNTIME_MISSING", [2]string{"Ready", "Needs to be prepared"}, "neoagent repair"),
		check("computer-image", "Computer's system", ready, "DOCTOR_COMPUTER_IMAGE_UNAVAILABLE", [2]string{image, image}, "neoagent repair"),
		check("server", "NeoAgent", cli.PortOpen(port), "DOCTOR_SERVER_UNREACHABLE", [2]string{fmt.Sprintf("Running on port %d", port), fmt.Sprintf("Not running on port %d", port)}, "neoagent start"),
		check("setup-state", "Setup", !setupPending, "DOCTOR_SETUP_INCOMPLETE", [2]string{"Finished", "Stopped partway, at " + stage}, "neoagent setup --resume"),
	}, port
}

func (a *App) cmdDoctor(ctx context.Context, _ []string) error {
	checks, port := a.doctorChecks()
	healthy := true
	for _, c := range checks {
		healthy = healthy && c.OK
	}
	if a.JSON {
		msg := "NeoAgent needs attention"
		if healthy {
			msg = "No NeoAgent problems were found"
		}
		a.Events.Ready("doctor", msg, struct {
			Healthy bool          `json:"healthy"`
			Port    int           `json:"port"`
			Checks  []doctorCheck `json:"checks"`
		}{healthy, port, checks})
		return nil
	}
	a.UI.Title("Checking "+appName, "Nothing is changed while this runs.")
	for _, c := range checks {
		if c.OK {
			a.UI.Item("ok", c.Label, c.Message)
		} else {
			fix := ""
			if c.Action != nil {
				fix = " — fix: " + *c.Action
			}
			a.UI.Item("error", c.Label, c.Message+fix)
		}
	}
	a.UI.Blank()
	switch {
	case healthy:
		a.UI.Item("ok", a.UI.Bold("No problems found"), "")
	case a.UI.Interactive():
		if ok, _ := a.UI.Confirm("Fix these for you now? Your data is backed up first.", true); ok {
			return a.cmdRepair(ctx, nil)
		}
		fallthrough
	default:
		a.UI.Note("Most problems are fixed by " + a.UI.Command("neoagent repair") + ".")
	}
	return nil
}

func (a *App) cmdLogs(ctx context.Context, _ []string) error {
	if err := a.Paths.Ensure(); err != nil {
		return err
	}
	logs := []string{filepath.Join(a.Paths.LogDir, "neoagent.log"), filepath.Join(a.Paths.LogDir, "neoagent.error.log")}
	for _, l := range logs {
		f, err := os.OpenFile(l, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
		if err != nil {
			return err
		}
		f.Close()
	}
	if runtime.GOOS == "windows" {
		a.UI.Info("Logs: " + strings.Join(logs, ", "))
		return nil
	}
	a.UI.Title("What NeoAgent is doing", "Press Ctrl+C to stop watching.")
	cmd := exec.CommandContext(ctx, "tail", append([]string{"-f"}, logs...)...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil && ctx.Err() == nil {
		return err
	}
	return nil
}

func (a *App) cmdUninstall(_ context.Context, _ []string) error {
	if a.UI.Interactive() {
		if ok, err := a.UI.Confirm("Stop NeoAgent and stop it starting with your computer? Your data stays.", false); err != nil || !ok {
			return err
		}
	}
	a.Service.Uninstall()
	a.killServerProcesses()
	a.UI.OK("NeoAgent no longer starts with your computer")
	a.UI.Note("Your settings and chats are still in " + a.Paths.Home + ". Turn it back on with " + a.UI.Command("neoagent install") + ".")
	return nil
}

func (a *App) cmdRepair(ctx context.Context, args []string) error {
	runtimePackage := cli.HasFlag(args, "--runtime-package")
	a.UI.Title("Repairing "+appName, "Your data is backed up first. This can take a few minutes.")
	steps := []struct {
		doing, done string
		fn          func() error
	}{
		{"Stopping NeoAgent", "Stopped NeoAgent", func() error {
			a.stopService()
			if !a.waitForServerExit(ctx, 15*time.Second) {
				return fmt.Errorf("NeoAgent did not stop in time for a consistent repair backup.")
			}
			return nil
		}},
		{"Saving a backup of your settings and chats", "Saved a backup of your settings and chats", func() error {
			_, err := a.backupRuntimeData(ctx, "pre-update")
			return err
		}},
		{"Checking NeoAgent's files", "Checked NeoAgent's files", func() error {
			if !exists(filepath.Join(a.AppDir, "public", "index.html")) {
				return cli.Errorf("SETUP_RUNTIME_INCOMPLETE", "The verified runtime package is missing the bundled web client.")
			}
			return nil
		}},
		{"Checking the agent's computer", "Checked the agent's computer", func() error {
			if err := a.ensureComputerRuntime(ctx, runtimePackage, true); err != nil {
				return err
			}
			checked, repaired, err := a.repairComputerDisks(ctx)
			if repaired > 0 {
				a.UI.OK(fmt.Sprintf("Repaired %d of %d computer disk(s)", repaired, checked))
			}
			return err
		}},
		{"Starting NeoAgent", "Started NeoAgent", func() error {
			if err := a.ensureSecrets(); err != nil {
				return err
			}
			return a.Service.Install()
		}},
		{"Checking it's answering", "It's answering", func() error { return a.waitForServerReady(ctx, a.Port(), 30*time.Second) }},
	}
	for _, s := range steps {
		if err := a.UI.Step(s.doing, s.done, s.fn); err != nil {
			return err
		}
	}
	if !a.JSON {
		a.printRunning("Repair complete.")
		a.UI.Note("Check on it any time with " + a.UI.Command("neoagent status") + ".")
	}
	return nil
}

func (a *App) cmdChannel(_ context.Context, args []string) error {
	pos := cli.Positionals(args)
	if len(pos) == 0 {
		a.UI.Item("info", "Updates come from the "+release.ChannelLabel(a.channel())+" channel.", "")
		a.UI.Note("Switch with " + a.UI.Command("neoagent channel stable") + " or " + a.UI.Command("neoagent channel beta") + ".")
		return nil
	}
	next := release.ParseChannel(pos[0])
	if next == "" {
		return usageError("Usage: neoagent channel [stable|beta]")
	}
	if err := a.setEnv("NEOAGENT_RELEASE_CHANNEL", next); err != nil {
		return err
	}
	a.UI.OK("Updates now come from the " + release.ChannelLabel(next) + " channel")
	a.UI.Note("Get it with " + a.UI.Command("neoagent update") + ".")
	return nil
}
