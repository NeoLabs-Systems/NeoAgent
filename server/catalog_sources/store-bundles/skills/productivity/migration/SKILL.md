---
name: agent-migration
description: Guides users through migrating from OpenClaw or Hermes to NeoAgent. Run this skill when a user wants to migrate their existing agent setup. Provides step-by-step guidance, dry-run previews, and handles API key conflicts interactively.
version: 1.0.0
metadata:
  neoagent:
    tags: [migration, openclaw, hermes, setup, import]
    related_skills: []
---

# Agent Migration Guide

Guides users through migrating their existing OpenClaw or Hermes agent setup to NeoAgent.

## When to Use This Skill

Use this skill when:
- A user says they're migrating from OpenClaw or Hermes
- A user wants to import their existing skills, memories, or API keys
- A user runs `neoagent migrate` and needs guidance

## How Migration Works

NeoAgent's migration system automatically detects existing OpenClaw (`~/.openclaw/`) and Hermes (`~/.hermes/`) installations and migrates:

| Data | Source | Destination |
|------|--------|-------------|
| **Skills** | `skills/*.md` in source | `~/.neoagent/agent-data/skills/[source]-imports/` |
| **Memories** | `SOUL.md`, `MEMORY.md`, `USER.md` | `~/.neoagent/agent-data/memory/[source]/` |
| **API Keys** | `.env` files | `~/.neoagent/.env` (merged with conflict prompts) |

## Step-by-Step Migration Flow

### Step 1: Check Migration Status

Ask the user to run:
```
neoagent migrate status
```

This will show which source agents are detected.

### Step 2: Preview (Optional - Dry Run)

Ask the user to run:
```
neoagent migrate dry-run
```

This shows exactly what would be migrated without making any changes.

### Step 3: Run Full Migration

Ask the user to run:
```
neoagent migrate
```

The migration will:
1. Scan both sources (if present)
2. Copy skills to import directories
3. Copy memory files
4. Merge API keys with interactive conflict resolution

### Step 4: Verify Migration

After migration completes, advise the user to:
```
neoagent status   # Check server is running
neoagent start    # Start the server if not running
```

Imported skills appear in:
- `~/.neoagent/agent-data/skills/openclaw-imports/`
- `~/.neoagent/agent-data/skills/hermes-imports/`

Imported memories appear in:
- `~/.neoagent/agent-data/memory/openclaw/`
- `~/.neoagent/agent-data/memory/hermes/`

## API Key Conflict Resolution

During migration, if an API key exists in multiple sources (including an existing NeoAgent config), the user will be prompted:

```
⚠️  Conflict: OPENAI_API_KEY
    Existing in: neoagent
    Incoming from: openclaw
  [1] Keep existing (neoagent)
  [2] Overwrite with new (openclaw)
  [3] Skip this key
```

Guide the user to choose based on their needs:
- **Keep existing**: If they want to preserve the current NeoAgent configuration
- **Overwrite**: If the incoming key is the one they want to use
- **Skip**: If they want to deal with it manually later

## Troubleshooting

### "No OpenClaw or Hermes installation detected"

**Cause**: The source directories don't exist at default locations.

**Solution**:
1. Check if the installation is at a custom path
2. Manually copy data:
   - Skills: Copy `*.md` files to `~/.neoagent/agent-data/skills/`
   - Memories: Copy to `~/.neoagent/agent-data/memory/`
   - API keys: Edit `~/.neoagent/.env` manually

### "Permission denied" errors

**Cause**: Missing read permissions on source or write permissions on target.

**Solution**: Ensure the user has appropriate permissions:
```bash
chmod 755 ~/.openclaw
chmod 755 ~/.hermes
chmod 755 ~/.neoagent
```

### Migration seems incomplete

**Cause**: Some files may have already existed and were skipped (migration is idempotent).

**Solution**: Re-run migration - it won't overwrite existing files.

## Manual Migration (If Automated Fails)

If the automated migration doesn't work:

### For Skills
```bash
# Create import directory
mkdir -p ~/.neoagent/agent-data/skills/openclaw-imports

# Copy all .md files
cp ~/.openclaw/skills/*.md ~/.neoagent/agent-data/skills/openclaw-imports/
```

### For Memories
```bash
# Create source directory
mkdir -p ~/.neoagent/agent-data/memory/openclaw

# Copy memory files
cp ~/.openclaw/workspace/SOUL.md ~/.neoagent/agent-data/memory/openclaw/
cp ~/.openclaw/workspace/MEMORY.md ~/.neoagent/agent-data/memory/openclaw/
cp ~/.openclaw/workspace/USER.md ~/.neoagent/agent-data/memory/openclaw/
```

### For API Keys
```bash
# Edit the .env file
nano ~/.neoagent/.env

# Add keys from source, e.g.:
# OPENAI_API_KEY=sk-...
# ANTHROPIC_API_KEY=sk-ant-...
```

## Post-Migration Checklist

After successful migration, advise the user to:

- [ ] Run `neoagent status` to verify server is healthy
- [ ] Run `neoagent start` if server isn't running
- [ ] Review imported skills in `~/.neoagent/agent-data/skills/`
- [ ] Review imported memories in `~/.neoagent/agent-data/memory/`
- [ ] Verify API keys are correctly set with `neoagent env list`
- [ ] Test the agent by sending a message in the UI
- [ ] Check logs if anything seems wrong: `neoagent logs`