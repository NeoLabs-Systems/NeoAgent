---
title: Configuration reference
sidebar_label: Configuration
description: Every environment variable NeoAgent reads, grouped by purpose.
---

# Configuration reference

**Every server setting NeoAgent reads from its environment file, with its default and what needs it.**

## 🛠️ Change a setting

- **The file.** `~/.neoagent/.env`, or `.env` under `NEOAGENT_HOME`.
- **The app.** The **Admin** tabs (Providers, Integrations, Configuration) write the same file. Desktop installs have no CLI, so use these.
- **Restart afterwards.** Most values are read once at startup.

```bash
neoagent env list               # every value, secrets masked
neoagent env get PORT           # one value, unmasked
neoagent env set PORT 3400
neoagent env unset PORT
neoagent restart
```

- **Nothing is required to start.** Secrets are generated on first start. **Required** below marks values a feature can't work without.
- **Setup bookkeeping.** `NEOAGENT_SETUP_PROFILE` and `NEOAGENT_SETUP_COMPLETED_SECTIONS` are written by setup. Leave them alone.

## 🖧 Core server {#core-server}

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `3333`, or the next free port at setup | HTTP port |
| `PUBLIC_URL` | unset | Public base URL for OAuth callbacks, email links and the address users are given |
| `ALLOWED_ORIGINS` | unset: loopback origins only | Comma-separated browser origins allowed to sign in and save changes. Once set, list `http://localhost:<PORT>` too |
| `SECURE_COOKIES` | `true` when `PUBLIC_URL` starts with `https://` | HTTPS-only session cookies. Setup writes `false` when there is no `PUBLIC_URL` |
| `TRUST_PROXY` | follows `SECURE_COOKIES` | Trust the reverse proxy's forwarded headers |
| `NEOAGENT_HSTS_MAX_AGE` | `86400` | HSTS max-age in seconds, sent while secure cookies are on |
| `NODE_ENV` | `production` | Node environment |
| `NEOAGENT_INSTANCE_NAME` | host name | Name shown to nearby apps; read on first start only |
| `NEOAGENT_DISABLE_MDNS` | unset | `true` stops advertising `_neoagent._tcp.local` on the local network |

Exposing the server: see [Reach it from other devices](getting-started.md#network-access).

## 🔐 Secrets

| Variable | Default | Purpose |
| --- | --- | --- |
| `SESSION_SECRET` | generated on first start | Signs sessions; fallback key for both encryption keys below |
| `NEOAGENT_DATA_ENCRYPTION_KEY` | `SESSION_SECRET` | Encrypts local secrets at rest |
| `NEOAGENT_ENCRYPTION_KEY` | `SESSION_SECRET` | Encrypts official integration tokens |
| `NEOAGENT_VM_GUEST_TOKEN` | generated on first start | Authenticates the server to each cloud computer |

:::danger Keep secrets stable
- **Changing `SESSION_SECRET` signs everyone out.** Without the two dedicated encryption keys, stored credentials also become unreadable.
- **Never reuse example values** from docs or issue reports.
:::

## 👥 Accounts and limits

| Variable | Default | Purpose |
| --- | --- | --- |
| `NEOAGENT_ADMIN_USERS` | unset | Usernames made admin on every start. Removing a name does not revoke; use `neoagent admin revoke <user>` |
| `NEOAGENT_ALLOW_SIGNUP` | on | `false`, `0` or `no` makes new accounts need a one-time sign-up key from an admin. A server with no accounts always lets the first one register |
| `NEOAGENT_RATE_LIMIT_4H` | `2500000` | Tokens per user per rolling 4 hours |
| `NEOAGENT_RATE_LIMIT_WEEKLY` | `10000000` | Tokens per user per rolling 7 days |
| `NEOAGENT_DISABLE_RATE_LIMITS` | unset | `true` turns both limits off for everyone |

- **In the app.** Admins change the defaults and per-user limits in the **Admin** tab.
- **Own keys are exempt.** Models running on a user's [own key](models.md#byok) skip the server limits.

## 🔄 Updates and install location

| Variable | Default | Purpose |
| --- | --- | --- |
| `NEOAGENT_RELEASE_CHANNEL` | `stable` | `stable` or `beta`; change it with `neoagent channel` |
| `NEOAGENT_DEPLOYMENT_MODE` | `self_hosted` | `managed` turns off in-app updates |
| `NEOAGENT_HOME` | `~/.neoagent` | Runtime root. Set it in the shell before installing; the background service keeps it |
| `NEOAGENT_SOURCE_DIR` | `~/NeoAgent` | Where `neoagent update` moves an old package-style install |

## 🧠 Model providers

| Variable | Provider | Notes |
| --- | --- | --- |
| `OPENAI_API_KEY` | OpenAI | Also memory embeddings, voice-note transcription and GPT-Live calls |
| `ANTHROPIC_API_KEY` | Anthropic | |
| `GOOGLE_AI_KEY` | Google Gemini | Also embeddings, transcription and Gemini Live calls |
| `XAI_API_KEY` | xAI | Also image generation |
| `MINIMAX_API_KEY` | MiniMax Code | Coding Plan key |
| `NVIDIA_API_KEY` | NVIDIA NIM | |
| `OPENROUTER_API_KEY` | OpenRouter | Also SystemOne models |
| `TYPESAFE_API_KEY` | TypeSafe | SystemOne models only |
| `OPENAI_COMPATIBLE_API_KEY` | Custom OpenAI-compatible | **Required** with the base URL below |
| `OPENAI_COMPATIBLE_BASE_URL` | Custom OpenAI-compatible | **Required** with the key above |
| `OLLAMA_URL` | Ollama | Default `http://localhost:11434` |

| Endpoint override | Default |
| --- | --- |
| `OPENAI_BASE_URL` | OpenAI's API |
| `ANTHROPIC_BASE_URL` | Anthropic's API |
| `XAI_BASE_URL` | `https://api.x.ai/v1` |
| `OPENAI_CODEX_BASE_URL` | `https://chatgpt.com/backend-api/codex` |
| `GITHUB_COPILOT_BASE_URL` | `https://api.githubcopilot.com` |

- **Account sign-ins.** `neoagent login` writes `CLAUDE_CODE_OAUTH_TOKEN`, `OPENAI_CODEX_ACCESS_TOKEN`, `GITHUB_COPILOT_ACCESS_TOKEN` or `GROK_OAUTH_ACCESS_TOKEN`. See [Models](models.md#account-logins).

## 🎙️ Search, voice and media

| Variable | Default | Purpose |
| --- | --- | --- |
| `BRAVE_SEARCH_API_KEY` | unset | **Required** for the `web_search` tool |
| `DEEPGRAM_API_KEY` | unset | Voice-note and dictation transcription with Deepgram Nova-3 |
| `VOICE_LIVE_PROVIDER` | `openai` | Default live voice provider: `openai` (GPT-Live) or `google` (Gemini Live) |
| `VOICE_LIVE_MODEL` | newest live model the provider lists | Default live voice model |
| `VOICE_LIVE_VOICE` | `marin` (OpenAI), `Kore` (Google) | Default live voice |
| `YT_DLP_BIN` | `yt-dlp` | yt-dlp binary for video and audio downloads |
| `FFMPEG_BIN` | `ffmpeg` | ffmpeg binary for media conversion |

- **In the app.** Admins set the live voice defaults under **Admin › Integrations › Live voice**.
- **Per account.** Each account can pick its own live voice provider, model and voice under **Settings › Voice**.

## 🔌 Official integrations {#official-integrations}

- **Per user by default.** Each user registers their own OAuth app in the app; no server setup is needed.
- **Optional global app.** `<PREFIX>_OAUTH_CLIENT_ID` and `<PREFIX>_OAUTH_CLIENT_SECRET` (prefixes `GOOGLE`, `MICROSOFT`, `GITHUB`, `NOTION`, `SLACK`, `FIGMA`, `SPOTIFY`), or `TRELLO_API_KEY`, apply one app to every account, so users only connect their accounts. Set them under **Admin › Integrations**.
- **OpenRouter account sign-in.** The same category has an enable switch backed by `NEOAGENT_OPENROUTER_SIGN_IN_ENABLED` (default `true`). Disabling it blocks registration, login, and account linking immediately; existing sessions and model keys keep working.
- **No server setup.** Home Assistant and Nextcloud are connected per account in the app.
- **Messaging channels.** Configured per agent under **Settings › Messaging**, not here.

## 📧 Service email {#service-email}

Optional SMTP for account confirmation, password reset and security notices; the agent can't read or send from this mailbox.

| Variable | Default | Purpose |
| --- | --- | --- |
| `NEOAGENT_EMAIL_SMTP_HOST` | unset | **Required** to turn service email on |
| `NEOAGENT_EMAIL_FROM` | unset | **Required**; sender address |
| `NEOAGENT_EMAIL_SMTP_PORT` | `587` | SMTP port |
| `NEOAGENT_EMAIL_SMTP_USER` | unset | SMTP user |
| `NEOAGENT_EMAIL_SMTP_PASS` | unset | SMTP password |
| `NEOAGENT_EMAIL_SMTP_SECURE` | `true` on port 465, else `false` | Implicit TLS |
| `NEOAGENT_EMAIL_SMTP_REQUIRE_TLS` | opposite of `SECURE` | Require STARTTLS |
| `NEOAGENT_EMAIL_SMTP_REJECT_UNAUTHORIZED` | `true` | Reject invalid certificates |
| `NEOAGENT_EMAIL_REPLY_TO` | unset | Reply-To address |
| `NEOAGENT_EMAIL_BRAND_NAME` | `NeoAgent` | Name used in emails |
| `NEOAGENT_EMAIL_SUPPORT_URL` | unset | Support link in emails |
| `NEOAGENT_EMAIL_PUBLIC_URL` | `PUBLIC_URL` | Base URL for links in emails |
| `NEOAGENT_EMAIL_TOKEN_TTL_HOURS` | `24` | Confirmation and reset link lifetime |
| `NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION` | `true` | New accounts confirm their email |
| `NEOAGENT_EMAIL_REQUIRE_EMAIL_CHANGE_CONFIRMATION` | `true` | Email changes are confirmed |
| `NEOAGENT_EMAIL_NOTIFY_UNUSUAL_LOGIN` | `true` | Alert on unusual sign-ins |
| `NEOAGENT_EMAIL_NOTIFY_ACCOUNT_CHANGES` | `true` | Alert on account changes |

The confirmation and notification switches apply only once SMTP is configured.

## 🖥️ Cloud computer

| Variable | Default | Purpose |
| --- | --- | --- |
| `TERMINAL_ENV` | `qemu` | Where each user's cloud computer runs: `qemu`, `docker` or `host` |
| `NEOAGENT_VM_BASE_IMAGE` | unset | Local guest image to use instead of the pinned Debian image (`qemu`) |
| `NEOAGENT_GUEST_BASE_IMAGE` | `node:22-bookworm-slim` | Base image for the guest build (`docker`) |
| `NEOAGENT_COMPUTER_MAX_MEMORY_MB` | `2560` | Most memory one computer gets; also set under **Admin › Configuration** |
| `NEOAGENT_COMPUTER_MIN_MEMORY_MB` | `1536` | Least memory one computer needs; limits how many run at once |
| `NEOAGENT_COMPUTER_MAX_CPUS` | `2` | Most vCPUs per computer; also set under **Admin › Configuration** |
| `NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_PERCENT` | `25` | Host memory kept free, at least `NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_MB` (default `2048`) |
| `NEOAGENT_COMPUTER_MIN_DISK_GIB` | `6` | Smallest disk per computer |
| `NEOAGENT_COMPUTER_MAX_DISK_GIB` | `12` | Largest disk per computer |
| `NEOAGENT_COMPUTER_STORAGE_RESERVE_PERCENT` | `20` | Free disk space kept for the host |
| `NEOAGENT_VM_IDLE_TIMEOUT_MS` | `600000` | Idle time before a computer shuts down |

| `TERMINAL_ENV` | Isolation | Trade-offs |
| --- | --- | --- |
| `qemu` | Per-user micro-VM | Desktop view; downloads a pinned Debian image (about 1 GB); fast with KVM, HVF or WHPX |
| `docker` | Per-user container | Starts in seconds; builds a local image instead of downloading one; shares the host kernel; no desktop view |
| `host` | None | Runs as the server's OS user; shell and workspace files only; one trusted account |

- **Switching backends.** Run `neoagent repair` afterwards; it prepares the guest for the selected backend.
- **`host` warning.** The server logs a warning naming the machine on every start.

## 📁 Runtime paths

| Path | Contents |
| --- | --- |
| `~/.neoagent/.env` | Settings and secrets |
| `~/.neoagent/data/` | SQLite database, logs, cloud computer disks |
| `~/.neoagent/agent-data/` | Skills and memory files |
| `~/.neoagent/backups/` | Backups from `neoagent backup`, `update` and `repair` |

The commented template is [`.env.example`](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/.env.example).
