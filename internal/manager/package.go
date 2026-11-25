package manager

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/release"
	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	nlrelease "github.com/NeoLabs-Systems/neolabs-go/cli/release"
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

// refreshLauncher updates the standalone command installed by install.sh. The
// packaged server binary and other installation methods are left untouched.
func (a *App) refreshLauncher(exe string, rt installedRuntime) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	binDir := strings.TrimSpace(os.Getenv("NEOAGENT_BIN_DIR"))
	if binDir == "" {
		binDir = filepath.Join(home, ".local", "bin")
	}
	launcher, err := filepath.Abs(filepath.Join(binDir, "neoagent"))
	if err != nil || filepath.Clean(exe) != launcher {
		return err
	}
	src, err := os.Open(rt.binary())
	if err != nil {
		return err
	}
	defer src.Close()
	tmp, err := os.CreateTemp(binDir, ".neoagent-update-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	_, copyErr := io.Copy(tmp, src)
	if copyErr == nil {
		copyErr = tmp.Chmod(0o755)
	}
	if err := tmp.Close(); copyErr == nil {
		copyErr = err
	}
	if copyErr != nil {
		return copyErr
	}
	return os.Rename(tmp.Name(), launcher)
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
type availableRuntime struct {
	Release  nlrelease.Release
	Version  string
	Artifact nlrelease.Artifact
}

func (a *App) findRuntime(ctx context.Context, channel string) (availableRuntime, error) {
	client := a.releaseClient()
	rel, err := client.ResolveRelease(ctx, release.Repository, channel, release.RuntimeManifestPrefix)
	if err != nil {
		return availableRuntime{}, err
	}
	key, err := signingKey()
	if err != nil {
		return availableRuntime{}, cli.Errorf("SETUP_TRUST_NOT_CONFIGURED", "The runtime verification key is invalid.")
	}
	raw, err := client.FetchVerifiedManifest(ctx, rel, key)
	if err != nil {
		return availableRuntime{}, err
	}
	var m nlrelease.RuntimeManifest
	if json.Unmarshal(raw, &m) != nil || m.SchemaVersion != setupcontract.C.SchemaVersion {
		return availableRuntime{}, cli.Errorf("SETUP_MANIFEST_INVALID", "The runtime manifest is invalid.")
	}
	v, err := nlrelease.NormalizeVersion(m.Version)
	if err != nil {
		return availableRuntime{}, cli.Errorf("SETUP_MANIFEST_INVALID", "The runtime manifest is invalid.")
	}
	for _, art := range m.Artifacts {
		if art.Platform != Platform() || art.Architecture != Architecture() {
			continue
		}
		n, err := nlrelease.NormalizeArtifact(art, setupcontract.C.RuntimeTargets)
		if err != nil {
			return availableRuntime{}, cli.Errorf("SETUP_MANIFEST_INVALID", "%s", err)
		}
		if rel.Assets[n.AssetName] == "" {
			return availableRuntime{}, cli.Errorf("SETUP_RUNTIME_ASSET_MISSING", "The selected runtime asset is missing.")
		}
		return availableRuntime{Release: rel, Version: v, Artifact: n}, nil
	}
	return availableRuntime{}, cli.Errorf("SETUP_PLATFORM_UNSUPPORTED", "No NeoAgent runtime is available for this computer.")
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
	if err := os.MkdirAll(a.versionsDir(), 0o700); err != nil {
		return "", err
	}
	staging, err := os.MkdirTemp(a.versionsDir(), ".staging-")
	if err != nil {
		return "", err
	}
	archive := filepath.Join(staging, rt.Artifact.AssetName)
	if err := a.releaseClient().Download(ctx, rt.Release.Assets[rt.Artifact.AssetName], archive, rt.Artifact.SizeBytes, rt.Artifact.SHA256); err != nil {
		os.RemoveAll(staging)
		return "", err
	}
	return archive, nil
}

// installRuntime unpacks a downloaded package into its versions folder and
// removes the staging folder.
func (a *App) installRuntime(_ context.Context, rt availableRuntime, archive string, force bool) (installedRuntime, error) {
	staging := filepath.Dir(archive)
	defer os.RemoveAll(staging)
	target := installedRuntime{Version: rt.Version, Dir: filepath.Join(a.versionsDir(), rt.Version)}
	if exists(target.binary()) && !force {
		return target, nil
	}
	if err := a.runtimeStore().InstallArchive(rt.Version, archive); err != nil {
		return target, err
	}
	return target, nil
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
