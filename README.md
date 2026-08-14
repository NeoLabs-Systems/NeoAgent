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
  <a href="https://www.npmjs.com/package/neoagent"><img src="https://img.shields.io/npm/v/neoagent?style=flat-square&label=npm" alt="npm version"></a>
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/Node.js-20%2B-5fa04e?style=flat-square" alt="Node.js 20 or newer"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-a855f7?style=flat-square" alt="AGPL-3.0 license"></a>
</p>

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

The NeoAgent desktop app installs and starts the backend on macOS, Windows, and
Linux without a terminal, Node.js, npm, Git, Docker, or a manually entered
server address. Choose **Quickstart** for safe automatic defaults or **Full
setup** to continue through providers, integrations, voice, and optional tools.

<p align="center">
  <a href="https://github.com/NeoLabs-Systems/NeoAgent/releases/latest"><img alt="Download NeoAgent" src="https://img.shields.io/badge/Desktop_and_CLI-download-black?style=flat-square"></a>
</p>

The same releases contain standalone `neoagent` CLI executables. They include
their own Node runtime and verify the backend package before installing it:

```bash
neoagent
```

The npm distribution remains available for existing Node.js installations:

```bash
npm install -g neoagent
neoagent setup --quick
```

The first account is protected by a short-lived one-time setup claim. The app
connects to the actual selected port automatically; nearby NeoAgent servers are
discovered and verified on the local network. The CLI downloads the signed
QEMU runtime, firmware, and guest image used for
the isolated cloud computer; no separate VM product is required.

Read the [installation guide](docs/getting-started.md) before exposing the
service to a network.

## ✨ What makes it different

- **It is a service, not just a chat window.** NeoAgent keeps tasks, integrations, memory, connected devices, and messaging channels available between sessions.
- **Memory is stored as structured local data.** Durable facts are separated from conversation history, scoped by user and agent, and updated when newer information replaces older information. NeoAgent can also index supported integration content with source references. See [How memory works](docs/memory.md).
- **It operates real devices.** The agent uses one persistent Linux cloud computer or, with explicit per-capability permission in the desktop app, the local macOS/Windows/Linux session for browser, desktop, files, and shell work. Android devices or emulators remain available over ADB.
- **Automation can start without a message.** Tasks can run on a schedule or from supported Gmail, Outlook, Slack, Teams, personal WhatsApp, and weather events. Android notifications can also start an agent run.
- **Agents and users have separate state.** Specialist agents can have their own memory, settings, tools, account assignments, conversations, and task history. Multi-user deployments include administrative account controls and optional email confirmation.
- **SaaS billing is built in and off by default.** Set `NEOAGENT_BILLING_ENABLED=true` to activate Stripe subscriptions, plan management, free trials, and model access restrictions. When disabled, no payment routes or UI appear anywhere. See [Billing](docs/billing.md).
- **The same server has several interfaces.** NeoAgent includes web, Android, desktop, and Android launcher clients, messaging bridges, and firmware for a supported ESP32-S3 wearable.

## 🖥️ Interfaces

| Operator interface | Memory | Remote devices |
| --- | --- | --- |
| ![NeoAgent dashboard](landing/images/dashboard-dark.png) | ![NeoAgent memory view](landing/images/memory-dark.png) | ![NeoAgent device controls](landing/images/remote-devices-dark.png) |

## 🔎 NeoAgent, OpenClaw, and Hermes

NeoAgent is aimed at people who want a UI-first, self-hosted agent with
structured local memory, multi-user administration, automation, and direct
Android control in one installation.

OpenClaw has a broader gateway and node ecosystem. Hermes is oriented around a
terminal-first agent workflow. NeoAgent is a different tradeoff rather than a
blanket replacement for either project.

The [comparison page](docs/why-neoagent.md) records the concrete differences
and links to the source material used.

## 🧪 Project status

NeoAgent is beta software maintained primarily by one person. Expect breaking
changes and rough edges. Review the
[security boundaries](docs/security-boundaries.md) before connecting sensitive
accounts or giving the agent access to a personal workstation.

Start with the [documentation](https://neolabs-systems.github.io/NeoAgent/docs/).
Use [GitHub Discussions](https://github.com/NeoLabs-Systems/NeoAgent/discussions)
for questions and [GitHub Issues](https://github.com/NeoLabs-Systems/NeoAgent/issues)
for reproducible bugs. Security reports belong in the process described by
[SECURITY.md](SECURITY.md).

## License

NeoAgent is licensed under the
[GNU Affero General Public License v3.0 only](LICENSE). The
[licensing decision](docs/licensing.md) explains why AGPL remains the fit for
this networked, self-hosted project and compares it with MPL-2.0.

*Made with ❤️ by [Neo](https://github.com/neooriginal) · [NeoLabs Systems](https://github.com/NeoLabs-Systems)*
