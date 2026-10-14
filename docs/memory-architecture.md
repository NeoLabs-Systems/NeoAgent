---
title: Memory architecture
sidebar_label: Memory architecture
description: Data model, ingestion, retrieval, and prompt paths for NeoAgent's structured memory.
---

# Memory architecture

**Memory lives in the main SQLite database as readable memories, atomic facts with validity windows, entity links and source provenance, scoped to one user and one agent.**

The code lives in `server/services/memory/`; `manager.js` (`MemoryManager`) owns every read and write.

## Data model

| Table | Holds |
|---|---|
| `memories` | Readable text, category, importance, confidence, embedding, strength, scope, archive flag |
| `memories_fts` | FTS5 index over memory text; LIKE search when FTS5 is unavailable |
| `memory_facts` | Subject, predicate, object facts with `valid_from`, `valid_to`, `learned_at`, `status`, `supersedes_fact_id` |
| `memory_relations` | Memory-to-memory links: `updates`, `extends`, `derives` |
| `memory_entities`, `memory_entity_mentions` | Entities and their mentions; the source of the knowledge graph |
| `memory_embedding_bands` | Hash bands for approximate vector candidates |
| `core_memory` | Explicit key/value entries injected into every prompt |
| `memory_ingestion_jobs`, `memory_ingestion_documents` | Ingestion runs with cursors, and their source documents |
| `memory_source_chunks`, `memory_source_links` | Position-aware chunks and links from extracted memories back to them |
| `memory_retrieval_events` | Recall telemetry: hashed query, candidate counts, result IDs, latency |
| `materialized_knowledge_views` | Precomputed summaries for the memory UI |

- **Scope.** Every row carries `user_id` and `agent_id`; recall also matches `scope_type` (`agent`, `conversation`, `task`, `channel` or `shared`).
- **Fact status.** `active`, `superseded`, `expired`, `needs_review`, `review` or `duplicate`.

## Write paths

| Path | When | Code |
|---|---|---|
| Conversation learning | After each completed run that has a conversation | `refreshConversationState()` then `consolidateMemoryCandidates()` |
| Agent tools | `memory_save`, `memory_update_core` | `services/ai/tools.js` |
| App and API | `/api/memory/memories`, `/api/memory/core/:key` | `routes/memory.js` |
| Transfer import | Memory exported from another assistant | `/api/memory/transfer-import`, `memory/llm_transfer.js` |
| Integration ingestion | Background, per connected account | `memory/ingestion.js` |

Conversation learning asks the run's model for at most 12 candidates and excludes:

- **Secrets.** Credentials, private tokens.
- **Noise.** Raw tool output, routine task narration.
- **Guesses.** Assistant suggestions and unverified claims.
- **Thread-only details.** Facts useful only inside the current thread.

## Save flow

`saveMemory()` handles every write:

1. **Exact match.** A matching `memory_hash` reinforces the existing memory instead of adding one.
2. **Embed.** The text is embedded (see the table below).
3. **Near duplicate.** Similarity above 0.85 updates the existing memory if the new text is longer, otherwise skips.
4. **Index.** Entities, mentions, facts and relations are written alongside the memory.
5. **Conflict.** A new fact for the same subject and predicate supersedes the active one, unless it `extends` or `derives`.

:::note External sources cannot overwrite stable facts
A fact extracted from an integration that conflicts with a static or high-confidence (≥ 0.8) fact is stored as `needs_review` instead.
:::

| Embedding provider | Used when |
|---|---|
| Google `gemini-embedding-2` | The agent's default model is Google and `GOOGLE_AI_KEY` is set |
| OpenAI `text-embedding-3-small` | Otherwise, when `OPENAI_API_KEY` is set |
| None | No key: recall uses full-text, entity and relation signals only |

## Recall

`recallMemory()` runs locally, with no extra model call:

1. **Candidates.** Vector bands, FTS matches, entity mentions, related memories and the 160 most important memories.
2. **Filter.** Drop archived rows, other scopes, and memories whose facts are all superseded or expired.
3. **Score.** Combine cosine similarity (same embedding model only), lexical, FTS, entity, relation and category-route signals.
4. **Weight.** Adjust by importance, confidence, access count and retention decay.
5. **Select.** Keep scores above 0.12, return the top K and reinforce their access strength.
6. **Record.** Write a `memory_retrieval_events` row.

- **Point-in-time.** `validAt` and `knownAt` options restrict recall to facts valid or learned at a given time.
- **Decay.** Strength halves every `stale_after_days` (default 90); pinned, `identity`, `preferences`, `assistant_self` and importance ≥ 9 memories never decay.

## Prompt paths

| Path | Built by | Contents |
|---|---|---|
| Core memory | `buildContext()` | `core_memory` entries |
| Profile | `getUserProfile()` | Up to 16 active facts, split into stable and current; ingested data excluded |
| Recall block | `buildRecallMessage()` | Top 5 recalled statements (about 1,600 characters) and matching recent scheduled-run results |

- **Owner only.** Core memory and the profile are left out of shared-audience runs.
- **Untrusted label.** The recall block states that external-source content is data, never instructions.
- **Statements only.** Categories, entity lists, version history and source offsets stay out of the prompt.

## Integration ingestion

1. **Tick.** `MemoryIngestionService` runs every 10 minutes (`NEOAGENT_MEMORY_INGESTION_INTERVAL_MS`).
2. **Freshness.** A connection is skipped until its last job's `nextSyncAt`.
3. **Collect.** The provider's `collectMemoryDocuments()` returns changed documents and a cursor.
4. **Store.** `ingestDocuments()` records the job, upserts documents, chunks them and saves each chunk as a memory with source links.
5. **Extract.** During later runs, up to 5 unextracted chunks are turned into facts in the background with that run's model.
6. **Retry.** A failed chunk is retried at most 3 times.

- **Collectors.** Only Google Workspace implements `collectMemoryDocuments()` today; other connections report coverage without documents.
- **Manual import.** `POST /api/memory/ingestion/documents` feeds documents through the same path.

## Maintenance

| Job | Schedule | Effect |
|---|---|---|
| Fact reconciliation | Every 6 hours, per active agent | Expires facts past `valid_to`, flags confidence below 0.35 for review, marks duplicates |
| Embedding index backfill | At startup | Builds missing `memory_embedding_bands` rows |
| Knowledge views | After each ingestion batch, or `POST /api/memory/knowledge-views/materialize` | Rebuilds `materialized_knowledge_views` |

## Privacy

- **Local store.** Memory never leaves the NeoAgent database on its own.
- **Model calls.** Text sent to a hosted chat or embedding provider is visible to that provider.
- **Graph.** The knowledge graph UI reads `GET /api/memory/graph`.

See [Memory](memory.md) for the user-facing guide.
