---
title: Automation and triggers
sidebar_label: Automation
description: Run the agent unattended on schedules, account events, phone signals, other tasks, and signed webhooks.
---

# Automation and triggers

**A task runs the same agent, tools and permissions as chat, started by a trigger instead of a message.**

## 📝 Create a task

1. Open **Tasks** and press **Add Task**.
2. Choose the **Assigned Agent**; the task uses that agent's memory, accounts and model.
3. Press **Select Trigger** and pick one from the [trigger list](#trigger-types), or search for it.
4. Write the **Instructions** the agent follows every time the trigger fires.
5. Optional: set a **Model Override** and a **Result Delivery** channel, then save.

- **From chat.** Ask the agent for a reminder or a recurring check; it creates the task with its `create_task` tool.
- **Starter ideas.** **Get inspired** fills in ready-made tasks such as Morning briefing, Hourly inbox check and Weekly review.
- **Run Now.** Any task can be started by hand from its card.

## ⚙️ How triggers fire

- **Code checks, the model runs.** Each trigger tests its condition in server code; a model run starts only when it fires.
- **Polling triggers** query the connected account every 1 to 15 minutes; World News every 30 by default.
- **Event triggers** (messaging, MCP, phone, wearable, other tasks) fire as soon as the event arrives.
- **Baseline first.** Items that existed when the task was created never fire.
- **No duplicates.** Every event carries a fingerprint, so the same email, row or reading fires once.
- **One run at a time.** A task that is still running makes new events wait their turn.

## 🗂️ Trigger types {#trigger-types}

The server registers 42 trigger types in `server/services/tasks/adapters/index.js`.

| Group | Type ID | Fires when | Needs |
| --- | --- | --- | --- |
| **On demand and time** | `manual` | You press **Run Now** | Nothing |
| | `schedule` | A cron slot or a one-time date arrives | Nothing |
| | `webhook` | A signed request reaches the task's [webhook URL](#webhooks) | Nothing (API only, not in the picker) |
| **Email** | `gmail_message_received` | A new Gmail message matches an optional search query or unread filter | Google Workspace |
| | `outlook_email_received` | A new Outlook email matches an optional folder, search or unread filter | Microsoft 365 |
| **Messaging** | `slack_message_received` | A message lands in a Slack channel, optionally from one sender | Slack integration |
| | `teams_message_received` | A message lands in a Teams chat, optionally from one sender | Microsoft 365 |
| | `whatsapp_personal_message_received` | A message arrives in a chosen personal WhatsApp chat | Personal WhatsApp integration |
| | `messaging_member_joined` | Someone joins a Discord server, Telegram or WhatsApp group, Slack channel or Matrix room | That messaging channel |
| | `messaging_member_left` | Someone leaves one of those spaces | That messaging channel |
| | `messaging_reaction_added` | An allowed person reacts in a private Discord, Telegram or WhatsApp chat | That messaging channel |
| | `messaging_platform_disconnected` | A channel stops and needs you, for example after a logout | Any messaging channel |
| **Calendar** | `google_calendar_event_starting` | A timed event is N minutes away (default 10; all-day events skipped) | Google Workspace |
| | `google_calendar_event_created` | A new event appears, optionally only invites organized by others | Google Workspace |
| | `outlook_calendar_event_starting` | A timed Outlook event is N minutes away | Microsoft 365 |
| | `nextcloud_calendar_event_starting` | An event in a chosen Nextcloud calendar is N minutes away | Nextcloud |
| **Files and documents** | `google_drive_file_added` | A file appears in a Drive folder, or anywhere in Drive | Google Workspace |
| | `google_sheets_row_added` | A row is added to a range such as `Sheet1!A:E` | Google Workspace |
| | `onedrive_file_added` | A file appears in a OneDrive folder | Microsoft 365 |
| | `nextcloud_file_added` | A file appears in a Nextcloud folder | Nextcloud |
| | `nextcloud_share_received` | Someone shares a file with you | Nextcloud |
| | `notion_database_item_added` | An item is added to a Notion database | Notion |
| | `notion_database_item_updated` | An item in a Notion database changes | Notion |
| | `trello_card_entered_list` | A card is created in or moved into a list | Trello |
| | `figma_comment_added` | Someone comments on a Figma file | Figma |
| **Developer** | `github_issue_opened` | An issue opens, filtered by author, assignee, labels or text | GitHub |
| | `github_pr_opened` | A pull request opens, filtered by author or text | GitHub |
| | `github_workflow_run_failed` | A GitHub Actions run fails, optionally for one workflow or branch | GitHub |
| | `github_commit_pushed` | A commit lands on a branch (the default branch if empty) | GitHub |
| | `mcp_server_disconnected` | One MCP server, or any, fails | An MCP server |
| **Home, media and memory** | `home_assistant_state_changed` | An entity changes, or starts matching a target state or numeric range | Home Assistant |
| | `spotify_track_changed` | A different track starts playing | Spotify |
| | `neorecall_memory_created` | NeoRecall saves a memory, filtered by type, topic or text | NeoRecall |
| | `neorecall_daily_summary_created` | NeoRecall finishes a daily summary | NeoRecall |
| | `neorecall_conversation_recorded` | NeoRecall records a conversation | NeoRecall |
| **Weather and news** | `weather_event` | The forecast shows rain or snow starting, strong wind, or a temperature threshold | Weather (Open-Meteo, no key) |
| | `world_news` | New headlines match your keywords or category; the run decides if they matter | World News (GNews API key) |
| **Devices and places** | `android_notification_received` | A notification arrives on your phone, optionally from one app package | Android app, **Notification triggers** on |
| | `geofence_event` | Your phone enters or leaves a place (radius 50 m to 50 km, default 200 m) | Android app, **Location triggers** on |
| | `health_metric_recorded` | A phone health sync contains a matching metric, optionally above or below a value | Android app with Health Connect |
| | `wearable_connection_changed` | The wearable connects or disconnects | ESP32-S3 wearable |
| **Tasks** | `task_run_finished` | Another task finishes with any outcome, success or failure | Another task |

:::note Chained tasks
`task_run_finished` chains stop after three linked runs, so tasks that trigger each other cannot loop forever.
:::

## ⏰ Schedules

- **Presets.** Every 15 minutes, Every 30 minutes, Hourly, Daily, Weekdays, Weekly, Monthly, or Custom cron.
- **Once.** Choose **Once** and set **Run At**.
- **Cron.** Five fields, `minute hour day-of-month month day-of-week`. Seconds are not supported.
- **Your time zone.** Cron slots and dates without an offset use the account **Time zone** under **Settings › General**.
- **Finish at the scheduled time.** Starts early by the task's measured average run time, so the result lands on time.
- **Missed slots are skipped.** A recurring run that cannot start within 90 seconds of its slot waits for the next one.

| Expression | Runs |
| --- | --- |
| `0 9 * * *` | Every day at 09:00 |
| `0 9 * * 1-5` | Weekdays at 09:00 |
| `0 8 * * 1` | Mondays at 08:00 |
| `*/30 * * * *` | Every 30 minutes |

## 📬 Delivery

An automatic run must end with exactly one `send_message` call, with one of these `purpose` values:

| `purpose` | Meaning |
| --- | --- |
| `final_result` | A concrete result worth sending |
| `blocker` | A real problem you should know about |
| `no_response` | Nothing worth reporting; nothing is sent |

- **Plain text is internal.** On automatic runs, a reply without `send_message` is not delivered.
- **Destination.** **Result Delivery** sets the channel; **Use default channel** picks the chat you last used with this agent.
- **Quiet by default.** Built-in rules report only what changed and skip empty results. Your instructions override them.
- **Run Now is lenient.** A manual run delivers its plain reply when the agent sends nothing.
- **Failures reach you.** After one automatic retry, a failed run sends its reason. Provider outages and rate limits stay quiet.
- **Delivery needs a channel.** Connect a [messaging channel](integrations.md#messaging-channels); a run can succeed while its delivery fails.

## ✍️ Write instructions that run alone

- **Self-contained.** The run sees no chat history. Name the account, chat, repository or folder.
- **Say when to stay quiet.** For example: "Do not send anything when no reply is needed."
- **Prefer structured tools.** Integrations and MCP are easier to restrict and debug than browser automation.

```text
Search unread Gmail received since the previous run. Summarize messages that
need a reply and send the summary to my Telegram chat. Do not send anything
when no reply is needed.
```

## 🔗 Webhooks {#webhooks}

The `webhook` trigger is API-only: create the task by asking the agent, or with `POST /api/tasks`.

1. Get the signing secret while signed in: `POST /api/task-webhooks/<taskId>/rotate`. It is shown once.
2. Send each event to `POST /api/task-webhooks/<taskId>/deliver` with the headers below.
3. Check recent deliveries with `GET /api/task-webhooks/<taskId>/deliveries`.

| Header | Value |
| --- | --- |
| `X-NeoAgent-Timestamp` | Unix time in milliseconds, within 5 minutes of the server clock |
| `X-NeoAgent-Request-Id` | Unique per request; a reused ID is rejected |
| `X-NeoAgent-Signature` | `sha256=` plus the hex HMAC-SHA256 of `<timestamp>.<raw body>`, keyed with the secret |

```bash
TS=$(date +%s000)
BODY='{"event":"deploy_finished"}'
SIG=$(printf '%s.%s' "$TS" "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -hex | sed 's/^.* //')
curl -X POST "$PUBLIC_URL/api/task-webhooks/$TASK_ID/deliver" \
  -H 'Content-Type: application/json' \
  -H "X-NeoAgent-Timestamp: $TS" \
  -H "X-NeoAgent-Request-Id: $(uuidgen)" \
  -H "X-NeoAgent-Signature: sha256=$SIG" \
  -d "$BODY"
```

- **Size limit.** Bodies up to 256 KiB.
- **Untrusted payload.** The body reaches the run as fenced data, never as instructions.

## 📊 Runs and pausing

- **Runs.** Every execution appears in **Runs** with its trigger, steps, tool calls, final response and errors.
- **Pause task loop.** The switch under **Loop execution** skips the task before it calls the model.
- **No run caps.** Tasks have no daily run or token limit; pause or disable a task to stop it.
- **API flag.** `loopPaused: true` in the task config is the same switch; legacy `loopBudget.paused` still works.

## 🔒 Safety

- **Start read-only.** Connect integration accounts as **Read Only** until a task must write.
- **Keep approvals on.** Leave shell, file write, Android and desktop categories on approval for unattended work.
- **Approvals need you present.** An unanswered prompt blocks the call after 30 seconds.
- **No secrets in instructions.** Use the [credential broker](security-boundaries.md) instead.
- **Restrict senders.** Messaging allowlists decide who can start runs.
- **Treat trigger content as untrusted.** Emails, pages, messages and webhook bodies can carry prompt injection.
