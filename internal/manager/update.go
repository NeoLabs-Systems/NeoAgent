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

// restartInto stops the running NeoAgent and starts rt in its place. It
// returns how many cut-off tasks the new server resumes.
func (a *App) restartInto(ctx context.Context, rt installedRuntime) (int, error) {
	if err := a.ensureSecrets(); err != nil {
		return 0, err
	}
	if err := a.stopAndWait(ctx); err != nil {
		return 0, err
	}
	resumable := a.countResumableRuns(ctx)
	if err := a.writeCurrent(rt.Version); err != nil {
		return 0, err
	}
	a.useBinary(rt.binary(), rt.appDir())
	return resumable, a.Service.Install()
}

// verifyRunning waits until NeoAgent answers on port with rt's version.
func (a *App) verifyRunning(ctx context.Context, rt installedRuntime, port int) error {
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
		a.UI.Blank()
		a.UI.OK(fmt.Sprintf("You have the latest version (%s)", before))
		a.UI.Blank()
		return a.reportUpdate(before, before, "You have the latest version ("+before+")")
	}
	if notesOnly {
		a.UI.Blank()
		a.UI.Item("warn", a.UI.Bold(available.Version+" is ready"), "you have "+before)
		a.UI.Blank()
		a.UI.Note("Get it with " + a.UI.Command("neoagent update") + ".")
		a.UI.Blank()
		return a.reportUpdate(before, available.Version, available.Version+" is ready")
	}
	a.reportProgress(map[string]any{"progress": 10, "phase": "preparing", "message": "Preparing the update", "versionAfter": available.Version, "targetBranch": channelBranch(channel), "changelog": []any{}})
	a.UI.Title("Updating "+appName, fmt.Sprintf("%s → %s · %s", before, available.Version, channel))
	a.UI.Blank()
	port := a.Port()
	var installed installedRuntime
	var archive string
	snapshot := a.snapshotService()
	resumable := 0
	switched := false
	steps := []struct {
		phase string
		run   func() error
	}{
		{"backup", func() error {
			_, err := a.backupRuntimeData(ctx, "pre-update")
			return err
		}},
		{"downloading", func() (err error) {
			archive, err = a.downloadRuntime(ctx, available)
			return err
		}},
		{"installing", func() (err error) {
			installed, err = a.installRuntime(ctx, available, archive, true)
			return err
		}},
		{"restarting", func() (err error) {
			switched = true
			resumable, err = a.restartInto(ctx, installed)
			return err
		}},
		{"verifying", func() error {
			if err := a.verifyRunning(ctx, installed, port); err != nil {
				return err
			}
			// The new binary prepares the computer runtime it ships with.
			_ = a.delegateQuiet(ctx, installed, "repair-runtime")
			return nil
		}},
	}
	list := a.UI.Steps([]cli.Label{
		{Doing: "Saving a backup of your settings and chats", Done: "Saved a backup of your settings and chats"},
		{Doing: "Downloading the new version", Done: "Downloaded the new version"},
		{Doing: "Installing it", Done: "Installed it"},
		{Doing: "Restarting NeoAgent", Done: "Restarted NeoAgent"},
		{Doing: "Making sure it all works", Done: "Made sure it all works"},
	}, true)
	for i, s := range steps {
		a.reportProgress(map[string]any{"progress": 15 + i*16, "phase": s.phase, "message": list.Doing(i)})
		if err := list.Run(i, s.run); err != nil {
			if !switched {
				list.Close()
				return err
			}
			a.reportProgress(map[string]any{"progress": 85, "phase": "rollback", "message": fmt.Sprintf("Restoring %s after the update failed", before)})
			rollback := list.Add(cli.Label{Doing: "Going back to " + before, Done: "Went back to " + before})
			rerr := list.Run(rollback, func() error { return a.restoreService(ctx, snapshot, port) })
			list.Close()
			if rerr != nil {
				return &codedErr{code: "UPDATE_ROLLBACK_FAILED", msg: fmt.Sprintf("%s\nGoing back to %s also failed: %s", err, before, rerr)}
			}
			return &codedErr{code: "UPDATE_ROLLED_BACK", msg: fmt.Sprintf("%s\nNeoAgent is running %s again; nothing was lost.", err, before)}
		}
	}
	list.Close()
	a.UI.Blank()
	a.UI.Item("ok", a.UI.Bold(fmt.Sprintf("%s %s is ready", appName, installed.Version)), a.url())
	a.UI.Blank()
	a.printResumeNote(resumable, "now")
	a.UI.Note("Your chats, settings and accounts were kept.")
	a.UI.Blank()
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
