# Automation

Tasks run on a schedule or integration trigger, use the same tools as chat, and can deliver results through any connected messaging platform.

## Creating a Task

Open **Tasks** in the UI and fill in:

| Field | Description |
|---|---|
| **Name** | Human-readable label |
| **Cron** | Five-field schedule expression |
| **Prompt** | Self-contained instruction for the future run |
| **Enabled** | Active or paused |
| **Model** | Optional per-task model override |

## Cron Expressions

```
┌───── minute (0–59)
│  ┌──── hour (0–23)
│  │  ┌─── day of month (1–31)
│  │  │  ┌── month (1–12)
│  │  │  │  ┌─ day of week (0–7, both 0 and 7 = Sunday)
│  │  │  │  │
*  *  *  *  *
```

Common patterns:

| Expression | Runs |
|---|---|
| `0 9 * * *` | Daily at 9:00 AM |
| `0 9 * * 1-5` | Weekdays at 9:00 AM |
| `0 8 * * 1` | Every Monday at 8:00 AM |
| `0 18 * * 5` | Every Friday at 6:00 PM |
| `0 9 1 * *` | First of every month at 9:00 AM |
| `0 */4 * * *` | Every 4 hours |
| `*/30 * * * *` | Every 30 minutes |

## Writing Good Task Prompts

Prompts run unattended. Be specific about what to check and when to notify — tasks that always send a message become noise, tasks that only notify on a condition are useful.

**Daily news digest**
```
Search Hacker News for the top 5 stories today. Send me a brief summary of each via Telegram, including the title and link.
```

**Price monitor**
```
Check the price of Bitcoin and Ethereum on CoinGecko. If either has changed more than 5% in the last 24 hours, send me a Telegram message with the current prices and percentage change. If there are no significant changes, do nothing.
```

**Server health check**
```
Run `df -h` and `free -m`. If disk usage on any partition is above 85% or available memory is below 500MB, send me a Telegram alert with the details. Otherwise do nothing.
```

**Weekly email digest**
```
Search my Gmail for unread emails from the last 7 days. Group them by sender domain and summarize the main topics. Send the summary to my Telegram.
```

## Tool Access

Automation can use everything available in chat:

| Capability | Examples |
|---|---|
| **Browser** | Navigate, extract content, screenshot, evaluate JavaScript |
| **CLI** | Shell commands in a persistent terminal |
| **Files** | Read, write, search host files |
| **Memory** | Store and retrieve long-term facts |
| **Messaging** | Send results through any connected platform |
| **MCP** | Tools from configured remote MCP servers |
| **Integrations** | Gmail, Calendar, Notion, Slack, and other OAuth tools |
| **Recordings** | Search and read transcripts |
| **Health** | Read synced Android Health Connect metrics |
| **Android** | Control an emulator or device |
| **Subagents** | Spawn parallel helpers inside a longer run |
| **Outputs** | Artifacts, images, Mermaid graphs, markdown tables |

Prefer official integrations and MCP tools over browser automation when both can do the job — they are more reliable and easier to audit.

## Safety

NeoAgent runs on your server and can touch real files, messaging surfaces, connected accounts, and browser sessions. Keep prompts narrow.

- Use messaging allowlists to restrict which chats receive automated messages
- Keep secrets in server config, not in prompts or skill files
- Prefer read-only checks unless the task explicitly needs to write data
- Review run history in **Runs** and service logs in **Logs** when behavior is unexpected
- Browser, CLI, Android, and file tools run on the NeoAgent server — not necessarily your current laptop
