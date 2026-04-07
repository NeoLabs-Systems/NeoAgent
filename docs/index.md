# NeoAgent

NeoAgent is a self-hosted proactive AI agent with a bundled Flutter client for web and Android. It runs on your server, keeps credentials server-side, and gives you an operator UI for chat, runs, logs, scheduler tasks, skills, integrations, MCP, memory, Android control, recordings, Health Connect data, wearables, and settings.

It is designed for people who want a focused personal automation server rather than a broad gateway platform. NeoAgent can run scheduled tasks, control a browser, operate a server-attached Android emulator or device, manage files, remember long-term context, connect to hosted AI providers or local Ollama, search recordings, read synced health summaries, and send results through Telegram, Discord, WhatsApp, or Telnyx Voice.

## Quick Start

```bash
npm install -g neoagent
neoagent install
```

Open the server URL, sign in, configure providers and messaging, then create a scheduled task or chat run.

## What NeoAgent Does

| Area | Capability |
|---|---|
| AI providers | OpenAI, Anthropic, xAI, Google, MiniMax Code, and local Ollama |
| Operator UI | Chat, live runs, logs, scheduler, skills, integrations, MCP, memory, devices, recordings, health, wearables, settings |
| Automation | Recurring scheduled tasks, one-time runs, browser control, file access, CLI skills, subagents, and messaging delivery |
| Android control | AI control of a server-attached Android emulator or device: screenshots, UI dumps, taps, typing, intents, APK installs, and ADB shell |
| Recordings | Web, Android, and wearable audio sessions with transcript search and AI insights |
| Integrations | Google Workspace, Notion, Microsoft 365, Slack, Figma, and remote MCP servers |
| Messaging | Telegram, Discord, WhatsApp text/media, and Telnyx Voice calls |
| Outputs | Artifacts, Grok image generation, vision analysis, markdown tables, and Mermaid graphs |
| Recovery | `neoagent status`, `neoagent logs`, `neoagent update`, release channels, and `neoagent fix` |

## Main Paths

| Need | Start here |
|---|---|
| Install and first run | [Getting Started](getting-started.md) |
| Full product surface | [Capabilities](capabilities.md) |
| Android device control | [Capabilities: Android Control](capabilities.md#android-control) |
| Recordings and transcripts | [Capabilities: Recordings](capabilities.md#recordings) |
| Scheduled tasks | [Automation](automation.md) |
| OAuth apps and messaging | [Integrations](integrations.md) |
| Skills and MCP | [Skills](skills.md) |
| Secrets and runtime settings | [Configuration](configuration.md) |
| Logs, updates, and repair | [Operations](operations.md) |
| OpenClaw comparison | [Why NeoAgent](why-neoagent.md) |
