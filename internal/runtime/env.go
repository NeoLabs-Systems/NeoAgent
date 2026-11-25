package runtime

import (
	"log/slog"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// Dirs are the locations the runtime reads and writes.
type Dirs struct {
	// AppDir holds files shipped next to the server (computer-runtime/...).
	AppDir string
	// RuntimeHome is NEOAGENT_HOME, DataDir the data directory beneath it.
	RuntimeHome string
	DataDir     string
}

func (d Dirs) computerRoot() string  { return filepath.Join(d.DataDir, "computers") }
func (d Dirs) imageRoot() string     { return filepath.Join(d.computerRoot(), "images") }
func (d Dirs) instanceRoot() string  { return filepath.Join(d.computerRoot(), "instances") }
func (d Dirs) vmRoot() string        { return filepath.Join(d.DataDir, "runtime-vms") }
func (d Dirs) containerRoot() string { return filepath.Join(d.DataDir, "runtime-containers") }

// Env is the process environment the runtime reads settings from. A nil Getenv
// reads the real environment.
type Env struct {
	Getenv func(string) string
	Log    *slog.Logger
}

func (e Env) get(name string) string {
	if e.Getenv != nil {
		return e.Getenv(name)
	}
	return os.Getenv(name)
}

func (e Env) logger() *slog.Logger {
	if e.Log != nil {
		return e.Log
	}
	return slog.New(slog.NewTextHandler(discard{}, nil))
}

type discard struct{}

func (discard) Write(p []byte) (int, error) { return len(p), nil }

func ensurePrivateDir(dir string) error {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	if runtime.GOOS == "windows" {
		return nil
	}
	return os.Chmod(dir, 0o700)
}

func ensurePrivateFile(path string) {
	if runtime.GOOS == "windows" {
		return
	}
	if _, err := os.Stat(path); err == nil {
		_ = os.Chmod(path, 0o600)
	}
}

func trimmed(s string) string { return strings.TrimSpace(s) }

// goArchitecture names the host architecture the way the runtime does: "arm64"
// or "x64".
func hostArchitecture() string {
	if runtime.GOARCH == "arm64" {
		return "arm64"
	}
	return "x64"
}

// normalizeArchitecture maps aarch64/arm64 to "arm64" and anything else to "x64".
func normalizeArchitecture(value string) string {
	switch strings.ToLower(value) {
	case "arm64", "aarch64":
		return "arm64"
	}
	return "x64"
}
