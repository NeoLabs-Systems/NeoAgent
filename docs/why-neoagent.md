# Why NeoAgent

NeoAgent is the right choice if you want a focused self-hosted agent with real Android device control, recordings, health data, and a practical operator UI. OpenClaw covers more platforms but is a different kind of product.

This comparison is based on the public [OpenClaw README](https://raw.githubusercontent.com/openclaw/openclaw/main/README.md) as of April 7, 2026 and the current NeoAgent repository.

| | NeoAgent | OpenClaw |
|---|---|---|
| **Best for** | Personal automation server with Android control, recordings, and health data | Broad AI gateway with many channels, nodes, and companion surfaces |
| **Setup** | `npm install -g neoagent && neoagent install` | `openclaw onboard` guided setup |
| **Architecture** | Self-hosted Node server, SQLite, bundled web UI, server-side credentials | Gateway control plane with channels, optional nodes, wider platform surface |
| **Android control** | Full AI control: screenshots, UI dumps, tap, swipe, type, intent launch, APK install, `adb shell` | Android node capabilities via the node ecosystem |
| **Messaging** | 15+ platforms built-in — Telegram, WhatsApp, Discord, Slack, Signal, Matrix, iMessage, Teams, IRC, LINE, Mattermost, Telnyx Voice, webhook bridges | Larger channel/node ecosystem |
| **Operator UI** | Chat, runs, logs, tasks, skills, integrations, MCP, memory, devices, recordings, health, settings | Gateway, canvas, platform, node, and channel surfaces |
| **Credentials** | All secrets server-side; channel settings stored through the app | Broader config surface across gateway, channels, and nodes |
| **Automation** | Cron tasks, integration triggers, browser/CLI skills, MCP, subagents, recording search, health summaries, messaging delivery | Cron, webhooks, nodes, channel-specific actions |
| **Recovery** | `neoagent status`, `neoagent logs`, `neoagent update`, `neoagent fix` | Doctor-style diagnostics plus channel/node tooling |

**Choose NeoAgent** when you want the shortest path to a self-hosted proactive agent with Android control and a practical operator UI.

**Choose OpenClaw** when you need maximum channel coverage, a gateway/node architecture, or the larger companion-app ecosystem.
