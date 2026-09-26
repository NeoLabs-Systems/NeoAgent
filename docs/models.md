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
- Voice transcription can use Deepgram when enabled.
- Image generation and analysis depend on the selected provider and model.

## ⚡ Jev decisions

Jev is TypeSafe's decision model. It answers typed questions (yes or no,
pick one, score) in a few hundred milliseconds instead of writing text, and
NeoAgent uses it for the decisions it makes behind the scenes:

- routing a request and choosing the tools and skill it needs
- ranking recalled memories
- during research, rating each search result and fetched page for whether it
  holds what the task needs, so the model opens the right sources first and
  skips pages without the information
- deciding whether to speak in group chats
- checking a reply against the run's tool results, so the verifier model only
  runs when Jev is not sure the reply is backed
- driving web pages with the `browser_act` tool, one click, field, or option
  per step

Everything a person reads is still written by the chat model, and every
decision falls back to the model path when Jev does not answer. Broad or long
requests still get the chat model's own planning.

Jev runs through OpenRouter, so it needs an OpenRouter key: the server's or an
agent's own under **Advanced › Bring your own key**. With one configured, turn
Jev on under **Settings > Models**, below the model selectors. Requests Jev
decides on are sent to TypeSafe through OpenRouter.

Server admins set the policy under **Admin › Models** or with the CLI:

```bash
neoagent jev          # show the policy and key status
neoagent jev on       # Jev on for every agent
neoagent jev agent    # each agent decides in Settings (default)
neoagent jev off      # Jev off on this server
```

The CLI commands restart NeoAgent to apply the change; the admin console
applies it at once. Jev Router (`typesafe/jev-router`) is a separate choice:
it is an OpenRouter chat model that picks a model per request and can be
selected like any other model.

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
