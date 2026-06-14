# Agents, automation, and triggers

Agents, tasks, and runs share a common scope: user ID plus agent ID. A task does
not create a separate agent context; it invokes the configured agent with
trigger metadata.

## Agent profiles

The agent manager resolves the selected profile and guarantees a main agent for
each user. Agent-scoped tables store settings, conversations, memory, runs,
integration connections, and task ownership.

Orchestrator profiles can delegate work through subagents. Delegated runs keep
their own execution state while preserving the caller's user and intended
agent scope.

## Task adapters

The trigger registry loads adapters for:

- recurring and one-time schedules;
- manual execution;
- authenticated webhooks;
- Gmail and Outlook email;
- Slack and Teams messages;
- personal WhatsApp messages; and
- weather events.

Adapters validate and normalize configuration, summarize it for the UI, and
provide trigger-specific runtime behavior.

## Scheduling and polling

Recurring schedules are registered with `node-cron`. One-time tasks and polled
integration triggers are checked by runtime pollers. Event-capable integration
sources can attach listeners when the task runtime starts.

The repository prevents duplicate active executions for the same task and
records trigger fingerprints so the same external event is not repeatedly
processed.

## Execution and delivery

The task runtime creates an agent run with trigger context, captures the final
response, and optionally sends it to a normalized messaging target. Run success
and delivery success are distinct states.

Notification triggers from the Android client enter through a separate route
and directly request an agent evaluation; they are not stored schedule
adapters.
