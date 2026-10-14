---
title: Architecture
sidebar_label: Architecture
description: How the server, clients, persistence layer, and execution runtimes fit together.
---

# Architecture

**One Node.js service owns accounts, agents, tools, memory and automation; every app, chat platform and device is a client of it.**

```text
Clients    Flutter apps · messaging platforms · task webhooks · wearable
   │
Edge       Express routes · Socket.IO · WebSocket gateways
   │
Services   agent engine · tasks · integrations · messaging · memory · voice
   │
Runtimes   cloud computer · desktop companion · Android over ADB · MCP servers
   │
State      SQLite and files under NEOAGENT_HOME
```

## Repository layout

| Path | Contents |
|---|---|
| `server/index.js` | Entry point: HTTP server, Socket.IO, gateways, service startup |
| `server/http/` | Middleware, route table (`routes.js`), Socket.IO setup, static files, error handler |
| `server/routes/` | One thin Express router per domain |
| `server/services/` | Business logic, one directory per domain |
| `server/db/` | SQLite connection, base schema, HTTP session store |
| `server/guest_agent.js` | HTTP agent that runs inside the cloud computer |
| `lib/` | `neoagent` CLI (`manager.js`, `cli/`), setup engine (`setup/`), schema migrations |
| `runtime/` | Runtime paths, env parsing, release channel |
| `bin/` | `neoagent.js` (CLI) and `neoagent-bootstrap.js` (standalone CLI entry) |
| `flutter_app/` | Flutter client for web, Android, macOS, Windows and Linux |
| `firmware/` | ESP32-S3 wearable firmware (ESP-IDF) |
| `landing/` | Landing page at `/` and status page at `/status` |
| `scripts/` | Release, runtime staging and signing helpers |
| `test/` | Backend, security, contract, e2e, WebSocket, Flutter and install tests |

## Startup sequence

1. **Runtime home.** `runtime/paths.js` sets a private umask, migrates legacy in-repo data and creates the runtime directories.
2. **Environment.** dotenv loads the checkout's `.env`, then `NEOAGENT_HOME/.env` with override.
3. **Database.** `server/db/database.js` opens SQLite, applies migrations and marks runs left by a dead process as interrupted.
4. **HTTP edge.** Middleware, session store, Socket.IO, API routes, static routes and the error handler are registered.
5. **Gateways.** The display, desktop-companion and wearable WebSocket gateways attach to the HTTP server.
6. **Listen.** The server listens on `PORT` (default `3333`), then calls `startServices()`.
7. **Services.** `server/services/manager.js` builds the service graph, restores messaging and MCP connections, starts the task runtime and resumes interrupted runs.

## Service graph

`startServices()` creates each long-lived service once and stores it on `app.locals`.

| `app.locals` key | Module (`server/services/`) | Owns |
|---|---|---|
| `agentEngine` | `ai/engine.js` | Agent runs, subagents, delegation |
| `runtimeManager` | `runtime/manager.js` | Cloud and local computers, control leases, Android controllers |
| `taskRuntime` | `tasks/runtime.js` | Schedules, triggers, task runs and result delivery |
| `messagingManager` | `messaging/manager.js` | Messaging platform adapters and the inbound queue |
| `integrationManager` | `integrations/manager.js` | Official integrations, OAuth, integration tools |
| `memoryManager` | `memory/manager.js` | Memories, facts, recall, core memory |
| `memoryIngestionService` | `memory/ingestion.js` | Background ingestion from connected accounts |
| `mcpClient` | `mcp/client.js` | Remote MCP server connections and their tools |
| `skillRunner` | `ai/toolRunner.js` | Skills loaded from `agent-data/skills` |
| `skillLearningService` | `skills/learning_service.js` | Skills learned from completed runs |
| `toolPolicyService`, `approvalGateService` | `security/` | Tool permissions and approval prompts |
| `credentialBroker` | `credentials/broker.js` | Bitwarden-backed credential use |
| `voiceRuntimeManager` | `voice/runtimeManager.js` | Live voice sessions |
| `wearableService` | `wearable/service.js` | Wearable sessions and firmware updates |
| `teachService` | `teach/service.js` | Teach Mode recordings |

## Real-time channels

| Channel | Path | Carries |
|---|---|---|
| Socket.IO | `/socket.io` | `run:*`, `tool:approval_*`, `tasks:*`, `messaging:*`, `voice:*`, `computer:status` |
| Display gateway | `/api/computer/display-ws` | noVNC stream of the cloud computer |
| Desktop companion | `/api/computer/local/ws` | Commands to a desktop app acting as the computer |
| Wearable gateway | `/api/wearable/ws` | Push-to-talk voice for the ESP32-S3 wearable |

- **Session-bound.** Every channel authenticates with the HTTP session cookie.
- **Per-user rooms.** Socket.IO emits into `user:<id>`, so one account never sees another's events.

## Execution backends

Each user picks a computer provider (`computer_provider` in `user_settings`); the server picks the cloud backend with `TERMINAL_ENV`.

| Provider | Backend | Isolation |
|---|---|---|
| `cloud` | `TERMINAL_ENV=qemu` (default): persistent Debian VM per user | VM; needs KVM, HVF or WHPX |
| `cloud` | `TERMINAL_ENV=docker`: per-user container with a named home volume | Container |
| `cloud` | `TERMINAL_ENV=host`: the server's own OS session | None |
| `local` | Desktop companion: a signed-in macOS, Windows or Linux app | The user's own machine |

- **Android.** A separate per-user controller drives emulators or devices over ADB on the server host.
- **MCP.** Only remote `http(s)` MCP servers are accepted; local stdio servers are disabled.

## State

- **Database.** One SQLite file, `data/neoagent.db`, through `server/db/database.js`; HTTP sessions use `data/sessions.db`.
- **Files.** Skills, workspaces, artifacts and computer disks live under `NEOAGENT_HOME` (default `~/.neoagent`).
- **Details.** See [Persistence and migrations](persistence.md).

## Subsystem guides

- [Agent run lifecycle](agent-run-lifecycle.md)
- [Memory architecture](memory-architecture.md)
- [Runtime and tool execution](runtime-and-tools.md)
- [Agents, automation, and triggers](automation-architecture.md)
- [Integrations and messaging](integrations-architecture.md)
- [Clients and device bridges](clients-and-devices.md)
- [Persistence and migrations](persistence.md)
- [Runtime packaging and trust](runtime-packaging.md)
- [Development and testing](development.md)
