# Persistence and migrations

NeoAgent uses a single SQLite database opened through
`server/db/database.js`. Services share that instance and use synchronous
`better-sqlite3` statements and transactions.

## Stored state

The database owns:

- Users, sessions, agents, and settings
- Conversations, messages, runs, steps, events, and model usage
- Tasks, triggers, webhook deliveries, and widgets
- Integration connections and encrypted credentials
- Memory, facts, entities, source documents, and retrieval telemetry
- Health records and device registrations
- Tool policies and approval history

Larger artifacts and editable agent data use runtime directories under
`NEOAGENT_HOME`.

## Schema changes

Base schema creation lives in the database module. Incremental migrations live
in `lib/migrations.js` and `lib/schema_migrations.js`. A migration must be
idempotent and preserve existing user data.

Do not create tables or run `ALTER TABLE` from feature services. Do not open a
second SQLite database instance.

FTS5 and JSON1 use graceful fallbacks where the host SQLite build may not
provide an extension. New behavior must preserve those fallback paths unless
the installation requirements are deliberately changed.

## Runtime paths

`runtime/paths.js` is the source of truth for application, configuration, data,
agent-data, log, update, and PID paths. Services must use those exports rather
than hard-coded home-directory paths.

Startup can migrate legacy in-repository `.env`, `data`, and `agent-data`
locations into the runtime home when the destination is empty.

## Backup implications

The database and agent-data directories should be backed up as one logical
state. Integration credentials and session material make backups sensitive.
Restoring only the database can leave referenced files or editable skills out
of sync.
