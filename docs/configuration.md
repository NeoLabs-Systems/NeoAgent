# Configuration

All settings live in `.env` at the project root. Run `./neo.sh setup` to regenerate interactively.

## Variables

### Core

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3060` | HTTP port |
| `SESSION_SECRET` | *(required)* | Random string for session signing — generate with `openssl rand -hex 32` |
| `NODE_ENV` | `production` | Set to `development` to enable verbose logs |
| `SECURE_COOKIES` | `false` | Set `true` when behind a TLS-terminating proxy |
| `ALLOWED_ORIGINS` | *(none)* | Comma-separated CORS origins, e.g. `https://example.com` |

### AI Providers

At least one API key is required. The active provider and model are configured in the web UI.

| Variable | Provider |
|---|---|
| `ANTHROPIC_API_KEY` | Claude (Anthropic) |
| `OPENAI_API_KEY` | GPT-4o / Whisper (OpenAI) |
| `XAI_API_KEY` | Grok (xAI) |
| `GOOGLE_AI_KEY` | Gemini (Google) |
| `OLLAMA_URL` | Local Ollama (`http://localhost:11434`) |

### Messaging

| Variable | Description |
|---|---|
| `TELNYX_WEBHOOK_TOKEN` | Telnyx webhook signature verification |

Telegram, Discord, and WhatsApp tokens are stored in the database via the web UI Settings page — not in `.env`.

---

## Minimal `.env` example

```dotenv
PORT=3060
SESSION_SECRET=change-me-to-something-random
ANTHROPIC_API_KEY=sk-ant-...
```
