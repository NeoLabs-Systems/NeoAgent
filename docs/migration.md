---
slug: /migration
title: Migrating from OpenClaw or Hermes
sidebar_label: Migration
---

# Migrating from OpenClaw or Hermes

NeoAgent can copy supported files and selected configuration from a default
OpenClaw or Hermes installation. Run a dry run first and review imported
content before using it with an agent.

```bash
neoagent migrate           # detect and migrate interactively
neoagent migrate dry-run   # preview what would be migrated
neoagent migrate status    # check what's detected
```

## What gets migrated

| Data | OpenClaw source | Hermes source | Destination |
|---|---|---|---|
| Skills | `~/.openclaw/skills/*.md` | `~/.hermes/skills/*.md` | `~/.neoagent/agent-data/skills/openclaw-imports/` or `hermes-imports/` |
| Memory files | `SOUL.md`, `MEMORY.md`, `USER.md` | `MEMORY.md`, `USER.md` | `~/.neoagent/agent-data/memory/openclaw/` or `hermes/` |
| API keys | from `.env` | from `.env` | merged into `~/.neoagent/.env` |

## Prerequisites

- NeoAgent installed: `npm install -g neoagent`
- An existing OpenClaw (`~/.openclaw/`) or Hermes (`~/.hermes/`) installation

## Running the migration

1. `neoagent migrate status` — reports which source installations were found
2. `neoagent migrate dry-run` — lists the skills, memory files, and API keys each source would contribute, without writing anything
3. `neoagent migrate` — asks which sources to import

When an API key already exists in your NeoAgent `.env`, the interactive flow
stops and asks per key:

```
  ⚠️  Conflict: OPENAI_API_KEY
      Existing in: neoagent
      Incoming from: openclaw
    [1] Keep existing
    [2] Overwrite with new
    [3] Skip this key
  Choice [1]:
```

The default keeps your existing key.

## Source paths

### OpenClaw

| Data | Path |
|---|---|
| Config | `~/.openclaw/openclaw.json` |
| Skills | `~/.openclaw/skills/` |
| Memory | `~/.openclaw/workspace/SOUL.md`, `MEMORY.md`, `USER.md` |
| Legacy | `~/.clawdbot/` |

### Hermes

| Data | Path |
|---|---|
| Config | `~/.hermes/config.yaml` |
| Skills | `~/.hermes/skills/` |
| Memory | `~/.hermes/memories/MEMORY.md`, `USER.md` |
| API keys | `~/.hermes/.env` |

## API keys detected and merged

`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `XAI_API_KEY`, `GOOGLE_AI_KEY`, `MINIMAX_API_KEY`, `BRAVE_SEARCH_API_KEY`, `DEEPGRAM_API_KEY`, `TELEGRAM_BOT_TOKEN`, `OPENROUTER_API_KEY`, `ELEVENLABS_API_KEY`, `SLACK_BOT_TOKEN`, `DISCORD_BOT_TOKEN`

Imported Markdown is preserved as source material. Copying it does not turn
every line into a verified structured memory fact. Review it for stale,
conflicting, or sensitive information.

## Post-migration steps

1. `neoagent status` — verify the installation
2. `neoagent start` — start the server
3. Review imported skills in `~/.neoagent/agent-data/skills/openclaw-imports/` and `hermes-imports/`
4. Review imported memory in `~/.neoagent/agent-data/memory/`
5. Reconfigure messaging channels and official integrations in the NeoAgent UI
6. Test recall with non-sensitive facts before relying on imported memory

## Troubleshooting

**"No OpenClaw or Hermes installation detected"** — Installation must be at the default path. If it's elsewhere, migrate manually:
- Copy `.md` skill files to `~/.neoagent/agent-data/skills/`
- Copy memory files to `~/.neoagent/agent-data/memory/`
- Merge API keys into `~/.neoagent/.env`

**"Permission denied" errors** — Check read permissions on source directories and write permissions on `~/.neoagent/`.

**Migration partially completed** — Safe to re-run. Only new files are copied; existing files are not overwritten.
