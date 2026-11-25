package release

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

// StageQemu copies the host's QEMU (system emulator for the host
// architecture, qemu-img, their shared libraries and firmware) into output as
// a portable runtime with a manifest. On Linux libraries are rewired with
// patchelf, on macOS with install_name_tool and re-signed (the emulator keeps
// the hypervisor entitlement), on Windows the DLLs next to QEMU are copied.
func StageQemu(ctx context.Context, output string) error {
	arch := runtime.GOARCH
	system, err := resolveCommand(vm.SystemBinaryName(arch))
	if err != nil {
		return err
	}
	img, err := resolveCommand("qemu-img")
	if err != nil {
		return err
	}
	data := findQemuDataDirectory(system)
	if data == "" {
		return fmt.Errorf("QEMU firmware/data directory was not found. Searched: %s", strings.Join(qemuDataCandidates(system), ", "))
	}
	if err := os.RemoveAll(output); err != nil {
		return err
	}
	bin := filepath.Join(output, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		return err
	}
	c := &copier{seen: map[string]string{}}
	var staged []string
	if runtime.GOOS == "windows" {
		entries, err := os.ReadDir(filepath.Dir(system))
		if err != nil {
			return err
		}
		for _, e := range entries {
			lower := strings.ToLower(e.Name())
			if e.Type().IsRegular() && (strings.HasSuffix(lower, ".dll") || lower == strings.ToLower(filepath.Base(system)) || lower == strings.ToLower(filepath.Base(img))) {
				if err := copyFile(filepath.Join(filepath.Dir(system), e.Name()), filepath.Join(bin, e.Name()), 0o755); err != nil {
					return err
				}
			}
		}
		staged = []string{filepath.Join(bin, filepath.Base(system)), filepath.Join(bin, filepath.Base(img))}
	} else {
		for _, b := range []string{system, img} {
			dst, err := c.copy(b, bin)
			if err != nil {
				return err
			}
			staged = append(staged, dst)
		}
		if runtime.GOOS == "darwin" {
			err = c.macDependencies(ctx, staged, output)
		} else {
			err = c.linuxDependencies(staged, output)
		}
		if err != nil {
			return err
		}
	}
	if err := copyTree(data, filepath.Join(output, "share", "qemu")); err != nil {
		return err
	}
	versionOut, err := output1(system, "--version")
	if err != nil {
		return err
	}
	manifest := map[string]any{
		"schemaVersion": 1,
		"platform":      nodePlatform(runtime.GOOS),
		"architecture":  nodeArch(arch),
		"version":       strings.SplitN(versionOut, "\n", 2)[0],
	}
	var files []map[string]string
	for _, f := range staged {
		sum, err := hashFile(f)
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(output, f)
		files = append(files, map[string]string{"path": filepath.ToSlash(rel), "sha256": sum})
	}
	manifest["files"] = files
	raw, err := json.MarshalIndent(orderedManifest(manifest), "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(output, "manifest.json"), append(raw, '\n'), 0o644)
}

// orderedManifest keeps the key order of the Node manifest.
func orderedManifest(m map[string]any) any {
	return struct {
		SchemaVersion any `json:"schemaVersion"`
		Platform      any `json:"platform"`
		Architecture  any `json:"architecture"`
		Version       any `json:"version"`
		Files         any `json:"files"`
	}{m["schemaVersion"], m["platform"], m["architecture"], m["version"], m["files"]}
}

func nodePlatform(goos string) string {
	if goos == "windows" {
		return "win32"
	}
	return goos
}

func nodeArch(goarch string) string {
	if goarch == "amd64" {
		return "x64"
	}
	return goarch
}

func output1(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	if err != nil {
		var stderr string
		if ee, ok := err.(*exec.ExitError); ok {
			stderr = string(ee.Stderr)
		}
		return "", fmt.Errorf("%s %s: %w %s", name, strings.Join(args, " "), err, strings.TrimSpace(stderr))
	}
	return strings.TrimSpace(string(out)), nil
}

func resolveCommand(name string) (string, error) {
	p, err := exec.LookPath(name)
	if err != nil {
		return "", fmt.Errorf("%s was not found on PATH", name)
	}
	return filepath.EvalSymlinks(p)
}

func hashFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:]), nil
}

var qemuDataMarkers = []string{"bios.bin", "bios-256k.bin", "edk2-x86_64-code.fd", "edk2-i386-code.fd", "edk2-aarch64-code.fd", "kvmvapic.bin"}

func isQemuDataDirectory(dir string) bool {
	info, err := os.Stat(dir)
	if err != nil || !info.IsDir() {
		return false
	}
	for _, m := range qemuDataMarkers {
		if _, err := os.Stat(filepath.Join(dir, m)); err == nil {
			return true
		}
	}
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		switch strings.ToLower(filepath.Ext(e.Name())) {
		case ".bin", ".fd", ".rom":
			return true
		}
	}
	return false
}

func qemuDataCandidates(system string) []string {
	binDir := filepath.Dir(system)
	prefix := filepath.Dir(binDir)
	return []string{
		filepath.Join(binDir, "share", "qemu"), filepath.Join(binDir, "share"), filepath.Join(prefix, "share", "qemu"),
		"/usr/share/qemu", "/usr/local/share/qemu", "/opt/homebrew/share/qemu",
	}
}

func findQemuDataDirectory(system string) string {
	for _, c := range qemuDataCandidates(system) {
		if isQemuDataDirectory(c) {
			return c
		}
	}
	return ""
}

// copier copies binaries and libraries into one directory, refusing two
// different files with the same name.
type copier struct{ seen map[string]string }

func (c *copier) copy(src, dir string) (string, error) {
	real, err := filepath.EvalSymlinks(src)
	if err != nil {
		return "", err
	}
	dst := filepath.Join(dir, filepath.Base(real))
	if prev, ok := c.seen[dst]; ok {
		if prev != real {
			a, _ := hashFile(prev)
			b, _ := hashFile(real)
			if a != b {
				return "", fmt.Errorf("Portable QEMU dependency name collision: %s", filepath.Base(real))
			}
		}
		return dst, nil
	}
	c.seen[dst] = real
	if _, err := os.Stat(dst); err == nil {
		return dst, nil
	}
	return dst, copyFile(real, dst, 0o755)
}

var lddLine = regexp.MustCompile(`=>\s+(/\S+)|^\s*(/\S+)`)
var systemLib = regexp.MustCompile(`^(?:ld-linux|libc\.so|libm\.so|libpthread\.so|librt\.so|libdl\.so)`)

func (c *copier) linuxDependencies(binaries []string, output string) error {
	lib := filepath.Join(output, "lib")
	if err := os.MkdirAll(lib, 0o755); err != nil {
		return err
	}
	pending := append([]string(nil), binaries...)
	visited := map[string]bool{}
	for len(pending) > 0 {
		b := pending[len(pending)-1]
		pending = pending[:len(pending)-1]
		real, err := filepath.EvalSymlinks(b)
		if err != nil {
			return err
		}
		if visited[real] {
			continue
		}
		visited[real] = true
		out, err := output1("ldd", real)
		if err != nil {
			return err
		}
		for _, line := range strings.Split(out, "\n") {
			m := lddLine.FindStringSubmatch(line)
			if m == nil {
				continue
			}
			dep := m[1] + m[2]
			if systemLib.MatchString(filepath.Base(dep)) {
				continue
			}
			target, err := c.copy(dep, lib)
			if err != nil {
				return err
			}
			if realDep, _ := filepath.EvalSymlinks(dep); !visited[realDep] {
				pending = append(pending, dep)
			}
			if _, err := output1("patchelf", "--set-rpath", "$ORIGIN", target); err != nil {
				return err
			}
		}
	}
	for _, b := range binaries {
		if _, err := output1("patchelf", "--set-rpath", "$ORIGIN/../lib", b); err != nil {
			return err
		}
	}
	return nil
}

func macDependencies(binary string) ([]string, error) {
	out, err := output1("otool", "-L", binary)
	if err != nil {
		return nil, err
	}
	var deps []string
	for _, line := range strings.Split(out, "\n")[1:] {
		dep := strings.SplitN(strings.TrimSpace(line), " (", 2)[0]
		if strings.HasPrefix(dep, "/") && !strings.HasPrefix(dep, "/usr/lib/") && !strings.HasPrefix(dep, "/System/") {
			deps = append(deps, dep)
		}
	}
	return deps, nil
}

func (c *copier) macDependencies(ctx context.Context, binaries []string, output string) error {
	lib := filepath.Join(output, "lib")
	if err := os.MkdirAll(lib, 0o755); err != nil {
		return err
	}
	mapped := map[string]string{}
	pending := append([]string(nil), binaries...)
	visited := map[string]bool{}
	for len(pending) > 0 {
		b := pending[len(pending)-1]
		pending = pending[:len(pending)-1]
		real, err := filepath.EvalSymlinks(b)
		if err != nil {
			return err
		}
		if visited[real] {
			continue
		}
		visited[real] = true
		deps, err := macDependencies(real)
		if err != nil {
			return err
		}
		for _, dep := range deps {
			realDep, err := filepath.EvalSymlinks(dep)
			if err != nil {
				return err
			}
			target, err := c.copy(realDep, lib)
			if err != nil {
				return err
			}
			mapped[dep] = target
			pending = append(pending, realDep)
		}
	}
	targets := append([]string(nil), binaries...)
	unique := map[string]bool{}
	for _, t := range mapped {
		if !unique[t] {
			unique[t] = true
			targets = append(targets, t)
		}
	}
	for _, t := range targets {
		inLib := filepath.Dir(t) == lib
		deps, err := macDependencies(t)
		if err != nil {
			return err
		}
		for _, dep := range deps {
			repl, ok := mapped[dep]
			if !ok {
				continue
			}
			prefix := "@loader_path/../lib/"
			if inLib {
				prefix = "@loader_path/"
			}
			if _, err := output1("install_name_tool", "-change", dep, prefix+filepath.Base(repl), t); err != nil {
				return err
			}
		}
		if inLib {
			if _, err := output1("install_name_tool", "-id", "@loader_path/"+filepath.Base(t), t); err != nil {
				return err
			}
		}
		// install_name_tool invalidates the signature; the emulator must keep
		// com.apple.security.hypervisor or HVF cannot create the VM.
		if err := vm.SignBinary(ctx, t, strings.HasPrefix(filepath.Base(t), "qemu-system-")); err != nil {
			return err
		}
	}
	return nil
}

// copyTree copies a directory, following symbolic links so the result is
// self-contained.
func copyTree(src, dst string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		target := filepath.Join(dst, rel)
		if info.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		if info.Mode()&os.ModeSymlink != 0 {
			resolved, err := os.Stat(path)
			if err != nil {
				return nil // dangling link: nothing to ship
			}
			if resolved.IsDir() {
				return copyTree(path+string(filepath.Separator), target)
			}
		}
		return copyFile(path, target, 0o644)
	})
}
