# Configuration reference

NeoAgent reads server configuration from `~/.neoagent/.env`. Set
`NEOAGENT_HOME` before installation to use another runtime root.

Prefer the setup wizard or environment CLI over manual file edits:

```bash
neoagent setup
neoagent env list
```

Use `neoagent env set` or `neoagent env unset` with the variable named in the
tables below. Restart NeoAgent after changing values that are only read during
startup.

## Core server

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `3333` | HTTP port |
| `PUBLIC_URL` | unset | Public HTTPS base URL for remote clients, OAuth, and webhooks |
| `SESSION_SECRET` | required | Session-signing secret |
| `NODE_ENV` | `production` | Node environment |
| `SECURE_COOKIES` | inferred | Require secure session cookies |
| `TRUST_PROXY` | inferred | Trust proxy headers from the deployment proxy |
| `ALLOWED_ORIGINS` | unset | Additional comma-separated CORS origins |
| `NEOAGENT_PROFILE` | `prod` | Deployment/runtime policy profile |
| `NEOAGENT_RELEASE_CHANNEL` | `stable` | Update channel |

Generate a session secret before setting it:

```bash
neoagent env set SESSION_SECRET "$(openssl rand -hex 32)"
```

## Model providers

| Variable | Provider or feature |
|---|---|
| `ANTHROPIC_API_KEY` | Anthropic |
| `OPENAI_API_KEY` | OpenAI and supported embedding/transcription paths |
| `GOOGLE_AI_KEY` | Google Gemini and supported embeddings |
| `XAI_API_KEY` | xAI |
| `MINIMAX_API_KEY` | MiniMax |
| `NVIDIA_API_KEY` | NVIDIA NIM |
| `OPENROUTER_API_KEY` | OpenRouter |
| `OPENAI_BASE_URL` | OpenAI-compatible base URL override |
| `ANTHROPIC_BASE_URL` | Anthropic-compatible base URL override |
| `OLLAMA_URL` | Ollama server URL |
| `BRAVE_SEARCH_API_KEY` | Web search |
| `DEEPGRAM_API_KEY` | Recording transcription |
| `DEEPGRAM_BASE_URL` | Deepgram-compatible base URL override |
| `DEEPGRAM_MODEL` | Speech model |
| `DEEPGRAM_LANGUAGE` | Speech language mode |

Account-backed model providers use `neoagent login`, not these API-key fields.

## Official integrations

| Variable prefix | Integration |
|---|---|
| `GOOGLE_OAUTH_` | Google Workspace |
| `MICROSOFT_OAUTH_` | Microsoft 365 |
| `GITHUB_OAUTH_` | GitHub |
| `NOTION_OAUTH_` | Notion |
| `SLACK_OAUTH_` | Slack |
| `FIGMA_OAUTH_` | Figma |
| `SPOTIFY_OAUTH_` | Spotify |
| `TRELLO_API_KEY` | Shared Trello application key |

OAuth providers generally use a client ID, client secret, and optional redirect
URI. The default callback is
`PUBLIC_URL/api/integrations/oauth/callback`. Home Assistant and personal
Trello credentials are configured through the application.

## Service email

SMTP is optional. When configured, it supports account confirmation, password
reset, email changes, and security notifications.

| Variable | Purpose |
|---|---|
| `NEOAGENT_EMAIL_FROM` | Sender address |
| `NEOAGENT_EMAIL_SMTP_HOST` | SMTP host |
| `NEOAGENT_EMAIL_SMTP_PORT` | SMTP port |
| `NEOAGENT_EMAIL_SMTP_USER` | SMTP user |
| `NEOAGENT_EMAIL_SMTP_PASS` | SMTP password |
| `NEOAGENT_EMAIL_SMTP_SECURE` | Implicit TLS |
| `NEOAGENT_EMAIL_SMTP_REQUIRE_TLS` | Require STARTTLS |
| `NEOAGENT_EMAIL_SMTP_REJECT_UNAUTHORIZED` | Reject invalid certificates |
| `NEOAGENT_EMAIL_REPLY_TO` | Reply-To address |
| `NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION` | Confirm new accounts |
| `NEOAGENT_EMAIL_REQUIRE_EMAIL_CHANGE_CONFIRMATION` | Confirm email changes |
| `NEOAGENT_EMAIL_NOTIFY_UNUSUAL_LOGIN` | Notify on unusual login |
| `NEOAGENT_EMAIL_NOTIFY_ACCOUNT_CHANGES` | Notify on account changes |
| `NEOAGENT_EMAIL_PUBLIC_URL` | Base URL used in email links |
| `NEOAGENT_EMAIL_TOKEN_TTL_HOURS` | Confirmation token lifetime |

## Isolated runtime

| Variable | Purpose |
|---|---|
| `NEOAGENT_VM_BASE_IMAGE_URL` | Download source for the guest image |
| `NEOAGENT_VM_BASE_IMAGE` | Existing local guest image |
| `NEOAGENT_VM_GUEST_TOKEN` | Server-to-runtime authentication token |
| `NEOAGENT_VM_MEMORY_MB` | Guest memory allocation |
| `NEOAGENT_VM_CPUS` | Guest CPU allocation |

The installer generates the guest token. Do not reuse the example values from
documentation or issue reports.

## Messaging

Messaging credentials are normally configured in **Settings > Messaging**.
`TELNYX_WEBHOOK_TOKEN` remains a server environment value for Telnyx webhook
verification.

## Runtime paths

| Path | Contents |
|---|---|
| `~/.neoagent/.env` | Configuration and secrets |
| `~/.neoagent/data/` | Database, sessions, logs, update state |
| `~/.neoagent/agent-data/` | Skills, memory files, daily data |

The canonical complete variable list and comments are in
[`.env.example`](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/.env.example).
