package android

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/adbx"
)

func TestDownloadFileVerifiesChecksumAndScheme(t *testing.T) {
	payload := bytes.Repeat([]byte("sdk"), 1000)
	sum := sha256.Sum256(payload)
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/redirect":
			http.Redirect(w, r, "http://example.invalid/x", http.StatusFound)
		case "/missing":
			http.NotFound(w, r)
		default:
			_, _ = w.Write(payload)
		}
	}))
	defer srv.Close()
	dest := filepath.Join(t.TempDir(), "tools.zip")
	ctx := context.Background()

	if err := downloadFile(ctx, srv.Client(), srv.URL+"/ok", dest, hex.EncodeToString(sum[:])); err != nil {
		t.Fatal(err)
	}
	if got, _ := os.ReadFile(dest); !bytes.Equal(got, payload) {
		t.Fatal("downloaded bytes differ")
	}
	os.Remove(dest)

	cases := []struct{ path, sha, want string }{
		{"/ok", strings.Repeat("0", 64), "Android SDK download failed SHA-256 verification."},
		{"/ok", "short", "Android SDK download is missing a valid SHA-256 checksum."},
		{"/missing", hex.EncodeToString(sum[:]), "Android SDK download failed with HTTP 404."},
		{"/redirect", hex.EncodeToString(sum[:]), "Refusing non-HTTPS Android SDK download: http:"},
	}
	for _, c := range cases {
		err := downloadFile(ctx, srv.Client(), srv.URL+c.path, dest, c.sha)
		if err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: err = %v, want %q", c.path, err, c.want)
		}
		if _, statErr := os.Stat(dest); statErr == nil {
			t.Errorf("%s: a failed download left a file", c.path)
		}
	}
	if err := downloadFile(ctx, srv.Client(), "http://example.com/x", dest, hex.EncodeToString(sum[:])); err == nil ||
		err.Error() != "Refusing non-HTTPS Android SDK download: http:" {
		t.Errorf("plain http err = %v", err)
	}
}

func TestUnzipKeepsModesAndRejectsEscapes(t *testing.T) {
	build := func(name string, mode os.FileMode, content string) string {
		path := filepath.Join(t.TempDir(), "a.zip")
		f, _ := os.Create(path)
		zw := zip.NewWriter(f)
		hdr := &zip.FileHeader{Name: name, Method: zip.Deflate}
		hdr.SetMode(mode)
		w, _ := zw.CreateHeader(hdr)
		_, _ = io.WriteString(w, content)
		zw.Close()
		f.Close()
		return path
	}
	dir := t.TempDir()
	if err := unzip(build("cmdline-tools/bin/sdkmanager", 0o755, "#!/bin/sh\n"), dir); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(filepath.Join(dir, "cmdline-tools", "bin", "sdkmanager"))
	if err != nil || info.Mode().Perm() != 0o755 {
		t.Fatalf("extracted = %v, %v", info, err)
	}
	if err := unzip(build("../escape.txt", 0o644, "x"), dir); err == nil {
		t.Fatal("zip-slip entry extracted")
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(dir), "escape.txt")); err == nil {
		t.Fatal("file written outside the target")
	}
}

func TestPickSystemImage(t *testing.T) {
	sdk := t.TempDir()
	for _, p := range []string{
		"android-34/google_apis/x86_64", "android-36/google_apis/arm64-v8a", "android-35/google_apis_playstore/arm64-v8a",
		"android-36/default/x86_64",
	} {
		must(t, os.MkdirAll(filepath.Join(sdk, "system-images", filepath.FromSlash(p)), 0o755))
	}
	want := "system-images;android-36;google_apis;arm64-v8a"
	if !hostIsARM() {
		want = "system-images;android-34;google_apis;x86_64"
	}
	if got := pickSystemImage(sdk); got != want {
		t.Fatalf("picked %q, want %q", got, want)
	}
	if pickSystemImage(t.TempDir()) != "" {
		t.Fatal("empty sdk picked an image")
	}
}

func TestPatchAvdConfig(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.ini")
	must(t, os.WriteFile(path, []byte("hw.ramSize = 2048\ndisk.dataPartition.size=6G\ndisk.cachePartition.size = 66MB\nuserdata.useQcow2 = no\n"), 0o644))
	must(t, patchAvdConfig(path))
	got, _ := os.ReadFile(path)
	want := "hw.ramSize = 2048\ndisk.dataPartition.size = 2147483648\ndisk.cachePartition.size = 33554432\nuserdata.useQcow2 = yes\n"
	if string(got) != want {
		t.Fatalf("config:\n%s", got)
	}
	must(t, os.WriteFile(path, []byte("hw.ramSize = 1\n"), 0o644))
	must(t, patchAvdConfig(path))
	if got, _ := os.ReadFile(path); !strings.HasSuffix(string(got), "\nuserdata.useQcow2 = yes\n") {
		t.Fatalf("missing qcow2 line: %q", got)
	}
}

// lifecycleStack builds a fake SDK complete enough to skip provisioning, whose
// emulator is a script.
func lifecycleStack(t *testing.T, emulatorScript string) (*stack, *Controller) {
	t.Helper()
	s := newStack(t, false)
	sdk := s.fake.sdk
	for _, dir := range []string{"cmdline-tools/latest/bin", "system-images/android-36/google_apis/arm64-v8a", "system-images/android-36/google_apis/x86_64"} {
		must(t, os.MkdirAll(filepath.Join(sdk, filepath.FromSlash(dir)), 0o755))
	}
	must(t, os.WriteFile(filepath.Join(sdk, "cmdline-tools", "latest", "bin", "sdkmanager"), nil, 0o755))
	must(t, os.WriteFile(filepath.Join(sdk, "emulator", "emulator"), []byte(emulatorScript), 0o755))
	s.host.cfg.RuntimeHome = s.fake.home
	must(t, os.MkdirAll(filepath.Join(s.host.cfg.AVDHome, "neoagent_1.avd"), 0o755))
	s.host.cfg.Log = slog.New(slog.NewTextHandler(io.Discard, nil))
	c, err := s.host.Controller("1")
	must(t, err)
	return s, c
}

func waitFor(t *testing.T, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(20 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

func TestEmulatorLifecycle(t *testing.T) {
	s, c := lifecycleStack(t, "#!/bin/sh\necho $$ > \"$FAKE_ADB_PID_FILE\"\nexec sleep 600\n")
	logo, _ := filepath.Abs("testdata/screen.png")
	s.host.cfg.LogoPath = logo
	ctx := context.Background()

	res, err := c.RequestStartEmulator(ctx, StartOptions{})
	if err != nil {
		t.Fatal(err)
	}
	if p, ok := res.(PendingStart); !ok || !p.Success || !p.Pending || !p.Starting {
		t.Fatalf("start = %#v", res)
	}
	waitFor(t, "boot", func() bool { st, _ := c.GetStatus(ctx); return st.Bootstrapped && !st.Starting })

	st, _ := c.GetStatus(ctx)
	if st.AdbSerial == nil || *st.AdbSerial != c.adbSerial || len(st.Devices) != 1 || st.Starting || st.LastStartError != nil {
		t.Fatalf("status = %+v", st)
	}
	if serial := c.LiveAdbSerial(); serial != c.adbSerial {
		t.Fatalf("live serial = %q", serial)
	}
	waitFor(t, "wallpaper", func() bool {
		raw, _ := os.ReadFile(s.fake.log)
		return strings.Contains(string(raw), "wallpaper set-stream")
	})
	raw, _ := os.ReadFile(s.fake.log)
	for _, want := range []string{
		"-s " + c.adbSerial + " shell getprop sys.boot_completed",
		"-s " + c.adbSerial + " push " + logo + " /sdcard/neoagent-wallpaper.png",
		"-s " + c.adbSerial + " shell cmd wallpaper set-stream",
	} {
		if !strings.Contains(string(raw), want) {
			t.Fatalf("adb log lacks %q:\n%s", want, raw)
		}
	}

	// A second start while running just reports the running emulator.
	again, _ := c.RequestStartEmulator(ctx, StartOptions{})
	if r, ok := again.(RunningStart); !ok || !r.Bootstrapped || r.Pending {
		t.Fatalf("second start = %#v", again)
	}

	pid := *c.state().PID
	if _, err := c.StopEmulator(ctx); err != nil {
		t.Fatal(err)
	}
	if c.LiveAdbSerial() != "" {
		t.Fatal("emulator still live after stop")
	}
	waitFor(t, "process exit", func() bool { return !adbx.PidAlive(pid) })
	st, _ = c.GetStatus(ctx)
	if st.Bootstrapped || st.AdbSerial != nil {
		t.Fatalf("status after stop = %+v", st)
	}
}

func TestEmulatorStartFailureIsRecorded(t *testing.T) {
	_, c := lifecycleStack(t, "#!/bin/sh\necho 'no KVM here' >&2\nexit 3\n")
	ctx := context.Background()
	if _, err := c.RequestStartEmulator(ctx, StartOptions{}); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "failure", func() bool { st := c.state(); return !st.Starting && st.LastStartError != nil })
	st := c.state()
	if deref(st.StartupPhase) != "Failed" || st.PID != nil || st.AdbSerial != nil || st.Bootstrapped {
		t.Fatalf("state = %+v", st)
	}
	if msg := *st.LastStartError; !strings.HasPrefix(msg, "Android emulator exited before boot completed (3).") || !strings.Contains(msg, "no KVM here") {
		t.Fatalf("error = %q", msg)
	}
	// WaitForDevice surfaces the recorded failure.
	if _, err := c.WaitForDevice(ctx, time.Second); err == nil || !strings.HasPrefix(err.Error(), "Android emulator exited before boot completed") {
		t.Fatalf("WaitForDevice err = %v", err)
	}
}

func TestStopCancelsStartup(t *testing.T) {
	// An emulator that never boots: adb answers 0 for the boot property.
	s, c := lifecycleStack(t, "#!/bin/sh\nexec sleep 600\n")
	script, _ := os.ReadFile("testdata/fake_adb.sh")
	patched := strings.Replace(string(script), `"getprop sys.boot_completed") echo 1 ;;`, `"getprop sys.boot_completed") echo 0 ;;`, 1)
	must(t, os.WriteFile(filepath.Join(s.fake.sdk, "platform-tools", "adb"), []byte(patched), 0o755))
	ctx := context.Background()
	if _, err := c.RequestStartEmulator(ctx, StartOptions{}); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "emulator process", func() bool { st := c.state(); return st.PID != nil })
	pid := *c.state().PID
	if _, err := c.StopEmulator(ctx); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "process exit", func() bool { return !adbx.PidAlive(pid) })
	st := c.state()
	if st.Starting || st.PID != nil || st.Bootstrapped {
		t.Fatalf("state = %+v", st)
	}
}

func TestIntentURLValidation(t *testing.T) {
	h, _ := NewHost(HostConfig{DataDir: t.TempDir(), RuntimeHome: t.TempDir(), URLCheck: func(context.Context, string) (bool, string, error) {
		return false, "blocked by checker", nil
	}})
	for raw, want := range map[string]string{
		"":                 "No URI was given.",
		"nonsense":         `"nonsense" is not a valid URI. Include a scheme, e.g. https:// or geo:`,
		"FILE:///x":        "The file: scheme is not allowed for Android intents.",
		"content://a/b":    "The content: scheme is not allowed for Android intents.",
		"https://x.test/":  "blocked by checker",
		"geo:0,0?q=Berlin": "",
		"market://details": "",
		"tel:+491234":      "",
	} {
		allowed, reason, err := h.ValidateIntentURL(context.Background(), raw)
		if err != nil || allowed != (want == "") || reason != want {
			t.Errorf("%q: allowed=%v reason=%q err=%v, want reason %q", raw, allowed, reason, err, want)
		}
	}
}
