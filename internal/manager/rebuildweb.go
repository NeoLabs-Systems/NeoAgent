package manager

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

// requiredFlutter is the oldest Flutter the web client builds with.
const requiredFlutter = "3.47.9"

// cmdRebuildWeb builds the browser app from flutter_app into public/ — a
// developer command for source checkouts. Release packages carry the built
// app, so without flutter_app or Flutter the bundled copy keeps being used.
func (a *App) cmdRebuildWeb(ctx context.Context, _ []string) error {
	return a.UI.Step("Rebuilding the app", "Rebuilt the app", func() error { return a.rebuildWeb(ctx) })
}

func (a *App) rebuildWeb(ctx context.Context) error {
	sources := filepath.Join(a.AppDir, "flutter_app")
	bundled := exists(filepath.Join(a.AppDir, "public", "index.html"))
	if !exists(sources) {
		// A release package: its app was built for it.
		a.UI.Info("Using the app that came with NeoAgent")
		return nil
	}
	if _, err := exec.LookPath("flutter"); err != nil {
		if bundled {
			a.UI.Info("Using the app that came with NeoAgent")
			return nil
		}
		return fmt.Errorf("Flutter SDK is required to build the web client because no bundled client was found.")
	}
	run := func(dir string, name string, args ...string) (string, error) {
		cmd := exec.CommandContext(ctx, name, args...)
		cmd.Dir = dir
		out, err := cmd.CombinedOutput()
		return string(out), err
	}
	if installed := flutterVersion(run); installed != "" && release.CompareVersions(installed, requiredFlutter) < 0 {
		a.UI.Info("Updating Flutter to " + requiredFlutter + " or newer")
		_, _ = run(sources, "flutter", "upgrade")
		if upgraded := flutterVersion(run); upgraded == "" || release.CompareVersions(upgraded, requiredFlutter) < 0 {
			if bundled {
				a.UI.Info("Using the app that came with NeoAgent")
				return nil
			}
			return fmt.Errorf("Flutter could not be updated to %s, which the web client needs. Run `flutter upgrade` and try again.", requiredFlutter)
		}
	}
	if script := filepath.Join(a.AppDir, "scripts", "repair_pub_cache.sh"); exists(script) {
		if out, err := run(filepath.Dir(script), "bash", script); err != nil {
			return fmt.Errorf("Failed to repair Flutter pub cache ownership before web rebuild.\n%s", tailLines(out))
		}
	}
	if out, err := run(sources, "flutter", "pub", "get"); err != nil {
		return fmt.Errorf("Flutter pub get failed before web rebuild.\n%s", tailLines(out))
	}
	a.UI.Info("Building the app — this can take a few minutes")
	out, err := run(sources, "flutter", "build", "web", "--no-wasm-dry-run", "--output", "../public",
		"--dart-define=NEOAGENT_BACKEND_URL="+os.Getenv("NEOAGENT_BACKEND_URL"))
	if err != nil {
		if bundled {
			a.UI.Warn("The app could not be rebuilt; the bundled copy stays in use.\n" + tailLines(out))
			return nil
		}
		return fmt.Errorf("Flutter web build failed and no bundled web client is available.\n%s", tailLines(out))
	}
	return nil
}

func flutterVersion(run func(string, string, ...string) (string, error)) string {
	out, err := run("", "flutter", "--version", "--machine")
	start := strings.Index(out, "{")
	if err != nil || start < 0 {
		return ""
	}
	var v struct {
		FrameworkVersion string `json:"frameworkVersion"`
	}
	if json.Unmarshal([]byte(out[start:]), &v) != nil {
		return ""
	}
	return v.FrameworkVersion
}

func tailLines(s string) string {
	lines := strings.Split(strings.TrimSpace(s), "\n")
	if len(lines) > 12 {
		lines = lines[len(lines)-12:]
	}
	return strings.Join(lines, "\n")
}
