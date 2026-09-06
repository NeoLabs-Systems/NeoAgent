# Integrations and messaging architecture

Official integrations and messaging channels are separate service families.
They can expose the same external product while using different credentials
and data paths.

## Integration registry

The integration registry loads provider implementations. A provider describes
its applications, environment readiness, connection flow, tool definitions,
access modes, and optional memory-ingestion support.

OAuth state is short-lived and server-stored. Connection credentials are
encrypted before they are written to SQLite. Refresh responses are merged with
existing credentials so providers that omit a new refresh token do not erase
the durable token.

Connections are scoped by user, agent, provider, and account. Read-only access
is enforced when the integration tool is executed, not through prompt wording.

## Tool execution

Integration tools join the agent tool catalog when the owning agent has a
usable connection. The integration manager resolves the connection, refreshes
credentials when required, enforces access mode, invokes the provider, and
persists updated credentials.

## Memory ingestion

Providers that support background memory expose source collectors. The
ingestion service creates durable jobs, fetches changed source objects, stores
source documents, chunks content, and links extracted memory back to those
chunks.

Provider snapshots shown in the client are decorated with ingestion coverage
and status.

NeoRecall is intentionally queried on demand instead of being copied into
NeoAgent memory. Its integration uses a dynamic public OAuth client with PKCE,
rotating refresh tokens, and read-only scopes. The available tools call
NeoRecall's local hybrid search and evidence APIs; they cannot access audio or
trigger NeoRecall's Ask endpoint.

When NeoRecall is connected, the runtime injects the provider's model summary
into the run context and prefers the daily-summary, search, and conversation
list tools in the initial active set so personal day questions route to
NeoRecall automatically.

## Messaging

Messaging providers are long-running channel adapters managed separately from
official integrations. They normalize inbound messages, enforce chat and
sender allowlists, create agent runs, send typing state, and deliver outbound
messages.

Webhook-backed channels enter through shared HTTP routes. Native adapters can
maintain sockets, polling loops, or provider-specific sessions. Personal
WhatsApp integration credentials remain separate from the WhatsApp messaging
bridge.
