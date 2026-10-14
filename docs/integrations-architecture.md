---
title: Integrations and messaging architecture
sidebar_label: Integrations architecture
description: The integration registry, tool execution path, memory ingestion, and how messaging adapters differ.
---

# Integrations and messaging architecture

**Official integrations give agents tools over a user's accounts, while messaging platforms carry conversations in and out; the two families keep separate credentials and code paths.**

| Family | Manager | Credentials in | Gives the agent |
|---|---|---|---|
| Official integrations | `IntegrationManager` (`services/integrations/manager.js`) | `integration_connections` | Tools, triggers, memory ingestion |
| Messaging platforms | `MessagingManager` (`services/messaging/manager.js`) | `platform_connections` | Inbound chats, `send_message` delivery |

## Integration registry

`services/integrations/registry.js` discovers every `<provider>/provider.js` at startup; there is no central list.

- **Factory.** Each module exports exactly one `create*Provider` function.
- **Contract.** A provider declares `key`, `label`, `description`, `apps`, `getApp()`, `getEnvStatus()`, `getToolDefinitions()`, `supportsTool()` and `buildSnapshot()`.
- **Uniqueness.** Duplicate provider keys fail startup.

| Provider key | Apps |
|---|---|
| `google_workspace` | `gmail`, `calendar`, `drive`, `docs`, `sheets` |
| `microsoft_365` | `outlook`, `calendar`, `onedrive`, `teams` |
| `slack` | `slack` |
| `github` | `repos`, `mentions` |
| `notion`, `trello`, `figma`, `spotify` | One app each |
| `nextcloud` | `files`, `calendar`, `contacts` |
| `home_assistant` | `home_assistant` |
| `neorecall` | `recall` |
| `bitwarden` | `password_manager` |
| `whatsapp_personal` | `personal` |
| `news`, `weather` | `headlines`, `forecast` |

## Connecting an account

1. **Start.** The app requests an authorization URL; the server stores a short-lived state and an encrypted PKCE verifier in `integration_oauth_states`.
2. **Callback.** The provider redirects to `/api/integrations/oauth/callback`.
3. **Exchange.** The provider module trades the code for tokens.
4. **Merge.** New tokens are merged with any existing ones, so a refresh without `refresh_token` keeps the old one.
5. **Store.** Credentials are encrypted with `NEOAGENT_ENCRYPTION_KEY` (or `SESSION_SECRET`) and written to `integration_connections`.

The shared callback also serves two other flows, told apart by the `state` prefix:

| `state` | Flow | Module |
|---|---|---|
| `auth_…` | Sign in to NeoAgent with an external account | `services/account/auth_provider_manager.js` |
| `model_…` | "Sign in with OpenRouter" for a model API key | `services/ai/provider_sign_in/` (route `/api/provider-sign-in`) |
| No prefix (48 hex characters) | Official integration connection | `services/integrations/manager.js` |

- **Model sign-in.** `provider_sign_in/index.js` keeps PKCE flows in memory for 10 minutes; `openrouter.js` is the only method today.
- **Scope.** Connections belong to a user, agent, provider and account (`account_email`).
- **Config-based providers.** Nextcloud, Home Assistant, Trello, Bitwarden, NeoRecall and news use a user-entered config instead of, or before, OAuth.

## Tool execution

1. **Expose.** `getToolDefinitions()` adds a provider's tools only for apps with a `connected` connection.
2. **Select.** `executeTool()` picks the connection from `connection_id` or `account_email`, or the default.
3. **Enforce.** A write tool on a `read_only` connection is refused before the provider runs.
4. **Refresh.** Tokens expiring within 60 seconds are refreshed first; a `401` triggers one refresh and retry.
5. **Run.** The provider's `executeTool()` handles the call.
6. **Persist.** Updated credentials are written back encrypted.

- **Usage notes.** `summarizeConnectedProviders()` sends each integration's notes once per run, alongside its tools.
- **Access mode.** `read_write` or `read_only` per connection, set with `accessMode`; enforced in code, never by prompt wording.

## Memory ingestion

- **Collectors.** A provider may implement `collectMemoryDocuments()`; Google Workspace is the only one today.
- **Coverage.** Snapshots shown in the app are decorated with ingestion status, domains and document counts.
- **Details.** See [Memory architecture](memory-architecture.md#integration-ingestion).

## NeoRecall

| Aspect | Behavior |
|---|---|
| Setup | The user enters the NeoRecall base URL; OAuth bootstrap returns a client ID |
| Auth | PKCE (`S256`), scopes `search:read`, `memories:read`, `recordings:read`, refresh token required |
| Data | Queried on demand; never copied into NeoAgent memory |
| Tools | `neorecall_search`, `neorecall_list_memories`, `neorecall_get_memory`, `neorecall_list_mini_memories`, `neorecall_list_daily_summaries`, `neorecall_list_conversations`, `neorecall_get_conversation` |
| Limits | Tools use NeoRecall's local hybrid search; none calls NeoRecall Ask or fetches audio |

When NeoRecall is connected, `neorecall_list_daily_summaries`, `neorecall_search` and `neorecall_list_conversations` start active in every run.

## Messaging platforms

`MessagingManager.platformTypes` registers 24 platform types.

| Adapter | Platforms | Inbound |
|---|---|---|
| Native clients | `whatsapp` (Baileys), `discord` (discord.js), `telegram` (Telegraf), `github` | Long-lived client |
| `http_platforms.js` | `slack`, `google_chat`, `teams`, `signal`, `line`, `mattermost`, `bluebubbles`, `imessage` (through BlueBubbles) | Webhook at `/api/messaging/webhook/:platform` |
| `http_platforms.js` | `matrix` | Sync polling |
| IRC | `irc`, `twitch` | IRC connection |
| Generic HTTP | `feishu`, `nextcloud_talk`, `nostr`, `synology_chat`, `tlon`, `zalo`, `zalo_personal`, `wechat`, `webchat` | Configurable webhook |

- **Contract.** Adapters extend `BasePlatform` (`messaging/base.js`): `connect()`, `disconnect()`, `sendMessage()`, plus access-policy hooks.
- **Stored config.** Platform config is stored encrypted in `platform_connections`; WhatsApp session files live in `agent-data/messaging-auth/<user>/<agent>/whatsapp`.
- **No telephony.** There is no SMS or phone-number channel.

## Inbound message flow

1. **Receive.** The adapter emits a normalized message.
2. **Persist.** `MessagingManager` writes it to `messaging_inbound_jobs`; unfinished jobs are replayed after a restart.
3. **Access.** `access_policy.js` checks the sender and chat allowlists.
4. **Queue.** `inbound_queue.js` serializes messages per user, agent, platform and chat.
5. **Behavior.** `services/behavior/` decides whether to speak in group chats (addressing, turn-taking).
6. **Run.** `agentEngine.run()` starts with `triggerSource: 'messaging'` while a typing indicator is kept alive.
7. **Reply.** The agent answers with `send_message`, or the final answer is delivered as a fallback.

:::note Personal WhatsApp is not the WhatsApp channel
The `whatsapp_personal` integration (tools and triggers over the owner's chats) and the `whatsapp` messaging platform (the agent's own chat channel) use separate sessions; the integration's live in `agent-data/integrations/whatsapp-personal/`.
:::
