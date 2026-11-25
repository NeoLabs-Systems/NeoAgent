# NeoAgent — Engineering Guidelines

## Project Overview

NeoAgent is a Go backend + Flutter frontend personal AI agent. It supports multiple AI providers, SQLite storage, socket.io real-time communication, and integrations with WhatsApp, Discord, Telegram, Google, Microsoft, Slack, Figma, Notion, and more.

Generic building blocks shared by the NeoLabs apps (sessions, auth, sealed secrets, rate limits, SSRF-safe HTTP, LLM provider clients, the CLI shell, realtime) live in the separate module [`github.com/NeoLabs-Systems/neolabs-go`](https://github.com/NeoLabs-Systems/neolabs-go). NeoAgent-specific code (its tables, routes, prompts, tools) lives here.

### Directory Map

```
cmd/
  neoagent/          The single binary: server (`neoagent serve`) and CLI (install, update, ...)
  neoagent-guest/    Agent that runs inside each cloud computer (Linux)
  neoagent-release/  Release tooling used by CI (runtime archives, manifests, setup contract)
internal/
  config/            Environment and paths (NEOAGENT_HOME, data dir, web dir)
  schema/            The database schema: baseline.sql plus ordered Go steps
  httpserver/        HTTP server, security headers, origin checks, static clients
  wiring/            Builds every domain and connects them through small interfaces
  agent/             Agent runs: orchestration, delivery, resume, sub-agents
  ai/                The agent loop, prompts, tool definitions, models, compaction
    handlers/        Tool implementations
  <domain>/          One package per feature domain (memory, tasks, messaging, ...)
flutter_app/         Cross-platform Flutter client (web, Android, iOS, macOS, Windows, Linux)
public/              Flutter web build output, served at /app (generated)
landing/             Static landing page
website/             Docusaurus site that renders docs/
docs/                User and developer documentation
firmware/            ESP32 wearable firmware
```

---

## Core Principles

- **No duplication.** Before adding a helper, search the domain package, `internal/`, and `neolabs-go`. Reuse what exists.
- **No premature abstraction.** Three similar lines is fine. Abstract only when a fourth copy would appear.
- **No speculative features.** Implement exactly what the task requires. No extra fallbacks, feature flags, or backwards-compat shims for callers that don't yet exist.
- **No dead code.** Remove unused functions, variables, and branches. Do not leave commented-out blocks behind.
- **Readable over clever.** Prefer direct, boring code.
- **Generic goes to the foundation.** If a building block knows nothing about NeoAgent's schema or product, it belongs in `neolabs-go` (with tests) so the other apps can use it.

---

## Go / Server

### Packages

- One package per domain under `internal/`. A domain exposes `New(Config)` (dependencies as fields, no globals, no `init()` side effects), `Routes(mux *http.ServeMux)` with Go 1.22 patterns such as `"GET /api/memory/memories"`, and optional `Start(ctx)` / `Stop()` for background work.
- **Domains do not import each other.** A domain that needs another one declares the narrow interface it uses in its own package (consumer side); `internal/wiring` satisfies it. Keep `cmd/neoagent` thin: it builds config and calls `wiring.Build`.
- Handlers handle HTTP only: parse the request, call the service, write the response with `httpx.WriteJSON`. Business logic lives in the service.
- Split files that grow past ~400 lines along real seams.

### API compatibility

- The Flutter client, wearables, and existing installs depend on the API: keep routes, status codes, error texts, key order, `null` versus omitted keys, and date formats stable. Error texts are part of the contract (staticcheck ST1005 is off for that reason).
- Every request that changes behaviour visible to clients needs a test that pins the response.

### Database

- One SQLite database (`modernc.org/sqlite`, pure Go), opened once through `dbx`. Never open a second handle to the same file from a domain.
- All queries use parameters. No string interpolation into SQL.
- The schema is `internal/schema/baseline.sql` plus ordered steps in `schema.Steps()`. A schema change is a new step; never edit the baseline or create tables inline in a domain.
- Opening a database runs the steps. Tests use a temp `NEOAGENT_HOME`; never point tests or tools at `~/.neoagent`.

### AI / LLM

- All model calls go through the `neolabs-go/llm` provider clients via `internal/ai/models`. Do not call provider APIs from routes or other domains.
- Tool schemas and metadata live in `internal/ai/tools/definitions.json`; implementations in `internal/ai/handlers`. Do not keep lists of tool names elsewhere: scheduling, repeat detection, trust, budgets, and the security policy read the tool metadata.
- Large tool results go through the result compaction in `internal/ai` before they enter the transcript.
- Everything a run shows a user goes through the delivery ledger in `internal/agent`. A new path that sends a message reserves a delivery slot there; do not add delivered-yet flags.
- Prompt text lives in `internal/ai/prompts/` as versioned fragments. Changing a fragment's text means bumping its version.
- Run telemetry carries metadata only: no prompt text, tool results, memory content, or private reasoning.
- One model, one loop. Do not add pre-passes, planner or critic model calls, or LLM routers. All user-facing agent text is model-authored: no canned status lines or templates. A harness change has to earn its place by raising task success or lowering latency, tokens, unnecessary tool calls, or errors.

### Error handling

- Validate at system boundaries: request bodies, external API responses, user-supplied env values. Do not defensively validate arguments passed between internal functions.
- Return errors with context (`fmt.Errorf("memory: recall: %w", err)`); log once, where the error is handled, with `slog`.
- Errors shown to non-admins pass through `publicerr` (installed globally).

### Security

- Secrets are sealed at rest with `secretbox`; store token digests, not tokens; compare secrets in constant time.
- Every outbound request a user or the model can influence goes through `neolabs-go/ssrf`.
- Paths from users are confined with `os.Root`. Data directories are 0700, files 0600.
- Never log secrets, tokens, or PII. Log boolean presence in startup diagnostics.
- No shelling out with unsanitised input.
- CORS and origin validation go through `internal/httpserver`. No ad-hoc bypasses.

### Environment & paths

- Read configuration through `internal/config`. Never hardcode `~/.neoagent` or absolute system paths.

### Tests

- `gofmt`, `go vet ./...`, `staticcheck ./...`, and `go test -race ./...` must pass (CI runs them).
- Use a real temp SQLite (`dbx.Open` + `schema.Ensure`) and `httptest`, not mocks of the database.
- Table-driven tests for behaviour; recorded scenarios (testdata JSON) for API responses and byte-exact texts.

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
- Do not run `dart format` on whole files: parts of the codebase are intentionally unformatted.

### Flutter web build

- Flutter web builds are handled by the maintainer and the release pipeline. Do not run `flutter build web` during normal development.
- For local development run the client against a local server: `cd flutter_app && flutter run -d chrome --dart-define=NEOAGENT_BACKEND_URL=http://localhost:3333`.

---

## Naming Conventions

| Context | Convention |
|---|---|
| Go packages | short, lowercase, no underscores (`memory`, `socialreach`) |
| Go files | `snake_case.go` |
| Go identifiers | `camelCase` / `PascalCase` for exported |
| Dart filenames | `snake_case` |
| Dart classes / types | `UpperCamelCase` |
| Dart variables / functions | `lowerCamelCase` |
| Environment variables | `SCREAMING_SNAKE_CASE` |
| HTTP route paths | `kebab-case` |
| SQLite tables / columns | `snake_case` |

---

## Extension Recipes

### New integration

1. A package `internal/integrations/<name>/` implementing the provider interface in `internal/integrations` (spec, connection, tools). OAuth and token refresh use the shared integration OAuth helpers.
2. Register the provider in `internal/wiring`.
3. Add the env key(s) to `.env.example` with a descriptive comment.

### New AI tool

1. Add the schema and metadata to `internal/ai/tools/definitions.json`: at least `group`, `access`, and `capabilities`, plus `policy`, `stateScope`, `sideEffect`, `repeatable`, and `untrusted` where the defaults do not hold. Give it `whenToUse` / `whenNotToUse` if a neighbouring tool is easy to confuse it with.
2. Implement it in `internal/ai/handlers`, calling the owning domain through its interface.
3. Make sure large results pass through result compaction.

---

## Hard Rules

- Do not call AI provider APIs outside `neolabs-go/llm` and `internal/ai/models`.
- Do not create additional SQLite database files. One DB, one handle.
- Do not commit `.env`, `data/`, `agent-data/`, or anything matched by `.gitignore`.
- Do not bypass git hooks with `--no-verify`.
- Do not run `flutter build web` outside the release pipeline.
- Do not edit `README.md` layout; it stays visual.
- Do not create `CHANGELOG.md`; GitHub Releases are the canonical release history.
