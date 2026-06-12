<p align="center">
  <img src="flutter_app/assets/branding/app_icon_128.png" width="80" alt="NeoAgent">
</p>

<h1 align="center">NeoAgent</h1>

<p align="center"><strong>Your agent. Your server. Your rules.</strong></p>

<p align="center">A self-hosted AI agent that runs as a service, operates Android over ADB, and connects to 15+ messaging platforms while keeping credentials on your server.</p>

<p align="center">
  <a href="https://www.npmjs.com/package/neoagent"><img src="https://img.shields.io/npm/v/neoagent?style=flat-square&label=npm" alt="npm version"></a>
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/Node.js-20+-5fa04e?style=flat-square&logo=node.js&logoColor=white" alt="Node.js"></a>
  <a href="https://sqlite.org"><img src="https://img.shields.io/badge/SQLite-WAL-003b57?style=flat-square&logo=sqlite&logoColor=white" alt="SQLite"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-web%20%2B%20android-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-a855f7?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <img src="demo.gif" alt="NeoAgent demo" width="100%">
</p>

## Why NeoAgent

| Android that the agent can operate | Credentials that stay server-side |
| --- | --- |
| NeoAgent can inspect the UI, take screenshots, tap, swipe, type, launch apps, install APKs, and run `adb shell` against a connected device or emulator. | API keys, OAuth tokens, messaging credentials, history, and runtime data are stored under `~/.neoagent` on the server, never in the client. |

## Quick Start

Requires Node.js 20 or newer.

```bash
npm install -g neoagent
neoagent install
```

`neoagent install` checks the host, creates secure runtime configuration,
installs dependencies and supported system tools, and starts the service. Open
**http://localhost:3333** when it finishes.

No hosted-model key is required when using local [Ollama](https://ollama.com/).
See [Getting Started](docs/getting-started.md) for prerequisites and first-run
setup.

## What It Does

- **15+ messaging platforms**: Telegram, WhatsApp, Discord, Signal, Slack, Matrix, iMessage, Teams, IRC, LINE, Mattermost, Telnyx Voice, and webhook bridges.
- **Automation**: cron schedules, integration and weather triggers, reusable skills, MCP tools, and subagents.
- **Browser and shell**: an isolated browser runtime plus a full PTY terminal on the NeoAgent server.
- **Integrations**: Google Workspace, Microsoft 365, Notion, Home Assistant, Trello, Spotify, Slack, Figma, GitHub, and more.
- **Recordings and memory**: audio capture, transcription, transcript search, long-term memory, session history, and health summaries.
- **Model choice**: Anthropic, OpenAI, Gemini, Grok, MiniMax, NVIDIA NIM, OpenRouter, GitHub Copilot, OpenAI Codex, or local Ollama.

## Interfaces

| | | | |
| --- | --- | --- | --- |
| <img alt="WebUI" src="https://github.com/user-attachments/assets/3c76d59a-b6e3-4698-929b-9c94741ccf1e" height="420"> | <img height="494" alt="Android" src="https://github.com/user-attachments/assets/e8a0af7a-6881-485d-ad52-f3bc6f2023ca"> | <img alt="Mobile Telegram" src="https://github.com/user-attachments/assets/1fd41a9b-5452-4aa4-9478-888c8ad7363a" height="420"> | <img height="494" alt="image" src="https://github.com/user-attachments/assets/d5a57282-0851-4902-9588-d8de4b82d45c"> |

## Service Commands

```bash
neoagent status
neoagent start
neoagent stop
neoagent restart
neoagent update
neoagent fix
neoagent logs
```

## Project Status

NeoAgent is beta software maintained by one person. Expect rough edges, and
please report failures with enough detail to reproduce them. Contributions to
the backend, Flutter clients, integrations, skills, tests, and documentation
are welcome.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Security
issues should be reported privately according to [SECURITY.md](SECURITY.md).

## Documentation

[Docs](https://neolabs-systems.github.io/NeoAgent/docs/) | [Getting Started](docs/getting-started.md) | [Configuration](docs/configuration.md) | [Capabilities](docs/capabilities.md) | [Skills and MCP](docs/skills.md) | [Operations](docs/operations.md) | [Discussions](https://github.com/NeoLabs-Systems/NeoAgent/discussions) | [Issues](https://github.com/NeoLabs-Systems/NeoAgent/issues)

---

<p align="center">
  Made by <a href="https://github.com/neooriginal">Neo</a> | <a href="https://github.com/NeoLabs-Systems">NeoLabs Systems</a>
</p>
