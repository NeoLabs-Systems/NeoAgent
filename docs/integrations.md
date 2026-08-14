# Integrations and messaging

NeoAgent has two connection layers with different purposes.

**Integrations** give the agent structured tools for an account. **Messaging
channels** let people talk to the agent and receive automation results.
Connecting Slack or WhatsApp in one layer does not automatically configure the
other.

## Official integrations

Connect accounts in **Integrations**.

| Provider | Available areas |
|---|---|
| Google Workspace | Gmail, Calendar, Drive, Docs, Sheets |
| Microsoft 365 | Outlook, Calendar, OneDrive, Teams |
| GitHub | Repositories, issues, pull requests, files, branches, workflows |
| Notion | Pages, databases, blocks, search |
| Slack | Conversations, history, search, messages |
| Figma | Files, nodes, rendered images, comments |
| NeoArchive | Documents, extracted text, metadata, search, upload, archive, reprocessing |
| NeoRecall | Local hybrid recall search, memories, mini-memories, daily summaries, conversations, transcript evidence |
| Home Assistant | Entity state and service calls |
| Trello | Boards, lists, cards, comments, search |
| Spotify | Playback, history, search, queue |
| Weather | Location search, current conditions, forecasts |
| Personal WhatsApp | Private account chat history and send tools |

Available operations are discovered from the current server implementation and
connected account. They may differ by provider permissions.

### Read-only accounts

Connected accounts can be set to **Read Only**. NeoAgent blocks their write
tools server-side. Use read-only mode unless an agent must create, send, update,
or delete data.

### Setup

Google, Microsoft, GitHub, Notion, Slack, Figma, and Spotify require OAuth
application credentials on the server. The callback URL for every provider is
`PUBLIC_URL/api/integrations/oauth/callback`.

GitHub as the example:

1. Create an **OAuth App** under GitHub Developer Settings.
2. Set the authorization callback URL to the one above.
3. Add the credentials to the server environment:
   - `GITHUB_OAUTH_CLIENT_ID`
   - `GITHUB_OAUTH_CLIENT_SECRET`

The other providers follow the same pattern with their own `*_OAUTH_`
prefixes, listed in [Configuration](configuration.md).

NeoArchive, NeoRecall, Home Assistant, and Trello need no server-side app
registration; users configure them from the application.

### NeoRecall

Open **Integrations**, choose **NeoRecall**, and enter the base URL of the
NeoRecall server. NeoAgent validates the server and opens NeoRecall's own
authorization page. Sign in there and approve the three read-only scopes.

NeoRecall contributes seven on-demand tools for local hybrid search and for
reading memories, mini-memories, daily summaries, conversations, and transcript
evidence. It does not expose audio, recording, memory mutation, consolidation,
or NeoRecall Ask. This keeps the products isolated and avoids a second LLM call
when NeoAgent only needs retrieval context.

## Messaging channels

Configure messaging under **Settings > Messaging**. Supported bridges include
WhatsApp, Telegram, Discord, Slack, Google Chat, Teams, Matrix, Signal,
iMessage through BlueBubbles, IRC, Twitch, LINE, Mattermost, and
several webhook-backed services.

Each channel has its own authentication and allowlist behavior. Restrict which
chats, rooms, groups, and senders may start agent runs.

Webhook-based channels require a reachable `PUBLIC_URL`. The generic inbound
path is:

```text
PUBLIC_URL/api/messaging/webhook/:platform
```

## Troubleshooting

For failed OAuth connections, confirm the public URL, callback, client
credentials, and provider scopes. For messaging failures, inspect **Runs** and
server logs on the NeoAgent host, then verify the channel allowlist and webhook
reachability.
