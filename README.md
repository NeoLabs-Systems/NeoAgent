<p align="center">
  <img src="marketing/final/github-banner.png" alt="NeoAgent — an AI assistant that keeps working" width="100%">
</p>

<h1 align="center">NeoAgent</h1>

<p align="center"><strong>A self-hosted AI agent that can keep working after the chat ends.</strong></p>

<p align="center">
  NeoAgent runs as a service on your server. It can use a browser and terminal,
  control Android devices, connect to your accounts, remember useful context,
  and run scheduled or event-triggered work.
</p>

<p align="center">
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/Node.js-20%2B-5fa04e?style=flat-square" alt="Node.js 20 or newer"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-a855f7?style=flat-square" alt="AGPL-3.0 license"></a>
</p>

> [!IMPORTANT]
> **npm distribution has been shut down.** Install NeoAgent directly from GitHub using the desktop app, standalone CLI, or repository installer below.

<p align="center">
  <a href="https://discord.gg/f59rg2RwUT"><img src="https://img.shields.io/badge/Join%20NeoLabs-Discord-5865F2?style=for-the-badge&amp;logo=discord&amp;logoColor=white" alt="Join the NeoLabs Discord"></a>
</p>

<p align="center">
  <a href="https://github.com/NeoLabs-Systems/NeoAgent/releases/latest"><img alt="Android" src="https://img.shields.io/badge/Android-APK-3ddc84?style=flat-square&logo=android&logoColor=white"></a>
  <a href="https://github.com/NeoLabs-Systems/NeoAgent/releases/latest"><img alt="iOS" src="https://img.shields.io/badge/iOS-coming_soon-lightgrey?style=flat-square&logo=apple&logoColor=white"></a>
  <a href="https://github.com/NeoLabs-Systems/NeoAgent/releases/latest"><img alt="Windows" src="https://img.shields.io/badge/Windows-EXE-0078d4?style=flat-square&logo=windows&logoColor=white"></a>
</p>

<p align="center">
  <a href="https://www.producthunt.com/products/neoagent-2?embed=true&utm_source=badge-featured&utm_medium=badge&utm_campaign=badge-neoagent-2" target="_blank" rel="noopener noreferrer"><img alt="NeoAgent - The next-gen self-hosted AI agent that works beyond chat | Product Hunt" width="250" height="54" src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1171573&theme=light&t=1781447653039"></a>
</p>

<p align="center">
  <img src="marketing/final/trailer.gif" alt="NeoAgent trailer" width="100%">
</p>

<p align="center">
  <img src="demo.gif" alt="NeoAgent demo" width="100%">
</p>

## 🚀 Install

**Desktop app** — installs and starts everything on macOS, Windows, and Linux.
No terminal, Node.js, npm, Git, or Docker needed. **Quickstart** picks safe
defaults; **Full setup** adds providers, integrations, voice, and tools.

<p align="center">
  <a href="https://github.com/NeoLabs-Systems/NeoAgent/releases/latest"><img alt="Download NeoAgent" src="https://img.shields.io/badge/Desktop_and_CLI-download-black?style=flat-square"></a>
</p>

**Standalone CLI** — in the same releases, with its own bundled Node runtime:

```bash
neoagent
```

**Repository installer** — clones NeoAgent directly from GitHub (requires Git,
Node.js 20+, and npm for dependencies):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/install.sh)
```

Good to know:

- The first account is protected by a short-lived one-time setup claim.
- The app finds the server's port automatically and discovers nearby NeoAgent servers on the local network.
- The CLI downloads the signed QEMU runtime, firmware, and guest image for the isolated cloud computer — no separate VM product.
- Read the [installation guide](docs/getting-started.md) before exposing the service to a network.

## ✨ What makes it different

- **Runs as a service.** Tasks, memory, integrations, devices, and messaging channels stay live between sessions.
- **Structured local memory.** Durable facts kept apart from chat history, scoped per user and agent. See [How memory works](docs/memory.md).
- **Operates real devices.** A persistent Linux cloud computer, optionally your own desktop (per-capability opt-in), and Android over ADB.
- **Automation without a message.** Schedules, plus Gmail, Outlook, Slack, Teams, WhatsApp, weather, and Android-notification triggers.
- **Multi-user and multi-agent.** Specialist agents with their own memory, tools, and history; admin controls for deployments.
- **Optional SaaS billing.** Stripe subscriptions behind `NEOAGENT_BILLING_ENABLED=true` — invisible when off. See [Billing](docs/billing.md).
- **Many interfaces, one server.** Web, Android, desktop, and launcher clients, messaging bridges, and ESP32-S3 wearable firmware.

## 🖥️ Interfaces

| Operator interface | Memory | Remote devices |
| --- | --- | --- |
| ![NeoAgent dashboard](landing/images/dashboard-dark.png) | ![NeoAgent memory view](landing/images/memory-dark.png) | ![NeoAgent device controls](landing/images/remote-devices-dark.png) |

## 🔎 NeoAgent, OpenClaw, and Hermes

| Project | Strength |
| --- | --- |
| **NeoAgent** | UI-first, structured memory, multi-user, automation, Android control — one install |
| **OpenClaw** | Broader gateway and node ecosystem |
| **Hermes** | Terminal-first agent workflow |

Different tradeoffs, not drop-in replacements. Switching anyway?
`neoagent migrate` [imports](docs/migration.md) skills, memory, and API keys
from both. The [comparison page](docs/why-neoagent.md) records the concrete
differences with sources.

## 🧪 Project status

Beta software, maintained primarily by one person — expect breaking changes
and rough edges. Review the
[security boundaries](docs/security-boundaries.md) before connecting sensitive
accounts.

- 📚 [Documentation](https://neolabs-systems.github.io/NeoAgent/docs/)
- 💬 [Discussions](https://github.com/NeoLabs-Systems/NeoAgent/discussions) for questions
- 🐛 [Issues](https://github.com/NeoLabs-Systems/NeoAgent/issues) for reproducible bugs
- 🔒 [SECURITY.md](SECURITY.md) for vulnerability reports

## License

[AGPL-3.0-only](LICENSE) — the [licensing decision](docs/licensing.md)
explains why.

*Made with ❤️ by [Neo](https://github.com/neooriginal) · [NeoLabs Systems](https://github.com/NeoLabs-Systems)*
