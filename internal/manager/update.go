package manager

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/updatestatus"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

// serviceSnapshot is the service definition before a switch, so a failed
// update or migration can put the old one (Go or Node.js) back.
type serviceSnapshot struct {
	path        string
	content     []byte
	marker      []byte
	exe, appDir string
}

func (a *App) snapshotService() serviceSnapshot {
	s := serviceSnapshot{exe: a.Exe, appDir: a.AppDir}
	switch Platform() {
	case "macos":
		s.path = a.Service.PlistPath
	case "linux":
		s.path = a.Service.UnitPath
	}
	if s.path != "" {
		s.content, _ = os.ReadFile(s.path)
	}
	s.marker, _ = os.ReadFile(a.currentMarker())
	return s
}

func (a *App) restoreService(ctx context.Context, s serviceSnapshot, port int) error {
	a.stopService()
	a.waitForServerExit(ctx, 15*time.Second)
	if s.marker != nil {
		_ = os.WriteFile(a.currentMarker(), s.marker, 0o600)
	}
	a.useBinary(s.exe, s.appDir)
	if s.path != "" && s.content != nil {
		if err := os.WriteFile(s.path, s.content, 0o644); err != nil {
			return err
		}
	}
	if err := a.Service.Launch(); err != nil {
		return err
	}
	return a.waitForServerReady(ctx, port, 45*time.Second)
}

// switchTo stops the running NeoAgent (Go or Node.js), points the service at
// rt and waits until it answers with rt's version.
func (a *App) switchTo(ctx context.Context, rt installedRuntime, port int) error {
	if err := a.ensureSecrets(); err != nil {
		return err
	}
	if err := a.stopAndWait(ctx); err != nil {
		return err
	}
	if err := a.writeCurrent(rt.Version); err != nil {
		return err
	}
	a.useBinary(rt.binary(), rt.appDir())
	if err := a.Service.Install(); err != nil {
		return err
	}
	if err := a.waitForServerReady(ctx, port, 60*time.Second); err != nil {
		return err
	}
	if h := fetchHandshake(ctx, port); h != nil && h.ServerVersion != "" && h.ServerVersion != rt.Version {
		return fmt.Errorf("NeoAgent restarted but is still running %s.", h.ServerVersion)
	}
	return nil
}

func (a *App) cmdUpdate(ctx context.Context, args []string) error {
	if v := strings.ToLower(strings.TrimSpace(os.Getenv("NEOAGENT_CONTAINER_IMAGE"))); v == "1" || v == "true" {
		return errors.New("This NeoAgent runs from a container image. Update it by pulling the new image: docker compose pull && docker compose up -d")
	}
	notesOnly := cli.HasFlag(args, "--notes")
	requested := ""
	if pos := cli.Positionals(args); len(pos) > 0 {
		if requested = release.ParseChannel(pos[0]); requested == "" {
			return usageError("Usage: neoagent update [stable|beta] [--notes]")
		}
	}
	channel := a.channel()
	if requested != "" {
		channel = requested
		if !notesOnly {
			if err := a.setEnv("NEOAGENT_RELEASE_CHANNEL", requested); err != nil {
				return err
			}
		}
	}
	if err := a.Paths.Ensure(); err != nil {
		return err
	}
	before := version()
	a.reportProgress(map[string]any{"progress": 5, "phase": "checking", "message": "Checking the release channel", "versionBefore": before, "releaseChannel": channel})
	available, err := a.findRuntime(ctx, channel)
	if err != nil {
		if cli.CodeOf(err, "") == "SETUP_DOWNLOAD_FAILED" {
			return fmt.Errorf("NeoAgent couldn't reach GitHub to look for updates. Check the internet connection and try again.")
		}
		return err
	}
	newer := release.CompareVersions(available.Version, before) > 0
	if !newer && !(requested != "" && available.Version != before) {
		a.UI.OK(fmt.Sprintf("You have the latest version (%s)", before))
		return a.reportUpdate(before, before, "You have the latest version ("+before+")")
	}
	if notesOnly {
		a.UI.Item("warn", a.UI.Bold(available.Version+" is ready"), "you have "+before)
		a.UI.Note("Get it with " + a.UI.Command("neoagent update") + ".")
		return a.reportUpdate(before, available.Version, available.Version+" is ready")
	}
	a.reportProgress(map[string]any{"progress": 10, "phase": "preparing", "message": "Preparing the update", "versionAfter": available.Version, "targetBranch": channelBranch(channel), "changelog": []any{}})
	a.UI.Title("Updating "+appName, fmt.Sprintf("%s → %s · %s", before, available.Version, channel))
	port := a.Port()
	var installed installedRuntime
	snapshot := a.snapshotService()
	switched := false
	steps := []struct {
		phase, doing, done string
		fn                 func() error
	}{
		{"backup", "Saving a backup of your settings and chats", "Saved a backup of your settings and chats", func() error {
			_, err := a.backupRuntimeData(ctx, "pre-update")
			return err
		}},
		{"downloading", "Downloading the new version", "Downloaded the new version", func() (err error) {
			installed, err = a.unpackRuntime(ctx, available, true)
			return err
		}},
		{"restarting", "Restarting NeoAgent", "Restarted NeoAgent", func() error {
			switched = true
			return a.switchTo(ctx, installed, port)
		}},
	}
	for i, s := range steps {
		a.reportProgress(map[string]any{"progress": 15 + i*16, "phase": s.phase, "message": s.doing})
		if err := a.UI.Step(s.doing, s.done, s.fn); err != nil {
			if !switched {
				return err
			}
			a.reportProgress(map[string]any{"progress": 85, "phase": "rollback", "message": fmt.Sprintf("Restoring %s after the update failed", before)})
			a.UI.Info("Going back to " + before)
			if rerr := a.restoreService(ctx, snapshot, port); rerr != nil {
				return &codedErr{code: "UPDATE_ROLLBACK_FAILED", msg: fmt.Sprintf("%s\nGoing back to %s also failed: %s", err, before, rerr)}
			}
			return &codedErr{code: "UPDATE_ROLLED_BACK", msg: fmt.Sprintf("%s\nNeoAgent is running %s again; nothing was lost.", err, before)}
		}
	}
	// The new binary prepares the computer runtime it ships with.
	_ = a.delegateQuiet(ctx, installed, "repair-runtime")
	a.UI.Item("ok", a.UI.Bold(fmt.Sprintf("%s %s is ready", appName, installed.Version)), a.url())
	a.UI.Note("Your chats, settings and accounts were kept.")
	return a.reportUpdate(before, installed.Version, fmt.Sprintf("NeoAgent %s is ready. Your chats, settings and accounts were kept.", installed.Version))
}

type codedErr struct{ code, msg string }

func (e *codedErr) Error() string { return e.msg }
func (e *codedErr) Code() string  { return e.code }

func (a *App) reportUpdate(before, after, message string) error {
	a.updateResult = map[string]any{"message": message, "versionBefore": before, "versionAfter": after}
	if !a.JSON {
		return nil
	}
	return cli.WriteJSONLine(a.Out, map[string]string{"message": message, "versionBefore": before, "versionAfter": after})
}

// delegateQuiet runs a command of an installed runtime without output.
func (a *App) delegateQuiet(ctx context.Context, rt installedRuntime, args ...string) error {
	cmd := a.command(ctx, rt, args...)
	return cmd.Run()
}

func (a *App) reportProgress(patch map[string]any) {
	if a.progress != nil {
		a.progress(patch)
	}
}

func channelBranch(channel string) string {
	if release.NormalizeChannel(channel) == release.Beta {
		return "beta"
	}
	return "main"
}

// cmdUpdateRunner is the update started from the admin UI: the same update as
// `neoagent update`, run detached so it outlives the server it restarts, and
// reported through the status file the admin page polls.
func (a *App) cmdUpdateRunner(ctx context.Context, _ []string) error {
	file := updatestatus.File(a.Paths.DataDir)
	pid := os.Getpid()
	_, _ = updatestatus.Write(file, map[string]any{"runnerPid": pid})
	a.progress = func(patch map[string]any) {
		patch["state"], patch["runnerPid"] = "running", pid
		_, _ = updatestatus.Write(file, patch)
		if msg, _ := patch["message"].(string); msg != "" {
			_ = updatestatus.AppendLog(file, msg)
		}
	}
	err := a.cmdUpdate(ctx, []string{a.channel()})
	done := time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
	if err != nil {
		_, _ = updatestatus.Write(file, map[string]any{
			"state": "failed", "phase": "failed", "message": err.Error(),
			"rolledBack": cli.CodeOf(err, "") == "UPDATE_ROLLED_BACK", "completedAt": done, "runnerPid": nil,
		})
		return err
	}
	final := map[string]any{"state": "completed", "progress": 100, "phase": "completed", "completedAt": done, "runnerPid": nil}
	for k, v := range a.updateResult {
		final[k] = v
	}
	_, err = updatestatus.Write(file, final)
	return err
}
