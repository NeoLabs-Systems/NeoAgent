---
title: Models and providers
sidebar_label: Models
description: Configure local, API-key, and account-backed model providers, and keep credentials on the server.
---

# Models and providers

**Connect the models NeoAgent thinks with: API keys, a local Ollama server, or AI accounts you already pay for.**

## ⚙️ Where to set things

| Where | Applies to | Use it for |
| --- | --- | --- |
| **Admin › Providers** | Every account | Server-wide keys and endpoints |
| **Admin › Models** | Every account | Which chat and SystemOne models accounts may pick |
| **Settings › Models** | One agent | Chat model, Model pool, Advanced model settings, SystemOne models, Bring your own key |
| `neoagent env set`, `neoagent setup` | The server | The same keys as **Admin › Providers** |
| `neoagent login <provider>` | The server | [Account sign-ins](#account-logins) |

Desktop installs have no `neoagent` command; use **Admin › Providers** and **Settings › Models** there.

## 🧩 Providers {#providers}

Model lists come live from each provider, so this page lists providers, not models.

| Provider | Connect with | Notes |
| --- | --- | --- |
| OpenAI | `OPENAI_API_KEY` | Optional `OPENAI_BASE_URL` |
| Anthropic | `ANTHROPIC_API_KEY` | Optional `ANTHROPIC_BASE_URL` |
| Google | `GOOGLE_AI_KEY` | Gemini models |
| xAI | `XAI_API_KEY` | Grok models; also image generation |
| NVIDIA NIM | `NVIDIA_API_KEY` | Hosted models including free-tier ones; key from build.nvidia.com |
| MiniMax Code | `MINIMAX_API_KEY` | Coding Plan key for MiniMax-M2.7; server-wide only |
| OpenRouter | `OPENROUTER_API_KEY` or **Sign in with OpenRouter** | 300+ models, some free; also serves SystemOne models |
| TypeSafe | `TYPESAFE_API_KEY` | SystemOne models only; key from console.typesafe.ai |
| Custom OpenAI-compatible | `OPENAI_COMPATIBLE_API_KEY` and `OPENAI_COMPATIBLE_BASE_URL` | Both required; the endpoint must offer Chat Completions and model listing |
| Ollama | `OLLAMA_URL` (default `http://localhost:11434`) | Local models, no key; can run on another reachable machine |
| Claude Code | `neoagent login claude-code` | Claude subscription |
| OpenAI Codex | `neoagent login openai-codex` | ChatGPT account |
| GitHub Copilot | `neoagent login github-copilot` | Copilot subscription |
| Grok (xAI OAuth) | `neoagent login grok-oauth` | xAI account |

:::note Custom endpoint tokens
If `OPENAI_API_KEY` holds the same token as `OPENAI_COMPATIBLE_API_KEY`, official OpenAI is treated as unavailable, so give each its own key.
:::

## 🪪 Account sign-ins {#account-logins}

| Command | Signs in to | How |
| --- | --- | --- |
| `neoagent login claude-code` | Claude | Reuses an existing Claude Code login on this machine, otherwise opens a browser sign-in |
| `neoagent login openai-codex` | ChatGPT (OpenAI Codex) | Device code: open the link, enter the code |
| `neoagent login github-copilot` | GitHub Copilot | Device code |
| `neoagent login grok-oauth` | Grok (xAI) | Browser sign-in that returns to this machine |

- **Server-wide.** The token goes into `~/.neoagent/.env`, so every account on the server uses it.
- **Pick from a list.** `neoagent login` with no argument asks which account to connect.
- **Applied right away.** A running server restarts to pick up the new token.
- **During setup.** Quickstart offers the same sign-ins as **Sign in with an account I already have**.

## 🔑 Bring your own key {#byok}

Each agent can use its own provider keys instead of the server's, under **Settings › Models › Bring your own key**.

- **Yours first.** An agent's own key wins over the server key; removing it falls back to the server key.
- **Encrypted.** Keys are stored encrypted and never shown again.
- **No server limits.** Usage limits don't apply to models running on your own key.
- **Sign in with OpenRouter.** Connects an OpenRouter account without copying a key; the key is stored like a pasted one.
- **Plain-HTTP servers.** On `https://` or `localhost` the browser returns by itself; on a plain-HTTP LAN address, paste OpenRouter's one-time code.
- **Custom endpoint.** Point an agent at any OpenAI-compatible endpoint. It must be reachable on the public internet; local and private-network addresses are refused.
- **Server-only providers.** Account sign-ins and MiniMax Code can't be added per agent.

## 🎯 Choosing models {#auto}

| Setting | Where | Default |
| --- | --- | --- |
| **Chat model** | Settings › Models | **Auto** |
| **Model pool** | Settings › Models | Every available model |
| **Advanced model settings** | Settings › Models | Follows the chat model |
| **Model Override** | A task's editor | The agent's chat model |

- **Auto ranks candidates.** Tool-capable models first, then the price class the request suits, then the newest release.
- **Model pool limits Auto.** With a pool set, Auto only picks from it.
- **Per-kind pins.** Pin a model to Coding, Computer use, Android use or Research; it takes over when the agent uses those tools.
- **Failover.** A failing model cools down and the run moves to another available model.
- **Tool calling.** A model used for tools must support tool calling through its provider.

| Feature | Model used |
| --- | --- |
| Memory search | Gemini or OpenAI embeddings; keyword search when neither key is set |
| Voice notes and dictation | **Speech-to-text** in Settings › Voice; **Auto** uses OpenAI, Gemini or Deepgram, whichever has a key |
| Image generation | xAI `grok-imagine-image`; needs `XAI_API_KEY` |

## ⚡ SystemOne models {#systemone}

SystemOne models are decision models: they answer typed questions (yes or no, pick one, score) in a few hundred milliseconds instead of writing text.

| Used for | Without SystemOne |
| --- | --- |
| Deciding whether to speak in group chats | The **Turn-taking model** under Settings › Behavior decides |
| The `browser_act` tool: one click, field or option per step | Not offered; the agent uses `browser_click` and `browser_type` |

| Provider | Models | Setup |
| --- | --- | --- |
| TypeSafe | Jev | `TYPESAFE_API_KEY` |
| OpenRouter | The decision models OpenRouter lists | `OPENROUTER_API_KEY` |
| Ollama 0.35+ | Local decision models such as `nimble` | `ollama pull nimble` |

- **Per agent.** **Settings › Models › SystemOne models**: **Off** (default), **Auto**, or a specific model.
- **Auto** prefers Jev 1.13, which NeoAgent's decision thresholds were tuned on, then any other available SystemOne model.
- **Admin control.** **Admin › Models** switches SystemOne models on or off for everyone. Agents whose model is switched off fall back to **Auto**.
- **Own keys work too.** TypeSafe and OpenRouter keys under **Bring your own key** also serve SystemOne models.
- **Separate pickers.** Chat model pickers never list SystemOne models.
- **Jev Router.** `typesafe/jev-router` is an OpenRouter chat model that picks a model per request and keeps it for the session.

Everything a person reads is still written by the chat model.

## 🎙️ Live voice {#live-voice}

In-app voice calls run on a speech-to-speech model with the same persona, memory and chat history as chat.

| Provider | Key | Default voice |
| --- | --- | --- |
| OpenAI GPT-Live | `OPENAI_API_KEY` | `marin` |
| Google Gemini Live | `GOOGLE_AI_KEY` | `Kore` |

- **Hands work off.** It answers conversation itself and hands tool work to background agent runs, several at once if needed.
- **Stays in touch.** It reports progress when the line is quiet; ask about, change or stop a task by voice.
- **Model.** Blank means the newest released live model the provider lists.
- **Input mode.** **Hands-free** (default) or **Push-to-talk** under **Settings › Voice**. The wearable is always push-to-talk.
- **Server defaults.** `VOICE_LIVE_PROVIDER`, `VOICE_LIVE_MODEL` and `VOICE_LIVE_VOICE`, or **Admin › Integrations › Live voice**.
- **Per account.** Override them under **Settings › Voice**.

## 🔐 Credential handling

- **Where keys live.** Server keys in `~/.neoagent/.env`; per-agent keys encrypted in the database.
- **Keep them out of content.** Never put credentials in task prompts, skills, screenshots, issue reports or chat.
- **Masked listing.** `neoagent env list` masks secrets. `neoagent env get <KEY>` prints the raw value, so avoid it in recorded or shared terminals.

## 🔗 Related

- [Configuration reference](configuration.md): every environment variable
- [Memory](memory.md): how embeddings feed recall
- [Security and permissions](security-boundaries.md): how credentials are scoped
