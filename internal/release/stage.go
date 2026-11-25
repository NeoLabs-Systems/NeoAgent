package release

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

// StageOptions are the inputs of a runtime archive.
type StageOptions struct {
	Output string
	// Binary is the neoagent executable for the target platform.
	Binary string
	// Guests are static Linux guest agents (neoagent-guest-linux-<arch>).
	Guests []string
	// WebDir is the Flutter web build, LandingDir the marketing site.
	WebDir, LandingDir string
	// ComputerRuntime is a portable QEMU runtime (StageQemu output), optional.
	ComputerRuntime string
	// Platform is macos, linux or windows; Architecture x64 or arm64.
	Platform, Architecture string
	License                string
}

// The archive layout, which the desktop app's installer and the CLI's
// updater both rely on:
//
//	app/bin/neoagent[.exe]                 the server and CLI
//	app/bin/neoagent-guest-linux-<arch>    guest agents, next to the binary
//	app/public/                            web client
//	app/landing/                           landing page
//	app/computer-runtime/qemu/             portable QEMU (optional)
//	app/LICENSE

// BinaryName is the executable name on platform.
func BinaryName(platform string) string {
	if platform == "windows" {
		return "neoagent.exe"
	}
	return "neoagent"
}

// StageRuntime assembles a runtime archive directory.
func StageRuntime(o StageOptions) error {
	if err := os.RemoveAll(o.Output); err != nil {
		return err
	}
	app := filepath.Join(o.Output, "app")
	bin := filepath.Join(app, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		return err
	}
	if err := copyFile(o.Binary, filepath.Join(bin, BinaryName(o.Platform)), 0o755); err != nil {
		return fmt.Errorf("runtime binary: %w", err)
	}
	for _, g := range o.Guests {
		if err := copyFile(g, filepath.Join(bin, filepath.Base(g)), 0o755); err != nil {
			return fmt.Errorf("guest agent: %w", err)
		}
	}
	if _, err := os.Stat(filepath.Join(o.WebDir, "index.html")); err != nil {
		return fmt.Errorf("the web client build is missing at %s (build it into public/ first)", o.WebDir)
	}
	if err := os.CopyFS(filepath.Join(app, "public"), os.DirFS(o.WebDir)); err != nil {
		return err
	}
	if o.LandingDir != "" {
		if err := os.CopyFS(filepath.Join(app, "landing"), os.DirFS(o.LandingDir)); err != nil {
			return err
		}
	}
	if o.License != "" {
		if err := copyFile(o.License, filepath.Join(app, "LICENSE"), 0o644); err != nil {
			return err
		}
	}
	if o.ComputerRuntime != "" {
		arch := "amd64"
		if o.Architecture == "arm64" {
			arch = "arm64"
		}
		for _, rel := range []string{
			filepath.Join("bin", exe(o.Platform, vm.SystemBinaryName(arch))),
			filepath.Join("bin", exe(o.Platform, "qemu-img")),
			filepath.Join("share", "qemu"),
			"manifest.json",
		} {
			if _, err := os.Stat(filepath.Join(o.ComputerRuntime, rel)); err != nil {
				return fmt.Errorf("Computer runtime is incomplete: %s", rel)
			}
		}
		if err := os.CopyFS(filepath.Join(app, "computer-runtime", "qemu"), os.DirFS(o.ComputerRuntime)); err != nil {
			return err
		}
	}
	return nil
}

func exe(platform, name string) string {
	if platform == "windows" {
		return name + ".exe"
	}
	return name
}

func copyFile(src, dst string, mode os.FileMode) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(dst, data, mode); err != nil {
		return err
	}
	return os.Chmod(dst, mode)
}
