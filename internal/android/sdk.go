package android

import (
	"archive/zip"
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/adbx"
)

// Google publishes the current filenames and checksums at
// https://developer.android.com/studio#command-line-tools-only
const commandLineToolsVersion = "15859902"

type toolsRelease struct{ url, sha256 string }

func commandLineToolsRelease(goos, goarch string) (toolsRelease, error) {
	base := "https://dl.google.com/android/repository/commandlinetools-"
	switch goos {
	case "darwin":
		switch goarch {
		case "arm64":
			return toolsRelease{base + "mac_arm64-" + commandLineToolsVersion + "_latest.zip",
				"835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e"}, nil
		case "amd64":
			return toolsRelease{base + "mac_x86_64-" + commandLineToolsVersion + "_latest.zip",
				"c5a6378ab5cf7e0d5701921405115befff13e9ff7417fb588389338f8bd050f3"}, nil
		}
		return toolsRelease{}, fmt.Errorf("No Android command-line-tools download for macOS architecture: %s", goarch)
	case "linux":
		return toolsRelease{base + "linux-" + commandLineToolsVersion + "_latest.zip",
			"4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"}, nil
	case "windows":
		return toolsRelease{base + "win-" + commandLineToolsVersion + "_latest.zip",
			"90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a"}, nil
	}
	return toolsRelease{}, fmt.Errorf("No Android command-line-tools download for platform: %s", goos)
}

func exe(name, windowsSuffix string) string {
	if runtime.GOOS == "windows" {
		return name + windowsSuffix
	}
	return name
}

func sdkManagerBin(sdk string) string {
	return filepath.Join(sdk, "cmdline-tools", "latest", "bin", exe("sdkmanager", ".bat"))
}
func avdManagerBin(sdk string) string {
	return filepath.Join(sdk, "cmdline-tools", "latest", "bin", exe("avdmanager", ".bat"))
}
func emulatorBin(sdk string) string { return filepath.Join(sdk, "emulator", exe("emulator", ".exe")) }

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

// findExistingSdk returns the first Android SDK that has an emulator.
func findExistingSdk(runtimeHome string) string {
	home, _ := os.UserHomeDir()
	candidates := []string{
		os.Getenv("ANDROID_HOME"), os.Getenv("ANDROID_SDK_ROOT"),
		filepath.Join(home, "Library", "Android", "sdk"),
		filepath.Join(home, "Android", "Sdk"),
		filepath.Join(home, ".android", "sdk"),
		filepath.Join(runtimeHome, "android-sdk"),
	}
	for _, dir := range candidates {
		if dir != "" && fileExists(emulatorBin(dir)) {
			return dir
		}
	}
	return ""
}

type systemImage struct{ api, tag, abi string }

func (i systemImage) key() string { return "system-images;" + i.api + ";" + i.tag + ";" + i.abi }

func hostIsARM() bool { return runtime.GOARCH == "arm64" || runtime.GOARCH == "arm" }

func subdirs(dir string) []string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var names []string
	for _, e := range entries {
		if info, err := os.Stat(filepath.Join(dir, e.Name())); err == nil && info.IsDir() {
			names = append(names, e.Name())
		}
	}
	return names
}

// pickSystemImage chooses the best installed system image for this CPU, or "".
func pickSystemImage(sdk string) string {
	root := filepath.Join(sdk, "system-images")
	var images []systemImage
	for _, api := range subdirs(root) {
		for _, tag := range subdirs(filepath.Join(root, api)) {
			entries, _ := os.ReadDir(filepath.Join(root, api, tag))
			for _, abi := range entries {
				images = append(images, systemImage{api, tag, abi.Name()})
			}
		}
	}
	preferred, fallback := "x86_64", "arm64-v8a"
	if hostIsARM() {
		preferred, fallback = "arm64-v8a", "x86_64"
	}
	score := func(i systemImage) int {
		s := 0
		switch i.abi {
		case preferred:
			s += 100
		case fallback:
			s += 10
		}
		switch i.tag {
		case "google_apis":
			s += 5
		case "google_apis_playstore":
			s += 3
		}
		n, _ := strconv.Atoi(leadingDigits(strings.TrimPrefix(i.api, "android-")))
		return s + n
	}
	sort.SliceStable(images, func(a, b int) bool { return score(images[a]) > score(images[b]) })
	if len(images) == 0 {
		return ""
	}
	return images[0].key()
}

// leadingDigits mimics parseInt: the numeric prefix, "" when there is none.
func leadingDigits(s string) string {
	i := 0
	for i < len(s) && s[i] >= '0' && s[i] <= '9' {
		i++
	}
	return s[:i]
}

func defaultSystemImage() string {
	abi := "x86_64"
	if hostIsARM() {
		abi = "arm64-v8a"
	}
	return "system-images;android-36;google_apis;" + abi
}

// downloadFile fetches an HTTPS URL to destination, verifying the SHA-256 and
// the size cap while streaming. The file appears only when it verified.
func downloadFile(ctx context.Context, base *http.Client, rawURL, destination, expectedSHA256 string) error {
	const (
		maxRedirects = 5
		maxBytes     = 500 << 20
		timeout      = 10 * time.Minute
	)
	want, err := hex.DecodeString(strings.ToLower(strings.TrimSpace(expectedSHA256)))
	if err != nil || len(want) != sha256.Size {
		return errors.New("Android SDK download is missing a valid SHA-256 checksum.")
	}
	client := *base
	client.Timeout = timeout
	client.CheckRedirect = func(req *http.Request, via []*http.Request) error {
		if len(via) > maxRedirects {
			return errors.New("Android SDK download exceeded its redirect limit.")
		}
		return requireHTTPS(req.URL)
	}
	u, err := url.Parse(rawURL)
	if err != nil {
		return err
	}
	if err := requireHTTPS(u); err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("Android SDK download failed with HTTP %d.", resp.StatusCode)
	}
	if resp.ContentLength > maxBytes {
		return fmt.Errorf("Android SDK download exceeds the %d-byte limit.", maxBytes)
	}
	tmp, err := os.CreateTemp(filepath.Dir(destination), filepath.Base(destination)+".*.part")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	h := sha256.New()
	n, err := io.Copy(io.MultiWriter(tmp, h), io.LimitReader(resp.Body, maxBytes+1))
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return err
	}
	if n > maxBytes {
		return fmt.Errorf("Android SDK download exceeds the %d-byte limit.", maxBytes)
	}
	if subtle.ConstantTimeCompare(h.Sum(nil), want) != 1 {
		return errors.New("Android SDK download failed SHA-256 verification.")
	}
	return os.Rename(tmp.Name(), destination)
}

func requireHTTPS(u *url.URL) error {
	if u.Scheme != "https" {
		return fmt.Errorf("Refusing non-HTTPS Android SDK download: %s:", u.Scheme)
	}
	return nil
}

// unzip extracts an archive into dir, refusing entries that escape it, and
// keeps the unix permission bits (the SDK tools are executable scripts).
func unzip(archive, dir string) error {
	r, err := zip.OpenReader(archive)
	if err != nil {
		return err
	}
	defer r.Close()
	root, err := os.OpenRoot(dir)
	if err != nil {
		return err
	}
	defer root.Close()
	for _, f := range r.File {
		name := filepath.FromSlash(strings.TrimPrefix(f.Name, "/"))
		if f.FileInfo().IsDir() {
			if err := root.MkdirAll(name, 0o755); err != nil {
				return err
			}
			continue
		}
		if err := root.MkdirAll(filepath.Dir(name), 0o755); err != nil {
			return err
		}
		if err := extractEntry(root, f, name); err != nil {
			return err
		}
	}
	return nil
}

func extractEntry(root *os.Root, f *zip.File, name string) error {
	src, err := f.Open()
	if err != nil {
		return err
	}
	defer src.Close()
	mode := f.Mode().Perm()
	if mode == 0 {
		mode = 0o644
	}
	if f.Mode()&os.ModeSymlink != 0 {
		target, err := io.ReadAll(io.LimitReader(src, 4096))
		if err != nil {
			return err
		}
		_ = root.Remove(name)
		return root.Symlink(string(target), name)
	}
	dst, err := root.OpenFile(name, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	if _, err := io.Copy(dst, src); err != nil {
		dst.Close()
		return err
	}
	return dst.Close()
}

var errNoUniversalAPK = errors.New("The .apks bundle does not contain universal.apk. Export it with bundletool --mode=universal.")

func (c *Controller) sdkEnv() []string {
	return append(os.Environ(), "ANDROID_SDK_ROOT="+c.sdkDir, "ANDROID_HOME="+c.sdkDir)
}

// ensureSdk downloads the command-line tools when the SDK has none.
func (c *Controller) ensureSdk(ctx context.Context, progress func(string)) error {
	if fileExists(sdkManagerBin(c.sdkDir)) {
		return nil
	}
	release, err := commandLineToolsRelease(runtime.GOOS, runtime.GOARCH)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(c.sdkDir, 0o755); err != nil {
		return err
	}
	progress("Downloading Android SDK command-line tools (~182 MB)…")
	dl, err := os.MkdirTemp("", "neoagent-android-sdk-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(dl)
	zipPath := filepath.Join(dl, "cmdline-tools.zip")
	if err := downloadFile(ctx, http.DefaultClient, release.url, zipPath, release.sha256); err != nil {
		return err
	}
	progress("Extracting…")
	tools := filepath.Join(c.sdkDir, "cmdline-tools")
	if err := os.MkdirAll(tools, 0o755); err != nil {
		return err
	}
	if err := unzip(zipPath, tools); err != nil {
		return err
	}
	extracted, latest := filepath.Join(tools, "cmdline-tools"), filepath.Join(tools, "latest")
	if fileExists(extracted) && !fileExists(latest) {
		if err := os.Rename(extracted, latest); err != nil {
			return err
		}
	}
	if !fileExists(sdkManagerBin(c.sdkDir)) {
		return errors.New("sdkmanager not found after extraction")
	}
	return nil
}

func (c *Controller) ensurePackages(ctx context.Context, progress func(string)) error {
	sdkman := sdkManagerBin(c.sdkDir)
	progress("Accepting Android SDK licenses…")
	if _, err := adbx.Run(ctx, sdkman, []string{"--licenses", "--sdk_root=" + c.sdkDir}, adbx.RunOptions{
		Stdin: []byte(strings.Repeat("y\n", 20)), Env: c.sdkEnv(), Timeout: 5 * time.Minute, MaxOutputBytes: 8 << 20,
	}); err != nil {
		return err
	}
	packages := []string{"platform-tools", "emulator"}
	if pickSystemImage(c.sdkDir) == "" {
		packages = append(packages, defaultSystemImage())
	}
	progress("Installing " + strings.Join(packages, ", ") + " (first run only)…")
	_, err := adbx.Run(ctx, sdkman, append(packages, "--sdk_root="+c.sdkDir), adbx.RunOptions{
		Env: c.sdkEnv(), Timeout: 20 * time.Minute, MaxOutputBytes: 32 << 20,
	})
	return err
}

func (c *Controller) ensureEmulatorRegistered(ctx context.Context) error {
	if fileExists(filepath.Join(c.sdkDir, "emulator", "package.xml")) || !fileExists(emulatorBin(c.sdkDir)) {
		return nil
	}
	_, err := adbx.Run(ctx, sdkManagerBin(c.sdkDir), []string{"emulator", "--sdk_root=" + c.sdkDir}, adbx.RunOptions{
		Env: c.sdkEnv(), Stdin: []byte(strings.Repeat("y\n", 5)), Timeout: 5 * time.Minute, MaxOutputBytes: 16 << 20,
	})
	return err
}

func (c *Controller) ensureAvd(ctx context.Context, progress func(string)) error {
	avdDir := filepath.Join(c.avdHome, c.avdName+".avd")
	if fileExists(avdDir) {
		return nil
	}
	if err := c.ensureEmulatorRegistered(ctx); err != nil {
		return err
	}
	img := pickSystemImage(c.sdkDir)
	if img == "" {
		img = defaultSystemImage()
	}
	progress(fmt.Sprintf("Creating AVD %q using %s…", c.avdName, img))
	if err := os.MkdirAll(c.avdHome, 0o755); err != nil {
		return err
	}
	env := append(c.sdkEnv(), "ANDROID_AVD_HOME="+c.avdHome)
	if _, err := adbx.Run(ctx, avdManagerBin(c.sdkDir),
		[]string{"create", "avd", "-n", c.avdName, "-k", img, "--device", "pixel", "--force"},
		adbx.RunOptions{Env: env, Stdin: []byte("\n"), Timeout: 2 * time.Minute, MaxOutputBytes: 4 << 20}); err != nil {
		return err
	}
	return patchAvdConfig(filepath.Join(avdDir, "config.ini"))
}

// patchAvdConfig makes the data partition sparse QCOW2 with a small cache.
func patchAvdConfig(path string) error {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	cfg := string(raw)
	cfg = replaceFirstSetting(cfg, `disk\.dataPartition\.size`, fmt.Sprintf("disk.dataPartition.size = %d", 2*1024*1024*1024))
	cfg = replaceFirstSetting(cfg, `disk\.cachePartition\.size`, fmt.Sprintf("disk.cachePartition.size = %d", 32*1024*1024))
	updated := replaceFirstSetting(cfg, `userdata\.useQcow2`, "userdata.useQcow2 = yes")
	if updated == cfg && !strings.Contains(cfg, "userdata.useQcow2") {
		updated += "\nuserdata.useQcow2 = yes\n"
	}
	return os.WriteFile(path, []byte(updated), 0o644)
}

// replaceFirstSetting replaces the first "name = value" line of an INI file.
func replaceFirstSetting(cfg, name, replacement string) string {
	re := regexp.MustCompile(name + `\s*=\s*\S+`)
	done := false
	return re.ReplaceAllStringFunc(cfg, func(m string) string {
		if done {
			return m
		}
		done = true
		return replacement
	})
}
