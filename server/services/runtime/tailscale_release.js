'use strict';

// Shared by Docker and QEMU guest builds. Only the daemon is installed; no
// extra image, CLI, package manager, or runtime download is required by tools.
const VERSION = '1.104.5';
const SHA256 = {
  amd64: '720cbbccbfc03d8b55df72afc19e5a72e31b0f65934700aa6fa38074d4ad7bf7',
  arm64: 'e900b0e6e25023a1e504b2c237ce2a32ea0535e006f8c1a1097a490886493b6c',
};

// Each step stops the script itself: the QEMU bootstrap runs without `set -e`,
// so a failed checksum would otherwise go on to install the download.
function orFail(step) {
  return `|| { echo "Error: Tailscale ${step} failed." >&2; rm -rf "$ts_tmp"; exit 1; };`;
}

function tailscaleInstallScript() {
  return [
    'case "$(uname -m)" in',
    `  x86_64) ts_arch=amd64; ts_sha=${SHA256.amd64} ;;`,
    `  aarch64|arm64) ts_arch=arm64; ts_sha=${SHA256.arm64} ;;`,
    '  *) echo "Unsupported Tailscale guest architecture" >&2; exit 1 ;;',
    'esac;',
    `ts_tmp=$(mktemp -d) ${orFail('temp directory')}`,
    `curl --fail --silent --show-error --location --retry 3 "https://pkgs.tailscale.com/stable/tailscale_${VERSION}_$ts_arch.tgz" -o "$ts_tmp/client.tgz" ${orFail('download')}`,
    `echo "$ts_sha  $ts_tmp/client.tgz" | sha256sum -c - ${orFail('checksum')}`,
    `tar -xzf "$ts_tmp/client.tgz" -C "$ts_tmp" "tailscale_${VERSION}_$ts_arch/tailscaled" ${orFail('extract')}`,
    `install -m 0755 "$ts_tmp/tailscale_${VERSION}_$ts_arch/tailscaled" /usr/local/bin/tailscaled ${orFail('install')}`,
    'rm -rf "$ts_tmp";',
  ].join('\n');
}

module.exports = { tailscaleInstallScript };
