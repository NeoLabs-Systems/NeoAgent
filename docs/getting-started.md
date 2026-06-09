# Getting Started

Install takes about 5 minutes. The first VM boot downloads and configures an Ubuntu guest image, which adds a few more minutes on first run.

## Requirements

| | |
|---|---|
| Node.js | 20 or newer |
| QEMU | installed automatically when supported; used for VM-isolated browser and Android |
| AI provider key | Anthropic, OpenAI, Gemini, Grok, MiniMax, or local Ollama |

No API key is required if you only use local Ollama.

### Optional manual QEMU install

`neoagent install` tries to install QEMU on supported macOS and Linux package
managers. If the machine does not have a supported package manager yet, install
QEMU manually and rerun `neoagent install`.

```bash
# macOS
brew install qemu

# Ubuntu / Debian
sudo apt-get update && sudo apt-get install -y qemu-system qemu-utils
```

## Install

```bash
npm install -g neoagent
neoagent install
```

This runs a preflight, creates or updates config, installs dependencies, builds
or uses the bundled web client, starts the service, and prints any remaining
machine-specific action items.

Open **http://localhost:3333** in your browser when the install finishes.

## First Run

1. Create an account.
2. Open **Settings → AI Providers** and add at least one API key.
3. Send a message in **Chat** to confirm the agent responds.

Everything else — integrations, messaging, tasks, Android control — is configured inside the app.

## Service Commands

```bash
neoagent status      # check install root, config path, and service state
neoagent start
neoagent stop
neoagent restart
neoagent logs        # first stop when something behaves unexpectedly
```

## Re-running Setup

Run this to regenerate config or change provider keys:

```bash
neoagent setup
```

The wizard prompts for port, public URL, release channel, AI keys, Ollama URL, and OAuth credentials.

## Updates and Recovery

```bash
neoagent channel stable   # switch to stable releases
neoagent channel beta     # switch to prerelease builds
neoagent update           # update to latest on the current channel
neoagent fix              # reset after a broken install or self-edit
```

`neoagent fix` backs up runtime data, resets source files, reinstalls dependencies, and restarts the service. Use it when `neoagent setup && neoagent restart` hasn't resolved an issue.

## Runtime Paths

| Path | Contents |
|---|---|
| `~/.neoagent/.env` | Server config and secrets |
| `~/.neoagent/data/` | Database, session data, logs |
| `~/.neoagent/agent-data/` | Skills, memory, daily data |

Set `NEOAGENT_HOME` to move the runtime root.
