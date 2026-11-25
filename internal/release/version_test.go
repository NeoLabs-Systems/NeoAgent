package release

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSetVersionUpdatesBothFiles(t *testing.T) {
	dir := t.TempDir()
	pkg := "{\n  \"name\": \"neoagent\",\n  \"version\": \"1.0.0\",\n  \"private\": true\n}\n"
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkg), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := SetVersion(dir, "1.2.3-beta.4"); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(filepath.Join(dir, "package.json"))
	if want := strings.Replace(pkg, `"1.0.0"`, `"1.2.3-beta.4"`, 1); string(got) != want {
		t.Fatalf("package.json = %q", got)
	}
	if v, _ := os.ReadFile(filepath.Join(dir, "VERSION")); string(v) != "1.2.3-beta.4\n" {
		t.Fatalf("VERSION = %q", v)
	}
	if err := SetVersion(dir, "v1.2.3"); err == nil {
		t.Fatal("a v-prefixed version must be rejected")
	}
}
