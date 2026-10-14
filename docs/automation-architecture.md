---
title: Agents, automation, and triggers
sidebar_label: Automation architecture
description: How agents, tasks, and runs share scope, and how the trigger registry schedules execution.
---

# Agents, automation, and triggers

**A task stores a prompt, a trigger and a delivery target; when the trigger fires, the task's agent runs like it would for a chat message.**

## Agents

| Concept | Implementation |
|---|---|
| Main agent | `ensureMainAgent()` in `services/agents/manager.js` keeps one `main` agent per user |
| Agent scope | `agent_id` on settings, conversations, memory, runs, connections, MCP servers and tasks |
| Delegation | `delegateToAgent()` starts a run of another agent; recorded in `agent_delegations` |
| Subagents | `spawnSubagent()` starts a child run of the same agent; cancelled when the parent ends |

- **Delegation rule.** The source needs `can_delegate`; the target must allow `can_be_delegated_to`.
- **Target list.** An empty `delegate_targets_json` allows every eligible agent.
- **Shared trust.** Subagents and delegations inherit the parent run's trust record.

## Task record

Tasks live in `scheduled_tasks` and are managed by `TaskRuntime` (`services/tasks/runtime.js`).

| Column | Holds |
|---|---|
| `agent_id` | The agent that runs the task |
| `trigger_type`, `trigger_config` | Adapter type and its validated config |
| `task_config` | `prompt`, notify target (`notifyPlatform`, `notifyTo`), `model`, `loopBudget` |
| `cron_expression`, `run_at`, `one_time` | Schedule fields |
| `last_trigger_fingerprint` | Last event handled, for de-duplication |

## Trigger adapters

`services/tasks/adapters/index.js` lists 42 trigger types; each adapter exports `type`, `label`, `configHint`, `validateConfig()`, `summarize()`, and a `poll` or `event` block.

| Group | Types | Fires by |
|---|---|---|
| Core | `schedule`, `manual`, `webhook` | Cron or one-time poller, Run button, signed HTTP |
| Email and chat | `gmail_message_received`, `outlook_email_received`, `slack_message_received`, `teams_message_received`, `whatsapp_personal_message_received` | Poll; WhatsApp also by event |
| Messaging platforms | `messaging_member_joined`, `messaging_member_left`, `messaging_reaction_added`, `messaging_platform_disconnected` | Event |
| Calendars | `google_calendar_event_starting`, `google_calendar_event_created`, `outlook_calendar_event_starting`, `nextcloud_calendar_event_starting` | Poll |
| Files and documents | `google_drive_file_added`, `google_sheets_row_added`, `onedrive_file_added`, `nextcloud_file_added`, `nextcloud_share_received`, `notion_database_item_added`, `notion_database_item_updated`, `trello_card_entered_list`, `figma_comment_added` | Poll |
| Developer | `github_issue_opened`, `github_pr_opened`, `github_workflow_run_failed`, `github_commit_pushed`, `mcp_server_disconnected` | Poll; MCP by event |
| Home, media, memory | `home_assistant_state_changed`, `spotify_track_changed`, `neorecall_memory_created`, `neorecall_daily_summary_created`, `neorecall_conversation_recorded` | Poll |
| World | `weather_event`, `world_news` | Poll |
| Devices and tasks | `android_notification_received`, `geofence_event`, `health_metric_recorded`, `wearable_connection_changed`, `task_run_finished` | Event |

## Firing paths

| Path | Module | How |
|---|---|---|
| Recurring schedule | `runtime.js` | One `node-cron` job per task, in the user's timezone |
| One-time schedule | `runtime.js` | Minute poller; the task is deleted after it runs |
| Finish on time | `runtime.js` | `finishOnTime` tasks start early by their average run time (last 10 runs, at most 1 hour) |
| Polled trigger | `trigger_polling.js` | Minute tick; `fetchRows()` calls integration tools and returns rows after the checkpoint |
| Event trigger | `trigger_events.js` | Listens on `runtime`, `messaging`, `mcp`, `wearable` and `whatsapp_personal` emitters |
| Device events | `routes/triggers.js` | `POST /api/triggers/notification` and `/api/triggers/geofence` publish runtime events |
| Webhook | `tasks/webhooks.js` | `POST /api/task-webhooks/:taskId/deliver` |

- **De-duplication.** `fireTaskFromTrigger()` ignores a fingerprint equal to `last_trigger_fingerprint` and stores it after a successful run.
- **Event queue.** Events for one task wait for the previous run, so two at once both run.
- **Chains.** `task_run_finished` stops after a chain depth of 3.

## Webhook authentication

| Header | Value |
|---|---|
| `X-NeoAgent-Timestamp` | Milliseconds since epoch, within 5 minutes of server time |
| `X-NeoAgent-Request-Id` | Unique per delivery; a reused ID is rejected with `409` |
| `X-NeoAgent-Signature` | `sha256=` + hex HMAC-SHA256 of `<timestamp>.<raw body>` with the task secret |

- **Secret.** Stored encrypted in `task_webhook_secrets`; rotate with `POST /api/task-webhooks/:taskId/rotate`.
- **Limit.** Payloads above 256 KiB are refused.
- **Log.** Each delivery is recorded in `task_webhook_deliveries`.

## Execution and delivery

1. **Gate.** A task already running is skipped (`already_running_or_queued`); a recurring run starting over 90 seconds late is skipped (`stale_start_delay`).
2. **Prompt.** The task prompt is combined with the trigger payload, fenced as untrusted data.
3. **Run.** The agent runs in the task's own conversation with `triggerSource` set to the trigger type.
4. **Decide.** Automatic runs must end with one `send_message` whose `purpose` is `final_result`, `blocker` or `no_response`.
5. **Deliver.** The runtime sends the staged message to the notify target; plain text is delivered only for manual runs.
6. **Retry.** A failed run retries once with the error attached; rate-limit errors skip the run instead.
7. **Publish.** A `task_run_finished` event lets other tasks react.

- **Default target.** Without a configured target, the agent's last messaging chat (`last_platform`, `last_chat_id`) is used.
- **Delivery failure.** A failed send fails the task (`TASK_DELIVERY_FAILED`) without re-running the agent.

See [Automation](automation.md) for the user-facing guide.
