---
title: Development and testing
sidebar_label: Development
description: Set up a local checkout, follow the server conventions, and run the right test suite.
---

# Development and testing

**Clone, run the backend in watch mode, test the suite you touched, and follow [GUIDELINES.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/GUIDELINES.md) for every change.**

## Requirements

| Tool | Version |
|---|---|
| Node.js | `>=20.19.0`; CI tests Node 20 and 22 |
| npm | Ships with Node.js |
| Flutter | Stable channel; CI pins 3.35.6 |
| ESP-IDF | Only for wearable firmware |

## Setup

```bash
git clone https://github.com/NeoLabs-Systems/NeoAgent.git
cd NeoAgent
npm ci
export NEOAGENT_HOME="$HOME/.neoagent-dev"
npm run dev:backend
```

- **Separate data.** Without `NEOAGENT_HOME`, development shares `~/.neoagent` with a real install.
- **Checkout `.env`.** A `.env` in the repository root is loaded before `NEOAGENT_HOME/.env` and copied there if that file is missing.

:::warning `dev:backend` frees port 3333 by force
`dev/backend.sh` runs `kill -9` on whatever listens on port 3333, including an installed NeoAgent service.
:::

## Dev scripts

| Command | Runs |
|---|---|
| `npm run dev:backend` | `node --watch server/index.js` after freeing port 3333 (`dev/backend.sh prod` runs `npm start`) |
| `npm run flutter:run:web` | Flutter web client in Chrome against `NEOAGENT_BACKEND_URL` (default `http://localhost:3333`) |
| `npm run dev:web` | `flutter run -d chrome` on port 54009 with `NEOAGENT_BACKEND_URL=http://localhost:3333` |
| `npm run dev:stack` | `dev:backend` and `dev:web` together, stopping a stale NeoAgent on the port first |
| `npm run dev:test` | `npm test`, `node --check` on entry points, `flutter analyze` |
| `npm start` | `node server/index.js` without watch |

Point it at another backend with `NEOAGENT_BACKEND_URL=http://192.168.1.20:3333 npm run flutter:run:web`.

:::danger Never build the web client locally
These run `flutter build web` and overwrite `server/public`, which only the release pipeline builds:

- `npm run flutter:build:web`
- `npm run dev:build`
- `neoagent rebuild-web`, and `neoagent install` from a checkout when Flutter is on `PATH`
:::

## Tests

| Command | Runs |
|---|---|
| `npm run test:unit` | `test/backend/unit/*.test.js` |
| `npm run test:integration` | `test/integration/*.test.js` |
| `npm run test:security` | `test/security/*.test.js` |
| `npm run test:contract` | `test/contract/*.test.js` |
| `npm run test:e2e` | `test/e2e/*.test.js` |
| `npm run test:ws` | `test/websocket/*.test.js` |
| `npm run test:backend` (`npm test`) | The six suites above, chained with `&&` |
| `npm run flutter:test` | `test/flutter/unit` and `test/flutter/widget` |
| `npm run flutter:test:unit`, `flutter:test:widget` | One Flutter folder |
| `bash test/install/install_smoke_test.sh` | Repository install in temporary directories |

- **Chained suites.** `test:backend` stops at the first failing suite; run the remaining suites one by one to see their results.
- **App-local Flutter tests.** `flutter_app/test/` (call, launcher, loading, mascot) is outside `flutter:test`; run `flutter test` inside `flutter_app`.
- **Analyzer.** `cd flutter_app && flutter analyze --no-pub` uses `analysis_options.yaml`.

:::note One unit test needs an Alpine ISO
- **Where it runs.** `test/backend/unit/qemu_ramfb_display.test.js` runs on arm64 hosts with `qemu-system-aarch64` and edk2 firmware; elsewhere it skips.
- **What it needs.** `/tmp/neoagent-display-test/alpine-virt-aarch64.iso`; without it the test fails and `test:backend` stops.
:::

## Other checks

| Command | Checks |
|---|---|
| `npm run setup:contract:check` | `flutter_app/lib/src/setup_contract.g.dart` matches `lib/setup/contract.json` |
| `npm run audit:ci` | `npm audit` of production dependencies at high severity |
| `npm run docs:build` | Docusaurus build; broken links fail it |

## CI

`.github/workflows/ci.yml` runs on pushes to `main`, `beta` and `dev`, and on pull requests to `beta`.

| Job | Steps |
|---|---|
| Backend tests | `npm ci`, `npm run test:backend` on Node 20 and 22 |
| Flutter tests | `flutter pub get`, `flutter analyze --no-pub`, `npm run flutter:test` |

## Server conventions

[GUIDELINES.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/GUIDELINES.md) is the full rule set; the essentials:

- **Modules.** CommonJS only; every new server file starts with `'use strict';`.
- **Layers.** Routes parse, call a service and respond; business logic lives in `server/services/`.
- **Database.** Only through `server/db/database.js`, synchronous and parameterized; schema changes go through the [migration layer](persistence.md#schema-changes).
- **Models.** LLM calls go through `server/services/ai/engine.js`; provider SDKs are imported only in `server/services/ai/providers/`.
- **Tools.** Defined in `server/services/ai/tools.js`; large results pass through `compactToolResult()`.
- **Paths and env.** Use `runtime/paths.js` constants and `runtime/env.js` helpers.
- **Logging.** `server/utils/logger.js` with a `[ServiceName]` prefix; log secrets only as boolean presence.
- **New env keys.** Add them to `.env.example` and to `logStartupConfig()` in `server/index.js`.

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
