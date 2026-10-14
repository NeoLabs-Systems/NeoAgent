---
title: Persistence and migrations
sidebar_label: Persistence
description: The single SQLite instance, what it owns, how schema changes are applied, and what that means for backups.
---

# Persistence and migrations

**All application state lives in one SQLite database and a few directories under `NEOAGENT_HOME`; the schema is brought up to date on every start.**

## Database

- **One instance.** `server/db/database.js` opens `data/neoagent.db` once; every service imports that module.
- **Synchronous.** Services use `better-sqlite3` statements and `db.transaction()`, with parameters only.
- **Pragmas.** `journal_mode = WAL` (falls back to `DELETE`), `foreign_keys = ON`, `busy_timeout = 5000`.
- **Sessions.** The HTTP session store is a separate file, `data/sessions.db` (`server/db/sessions_db.js`); session metadata for the device list stays in `user_sessions`.
- **Permissions.** On macOS and Linux, database files are `0600` inside `0700` directories.

## What it stores

| Domain | Main tables |
|---|---|
| Accounts | `users`, `user_settings`, `user_sessions`, `user_two_factor`, `user_webauthn_credentials`, `user_auth_providers` |
| Agents | `agents`, `agent_settings`, `agent_delegations` |
| Conversations | `conversations`, `conversation_messages`, `conversation_history`, `messages` |
| Runs | `agent_runs`, `agent_steps`, `agent_run_events`, `agent_model_usage`, `agent_run_controls`, `agent_run_checkpoints`, `agent_outbox`, `agent_delivery_attempts` |
| Tasks | `scheduled_tasks`, `task_webhook_secrets`, `task_webhook_deliveries` |
| Connections | `integration_connections`, `integration_oauth_states`, `platform_connections`, `messaging_inbound_jobs`, `mcp_servers` |
| Memory | `memories`, `memory_facts`, `memory_relations`, `memory_entities`, `core_memory`, ingestion and retrieval tables |
| Skills | `skills`, `agent_skill_versions`, `skill_learning_candidates` |
| Security | `tool_policies`, `pending_approvals`, `tool_approval_log`, `approval_session_grants`, `credential_bindings`, `credential_usage_audit`, `access_audit_log` |
| Devices and health | `desktop_companion_devices`, `geofences`, `health_metric_samples`, `health_sync_runs` |

- **Encrypted columns.** Integration credentials, messaging platform config and webhook secrets are encrypted with `NEOAGENT_ENCRYPTION_KEY` (or `SESSION_SECRET`).
- **Full-text search.** `memories_fts`, `messages_fts` and `conversation_history_fts` use FTS5; without FTS5, search falls back to `LIKE`.
- **JSON functions.** `json_extract` and `json_set` are used directly, with no fallback.

## Schema changes

| Layer | Where | When it runs |
|---|---|---|
| Base schema | `CREATE TABLE IF NOT EXISTS` in `server/db/database.js` | Every start |
| Added columns | `ALTER TABLE … ADD COLUMN` list in `server/db/database.js` | Every start; "column exists" errors are ignored |
| Named migrations | Functions called by `runSchemaMigrations()` in `lib/schema_migrations.js` | Every start; each must be idempotent |
| Data migrations | `VERSIONED_MIGRATIONS` in `lib/schema_migrations.js`, run by `runVersionedMigrations()` | Once each, tracked by `PRAGMA user_version`; append only |
| Shared DDL | `lib/shared_schema.js` | Reused where the base schema and a migration create the same tables |

- **Not schema.** `lib/migrations.js` is the OpenClaw and Hermes importer behind `neoagent migrate`.
- **Preserve data.** A migration must keep existing user data and tolerate a partly migrated database.

:::danger Do not bypass the migration layer
- **No inline DDL.** Never create tables or run `ALTER TABLE` from feature services.
- **One instance.** Never open a second `better-sqlite3` connection to `neoagent.db`.
:::

## Startup clean-up

1. **Stale runs.** `interruptStaleAgentRuns()` marks runs and steps a dead process left open as `interrupted`.
2. **Orphan recovery.** `recoverOrphanedRuns()` closes runs whose lease expired, keeping checkpoints.
3. **Resume.** Eligible `web` and `messaging` runs restart, see [Agent run lifecycle](agent-run-lifecycle.md#pause-stop-and-restart).

## Runtime paths

`runtime/paths.js` is the only source for filesystem paths; services import its constants.

```text
NEOAGENT_HOME (~/.neoagent)
├── .env                    NEOAGENT_ENV_FILE
├── backups/                manual and pre-update backups
├── app/                    signed runtime versions and current.json
├── computer-runtime/       portable QEMU and the computer profile
├── data/                   NEOAGENT_DATA_DIR
│   ├── neoagent.db, sessions.db
│   ├── logs/, artifacts/
│   ├── computers/          QEMU images and per-user disks
│   └── runtime-containers/ Docker backend state
└── agent-data/             NEOAGENT_AGENT_DATA_DIR
    ├── skills/, workspaces/
    ├── messaging-auth/, integrations/
    └── users/              daily logs and agent-managed API keys
```

- **Legacy data.** On start, a checkout's `.env`, `data/` or `agent-data/` is copied into the runtime home if the target is missing or empty.
- **Desktop legacy.** `~/.neoagent/runtime/.env` from older desktop installs is migrated into `NEOAGENT_HOME/.env`.

## Backups

- **Command.** `neoagent backup` pauses the service, copies `.env`, `data/` and `agent-data/`, and adds compressed, verified QEMU disks.
- **One unit.** Back up the database and `agent-data/` together; restoring only one leaves skills, workspaces and files out of sync.
- **Docker volumes.** Per-user `neoagent-home-<user>` volumes of the Docker backend are not part of `neoagent backup`.
- **Sensitive.** Backups contain credentials, session secrets and personal data.

See [Operations](operations.md) for backup and recovery procedures.
