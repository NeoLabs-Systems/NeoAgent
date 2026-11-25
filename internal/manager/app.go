// Package manager is the `neoagent` command line: installing NeoAgent as a
// per-user service, its settings, status and repair, updates from signed
// release manifests and the move from a Node.js installation. The server
// itself runs through `neoagent serve` (cmd/neoagent).
package manager

import (
	"context"
	"database/sql"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/buildinfo"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/setupapi"
	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/cli/envfile"
	"github.com/NeoLabs-Systems/neolabs-go/cli/service"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/runtimecfg"
)

const appName = "NeoAgent"

// App is one CLI invocation.
type App struct {
	Paths   runtimecfg.Paths
	Exe     string // resolved path of this binary
	AppDir  string // holds public/, landing/ and computer-runtime/
	UI      *cli.UI
	Events  *cli.EventWriter
	JSON    bool
	Service *service.Manager
	Out     io.Writer
	Getenv  func(string) string
	// notes collects what the user still has to do after an install.
	notes []string
	// releaseAPI replaces the GitHub API (tests serve releases locally).
	releaseAPI string
	// login replaces the AI providers' OAuth endpoints (tests).
	login *loginEndpoints
	// boot builds the application for exec and migrate.
	boot Booter
	// progress receives update steps when the admin UI runs the update.
	progress func(patch map[string]any)
	// updateResult is what the last update reported.
	updateResult map[string]any
}

// Platform is "macos", "linux", "windows" or the GOOS name.
func Platform() string {
	if runtime.GOOS == "darwin" {
		return "macos"
	}
	return runtime.GOOS
}

// Architecture is "x64" or "arm64" (the setup contract's names).
func Architecture() string {
	if runtime.GOARCH == "amd64" {
		return "x64"
	}
	return runtime.GOARCH
}

// New prepares the paths and loads the env file into the process
// environment (never overriding real variables), like the server does.
func New(args []string) (*App, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	paths := runtimecfg.Resolve("NEOAGENT", ".neoagent", os.Getenv, home)
	if err := runtimecfg.LoadEnvFile(paths.EnvFile, os.LookupEnv, os.Setenv); err != nil {
		return nil, fmt.Errorf("load %s: %w", paths.EnvFile, err)
	}
	exe, err := os.Executable()
	if err != nil {
		return nil, err
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}
	jsonOut := cli.HasFlag(args, "--json")
	a := &App{Paths: paths, Exe: exe, UI: cli.NewUI(jsonOut), JSON: jsonOut, Out: os.Stdout, Getenv: os.Getenv}
	a.AppDir = a.resolveAppDir()
	profile := "quick"
	if cli.HasFlag(args, "--full") {
		profile = "full"
	}
	a.Events = cli.NewEventWriter(setupcontract.C.SchemaVersion, setupcontract.C.EventStages, profile, jsonOut, os.Stdout)
	a.Service, err = service.New(a.serviceSpec(), Platform())
	if err != nil {
		return nil, err
	}
	a.Service.Logf = func(level, msg string) {
		if level == "warn" {
			a.UI.Warn(msg)
		} else {
			a.UI.OK(msg)
		}
	}
	return a, nil
}

// resolveAppDir finds the directory with the web client: NEOAGENT_APP_DIR,
// the parent of a bin/ directory holding this binary (runtime packages), or
// the working directory (a source checkout).
func (a *App) resolveAppDir() string {
	if v := strings.TrimSpace(os.Getenv("NEOAGENT_APP_DIR")); v != "" {
		return v
	}
	if dir := filepath.Dir(a.Exe); filepath.Base(dir) == "bin" {
		parent := filepath.Dir(dir)
		if exists(filepath.Join(parent, "public")) {
			return parent
		}
	}
	cwd, _ := os.Getwd()
	return cwd
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func (a *App) serviceSpec() service.Spec {
	home, _ := os.UserHomeDir()
	path := "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
	if Platform() == "macos" {
		path = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
	}
	return service.Spec{
		Label: "com.neoagent", Name: "neoagent", TaskName: "NeoAgent",
		Description: "NeoAgent — Proactive personal AI agent",
		Program:     a.Exe, Args: []string{"serve"}, WorkDir: a.AppDir,
		Env: []service.EnvVar{
			{Key: "PATH", Value: path}, {Key: "HOME", Value: home},
			{Key: "NEOAGENT_ENV", Value: "production"},
			{Key: "NEOAGENT_HOME", Value: a.Paths.Home}, {Key: "NEOAGENT_APP_DIR", Value: a.AppDir},
		},
		EnvFile: a.Paths.EnvFile, LogDir: a.Paths.LogDir, LogName: "neoagent",
		PIDFile: filepath.Join(a.Paths.DataDir, "neoagent.pid"),
	}
}

// useBinary points the service at another installed binary and app dir.
func (a *App) useBinary(exe, appDir string) {
	a.Exe, a.AppDir = exe, appDir
	a.Service.Spec = a.serviceSpec()
}

func (a *App) env() map[string]string {
	values, _ := envfile.Load(a.Paths.EnvFile)
	if values == nil {
		values = map[string]string{}
	}
	return values
}

func (a *App) setEnv(key, value string) error {
	if err := envfile.Upsert(a.Paths.EnvFile, key, value); err != nil {
		return err
	}
	return os.Setenv(key, value)
}

// Port is PORT (the environment, then the env file), else the default.
func (a *App) Port() int {
	if n, err := strconv.Atoi(strings.TrimSpace(os.Getenv("PORT"))); err == nil && n > 0 {
		return n
	}
	return setupcontract.C.DefaultPort
}

func (a *App) url() string { return "http://localhost:" + strconv.Itoa(a.Port()) }

func (a *App) dbPath() string { return filepath.Join(a.Paths.DataDir, "neoagent.db") }

// openDB opens the main database and brings its schema up to date, as the
// server does on start. The server may run at the same time (WAL).
func (a *App) openDB(ctx context.Context) (*dbx.DB, error) {
	db, err := dbx.Open(ctx, a.dbPath(), dbx.Options{})
	if err != nil {
		return nil, err
	}
	if err := schema.Ensure(ctx, db.W); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

// instanceID reads the instance id without creating or migrating anything.
func (a *App) instanceID(ctx context.Context) string {
	if !exists(a.dbPath()) {
		return ""
	}
	db, err := sql.Open("sqlite", "file:"+a.dbPath()+"?mode=ro")
	if err != nil {
		return ""
	}
	defer db.Close()
	var id string
	if err := db.QueryRowContext(ctx, `SELECT instance_id FROM neoagent_instance WHERE singleton_id = 1`).Scan(&id); err != nil {
		return ""
	}
	return id
}

// ensureInstance creates the database and the instance id before the first
// start, so the readiness check knows which server is ours.
func (a *App) ensureInstance(ctx context.Context) error {
	db, err := a.openDB(ctx)
	if err != nil {
		return err
	}
	defer db.Close()
	setupapi.EnsureInstance(ctx, db, os.Getenv)
	return nil
}

func (a *App) hasAccount(ctx context.Context) bool {
	if !exists(a.dbPath()) {
		return false
	}
	db, err := sql.Open("sqlite", "file:"+a.dbPath()+"?mode=ro")
	if err != nil {
		return false
	}
	defer db.Close()
	var one int
	return db.QueryRowContext(ctx, `SELECT 1 FROM users LIMIT 1`).Scan(&one) == nil
}

func (a *App) note(text string) { a.notes = append(a.notes, text) }

// version is the build version.
func version() string { return buildinfo.Version }

// usageError is a wrong command line.
func usageError(format string, args ...any) error {
	return fmt.Errorf(format, args...)
}
