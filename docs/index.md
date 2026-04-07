# NeoAgent

NeoAgent is a self-hosted proactive AI agent with a bundled Flutter client for web and Android. It runs on your server, keeps credentials server-side, and gives you an operator UI for chat, runs, logs, scheduler tasks, skills, integrations, MCP, memory, Android devices, recordings, Health Connect data, wearables, and settings.

It is designed for people who want a focused personal automation server rather than a broad gateway platform. NeoAgent can run scheduled tasks, use browser and file tools, remember long-term context, connect to hosted AI providers or local Ollama, sync Android Health Connect data, record audio on Android, bridge supported wearables, and send results through Telegram, Discord, WhatsApp, or Telnyx Voice.

## Quick Start

```bash
npm install -g neoagent
neoagent install
```

Then open the server URL, sign in, configure providers and messaging, and create your first scheduled task or chat run.

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

## Where To Go Next

- [Getting started](getting-started.md) covers installation, setup, and service commands.
- [Capabilities](capabilities.md) lists the broader tool, Android control, recording, health, runtime, and integration surface.
- [Configuration](configuration.md) explains server-side environment variables and secrets.
- [Automation](automation.md) explains scheduled tasks and tool safety.
- [Integrations](integrations.md) explains OAuth integrations and messaging.
- [Skills](skills.md) explains built-in and custom skills.
- [Operations](operations.md) explains logs, updates, release channels, and recovery.
- [Why NeoAgent](why-neoagent.md) compares NeoAgent with OpenClaw.
