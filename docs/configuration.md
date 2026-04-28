# Configuration

NeoAgent keeps deployment secrets on the server. The default config file is `~/.neoagent/.env`; run `neoagent setup` to regenerate it interactively. You can move the runtime root by setting `NEOAGENT_HOME`.

AI provider credentials, OAuth client secrets, and deployment controls are not configured through the public web client. The Flutter UI can select providers and models, but the secrets stay in server-side environment variables or in the local NeoAgent database where the app explicitly stores channel settings.

## Core Variables

| Variable | Default | Description |
|---|---:|---|
| `PORT` | `3333` | HTTP port for the NeoAgent server. |
| `PUBLIC_URL` | optional | Public base URL used for OAuth callbacks and external links. |
| `SESSION_SECRET` | required | Random string for session signing. Generate one with `openssl rand -hex 32`. |
| `NODE_ENV` | `production` | Set to `development` to enable verbose logs. |
| `SECURE_COOKIES` | `false` | Set `true` when NeoAgent is behind a TLS-terminating proxy. |
| `TRUST_PROXY` | inferred from `PUBLIC_URL`/`SECURE_COOKIES` | Set `true` when NeoAgent runs behind Nginx, Caddy, Cloudflare, Fly, or another reverse proxy that sends `X-Forwarded-*` headers. |
| `ALLOWED_ORIGINS` | none | Comma-separated CORS origins, for example `https://example.com`. |
| `NEOAGENT_DEPLOYMENT_MODE` | `self_hosted` | `self_hosted` enables in-app update controls; `managed` hides operator-only controls for SaaS deployments. |
| `NEOAGENT_RELEASE_CHANNEL` | `stable` | Release track used by the self-hosted updater. |

## Service Email

Service email is optional. When `NEOAGENT_EMAIL_FROM` and `NEOAGENT_EMAIL_SMTP_HOST` are set, NeoAgent uses SMTP for account security flows: signup confirmation, password reset, unusual login notifications, password change notifications, and email change notifications. Confirmation and reset links use the same `PUBLIC_URL` base as the other server-generated links.

This mailbox is only for the NeoAgent server. The agent cannot read, search, or send from it, and it is not exposed as a Gmail, Outlook, or messaging integration account. Configure Gmail/Outlook tools separately under official integrations if you want the agent to work with a mailbox.

| Variable | Default | Description |
|---|---:|---|
| `NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION` | `true` when enabled | Requires new signup email confirmation before sign-in. |
| `NEOAGENT_EMAIL_REQUIRE_EMAIL_CHANGE_CONFIRMATION` | `true` when enabled | Requires account email changes to be confirmed by the new address. |
| `NEOAGENT_EMAIL_NOTIFY_UNUSUAL_LOGIN` | `true` | Sends a security notice when a login uses a new device or network pattern. |
| `NEOAGENT_EMAIL_NOTIFY_ACCOUNT_CHANGES` | `true` | Sends notices for password and email changes. |
| `NEOAGENT_EMAIL_BRAND_NAME` | `NeoAgent` | Display name used by service email templates. |
| `NEOAGENT_EMAIL_SUPPORT_URL` | optional | Optional operator support URL reserved for service email templates. |
| `NEOAGENT_EMAIL_TOKEN_TTL_HOURS` | `24` | Confirmation link lifetime. |
| `NEOAGENT_EMAIL_FROM` | required when enabled | Sender header, for example `NeoAgent <no-reply@example.com>`. |
| `NEOAGENT_EMAIL_REPLY_TO` | optional | Reply-To header. |
| `NEOAGENT_EMAIL_SMTP_HOST` | required when enabled | SMTP hostname. |
| `NEOAGENT_EMAIL_SMTP_PORT` | `587` | SMTP port. |
| `NEOAGENT_EMAIL_SMTP_SECURE` | `true` on port `465` | Use implicit TLS. |
| `NEOAGENT_EMAIL_SMTP_REQUIRE_TLS` | `true` unless implicit TLS | Require STARTTLS for non-implicit-TLS SMTP. |
| `NEOAGENT_EMAIL_SMTP_REJECT_UNAUTHORIZED` | `true` | Reject invalid TLS certificates. Keep enabled in production. |
| `NEOAGENT_EMAIL_SMTP_USER` | optional | SMTP username. |
| `NEOAGENT_EMAIL_SMTP_PASS` | optional | SMTP password or app password. |

## AI Providers

At least one hosted-provider API key is required unless you only use local Ollama. The active provider and model routing are selected in the app, but credentials are read from server-side config.

| Variable | Provider |
|---|---|
| `ANTHROPIC_API_KEY` | Claude (Anthropic) |
| `OPENAI_API_KEY` | GPT and Whisper (OpenAI) |
| `XAI_API_KEY` | Grok (xAI) |
| `XAI_BASE_URL` | Optional xAI-compatible base URL override |
| `GOOGLE_AI_KEY` | Gemini (Google) |
| `MINIMAX_API_KEY` | MiniMax Code, including `MiniMax-M2.7` |
| `BRAVE_SEARCH_API_KEY` | Brave Search API for the native `web_search` tool |
| `OPENAI_BASE_URL` | Optional OpenAI-compatible base URL override |
| `ANTHROPIC_BASE_URL` | Optional Anthropic-compatible base URL override |
| `DEEPGRAM_API_KEY` | Recordings transcription with Deepgram |
| `DEEPGRAM_BASE_URL` | Optional Deepgram API base URL override |
| `DEEPGRAM_MODEL` | Deepgram speech model override, defaults to `nova-3` |
| `DEEPGRAM_LANGUAGE` | Deepgram language override, defaults to `multi` |
| `OLLAMA_URL` | Local Ollama server, usually `http://localhost:11434` |

Recording insight generation is controlled in app AI settings with `auto_recording_insights`. It uses the configured AI providers after Deepgram transcription has produced transcript text.

## Official Integrations

Official integrations use OAuth or provider-native account linking and expose structured tools to the agent. The built-in registry currently covers Google Workspace, Notion, Microsoft 365, Slack, Figma, Home Assistant, Trello, Weather, Spotify, and personal WhatsApp.

All OAuth callbacks default to `PUBLIC_URL + /api/integrations/oauth/callback` unless you set a provider-specific redirect URI.

| Variable | Description |
|---|---|
| `GOOGLE_OAUTH_CLIENT_ID` | Google Workspace OAuth client ID |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Google Workspace OAuth client secret |
| `GOOGLE_OAUTH_REDIRECT_URI` | Optional Google Workspace OAuth callback URL |
| `NOTION_OAUTH_CLIENT_ID` | Notion OAuth client ID |
| `NOTION_OAUTH_CLIENT_SECRET` | Notion OAuth client secret |
| `NOTION_OAUTH_REDIRECT_URI` | Optional Notion OAuth callback URL |
| `MICROSOFT_OAUTH_CLIENT_ID` | Microsoft 365 OAuth client ID |
| `MICROSOFT_OAUTH_CLIENT_SECRET` | Microsoft 365 OAuth client secret |
| `MICROSOFT_OAUTH_REDIRECT_URI` | Optional Microsoft 365 OAuth callback URL |
| `MICROSOFT_OAUTH_TENANT_ID` | Optional Entra tenant selector, defaults to `common` |
| `SLACK_OAUTH_CLIENT_ID` | Slack OAuth client ID |
| `SLACK_OAUTH_CLIENT_SECRET` | Slack OAuth client secret |
| `SLACK_OAUTH_REDIRECT_URI` | Optional Slack OAuth callback URL |
| `FIGMA_OAUTH_CLIENT_ID` | Figma OAuth client ID |
| `FIGMA_OAUTH_CLIENT_SECRET` | Figma OAuth client secret |
| `FIGMA_OAUTH_REDIRECT_URI` | Optional Figma OAuth callback URL |
| `HOME_ASSISTANT_BASE_URL` | Optional fallback Home Assistant base URL. Users can configure this per account in Official Integrations. |
| `HOME_ASSISTANT_OAUTH_CLIENT_ID` | Optional fallback Home Assistant OAuth client ID. |
| `HOME_ASSISTANT_OAUTH_CLIENT_SECRET` | Optional fallback Home Assistant OAuth client secret. |
| `HOME_ASSISTANT_OAUTH_REDIRECT_URI` | Optional fallback Home Assistant OAuth callback URL. |
| `HOME_ASSISTANT_ALLOW_PRIVATE_BASE_URL` | Optional safety override. Set to `1` only if you intentionally allow Home Assistant base URLs on localhost/private networks. |
| `TRELLO_API_KEY` | Optional Trello Power-Up API key. If set, users only need to provide their personal token in Official Integrations. |
| `SPOTIFY_OAUTH_CLIENT_ID` | Spotify OAuth client ID |
| `SPOTIFY_OAUTH_CLIENT_SECRET` | Spotify OAuth client secret |
| `SPOTIFY_OAUTH_REDIRECT_URI` | Optional Spotify OAuth callback URL |

Home Assistant and Trello no longer require server-side setup. Each user can open Official Integrations and enter their own provider-specific credentials in the Flutter UI.
For safety, local/private Home Assistant targets are blocked by default unless `HOME_ASSISTANT_ALLOW_PRIVATE_BASE_URL=1` is set on the server.

Trello integration is flexible: users can provide both API key and token in the UI, or if `TRELLO_API_KEY` is set as a server environment variable, users only need to authenticate with their personal token. Tokens are stored securely per user and are never added to server environment variables.

Weather integration uses Open-Meteo public endpoints and does not require OAuth environment variables.

## Messaging

Messaging platform credentials are stored through the Flutter app messaging tab, not in `.env`. This includes Telegram, Discord, Slack, Google Chat, Microsoft Teams, Matrix, Signal, iMessage/BlueBubbles, IRC, Twitch, LINE, Mattermost, and the configurable webhook bridges. Use the app to set platform tokens, webhook URLs, inbound secrets, polling options, and access lists.

Generic inbound messaging callbacks use:

```text
PUBLIC_URL + /api/messaging/webhook/:platform
```

Telnyx webhook verification is configured through the environment.

| Variable | Description |
|---|---|
| `TELNYX_WEBHOOK_TOKEN` | Telnyx webhook signature verification token |

## Runtime Isolation

Runtime profile and backend selection are stored in user settings, not normally in `.env`. The main profiles are `trusted-host` and `secure-vm`. They control whether CLI, browser, and Android tools run on the host or through the local VM backend.

Production policy can require the VM backend. In that case, set a strong `NEOAGENT_VM_GUEST_TOKEN` of at least 32 characters and avoid placeholder values.

The app exposes two browser backend choices: Cloud and Chrome extension. Cloud uses the current deployment policy, which means host browser control for trusted private installs and VM browser control for isolated production installs. Chrome extension uses the paired extension connection instead of the server-local Puppeteer browser. To install only the extension on a remote machine, open NeoAgent, download `/api/browser-extension/download`, unzip it, load the folder through `chrome://extensions` with Developer mode enabled, then pair after logging in to NeoAgent. Unpacked Chrome extensions cannot replace themselves automatically; use the extension popup's update check to compare against the server bundle, then download and reload the latest ZIP when needed.

## Secrets Guidance

Treat `SESSION_SECRET`, provider API keys, OAuth client secrets, service email SMTP credentials, messaging credentials, and Telnyx tokens as sensitive. Do not commit them, print them in logs, or expose them in client-side code. Store them in server-side environment variables or a secrets manager, restrict access to operators who need them, and rotate them immediately if you suspect exposure.

## Runtime Paths

| Path | Purpose |
|---|---|
| `~/.neoagent/.env` | Server config and deployment secrets |
| `~/.neoagent/data/` | Database, sessions, update status, and logs |
| `~/.neoagent/agent-data/` | Skills, memory, and daily data files |

## Minimal `.env` Example

```dotenv
PORT=3333
SESSION_SECRET=change-me-to-something-random
ANTHROPIC_API_KEY=sk-ant-...
```
