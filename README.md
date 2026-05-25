<p align="center">
  <img src="flutter_app/assets/branding/app_icon_128.png" width="80" alt="NeoAgent">
</p>

<h1 align="center">NeoAgent</h1>

<p align="center"><strong>Your agent. Your server. Your rules.</strong></p>

<p align="center">
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/Node.js-20+-5fa04e?style=flat-square&logo=node.js&logoColor=white" alt="Node.js"></a>
  <a href="https://sqlite.org"><img src="https://img.shields.io/badge/SQLite-WAL-003b57?style=flat-square&logo=sqlite&logoColor=white" alt="SQLite"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-web%20%2B%20android-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-a855f7?style=flat-square" alt="License"></a>
</p>

<p align="center">Self-hosted AI agent — runs as a system service, controls Android over ADB, connects to 15+ messaging platforms, all credentials on your server.</p>

<p align="center">
  <img src="demo.gif" alt="NeoAgent demo" width="100%">
</p>

| | | | |
| --- | --- | --- | --- |
| <img alt="WebUI" src="https://github.com/user-attachments/assets/3c76d59a-b6e3-4698-929b-9c94741ccf1e" height="420"> | <img height="494" alt="Android" src="https://github.com/user-attachments/assets/e8a0af7a-6881-485d-ad52-f3bc6f2023ca"> | <img alt="Mobile Telegram" src="https://github.com/user-attachments/assets/1fd41a9b-5452-4aa4-9478-888c8ad7363a" height="420"> | <img height="494" alt="image" src="https://github.com/user-attachments/assets/d5a57282-0851-4902-9588-d8de4b82d45c"> |

- **Android control** — screenshot, observe UI, tap, swipe, type, launch apps, install APKs, `adb shell` — the agent operates Android, not just an app running on it
- **15+ messaging platforms** — Telegram, WhatsApp, Discord, Signal, Slack, Matrix, iMessage, IRC, LINE, Mattermost, Telnyx Voice
- **Integrations** — Google Workspace, Microsoft 365, Notion, Home Assistant, Trello, Spotify, Figma
- **Browser + shell** — VM-isolated server-side browser automation, full PTY terminal
- **Runs locally** — Ollama support, no API key required; credentials stay in `~/.neoagent/.env`, never in the client

## Install

```bash
npm install -g neoagent
neoagent install
```

Available at **http://localhost:3333** when complete.

## Manage

```bash
neoagent status
neoagent update
neoagent fix
neoagent logs
```

## Links
<p align="center">
  [Docs](https://neolabs-systems.github.io/NeoAgent/docs/) | [Getting Started](docs/getting-started.md) | [Configuration](docs/configuration.md) | [Capabilities](docs/capabilities.md) | [Why NeoAgent](docs/why-neoagent.md) | [Issues](https://github.com/NeoLabs-Systems/NeoAgent/issues)
</p>

---

<p align="center">
  Made by <a href="https://github.com/neooriginal">Neo</a> | <a href="https://github.com/NeoLabs-Systems">NeoLabs Systems</a>
</p>
