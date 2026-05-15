---
slug: /migration
title: Migration Guide
sidebar_label: Migration
---

# Migration Guide

Migrate your existing agent setup from OpenClaw or Hermes to NeoAgent with a single command.

## Quick Start

```bash
neoagent migrate           # detect and migrate interactively
neoagent migrate dry-run   # preview what would be migrated
neoagent migrate status    # check what's detected
```

## What Gets Migrated

| Data | OpenClaw source | Hermes source | Destination |
|---|---|---|---|
| Skills | `~/.openclaw/skills/*.md` | `~/.hermes/skills/*.md` | `~/.neoagent/agent-data/skills/openclaw-imports/` or `hermes-imports/` |
| Memory | `SOUL.md`, `MEMORY.md`, `USER.md` | `MEMORY.md`, `USER.md` | `~/.neoagent/agent-data/memory/openclaw/` or `hermes/` |
| API keys | from `.env` | from `.env` | merged into `~/.neoagent/.env` |

## Prerequisites

- NeoAgent installed: `npm install -g neoagent`
- An existing OpenClaw (`~/.openclaw/`) or Hermes (`~/.hermes/`) installation

## Running Migration

### 1. Check what's detected

```bash
neoagent migrate status
```

```
Source agents:
  OpenClaw: FOUND
  Hermes: FOUND

Run `neoagent migrate` to start migration.
```

### 2. Preview (optional)

```bash
neoagent migrate dry-run
```

```
=== Migration Dry Run ===

OpenClaw detection: FOUND
  Skills: 5
  Memories: 3
  API keys: ANTHROPIC_API_KEY, OPENAI_API_KEY, TELEGRAM_BOT_TOKEN

Hermes detection: FOUND
  Skills: 3
  Memories: 2
  API keys: OPENAI_API_KEY, XAI_API_KEY

Would migrate to:
  Skills → ~/.neoagent/agent-data/skills/
  Memories → ~/.neoagent/agent-data/memory/
  API keys → ~/.neoagent/.env
```

### 3. Migrate

```bash
neoagent migrate
```

The interactive flow asks which sources to migrate and prompts when an API key exists in multiple sources:

```
⚠️  API Key conflicts detected:
  OPENAI_API_KEY exists in both sources
    Existing in: neoagent
    Incoming from: openclaw
  [1] Keep existing
  [2] Overwrite with new
  [3] Skip this key
Choice [1]:
```

## Source Paths

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

## API Keys Detected and Merged

`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `XAI_API_KEY`, `GOOGLE_AI_KEY`, `MINIMAX_API_KEY`, `BRAVE_SEARCH_API_KEY`, `DEEPGRAM_API_KEY`, `TELEGRAM_BOT_TOKEN`, `OPENROUTER_API_KEY`, `ELEVENLABS_API_KEY`, `SLACK_BOT_TOKEN`, `DISCORD_BOT_TOKEN`

## Post-Migration Steps

1. `neoagent status` — verify the installation
2. `neoagent start` — start the server
3. Review imported skills in `~/.neoagent/agent-data/skills/openclaw-imports/` and `hermes-imports/`
4. Review imported memory in `~/.neoagent/agent-data/memory/`
5. Reconfigure messaging channels in the NeoAgent UI if you had Telegram or Discord set up

## Troubleshooting

**"No OpenClaw or Hermes installation detected"** — Installation must be at the default path. If it's elsewhere, migrate manually:
- Copy `.md` skill files to `~/.neoagent/agent-data/skills/`
- Copy memory files to `~/.neoagent/agent-data/memory/`
- Merge API keys into `~/.neoagent/.env`

**"Permission denied" errors** — Check read permissions on source directories and write permissions on `~/.neoagent/`.

**Migration partially completed** — Safe to re-run. Only new files are copied; existing files are not overwritten.
