package runtime

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

func stagedQemuRuntimeDirectory(runtimeHome string) string {
	return filepath.Join(runtimeHome, "computer-runtime", "qemu")
}

// readActivatedRuntimeVersion reads app/current.json of the runtime home.
func readActivatedRuntimeVersion(runtimeHome string) string {
	raw, err := os.ReadFile(filepath.Join(runtimeHome, "app", "current.json"))
	if err != nil {
		return ""
	}
	var current struct {
		Version any `json:"version"`
	}
	if json.Unmarshal(raw, &current) != nil {
		return ""
	}
	version := ""
	switch v := current.Version.(type) {
	case string:
		version = strings.TrimSpace(v)
	case nil:
	default:
		version = strings.TrimSpace(fmt.Sprint(v))
	}
	if version == "" || strings.Contains(version, "..") || strings.ContainsAny(version, `/\`) {
		return ""
	}
	return version
}

// PackagedQemuRuntimeDirectory is where the activated app version ships its
// QEMU runtime, or "" when no version is activated.
func PackagedQemuRuntimeDirectory(runtimeHome string) string {
	version := readActivatedRuntimeVersion(runtimeHome)
	if version == "" {
		return ""
	}
	return filepath.Join(runtimeHome, "app", "versions", version, "app", "computer-runtime", "qemu")
}

func packagedQemuExecutableCandidates(runtimeHome, name string) []string {
	if dir := PackagedQemuRuntimeDirectory(runtimeHome); dir != "" {
		return []string{filepath.Join(dir, "bin", vm.ExecutableName(name))}
	}
	return nil
}

// IsCompleteQemuRuntime reports whether directory holds the system emulator
// for the architecture and qemu-img.
func IsCompleteQemuRuntime(directory, architecture string) bool {
	if directory == "" {
		return false
	}
	for _, name := range []string{vm.SystemBinaryName(architecture), "qemu-img"} {
		if !vm.IsRunnableFile(filepath.Join(directory, "bin", vm.ExecutableName(name))) {
			return false
		}
	}
	return true
}

// QemuInstallPath is PATH extended with where package managers put QEMU.
func QemuInstallPath(envPath string) string {
	var extras []string
	if runtime.GOOS == "windows" {
		programFiles := os.Getenv("ProgramFiles")
		if programFiles == "" {
			programFiles = `C:\Program Files`
		}
		extras = []string{filepath.Join(programFiles, "qemu")}
	} else {
		extras = []string{"/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin"}
	}
	parts := append(extras, envPath)
	var kept []string
	for _, p := range parts {
		if p != "" {
			kept = append(kept, p)
		}
	}
	return strings.Join(kept, string(os.PathListSeparator))
}

// QemuInstallPlan is the package-manager command that installs QEMU.
type QemuInstallPlan struct {
	Command        string
	Args           []string
	MissingCommand string
}

// HostQemuInstallPlan chooses the install command for platform ("macos",
// "linux", "windows"), or nil when QEMU cannot be installed automatically.
func HostQemuInstallPlan(platform, architecture string, root bool) *QemuInstallPlan {
	switch platform {
	case "macos":
		return &QemuInstallPlan{"brew", []string{"install", "qemu"},
			"Homebrew is required to install the QEMU computer runtime. Install Homebrew, then run `neoagent repair`."}
	case "linux":
		systemPackage := "qemu-system-x86"
		if architecture == "arm64" {
			systemPackage = "qemu-system-arm"
		}
		packages := []string{systemPackage, "qemu-utils", "ovmf"}
		install := append([]string{"install", "-y", "--no-install-recommends"}, packages...)
		plan := &QemuInstallPlan{MissingCommand: "apt-get is required to install the QEMU computer runtime. Install QEMU with your package manager, then run `neoagent repair`."}
		if root {
			plan.Command, plan.Args = "apt-get", install
		} else {
			plan.Command, plan.Args = "sudo", append([]string{"apt-get"}, install...)
		}
		return plan
	case "windows":
		return &QemuInstallPlan{"choco", []string{"install", "qemu", "--yes", "--no-progress"},
			"Chocolatey is required to install the QEMU computer runtime. Install QEMU, then run `neoagent repair`."}
	}
	return nil
}

// QemuRestore performs the steps of restoring the QEMU computer runtime; the
// CLI supplies them so it controls how commands run and what is printed.
type QemuRestore struct {
	Architecture     string
	RuntimeHome      string
	AllowHostInstall bool
	Platform         string
	Root             bool
	CommandExists    func(string) bool
	// RunOrThrow runs a command with an environment whose PATH is extended.
	RunOrThrow func(command string, args []string, path string) error
	// Stage copies a host QEMU installation into destination as a portable
	// runtime (bin/, lib/, share/qemu/).
	Stage   func(destination string) error
	LogInfo func(string)
}

// RestoreResult says what restoring did.
type RestoreResult struct {
	Action    string
	Directory string
	Source    string
}

// RestoreQemuComputerRuntime makes sure a complete, signed QEMU runtime is
// staged in the runtime home: keep it, copy the packaged one, or install QEMU
// on the host and stage that.
func RestoreQemuComputerRuntime(ctx context.Context, r QemuRestore) (RestoreResult, error) {
	architecture := r.Architecture
	if architecture == "" {
		architecture = hostArchitecture()
	}
	destination := stagedQemuRuntimeDirectory(r.RuntimeHome)
	if IsCompleteQemuRuntime(destination, architecture) {
		if ensureStagedMacSignature(ctx, destination, architecture) {
			return RestoreResult{Action: "signed", Directory: destination}, nil
		}
		return RestoreResult{Action: "kept", Directory: destination}, nil
	}
	if packaged := PackagedQemuRuntimeDirectory(r.RuntimeHome); IsCompleteQemuRuntime(packaged, architecture) {
		if err := copyQemuRuntime(packaged, destination); err != nil {
			return RestoreResult{}, err
		}
		ensureStagedMacSignature(ctx, destination, architecture)
		return RestoreResult{Action: "copied", Directory: destination, Source: packaged}, nil
	}
	if !r.AllowHostInstall {
		return RestoreResult{Action: "missing", Directory: destination}, nil
	}
	if err := r.installHostQemu(architecture); err != nil {
		return RestoreResult{}, err
	}
	if r.Stage == nil {
		return RestoreResult{}, errors.New("Staging the host QEMU runtime is not available.")
	}
	if err := r.Stage(destination); err != nil {
		return RestoreResult{}, err
	}
	if !IsCompleteQemuRuntime(destination, architecture) {
		return RestoreResult{}, errors.New("QEMU was installed but the computer runtime is still incomplete.")
	}
	ensureStagedMacSignature(ctx, destination, architecture)
	return RestoreResult{Action: "staged", Directory: destination}, nil
}

func (r QemuRestore) installHostQemu(architecture string) error {
	plan := HostQemuInstallPlan(r.Platform, architecture, r.Root)
	if plan == nil {
		return errors.New("This platform cannot install the QEMU computer runtime automatically.")
	}
	if r.CommandExists != nil && !r.CommandExists(plan.Command) {
		return errors.New(plan.MissingCommand)
	}
	if plan.Command == "sudo" && r.CommandExists != nil && !r.CommandExists("apt-get") {
		return errors.New(plan.MissingCommand)
	}
	if r.LogInfo != nil {
		r.LogInfo(fmt.Sprintf("Installing QEMU with %s %s…", plan.Command, strings.Join(plan.Args, " ")))
	}
	return r.RunOrThrow(plan.Command, plan.Args, QemuInstallPath(os.Getenv("PATH")))
}

func copyQemuRuntime(source, destination string) error {
	src, _ := filepath.Abs(source)
	dst, _ := filepath.Abs(destination)
	if src == dst {
		return nil
	}
	if err := os.RemoveAll(dst); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o700); err != nil {
		return err
	}
	return os.CopyFS(dst, os.DirFS(src))
}

func ensureStagedMacSignature(ctx context.Context, directory, architecture string) bool {
	return vm.EnsureHypervisorSignature(ctx, filepath.Join(directory, "bin", vm.ExecutableName(vm.SystemBinaryName(architecture))))
}
