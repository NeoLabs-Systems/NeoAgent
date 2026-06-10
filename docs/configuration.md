# Configuration

NeoAgent reads server config from `~/.neoagent/.env`. Run `neoagent setup` to generate or update it interactively. Set `NEOAGENT_HOME` to move the runtime root.

All AI provider credentials, OAuth client secrets, and deployment settings are server-side only — never sent to the client or exposed in the UI.

## Admin Dashboard

The admin dashboard at `/admin` provides a web UI for operator tasks including AI provider key management, server logs, and runtime updates. Credentials are generated during `neoagent setup` (or run `neoagent admin` to view them).

Navigate to **Providers** in the sidebar to set or rotate API keys without editing `.env` manually — changes take effect immediately without a server restart.

## Minimal Config

```dotenv
PORT=3333
SESSION_SECRET=change-me-to-something-random
ANTHROPIC_API_KEY=sk-ant-...
```

Generate a session secret: `openssl rand -hex 32`

## Core Variables

| Variable | Default | Description |
|---|---:|---|
| `PORT` | `3333` | HTTP port for the NeoAgent server |
| `PUBLIC_URL` | optional | Public base URL — required for OAuth callbacks, messaging webhooks, and mobile access |
| `SESSION_SECRET` | required | Random string for session signing |
| `NODE_ENV` | `production` | Set to `development` for verbose logs |
| `SECURE_COOKIES` | `false` | Set `true` when behind a TLS-terminating proxy |
| `TRUST_PROXY` | inferred | Set `true` when behind Nginx, Caddy, Cloudflare, Fly, or any proxy sending `X-Forwarded-*` |
| `ALLOWED_ORIGINS` | none | Comma-separated CORS origins |
| `NEOAGENT_DEPLOYMENT_MODE` | `self_hosted` | `managed` hides operator-only controls for SaaS deployments |
| `NEOAGENT_RELEASE_CHANNEL` | `stable` | Release track followed by `neoagent update` |

## AI Providers

At least one key is required unless you only use local Ollama.

| Variable | Provider |
|---|---|
| `ANTHROPIC_API_KEY` | Claude (Anthropic) |
| `OPENAI_API_KEY` | GPT and Whisper (OpenAI) |
| `XAI_API_KEY` | Grok (xAI) |
| `XAI_BASE_URL` | Optional xAI-compatible base URL override |
| `GOOGLE_AI_KEY` | Gemini (Google) |
| `MINIMAX_API_KEY` | MiniMax (including `MiniMax-M2.7`) |
| `NVIDIA_API_KEY` | NVIDIA NIM (free-tier + paid: Nemotron, Kimi, Llama 4, DeepSeek, etc.) |
| `OPENROUTER_API_KEY` | OpenRouter — access 300+ models from all providers through one API; free-tier models included |
| `BRAVE_SEARCH_API_KEY` | Brave Search for the `web_search` tool |
| `OPENAI_BASE_URL` | Optional OpenAI-compatible base URL override |
| `ANTHROPIC_BASE_URL` | Optional Anthropic-compatible base URL override |
| `DEEPGRAM_API_KEY` | Recording transcription |
| `DEEPGRAM_BASE_URL` | Optional Deepgram base URL override |
| `DEEPGRAM_MODEL` | Deepgram speech model (default: `nova-3`) |
| `DEEPGRAM_LANGUAGE` | Deepgram language mode (default: `multi`) |
| `OLLAMA_URL` | Local Ollama server, e.g. `http://localhost:11434` |

## Official Integrations

OAuth app credentials for structured agent tools. All callbacks default to `PUBLIC_URL + /api/integrations/oauth/callback`.

Home Assistant and Trello can be configured per-user in the Flutter UI without any server-side setup.

| Variable | Description |
|---|---|
| `GOOGLE_OAUTH_CLIENT_ID` | Google Workspace client ID |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Google Workspace client secret |
| `GOOGLE_OAUTH_REDIRECT_URI` | Optional Google OAuth callback URL |
| `NOTION_OAUTH_CLIENT_ID` | Notion client ID |
| `NOTION_OAUTH_CLIENT_SECRET` | Notion client secret |
| `NOTION_OAUTH_REDIRECT_URI` | Optional Notion OAuth callback URL |
| `MICROSOFT_OAUTH_CLIENT_ID` | Microsoft 365 client ID |
| `MICROSOFT_OAUTH_CLIENT_SECRET` | Microsoft 365 client secret |
| `MICROSOFT_OAUTH_REDIRECT_URI` | Optional Microsoft OAuth callback URL |
| `MICROSOFT_OAUTH_TENANT_ID` | Entra tenant selector (default: `common`) |
| `SLACK_OAUTH_CLIENT_ID` | Slack client ID |
| `SLACK_OAUTH_CLIENT_SECRET` | Slack client secret |
| `SLACK_OAUTH_REDIRECT_URI` | Optional Slack OAuth callback URL |
| `FIGMA_OAUTH_CLIENT_ID` | Figma client ID |
| `FIGMA_OAUTH_CLIENT_SECRET` | Figma client secret |
| `FIGMA_OAUTH_REDIRECT_URI` | Optional Figma OAuth callback URL |
| `TRELLO_API_KEY` | Server-side Trello Power-Up key — if set, users only need their personal token |
| `SPOTIFY_OAUTH_CLIENT_ID` | Spotify client ID |
| `SPOTIFY_OAUTH_CLIENT_SECRET` | Spotify client secret |
| `SPOTIFY_OAUTH_REDIRECT_URI` | Optional Spotify OAuth callback URL |

## Messaging

Messaging platform credentials (Telegram, Discord, WhatsApp, Slack, etc.) are configured through the Flutter app messaging tab — not `.env`. The exception is Telnyx, which requires server-side webhook verification.

| Variable | Description |
|---|---|
| `TELNYX_WEBHOOK_TOKEN` | Telnyx webhook signature verification token |

Generic inbound webhook path: `PUBLIC_URL + /api/messaging/webhook/:platform`

## Service Email

Optional. When configured, NeoAgent uses SMTP for account flows: signup confirmation, password reset, and security notifications. This mailbox is for the NeoAgent server only — it is not exposed as a Gmail or Outlook integration.

| Variable | Default | Description |
|---|---:|---|
| `NEOAGENT_EMAIL_FROM` | required | Sender address, e.g. `NeoAgent <no-reply@example.com>` |
| `NEOAGENT_EMAIL_SMTP_HOST` | required | SMTP hostname |
| `NEOAGENT_EMAIL_SMTP_PORT` | `587` | SMTP port |
| `NEOAGENT_EMAIL_SMTP_USER` | optional | SMTP username |
| `NEOAGENT_EMAIL_SMTP_PASS` | optional | SMTP password or app password |
| `NEOAGENT_EMAIL_SMTP_SECURE` | `true` on port 465 | Use implicit TLS |
| `NEOAGENT_EMAIL_SMTP_REQUIRE_TLS` | `true` | Require STARTTLS |
| `NEOAGENT_EMAIL_SMTP_REJECT_UNAUTHORIZED` | `true` | Reject invalid TLS certs — keep enabled in production |
| `NEOAGENT_EMAIL_REPLY_TO` | optional | Reply-To header |
| `NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION` | `true` | Require email confirmation before first sign-in |
| `NEOAGENT_EMAIL_REQUIRE_EMAIL_CHANGE_CONFIRMATION` | `true` | Require confirmation when changing account email |
| `NEOAGENT_EMAIL_NOTIFY_UNUSUAL_LOGIN` | `true` | Security notice for new device or network logins |
| `NEOAGENT_EMAIL_NOTIFY_ACCOUNT_CHANGES` | `true` | Notices for password and email changes |
| `NEOAGENT_EMAIL_BRAND_NAME` | `NeoAgent` | Display name in email templates |
| `NEOAGENT_EMAIL_SUPPORT_URL` | optional | Support link for email templates |
| `NEOAGENT_EMAIL_TOKEN_TTL_HOURS` | `24` | Confirmation link expiry |

## Runtime Isolation

| Variable | Description |
|---|---|
| `NEOAGENT_VM_GUEST_TOKEN` | Required for `secure-vm` policy — use 32+ characters, no placeholder values |

Runtime profiles (`trusted-host`, `secure-vm`) are set in user settings, not `.env`. See [Capabilities: Runtime Modes](capabilities.md#runtime-modes).

## Runtime Paths

| Path | Contents |
|---|---|
| `~/.neoagent/.env` | Server config and secrets |
| `~/.neoagent/data/` | Database, sessions, logs, update status |
| `~/.neoagent/agent-data/` | Skills, memory, daily data |

## Security

Treat `SESSION_SECRET`, all API keys, OAuth client secrets, SMTP credentials, and messaging tokens as sensitive. Don't commit them, log them, or expose them in client code or screenshots. Rotate immediately if you suspect exposure.
