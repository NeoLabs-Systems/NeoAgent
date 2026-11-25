// Package guest is the agent that runs inside a computer (a QEMU guest or a
// container) and serves the host's runtime over HTTP: shell commands, files,
// the workspace, the desktop and the reverse proxy for shared pages.
package guest

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime/cli"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

const (
	jsonBodyLimit          = 100 << 20
	maxWorkspaceFileBytes  = 16 << 20
	defaultMinFreeDisk     = 256 << 20
	defaultMaxImportBytes  = 4 << 30
	cloudInitBootFinished  = "/var/lib/cloud/instance/boot-finished"
	runtimeName            = "guest-agent"
	defaultDisplay         = ":0"
	diskLimitCode          = "COMPUTER_DISK_LIMIT"
	diskLimitMessage       = "The computer data disk has reached its safety limit. Remove files before continuing."
	maxReadableFileBytes   = 128 << 20
	workspacePathOutside   = "Workspace path is outside the computer workspace."
	workspacePathNotExists = "Workspace path does not exist."
)

// Config describes one guest agent.
type Config struct {
	Token   string
	Port    int
	Profile string
	// RuntimeHome is NEOAGENT_HOME (default ~/.neoagent); DataDir its data directory.
	RuntimeHome string
	DataDir     string
	// WorkspaceRoot is the directory the agent works in and confines files to.
	WorkspaceRoot string
	// HomeDir is the account's home, where imports are staged and teach events live.
	HomeDir string

	MinFreeDiskBytes int64
	MaxImportBytes   int64
	Executor         *cli.Executor
	// CloudInitFinishedPath overrides the boot marker (tests).
	CloudInitFinishedPath string
}

// Server is the guest agent's HTTP surface.
type Server struct {
	cfg      Config
	fileRoot string
	ws       workspace
	exec     *cli.Executor
	mux      *http.ServeMux
	desktop  desktopRunner
	launch   func(name string, args []string, env []string) error
	// waitScale stretches or shrinks the waits for the display; tests shrink it.
	waitScale float64
	readables []string
}

// New prepares directories and routes. Without an executor it creates one, and
// fails only when the machine has no usable shell.
func New(cfg Config) (*Server, error) {
	if strings.TrimSpace(cfg.Token) == "" {
		return nil, errors.New("a guest token is required")
	}
	home := cfg.HomeDir
	if home == "" {
		home, _ = os.UserHomeDir()
	}
	cfg.HomeDir = home
	if cfg.RuntimeHome == "" {
		cfg.RuntimeHome = envOrDefault("NEOAGENT_HOME", filepath.Join(home, ".neoagent"))
	}
	if cfg.DataDir == "" {
		cfg.DataDir = envOrDefault("NEOAGENT_DATA_DIR", filepath.Join(cfg.RuntimeHome, "data"))
	}
	if cfg.WorkspaceRoot == "" {
		cfg.WorkspaceRoot = envOrDefault(guestproto.EnvWorkspaceDir, filepath.Join(home, "workspace"))
	}
	if cfg.Port == 0 {
		cfg.Port = guestproto.DefaultPort
	}
	if cfg.MinFreeDiskBytes == 0 {
		cfg.MinFreeDiskBytes = defaultMinFreeDisk
	}
	if cfg.MaxImportBytes == 0 {
		cfg.MaxImportBytes = defaultMaxImportBytes
	}
	cfg.Profile = guestproto.NormalizeProfile(cfg.Profile)
	if cfg.CloudInitFinishedPath == "" {
		cfg.CloudInitFinishedPath = cloudInitBootFinished
	}
	root, err := filepath.Abs(cfg.WorkspaceRoot)
	if err != nil {
		return nil, err
	}
	s := &Server{cfg: cfg, fileRoot: filepath.Join(cfg.RuntimeHome, "guest-agent-files"), ws: workspace{root: root}, mux: http.NewServeMux(), desktop: systemRunner{}, launch: launchDetached, waitScale: 1}
	for _, dir := range []string{s.fileRoot, root} {
		if err := os.MkdirAll(dir, 0o777); err != nil {
			return nil, err
		}
	}
	s.exec = cfg.Executor
	if s.exec == nil && profileHasCLI(cfg.Profile) {
		if s.exec, err = cli.NewExecutor(); err != nil {
			return nil, err
		}
	}
	s.readables = s.readableRoots()
	s.routes()
	return s, nil
}

func profileHasCLI(profile string) bool {
	return profile == guestproto.ProfileCLI || profile == guestproto.ProfileBrowserCLI || profile == guestproto.ProfileAndroid
}

// Profile is the capability set this guest runs with.
func (s *Server) Profile() string { return s.cfg.Profile }

// Port is the port the guest agent's own listener uses; /proxy refuses it.
func (s *Server) Port() int { return s.cfg.Port }

// Handler is the root handler.
func (s *Server) Handler() http.Handler { return s.mux }

// Shutdown ends the commands that are still running.
func (s *Server) Shutdown() {
	if s.exec != nil {
		s.exec.KillAll("shutdown")
	}
}

// DataDir is the guest's data directory (screenshots, browser profiles).
func (s *Server) DataDir() string { return s.cfg.DataDir }

// Handle mounts a handler behind the same bearer token as the built-in routes,
// so the browser, Android and Tailscale domains can serve from the guest.
func (s *Server) Handle(pattern string, h http.Handler) { s.mux.Handle(pattern, s.auth(h)) }

func (s *Server) route(pattern string, h http.HandlerFunc) { s.mux.Handle(pattern, s.auth(h)) }

func (s *Server) routes() {
	s.mux.HandleFunc("GET /health", s.health)
	s.mux.Handle("/proxy/", s.auth(http.HandlerFunc(s.proxy)))
	s.mux.Handle("/proxy", s.auth(http.HandlerFunc(s.proxy)))
	s.route("GET /system/boot-assets", s.bootAssets)
	s.route("POST /exec", s.execute)
	s.route("POST /exec/kill", s.execKill)
	s.route("POST /files/read", s.filesRead)
	s.route("POST /workspace/import", s.workspaceImport)
	s.route("GET /workspace/files", s.workspaceList)
	s.route("GET /workspace/files/content", s.workspaceRead)
	s.route("PUT /workspace/files/content", s.workspaceWrite)
	s.route("GET /workspace/files/download", s.workspaceDownload)
	s.route("POST /workspace/search", s.workspaceSearch)
	s.route("GET /desktop/status", s.desktopStatus)
	s.route("POST /desktop/ensure", s.desktopEnsure)
	s.route("POST /desktop/screenshot", s.desktopScreenshot)
	s.route("POST /desktop/click", s.desktopClick)
	s.route("POST /desktop/mouse-move", s.desktopMouseMove)
	s.route("POST /desktop/drag", s.desktopDrag)
	s.route("POST /desktop/scroll", s.desktopScroll)
	s.route("POST /desktop/type-text", s.desktopTypeText)
	s.route("POST /desktop/press-key", s.desktopPressKey)
	s.route("POST /desktop/launch-app", s.desktopLaunchApp)
	s.route("GET /teach/context", s.teachContext)
	s.mux.Handle("/", s.auth(http.NotFoundHandler()))
}

// work runs a handler body the way Node's handle() does: its value is the
// JSON answer and any error is a 500 carrying the message.
func work(w http.ResponseWriter, fn func() (any, error)) {
	value, err := fn()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, value)
}

func writeJSON(w http.ResponseWriter, status int, value any) { httpx.WriteJSON(w, status, value) }

func errorBody(message string) map[string]any { return map[string]any{"error": message} }

// readBody decodes a JSON request body. Anything that is not JSON reads as an
// empty object, as with Express's json parser.
func readBody(r *http.Request) (map[string]any, error) {
	body := map[string]any{}
	if r.Body == nil || !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return body, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, jsonBodyLimit))
	if err != nil {
		return nil, err
	}
	if len(bytes.TrimSpace(raw)) == 0 {
		return body, nil
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	if err := dec.Decode(&body); err != nil || body == nil {
		return nil, errors.New("Invalid JSON body.")
	}
	return body, nil
}

func envOrDefault(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}

func isoTime(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }
