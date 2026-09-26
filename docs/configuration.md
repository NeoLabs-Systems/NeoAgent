---
title: Configuration reference
sidebar_label: Configuration
description: Every environment variable NeoAgent reads, grouped by purpose.
---

# Configuration reference

*The full list of server variables, grouped by what they configure.*

NeoAgent reads server configuration from `~/.neoagent/.env`. Set
`NEOAGENT_HOME` before installation to use another runtime root.

Prefer the setup wizard or environment CLI over manual file edits:

```bash
neoagent setup
neoagent setup --quick
neoagent setup --full
neoagent env list
```

Use `neoagent env set` or `neoagent env unset` with the variable named in the
tables below. Restart NeoAgent after changing values that are only read during
startup.

## 🖧 Core server

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | first available preferred port | HTTP port |
| `PUBLIC_URL` | unset | Public HTTPS base URL for remote clients, OAuth, and webhooks |
| `SESSION_SECRET` | required | Session-signing secret |
| `NODE_ENV` | `production` | Node environment |
| `SECURE_COOKIES` | inferred | Require secure session cookies |
| `TRUST_PROXY` | inferred | Trust proxy headers from the deployment proxy |
| `ALLOWED_ORIGINS` | unset | Additional comma-separated CORS origins |
| `NEOAGENT_ADMIN_USERS` | unset | Comma-separated usernames granted admin on every start (never revoked by removal) |
| `NEOAGENT_RELEASE_CHANNEL` | `stable` | Update channel |
| `NEOAGENT_SETUP_PROFILE` | `quick` | Last selected setup profile |
| `NEOAGENT_SETUP_COMPLETED_SECTIONS` | `core` | Non-secret setup completion state |

Generate a session secret before setting it:

```bash
neoagent env set SESSION_SECRET "$(openssl rand -hex 32)"
```

## 🧠 Model providers

| Variable | Provider or feature |
| --- | --- |
| `ANTHROPIC_API_KEY` | Anthropic |
| `OPENAI_API_KEY` | OpenAI and supported embedding/transcription paths |
| `OPENAI_COMPATIBLE_API_KEY` | Custom OpenAI-compatible provider token |
| `OPENAI_COMPATIBLE_BASE_URL` | Custom OpenAI-compatible provider base URL (required with its token) |
| `GOOGLE_AI_KEY` | Google Gemini and supported embeddings |
| `XAI_API_KEY` | xAI |
| `MINIMAX_API_KEY` | MiniMax |
| `NVIDIA_API_KEY` | NVIDIA NIM |
| `OPENROUTER_API_KEY` | OpenRouter |
| `NEOAGENT_JEV` | Jev decision model policy: `agent` (default, each agent decides), `on`, or `off`. See [Jev decisions](models.md#-jev-decisions) |
| `OPENAI_BASE_URL` | OpenAI-compatible base URL override |
| `ANTHROPIC_BASE_URL` | Anthropic-compatible base URL override |
| `OLLAMA_URL` | Ollama server URL |
| `BRAVE_SEARCH_API_KEY` | Web search |
| `DEEPGRAM_API_KEY` | Voice-note and dictation transcription |
| `VOICE_LIVE_PROVIDER` | Default live voice model provider: `openai` (GPT-Live, default) or `google` (Gemini Live) |
| `VOICE_LIVE_MODEL` | Default live voice model; blank uses `gpt-live-1` or `gemini-3.8-live` |
| `VOICE_LIVE_VOICE` | Default live voice; blank uses the provider's default voice |

Account-backed model providers use `neoagent login`, not these API-key fields.

## 🔌 Official integrations

| Variable prefix | Integration |
| --- | --- |
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
`PUBLIC_URL/api/integrations/oauth/callback`. Home Assistant, Nextcloud, and
personal Trello credentials are configured through the application.

## 📧 Service email

SMTP is optional. When configured, it supports account confirmation, password
reset, email changes, and security notifications.

| Variable | Purpose |
| --- | --- |
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

## 💳 Billing

Billing is disabled by default. Use the interactive wizard to configure it:

```bash
neoagent billing setup    # guided Stripe key and webhook setup
neoagent billing          # show current status
neoagent billing enable   # activate billing and restart
neoagent billing disable  # deactivate billing and restart
```

See [Billing](billing.md) for the full setup guide, webhook configuration, and
plan management.

| Variable | Default | Purpose |
| --- | --- | --- |
| `NEOAGENT_BILLING_ENABLED` | `false` | Enable the Stripe billing system |
| `STRIPE_SECRET_KEY` | unset | Stripe server-side API key |
| `STRIPE_PUBLISHABLE_KEY` | unset | Stripe client-side key (returned to clients) |
| `STRIPE_WEBHOOK_SECRET` | unset | Webhook signing secret |
| `BILLING_TRIAL_DAYS` | `14` | Free trial length in days |

## 🖥️ Isolated runtime

| Variable | Purpose |
| --- | --- |
| `TERMINAL_ENV` | Where computers run: `qemu` (default), `docker`, or `host` |
| `NEOAGENT_VM_BASE_IMAGE_URL` | Download source for the guest image |
| `NEOAGENT_VM_BASE_IMAGE` | Existing local guest image |
| `NEOAGENT_VM_GUEST_TOKEN` | Server-to-runtime authentication token |
| `NEOAGENT_VM_MEMORY_MB` | Guest memory allocation |
| `NEOAGENT_VM_CPUS` | Guest CPU allocation |
| `NEOAGENT_GUEST_BASE_IMAGE` | Base image for the Docker guest build |

`TERMINAL_ENV=docker` gives every user a Docker container instead of a QEMU
micro-VM. The container runs the same guest agent from the same payload, so
shell, browser, and file tools behave identically; it starts in seconds and
needs no guest image download, but it shares the host kernel and offers no
desktop view. `neoagent repair` builds the guest image for whichever backend is
selected. The memory and CPU allocation settings apply to both.

`TERMINAL_ENV=host` runs the agent on the server itself, through the same
desktop-companion path the desktop app uses: the server registers itself as
every account's companion, and shell commands run in that account's workspace
directory. There is no guest to prepare and nothing to download, so a computer
is ready immediately — but there is **no isolation**: every account's agent runs
as the server's own OS user with that user's full access to the machine, and
accounts are not separated from each other. Only the shell and workspace file
tools are available; there is no browser or desktop. The server logs a warning
naming the host on every start, and only grants accounts you would trust with a
shell on that machine.

:::danger Do not reuse example values
The installer generates the guest token. Do not reuse the example values from
documentation or issue reports.
:::

## 💬 Messaging

Messaging credentials are normally configured in **Settings > Messaging**.

## 📁 Runtime paths

| Path | Contents |
| --- | --- |
| `~/.neoagent/.env` | Configuration and secrets |
| `~/.neoagent/data/` | Database, sessions, logs, update state |
| `~/.neoagent/agent-data/` | Skills, memory files, daily data |

The canonical complete variable list and comments are in
[`.env.example`](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/.env.example).
