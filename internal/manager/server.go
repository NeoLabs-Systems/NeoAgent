package manager

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/cli"
)

// Handshake is what /api/setup/handshake answers.
type Handshake struct {
	Product         string `json:"product"`
	ProtocolVersion int    `json:"protocolVersion"`
	ServerVersion   string `json:"serverVersion"`
	InstanceID      string `json:"instanceId"`
}

func fetchHandshake(ctx context.Context, port int) *Handshake {
	ctx, cancel := context.WithTimeout(ctx, 1500*time.Millisecond)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("http://127.0.0.1:%d/api/setup/handshake", port), nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	var h Handshake
	if resp.StatusCode != http.StatusOK || json.NewDecoder(io.LimitReader(resp.Body, 64<<10)).Decode(&h) != nil {
		return nil
	}
	if h.Product != "NeoAgent" || h.ProtocolVersion != 1 {
		return nil
	}
	return &h
}

// ownInstanceReachable reports whether this installation answers on port.
// An installation without a database yet (a Node.js one being migrated
// keeps its own) accepts any NeoAgent.
func (a *App) ownInstanceReachable(ctx context.Context, port int) bool {
	if !cli.PortOpen(port) {
		return false
	}
	h := fetchHandshake(ctx, port)
	if h == nil {
		return false
	}
	want := a.instanceID(ctx)
	return want == "" || h.InstanceID == want
}

func (a *App) waitForServerReady(ctx context.Context, port int, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if a.ownInstanceReachable(ctx, port) {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(400 * time.Millisecond):
		}
	}
	return cli.Errorf("SETUP_SERVER_NOT_READY", "NeoAgent did not become reachable on port %d.", port)
}

// Healthcheck exits non-zero unless /api/health answers 2xx (Docker
// HEALTHCHECK). It prints nothing on success.
func Healthcheck(ctx context.Context, getenv func(string) string) error {
	port := 3333
	if n, err := strconv.Atoi(strings.TrimSpace(getenv("PORT"))); err == nil && n > 0 {
		port = n
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("http://127.0.0.1:%d/api/health", port), nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		return fmt.Errorf("health check answered HTTP %d", resp.StatusCode)
	}
	return nil
}

// serverProcess is a running server of this installation: this binary or
// one under the data directory started with `serve`, or the Node.js
// `server/index.js` this user's service definition (or app directory) runs.
// Servers of other installations on the machine are never matched.
type serverProcess struct {
	PID     int
	Command string
}

var (
	goServerPattern = regexp.MustCompile(`(^|[\s"'/])neoagent(\.exe)?["']?\s+serve($|\s)`)
	nodeEntryInText = regexp.MustCompile(`[^\s"'<>=]*server[/\\]index\.js`)
	nodeExecutable  = regexp.MustCompile(`(^|/)node\d*$`)
)

// legacyNodeEntries are the server/index.js paths of a Node.js installation
// this user's service definition still points at.
func (a *App) legacyNodeEntries() []string {
	entries := []string{filepath.ToSlash(filepath.Join(a.AppDir, "server", "index.js"))}
	for _, path := range []string{a.Service.PlistPath, a.Service.UnitPath} {
		raw, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		for _, m := range nodeEntryInText.FindAllString(string(raw), -1) {
			entries = append(entries, strings.ReplaceAll(m, `\`, "/"))
		}
	}
	return entries
}

func (a *App) ownsExecutable(exe string) bool {
	exe = filepath.Clean(exe)
	return exe == filepath.Clean(a.Exe) || strings.HasPrefix(exe, filepath.Clean(a.Paths.Home)+string(filepath.Separator))
}

func (a *App) serverProcesses() []serverProcess {
	if runtime.GOOS == "windows" {
		return nil
	}
	out, err := exec.Command("ps", "-axo", "pid=,command=").Output()
	if err != nil {
		return nil
	}
	nodeEntries := a.legacyNodeEntries()
	var list []serverProcess
	for _, line := range strings.Split(string(out), "\n") {
		pidText, command, ok := strings.Cut(strings.TrimSpace(line), " ")
		if !ok {
			continue
		}
		pid, err := strconv.Atoi(pidText)
		if err != nil || pid == os.Getpid() {
			continue
		}
		command = strings.TrimSpace(command)
		fields := strings.Fields(command)
		if goServerPattern.MatchString(command) && a.ownsExecutable(fields[0]) {
			list = append(list, serverProcess{PID: pid, Command: command})
			continue
		}
		if len(fields) > 1 && nodeExecutable.MatchString(fields[0]) {
			script := strings.ReplaceAll(fields[1], `\`, "/")
			if slices.Contains(nodeEntries, script) {
				list = append(list, serverProcess{PID: pid, Command: command})
			}
		}
	}
	return list
}

func (a *App) killServerProcesses() {
	for _, p := range a.serverProcesses() {
		if proc, err := os.FindProcess(p.PID); err == nil {
			_ = proc.Signal(syscall.SIGTERM)
		}
	}
}

// stopService stops the service and any stray server process.
func (a *App) stopService() {
	a.Service.Stop()
	a.killServerProcesses()
}

func (a *App) waitForServerExit(ctx context.Context, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	for len(a.serverProcesses()) > 0 && time.Now().Before(deadline) {
		select {
		case <-ctx.Done():
			return false
		case <-time.After(250 * time.Millisecond):
		}
	}
	return len(a.serverProcesses()) == 0
}

func (a *App) stopAndWait(ctx context.Context) error {
	a.stopService()
	if !a.waitForServerExit(ctx, 15*time.Second) {
		return fmt.Errorf("NeoAgent did not stop in time. Try again, or restart this computer.")
	}
	return nil
}

// portOwner names the program listening on port when lsof can tell.
func portOwner(port int) (int, string) {
	out, err := exec.Command("lsof", "-nP", fmt.Sprintf("-iTCP:%d", port), "-sTCP:LISTEN", "-Fpc").Output()
	if err != nil {
		return 0, ""
	}
	var pid int
	command := "An app"
	for _, line := range strings.Split(string(out), "\n") {
		if strings.HasPrefix(line, "p") && pid == 0 {
			pid, _ = strconv.Atoi(line[1:])
		}
		if strings.HasPrefix(line, "c") {
			command = line[1:]
		}
	}
	return pid, command
}

// portHeldByOther is true only when something that is not this NeoAgent
// listens on port; that program is never ours to stop.
func (a *App) portHeldByOther(ctx context.Context, port int) bool {
	if !cli.PortOpen(port) || a.ownInstanceReachable(ctx, port) {
		return false
	}
	if pid, _ := portOwner(port); pid > 0 {
		for _, p := range a.serverProcesses() {
			if p.PID == pid {
				return false
			}
		}
		return true
	}
	return !a.Service.Managed()
}

func portInUseError(port int) error {
	return cli.Errorf("SETUP_PORT_IN_USE", "Another app on this computer is already using port %d, the address NeoAgent wants. Close that app, or give NeoAgent another port with `neoagent env set PORT <number>`.", port)
}

// releasePort stops a running NeoAgent so a new one can bind its port.
func (a *App) releasePort(ctx context.Context, port int) error {
	if !cli.PortOpen(port) {
		return nil
	}
	if a.portHeldByOther(ctx, port) {
		return portInUseError(port)
	}
	a.UI.Info(fmt.Sprintf("Stopping the NeoAgent already running on port %d", port))
	a.stopService()
	deadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		time.Sleep(250 * time.Millisecond)
		if !cli.PortOpen(port) {
			return nil
		}
	}
	return cli.Errorf("SETUP_PORT_IN_USE", "Port %d is still in use. Stop whatever is listening on it, then run the update again.", port)
}
