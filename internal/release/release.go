// Package release builds and signs NeoAgent's release assets: the runtime
// archive the desktop app and `neoagent update` install, its metadata, the
// signed runtime and release manifests, the portable QEMU runtime and the
// download section of the GitHub release notes. cmd/neoagent-release is the
// command line in front of it, so CI needs nothing but Go.
package release

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	nlrelease "github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

// Asset name prefixes the desktop app and the CLI look for.
const (
	RuntimeManifestPrefix = "neoagent-runtime-manifest-"
	RuntimeMetadataPrefix = "neoagent-runtime-metadata-"
	ReleaseManifestPrefix = "neoagent-release-manifest-"
	Repository            = "NeoLabs-Systems/NeoAgent"
)

// RuntimeAssetName is the runtime archive of a platform, architecture and
// version, e.g. neoagent-runtime-linux-x64-3.8.1.zip.
func RuntimeAssetName(platform, architecture, version string) string {
	return fmt.Sprintf("neoagent-runtime-%s-%s-%s.zip", platform, architecture, strings.TrimPrefix(version, "v"))
}

// WriteRuntimeMetadata digests a runtime archive into its metadata file.
func WriteRuntimeMetadata(asset, output, platform, architecture string) error {
	sum, size, err := nlrelease.FileDigest(asset)
	if err != nil {
		return err
	}
	a, err := nlrelease.NormalizeArtifact(nlrelease.Artifact{Platform: platform, Architecture: architecture, AssetName: filepath.Base(asset), SHA256: sum, SizeBytes: size}, setupcontract.C.RuntimeTargets)
	if err != nil {
		return err
	}
	data, err := nlrelease.Serialize(a)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(output), 0o755); err != nil {
		return err
	}
	return os.WriteFile(output, data, 0o644)
}

// WriteRuntimeManifest collects every runtime metadata file in dir into the
// signed runtime manifest at output (and output.sig).
func WriteRuntimeManifest(dir, output, version, privateKey string) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	var artifacts []nlrelease.Artifact
	for _, e := range entries {
		if !strings.HasPrefix(e.Name(), RuntimeMetadataPrefix) || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			return err
		}
		var a nlrelease.Artifact
		if err := json.Unmarshal(raw, &a); err != nil {
			return fmt.Errorf("%s: %w", e.Name(), err)
		}
		artifacts = append(artifacts, a)
	}
	m, err := nlrelease.NewRuntimeManifest(setupcontract.C.SchemaVersion, version, artifacts, setupcontract.C.RuntimeTargets)
	if err != nil {
		return err
	}
	data, err := nlrelease.Serialize(m)
	if err != nil {
		return err
	}
	return nlrelease.WriteSigned(output, data, privateKey, setupcontract.PublicKey())
}

// WriteReleaseManifest digests every release asset in dir into the signed
// release manifest at output.
func WriteReleaseManifest(dir, output, version, privateKey string) error {
	m, err := nlrelease.NewReleaseManifest(setupcontract.C.SchemaVersion, version, dir, ReleaseManifestPrefix)
	if err != nil {
		return err
	}
	data, err := nlrelease.Serialize(m)
	if err != nil {
		return err
	}
	return nlrelease.WriteSigned(output, data, privateKey, setupcontract.PublicKey())
}

// VerifyManifest checks a manifest's signature against publicKey, or the
// embedded key when publicKey is empty.
func VerifyManifest(manifest, signature, publicKey string) error {
	data, err := os.ReadFile(manifest)
	if err != nil {
		return err
	}
	sig, err := os.ReadFile(signature)
	if err != nil {
		return err
	}
	if publicKey == "" {
		publicKey = setupcontract.PublicKey()
	}
	ok, err := nlrelease.Verify(data, string(sig), publicKey)
	if err != nil {
		return err
	}
	if !ok {
		return fmt.Errorf("The runtime manifest signature does not match the configured public key.")
	}
	return nil
}
