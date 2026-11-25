---
title: Runtime packaging and trust
sidebar_label: Runtime packaging
description: How release runtime artifacts are built, signed, and activated.
---

# Runtime packaging and trust

**Desktop apps and the standalone CLI install the same signed, per-platform server runtime from GitHub Releases, verify it, and run it as a per-user background service.**

Container packaging is covered in [Docker](docker.md). The release tool is `cmd/neoagent-release`; run `go run ./cmd/neoagent-release` for its subcommands.

## Release artifacts

`.github/workflows/_build-installers.yml` builds the artifacts; `.github/workflows/_publish-release-assets.yml` signs the manifests and attaches everything to the release.

| Artifact | File name | Produced by |
|---|---|---|
| Server runtime | `neoagent-runtime-<platform>-<arch>-<version>.zip` | `neoagent-release stage-runtime` and `runtime-archive` |
| Runtime metadata | `neoagent-runtime-metadata-<platform>-<arch>.json` (size, SHA-256) | `neoagent-release runtime-metadata` |
| Runtime manifest | `neoagent-runtime-manifest-<version>.json` and `.sig` | `neoagent-release runtime-manifest` |
| Release asset manifest | `neoagent-release-manifest-<version>.json` and `.sig` (SHA-256 of every asset) | `neoagent-release release-manifest` |
| Standalone CLI | `neoagent-cli-<platform>-<arch>-<version>` (`.exe` on Windows) | The `neoagent` binary itself |
| Desktop installers | `.dmg`, Inno Setup `.exe`, `.deb`, `.pkg.tar.zst`, `.AppImage` | Flutter desktop builds |
| Android | `neoagent-android-<version>.apk`, `neoagent-android-launcher-<version>.apk` | Flutter Android builds |

| Platform | Runtime and CLI architectures |
|---|---|
| macOS | `arm64`, `x64` |
| Windows | `x64`, `arm64` |
| Linux | `x64` |

## Runtime contents

```text
neoagent-runtime-<platform>-<arch>-<version>.zip
└── app/
    ├── bin/neoagent[.exe]              server and CLI
    ├── bin/neoagent-guest-linux-<arch> agent inside each cloud computer
    ├── public/                         the built web client
    ├── landing/
    ├── computer-runtime/qemu/          portable QEMU, qemu-img and firmware
    └── LICENSE
```

## Signing keys

| Item | Location |
|---|---|
| Public key (raw 32-byte Ed25519, base64) | `internal/setupcontract/runtime_signing_public_key.txt` |
| App copy | `embeddedRuntimeSigningPublicKey` in `flutter_app/lib/src/setup_contract.g.dart`; CI also passes `--dart-define=NEOAGENT_RUNTIME_PUBLIC_KEY` |
| CLI copy | Embedded in the `neoagent` binary |
| Private key (PKCS#8 DER, base64) | GitHub Actions secret `NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY` |

- **Fail closed.** Publishing stops if the secret is missing, and `neoagent-release verify-manifest` rejects a manifest signed with a key that does not match the committed public key.
- **Exact bytes.** The signature covers the manifest file byte for byte; artifacts are sorted by platform and architecture, one per pair.

Generate a key pair locally; commit the public value and store only the private value as the secret:

```bash
openssl genpkey -algorithm ed25519 -outform DER -out runtime-signing.der
echo "NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY=$(base64 < runtime-signing.der | tr -d '\n')"
openssl pkey -inform DER -in runtime-signing.der -pubout -outform DER | tail -c 32 | base64
```

The last line is the public value to commit.

Rotating the key:

1. Commit the new public key to `internal/setupcontract/runtime_signing_public_key.txt`.
2. Run `go run ./cmd/neoagent-release setup-contract`; `go run ./cmd/neoagent-release setup-contract --check` confirms the Dart copy.
3. Replace `NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY` before the next release.

:::warning Treat the private key as a release credential
Apps and CLIs verify only with the key they were built with, so after a rotation they must update before they can install a new runtime.
:::

## Desktop app install flow

`LocalBackendInstaller` (`flutter_app/lib/src/local_backend_installer_io.dart`) installs the server on macOS, Windows and Linux:

1. **Find a release.** Query the GitHub Releases API; stable skips prereleases, beta includes them.
2. **Verify the manifest.** Check `neoagent-runtime-manifest-*.json.sig` against the embedded public key.
3. **Download.** Fetch the artifact for this platform and architecture, capped at the manifest size.
4. **Check the hash.** Compare the archive's SHA-256 with the manifest.
5. **Stage.** Extract into a staging folder under `NEOAGENT_HOME/app/versions/` with entry names checked, then move it to `app/versions/<version>`.
6. **Activate.** Write `app/current.json` atomically through a temporary file and rename.
7. **Set up.** Run `app/bin/neoagent install --quick|--full --non-interactive --json --runtime-package --channel <channel>`.
8. **Connect.** The setup engine streams versioned JSON events and returns the backend URL, instance ID, server version and a first-account claim token.

- **Rollback.** If setup fails, the previous `current.json` is restored and that version runs `repair --runtime-package`; with no previous version, `stop` runs instead.
- **Reuse.** An already complete `app/versions/<version>` is activated without a new download.

## Background service

`neoagent install` registers the service through the foundation's `cli/service` package:

| OS | Service | Definition |
|---|---|---|
| macOS | launchd LaunchAgent `com.neoagent` | `~/Library/LaunchAgents/com.neoagent.plist` |
| Linux | systemd user unit | `~/.config/systemd/user/neoagent.service` |
| Windows | Task Scheduler task `NeoAgent` at logon, plus an immediate start | Per-user, limited rights |
| Fallback | Detached `neoagent serve` | PID in `data/neoagent.pid` |

## Standalone CLI

The standalone CLI is the `neoagent` binary. Without a web client next to it, it bootstraps a runtime.

| State | `neoagent …` does |
|---|---|
| No runtime installed | Asks for Quickstart or Full setup, installs a verified runtime as above, then runs `install --runtime-package` |
| Runtime installed | Runs the command with that runtime's `app/bin/neoagent` |
| `update [stable\|beta]` | Installs the newest runtime and runs `repair`; on failure, reactivates the previous version |
| `repair` | Downloads the runtime again, then runs `repair` |

Build one locally:

```bash
go build -o dist/neoagent ./cmd/neoagent
```

## Older Node.js installations

Installations from before the Go server update through their Node.js updater, which checks out the new release and runs `npm install`. The repository keeps a `package.json` whose only script is a `postinstall` running `scripts/node-handover.sh`, and an `.npmrc` that makes the install a dry run so the old dependencies stay intact for the updater's rollback. The script fails that install on purpose, so the Node.js version keeps running, and once the updater exits it runs `install.sh`. That installs the Go binary and runs `neoagent install`, which backs up the data, points the launchd or systemd service at the binary, and restores the old service if the new server does not answer. Windows Node.js installations need `install.sh` or the desktop app instead.

## Platform signing

Platform signing is optional in `_build-installers.yml`; the runtime manifest signature is not.

| Platform | With secrets | Without secrets |
|---|---|---|
| macOS | App and CLI signed with Developer ID and Hardened Runtime; DMG signed, notarized and stapled | Ad-hoc signed app; the build logs a warning |
| Windows | Authenticode (SHA-256, timestamped) on app binaries, installer and CLI | Unsigned; the build logs a warning |
| Android | Release keystore from `ANDROID_KEYSTORE_*` secrets | Bundled CI keystore `flutter_app/android/ci-release.keystore` |
| Linux | Not signed | Not signed |
