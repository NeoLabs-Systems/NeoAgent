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


Google, Microsoft, GitHub, Notion, Slack, Figma, and Spotify require OAuth application credentials on the server. The default callback is:
`PUBLIC_URL/api/integrations/oauth/callback`

**GitHub OAuth Configuration:**
1. Navigate to your GitHub Developer Settings and create a new **OAuth App**.
2. Set the Authorization callback URL to: `PUBLIC_URL/api/integrations/oauth/callback`.
3. Generate a **Client ID** and **Client Secret**.
4. Add these to your server environment configuration:
   - `GITHUB_CLIENT_ID=your_id_here`
   - `GITHUB_CLIENT_SECRET=your_secret_here`

Home Assistant and Trello can be configured for a user from the application. See Configuration.

## Messaging channels

Configure messaging under **Settings > Messaging**. Supported bridges include
WhatsApp, Telegram, Discord, Slack, Google Chat, Teams, Matrix, Signal,
iMessage through BlueBubbles, IRC, Twitch, LINE, Mattermost, Telnyx Voice, and
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
