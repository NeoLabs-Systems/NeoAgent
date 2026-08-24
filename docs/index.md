---
slug: /
title: NeoAgent documentation
sidebar_label: Overview
---

# NeoAgent documentation

NeoAgent is a self-hosted AI agent that runs continuously on a macOS or Linux
server. It provides an operator interface for chat, automation, integrations,
memory, and connected devices.

NeoAgent is beta software. Install it on a machine you administer, start with
restricted tool permissions, and read the security guide before connecting
sensitive accounts.

## 🚀 Start here

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/install.sh)
```

On a new machine, the bare command detects that NeoAgent is not installed,
runs the installer, and guides you through AI provider API keys. It starts the
service and prints any host-specific action items. Open
`http://localhost:3333` when it finishes.

Continue with:

- [Install and complete the first run](getting-started.md)
- [Choose and configure a model](models.md)
- [Understand the security boundaries](security-boundaries.md)
- [Migrate from OpenClaw or Hermes](migration.md)

## 🧭 User guide

| Guide | Use it for |
|---|---|
| [Installation](getting-started.md) | Host requirements, installation, first run |
| [Models](models.md) | Local, API-key, and account-backed model providers |
| [Agents and users](agents-and-users.md) | Specialist agents and multi-user administration |
| [Automation](automation.md) | Schedules, event triggers, delivery, and run history |
| [Memory](memory.md) | What NeoAgent remembers and how to manage it |
| [Integrations](integrations.md) | Connected app accounts and messaging channels |
| [Devices and interfaces](devices.md) | Android, desktop, Chrome, launcher, and wearable surfaces |
| [Health](health.md) | Health Connect |
| [Skills and MCP](skills.md) | Reusable instructions and external tool servers |
| [Operations](operations.md) | Updates, backups, logs, and recovery |
| [Billing](billing.md) | Stripe subscriptions, plans, trials, and webhooks |
| [Configuration](configuration.md) | Environment and runtime reference |
| [Why NeoAgent](why-neoagent.md) | Factual comparison with OpenClaw and Hermes |

## 🛠️ Developer guide

The developer guide explains the implementation rather than the product setup.
Start with [Architecture](architecture.md), then follow the subsystem links in
the developer section of the sidebar.

Contributors must also follow
[GUIDELINES.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/GUIDELINES.md)
and
[CONTRIBUTING.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/CONTRIBUTING.md).
