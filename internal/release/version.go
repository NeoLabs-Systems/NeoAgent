package release

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
)

var (
	versionPattern     = regexp.MustCompile(`^\d+\.\d+\.\d+(-beta\.\d+)?$`)
	packageVersionLine = regexp.MustCompile(`("version":\s*)"[^"]*"`)
)

// VersionFile holds the release version, relative to the repository root.
const VersionFile = "internal/buildinfo/VERSION"

// SetVersion writes the release version to VersionFile and to package.json, which
// must carry the same version for the Node.js updater handover (see
// scripts/node-handover.sh).
func SetVersion(root, version string) error {
	if !versionPattern.MatchString(version) {
		return fmt.Errorf("invalid version %q: want MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-beta.N", version)
	}
	pkgPath := filepath.Join(root, "package.json")
	pkg, err := os.ReadFile(pkgPath)
	if err != nil {
		return err
	}
	if !packageVersionLine.Match(pkg) {
		return fmt.Errorf("%s has no version field", pkgPath)
	}
	pkg = packageVersionLine.ReplaceAll(pkg, []byte(`${1}"`+version+`"`))
	if err := os.WriteFile(pkgPath, pkg, 0o644); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(root, VersionFile), []byte(version+"\n"), 0o644)
}
