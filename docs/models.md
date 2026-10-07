---
title: Models and providers
sidebar_label: Models
description: Configure local, API-key, and account-backed model providers, and keep credentials on the server.
---

# Models and providers

*Pick the models NeoAgent thinks with — local, API-key, or account-backed.*

NeoAgent supports local models, API-key providers, and several account-backed
providers. Provider credentials stay on the server.

## ⚙️ Configure a model

Open **Settings > Models** to choose chat and routing defaults. Add provider
credentials under **Admin › Providers** in the app, with `neoagent env`, or
during `neoagent setup`.

:::note Desktop installs
Installs made from the desktop app have no `neoagent` command on `PATH`: the
runtime lives under `~/.neoagent` and is managed from **Settings > Server**. Use
**Admin › Providers** for provider credentials there.
:::

### 🏠 Local models

[Ollama](https://ollama.com/) does not require a hosted-model API key. Set its
server URL with `OLLAMA_URL`, then select an available Ollama model in NeoAgent.
The Ollama process may run on the NeoAgent host or another reachable machine.

### 🔑 API-key providers

NeoAgent includes providers for Anthropic, OpenAI, Google Gemini, xAI, MiniMax,
NVIDIA NIM, OpenRouter, and OpenAI-compatible endpoints. Available models are
loaded through the configured provider rather than maintained as a fixed list
in the documentation.

Configure a custom endpoint with both `OPENAI_COMPATIBLE_BASE_URL` and
`OPENAI_COMPATIBLE_API_KEY`, either in the environment or on the admin
dashboard's **AI Providers** page. The endpoint must implement the OpenAI
Chat Completions and model-listing APIs. Putting that same token in
`OPENAI_API_KEY` does not enable official OpenAI (`api.openai.com`).

### 🪪 Account-backed providers

The CLI can authenticate supported developer subscriptions:

```bash
neoagent login github-copilot
neoagent login openai-codex
neoagent login claude-code
neoagent login grok-oauth
```

These login flows are separate from ordinary API-key providers.

## 🎯 Model assignment

The default model is selected in settings. Individual agents and scheduled
tasks can override it. A model used for tools must support the tool-calling
contract expected by its NeoAgent provider.

Some features use separate providers:

- Embeddings for memory search use a configured supported embedding provider
  and fall back to lexical retrieval when embeddings are unavailable.
- Voice calls run on a live speech-to-speech model (OpenAI GPT-Live or
  Gemini Live) that shares the chat's system prompt, memory and history. It
  answers conversation directly and hands anything that needs tools to a
  normal agent run in the background, several at once if needed. While they
  run, it passes on progress when the line is quiet, and you can ask how they
  are going, change them or stop them by voice; each result is spoken when it
  arrives.
- Voice-note and dictation transcription uses OpenAI, Gemini or Deepgram.
- Image generation and analysis depend on the selected provider and model.

## ⚡ SystemOne models

SystemOne models are decision models. They answer typed questions (yes or no,
pick one, score) in a few hundred milliseconds instead of writing text, and
NeoAgent uses them for the decisions it makes behind the scenes:

- deciding whether to speak in group chats
- driving web pages with the `browser_act` tool, one click, field, or option
  per step

Everything a person reads is still written by the chat model, and every
decision falls back to the model path when the SystemOne model does not answer.

These providers serve SystemOne models, with the same keys as chat models (the
server's, or an agent's own under **Advanced › Bring your own key**):

| Provider | Models | Setup |
| --- | --- | --- |
| TypeSafe | Jev | `TYPESAFE_API_KEY` from console.typesafe.ai |
| OpenRouter | Jev, Solar Decide, Mercury Decide, Span, Kev, Tev1 | `OPENROUTER_API_KEY` |
| Ollama 0.35+ | local decision models such as `nimble` and `tev1` | `ollama pull nimble` |

Each agent picks one under **Settings > Models › SystemOne models**:

- **Off** (the default): the chat model makes these decisions
- **Auto**: NeoAgent picks the model. It prefers Jev 1.13, which the decision
  thresholds were tuned on, and moves to another available SystemOne model when
  that one is switched off or gone
- a specific model from the list

The chat model pickers list only chat models; SystemOne models appear only in
their own picker. Server admins choose which SystemOne models are available
under **Admin › Models**, next to the chat models. A model switched off there
disappears from the picker, and agents that chose it fall back to Auto.

Jev Router (`typesafe/jev-router`) is a separate choice: it is an OpenRouter
chat model that picks a model per request and can be selected like any other
chat model.

## 🔐 Credential handling

API keys and account tokens are stored under the NeoAgent runtime directory on
the server. Do not put credentials in task prompts, skills, screenshots, issue
reports, or chat messages.

Use the environment CLI when terminal administration is more appropriate:

```bash
neoagent env list
```

`env list` masks secrets. The `env get`, `env set`, and `env unset` commands
accept a variable name; `env get` prints the selected value, so avoid running it
in recorded terminals or shared shells.

## 🔗 Related

- [Configuration reference](configuration.md) — every environment variable
- [Memory](memory.md) — embedding providers for recall
- [Security and permissions](security-boundaries.md) — how credentials are scoped
