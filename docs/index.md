---
slug: /
title: NeoAgent documentation
sidebar_label: Overview
description: The personal AI agent you host yourself. Install it, connect a model, put it to work.
---

# NeoAgent documentation

**NeoAgent is a personal AI agent you host yourself.**

:::warning Beta software
Run it on a machine you administer, start with restricted tool permissions, and read [Security and permissions](security-boundaries.md) before connecting sensitive accounts.
:::

## 🚀 Start here

| Step | Guide |
| --- | --- |
| **1. Install** | [Desktop app, Docker or script](getting-started.md) |
| **2. Connect a model** | [Models](models.md), or **Sign in with OpenRouter** during onboarding |
| **3. Set limits** | [Security and permissions](security-boundaries.md) |
| **4. Bring your setup** | [Migrate from OpenClaw or Hermes](migration.md) |

## 🧭 User guide

| Guide | Covers |
| --- | --- |
| [Installation](getting-started.md) | Install options, first run, onboarding |
| [Docker](docker.md) | Compose setup, data volume, cloud computer backends |
| [Models](models.md) | Providers, your own keys, local models, Auto routing |
| [Agents and users](agents-and-users.md) | Specialist agents, accounts, admin |
| [Automation](automation.md) | Schedules, event triggers, delivery |
| [Memory](memory.md) | What it remembers and how to edit it |
| [Integrations](integrations.md) | App accounts and messaging channels |
| [Devices](devices.md) | Cloud computer, desktop, Android, wearable |
| [Health](health.md) | Health Connect |
| [Skills and MCP](skills.md) | Skills, Teach Mode, MCP servers |
| [Security and permissions](security-boundaries.md) | Tool permissions, credentials, isolation |
| [Operations](operations.md) | Updates, backups, logs, recovery |
| [Configuration](configuration.md) | Environment variable reference |
| [Why NeoAgent](why-neoagent.md) | Comparison with other agents |

## 🛠️ Developer guide

| Guide | Covers |
| --- | --- |
| [Architecture](architecture.md) | How the server, clients and services fit together |
| [Agent run lifecycle](agent-run-lifecycle.md) | What happens from message to final reply |
| [Memory architecture](memory-architecture.md) | Storage, retrieval, consolidation |
| [Runtime and tools](runtime-and-tools.md) | Tool registry and the cloud computer |
| [Automation architecture](automation-architecture.md) | Trigger adapters and task runs |
| [Integrations architecture](integrations-architecture.md) | Providers, OAuth, connections |
| [Clients and devices](clients-and-devices.md) | App, desktop, launcher, wearable |
| [Persistence](persistence.md) | Database and data directories |
| [Development](development.md) | Local setup, tests, release flow |

:::info Contributing
Follow [GUIDELINES.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/GUIDELINES.md) and [CONTRIBUTING.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/CONTRIBUTING.md).
:::
