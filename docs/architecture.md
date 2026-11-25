---
title: Architecture
sidebar_label: Architecture
description: How the server, clients, persistence layer, and execution runtimes fit together.
---

# Architecture

**One Go service owns accounts, agents, tools, memory and automation; every app, chat platform and device is a client of it.**

```text
Clients    Flutter apps · messaging platforms · task webhooks · wearable
   │
Edge       HTTP routes · Socket.IO · WebSocket gateways
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
| `cmd/neoagent/` | The `neoagent` binary: the server (`neoagent serve`) and the CLI |
| `cmd/neoagent-guest/` | HTTP agent that runs inside the cloud computer |
| `cmd/neoagent-release/` | Release tooling: runtime archives, signed manifests, setup contract |
| `internal/httpserver/` | Security headers, origin checks, static clients, error pages |
| `internal/wiring/` | Builds every domain once and connects them; mounts the routes |
| `internal/<domain>/` | One package per domain: routes and business logic |
| `internal/schema/` | SQLite base schema and ordered migration steps |
| `internal/manager/` | CLI commands: install, update, service, backup |
| `flutter_app/` | Flutter client for web, Android, macOS, Windows and Linux |
| `public/` | The built web client, served at `/app` |
| `firmware/` | ESP32-S3 wearable firmware (ESP-IDF) |
| `landing/` | Landing page at `/` and status page at `/status` |
| `website/` | Docusaurus site for these docs |
| `test/flutter/` | Flutter unit and widget tests; Go tests sit next to their packages |

Shared building blocks (sessions, sign-in, sealed secrets, rate limits, SSRF-safe HTTP, LLM clients, the CLI shell) come from the [`neolabs-go`](https://github.com/NeoLabs-Systems/neolabs-go) module.

## Startup sequence

1. **Environment.** `NEOAGENT_HOME/.env` fills in what the real environment does not set; `internal/config` reads the result and creates the runtime directories.
2. **Sessions.** `data/sessions.db` opens as the HTTP session store.
3. **Database.** `data/neoagent.db` opens and `internal/schema` applies pending migrations.
4. **Services.** `wiring.Build` creates each long-lived service once and connects them through small interfaces.
5. **Listen.** The HTTP server, Socket.IO and the WebSocket gateways listen on `PORT` (default `3333`).
6. **Start.** `App.Start` restores messaging and MCP connections, starts the task runtime and resumes interrupted runs.

## Service graph

`wiring.Build` creates each long-lived service once.

| Service | Package (`internal/`) | Owns |
|---|---|---|
| Agent engine | `agent`, `ai`, `runledger` | Agent runs, subagents, delegation, delivery |
| Runtime manager | `runtime`, `desktop` | Cloud and local computers, control leases |
| Android | `android` | Android emulators and devices over ADB |
| Task runtime | `tasks`, `triggers` | Schedules, triggers, task runs and result delivery |
| Messaging manager | `messaging`, `sharedmessaging` | Messaging platform adapters and the inbound queue |
| Integration manager | `integrations` | Official integrations, OAuth, integration tools |
| Memory | `memory` | Memories, facts, recall, core memory, ingestion from connected accounts |
| MCP client | `mcpserver` | Remote MCP server connections and their tools |
| Skills | `skills`, `skilllearning` | Skills from `agent-data/skills`, skills learned from runs |
| Security | `security`, `securityapi` | Tool permissions and approval prompts |
| Credential broker | `credentials` | Bitwarden-backed credential use |
| Voice | `voice` | Live voice sessions |
| Wearable | `wearable` | Wearable sessions and firmware updates |
| Teach Mode | `teach` | Teach Mode recordings |

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

- **Database.** One SQLite file, `data/neoagent.db`, opened once; HTTP sessions use `data/sessions.db`.
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
