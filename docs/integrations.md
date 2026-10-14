---
title: Integrations and messaging
sidebar_label: Integrations
description: Connect accounts so the agent gets structured tools, and messaging channels so people can talk to it.
---

# Integrations and messaging

**Integrations give the agent tools for your accounts; messaging channels let people talk to it and receive task results.**

- **Two separate layers.** Connecting Slack as an integration does not set up Slack messaging, and the reverse.
- **One exception.** The GitHub messaging channel reuses the GitHub integration's **Mentions** app.

## 🔌 Integrations

Connect accounts under **Tools › Integrations**; each agent keeps its own connections.

| Provider | What the agent can use | Setup |
| --- | --- | --- |
| Google Workspace | Gmail, Calendar, Drive, Docs, Sheets | Server OAuth app (`GOOGLE_OAUTH_*`) |
| Microsoft 365 | Outlook, Calendar, OneDrive, Teams | Server OAuth app (`MICROSOFT_OAUTH_*`) |
| GitHub | Repositories, issues, pull requests, files, branches, workflows; **Mentions** channel | Server OAuth app (`GITHUB_OAUTH_*`) |
| Notion | Pages, databases, blocks, search | Server OAuth app (`NOTION_OAUTH_*`) |
| Slack | Conversations, history, search, messages | Server OAuth app (`SLACK_OAUTH_*`) |
| Figma | Files, nodes, rendered images, comments | Server OAuth app (`FIGMA_OAUTH_*`) |
| Spotify | Playback control, recently played, search | Server OAuth app (`SPOTIFY_OAUTH_*`) |
| NeoRecall | Read-only search, memories, daily summaries, conversations | Your NeoRecall URL, then NeoRecall sign-in |
| Nextcloud | Files, shares, Calendar, Contacts, other apps via OCS | Your Nextcloud URL, then Nextcloud sign-in |
| Home Assistant | Entity states and service calls | HTTPS URL and a Long-Lived Access Token |
| Trello | Boards, lists, cards, comments, search | Trello API key and account token |
| Weather | Location search, current conditions, forecasts | One click (Open-Meteo, no key) |
| World News | Top headlines by keyword or category | GNews API key |
| Personal WhatsApp | Your own chats: history, profile, sending | Scan a QR code |
| Bitwarden | [Credential broker](security-boundaries.md); no tools of its own | Email, then master password once (never stored) |

- **Several accounts.** Most providers accept many accounts per agent. Home Assistant, World News, Trello and Bitwarden take one.
- **Approval.** Integration tools fall under **External & MCP Tools**, which asks first by default.
- **Hidden until configured.** An OAuth provider only appears once its server credentials are set.

### Read Only accounts

- **Set it per account.** **Access mode** offers **Read / Write** (default) and **Read Only**.
- **Enforced on the server.** Write tools of a Read Only account are blocked, whatever the model attempts.
- **Unknown means write.** A tool that does not declare itself read-only counts as a write.

### OAuth setup on the server

1. Register an OAuth app with the provider.
2. Set its callback URL to `PUBLIC_URL/api/integrations/oauth/callback`.
3. Enter the client ID and secret under **Admin › Integrations**, or set `<PREFIX>_OAUTH_CLIENT_ID` and `<PREFIX>_OAUTH_CLIENT_SECRET` with `neoagent env set`.

- **Prefixes.** `GOOGLE`, `MICROSOFT`, `GITHUB`, `NOTION`, `SLACK`, `FIGMA`, `SPOTIFY`.
- **Microsoft tenant.** `MICROSOFT_OAUTH_TENANT_ID` defaults to `common`.
- **Optional redirect.** `<PREFIX>_OAUTH_REDIRECT_URI` overrides the default callback.
- **Trello.** A shared `TRELLO_API_KEY` set here spares users from entering their own key.

Full variable list: [Configuration](configuration.md).

### NeoRecall

1. Choose **NeoRecall** and enter your NeoRecall server's base URL.
2. Sign in on NeoRecall's own page and approve the read-only access.

- **Seven read-only tools.** Search, memories, mini-memories, daily summaries, conversations and transcript evidence.
- **No mutation.** No audio, recording, memory changes or NeoRecall Ask.
- **Ready for daily questions.** Once connected, its search, daily-summary and conversation tools are active in every run.
- **Reachable callback.** Sign-in opens the URL you entered; NeoAgent's `PUBLIC_URL` must be reachable from your browser.

### Nextcloud

1. Choose **Nextcloud** and enter your instance URL; NeoAgent checks its `status.php`.
2. Sign in through Nextcloud Login Flow v2 with password, SSO or 2FA; there is no app password to paste.

- **One login, three apps.** Files, Calendar and Contacts.
- **Other apps.** `nextcloud_ocs_request` reaches any API under `/ocs/v2.php/`.
- **Talk** is a messaging channel, set up under **Settings › Messaging**.

### Home Assistant

- **HTTPS only**, on port 443 or 8123.
- **Private addresses are blocked.** Local, loopback and private-network addresses are refused, also after DNS resolution.

## 💬 Messaging channels {#messaging-channels}

Configure channels for the selected agent under **Settings › Messaging**.

| Connection | Platforms |
| --- | --- |
| Linked account or bot, no public URL needed | WhatsApp (QR), Telegram (bot token), Discord (bot token), Matrix, IRC, Twitch, GitHub |
| Webhook, needs a reachable `PUBLIC_URL` | Slack, Google Chat, Microsoft Teams, LINE, Signal, iMessage, BlueBubbles, Mattermost |
| Generic webhook bridges | Feishu, Nextcloud Talk, Nostr, Synology Chat, Tlon, Zalo, Zalo Personal, WeChat, WebChat |

- **24 platforms.** No SMS, phone telephony or email inbox channel.
- **Webhook path.** `POST PUBLIC_URL/api/messaging/webhook/<platform>`, checked against the channel's secret or signature.

### Who can message

Each channel has a **Who can message** dialog with two settings.

| Setting | Options |
| --- | --- |
| **Private chats** | **Approved only** (default), **Anyone**, **No one** |
| **Groups and channels** | **Approved only** (default), **Anyone**, **No one** |

- **Approved only** admits the people, chats, groups or roles you add.
- **Anyone** lets strangers start runs; those runs act for someone else and ask before touching your data. See [run trust](security-boundaries.md#run-trust).

### WhatsApp modes

Pick the mode before scanning the QR code, and switch later with **Chat mode** on the WhatsApp card.

| Mode | Behaviour |
| --- | --- |
| **Separate account** (default) | Links a number that belongs to the agent. Direct chats and groups, gated by **Who can message**. |
| **Personal self-chat** | Links your own number. Only your "Message yourself" chat reaches the agent; every other chat is ignored. |

### GitHub mentions

Approved people @mention the agent's GitHub account on an issue or pull request, and the agent replies in that thread.

- **Connect** through the GitHub integration's **Mentions** app. Use a dedicated bot account, signed in on github.com first.
- **Who can message.** Add watched repositories plus the people or roles (`OWNER`, `MEMBER`, `COLLABORATOR`) who may ask.
- **Mention only.** A watched repository alone admits no one, and **Anyone** is not offered.
- **Restricted runs.** No memory of yours, no other integrations, no shell; replies only in the same thread.
- **Per-repository memory.** Each repository gets its own memory, and requests stay inside that repository.
- **Safe branches.** Commits go only to a `neoagent/*` branch or the pull request's own branch, never the default branch.
- **Polling.** Each agent checks every 30 seconds with its own connection, so no webhook or `PUBLIC_URL` is needed.

## 🩺 Troubleshooting

- **OAuth fails.** Check `PUBLIC_URL`, the callback URL, client credentials and provider scopes.
- **Provider missing in Tools.** Its server OAuth credentials are not set.
- **Messages ignored.** Check **Who can message**, then the run list under **Runs** and the server logs.
- **Webhook channel silent.** Confirm `PUBLIC_URL` is reachable from the platform and the shared secret matches.
