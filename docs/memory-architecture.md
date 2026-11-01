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
| `memory_source_chunks`, `memory_source_links` | Chunks and links from the former raw-chunk ingestion; no longer written |
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
| Integration ingestion | When a mailbox connects, or on request | `memory/ingestion.js`, `memory/document_facts.js` |

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

1. **Connect.** Finishing OAuth emits `connected` on the integration manager. When the user left **Import past mail when connecting an account** on, `MemoryIngestionService` sweeps that mailbox once. Nothing polls connected accounts.
2. **Collect.** The provider's `collectMemorySweep()` returns up to 100 important threads from the last 12 months:
   - **Gmail.** Important, starred or sent threads, without promotions, social, updates and forums.
   - **Outlook.** High-importance, flagged or Focused Inbox mail, plus sent mail.
3. **Store.** `ingestDocuments()` records the job (tagged `mode: 'sweep'`) and upserts the documents as source material. Source text never becomes a memory.
4. **Extract.** `extractDocumentFacts()` reads the documents in batches of about 12,000 characters with the user's model. Each prompt lists what memory already holds (the profile, the closest recalled memories and facts from earlier batches) and asks only for new, durable facts about the user, at most 150 characters each.
5. **Save.** Facts go through `consolidateMemoryCandidates()` with the thread as their source. A reworded copy of a known memory resolves to it; a changed value (`relation: updates`) supersedes the old fact.

- **Failure.** A batch that fails is skipped; the import fails only when every batch fails.

- **Once per connection.** A connection with a completed sweep job is not swept again on reconnect.
- **Repeat on request.** `POST /api/memory/ingestion/sweep` (`providerKey`, `appId`) sweeps every connected account of that app in the background, skipping threads already in `memory_ingestion_documents`.
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
