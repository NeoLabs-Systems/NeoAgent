---
slug: /migration
title: Migrating from OpenClaw or Hermes
sidebar_label: Migration
description: Import skills, memory files, and API keys from an existing OpenClaw or Hermes installation.
---

# Migrating from OpenClaw or Hermes

**Copy skills, memory files and API keys from a default OpenClaw or Hermes install: preview first, review after.**

## ✅ Before you start

- **The `neoagent` command.** Use the [repository installer](getting-started.md#repository-installer); desktop app installs have no CLI.
- **Same user, default paths.** The source must sit at `~/.openclaw/` or `~/.hermes/` in the home folder of the user running the command.

## ▶️ Run it

```bash
neoagent migrate status     # which sources were found
neoagent migrate dry-run    # what would be copied; writes nothing
neoagent migrate            # pick the sources and copy
```

| Command | What it does |
| --- | --- |
| `neoagent migrate status` | Reports OpenClaw and Hermes as found or not found |
| `neoagent migrate dry-run` | Counts skills and memory files, and names the API keys, per source. `--dry-run` works too |
| `neoagent migrate` | Asks **What would you like to bring over?**: everything found, only OpenClaw, or only Hermes |
| `neoagent migrate openclaw-only` | Copies from OpenClaw without asking |
| `neoagent migrate hermes-only` | Copies from Hermes without asking |

## 📦 What gets copied

| Data | OpenClaw source | Hermes source | Destination |
| --- | --- | --- | --- |
| Skills | `*.md` directly in `~/.openclaw/skills/` | `*.md` directly in `~/.hermes/skills/` | `~/.neoagent/agent-data/skills/openclaw-imports/` or `hermes-imports/` |
| Memory files | `~/.openclaw/workspace/SOUL.md`, `MEMORY.md`, `USER.md` | `~/.hermes/memories/MEMORY.md`, `USER.md` | `~/.neoagent/agent-data/memory/openclaw/` or `hermes/` |
| API keys | `~/.openclaw/.env` | `~/.hermes/.env` | Merged into `~/.neoagent/.env` |

- **Skill folders are skipped.** Only top-level `.md` files are copied, not folders containing a `SKILL.md`.
- **Memory stays as files.** Memory files are copied, not turned into structured memory facts.
- **Config files are only for detection.** `openclaw.json` and Hermes' `config.yaml` are not read. A legacy `~/.clawdbot/config.json` counts as OpenClaw but contributes nothing.
- **Nothing else.** Agents, tasks, messaging channels and MCP servers are not imported.

Keys looked for in each `.env`:

`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `XAI_API_KEY`, `GOOGLE_AI_KEY`, `MINIMAX_API_KEY`, `BRAVE_SEARCH_API_KEY`, `DEEPGRAM_API_KEY`, `TELEGRAM_BOT_TOKEN`, `OPENROUTER_API_KEY`, `ELEVENLABS_API_KEY`, `VOICE_TOOLS_OPENAI_KEY`, `SLACK_BOT_TOKEN`, `DISCORD_BOT_TOKEN`

## 🔀 Key conflicts

When a key already exists in NeoAgent with a different value, the migration asks:

```text
  ⚠️  Conflict: OPENAI_API_KEY
      Existing in: neoagent
      Incoming from: openclaw
    [1] Keep existing
    [2] Overwrite with new
    [3] Skip this key
  Choice [1]:
```

- **Default keeps yours.** Enter, `1` or `3` leaves the existing value.
- **Identical values** are not asked about.
- **Both sources, no NeoAgent value.** Hermes wins without asking.

## 🏁 Afterwards

:::warning Imported skills go live on restart
NeoAgent loads every `.md` file under `agent-data/skills/` as a skill when the server starts, so review imports before restarting.
:::

1. Review `~/.neoagent/agent-data/skills/openclaw-imports/` and `hermes-imports/`. Delete anything stale.
2. Review `~/.neoagent/agent-data/memory/` for stale, conflicting or sensitive notes.
3. `neoagent restart` so new keys and skills take effect.
4. Reconnect messaging channels and integrations in the NeoAgent app.
5. Test recall with non-sensitive facts before relying on imported memory.

## 🩺 Troubleshooting

| Message or symptom | Fix |
| --- | --- |
| `No OpenClaw or Hermes installation detected.` | The source is not at the default path. Copy by hand: `.md` skills to `~/.neoagent/agent-data/skills/`, memory files to `~/.neoagent/agent-data/memory/`, keys with `neoagent env set` |
| `EACCES: permission denied` | Check read access to the source folder and write access to `~/.neoagent/` |
| Migration stopped partway | Re-run it. Copied files are overwritten with the source versions; keys ask again only if they differ |
