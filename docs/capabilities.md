# Capabilities

NeoAgent can operate real software on the machine it runs on — a browser, Android emulators and devices, and a terminal. It connects to your accounts, remembers context across sessions, and runs scheduled automations without you being present.

## Operator UI

| Section | What it's for |
|---|---|
| **Chat** | Interactive agent runs with full tool access, memory, integrations, and messaging |
| **Runs** | Live and historical step-by-step execution — browser, Android, CLI, messaging, tasks, MCP, subagents |
| **Tasks** | Schedule-triggered and integration-triggered automations |
| **Skills** | Built-in and custom reusable workflows |
| **Integrations** | OAuth account connections for structured app tools |
| **MCP** | Remote MCP server registration and tool discovery |
| **Memory** | Long-term memory, core facts, and session search |
| **Devices** | Server-side browser and Android runtime controls |
| **Recordings** | Audio sessions, transcripts, segment playback, AI insights |
| **Health** | Android Health Connect sync status and synced metrics |
| **Settings** | AI providers, model routing, runtime settings, messaging credentials |
| **Logs** | Service logs and diagnostics |

## Agent Tools

What the agent can use in chat and automation runs:

| Area | Capabilities |
|---|---|
| **CLI** | PTY-capable `execute_command` with stdin, timeout, stdout/stderr, exit code |
| **Browser** | Navigate, click, type, extract, screenshot, evaluate JavaScript |
| **Android** | UI observation, input, screenshots, app launch, intent launch, APK install, `adb shell` |
| **Web search** | Brave Search API |
| **Files** | Read, write, edit, list, search |
| **HTTP** | Direct requests |
| **Memory** | Semantic search, session search, daily logs, core memory, API key name lookup |
| **Skills** | Create, list, update, delete persistent skills |
| **Tasks** | Create, update, delete, and one-time run automations |
| **MCP** | Add/remove MCP servers, use dynamic MCP tools |
| **Subagents** | Spawn, wait for, and cancel async helpers inside a run |
| **Images** | Generate with Grok, analyze with vision models |
| **Recordings** | List, inspect, search transcripts |
| **Social video** | Extract transcript and metadata from public YouTube, TikTok, Instagram, and X URLs |
| **Health** | Read synced mobile health metrics and summaries |
| **Outputs** | Markdown tables, Mermaid graphs, downloadable artifacts |

## Android Control

The agent operates Android — it is not an app that runs on Android. Controls run on a server-attached emulator or physical device over ADB.

- Start and stop the managed emulator
- List connected devices and installed apps
- Screenshot and UIAutomator XML dump
- Observe visible UI nodes
- Open apps and launch Android intents
- Tap, long press, type, swipe, press navigation keys
- Wait for text, resource IDs, descriptions, or classes to appear
- Install `.apk` and `.apks` bundles
- Run `adb shell` commands directly

These actions run on the NeoAgent server. If NeoAgent is deployed remotely, it controls the Android runtime on that machine — not your local device.

## Recordings

Audio sessions are recorded server-side. The web client captures browser microphone and screen audio; the Android app records phone microphone audio via a foreground service.

- Chunked uploads with per-source sequence tracking
- Session statuses: recording, processing, completed, failed, cancelled
- Transcript segment retry and deletion
- Transcript search across sessions
- Agent tools: `recordings_list`, `recordings_get`, `recordings_search`
- Social video extraction via `social_video_extract` — title, description, transcript, and a representative frame from YouTube, TikTok, Instagram, and X URLs

Transcription uses Deepgram (`nova-3` model, multi-language by default). Enable `auto_recording_insights` in AI settings to generate summaries, action items, and events automatically after transcription.

## Runtime Modes

| Profile | What runs where |
|---|---|
| `trusted-host` | CLI and Android run on the host; browser runs in the VM or paired extension |
| `secure-vm` | CLI, browser, and Android all run inside the isolated VM |

Production deployments can require `secure-vm` and a strong `NEOAGENT_VM_GUEST_TOKEN` (32+ characters).

The browser always runs in isolation — either the local VM or a paired Chrome extension on a remote machine. To pair an extension: download `/api/browser-extension/download` from NeoAgent, unzip it, enable Developer Mode in `chrome://extensions`, load the folder, then pair after signing in.

## Integrations and Messaging

NeoAgent has two separate layers:

**Official integrations** — structured OAuth-backed tools the agent can use:

| Provider | Tools |
|---|---|
| Google Workspace | Gmail, Calendar, Drive, Docs, Sheets |
| Microsoft 365 | Outlook, Calendar, OneDrive, Teams |
| Notion | Pages, databases, blocks, search |
| Slack | Messages, conversations, search |
| Figma | Files, nodes, comments, rendered images |
| Home Assistant | Entity state, service calls |
| Trello | Boards, lists, cards, comments |
| Spotify | Playback, search, queue |
| Weather | Current conditions and forecasts (no API key needed) |
| Personal WhatsApp | Per-account read and send |

**Messaging platforms** — channels for communicating with the agent:

WhatsApp, Telegram, Discord, Slack, Google Chat, Teams, Matrix, Signal, iMessage/BlueBubbles, IRC, Twitch, LINE, Mattermost, Telnyx Voice, plus webhook bridges for Feishu, Nextcloud Talk, Nostr, Synology Chat, Tlon, Zalo, WeChat, and WebChat.

Each official integration account can be set to **Read/Write** (default) or **Read Only**. Write tools are blocked server-side for read-only accounts.

## Android App and Health

The Flutter Android app connects to the same self-hosted backend and can:

- Run chat and operator UI
- Sync Android Health Connect data (steps, heart rate, sleep, exercise, weight)
- Record microphone audio via a foreground service

Synced health data is available through the `read_health_data` agent tool and the **Health** UI section.
