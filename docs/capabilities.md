# Capabilities

This page lists the product surfaces that are easy to miss from the short README. It is based on the current server routes, agent tool registry, Flutter sections, Android bridge code, and integration providers in this repository.

## Operator UI

The Flutter client exposes the main operator surfaces:

| Section | What it is for |
|---|---|
| Chat | Normal agent runs with tools, memory, integrations, and messaging |
| Runs | Live and historical run steps, including browser, Android, CLI, messaging, scheduler, MCP, and subagent work |
| Logs | Service logs and diagnostics from the server you are connected to |
| Scheduler | Recurring cron tasks and one-time future runs |
| Skills | Built-in and custom reusable workflows |
| Integrations | OAuth account connections for structured app tools |
| MCP | Remote MCP server registration and tool discovery |
| Memory | Long-term memory, core memory, and session search |
| Devices | Server-side browser and Android runtime controls |
| Recordings | Recording sessions, transcripts, segments, and playback |
| Health | Android Health Connect sync status and synced metrics |
| Wearables | Supported Bluetooth recording devices and audio upload status |
| Settings | AI providers, model routing, runtime settings, messaging, and service controls |

## Recordings

NeoAgent records audio as server-side sessions with one or more sources. The web client can record browser microphone and screen audio, the Android app can record phone microphone audio through a foreground service, and the wearable bridge can upload audio chunks from supported Bluetooth devices.

Recording sessions support:

- Chunked uploads with per-source sequence checks.
- Sources, chunks, transcript segments, session status, and playback URLs.
- Statuses for recording, processing, completed, failed, and cancelled sessions.
- Retry transcription and delete transcript segment actions.
- Full session deletion with storage cleanup.
- Agent tools for listing, opening, and searching transcripts: `recordings_list`, `recordings_get`, and `recordings_search`.

Transcription uses Deepgram when `DEEPGRAM_API_KEY` is configured. The default speech model is `nova-3`, and the default language mode is `multi`. When `auto_recording_insights` is enabled in AI settings, NeoAgent can generate structured recording insights such as a summary, action items, and events.

## Android Control

NeoAgent can let the AI control an Android emulator or device attached to the NeoAgent server or configured worker. This is the Android capability in the comparison: the agent can observe and operate Android, not only run an Android companion app.

Android control supports:

- Starting and stopping the managed Android emulator.
- Listing ADB-connected devices and installed apps.
- Taking screenshots and UIAutomator XML dumps.
- Observing visible UI nodes.
- Opening apps and Android intents.
- Tapping, long pressing, typing, swiping, and pressing Android navigation keys.
- Waiting for text, resource IDs, descriptions, or classes to appear.
- Installing `.apk` and universal `.apks` bundles.
- Running `adb shell` commands when higher-level tools are not enough.

These actions run where the NeoAgent backend or runtime worker is running. If NeoAgent is deployed on a remote server, the AI controls the Android runtime attached to that server, not the laptop where you are reading the docs.

## Android App, Health, And Wearables

The Flutter Android app is still useful as a client. It can sign in to the same self-hosted backend, run chat and operator UI flows, sync Health Connect data, record audio locally, and bridge supported wearables.

Android app capabilities include:

- `NEOAGENT_BACKEND_URL` build/run configuration for real devices.
- Health Connect permission flow and background sync.
- Microphone recording through an Android foreground service.
- Boot restore hooks for recording and wearable services when Android allows them.
- Bluetooth wearable bridge support for HeyPocket-style devices.
- Upload of wearable chunks and synchronization state to the backend.

## Health Data

Health data comes from the Android app through `/api/mobile/health`. NeoAgent stores sync runs and normalized metric samples. The built-in metric aliases include steps, heart rate, sleep sessions, exercise sessions, and weight.

The agent tool `read_health_data` returns summaries and recent samples. It is designed to answer questions such as recent step totals or available health metrics without dumping every raw record.

## Integrations And Messaging

NeoAgent has two separate integration layers:

- Official OAuth integrations expose structured tools for Google Workspace, Microsoft 365, Notion, Slack, and Figma.
- Messaging platforms let the agent talk through WhatsApp, Telegram, Discord, Slack, Google Chat, Teams, Matrix, Signal, iMessage/BlueBubbles, IRC, Twitch, LINE, Mattermost, configurable webhook bridges, and Telnyx Voice.

Official integration examples include Gmail thread search and send mail, Google Calendar events, Drive upload/download/export/share links, Docs create/append/replace, Sheets read/update/append/create, Microsoft Outlook/Calendar/OneDrive/Teams tools, Notion search/page/block/database tools, Slack conversation/message tools, and Figma file/node/comment/image tools.

Messaging examples include Telegram and Discord messages, Slack channel replies, Matrix room messages, Google Chat and Teams webhook delivery, Signal bridge delivery, iMessage/BlueBubbles sends, WhatsApp text and media sends, Telnyx inbound voice, Telnyx outbound calls, and scheduled-task call delivery.

## Agent Tools

NeoAgent's agent tool surface includes more than basic chat:

| Area | Examples |
|---|---|
| CLI | PTY-capable `execute_command` with stdin, timeout, stdout, stderr, exit code, and duration |
| Browser | Navigate, click, type, extract, screenshot, and evaluate page JavaScript |
| Android control | UI observation, input, screenshots, app launch, intent launch, APK install, and shell commands |
| Web search | Brave Search API through `web_search` |
| Files | Read, write, edit, list, and search files |
| HTTP | Direct HTTP requests |
| Memory | Semantic memory, session search, daily logs, API key name reads, and core memory |
| Skills | Create, list, update, and delete persistent skills |
| Scheduler | Recurring tasks, one-time runs, model overrides, and optional Telnyx call delivery |
| MCP | Add, list, and remove MCP servers, plus dynamic MCP tool use |
| Subagents | Spawn, list, wait for, and cancel async subagents inside a run |
| Output | Generate markdown tables and Mermaid graphs |
| Images | Generate images with Grok and analyze local image files with a vision-capable model |
| Recordings | List, inspect, and search recording transcripts |
| Health | Read synced mobile health metrics |

Generated binary or text artifacts can be promoted into user-scoped artifact storage under `~/.neoagent/data/artifacts` and served through authenticated `/api/artifacts/:id/content` URLs.

## Runtime Modes

Runtime settings let operators choose where higher-risk work runs:

| Profile | Runtime shape |
|---|---|
| `trusted-host` | CLI, browser, and Android tools run on the host |
| `secure-vm` | CLI, browser, and Android tools run through the local VM backend |

Production policy can require the secure VM profile and a strong VM guest token.

These controls matter operationally: the browser, Android emulator, local files, and shell commands run wherever the NeoAgent backend, VM, or paired browser extension is running, not necessarily on the computer where you are reading the docs. Logs from a different server or remote browser may not match the logs on the local machine.

For extension-only remote browser control, download `/api/browser-extension/download` from NeoAgent, unzip it on the remote machine, load the folder in `chrome://extensions`, and pair after logging in. The extension uses Chrome's debugger permission for full browser control, so Chrome will show its normal debugging warning while attached. The popup can check whether the server has a newer extension bundle, but unpacked Developer Mode installs still need a manual download and reload.
