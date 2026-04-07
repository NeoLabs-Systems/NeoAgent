# Why NeoAgent

NeoAgent is not trying to beat OpenClaw at every surface. OpenClaw is broader. NeoAgent is better if you want a focused self-hosted server where the AI can operate a server-attached Android emulator or device, use recordings and health data, keep credentials server-side, and stay on a smaller set of common messaging paths.

This comparison is based on the public [OpenClaw README](https://raw.githubusercontent.com/openclaw/openclaw/main/README.md) checked on April 7, 2026 and the current NeoAgent repository behavior.

| Category | NeoAgent | OpenClaw |
|---|---|---|
| Best fit | A focused personal automation server with Android device control, recordings, health data, and built-in operator controls. | A broad personal assistant gateway with many channels, nodes, and companion surfaces. |
| Setup shape | `npm install -g neoagent` followed by `neoagent install`. | `openclaw onboard` is the preferred guided setup path. |
| Architecture | Self-hosted Node server, SQLite runtime data, built-in web UI, Android client, server-side credentials. | Gateway control plane with channel connections, optional apps/nodes, and a much wider platform surface. |
| Android control | AI control of a server-attached Android emulator or device: screenshots, UI dumps, visible node inspection, app launch, intent launch, taps, long press, typing, swipes, key presses, wait-for-element, APK installs, and `adb shell`. | Broader node/app ecosystem with Android node capabilities documented publicly. |
| Messaging breadth | Broad built-in messaging tab coverage: WhatsApp, Telegram, Discord, Slack, Google Chat, Signal, iMessage/BlueBubbles, IRC, Teams, Matrix, LINE, Mattermost, Twitch, and configurable webhook bridges for Feishu, Nextcloud Talk, Nostr, Synology Chat, Tlon, Zalo, WeChat, and WebChat, plus Telnyx Voice. | Still broader as a gateway ecosystem: the public README lists the same major channels plus a larger channel/node/app surface around them. |
| Operator UX | Built-in UI sections for chat, runs, logs, scheduler, skills, integrations, MCP, memory, devices, recordings, health, and settings. | Broader gateway, web, canvas, platform, node, and channel surfaces. |
| Credentials | AI provider keys and OAuth client secrets are server-side; channel settings are stored through the app where supported. | Public docs describe a broader config and auth surface across gateway, channels, nodes, and apps. |
| Automation | Cron-style scheduled tasks, one-time runs, browser/file/CLI skills, MCP tools, official integrations, subagents, recording search, health summaries, and messaging delivery. | Broader automation platform including cron, webhooks, nodes, and channel-specific actions. |
| Recovery | CLI-first service operations: `neoagent status`, `neoagent logs`, release channels, `neoagent update`, and `neoagent fix`. | Public README highlights onboarding, updating, and doctor-style diagnostics. |

Choose NeoAgent when you want the shortest path to a self-hosted proactive agent with a practical operator UI. Choose OpenClaw when you need maximum channel coverage, gateway/node architecture, or the larger companion-app ecosystem.
