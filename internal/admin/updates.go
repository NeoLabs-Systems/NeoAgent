package admin

import (
	"context"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	goruntime "runtime"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/cli/release"

	"github.com/NeoLabs-Systems/neoagent/internal/buildinfo"
	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neoagent/internal/updatestatus"
	"github.com/NeoLabs-Systems/neoagent/internal/versioninfo"
)

// UpdateDeps is what updating from the admin UI needs. Checking runs here;
// the update itself is `neoagent update-runner`, a detached process that
// outlives the server it restarts and reports through the status file.
type UpdateDeps struct {
	DataDir string
	LogDir  string
	// Exe is the installed neoagent binary; empty for builds that were not
	// installed by the installer, which cannot update themselves.
	Exe string
	// Latest returns the newest release version on a channel.
	Latest func(ctx context.Context, channel string) (string, error)
}

const updateCheckInterval = 6 * time.Hour

var processStart = time.Now()

// environmentKeys are the non-secret settings shown read-only on the admin page.
var environmentKeys = []string{"PORT", "NODE_ENV", "PUBLIC_URL", "NEOAGENT_DEPLOYMENT_MODE", "NEOAGENT_RELEASE_CHANNEL", "ALLOWED_ORIGINS", "SECURE_COOKIES", "TRUST_PROXY"}

type updateCheck struct {
	checkedAt string
	checked   bool
	version   string // newer release, or ""
	channel   string
}

type updater struct {
	deps *UpdateDeps
	env  *EnvStore

	mu   sync.Mutex
	last updateCheck
}

func (a *API) updates() *updater {
	a.updOnce.Do(func() { a.upd = &updater{deps: a.extra.Updates, env: a.Settings.Env} })
	return a.upd
}

func (a *API) getVersion(r *http.Request) (any, error) {
	info := versioninfo.Info(os.Getenv)
	status := map[string]any{"state": "idle", "phase": "idle", "message": ""}
	if d := a.extra.Updates; d != nil {
		status = updatestatus.Read(updatestatus.File(d.DataDir))
	}
	env := jsonobj.New()
	for _, k := range environmentKeys {
		env.Set(k, os.Getenv(k))
	}
	get := func(k string) any { v, _ := info.Get(k); return v }
	return jsonobj.New(
		"version", get("version"),
		"installedVersion", get("installedVersion"),
		"packageVersion", get("packageVersion"),
		"gitVersion", get("gitVersion"),
		"gitSha", get("gitSha"),
		"gitBranch", get("gitBranch"),
		"releaseChannel", get("releaseChannel"),
		"deploymentMode", get("deploymentMode"),
		"allowSelfUpdate", get("allowSelfUpdate"),
		"containerImage", get("containerImage"),
		"updateStatus", jsonobj.New("state", status["state"], "phase", status["phase"], "message", status["message"]),
		"uptime", time.Since(processStart).Seconds(),
		// The admin page labels this "Node.js"; the Go server reports its runtime.
		"nodeVersion", goruntime.Version(),
		"environment", env,
	), nil
}

func (a *API) getUpdateStatus(r *http.Request) (any, error) { return a.updates().status(), nil }

func (a *API) postUpdateCheck(r *http.Request) (any, error) {
	return a.updates().check(r.Context()), nil
}

func (a *API) postUpdateStart(r *http.Request) (any, error) { return a.updates().start() }

func (a *API) putUpdateChannel(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	return a.updates().setChannel(r.Context(), strVal(b["channel"]))
}

// StartUpdateChecks looks for a new version shortly after start and every few
// hours after, so the admin page can show the banner without a click.
func (a *API) StartUpdateChecks(ctx context.Context) {
	if a.extra.Updates == nil {
		return
	}
	u := a.updates()
	go func() {
		timer := time.NewTimer(5 * time.Second)
		defer timer.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-timer.C:
				u.check(ctx)
				timer.Reset(updateCheckInterval)
			}
		}
	}()
}

// blockedReason says why this install cannot update itself, or "".
func (u *updater) blockedReason() string {
	if runtime.ParseDeploymentMode(os.Getenv("NEOAGENT_DEPLOYMENT_MODE")) == runtime.ModeManaged {
		return "managed"
	}
	if versioninfo.ContainerImage(os.Getenv) {
		return "container"
	}
	if u.deps == nil || u.deps.Exe == "" || buildinfo.Version == "dev" {
		return "not_git"
	}
	return ""
}

func (u *updater) statusFile() string {
	if u.deps == nil {
		return ""
	}
	return updatestatus.File(u.deps.DataDir)
}

// job is the update runner's status; without a data directory, the idle default.
func (u *updater) job() map[string]any { return updatestatus.Read(u.statusFile()) }

func (u *updater) status() *jsonobj.Object {
	channel := versioninfo.Channel(os.Getenv)
	reason := u.blockedReason()
	u.mu.Lock()
	known := u.last
	u.mu.Unlock()
	if known.channel != channel {
		known = updateCheck{}
	}
	var available any
	if known.version != "" && release.CompareVersions(known.version, buildinfo.Version) != 0 {
		available = jsonobj.New("version", known.version, "branch", branchFor(channel), "changes", []any{})
	}
	var checkedAt, blocked any
	if known.checkedAt != "" {
		checkedAt = known.checkedAt
	}
	if reason != "" {
		blocked = reason
	}
	job := u.job()
	return jsonobj.New(
		"version", buildinfo.Version,
		"channel", channel,
		"channelLabel", release.ChannelLabel(channel),
		"selfUpdate", reason == "",
		"blockedReason", blocked,
		"checkedAt", checkedAt,
		"checkFailed", known.checkedAt != "" && !known.checked,
		"available", available,
		"job", jsonobj.New(
			"state", job["state"], "phase", job["phase"], "progress", job["progress"], "message", job["message"],
			"versionBefore", job["versionBefore"], "versionAfter", job["versionAfter"], "changelog", job["changelog"],
			"rolledBack", job["rolledBack"] == true, "logs", job["logs"],
			"startedAt", job["startedAt"], "completedAt", job["completedAt"],
		),
	)
}

func branchFor(channel string) string {
	if release.NormalizeChannel(channel) == release.Beta {
		return "beta"
	}
	return "main"
}

func (u *updater) check(ctx context.Context) *jsonobj.Object {
	if u.blockedReason() != "" || u.deps.Latest == nil {
		return u.status()
	}
	channel := versioninfo.Channel(os.Getenv)
	latest, err := u.deps.Latest(ctx, channel)
	result := updateCheck{channel: channel, checkedAt: time.Now().UTC().Format("2006-01-02T15:04:05.000Z"), checked: err == nil}
	if err == nil && release.CompareVersions(latest, buildinfo.Version) > 0 {
		result.version = latest
	}
	u.mu.Lock()
	// A failed check keeps the last good answer: offline must not hide a banner.
	if result.checked || !u.last.checked || u.last.channel != channel {
		u.last = result
	}
	u.mu.Unlock()
	return u.status()
}

func (u *updater) assertIdle() error {
	switch u.blockedReason() {
	case "managed":
		return fail(http.StatusConflict, "Updates are managed by this deployment.", "UPDATE_MANAGED")
	case "container":
		return fail(http.StatusConflict, "NeoAgent runs from a container image. Pull the new image and recreate the container.", "UPDATE_CONTAINER")
	case "not_git":
		return fail(http.StatusConflict, "This NeoAgent was not installed by the installer, so it cannot update itself.", "UPDATE_NOT_GIT")
	}
	if u.job()["state"] == "running" {
		return fail(http.StatusConflict, "An update is already running.", "UPDATE_RUNNING")
	}
	return nil
}

func (u *updater) start() (any, error) {
	if err := u.assertIdle(); err != nil {
		return nil, err
	}
	u.mu.Lock()
	target := u.last.version
	u.mu.Unlock()
	var versionAfter any
	if target != "" {
		versionAfter = target
	}
	file := u.statusFile()
	if _, err := updatestatus.Write(file, map[string]any{
		"state": "running", "progress": 1, "phase": "starting", "message": "Starting the update",
		"startedAt": time.Now().UTC().Format("2006-01-02T15:04:05.000Z"), "completedAt": nil,
		"versionBefore": buildinfo.Version, "versionAfter": versionAfter, "rolledBack": false,
		"changelog": []any{}, "logs": []any{}, "runnerPid": os.Getpid(),
	}); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(u.deps.LogDir, 0o700); err != nil {
		return nil, err
	}
	out, err := os.OpenFile(filepath.Join(u.deps.LogDir, "update.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return nil, err
	}
	defer out.Close()
	cmd := runnerCommand(u.deps.Exe)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = nil, out, out
	detach(cmd)
	if err := cmd.Start(); err != nil {
		_, _ = updatestatus.Write(file, map[string]any{
			"state": "failed", "phase": "failed", "message": "The update could not start: " + err.Error(),
			"runnerPid": nil, "completedAt": time.Now().UTC().Format("2006-01-02T15:04:05.000Z"),
		})
		return u.status(), nil
	}
	_, _ = updatestatus.Write(file, map[string]any{"runnerPid": cmd.Process.Pid})
	_ = cmd.Process.Release()
	return u.status(), nil
}

// runnerCommand starts the update runner. Under systemd a detached process
// still belongs to the service's cgroup, and stopping the service for the
// update would stop the runner with it, so it gets its own scope.
func runnerCommand(exe string) *exec.Cmd {
	if goruntime.GOOS == "linux" && os.Getenv("INVOCATION_ID") != "" {
		return exec.Command("systemd-run", "--user", "--scope", "--quiet", "--collect", exe, "update-runner")
	}
	return exec.Command(exe, "update-runner")
}

func (u *updater) setChannel(ctx context.Context, requested string) (any, error) {
	if err := u.assertIdle(); err != nil {
		return nil, err
	}
	channel := release.ParseChannel(requested)
	if channel == "" {
		return nil, fail(http.StatusBadRequest, `The release channel must be "stable" or "beta".`, "INVALID_CHANNEL")
	}
	if err := u.env.Persist("NEOAGENT_RELEASE_CHANNEL", channel); err != nil {
		return nil, err
	}
	return u.check(ctx), nil
}
