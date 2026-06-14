# Runtime and tool execution

The runtime manager selects where browser, shell, desktop, and Android actions
execute. Tool security is checked before dispatch, independent of the model
that requested the action.

## Browser and shell

The default browser and CLI backend is a per-user isolated runtime managed by
the server. It exposes a guest agent authenticated with a generated token and
stores artifacts through the server artifact service.

Browser settings can select a paired Chrome extension. CLI settings can select
a paired desktop companion. If the requested paired backend is unavailable,
the effective backend falls back to the isolated runtime.

## Desktop companion

Desktop control and selected CLI commands are sent through the authenticated
desktop companion registry. Non-PTY desktop commands can run through an
isolated worker process that has no imports from the main server process.

This process separation protects server memory; it does not restrict what the
paired desktop account itself can access.

## Android

The Android provider is created per user but executes through ADB on the
NeoAgent host. Device selection, screenshots, UI observation, input, intents,
application installation, and shell commands therefore operate outside the
browser and CLI runtime.

## Workspace files

File tools use server-side path validation and the user's workspace boundary.
They do not accept arbitrary paths merely because a model generated them.

## Tool security hook

`before_tool_call` runs before tool execution. The security hook maps sensitive
tools to categories and applies the user's deny, approval, session allow, or
persistent allow policy.

Approval waits are delivered through Socket.IO. The model receives a structured
blocked result for denial or timeout and should not treat the tool as executed.

## Boundaries not provided

The runtime does not provide destination-level network egress filtering.
Read-only tools can execute without approval. Paired machines and ADB devices
remain trusted operator resources. See [Security](security-boundaries.md) for
deployment guidance.
