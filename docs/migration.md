---
slug: /migration
title: Migrating from OpenClaw or Hermes Agent
sidebar_label: Migration
description: Bring agents, memory, skills, keys, automations, MCP servers and chat apps over from OpenClaw or Hermes Agent.
---

# Migrating from OpenClaw or Hermes Agent

**Install NeoAgent on the computer where OpenClaw or Hermes Agent runs. Setup finds it and offers to bring everything over.**

## ✅ Before you start

- **The `neoagent` command.** Use the [repository installer](getting-started.md#repository-installer); desktop app installs have no CLI.
- **Same computer, same user.** NeoAgent looks in `~/.openclaw` (plus `~/.openclaw-<profile>`, `~/.clawdbot`, `~/.moltbot` and `$OPENCLAW_STATE_DIR`) and in `~/.hermes` (plus `$HERMES_HOME`). For a copied folder, use `--from`.
- **Nothing is removed.** The old agent keeps working as it did, and its files are only read.

## ▶️ Run it

During `neoagent install` or `neoagent setup`, NeoAgent shows what it found and asks **Bring it over?** Saying yes:

1. Imports the AI keys straight away, so setup skips the AI question when a usable key came over.
2. Asks for your account name and password once NeoAgent is running.
3. Imports everything else.

On an existing install, run it yourself:

```bash
neoagent migrate --dry-run   # what would come over; writes nothing
neoagent migrate             # preview, choose, import
```

| Command | What it does |
| --- | --- |
| `neoagent migrate` | Shows one card per installation found, asks what to bring over, then imports |
| `neoagent migrate --dry-run` | Only the cards. `status` works too |
| `neoagent migrate openclaw` | Only OpenClaw (`hermes` for only Hermes Agent) |
| `neoagent migrate --from <folder>` | A copied or non-default folder; its files tell which agent it is |
| `neoagent migrate --yes` | No questions: import everything, queue the finish, restart |

Before writing anything, the import saves a backup to `~/.neoagent/backups/pre-import-…`. Running it again changes nothing that is already there.

## 📦 What comes over

| | OpenClaw | Hermes Agent | In NeoAgent |
| --- | --- | --- | --- |
| Agents | Every agent in `openclaw.json` | The default home and every `profiles/<name>` | The default agent becomes **main**; others become agents of their own |
| Personality | `SOUL.md` and the name from `IDENTITY.md` | `SOUL.md` | Agent instructions. Over 1,600 characters, they go to behaviour notes |
| Memory | `MEMORY.md` | `memories/MEMORY.md` (`§` entries) | Memories of up to 150 characters each, categorised by heading |
| About you | `USER.md` | `memories/USER.md` | Core memory `user_profile` |
| Daily notes | `workspace/memory/YYYY-MM-DD.md` | — | Daily logs |
| Skills | `skills/` and each workspace's `skills/` | Your own skills under `skills/`; bundled ones stay | Your skills, with their scripts and reference files |
| Keys | Auth profiles, `.env`, the secret store, custom providers | `.env` of every profile, `custom_providers` | `~/.neoagent/.env` |
| Model | `agents.defaults.model` and per-agent models | `model.default` with `model.provider` | Default chat model, only if a key for its provider came over |
| Automations | Cron jobs (SQLite or `cron/jobs.json`) | `cron/jobs.json` of every profile | Scheduled tasks with the same schedule, prompt, agent, chat target and on/off state |
| MCP servers | `mcp.servers` with a `url` | `mcp_servers` with a `url` | Remote MCP servers, Streamable HTTP or SSE, bearer token and headers |
| Chat apps | Telegram, Discord tokens and `allowFrom` | `TELEGRAM_*`, `DISCORD_*` | Connections and allowlists, online after the restart |
| Timezone | Schedule timezone or `USER.md` | `timezone` | Account timezone, if none is set |

Keys are read under the names each agent uses (`GEMINI_API_KEY` becomes `GOOGLE_AI_KEY`, `BRAVE_API_KEY` becomes `BRAVE_SEARCH_API_KEY`). When NeoAgent already has a key with a different value, yours is kept and the report says so.

## 🧩 What needs a hand

Some things have no direct NeoAgent equivalent. They are listed under **Needs a hand** and in the report:

- **Local MCP servers** (`command`/stdio). NeoAgent connects to MCP servers by URL.
- **Shell and script jobs.** NeoAgent's agent works on its own computer, not on yours.
- **WhatsApp.** It links to one app at a time: scan the QR code in NeoAgent. Allowed numbers are kept.
- **Slack.** NeoAgent receives Slack events by webhook, not socket mode. Set it up under Integrations.
- **OAuth sign-ins** (ChatGPT, Copilot and similar). Sign in again under Admin → Providers in the app.
- **Telegram usernames in allowlists.** Add the numeric user id instead.
- **OpenClaw's `AGENTS.md`**, when you changed it. It describes OpenClaw's own tools.
- **Keys for services NeoAgent does not use**, such as Firecrawl or Groq.

### 🤖 Let NeoAgent finish moving in

After the import, NeoAgent offers to finish the rest itself. If you agree, it queues a one-time automation for the main agent, two minutes after the restart. In that run the agent:

- looks at what was left behind and rebuilds what it can (automations, MCP servers, rules worth remembering),
- sends you one message with what it set up and what is still yours to do.

The run happens without you there, so it works only with tools that need no approval. It runs no shell commands and keeps your [tool permissions](runtime-and-tools.md) as they are. It needs an AI; if none is connected yet, you can connect one right there. It never makes up credentials.

Imported skills do not wait for this: each gets a short **NeoAgent Notes** block that maps the old agent's tool names (`terminal`, `patch`, `web_extract`, `cronjob`, …) to NeoAgent's.

## 🏁 Afterwards

1. The import offers to restart NeoAgent; skills, automations, MCP servers and chat apps load on start.
2. Read the report at `~/.neoagent/imports/import-<time>.md`. It lists every item; key values are never written to it.
3. Only one bot can poll a Telegram or Discord token at a time. Stop the old agent's gateway (`openclaw gateway stop`, `hermes gateway stop`) once NeoAgent answers.

## 🩺 Troubleshooting

| Message or symptom | Fix |
| --- | --- |
| `No OpenClaw or Hermes Agent found` | Point at the folder: `neoagent migrate --from ~/path/to/.openclaw` |
| `does not look like an OpenClaw or Hermes Agent folder` | `--from` needs the folder holding `openclaw.json` or Hermes' `config.yaml` |
| `NeoAgent is not set up yet` | Run `neoagent install` first; it offers the import itself |
| `more than one account` with `--yes` | Run without `--yes` and pick the account |
| A chat app does not answer | The old agent's gateway still holds the bot token: stop it, then `neoagent restart` |
| An MCP server shows an error | Its URL or token changed upstream; fix it in the app's MCP servers page |
