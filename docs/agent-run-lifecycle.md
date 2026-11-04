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
4. Emit `run:start` and a `run.started` event.

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
- **By meaning.** When the memory system has an embedding provider, up to three more tools closest to the request are added (`tool_retrieval.js`), in any language. It is not a model turn, and without a provider a run goes without it.
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
| Deterministic read repeated with nothing changed | suppressed | none |

A guard's job is to end a spinning run; recovery tries to unstick it first. After two failing, repeating, or empty turns the next turn carries a note with the goal, the last actions, and the failures. That adds no model call, happens at most three times in a run, and a healthy run never pays for it. If a guard still fires, the run gets a wrap-up turn to report its status, and fails if the model writes nothing twice.

- **Reasoning.** Private reasoning returned with a tool call goes back to the model on its next turn, so it keeps its train of thought. It stays in memory for the run and is dropped when another model takes over.
- **Task state.** A multi-step run keeps its goal, steps, and notes with `task_ledger`, next to what the harness itself recorded. That record and the files it changed go back in after every compaction.

## 4. Deliver

`commitDelivery()` in `runtime/delivery/delivery_worker.js` is the one commit point for everything a run shows a user: the final answer, `send_message`, interim updates, progress lines, and task results.

1. Reserve a slot in `agent_outbox`, unique per run, recipient, purpose, and slot. The same slot cannot be reserved twice.
2. Suppress the message if the same text already reached this recipient in this run, under any slot.
3. For a final answer, claim `final_delivery_id` on the run with a compare-and-swap; a second claim fails.
4. Transmit on the run's channel and record the attempt in `agent_delivery_attempts`.

A resumed run shares its slots with the run it continues, so a message sent before the restart is not sent again. A reservation left pending by a crash is settled as unknown and never retried.

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
- **Cleanup.** The lease is released, unfinished subagents are cancelled, and the workspace checkpoint is dropped if the run completed. A failed run keeps its checkpoint.

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

## Live voice

A live model talks while ordinary runs do the work, so a hand-off goes through the same orchestrator, tools, approvals and outbox as a chat message. Everything the owner hears is the live model's own wording: the server only tells it what happened, through the fragments in `prompts/voice/`. Those fragments show what must not be claimed but never what to say, because live models copy example wording.

- **Status.** While a task runs and nobody has spoken for 10, then 20, 40 and 60 seconds, the session asks the live model for one sentence on where things stand, from the run's latest step. This costs no extra run and works while a task sits inside one long tool. The owner speaking restarts the schedule, and an owner who stopped the speech is not talked back into. The client's typing sound fills the time in between.
- **Silence.** A reply the model owed but never gave (a tool result, a task's outcome) is asked for once more. What the owner was waiting for when the line dropped is asked for again on the new connection.
- **The floor.** `live/floor.js` holds everything until the line is free, so nothing cuts into the owner's sentence or the model's answer.

## What a run can do

Every tool call is checked at dispatch, not only when tools are offered to the model. A tool outside the run's catalog is refused, a read-only run cannot change anything, and a tool the run has not turned on yet is turned on and run. Sub-agents are read-only unless started with `write`, only one may write at a time while the parent waits, and each has a turn, token and time limit.

A resumed run does not repeat an external action that already succeeded, and it refuses to redo one that was in flight when the process died, because it may have happened.

## What came of a run

Run status says how the loop ended. `metrics.outcome.task_outcome` says what the run can show, from tool receipts alone: `answered`, `actions_done`, `verified` (a test command that exited cleanly reported passes after the last file change), `unverified`, `tests_failing`, `action_failed`, `rolled_back`. Changes nothing could track, including what a writing sub-agent did, count as changes, so they put earlier tests out of date. It does not read the model's text, so it cannot catch a false claim in an answer; the Runs tab shows both side by side. A tool call the model writes out as text never reaches the user.

## Telemetry

Every run writes a ledger of metadata events to `agent_run_events` and a summary to `agent_runs.metrics_json`. The Runs tab reads both, and `GET /api/agents/harness/report` aggregates them.

| Question | Event |
|---|---|
| What was the context made of? | `context.built`, `model.request` |
| Why did it have these tools? | `tools.selected` |
| Why was this memory loaded? | `memory.recall` |
| Where did the time go? | `model.response`, `tool.result`, `delivery.sent` |
| Why did a tool not run? | `tool.suppressed`, `permission.decision` |
| Did a message go out twice? | `delivery.reserved`, `delivery.sent`, `delivery.suppressed` |
| What happened when it got stuck? | `recovery.triggered`, `context.compacted`, `checkpoint.created` |

The Runs tab also spells out what looks wrong in a run, computed from the summary with no model involved (`runtime/events/run_diagnostics.js`): a message that may have arrived, a skipped call that ran anyway, a tool that was not on the first turn, repeated or failed calls, a run that is mostly model time, and tools filling the context. Its limits are starting points, not measured values.

Full prompts are kept apart in `agent_run_captures`, only for failed runs and any run someone asked for. They expire after a week. New captures omit provider replay reasoning state; historical migrated records may predate this restriction.

All of this stays on the server.

### Harness safety contracts

Child limits are enforced against the eligible catalog at dispatch, independently of activation. Registered skill tools participate in that catalog. Arbitrary shell operations, including apparently read-only commands, are not automatically replayed after restart. Automatic workspace restoration is disabled because shared-workspace ownership cannot be proven.

Metadata events retain argument digests/counts and error presence, not argument/error text. Detailed step inputs/results are operational content, retained for active/recoverable runs and expired seven days after terminal completion by the capture maintenance job. Captures expire after seven days. Conversation history, task notes, artifacts, run errors/final answers and delivery outbox content have their own retention; capture expiry does not erase them. Historical pre-fix event content is not retroactively rewritten by this change.

A completed execution whose external delivery fails or is ambiguous returns a failed run with executionCompleted and deliveryStatus fields; it does not emit a successful completion event or start success learning. The generated answer remains on the failed run.

Extracted memory relationships and model-declared tool observations are assumptions. Automatic extraction cannot verify a semantic relationship from word overlap. Direct user-authored complete text and explicit owner edits can establish user-stated provenance; paraphrases remain unverified.

Verification is bound to the exact owner-confirmed content digest. Historical trust labels without that binding are shown as retrieved until confirmed again; memories are preserved. Verification denotes provenance of the statement, not an independent guarantee that the statement is true.

A resume referring to expired operation inputs fails closed for those tool names instead of treating missing arguments as proof that no action ran. A fresh owner-requested run remains available for intentional new executions.
