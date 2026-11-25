package manager

import (
	"context"
	"fmt"
	"github.com/NeoLabs-Systems/neoagent/internal/agent"
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
	u := a.UI
	u.Blank()
	u.Print("  " + u.Error("✕") + " " + u.Bold("NeoAgent couldn't start"))
	u.Print("    " + u.Muted("Nothing is broken — your data is safe."))
	u.Section("What happened")
	u.Printf("  Another app on this computer is already using the address NeoAgent wants (port %d).", port)
	u.Blank()
	for {
		choice, ok, err := u.SelectOrQuit("What would you like to do?", []cli.Choice{
			{Value: "move", Label: "Use a free address instead", Hint: "NeoAgent moves to the next free port"},
			{Value: "show", Label: "Show me which app is using it"},
			{Value: "cancel", Label: "Cancel"},
		})
		if err != nil {
			return 0, err
		}
		if !ok || choice == "cancel" {
			return 0, cli.ErrCancelled
		}
		if choice == "show" {
			if pid, command := portOwner(port); pid > 0 {
				u.Item("info", fmt.Sprintf("%s (process %d) is using port %d.", command, pid, port), "")
			} else {
				u.Item("info", "This computer can't tell which app it is.", "")
			}
			u.Blank()
			continue
		}
		next, err := cli.FindAvailablePort(port+1, port+1)
		if err != nil {
			return 0, err
		}
		if err := a.setEnv("PORT", fmt.Sprint(next)); err != nil {
			return 0, err
		}
		u.Item("ok", fmt.Sprintf("NeoAgent will use port %d", next), "")
		if strings.TrimSpace(a.env()["PUBLIC_URL"]) != "" {
			u.Warn("If a proxy forwards your public address to NeoAgent, point it at the new port too.")
		}
		u.Blank()
		return next, nil
	}
}

func (a *App) printRunning(headline string) {
	a.UI.Blank()
	a.UI.Item("ok", a.UI.Bold(headline), "")
	a.UI.Print("    " + a.UI.Accent(a.url()))
}

// countResumableRuns is how many runs a stop cut off mid-task; the server
// resumes them on its next start.
func (a *App) countResumableRuns(ctx context.Context) int {
	if !exists(a.dbPath()) {
		return 0
	}
	db, err := a.openDB(ctx)
	if err != nil {
		return 0
	}
	defer db.Close()
	return agent.CountResumable(ctx, db)
}

func (a *App) printResumeNote(count int, when string) {
	switch {
	case count == 1:
		a.UI.Note("1 task that was running picks up where it left off " + when + ".")
	case count > 1:
		a.UI.Note(fmt.Sprintf("%d tasks that were running pick up where they left off %s.", count, when))
	}
}

// stopAndCount stops NeoAgent and returns how many cut-off tasks it resumes.
func (a *App) stopAndCount(ctx context.Context, resumable *int) func() error {
	return func() error {
		if err := a.stopAndWait(ctx); err != nil {
			return err
		}
		*resumable = a.countResumableRuns(ctx)
		return nil
	}
}

func (a *App) cmdStart(ctx context.Context, _ []string) error {
	if err := a.ensureSecrets(); err != nil {
		return err
	}
	port, err := a.ensureStartPort(ctx)
	if err != nil {
		return err
	}
	// Launching only spawns the process. Callers (the desktop app included)
	// treat success as "the backend answers now", so wait for the handshake.
	if err := a.UI.RunSteps(false,
		cli.Step{Label: cli.Label{Doing: "Starting NeoAgent", Done: "Started NeoAgent"}, Run: a.Service.Launch},
		cli.Step{Label: cli.Label{Doing: "Checking it's answering", Done: "It's answering"}, Run: func() error { return a.waitForServerReady(ctx, port, 30*time.Second) }},
	); err != nil {
		return err
	}
	if a.JSON {
		a.UI.OK(appName + " is reachable")
	} else {
		a.printRunning(appName + " is running.")
	}
	return nil
}

func (a *App) cmdStop(ctx context.Context, _ []string) error {
	var resumable int
	if err := a.UI.Step("Stopping NeoAgent", "Stopped NeoAgent", a.stopAndCount(ctx, &resumable)); err != nil {
		return err
	}
	a.UI.Blank()
	a.UI.OK(appName + " stopped")
	a.printResumeNote(resumable, "when NeoAgent starts again")
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
	var resumable int
	if err := a.UI.RunSteps(false,
		cli.Step{Label: cli.Label{Doing: "Getting the app ready", Done: "Got the app ready"}, Run: a.checkWebClient},
		cli.Step{Label: cli.Label{Doing: "Stopping NeoAgent", Done: "Stopped NeoAgent"}, Run: a.stopAndCount(ctx, &resumable)},
		cli.Step{Label: cli.Label{Doing: "Starting it again", Done: "Started it again"}, Run: a.Service.Launch},
		cli.Step{Label: cli.Label{Doing: "Checking it's answering", Done: "It's answering"}, Run: func() error { return a.waitForServerReady(ctx, port, 30*time.Second) }},
	); err != nil {
		return err
	}
	if a.JSON {
		a.UI.OK(appName + " is reachable")
		return nil
	}
	a.printRunning("Back online in " + cli.FormatDuration(time.Since(started)) + ".")
	a.printResumeNote(resumable, "now")
	a.UI.Blank()
	return nil
}

// checkWebClient makes sure the browser app is there. It never builds it:
// release packages carry it, and `neoagent rebuild-web` builds it from source.
func (a *App) checkWebClient() error {
	if !exists(filepath.Join(a.AppDir, "public", "index.html")) {
		return cli.Errorf("SETUP_RUNTIME_INCOMPLETE", "The bundled web client is missing.")
	}
	a.UI.Info("Using the app that came with NeoAgent")
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
	f := a.collectStatusFacts(ctx, !a.JSON && a.UI.Interactive())
	if a.JSON {
		msg := "NeoAgent is not reachable"
		if f.Running {
			msg = "NeoAgent is reachable"
		}
		var runningVersion any
		if f.RunningVersion != "" {
			runningVersion = f.RunningVersion
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
		}{f.Running, f.URL, f.ConfigPresent, f.WebClientPresent, f.Version, runningVersion, f.Channel, len(f.PIDs)})
		return nil
	}
	a.printStatus(f, cli.HasFlag(args, "--details"))
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
	shown := make([]statusCheck, len(checks))
	for i, c := range checks {
		shown[i] = statusCheck{Tone: "ok", Label: c.Label, Detail: c.Message}
		if !c.OK {
			shown[i].Tone = "error"
			if c.Action != nil {
				shown[i].Fix = *c.Action
			}
		}
	}
	a.printChecks(shown)
	a.UI.Blank()
	if healthy {
		a.UI.Item("ok", a.UI.Bold("No problems found"), "")
		a.UI.Blank()
		return nil
	}
	if a.UI.Interactive() {
		ok, err := a.UI.Confirm("Fix these for you now? Your data is backed up first.", true)
		if err != nil {
			return err
		}
		if ok {
			return a.cmdRepair(ctx, nil)
		}
	}
	a.UI.Note("Most problems are fixed by " + a.UI.Command("neoagent repair") + ".")
	a.UI.Blank()
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
	a.UI.Blank()
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
	a.UI.Blank()
	missing := func(what string) error {
		return cli.Errorf("SETUP_RUNTIME_INCOMPLETE", "The verified runtime package is missing %s.", what)
	}
	if err := a.UI.RunSteps(true,
		cli.Step{Label: cli.Label{Doing: "Stopping NeoAgent", Done: "Stopped NeoAgent"}, Run: func() error {
			a.stopService()
			if !a.waitForServerExit(ctx, 15*time.Second) {
				return fmt.Errorf("NeoAgent did not stop in time for a consistent repair backup.")
			}
			return nil
		}},
		cli.Step{Label: cli.Label{Doing: "Saving a backup of your settings and chats", Done: "Saved a backup of your settings and chats"}, Run: func() error {
			_, err := a.backupRuntimeData(ctx, "pre-update")
			return err
		}},
		cli.Step{Label: cli.Label{Doing: "Reinstalling what it needs", Done: "Reinstalled what it needs"}, Run: func() error {
			if !exists(a.Exe) {
				return missing("required dependencies")
			}
			return nil
		}},
		cli.Step{Label: cli.Label{Doing: "Preparing the app", Done: "Prepared the app"}, Run: func() error {
			if !exists(filepath.Join(a.AppDir, "public", "index.html")) {
				return missing("the bundled web client")
			}
			return nil
		}},
		cli.Step{Label: cli.Label{Doing: "Checking the agent's computer", Done: "Checked the agent's computer"}, Run: func() error {
			if err := a.ensureComputerRuntime(ctx, runtimePackage, true); err != nil {
				return err
			}
			checked, repaired, err := a.repairComputerDisks(ctx)
			if repaired > 0 {
				a.UI.OK(fmt.Sprintf("Repaired %d of %d computer disk(s)", repaired, checked))
			}
			return err
		}},
		cli.Step{Label: cli.Label{Doing: "Starting NeoAgent", Done: "Started NeoAgent"}, Run: func() error {
			if err := a.ensureSecrets(); err != nil {
				return err
			}
			if err := a.Service.Install(); err != nil {
				return err
			}
			return a.waitForServerReady(ctx, a.Port(), 30*time.Second)
		}},
	); err != nil {
		return err
	}
	if a.JSON {
		return nil
	}
	a.printRunning("Repair complete.")
	a.UI.Note("Check on it any time with " + a.UI.Command("neoagent status") + ".")
	a.UI.Blank()
	return nil
}

func (a *App) cmdChannel(_ context.Context, args []string) error {
	pos := cli.Positionals(args)
	if len(pos) == 0 {
		a.UI.Blank()
		a.UI.Item("info", "Updates come from the "+release.ChannelLabel(a.channel())+" channel.", "")
		a.UI.Note("Switch with " + a.UI.Command("neoagent channel stable") + " or " + a.UI.Command("neoagent channel beta") + ".")
		a.UI.Blank()
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
