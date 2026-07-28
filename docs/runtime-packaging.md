# Runtime packaging and trust

Desktop apps and standalone CLI executables use the same release runtime
artifacts. Each artifact contains the Node runtime, production dependencies,
native modules, server files, and prebuilt Flutter web client for one operating
system and processor architecture.

Release CI creates:

- one target- and version-named `neoagent-runtime` ZIP per build
- metadata with platform, architecture, byte size, and SHA-256
- one deterministic runtime manifest
- an Ed25519 signature for the exact manifest bytes
- a Node Single Executable Application for the standalone CLI

The Flutter app and CLI are compiled with the same raw 32-byte Ed25519 public
key. The private PKCS#8 key is available only to the release manifest job.
Release CI refuses to publish if the private key does not match the embedded
public key.

Generate a key pair locally and copy the two printed base64 values directly
into the named GitHub Actions secrets:

```bash
node - <<'NODE'
const crypto = require('crypto');
const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
console.log('NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY=' +
  privateKey.export({ format: 'der', type: 'pkcs8' }).toString('base64'));
console.log('NEOAGENT_RUNTIME_SIGNING_PUBLIC_KEY=' +
  publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64'));
NODE
```

Treat the private value as a release signing credential. Rotating it requires a
desktop and standalone CLI release containing the new public key before runtime
manifests are signed exclusively with the new private key.

Production release jobs also require the Windows Authenticode certificate
secrets and the macOS Developer ID/notarization secrets declared by
`_build-installers.yml`. Release builds fail closed when any platform signing
credential is absent. macOS app bundles use Hardened Runtime, the DMG is
Developer ID signed, submitted to Apple notary service, and stapled. Windows
application binaries, the Inno Setup installer, and standalone CLI are
timestamped and Authenticode signed.

Runtime staging is versioned under the per-user NeoAgent data directory.
Activation writes `app/current.json` atomically. The desktop installer restores
the previous marker and service when setup or readiness fails.
