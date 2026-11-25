package manager

import (
	"bytes"
	"context"
	"database/sql"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

// Folders under data/ a backup leaves out: the computers' disks (saved
// separately by `neoagent backup`) and teach recordings.
var backupExcluded = []string{"computers", "teach-sessions"}

var sqliteHeader = []byte("SQLite format 3\x00")

func isSQLite(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	head := make([]byte, len(sqliteHeader))
	_, err = io.ReadFull(f, head)
	return err == nil && bytes.Equal(head, sqliteHeader)
}

// snapshotSQLite writes a consistent copy of a live database. The running
// server may hold a write lock for a moment, so the copy waits for it.
func snapshotSQLite(ctx context.Context, src, dst string) error {
	db, err := sql.Open("sqlite", "file:"+src+"?mode=ro&_pragma=busy_timeout(15000)")
	if err != nil {
		return err
	}
	defer db.Close()
	_, err = db.ExecContext(ctx, `VACUUM INTO ?`, dst)
	return err
}

func copyPlain(src, dst string, mode os.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o700); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

// copyData copies a tree; SQLite databases are snapshotted (their -wal and
// -shm files are folded in), everything else copied as is.
func copyData(ctx context.Context, src, dst string, skip func(rel string) bool) error {
	return filepath.WalkDir(src, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		if rel != "." && skip != nil && skip(rel) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		target := filepath.Join(dst, rel)
		switch {
		case d.IsDir():
			return os.MkdirAll(target, 0o700)
		case !d.Type().IsRegular():
			return nil
		case strings.HasSuffix(path, "-wal") || strings.HasSuffix(path, "-shm"):
			if isSQLite(strings.TrimSuffix(strings.TrimSuffix(path, "-wal"), "-shm")) {
				return nil
			}
		case isSQLite(path):
			if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
				return err
			}
			_ = os.Remove(target)
			return snapshotSQLite(ctx, path, target)
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		return copyPlain(path, target, info.Mode().Perm()|0o600)
	})
}

// backupRuntimeData saves .env, data/ (without computer disks) and
// agent-data/ into <home>/backups/<prefix>-<timestamp>. Only the newest three
// pre-update backups are kept.
func (a *App) backupRuntimeData(ctx context.Context, prefix string) (string, error) {
	backups := filepath.Join(a.Paths.Home, "backups")
	stamp := strings.ReplaceAll(time.Now().UTC().Format("2006-01-02T15:04:05Z"), ":", "-")
	target := filepath.Join(backups, prefix+"-"+stamp)
	if exists(target) {
		target += "-" + randomHex(3)
	}
	if err := os.MkdirAll(target, 0o700); err != nil {
		return "", err
	}
	if exists(a.Paths.EnvFile) {
		if err := copyPlain(a.Paths.EnvFile, filepath.Join(target, ".env"), 0o600); err != nil {
			return "", err
		}
	}
	if exists(a.Paths.DataDir) {
		skip := func(rel string) bool {
			for _, ex := range backupExcluded {
				if rel == ex || strings.HasPrefix(rel, ex+string(filepath.Separator)) {
					return true
				}
			}
			return rel == "logs" || strings.HasPrefix(rel, "logs"+string(filepath.Separator))
		}
		if err := copyData(ctx, a.Paths.DataDir, filepath.Join(target, "data"), skip); err != nil {
			return "", fmt.Errorf("backing up %s: %w", a.Paths.DataDir, err)
		}
	}
	if exists(a.Paths.AgentDataDir) {
		if err := copyData(ctx, a.Paths.AgentDataDir, filepath.Join(target, "agent-data"), nil); err != nil {
			return "", fmt.Errorf("backing up %s: %w", a.Paths.AgentDataDir, err)
		}
	}
	pruneBackups(backups, "pre-update-", 3)
	return target, nil
}

func pruneBackups(dir, prefix string, keep int) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	type entry struct {
		path string
		mod  time.Time
	}
	var list []entry
	for _, e := range entries {
		if !e.IsDir() || !strings.HasPrefix(e.Name(), prefix) {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		list = append(list, entry{filepath.Join(dir, e.Name()), info.ModTime()})
	}
	sort.Slice(list, func(i, j int) bool {
		if !list[i].mod.Equal(list[j].mod) {
			return list[i].mod.After(list[j].mod)
		}
		return list[i].path > list[j].path
	})
	for i := keep; i < len(list); i++ {
		_ = os.RemoveAll(list[i].path)
	}
}

func (a *App) qemuImg() string {
	staged := filepath.Join(a.Paths.Home, "computer-runtime", "qemu", "bin", vm.ExecutableName("qemu-img"))
	if exists(staged) {
		return staged
	}
	if p, err := exec.LookPath("qemu-img"); err == nil {
		return p
	}
	return ""
}

func (a *App) instancesRoot() string { return filepath.Join(a.Paths.DataDir, "computers", "instances") }

// backupComputerDisks saves each computer's disks compressed, verified with
// qemu-img check, plus its small state files.
func (a *App) backupComputerDisks(ctx context.Context, target string) (int, error) {
	img := a.qemuImg()
	entries, err := os.ReadDir(a.instancesRoot())
	if img == "" || err != nil {
		return 0, nil
	}
	disks := 0
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		src := filepath.Join(a.instancesRoot(), e.Name())
		dst := filepath.Join(target, "data", "computers", "instances", e.Name())
		if err := os.MkdirAll(dst, 0o700); err != nil {
			return disks, err
		}
		for _, name := range []string{"base-build", "guest-token", "workspace-migration.json"} {
			if exists(filepath.Join(src, name)) {
				if err := copyPlain(filepath.Join(src, name), filepath.Join(dst, name), 0o600); err != nil {
					return disks, err
				}
			}
		}
		files, _ := os.ReadDir(src)
		for _, f := range files {
			if !strings.HasSuffix(f.Name(), ".qcow2") {
				continue
			}
			out := filepath.Join(dst, f.Name())
			if b, err := exec.CommandContext(ctx, img, "convert", "-O", "qcow2", "-c", filepath.Join(src, f.Name()), out).CombinedOutput(); err != nil {
				return disks, fmt.Errorf("Computer disk backup failed for %s/%s: %s", e.Name(), f.Name(), strings.TrimSpace(string(b)))
			}
			if err := exec.CommandContext(ctx, img, "check", out).Run(); err != nil {
				return disks, fmt.Errorf("Computer disk backup verification failed for %s/%s.", e.Name(), f.Name())
			}
			disks++
		}
	}
	profile := filepath.Join(a.Paths.Home, "computer-runtime", "profile.json")
	if exists(profile) {
		if err := copyPlain(profile, filepath.Join(target, "computer-runtime", "profile.json"), 0o600); err != nil {
			return disks, err
		}
	}
	return disks, nil
}

// repairComputerDisks runs qemu-img check on every disk and repairs leaks.
func (a *App) repairComputerDisks(ctx context.Context) (checked, repaired int, err error) {
	img := a.qemuImg()
	if img == "" || !exists(a.instancesRoot()) {
		return 0, 0, nil
	}
	err = filepath.WalkDir(a.instancesRoot(), func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(d.Name(), ".qcow2") {
			return err
		}
		checked++
		if exec.CommandContext(ctx, img, "check", path).Run() == nil {
			return nil
		}
		if exec.CommandContext(ctx, img, "check", "-r", "leaks", path).Run() != nil {
			return fmt.Errorf("Computer disk repair failed: %s", path)
		}
		repaired++
		return nil
	})
	return checked, repaired, err
}

func (a *App) cmdBackup(ctx context.Context, _ []string) error {
	wasRunning := len(a.serverProcesses()) > 0 || cli.PortOpen(a.Port())
	sub := ""
	if wasRunning {
		sub = "NeoAgent pauses while the backup is made."
	}
	a.UI.Title("Backing up "+appName, sub)
	a.UI.Blank()
	var target string
	steps := []cli.Step{
		{Label: cli.Label{Doing: "Saving your settings and chats", Done: "Saved your settings and chats"}, Run: func() (err error) {
			target, err = a.backupRuntimeData(ctx, "manual")
			return err
		}},
		{Label: cli.Label{Doing: "Saving the agent's computer", Done: "Saved the agent's computer"}, Run: func() error {
			_, err := a.backupComputerDisks(ctx, target)
			return err
		}},
	}
	if wasRunning {
		steps = append([]cli.Step{{Label: cli.Label{Doing: "Pausing NeoAgent", Done: "Paused NeoAgent"}, Run: func() error {
			a.stopService()
			if !a.waitForServerExit(ctx, 15*time.Second) {
				return fmt.Errorf("NeoAgent did not stop in time for a consistent computer backup.")
			}
			return nil
		}}}, steps...)
		steps = append(steps, cli.Step{Label: cli.Label{Doing: "Starting NeoAgent again", Done: "Started NeoAgent again"}, Run: func() error {
			if err := a.Service.Launch(); err != nil {
				return err
			}
			return a.waitForServerReady(ctx, a.Port(), 30*time.Second)
		}})
	}
	if err := a.UI.RunSteps(false, steps...); err != nil {
		// A failed backup must not leave NeoAgent switched off.
		if wasRunning && len(a.serverProcesses()) == 0 && !cli.PortOpen(a.Port()) {
			_ = a.cmdStart(ctx, nil)
		}
		return err
	}
	if a.JSON {
		return cli.WriteJSONLine(a.Out, map[string]string{"backup": target})
	}
	a.UI.Blank()
	a.UI.Item("ok", a.UI.Bold("Backup saved"), target)
	a.UI.Blank()
	return nil
}

// cmdRestore puts a backup back. The current data is backed up first, so a
// restore can itself be undone.
func (a *App) cmdRestore(ctx context.Context, args []string) error {
	pos := cli.Positionals(args)
	if len(pos) != 1 {
		return usageError("Usage: neoagent restore <backup folder>  (see %s)", filepath.Join(a.Paths.Home, "backups"))
	}
	src, err := filepath.Abs(pos[0])
	if err != nil {
		return err
	}
	if !exists(filepath.Join(src, "data")) && !exists(filepath.Join(src, ".env")) {
		return fmt.Errorf("%s is not a NeoAgent backup (no data/ or .env inside).", src)
	}
	if a.UI.Interactive() {
		ok, err := a.UI.Confirm("Replace the current settings and chats with this backup? They are backed up first.", false)
		if err != nil || !ok {
			return err
		}
	}
	wasRunning := len(a.serverProcesses()) > 0 || cli.PortOpen(a.Port())
	a.UI.Title("Restoring "+appName, "Your current settings and chats are backed up first.")
	a.UI.Blank()
	var safety string
	if err := a.UI.RunSteps(false,
		cli.Step{Label: cli.Label{Doing: "Stopping NeoAgent", Done: "Stopped NeoAgent"}, Run: func() error { return a.stopAndWait(ctx) }},
		cli.Step{Label: cli.Label{Doing: "Saving the current data first", Done: "Saved the current data"}, Run: func() (err error) {
			safety, err = a.backupRuntimeData(ctx, "pre-restore")
			return err
		}},
		cli.Step{Label: cli.Label{Doing: "Restoring the backup", Done: "Restored the backup"}, Run: func() error { return a.restoreFrom(ctx, src) }},
	); err != nil {
		if safety != "" {
			a.UI.Warn("The data from before the restore is in " + safety)
		}
		return err
	}
	a.UI.Blank()
	a.UI.Item("ok", a.UI.Bold("Backup restored"), src)
	a.UI.Note("The data from before the restore is in " + safety)
	if wasRunning || a.Service.Installed() {
		return a.cmdStart(ctx, nil)
	}
	a.UI.Blank()
	return nil
}

func (a *App) restoreFrom(ctx context.Context, src string) error {
	if exists(filepath.Join(src, ".env")) {
		if err := copyPlain(filepath.Join(src, ".env"), a.Paths.EnvFile, 0o600); err != nil {
			return err
		}
	}
	for _, pair := range [][2]string{{"data", a.Paths.DataDir}, {"agent-data", a.Paths.AgentDataDir}} {
		from := filepath.Join(src, pair[0])
		if !exists(from) {
			continue
		}
		// A restored database must not meet the old one's write-ahead log.
		_ = filepath.WalkDir(from, func(path string, d os.DirEntry, err error) error {
			if err == nil && !d.IsDir() && isSQLite(path) {
				rel, _ := filepath.Rel(from, path)
				_ = os.Remove(filepath.Join(pair[1], rel) + "-wal")
				_ = os.Remove(filepath.Join(pair[1], rel) + "-shm")
			}
			return nil
		})
		if err := copyData(ctx, from, pair[1], nil); err != nil {
			return err
		}
	}
	return nil
}
