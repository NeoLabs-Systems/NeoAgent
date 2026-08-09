# Models and providers

NeoAgent supports local models, API-key providers, and several account-backed
providers. Provider credentials stay on the server.

## Configure a model

Open **Settings > AI Providers** to add credentials and choose models. You can
also run `neoagent setup` to configure common values from the terminal.

### Local models

[Ollama](https://ollama.com/) does not require a hosted-model API key. Set its
server URL with `OLLAMA_URL`, then select an available Ollama model in NeoAgent.
The Ollama process may run on the NeoAgent host or another reachable machine.

### API-key providers

NeoAgent includes providers for Anthropic, OpenAI, Google Gemini, xAI, MiniMax,
NVIDIA NIM, OpenRouter, and OpenAI-compatible endpoints. Available models are
loaded through the configured provider rather than maintained as a fixed list
in the documentation.

Configure a custom endpoint with both `OPENAI_COMPATIBLE_BASE_URL` and
`OPENAI_COMPATIBLE_API_KEY`, either in the environment or on the admin
dashboard's **AI Providers** page. The endpoint must implement the OpenAI
Chat Completions and model-listing APIs.

### Account-backed providers

The CLI can authenticate supported developer subscriptions:

```bash
neoagent login github-copilot
neoagent login openai-codex
neoagent login claude-code
neoagent login grok-oauth
```

These login flows are separate from ordinary API-key providers.

## Model assignment

The default model is selected in settings. Individual agents and scheduled
tasks can override it. A model used for tools must support the tool-calling
contract expected by its NeoAgent provider.

Some features use separate providers:

- Embeddings for memory search use a configured supported embedding provider
  and fall back to lexical retrieval when embeddings are unavailable.
- Voice transcription can use Deepgram when enabled.
- Image generation and analysis depend on the selected provider and model.

## Credential handling

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
