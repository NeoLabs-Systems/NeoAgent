# Integrations

NeoAgent has two integration layers: official integrations for structured app tools, and messaging platforms for communicating with the agent.

## Official Integrations

Structured OAuth-backed tools the agent can use in chat and automation. Connect accounts in the Flutter app under **Integrations**.

| Provider | What the agent can do |
|---|---|
| **Google Workspace** | Search and send Gmail, read/create Calendar events, Drive upload/download/share, Docs create/append, Sheets read/write |
| **Microsoft 365** | Outlook mail, Calendar, OneDrive, Teams messages, Graph API |
| **Notion** | Search pages, read/write databases and blocks, manage comments |
| **Slack** | Read and send messages, search conversations |
| **Figma** | Read files and nodes, get rendered images, manage comments |
| **Home Assistant** | Read entity state, call services |
| **Trello** | Manage boards, lists, cards, comments, and search |
| **Spotify** | Playback controls, search, queue management |
| **Weather** | Current conditions and forecasts — no API key needed |
| **Personal WhatsApp** | Per-account read and send with isolated access |

### Access Modes

Each connected account can be set to **Read/Write** (default) or **Read Only**. Read-only blocks all write operations server-side — sending, creating, updating, and deleting.

### OAuth Setup

Most providers require OAuth app credentials in server config before users can connect. See [Configuration: Official Integrations](configuration.md#official-integrations) for the required environment variables.

Home Assistant and Trello can be configured per-user in the **Integrations** UI without any server-side setup.

The default OAuth callback URL is `PUBLIC_URL + /api/integrations/oauth/callback`.

**If an OAuth connection fails:**
1. Confirm `PUBLIC_URL` is reachable by the provider
2. Confirm the redirect URI in your OAuth app matches NeoAgent's callback URL
3. Confirm the client ID and secret are set in server config
4. Restart after changing environment variables: `neoagent restart`

## Messaging Platforms

Channels through which users and the agent communicate. Configure credentials in the Flutter app under **Settings → Messaging** — not in `.env`.

| Platform | Notes |
|---|---|
| **WhatsApp** | Messaging bridge for agent chat; separate official integration for structured read/send tools |
| **Telegram** | Bot token plus approved chat IDs |
| **Discord** | Bot token plus server or channel access |
| **Slack** | Bot token sends, Events API callbacks |
| **Google Chat** | Space webhook sends, app callback ingestion |
| **Microsoft Teams** | Incoming webhook sends, outgoing webhook ingestion |
| **Matrix** | Homeserver access token, room send, polling |
| **Signal** | signal-cli REST API bridge |
| **iMessage / BlueBubbles** | BlueBubbles-compatible bridge on a macOS host |
| **IRC and Twitch** | IRC-style channel connections |
| **LINE and Mattermost** | Native send, webhook ingestion |
| **Telnyx Voice** | Inbound and outbound calls with text-to-speech |
| **Webhook bridges** | Feishu, Nextcloud Talk, Nostr, Synology Chat, Tlon, Zalo, WeChat, WebChat |

Inbound webhook path: `PUBLIC_URL + /api/messaging/webhook/:platform`

`TELNYX_WEBHOOK_TOKEN` is the only messaging credential that goes in `.env` — all others are configured through the app messaging tab.

## Security

Keep OAuth client secrets, bot tokens, and API keys on the server. Don't put them in skill files, task prompts, screenshots, or logs. Rotate immediately if a credential is exposed.
