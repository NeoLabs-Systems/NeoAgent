package manager

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/release"
	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	nlrelease "github.com/NeoLabs-Systems/neolabs-go/cli/release"
	"github.com/NeoLabs-Systems/neolabs-go/cli/update"
)

// Installed runtime packages live in <home>/app/versions/<version>, and
// <home>/app/current.json names the active one. The desktop app uses the
// same layout.

// installedRuntime is one unpacked runtime package.
type installedRuntime struct {
	Version string
	Dir     string // .../versions/<version>
}

func (r installedRuntime) appDir() string { return filepath.Join(r.Dir, "app") }
func (r installedRuntime) binary() string {
	return filepath.Join(r.appDir(), "bin", release.BinaryName(Platform()))
}

// refreshLauncher updates the standalone command installed by install.sh.
func (a *App) refreshLauncher(exe string, rt installedRuntime) error {
	return update.RefreshLauncher(exe, os.Getenv("NEOAGENT_BIN_DIR"), release.BinaryName(Platform()), rt.binary())
}

// healLauncher replaces a `neoagent` command left behind by releases that
// updated the runtime without it, which then reinstalled on every update.
func (a *App) healLauncher(ctx context.Context) {
	rt := a.currentRuntime()
	if rt == nil {
		return
	}
	source, err := filepath.EvalSymlinks(rt.binary())
	if err != nil || source != a.Exe {
		return
	}
	if _, err := update.HealLauncher(ctx, a.Getenv("NEOAGENT_BIN_DIR"), release.BinaryName(Platform()), source, rt.Version); err != nil {
		a.UI.Warn("The command-line launcher could not be refreshed: " + err.Error())
	}
}

func (a *App) versionsDir() string { return filepath.Join(a.Paths.Home, "app", "versions") }

func (a *App) currentMarker() string { return filepath.Join(a.Paths.Home, "app", "current.json") }

// runtimeStore is shared with the other NeoLabs applications.
func (a *App) runtimeStore() nlrelease.RuntimeStore {
	return nlrelease.RuntimeStore{
		Root: filepath.Join(a.Paths.Home, "app"), SchemaVersion: setupcontract.C.SchemaVersion,
		RequiredFiles: []string{filepath.Join("app", "bin", release.BinaryName(Platform())), filepath.Join("app", "public", "index.html")},
	}
}

func (a *App) currentRuntime() *installedRuntime {
	marker, err := a.runtimeStore().Current()
	if err != nil {
		return nil
	}
	return &installedRuntime{Version: marker.Version, Dir: filepath.Join(a.versionsDir(), marker.Version)}
}

func (a *App) writeCurrent(version string) error { return a.runtimeStore().Activate(version) }

func (a *App) releaseClient() *nlrelease.Client {
	c := &nlrelease.Client{UserAgent: "NeoAgent CLI " + version()}
	if a.releaseAPI != "" {
		c.APIBase, c.AllowHTTP = a.releaseAPI, true
	}
	return c
}

// signingKey is NEOAGENT_RUNTIME_PUBLIC_KEY or the embedded key.
func signingKey() (string, error) {
	if k := strings.TrimSpace(os.Getenv("NEOAGENT_RUNTIME_PUBLIC_KEY")); k != "" {
		return nlrelease.NormalizePublicKey(k)
	}
	return setupcontract.PublicKey(), nil
}

// availableRuntime is the newest verified runtime of the channel for this
// computer.
type availableRuntime = update.Candidate

// runtimeSource is where NeoAgent's signed runtimes are published.
func (a *App) runtimeSource() (update.Source, error) {
	key, err := signingKey()
	if err != nil {
		return update.Source{}, cli.Errorf("SETUP_TRUST_NOT_CONFIGURED", "The runtime verification key is invalid.")
	}
	return update.Source{
		Client: a.releaseClient(), Repository: release.Repository, ManifestPrefix: release.RuntimeManifestPrefix,
		PublicKey: key, SchemaVersion: setupcontract.C.SchemaVersion, Targets: setupcontract.C.RuntimeTargets,
		Platform: Platform(), Architecture: Architecture(),
	}, nil
}

func (a *App) findRuntime(ctx context.Context, channel string) (availableRuntime, error) {
	source, err := a.runtimeSource()
	if err != nil {
		return availableRuntime{}, err
	}
	return source.Find(ctx, channel)
}

// unpackRuntime downloads, verifies and unpacks a runtime package into
// versions/<version> without activating it.
func (a *App) unpackRuntime(ctx context.Context, rt availableRuntime, force bool) (installedRuntime, error) {
	target := installedRuntime{Version: rt.Version, Dir: filepath.Join(a.versionsDir(), rt.Version)}
	if exists(target.binary()) && !force {
		return target, nil
	}
	archive, err := a.downloadRuntime(ctx, rt)
	if err != nil {
		return target, err
	}
	return a.installRuntime(ctx, rt, archive, force)
}

// downloadRuntime downloads and verifies rt's package into a staging folder
// under the versions folder and returns the archive's path.
func (a *App) downloadRuntime(ctx context.Context, rt availableRuntime) (string, error) {
	source := update.Source{Client: a.releaseClient()}
	return source.Download(ctx, a.runtimeStore(), rt)
}

// installRuntime unpacks a downloaded package into its versions folder and
// removes the staging folder.
func (a *App) installRuntime(_ context.Context, rt availableRuntime, archive string, force bool) (installedRuntime, error) {
	target := installedRuntime{Version: rt.Version, Dir: filepath.Join(a.versionsDir(), rt.Version)}
	return target, update.Unpack(a.runtimeStore(), rt.Version, archive, force)
}

// pruneRuntimes keeps the active runtime and the previous rollback target.
// Unknown entries and staging directories are not managed here.
func (a *App) pruneRuntimes(active installedRuntime, previous *installedRuntime) error {
	old := ""
	if previous != nil {
		old = previous.Version
	}
	return a.runtimeStore().Prune(active.Version, old)
}

func (a *App) channel() string {
	return nlrelease.NormalizeChannel(orDefault(os.Getenv("NEOAGENT_RELEASE_CHANNEL"), a.env()["NEOAGENT_RELEASE_CHANNEL"]))
}

// delegate runs the packaged binary with args, sharing this terminal.
func (a *App) delegate(ctx context.Context, rt installedRuntime, args []string) error {
	cmd := a.command(ctx, rt, args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return eventEmitted{fmt.Errorf("%s %s: %w", filepath.Base(rt.binary()), strings.Join(args, " "), err)}
	}
	return nil
}

// bootstrapInstall installs the newest signed runtime package and runs its
// own `install --runtime-package` with the same flags.
func (a *App) bootstrapInstall(ctx context.Context, args []string, o SetupOptions) error {
	profile := o.Profile
	if profile == "" && !o.Resume {
		var err error
		if profile, err = a.resolveProfile(o); err != nil {
			return err
		}
	}
	profile = normalizeProfile(profile)
	a.Events.Profile = profile
	a.Events.Start("download", "Downloading the verified NeoAgent runtime", 0.05)
	rt, err := a.findRuntime(ctx, a.channel())
	if err == nil {
		var installed installedRuntime
		if installed, err = a.unpackRuntime(ctx, rt, false); err == nil {
			if err = a.writeCurrent(installed.Version); err == nil {
				a.Events.Complete("download", "Verified NeoAgent runtime installed", 0.25)
				next := append([]string{"install"}, args...)
				if o.Profile == "" && !o.Resume {
					next = append(next, "--"+profile)
				}
				return a.delegate(ctx, installed, append(next, "--runtime-package"))
			}
		}
	}
	a.Events.Fail(err, cli.CodeOf(err, "") != "SETUP_PLATFORM_UNSUPPORTED", "retry")
	return eventEmitted{err}
}
