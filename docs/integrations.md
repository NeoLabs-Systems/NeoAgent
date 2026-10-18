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
| Google Workspace | Gmail, Calendar, Drive, Docs, Sheets | [OAuth app](#oauth-apps) |
| Microsoft 365 | Outlook, Calendar, OneDrive, Teams | [OAuth app](#oauth-apps) |
| GitHub | Repositories, issues, pull requests, files, branches, workflows; **Mentions** channel | [OAuth app](#oauth-apps) |
| Notion | Pages, databases, blocks, search | [OAuth app](#oauth-apps) |
| Slack | Conversations, history, search, messages | [OAuth app](#oauth-apps) |
| Figma | Files, nodes, rendered images, comments | [OAuth app](#oauth-apps) |
| Spotify | Playback control, recently played, search | [OAuth app](#oauth-apps) |
| Email & Calendar | Mail over IMAP/SMTP; calendars and contacts over CalDAV/CardDAV; read-only calendars by iCal link | [App password or iCal link](#email-and-calendar) |
| Phone calendar & contacts | Every calendar and contact on your phone | [NeoAgent phone app](#phone-calendar-and-contacts) |
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

### Read Only accounts

- **Set it per account.** **Access mode** offers **Read / Write** (default) and **Read Only**.
- **Enforced on the server.** Write tools of a Read Only account are blocked, whatever the model attempts.
- **Unknown means write.** A tool that does not declare itself read-only counts as a write.

### OAuth apps {#oauth-apps}

1. Open the provider in **Tools › Integrations** and choose **Configure**.
2. Follow the dialog: open the provider's developer console, register the callback URL it shows, and allow the listed scopes.
3. Paste the client ID and secret, save, then connect your accounts.

- **One app per account.** It is shared by all your agents; the client secret is stored encrypted and never shown again.
- **Or skip it.** For mail, calendar and contacts, [Email & Calendar](#email-and-calendar) and the [phone app](#phone-calendar-and-contacts) need no developer console; the Google and Microsoft dialogs offer them.
- **Global app.** When an admin sets a global app under **Admin › Integrations**, every account uses it and per-user setup is hidden. See [Configuration](configuration.md#official-integrations).

### Email & Calendar {#email-and-calendar}

The quickest way to connect a mailbox: no developer console.

1. Choose **Email & Calendar** and pick your provider: Gmail, iCloud, Fastmail, Yahoo, or any other IMAP server.
2. Create an app password with the link the dialog shows, then enter your address and that password.

- **What you get.** Mail for every provider; calendars and contacts too for iCloud, Fastmail and servers with CalDAV/CardDAV.
- **Calendar link (iCal).** Paste a calendar's iCal address (Google: *Secret address in iCal format*; Outlook: *Publish a calendar*; iCloud: *Public Calendar*) for a read-only calendar with repeating events expanded. Anyone with the address can read the calendar, so keep it private.
- **Gmail.** Mail with an app password; add Google Calendar as a calendar link, or use the Google Workspace integration or the phone app.
- **Outlook / Microsoft 365.** Microsoft no longer accepts app passwords for mail; use the Microsoft 365 integration, or add the calendar as a calendar link.
- **Checked on save.** NeoAgent signs in once before saving, so a wrong password shows up right away.

### Phone calendar & contacts {#phone-calendar-and-contacts}

The NeoAgent app on Android or iOS shares the calendars and contacts already on the phone, from every account it syncs (Google, Outlook, iCloud, Exchange).

1. On the phone, open **Tools › Integrations › Phone calendar & contacts**, or answer the question the app asks once after you sign in.
2. Choose calendar, contacts or both, and allow access.

- **What syncs.** Events from 30 days ago to 90 days ahead, and names, email addresses and phone numbers; stored encrypted on your server.
- **When.** Android syncs every 15 minutes and shortly after anything changes. iOS syncs while the app is open and when iOS allows a background refresh, so it can lag by hours.
- **Changes.** Events and contacts the agent adds are made by the phone, then sync on to their account. While the phone is offline they wait, and the agent says so.
- **Other devices.** The integration shows on desktop and web too, greyed out until a phone shares.

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
- **Callback rejected.** The callback URL comes from `PUBLIC_URL`; set it to the address your browser uses.
- **Messages ignored.** Check **Who can message**, then the run list under **Runs** and the server logs.
- **Webhook channel silent.** Confirm `PUBLIC_URL` is reachable from the platform and the shared secret matches.
