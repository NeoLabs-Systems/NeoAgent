package manager

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/release"
	agentruntime "github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/cli/envfile"
)

func (a *App) cmdInstall(ctx context.Context, args []string) error {
	o, err := ParseSetupArguments(args)
	if err != nil {
		return err
	}
	if err := a.applyChannelFlag(o); err != nil {
		return err
	}
	// A standalone CLI (install.sh, a downloaded binary) has no web client
	// next to it: it installs the signed runtime package and hands over.
	if !o.RuntimePackage && !exists(filepath.Join(a.AppDir, "public", "index.html")) {
		return a.bootstrapInstall(ctx, args, o)
	}
	a.UI.Title("Welcome to "+appName, "Let's get it running on this computer. It takes a few minutes.")
	profile, err := a.resolveProfile(o)
	if err != nil {
		return err
	}
	a.Events.Profile = profile
	if err := a.install(ctx, profile, o); err != nil {
		_, _ = a.writeState(SetupState{Profile: profile, Stage: a.Events.Stage, Status: "failed"})
		a.Events.Fail(err, true, "neoagent setup --resume")
		return eventEmitted{err}
	}
	return nil
}

// eventEmitted marks an error the JSON stream already reported.
type eventEmitted struct{ error }

func (e eventEmitted) Unwrap() error { return e.error }

func (a *App) install(ctx context.Context, profile string, o SetupOptions) error {
	a.notes = nil
	a.Events.Start("prepare", "Checking this computer", 0.01)
	if err := a.Paths.Ensure(); err != nil {
		return err
	}
	if !exists(filepath.Join(a.AppDir, "public", "index.html")) {
		return cli.Errorf("SETUP_RUNTIME_INCOMPLETE", "The verified runtime package does not contain the web client.")
	}
	if p := Platform(); !(p == "macos" && a.Service.Runner.Exists("launchctl")) && !(p == "linux" && a.Service.Runner.Exists("systemctl")) && p != "windows" {
		a.note("NeoAgent can't start by itself on this computer. After a restart, run `neoagent start`.")
	}
	port, err := a.runSetupProfile(ctx, profile, o)
	if err != nil {
		return err
	}
	downloadImage := false
	if profile == "full" && !o.NonInteractive && a.UI.Interactive() {
		downloadImage, _ = a.UI.Confirm("Download the agent's computer now? (about 1 GB; otherwise on first use)", false)
	}
	a.UI.Title("Installing "+appName, "")
	a.Events.Start("dependencies", "Preparing NeoAgent runtime", 0.2)
	a.Events.Complete("dependencies", "Runtime prepared", 0.45)
	_ = a.UI.Step("Setting up the agent's computer", "Set up the agent's computer", func() error {
		a.ensureComputerRuntime(ctx, false, downloadImage)
		return nil
	})
	// An existing installation (also a Node.js one being replaced) is backed
	// up first, and its service definition comes back if the new server does
	// not answer.
	snapshot := a.snapshotService()
	if exists(a.dbPath()) {
		if err := a.UI.Step("Saving a backup of your settings and chats", "Saved a backup of your settings and chats", func() error {
			_, err := a.backupRuntimeData(ctx, "pre-install")
			return err
		}); err != nil {
			return err
		}
	}
	if err := a.ensureInstance(ctx); err != nil {
		return err
	}
	a.Events.Start("service", "Starting NeoAgent in the background", 0.55)
	started := false
	err = a.UI.Step("Starting NeoAgent", "Started NeoAgent", func() error {
		if err := a.releasePort(ctx, port); err != nil {
			return err
		}
		started = true
		return a.Service.Install()
	})
	if err == nil {
		err = a.UI.Step("Checking it's answering", "It's answering", func() error { return a.waitForServerReady(ctx, port, 45*time.Second) })
	}
	if err != nil {
		if started && snapshot.content != nil {
			if rerr := a.restoreService(ctx, snapshot, port); rerr == nil {
				return fmt.Errorf("%w\nThe previous NeoAgent is running again; nothing was lost.", err)
			}
		}
		return err
	}
	a.Events.Complete("service", "NeoAgent is ready", 0.85)
	backendURL := fmt.Sprintf("http://localhost:%d", port)
	a.clearState()
	_, _ = a.Events.Emit("ready", cli.EmitOptions{Stage: "complete", Progress: 1, Message: "NeoAgent setup is complete", Result: struct {
		BackendURL    string `json:"backendUrl"`
		InstanceID    string `json:"instanceId"`
		ServerVersion string `json:"serverVersion"`
	}{backendURL, a.instanceID(ctx), version()}})
	if !a.JSON {
		a.finishInstall(ctx, backendURL)
	}
	return nil
}

func (a *App) finishInstall(ctx context.Context, backendURL string) {
	env := a.env()
	publicURL := strings.TrimSpace(env["PUBLIC_URL"])
	notes := a.notes
	if publicURL != "" && !strings.EqualFold(strings.TrimSpace(env["SECURE_COOKIES"]), "true") {
		notes = append([]string{"On this computer you can also use " + backendURL + "."}, notes...)
	}
	target := orDefault(publicURL, backendURL)
	a.UI.Blank()
	a.UI.Item("ok", a.UI.Bold(appName+" is running"), target)
	if !a.hasAccount(ctx) {
		a.UI.Note("Open it and create your account; the first account becomes the admin.")
	}
	if !a.Service.Managed() {
		a.UI.Note("It does not start by itself; run " + a.UI.Command("neoagent start") + " after a restart.")
	}
	backtick := regexp.MustCompile("`([^`]+)`")
	for _, n := range notes {
		a.UI.Note(backtick.ReplaceAllStringFunc(n, func(m string) string { return a.UI.Command(strings.Trim(m, "`")) }))
	}
	a.UI.Blank()
	if a.UI.Interactive() {
		if ok, _ := a.UI.Confirm("Open it in your browser now?", true); ok {
			openInBrowser(target)
		}
	}
}

func openInBrowser(url string) {
	opener := map[string]string{"darwin": "open", "windows": "explorer"}[runtime.GOOS]
	if opener == "" {
		opener = "xdg-open"
	}
	_ = exec.Command(opener, url).Start()
}

// ensureComputerRuntime prepares the runtime TERMINAL_ENV selects; failures
// become notes unless required.
func (a *App) ensureComputerRuntime(ctx context.Context, required, downloadImage bool) error {
	dirs := agentruntime.Dirs{AppDir: a.AppDir, RuntimeHome: a.Paths.Home, DataDir: a.Paths.DataDir}
	env := agentruntime.Env{Getenv: os.Getenv}
	fail := func(err error, action string) error {
		msg := "Computer runtime preparation did not complete: " + err.Error()
		if required {
			return fmt.Errorf("%s", msg)
		}
		a.UI.Warn(msg)
		a.note(action)
		return nil
	}
	switch agentruntime.ParseTerminalEnv(os.Getenv("TERMINAL_ENV")) {
	case agentruntime.TerminalHost:
		a.UI.OK("Host computer runtime is ready (agents run on this machine, unisolated)")
		return nil
	case agentruntime.TerminalDocker:
		ready, err := agentruntime.NewDockerManager(agentruntime.DockerOptions{Dirs: dirs, Env: env}).PrepareRuntime(ctx, downloadImage)
		if err != nil {
			return fail(err, "Start Docker, then run `neoagent repair` to build the guest container image.")
		}
		a.UI.OK("Docker computer runtime is ready (" + orDefault(ready.String("image"), "guest image builds on first start") + ")")
		return nil
	}
	a.cleanupLegacyDockerRuntime()
	restored, err := agentruntime.RestoreQemuComputerRuntime(ctx, agentruntime.QemuRestore{
		RuntimeHome: a.Paths.Home, AllowHostInstall: true, Platform: Platform(), Root: os.Geteuid() == 0,
		CommandExists: a.Service.Runner.Exists,
		RunOrThrow: func(command string, args []string, path string) error {
			cmd := exec.CommandContext(ctx, command, args...)
			cmd.Env = append(os.Environ(), "PATH="+path)
			out, err := cmd.CombinedOutput()
			if err != nil {
				return fmt.Errorf("%s failed: %w\n%s", command, err, strings.TrimSpace(string(out)))
			}
			return nil
		},
		Stage:   func(destination string) error { return release.StageQemu(ctx, destination) },
		LogInfo: a.UI.Info,
	})
	if err != nil {
		return fail(err, "Install QEMU, then run `neoagent repair` to stage the computer runtime and guest image.")
	}
	switch restored.Action {
	case "signed":
		a.UI.OK("Enabled hardware acceleration on the bundled QEMU runtime")
	case "copied":
		a.UI.OK("Restored the signed QEMU runtime from the installed package")
	case "staged":
		a.UI.OK("Installed and staged the QEMU computer runtime")
	}
	ready, err := agentruntime.NewQemuManager(agentruntime.QemuOptions{Dirs: dirs, Env: env, ServerPort: a.Port()}).PrepareRuntime(ctx, downloadImage)
	if err != nil {
		return fail(err, "Install QEMU, then run `neoagent repair` to stage the computer runtime and guest image.")
	}
	if resources, ok := ready.Get("resources"); ok {
		if data, err := json.MarshalIndent(resources, "", "  "); err == nil {
			_ = envfile.WriteAtomic(filepath.Join(a.Paths.Home, "computer-runtime", "profile.json"), append(data, '\n'), 0o600)
		}
	}
	a.UI.OK("QEMU computer runtime is ready (" + orDefault(ready.String("accelerator"), "TCG") + ")")
	if ready.Bool("compatibilityMode") {
		a.UI.Warn("Hardware acceleration is unavailable; compatibility mode limits concurrency to one computer.")
	}
	if ready.Bool("imageReady") {
		a.UI.OK("Pinned Debian guest image is verified and ready")
	}
	return nil
}

// cleanupLegacyDockerRuntime removes the containers and images of the
// Docker-based computer runtime once; Docker itself is left alone.
func (a *App) cleanupLegacyDockerRuntime() {
	marker := filepath.Join(a.Paths.Home, "computer-runtime", "legacy-docker-cleanup.json")
	if exists(marker) {
		return
	}
	write := func(v map[string]any) {
		v["completedAt"] = cli.ISOTime(time.Now())
		data, _ := json.Marshal(v)
		_ = envfile.WriteAtomic(marker, append(data, '\n'), 0o600)
	}
	run := a.Service.Runner
	if !run.Exists("docker") {
		write(map[string]any{"removed": 0})
		return
	}
	if _, err := run.Run("docker", "info", "--format", "{{.ServerVersion}}"); err != nil {
		a.UI.Warn("Docker is installed but unavailable; legacy NeoAgent container cleanup will retry later.")
		return
	}
	ids := func(out string, pattern string) []string {
		re := regexp.MustCompile(pattern)
		var list []string
		for _, f := range strings.Fields(out) {
			if re.MatchString(f) && !contains(list, f) {
				list = append(list, f)
			}
		}
		return list
	}
	out, _ := run.Run("docker", "container", "ls", "--all", "--quiet", "--filter", "label=neoagent.managed=1")
	containers := ids(out, `^[a-fA-F0-9]{12,64}$`)
	if len(containers) > 0 {
		if _, err := run.Run("docker", append([]string{"container", "rm", "--force"}, containers...)...); err != nil {
			a.UI.Warn("Legacy NeoAgent containers could not be removed; cleanup will retry later.")
			return
		}
	}
	out, _ = run.Run("docker", "image", "ls", "--quiet", "--filter", "reference=neoagent-guest-agent:*")
	images := ids(out, `^(?:sha256:)?[a-fA-F0-9]{12,64}$`)
	if len(images) > 0 {
		if _, err := run.Run("docker", append([]string{"image", "rm", "--force"}, images...)...); err != nil {
			a.UI.Warn("Legacy NeoAgent images could not be removed; cleanup will retry later.")
			return
		}
	}
	write(map[string]any{"removedContainers": len(containers), "removedImages": len(images)})
	if len(containers)+len(images) > 0 {
		a.UI.OK(fmt.Sprintf("Removed %d legacy NeoAgent container(s) and %d image(s); Docker itself was not changed.", len(containers), len(images)))
	}
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}
