# Automation and triggers

Automations run the same agent loop and tools used by chat. They can start on a
schedule, from a supported account event, or through a webhook, and can deliver
their result through a configured messaging channel.

## Create a task

Open **Tasks**, choose the owning agent, select a trigger, and write a
self-contained instruction. A task can use the agent's model or a task-specific
override.

The currently implemented trigger families are:

| Trigger | Behavior |
|---|---|
| Schedule | Recurring cron expression or one-time timestamp |
| Gmail | Run when a matching Gmail message is received |
| Outlook | Run when a matching Outlook message is received |
| Slack | Run when a matching Slack message is received |
| Teams | Run when a matching Teams message is received |
| Personal WhatsApp | Run when a matching personal-account message is received |
| Weather | Run for configured forecast events such as rain or temperature thresholds |
| Webhook | Run after an authenticated task webhook request |

The Android app can also forward device notifications to
`/api/triggers/notification`. Notification runs are evaluated by the agent and
are separate from saved tasks.

## Schedules

Recurring tasks use five-field cron:

```text
minute hour day-of-month month day-of-week
```

Examples:

| Expression | Runs |
|---|---|
| `0 9 * * *` | Every day at 09:00 |
| `0 9 * * 1-5` | Weekdays at 09:00 |
| `0 8 * * 1` | Mondays at 08:00 |
| `*/30 * * * *` | Every 30 minutes |

Schedules use the server's configured time context. Confirm the next-run value
shown in the UI when the server and user are in different time zones.

## Write unattended instructions

A task prompt must contain enough context to run later without the current chat.
State what to inspect, what counts as actionable, where to deliver the result,
and when no message should be sent.

```text
Search unread Gmail received since the previous run. Summarize messages that
need a reply and send the summary to my Telegram chat. Do not send anything
when no reply is needed.
```

Prefer official integrations or MCP tools over browser automation when both
can perform the action. Structured tools are easier to restrict and diagnose.

## Bot-protected pages

The isolated VM browser uses native anti-detection hardening inspired by
Botasaurus' public anti-detect browser patterns: stable browser profiles,
common desktop viewport sizes, less mechanical pointer movement, referrer-aware
navigation, and challenge detection telemetry. NeoAgent does not embed or
depend on Botasaurus for this path.

`browser_navigate` accepts optional `referrerMode` values of `direct`,
`google`, or `current`. By default it also retries once with a Google referrer
when a known bot challenge is detected. Browser results can include
`botDetection` so runs can report that a page is blocked instead of treating the
challenge page as ordinary content.

Browser automation still must comply with the target site's terms and applicable
law. URL safety checks and the VM device-access restrictions remain in effect.

## Runs and delivery

Open **Runs** to inspect the trigger, tool calls, approvals, output, and error
for each execution. Delivery requires a configured messaging destination; a
completed run can still have a delivery error.

## Pausing task loops

Scheduled and event-triggered tasks have no per-day run or token hard limit.
They continue to follow their configured trigger until the task is disabled or
its loop is explicitly paused.

```json
{
  "loopPaused": true
}
```

Set `loopPaused` to `true` as a per-task kill switch. Existing tasks using
`loopBudget.paused` remain compatible, but the old run/token limit fields are
ignored.

## Safety

- Start with read-only integration accounts.
- Keep write, shell, Android, and desktop categories on approval unless the
  task runs in a controlled environment.
- Do not put secrets in prompts.
- Restrict messaging allowlists so untrusted chats cannot trigger an agent.
- Treat email, web pages, messages, and webhook bodies as untrusted input.
