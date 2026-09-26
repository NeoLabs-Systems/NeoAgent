# NeoAgent Client

The NeoAgent client application — one Flutter codebase shipping to web, Android,
Windows, macOS, and Linux. It connects to a self-hosted NeoAgent server and is
the surface for chat, live runs, device control, integrations, and setup.

## Layout

| Path | Contents |
|------|----------|
| `lib/src/` | Client logic — backend client, discovery, runtime management, platform bridges |
| `lib/src/theme/` | Design tokens and palette (mirrored by the `web/index.html` splash) |
| `web/` | Web shell: `index.html`, `manifest.json`, icons |
| `android/`, `windows/`, `macos/`, `linux/` | Per-platform runners and packaging |
| `tool/` | Branding and desktop asset generation |

Platform-specific code follows the `*_io.dart` / `*_web.dart` / `*_stub.dart`
conditional-import pattern; keep the stub in sync when adding a new bridge.

## Working on it

```bash
flutter analyze --no-pub
```

```bash
npm run flutter:test
```

UI work must follow [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) — use the documented
spacing, color, and typography tokens rather than raw values.

See [docs/development.md](../docs/development.md) for the full workflow and
[docs/clients-and-devices.md](../docs/clients-and-devices.md) for how the client
pairs with a server.
