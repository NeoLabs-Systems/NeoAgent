---
title: Runtime packaging and trust
sidebar_label: Runtime packaging
description: How release runtime artifacts are built, signed, and activated.
---

# Runtime packaging and trust

**Desktop apps and the standalone CLI install the same signed, per-platform server runtime from GitHub Releases, verify it, and run it as a per-user background service.**

Container packaging is covered in [Docker](docker.md).

## Release artifacts

`.github/workflows/_build-installers.yml` builds the artifacts; `.github/workflows/_publish-release-assets.yml` signs the manifests and attaches everything to the release.

| Artifact | File name | Produced by |
|---|---|---|
| Server runtime | `neoagent-runtime-<platform>-<arch>-<version>.zip` | `scripts/stage_runtime.js` |
| Runtime metadata | `neoagent-runtime-metadata-<platform>-<arch>.json` (size, SHA-256) | `scripts/create_runtime_metadata.js` |
| Runtime manifest | `neoagent-runtime-manifest-<version>.json` and `.sig` | `scripts/create_runtime_manifest.js` |
| Release asset manifest | `neoagent-release-manifest-<version>.json` and `.sig` (SHA-256 of every asset) | `scripts/create_release_manifest.js` |
| Standalone CLI | `neoagent-cli-<platform>-<arch>-<version>` (`.exe` on Windows) | `scripts/build_cli_sea.js` |
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
├── node/                       Node.js 22 binary
└── app/
    ├── bin/  lib/  runtime/
    ├── server/                 includes server/public, the built web client
    ├── node_modules/           production dependencies only
    ├── computer-runtime/qemu/  portable QEMU, qemu-img and firmware
    └── package.json  package-lock.json  LICENSE  com.neoagent.plist
```

## Signing keys

| Item | Location |
|---|---|
| Public key (raw 32-byte Ed25519, base64) | `lib/setup/runtime_signing_public_key.txt` |
| App copy | `embeddedRuntimeSigningPublicKey` in `flutter_app/lib/src/setup_contract.g.dart`; CI also passes `--dart-define=NEOAGENT_RUNTIME_PUBLIC_KEY` |
| CLI copy | Compiled into the standalone CLI by `scripts/build_cli_sea.js` |
| Private key (PKCS#8 DER, base64) | GitHub Actions secret `NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY` |

- **Fail closed.** Publishing stops if the secret is missing or does not match the committed public key (`assertRuntimeSigningKeypair()`).
- **Exact bytes.** The signature covers the manifest file byte for byte; artifacts are sorted by platform and architecture, one per pair.

Generate a key pair locally; commit the public value and store only the private value as the secret:

```bash
node - <<'NODE'
const crypto = require('crypto');
const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
console.log('commit lib/setup/runtime_signing_public_key.txt =');
console.log(publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64'));
console.log('NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY=' +
  privateKey.export({ format: 'der', type: 'pkcs8' }).toString('base64'));
NODE
```

Rotating the key:

1. Commit the new public key to `lib/setup/runtime_signing_public_key.txt`.
2. Run `node scripts/generate_setup_contract.js`; `npm run setup:contract:check` confirms the Dart copy.
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
7. **Set up.** Run the bundled Node with `app/bin/neoagent.js install --quick|--full --non-interactive --json --runtime-package --channel <channel>`.
8. **Connect.** The setup engine streams versioned JSON events and returns the backend URL, instance ID, server version and a first-account claim token.

- **Rollback.** If setup fails, the previous `current.json` is restored and that version runs `repair --runtime-package`; with no previous version, `stop` runs instead.
- **Reuse.** An already complete `app/versions/<version>` is activated without a new download.

## Background service

`neoagent install` registers the service through `lib/setup/service_adapters.js`:

| OS | Service | Definition |
|---|---|---|
| macOS | launchd LaunchAgent `com.neoagent` | `~/Library/LaunchAgents/com.neoagent.plist` |
| Linux | systemd user unit | `~/.config/systemd/user/neoagent.service` |
| Windows | Task Scheduler task `NeoAgent` at logon, plus an immediate start | Per-user, limited rights |
| Fallback | Detached `node server/index.js` | PID in `data/neoagent.pid` |

## Standalone CLI

`scripts/build_cli_sea.js` bundles `bin/neoagent-bootstrap.js` with esbuild and injects it into a Node Single Executable Application with postject.

| State | `neoagent …` does |
|---|---|
| No runtime installed | Asks for Quickstart or Full setup, installs a verified runtime as above, then runs `install --runtime-package` |
| Runtime installed | Runs the command with that runtime's Node and `app/bin/neoagent.js` |
| `update [stable\|beta]` | Installs the newest runtime and runs `repair`; on failure, reactivates the previous version |
| `repair` | Downloads the runtime again, then runs `repair` |

Build one locally:

```bash
npm run build:cli:sea -- --output dist/neoagent-cli
```

## Platform signing

Platform signing is optional in `_build-installers.yml`; the runtime manifest signature is not.

| Platform | With secrets | Without secrets |
|---|---|---|
| macOS | App and CLI signed with Developer ID and Hardened Runtime; DMG signed, notarized and stapled | Ad-hoc signed app; the build logs a warning |
| Windows | Authenticode (SHA-256, timestamped) on app binaries, installer and CLI | Unsigned; the build logs a warning |
| Android | Release keystore from `ANDROID_KEYSTORE_*` secrets | Bundled CI keystore `flutter_app/android/ci-release.keystore` |
| Linux | Not signed | Not signed |
