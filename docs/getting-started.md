# Getting Started

NeoAgent installs as a Node CLI and runs a self-hosted server with a bundled Flutter web client. The same server can be reached from the Android client when you point it at the deployed backend URL.

## Requirements

- Node.js 20 or newer.
- A reachable server URL if you want OAuth callbacks, mobile access, or messaging webhooks.
- At least one hosted AI provider API key, unless you only use local Ollama.
- Android Studio or a Flutter Android toolchain if you build the Android client yourself.

## Install

```bash
npm install -g neoagent
neoagent install
```

`neoagent install` runs setup if `~/.neoagent/.env` does not exist, installs dependencies, builds or verifies the bundled web client, and starts the service through the host service manager when available.

On macOS, NeoAgent uses a `launchd` user service. On Linux, it uses a `systemd --user` service. On unsupported platforms it falls back to a background Node process.

## Setup

Run setup again whenever you need to regenerate server config:

```bash
neoagent setup
```

The setup flow asks for the server port, public URL, release channel, AI provider keys, Ollama URL, and official integration OAuth settings. Provider credentials live in server-side config, not in the web client.

## Service Commands

```bash
neoagent status
neoagent start
neoagent stop
neoagent restart
neoagent logs
```

Use `neoagent status` to confirm the install root, config path, release channel, and service state. Use `neoagent logs` when the service starts but the UI or integrations do not behave as expected.

## Updates And Recovery

```bash
neoagent channel stable
neoagent channel beta
neoagent update
neoagent fix
```

`neoagent update` follows the configured release channel. `neoagent fix` is for recovery after a self-edit or broken local install. On git installs it backs up runtime data, saves local tracked changes, resets tracked source files, reinstalls dependencies, and restarts the service.

## Runtime Paths

| Path | Purpose |
|---|---|
| `~/.neoagent/.env` | Server config and secrets |
| `~/.neoagent/data/` | Database, sessions, update status, and logs |
| `~/.neoagent/agent-data/` | Skills, memory, and daily data files |

Set `NEOAGENT_HOME` if you need to move the runtime root.
