# Agent run lifecycle

An agent run is the durable execution record for a chat request, scheduled
task, integration event, messaging event, widget refresh, or delegated job.

## 1. Resolve context

The caller supplies the user, agent, trigger source, conversation, and optional
model override. The engine resolves the effective agent settings and available
models, then creates the run record.

The prompt context can include:

- Agent identity and behavior settings
- Conversation history and working summary
- Core memory and the auto-maintained user profile
- Query-specific recalled memory
- Installed skills
- Available integrations, MCP tools, and runtime health
- Platform-specific output guidance

Large history and tool results are compacted before model calls.

## 2. Analyze and select tools

The engine classifies the request as a direct response or an execution task,
selects a planning depth, and activates a bounded tool catalog. Complex runs
can produce an execution plan, use subagents, and request a final verification
pass.

Model selection is scoped to the user and agent. Explicit run or task
overrides take precedence when the requested model is enabled and available.

## 3. Execute the loop

Each model turn can return text, completion state, or tool calls. Before a tool
runs:

1. Arguments are normalized.
2. The `before_tool_call` hooks execute.
3. Server security policy can deny or suspend the call for approval.
4. The tool is dispatched to its service or runtime backend.
5. The result is compacted and appended to the next model turn.

The engine records steps, run events, model usage, timing, and artifacts.
Repetition guards and loop limits prevent unbounded retries.

## 4. Complete and deliver

The final response is sanitized and stored. Messaging-triggered runs send an
explicit message or use the final response as a fallback when nothing visible
was already delivered.

The engine emits `run:complete`, persists prompt and usage metrics, refreshes
conversation summaries and working state, and cancels unfinished subagents.
Failures and user stops produce separate terminal run states.

## 5. Post-run processing

Completed conversations can run structured memory consolidation. The engine
extracts durable candidates, reconciles updates, and invalidates prompt caches
after memory changes.

The `on_loop_end` hook provides a non-blocking observer for learning and
analytics. Hook errors cannot change the completed run outcome.
