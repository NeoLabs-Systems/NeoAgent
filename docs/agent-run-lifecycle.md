---
title: Agent run lifecycle
sidebar_label: Agent run lifecycle
description: The five stages of a durable agent run, from context resolution to post-run memory consolidation.
---

# Agent run lifecycle

**Every chat message, task, messaging event, voice hand-off and delegation becomes one durable `agent_runs` row driven by the same loop.**

## Entry points

| Caller | Starts the run in | `triggerSource` |
|---|---|---|
| App chat | Socket.IO `agent:run` or `POST /api/agents` | `web` |
| Messaging | `services/messaging/automation.js` | `messaging` |
| Tasks | `services/tasks/runtime.js` | `schedule`, `manual` or the trigger type |
| Live voice hand-off | `services/voice/live/task_bridge.js` | `voice_live` |
| `neoagent exec` | `services/agents/headless.js` | `cli` |
| Subagent, delegation | `spawnSubagent()`, `delegateToAgent()` | `agent`, `agent_delegation` |

- **One path.** All callers reach `DurableRunRuntime.run()` in `services/ai/runtime/run_orchestrator.js`.
- **Steering first.** A Socket.IO chat message sent while a run is active joins that run instead of starting a new one.

## 1. Accept

1. Resolve the agent (`resolveAgentId`) and its AI settings.
2. Apply server usage limits; an explicit BYOK model selection skips them.
3. Insert the `agent_runs` row with `runtime_state = accepted` and take the run lease.
4. Emit `run:start` and a `run.accepted` event.

## 2. Assemble context

These steps run concurrently where possible:

| Input | Source |
|---|---|
| Model | `getProviderForUser()` in `provider_selector.js` and `model_router.js` (explicit choice or Auto) |
| System prompt | `buildSystemPrompt()`: agent identity, core memory, auto-maintained profile |
| Recalled memory | `buildMemoryRecall()`, see [Memory architecture](memory-architecture.md) |
| History | Conversation summary plus the last `chat_history_window` messages |
| Runtime status | Connected integrations and capability health, omitted for public runs |
| Tools | Built-in, integration, skill and MCP tools |
| Trust record | `createRunTrust()`: audience and taint for the tool security hook |

- **Bounded tool set.** `selectInitialTools()` activates at most 20 tools: a fixed core plus defaults such as `web_search` and `execute_command`.
- **Self-activation.** The model finds the rest with `search_tools` and turns them on with `activate_tools`.

## 3. Run the loop

`runAgentLoop()` in `runtime/agent_loop.js` repeats until the model answers without calling a tool.

1. **Controls.** Honor pending pause, stop or interrupt from `agent_run_controls`.
2. **Hook.** `on_loop_iteration` hooks may stop the run.
3. **Guards.** Check the runaway guards (table below).
4. **Steering.** Apply queued user follow-ups.
5. **Context pressure.** Compact older history with a summary when the window is nearly full.
6. **Model turn.** Request the next turn; on failure or a blank reply, switch to a fallback model.
7. **Tool turn.** Run each call through `before_tool_call`, the repetition guard and the tool, then compact the result.
8. **Task model.** After a tool turn, move to a pinned model for that kind of work (`coding`, `computer_use`, `android_use`, `research`) unless the run had an explicit model.

- **Ordering.** Contiguous read-only calls run in parallel; a state-changing call is a barrier.
- **Progress.** Interactive runs post a model-written progress line after a silence; schedules and subagents stay quiet.

| Runaway guard | Default | Setting |
|---|---|---|
| Tool turns with no new state or evidence | 8 | `max_consecutive_read_only_iterations` |
| Tool turns where every call failed | 5 | `max_consecutive_tool_failures` |
| Model turns | 5,000 (emergency ceiling) | per-call `maxIterations` |
| Identical call already failed twice | blocked | none |

When a guard fires, the run gets one wrap-up turn to report its status, and fails if the model writes nothing.

## 4. Deliver

`requestFinalDelivery()` in `runtime/delivery/delivery_worker.js` is the only writer of a final answer.

1. Enqueue the answer in `agent_outbox` with idempotency key `<runId>:final:1`.
2. Claim `final_delivery_id` on the run with a compare-and-swap; a second claim fails.
3. Transmit on the run's channel.
4. Record the attempt in `agent_delivery_attempts`.

| Channel | Transmit |
|---|---|
| `web` | Emit `run:complete` once |
| `messaging` | Send the answer unless `send_message` already delivered it |
| `voice_live` | Hand to the live call, or to the chat if the call has ended |

:::note Ambiguous delivery is not retried
A delivery whose outcome is unknown marks the run `failed` instead of sending twice.
:::

## 5. Learn

After delivery, these run in the background and never change the run's outcome:

- **Thread state.** `refreshConversationState()` updates the thread summary, open commitments and questions.
- **Memory.** The same call extracts memory candidates; `consolidateMemoryCandidates()` stores them and invalidates the prompt cache.
- **Skills.** `skillLearningService.enqueueCompletedRun()` queues the run for skill learning.
- **Cleanup.** The lease is released and unfinished subagents are cancelled.

## Run states

`runtime_state` follows `runtime/run_state_machine.js`; clients see the mapped `status`.

| `runtime_state` | `status` | Meaning |
|---|---|---|
| `accepted` | `running` | Row written, lease held |
| `executing` | `running` (`pausing`, `paused`, `resuming` while paused) | Loop active |
| `delivering` | `running` | Final answer claimed |
| `completed` | `completed` | Delivered |
| `cancelled` | `stopped` or `interrupted` | Stopped by the user, a hook or a shutdown |
| `failed` | `failed` | Error, failed or ambiguous delivery, or no wrap-up reply |

- **First writer wins.** Transitions use a version check, and a terminal state never changes again.
- **Settled together.** Closing a run also closes its running steps and delegations in one transaction.

## Pause, stop and restart

| Action | Effect |
|---|---|
| Pause (`POST /api/agents/:id/pause`) | Aborts the model call, kills tool processes, releases the computer, expires pending approvals, checkpoints |
| Resume (`POST /api/agents/:id/resume`) | Consumes the pause control and continues the parked loop |
| Stop (`POST /api/agents/:id/abort`) | Ends the run as `stopped` |
| User takes the computer | Pauses the agent that holds the control lease |
| Server restart | Marks open runs `interrupted`, then resumes eligible ones |

- **Resume window.** Only `web` and `messaging` runs with a heartbeat in the last 60 minutes are resumed, as a new run.
- **Not resumed.** Subagents, delegations, scheduled tasks, live voice calls and `neoagent exec`.

## Hooks

| Event | Registered by | Can |
|---|---|---|
| `before_tool_call` | `services/security/tool_security_hook.js` | Block a call; fails closed on error |
| `on_loop_iteration` | Nothing in core; open to `globalHooks.register()` | Stop the run before the next turn |
