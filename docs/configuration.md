# Configuration

All settings live in `~/.neoagent/.env` by default. Run `neoagent setup` to regenerate interactively. AI provider credentials are configured through the server environment or `neoagent setup`, not through the web UI. If a self-edit or local install issue leaves NeoAgent broken, rerun setup or restore the env file and restart the service.
You can override the runtime root with `NEOAGENT_HOME`.

## Variables

### Core

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3333` | HTTP port |
| `PUBLIC_URL` | *(optional)* | Public base URL used for callbacks and external links |
| `SESSION_SECRET` | *(required)* | Random string for session signing — generate with `openssl rand -hex 32` |
| `NODE_ENV` | `production` | Set to `development` to enable verbose logs |
| `SECURE_COOKIES` | `false` | Set `true` when behind a TLS-terminating proxy |
| `ALLOWED_ORIGINS` | *(none)* | Comma-separated CORS origins, e.g. `https://example.com` |
| `NEOAGENT_DEPLOYMENT_MODE` | `self_hosted` | `self_hosted` enables in-app update controls; `managed` hides operator-only controls for SaaS deployments |
| `NEOAGENT_RELEASE_CHANNEL` | `stable` | Release track used by the self-hosted updater |

### AI Providers

At least one hosted-provider API key is required unless you only use local Ollama. The active provider and model routing are configured in the Flutter app; credentials stay in server-side config.

| Variable | Provider |
|---|---|
| `ANTHROPIC_API_KEY` | Claude (Anthropic) |
| `OPENAI_API_KEY` | GPT-4o / Whisper (OpenAI) |
| `XAI_API_KEY` | Grok (xAI) |
| `XAI_BASE_URL` | Optional xAI-compatible base URL override |
| `GOOGLE_AI_KEY` | Gemini (Google) |
| `GOOGLE_OAUTH_CLIENT_ID` | Google Workspace official integrations OAuth client ID |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Google Workspace official integrations OAuth client secret |
| `GOOGLE_OAUTH_REDIRECT_URI` | Optional override for the Google Workspace OAuth callback URL |
| `MINIMAX_API_KEY` | MiniMax Code (Coding Plan / Token Plan for `MiniMax-M2.7`) |
| `BRAVE_SEARCH_API_KEY` | Brave Search API for the native `web_search` tool |
| `OPENAI_BASE_URL` | Optional OpenAI-compatible base URL override |
| `ANTHROPIC_BASE_URL` | Optional Anthropic-compatible base URL override |
| `DEEPGRAM_API_KEY` | Recordings transcription with Deepgram Nova-3 multilingual |
| `DEEPGRAM_BASE_URL` | Optional Deepgram API base URL override |
| `DEEPGRAM_MODEL` | Deepgram speech model override (defaults to `nova-3`) |
| `DEEPGRAM_LANGUAGE` | Deepgram language override (defaults to `multi`) |
| `OLLAMA_URL` | Local Ollama (`http://localhost:11434`) |

### Messaging

| Variable | Description |
|---|---|
| `TELNYX_WEBHOOK_TOKEN` | Telnyx webhook signature verification |

Telegram, Discord, and WhatsApp tokens are stored in the database via the Flutter app settings page — not in `.env`.

## Runtime data paths

- Config: `~/.neoagent/.env`
- Database/session/logs: `~/.neoagent/data/`
- Skills/memory/daily data files: `~/.neoagent/agent-data/`

---

## Minimal `.env` example

```dotenv
PORT=3333
SESSION_SECRET=change-me-to-something-random
ANTHROPIC_API_KEY=sk-ant-...
```
