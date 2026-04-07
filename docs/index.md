---
layout: home

hero:
  name: NeoAgent
  text: Self-hosted proactive AI agent
  tagline: Run your own server, keep credentials server-side, and operate browser, Android, recordings, schedules, integrations, memory, MCP, and messaging from one Flutter UI.
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started
    - theme: alt
      text: Capabilities
      link: /capabilities
    - theme: alt
      text: Why NeoAgent
      link: /why-neoagent

features:
  - title: Android Control
    details: Let the AI operate a server-attached Android emulator or device with screenshots, UI dumps, app launch, intents, taps, typing, swipes, APK installs, and ADB shell.
    link: /capabilities#android-control
    linkText: Android Control
  - title: Recordings
    details: Capture web, Android, and wearable audio as sessions with transcripts, searchable segments, playback, retry, cleanup, and AI-generated insights.
    link: /capabilities#recordings
    linkText: Recordings
  - title: Proactive Automation
    details: Create recurring tasks and one-time runs that can use browser, files, CLI, memory, MCP, integrations, subagents, health summaries, and messaging delivery.
    link: /automation
    linkText: Automation
  - title: Official Integrations
    details: Use OAuth-backed Google Workspace, Microsoft 365, Notion, Slack, and Figma tools instead of brittle browser automation where possible.
    link: /integrations
    linkText: Integrations
  - title: Server-Side Secrets
    details: Keep AI provider keys, OAuth client secrets, Telnyx tokens, runtime settings, and deployment controls on the NeoAgent server.
    link: /configuration
    linkText: Configuration
  - title: Recovery Path
    details: Operate self-hosted installs with status, logs, release channels, update, fix, runtime paths, and the remote-server log caveat.
    link: /operations
    linkText: Operations
---

## Quick Start

```bash
npm install -g neoagent
neoagent install
```

Open the server URL, sign in, configure providers and messaging, then create a scheduled task or chat run.

## Navigation

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
