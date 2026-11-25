package runtime

import (
	"fmt"
	"strings"
)

// Shared by Docker and QEMU guest builds. Only the daemon is installed; no
// extra image, CLI, package manager, or runtime download is required by tools.
const (
	tailscaleVersion     = "1.104.5"
	tailscaleSHA256AMD64 = "720cbbccbfc03d8b55df72afc19e5a72e31b0f65934700aa6fa38074d4ad7bf7"
	tailscaleSHA256ARM64 = "e900b0e6e25023a1e504b2c237ce2a32ea0535e006f8c1a1097a490886493b6c"
)

// Each step stops the script itself: the QEMU bootstrap runs without `set -e`,
// so a failed checksum would otherwise go on to install the download.
func orFail(step string) string {
	return fmt.Sprintf(`|| { echo "Error: Tailscale %s failed." >&2; rm -rf "$ts_tmp"; exit 1; };`, step)
}

// TailscaleInstallScript is the shell script that installs tailscaled in a
// guest from the pinned release, verifying its checksum.
func TailscaleInstallScript() string {
	return strings.Join([]string{
		`case "$(uname -m)" in`,
		fmt.Sprintf(`  x86_64) ts_arch=amd64; ts_sha=%s ;;`, tailscaleSHA256AMD64),
		fmt.Sprintf(`  aarch64|arm64) ts_arch=arm64; ts_sha=%s ;;`, tailscaleSHA256ARM64),
		`  *) echo "Unsupported Tailscale guest architecture" >&2; exit 1 ;;`,
		`esac;`,
		fmt.Sprintf(`ts_tmp=$(mktemp -d) %s`, orFail("temp directory")),
		fmt.Sprintf(`curl --fail --silent --show-error --location --retry 3 "https://pkgs.tailscale.com/stable/tailscale_%s_$ts_arch.tgz" -o "$ts_tmp/client.tgz" %s`, tailscaleVersion, orFail("download")),
		fmt.Sprintf(`echo "$ts_sha  $ts_tmp/client.tgz" | sha256sum -c - %s`, orFail("checksum")),
		fmt.Sprintf(`tar -xzf "$ts_tmp/client.tgz" -C "$ts_tmp" "tailscale_%s_$ts_arch/tailscaled" %s`, tailscaleVersion, orFail("extract")),
		fmt.Sprintf(`install -m 0755 "$ts_tmp/tailscale_%s_$ts_arch/tailscaled" /usr/local/bin/tailscaled %s`, tailscaleVersion, orFail("install")),
		`rm -rf "$ts_tmp";`,
	}, "\n")
}
