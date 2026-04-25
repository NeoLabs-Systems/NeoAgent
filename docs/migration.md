---
slug: /migration
title: Migration Guide
sidebar_label: Migration
---

# Migration Guide

Migrate your existing agent setup from **OpenClaw** or **Hermes** to NeoAgent with a single command.

## Quick Start

```bash
# Detect existing installations and migrate
neoagent migrate

# Preview what would be migrated (dry run)
neoagent migrate dry-run

# Check migration status
neoagent migrate status
```

## What Gets Migrated

| Data Type | OpenClaw | Hermes | Destination |
|-----------|----------|--------|-------------|
| **Skills** | `~/.openclaw/skills/*.md` | `~/.hermes/skills/*.md` | `~/.neoagent/agent-data/skills/openclaw-imports/` or `hermes-imports/` |
| **Memory** | `SOUL.md`, `MEMORY.md`, `USER.md` | `MEMORY.md`, `USER.md` | `~/.neoagent/agent-data/memory/openclaw/` or `hermes/` |
| **API Keys** | From `.env` | From `.env` | `~/.neoagent/.env` (merged with prompts on conflict) |

## Prerequisites

- NeoAgent installed (`npm install -g neoagent`)
- Existing OpenClaw (at `~/.openclaw/`) and/or Hermes (at `~/.hermes/`) installation

## Step-by-Step Migration

### 1. Run Migration Detection

```bash
neoagent migrate status
```

This will show:
```
Source agents:
  OpenClaw: FOUND
  Hermes: FOUND

Run `neoagent migrate` to start migration.
```

### 2. Preview Migration (Optional)

```bash
neoagent migrate dry-run
```

Sample output:
```
=== Migration Dry Run ===

OpenClaw detection: FOUND
  Skills: 5
  Memories: 3
  API keys: ANTHROPIC_API_KEY, OPENAI_API_KEY, TELEGRAM_BOT_TOKEN
  Config: ~/.openclaw/openclaw.json

Hermes detection: FOUND
  Skills: 3
  Memories: 2
  API keys: OPENAI_API_KEY, XAI_API_KEY
  Config: ~/.hermes/config.yaml

Would migrate to:
  Skills → ~/.neoagent/agent-data/skills/
  Memories → ~/.neoagent/agent-data/memory/
  API keys → ~/.neoagent/.env
```

### 3. Run Full Migration

```bash
neoagent migrate
```

Interactive prompts:
```
=== NeoAgent Migration ===

  -> OpenClaw detected at ~/.openclaw/
  -> Hermes detected at ~/.hermes/

What would you like to migrate?
  [1] Migrate from all detected sources
  [2] Migrate from OpenClaw only
  [3] Migrate from Hermes only
  [4] Cancel

  Choice [1]: 1

Scanning sources...
  OpenClaw: 5 skills, 3 memories, 3 API keys
  Hermes: 3 skills, 2 memories, 2 API keys

Migrating skills and memories...
  → Copied 5 skills to openclaw-imports/
  → Copied 3 skills to hermes-imports/
  → Copied 5 memory files

⚠️  API Key conflicts detected:
  OPENAI_API_KEY exists in both sources
      Existing in: neoagent
      Incoming from: openclaw
    [1] Keep existing
    [2] Overwrite with new
    [3] Skip this key
  Choice [1]: 1

Merging API keys...
  → Merged 4 API keys

=== Migration Complete ===

Skills migrated to:
  openclaw-imports/
  hermes-imports/

Memories migrated to:
  memory/openclaw/
  memory/hermes/

Run `neoagent status` to verify the installation.
Run `neoagent start` to start the server.
```

## Source Paths

### OpenClaw

| Data | Path |
|------|------|
| Config | `~/.openclaw/openclaw.json` |
| Workspace | `~/.openclaw/workspace/` |
| Skills | `~/.openclaw/skills/` |
| Memories | `~/.openclaw/workspace/SOUL.md`, `MEMORY.md`, `USER.md` |
| Legacy | `~/.clawdbot/` |

### Hermes

| Data | Path |
|------|------|
| Config | `~/.hermes/config.yaml` |
| Skills | `~/.hermes/skills/` |
| Memories | `~/.hermes/memories/MEMORY.md`, `USER.md` |
| API Keys | `~/.hermes/.env` |

## Target Paths (NeoAgent)

| Data | Path |
|------|------|
| Config | `~/.neoagent/.env` |
| Skills | `~/.neoagent/agent-data/skills/` |
| Memory | `~/.neoagent/agent-data/memory/` |
| Database | `~/.neoagent/data/neoagent.db` |

## API Keys Merged

The following API keys are automatically detected and merged:

- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`
- `XAI_API_KEY`
- `GOOGLE_AI_KEY`
- `MINIMAX_API_KEY`
- `BRAVE_SEARCH_API_KEY`
- `DEEPGRAM_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `OPENROUTER_API_KEY`
- `ELEVENLABS_API_KEY`
- `SLACK_BOT_TOKEN`
- `DISCORD_BOT_TOKEN`

## Conflict Resolution

When an API key exists in multiple sources (including your existing NeoAgent config), you'll be prompted:

```
⚠️  Conflict: OPENAI_API_KEY
    Existing in: neoagent
    Incoming from: openclaw
  [1] Keep existing
  [2] Overwrite with new
  [3] Skip this key
```

Choose `1` to keep the NeoAgent value, `2` to overwrite with the imported value, or `3` to skip entirely.

## Post-Migration Steps

1. **Verify installation**: `neoagent status`
2. **Start server**: `neoagent start`
3. **Review imported skills**: Check `~/.neoagent/agent-data/skills/openclaw-imports/` and `hermes-imports/`
4. **Review imported memories**: Check `~/.neoagent/agent-data/memory/`
5. **Configure messaging channels**: If you had Telegram/Discord configured, verify settings in the NeoAgent UI

## Troubleshooting

### "No OpenClaw or Hermes installation detected"

Ensure your existing installation is at the default path (`~/.openclaw/` or `~/.hermes/`). If it's at a custom path, you can manually copy the data:
- Skills: Copy `.md` files to `~/.neoagent/agent-data/skills/`
- Memories: Copy to `~/.neoagent/agent-data/memory/`
- API keys: Merge into `~/.neoagent/.env`

### "Permission denied" errors

Ensure you have read permissions on the source directories and write permissions on `~/.neoagent/`.

### Migration partially failed

The migration is designed to be idempotent - you can re-run it. Only new files are copied; existing files are not overwritten.

## Manual Migration

If the automated migration doesn't work for your setup:

1. **Skills**: Copy skill `.md` files from source `skills/` directory to `~/.neoagent/agent-data/skills/[source]-imports/`
2. **Memory**: Copy `SOUL.md`, `MEMORY.md`, `USER.md` to `~/.neoagent/agent-data/memory/[source]/`
3. **API Keys**: Edit `~/.neoagent/.env` and add keys from source `.env` file

## Getting Help

If you encounter issues:
- Run `neoagent status` to check NeoAgent health
- Run `neoagent logs` to view logs
- Run `neoagent doctor` to diagnose issues