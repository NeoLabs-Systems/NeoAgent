# Integrations

NeoAgent has two integration layers: official OAuth integrations for structured app tools, and messaging platforms for talking to the agent.

## Official OAuth Integrations

The built-in registry includes:

| Provider | Use |
|---|---|
| Google Workspace | Gmail, Calendar, Drive, Docs, and Sheets tools |
| Notion | Search, pages, databases, blocks, comments, and raw Notion API requests |
| Microsoft 365 | Outlook, Calendar, OneDrive, Teams, and Microsoft Graph requests |
| Slack | Conversations, history, posting, search, user info, and Slack Web API requests |
| Figma | Current user, files, nodes, rendered images, comments, and Figma REST requests |

OAuth app credentials are configured through server environment variables. Account connections are created in the Flutter UI under **Integrations**. Connected tools are exposed to the agent as structured tools, so prefer them over browser automation when they can do the job.

The default callback is:

```text
PUBLIC_URL + /api/integrations/oauth/callback
```

You can override it with provider-specific redirect URI variables listed in [Configuration](configuration.md).

## Messaging Platforms

NeoAgent can talk through:

| Platform | Notes |
|---|---|
| WhatsApp | QR-based linking through the app settings; text and media sends |
| Telegram | Bot token plus approved chats |
| Discord | Bot token plus server or channel access |
| Slack | Bot token sends plus Events API callbacks |
| Google Chat | Space webhook sends plus app callback ingestion |
| Microsoft Teams | Incoming webhook sends plus outgoing webhook ingestion |
| Matrix | Homeserver access token with room send and polling |
| Signal | signal-cli REST API bridge |
| iMessage / BlueBubbles | BlueBubbles-compatible bridge for macOS-hosted iMessage |
| IRC and Twitch | IRC-style channel connections |
| LINE and Mattermost | Native send paths with webhook ingestion |
| Feishu, Nextcloud Talk, Nostr, Synology Chat, Tlon, Zalo, Zalo Personal, WeChat, and WebChat | Configurable webhook bridges |
| Telnyx Voice | Inbound and outbound calling with text-to-speech; scheduled tasks can call a number |

Messaging channel credentials are configured through the Flutter app messaging tab (not `.env`) for channel setup and inbound callback routing. The generic inbound callback path is:

```text
PUBLIC_URL + /api/messaging/webhook/:platform
```

Use the per-platform inbound secret or native signature fields in the messaging tab for webhook callbacks.

Telnyx exception: only the Telnyx voice webhook verification token stays in server environment variables as `TELNYX_WEBHOOK_TOKEN`, because webhook request verification is performed server-side. Other Telnyx and messaging channel credentials should be configured in the Flutter app messaging tab as part of channel/client configuration.

## Credentials

Keep provider API keys, OAuth client secrets, and messaging tokens on the server. Do not put them in docs, skill files, client-side code, screenshots, or logs.

If an OAuth provider fails to connect, check:

- `PUBLIC_URL` is reachable by the provider.
- The provider redirect URI matches NeoAgent's callback URL.
- The provider client ID and client secret are set on the server.
- The NeoAgent service was restarted after changing environment variables.

See [Capabilities](capabilities.md) for examples of the structured tools exposed by each provider.
