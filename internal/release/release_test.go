package release

import (
	"archive/zip"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	nlrelease "github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

// testdata/*.txt were rendered by scripts/release_download_notes.js.
func TestDownloadNotesMatchNode(t *testing.T) {
	assets := []ReleaseAsset{{Name: "neoagent-macos-arm64-3.8.1.dmg", URL: "https://x/a b"}, {Name: "neoagent-android-launcher-3.8.1.apk"}, {Name: "neoagent-android-3.8.1.apk"}, {Name: "other.zip"}}
	section := DownloadNotes("v3.8.1-beta.1", "NeoLabs-Systems/NeoAgent", assets)
	for file, got := range map[string]string{
		"notes.txt":  section,
		"merge1.txt": MergeDownloadNotes("\uFEFFintro\n\n<!-- neoagent-download:start -->old<!-- neoagent-download:end -->\n\n  rest", section),
		"merge2.txt": MergeDownloadNotes("  body", section),
	} {
		want, err := os.ReadFile(filepath.Join("testdata", file))
		if err != nil {
			t.Fatal(err)
		}
		if got != string(want) {
			t.Errorf("%s differs\n got %q\nwant %q", file, got, want)
		}
	}
}

func TestWebBuildID(t *testing.T) {
	if WebBuildID(func(string) string { return " fixed " }, time.Now()) != "fixed" {
		t.Fatal("explicit id")
	}
	id := WebBuildID(func(string) string { return "" }, time.UnixMilli(36*36))
	if !strings.HasPrefix(id, "100-") {
		t.Fatal(id)
	}
}

func TestStageRuntimeAndMetadata(t *testing.T) {
	src := t.TempDir()
	write := func(rel, body string, mode os.FileMode) string {
		p := filepath.Join(src, rel)
		os.MkdirAll(filepath.Dir(p), 0o755)
		os.WriteFile(p, []byte(body), mode)
		return p
	}
	bin := write("build/neoagent", "bin", 0o755)
	guest := write("build/neoagent-guest-linux-amd64", "guest", 0o755)
	write("public/index.html", "<html>", 0o644)
	write("landing/index.html", "landing", 0o644)
	write("qemu/bin/qemu-system-x86_64", "q", 0o755)
	write("qemu/bin/qemu-img", "i", 0o755)
	write("qemu/share/qemu/bios.bin", "b", 0o644)
	write("qemu/manifest.json", "{}", 0o644)
	lic := write("LICENSE", "AGPL", 0o644)

	stage := filepath.Join(t.TempDir(), "stage")
	err := StageRuntime(StageOptions{Output: stage, Binary: bin, Guests: []string{guest}, WebDir: filepath.Join(src, "public"), LandingDir: filepath.Join(src, "landing"),
		ComputerRuntime: filepath.Join(src, "qemu"), Platform: "linux", Architecture: "x64", License: lic})
	if err != nil {
		t.Fatal(err)
	}
	for _, rel := range []string{"app/bin/neoagent", "app/bin/neoagent-guest-linux-amd64", "app/public/index.html", "app/landing/index.html", "app/computer-runtime/qemu/share/qemu/bios.bin", "app/LICENSE"} {
		if _, err := os.Stat(filepath.Join(stage, rel)); err != nil {
			t.Errorf("missing %s", rel)
		}
	}
	if info, _ := os.Stat(filepath.Join(stage, "app/bin/neoagent")); info.Mode().Perm()&0o111 == 0 {
		t.Fatal("binary is not executable")
	}
	if err := StageRuntime(StageOptions{Output: stage, Binary: bin, WebDir: filepath.Join(src, "missing"), Platform: "linux"}); err == nil {
		t.Fatal("missing web client accepted")
	}

	dist := t.TempDir()
	asset := filepath.Join(dist, RuntimeAssetName("linux", "x64", "v1.2.3"))
	StageRuntime(StageOptions{Output: stage, Binary: bin, WebDir: filepath.Join(src, "public"), Platform: "linux"})
	if err := nlrelease.CreateZip(stage, asset); err != nil {
		t.Fatal(err)
	}
	if err := WriteRuntimeMetadata(asset, filepath.Join(dist, RuntimeMetadataPrefix+"linux-x64.json"), "linux", "x64"); err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(filepath.Join(dist, RuntimeMetadataPrefix+"linux-x64.json"))
	var meta nlrelease.Artifact
	json.Unmarshal(raw, &meta)
	if meta.AssetName != "neoagent-runtime-linux-x64-1.2.3.zip" || meta.SizeBytes <= 0 || len(meta.SHA256) != 64 {
		t.Fatalf("%s", raw)
	}
	if err := WriteRuntimeMetadata(asset, filepath.Join(dist, "x.json"), "linux", "arm64"); err == nil {
		t.Fatal("unsupported target accepted")
	}
	zr, err := zip.OpenReader(asset)
	if err != nil {
		t.Fatal(err)
	}
	defer zr.Close()
	found := false
	for _, f := range zr.File {
		found = found || f.Name == "app/bin/neoagent"
	}
	if !found {
		t.Fatal("archive lacks app/bin/neoagent")
	}
	// Without the real private key the manifest cannot be signed.
	if err := WriteRuntimeManifest(dist, filepath.Join(dist, RuntimeManifestPrefix+"1.2.3.json"), "1.2.3", ""); err == nil {
		t.Fatal("signed without a key")
	}
	if setupcontract.PublicKey() == "" {
		t.Fatal("no embedded key")
	}
}

// Older Node.js installations update by checking out a release and running
// npm install: package.json must carry the release version (or the updater
// sees nothing newer) and .npmrc must keep that install a dry run.
func TestNodeHandoverFiles(t *testing.T) {
	version, err := os.ReadFile("../../" + VersionFile)
	if err != nil {
		t.Skip("not in the repository")
	}
	var pkg struct {
		Version string            `json:"version"`
		Scripts map[string]string `json:"scripts"`
	}
	raw, err := os.ReadFile("../../package.json")
	if err != nil || json.Unmarshal(raw, &pkg) != nil {
		t.Fatalf("package.json: %v", err)
	}
	if pkg.Version != strings.TrimSpace(string(version)) {
		t.Fatalf("package.json version %q != VERSION %q", pkg.Version, strings.TrimSpace(string(version)))
	}
	if pkg.Scripts["postinstall"] != "sh scripts/node-handover.sh" || len(pkg.Scripts) != 1 {
		t.Fatalf("scripts %v", pkg.Scripts)
	}
	npmrc, _ := os.ReadFile("../../.npmrc")
	if !strings.Contains(string(npmrc), "\ndry-run=true\n") {
		t.Fatalf(".npmrc lacks dry-run: %q", npmrc)
	}
}
