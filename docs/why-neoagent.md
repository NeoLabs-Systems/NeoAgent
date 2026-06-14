# NeoAgent, OpenClaw, and Hermes

This page describes product emphasis, not a universal ranking. The projects
change quickly, and the right choice depends on the interfaces and operating
model you need.

The comparison was reviewed on June 14, 2026 against the public
[OpenClaw repository](https://github.com/openclaw/openclaw),
[Hermes Agent repository](https://github.com/NousResearch/hermes-agent), and
the current NeoAgent source.

| Area | NeoAgent | OpenClaw | Hermes Agent |
|---|---|---|---|
| Primary experience | Operator UI backed by a self-hosted service | Gateway and assistant across channels, nodes, and companion surfaces | Terminal UI or messaging gateway |
| Persistent memory | Local structured facts, temporal updates, provenance, hybrid retrieval | Project-defined memory and plugin surfaces | Built-in Markdown memory with optional external memory providers |
| Android operation | Direct ADB control of a host-attached device or emulator | Android companion/node capabilities | Android and Termux-oriented capabilities |
| Desktop and browser | Isolated runtime, paired desktop companion, paired Chrome extension | Node and companion ecosystem | Local and remote execution backends |
| Multi-user administration | User accounts, admin interface, optional service email, per-user runtime | Gateway-centered deployment model | Primarily personal-agent configuration |
| Automation | Schedules, account events, weather events, webhooks, notification runs | Cron, hooks, webhooks, and channel/node events | Cron, gateway events, and tool-driven workflows |
| Interfaces | Web, Android, desktop, launcher, messaging, extension, wearable firmware | Broad channel, platform, node, and companion ecosystem | Terminal plus Telegram, Discord, Slack, WhatsApp, Signal, email, and other integrations |
| Migration into NeoAgent | Native importer target | Skills, memory files, and selected keys can be imported | Skills, memory files, and selected keys can be imported |

## Choose NeoAgent when

- You want a visual operator interface for agents, runs, memory, tasks,
  accounts, devices, and administration.
- Direct Android control over ADB is central to the deployment.
- You want structured memory and integration ingestion without a separate
  memory service.
- You need multiple users or specialist agents with separate state.
- Launcher mode, Health Connect, recordings, or the bundled device interfaces
  are part of the use case.

## Consider OpenClaw when

- Its larger gateway, node, channel, plugin, or companion ecosystem is the main
  requirement.
- You need an existing OpenClaw-specific integration or community resource.
- Its distributed assistant architecture better matches your devices.

## Consider Hermes when

- A terminal-first workflow is preferable.
- Its skill ecosystem, remote execution options, or model workflow fits the
  task.
- Built-in Markdown memory or one of its external memory providers is already
  part of your setup.

NeoAgent's memory architecture is documented in [Memory](memory.md). The
project does not claim superior recall without a reproducible, published
benchmark that records the dataset, models, retrieval settings, judge, token
budget, latency, and run artifacts.
