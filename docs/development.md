---
title: Development and testing
sidebar_label: Development
description: Set up a local checkout, follow the server conventions, and run the right test suite.
---

# Development and testing

**Clone, run the server with its own data directory, test the package you touched, and follow [GUIDELINES.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/GUIDELINES.md) for every change.**

## Requirements

| Tool | Version |
|---|---|
| Go | The version in `go.mod` |
| Flutter | Stable channel; CI pins 3.47.9 |
| ESP-IDF | Only for wearable firmware |

## Setup

```bash
git clone https://github.com/NeoLabs-Systems/NeoAgent.git
cd NeoAgent
export NEOAGENT_HOME="$HOME/.neoagent-dev"
go run ./cmd/neoagent serve
```

- **Separate data.** Without `NEOAGENT_HOME`, development shares `~/.neoagent` with a real install. The server reads only `NEOAGENT_HOME/.env`.
- **Foundation module.** Shared packages come from `github.com/NeoLabs-Systems/neolabs-go`. To change both at once, clone it next to this repository and run `go work init . ../neolabs-go` (`go.work` is ignored by Git).
- **Web client.** Run it against the local server with `cd flutter_app && flutter run -d chrome --dart-define=NEOAGENT_BACKEND_URL=http://localhost:3333`; point `NEOAGENT_BACKEND_URL` at another server to use that one.

:::danger Never build the web client locally
`flutter build web` overwrites `public/`, which only the release pipeline builds. `neoagent rebuild-web` runs it too, and runs `flutter upgrade` when Flutter is older than 3.47.9.
:::

## Tests

| Command | Runs |
|---|---|
| `go test ./internal/<package>/...` | One package while you work |
| `go test -race ./...` | Every Go test; CI runs this |
| `go vet ./...` and `gofmt -l cmd internal` | Vet and formatting, both required by CI |
| `go run honnef.co/go/tools/cmd/staticcheck@v0.8.2 ./...` | Staticcheck with `staticcheck.conf` |
| `cd flutter_app && flutter test ../test/flutter/unit ../test/flutter/widget` | Flutter unit and widget tests |

- **Recorded behaviour.** Many tests replay request/response scenarios and vectors in `testdata/`. A changed API response or prompt text fails them on purpose; update the recording together with the change.
- **Temporary data.** Tests open a temporary SQLite database; never point a test or tool at `~/.neoagent`.
- **Browser tests.** Tests that drive Chrome skip when no Chrome is installed.
- **App-local Flutter tests.** `flutter_app/test/` (call, launcher, loading, mascot) runs with `flutter test` inside `flutter_app`.
- **Analyzer.** `cd flutter_app && flutter analyze --no-pub` uses `analysis_options.yaml`.

## Other checks

| Command | Checks |
|---|---|
| `go run ./cmd/neoagent-release setup-contract --check` | `flutter_app/lib/src/setup_contract.g.dart` matches the setup contract |
| `go run golang.org/x/vuln/cmd/govulncheck@v1.10.0 ./...` | Known vulnerabilities in reachable code |
| `cd website && npm ci && npm run build` | Docusaurus build of `docs/`; broken links fail it |

## CI

`.github/workflows/ci.yml` runs on pushes to `main`, `beta` and `dev`, on pull requests to `beta`, and before every release.

| Job | Steps |
|---|---|
| Go | gofmt, `go vet`, staticcheck, govulncheck, `go test -race`, static builds for every release target, setup contract check |
| Flutter tests | `flutter pub get`, `flutter analyze --no-pub`, unit and widget tests |

## Server conventions

[GUIDELINES.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/GUIDELINES.md) is the full rule set; the essentials:

- **Packages.** One package per domain in `internal/`; domains do not import each other and talk through small interfaces that `internal/wiring` satisfies.
- **Layers.** Handlers parse, call a service and respond; business logic lives in the service.
- **Database.** One SQLite handle, parameterized queries; schema changes go through the [migration layer](persistence.md#schema-changes).
- **Models.** LLM calls go through `neolabs-go/llm` via `internal/ai/models`.
- **Tools.** Schemas and metadata in `internal/ai/tools/definitions.json`, code in `internal/ai/handlers`; large results pass through result compaction.
- **Config.** Read environment and paths through `internal/config`.
- **Logging.** `slog`; log secrets only as boolean presence.
- **New env keys.** Add them to `.env.example`.

## Flutter conventions

- **State.** `MainController` is the single root `ChangeNotifier`; no other state packages.
- **Thin widgets.** Logic goes in `lib/src/<feature>_bridge.dart` or `lib/src/<feature>_service.dart`.
- **Platforms.** Use the `_io`, `_web` and `_stub` conditional-export files, not inline `kIsWeb` branches.
- **Cleanup.** Cancel every stored subscription and listener in `dispose()`.

## Wearable firmware

```bash
bash scripts/flash_wearable.sh --port /dev/cu.usbmodem1101
```

- **Toolchain.** Needs ESP-IDF on `PATH`, in `IDF_PATH`, or at `~/esp/esp-idf`.
- **Options.** `--erase`, `--monitor` and `--skip-build`; the port is an example.

## Contributions

- **Target branch.** Pull requests go to `beta`, never `main`.
- **Scope.** Keep changes focused, add tests for behavior changes, and update docs for new commands or settings.
- **Never commit.** `.env`, `data/`, `agent-data/` or anything in `.gitignore`; do not use `--no-verify`.
- **Changelog.** GitHub Releases are the release history; do not add `CHANGELOG.md`.

See [CONTRIBUTING.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/CONTRIBUTING.md) for the review process.
