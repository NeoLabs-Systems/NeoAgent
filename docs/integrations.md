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
| Telnyx Voice | Inbound and outbound calling with text-to-speech; scheduled tasks can call a number |

Telegram, Discord, and WhatsApp tokens are stored through the Flutter app settings page rather than `.env`. Telnyx webhook verification uses `TELNYX_WEBHOOK_TOKEN`.

## Credentials

Keep provider API keys, OAuth client secrets, and messaging tokens on the server. Do not put them in docs, skill files, client-side code, screenshots, or logs.

If an OAuth provider fails to connect, check:

- `PUBLIC_URL` is reachable by the provider.
- The provider redirect URI matches NeoAgent's callback URL.
- The provider client ID and client secret are set on the server.
- The NeoAgent service was restarted after changing environment variables.

See [Capabilities](capabilities.md) for examples of the structured tools exposed by each provider.
