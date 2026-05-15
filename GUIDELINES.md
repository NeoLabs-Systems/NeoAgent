# NeoAgent — Engineering Guidelines

## Project Overview

NeoAgent is a Node.js/Express backend + Flutter frontend personal AI agent. It supports multiple AI providers, SQLite storage, WebSocket real-time communication, and integrations with WhatsApp, Discord, Telegram, Google, Microsoft, Slack, Figma, Notion, and more.

### Directory Map

```
server/          Express HTTP server, all backend logic
  config/        Static configuration (origins, deployment flags)
  db/            SQLite via better-sqlite3
  http/          Middleware, routes registration, socket setup, static serving
  routes/        One file per feature domain (tasks.js, agents.js, etc.)
  services/      Business logic, grouped by domain
    ai/          LLM engine, providers, tool runner, history, compaction
    agents/      Agent profile manager
    skills/      Skill catalog and runtime
    tasks/       Task scheduling, execution, security
    integrations/ OAuth flows and integration runtimes
  utils/         Shared server-side helpers
runtime/         Startup paths, env resolution, release channel
lib/             Install helpers and migration logic
flutter_app/     Cross-platform Flutter client (web, Android, macOS, Windows, Linux)
  lib/src/       Feature-specific Dart source files
extensions/      Chrome browser extension (ES modules, .mjs)
scripts/         Build and release utility scripts
```

---

## Core Principles

- **No duplication.** Before adding a helper, search `server/utils/`, `runtime/`, and the relevant service directory. Reuse what exists.
- **No premature abstraction.** Three similar lines is fine. Abstract only when a fourth copy would appear.
- **No speculative features.** Implement exactly what the task requires. No extra fallbacks, feature flags, or backwards-compat shims for callers that don't yet exist.
- **No dead code.** Remove unused exports, variables, and branches. Do not leave commented-out blocks behind.
- **Readable over clever.** Prefer direct, boring code. Avoid chained `.reduce`, nested ternaries, or dense one-liners that obscure intent.

---

## Node.js / Server

### Module system

- CommonJS (`require` / `module.exports`) throughout the server. Do not introduce ES `import`/`export` in server files.
- Every new server file starts with `'use strict';`.

### File layout

- **Routes** (`server/routes/<domain>.js`) handle only HTTP concerns: parse the request, call a service, return a response. No business logic.
- **Services** (`server/services/<domain>/`) own all business logic. If a file grows past ~300 lines, split it.
- **Utils** (`server/utils/`) are pure helpers with no side effects and no service imports.

### Database

- All DB access goes through `server/db/database.js`. Never instantiate a second `Database`.
- Use the `better-sqlite3` synchronous API. No async wrappers or callbacks.
- All queries use parameterized statements. No string interpolation into SQL.
- Schema changes (migrations) belong in `lib/migrations.js`. No `ALTER TABLE` or `CREATE TABLE` inline in service files.

### AI / LLM

- All LLM calls go through `server/services/ai/engine.js`. Do not call provider SDKs directly from routes or other services.
- Provider-specific code belongs in `server/services/ai/providers/<name>.js`. Each provider extends `base.js`.
- Tool definitions are registered in `server/services/ai/tools.js`. Do not define ad-hoc tool schemas elsewhere.
- Large tool results must pass through `compactToolResult()` before being appended to conversation history.

### Error handling

- Validate at system boundaries: HTTP request bodies, external API responses, user-supplied env values. Do not defensively validate arguments passed between internal functions.
- Wrap I/O and external calls in `try/catch`. Log errors with a `[ServiceName]` prefix for searchability.
- Every route handler must send a response. Unhandled errors propagate to `server/http/errors.js`.

### Security

- Never log secrets, tokens, or PII. Log boolean presence (`Boolean(process.env.KEY)`) in startup diagnostics.
- Parameterized queries everywhere — no SQL string interpolation, ever.
- CORS and origin validation go through `server/config/origins.js`. No ad-hoc bypasses.
- Server startup must reject (and log clearly) if `SESSION_SECRET` is absent.

### Environment & paths

- Use the constants exported from `runtime/paths.js` for all filesystem paths. Never hardcode `~/.neoagent` or absolute system paths.
- Use `runtime/env.js` helpers for env access in service code. Raw `process.env` is acceptable only for simple top-level feature flags in entry points.

### Logging

- Use `server/utils/logger.js` in all service and library code. Plain `console.log` is only acceptable in entry-point startup sequences.

---

## Flutter / Dart

### Architecture

- `flutter_app/lib/main_controller.dart` is the single root `ChangeNotifier`. Do not introduce competing global state objects.
- Feature logic goes in `lib/src/<feature>_bridge.dart` or `lib/src/<feature>_service.dart`. Widgets are thin — no business logic in widget files.
- Platform-conditional code uses the established `_io` / `_web` / `_stub` file-suffix pattern in `lib/src/`. Do not use `kIsWeb` inline branches when a conditional export covers the case.

### State and side effects

- `ChangeNotifier` + `ListenableBuilder` / `addListener` is the state model. Do not add additional state management packages.
- Every `StreamSubscription` and listener stored as a field must be cancelled/removed in `dispose()`.

### Dart style

- Follow the rules in `flutter_app/analysis_options.yaml`.
- Prefer `final`. Use `late final` only when initialization is genuinely deferred.
- Use `const` constructors wherever the analyzer allows.
- Avoid `dynamic`. When interfacing with untyped data (JSON, JS interop), cast and validate at the boundary.

### Flutter web build

- Flutter web builds are handled separately as part of the release pipeline. Do not run `flutter build web` during normal development.
- For local development use the `flutter:run:web` npm script, which includes the required `--dart-define` flags.

---

## Chrome Extension

- ES module syntax (`.mjs` files) is used exclusively inside `extensions/chrome-browser/`.
- All backend communication must use the message protocol defined in `extensions/chrome-browser/protocol.mjs`. Adding a new message type requires updating both the extension and the backend gateway.

---

## Naming Conventions

| Context | Convention |
|---|---|
| JS filenames | `snake_case` |
| JS variables / functions | `camelCase` |
| JS classes | `PascalCase` |
| Dart filenames | `snake_case` |
| Dart classes / types | `UpperCamelCase` |
| Dart variables / functions | `lowerCamelCase` |
| Environment variables | `SCREAMING_SNAKE_CASE` |
| HTTP route paths | `kebab-case` |
| SQLite tables / columns | `snake_case` |

---

## Extension Recipes

### New integration

1. OAuth client, token storage, and refresh logic in `server/services/integrations/`.
2. Route file at `server/routes/<name>.js` — HTTP only, delegate to service.
3. Register the route in `server/http/routes.js`.
4. Add the env key(s) to `.env.example` with a descriptive comment.
5. Add boolean presence logging for the new keys in `logStartupConfig()` in `server/index.js`.

### New AI tool

1. Define the tool schema and handler in `server/services/ai/tools.js`.
2. Extract non-trivial logic into `server/services/ai/integrated_tools/` and import from there.
3. Ensure the tool result is passed through `compactToolResult()` if it can produce large payloads.

### New skill

1. Add the skill definition to `server/services/skills/base_catalog.js`.
2. If server-side execution is needed, implement it in `server/services/skills/runtime.js`.

---

## Hard Rules

- Do not import Anthropic, OpenAI, or Google AI SDKs outside of `server/services/ai/providers/`.
- Do not create additional SQLite database files. One DB, one instance.
- Do not commit `.env`, `data/`, `agent-data/`, or anything matched by `.gitignore`.
- Do not bypass git hooks with `--no-verify`.
- Do not run `flutter build web` outside the release pipeline.
