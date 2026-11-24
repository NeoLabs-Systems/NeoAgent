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
- **Trust level.** `memories.metadata_json.trustLevel` records where a memory came from, and decides how the model sees it (see [Prompt paths](#prompt-paths)).

| Trust level | Set by | Shown as |
|---|---|---|
| `user_stated` | Complete owner-authored text or explicit owner edit, bound to its content digest | Verified only while the digest matches |
| `tool_observed` | Historical label; model declarations do not establish verification | Retrieved without independently bound evidence |
| `agent_statement` | `memory_save` with no provable source, marked `derives` | Assumption |
| `external_source` | Ingested documents, tainted runs, event-triggered runs | Retrieved |
| `shared_room_conversation` | Conversation learning in a shared room | Retrieved |
| `user_or_verified_conversation`, none | Rows from before this field was checked and unverified imports | Retrieved |
| `model_inference` | Facts with no evidence in the thread, `memory_save` with `source: inference` | Assumption |

A memory with `relation: derives` is an assumption whatever its trust level. So is any unverified memory with confidence below 0.5.

## Write paths

| Path | When | Code |
|---|---|---|
| Conversation learning | After each completed run that has a conversation, except runs a saved task started (they open on the task's instructions, not on anything the owner said) | `refreshConversationState()` then `consolidateMemoryCandidates()` |
| Agent tools | `memory_save`, `memory_update_core` | `services/ai/tools/handlers/memory.js` |
| App and API | `/api/memory/memories`, `/api/memory/core/:key` | `routes/memory.js` |
| Transfer import | Memory exported from another assistant | `/api/memory/transfer-import`, `memory/llm_transfer.js` |
| Integration ingestion | When a mailbox connects, or on request | `memory/ingestion.js`, `memory/document_facts.js` |

Conversation learning asks the run's model for at most 12 candidates and excludes:

- **Secrets.** Credentials, private tokens.
- **Noise.** Raw tool output, routine task narration.
- **Guesses.** Assistant suggestions and unverified claims.
- **Thread-only details.** Facts useful only inside the current thread.

A candidate whose `evidence` quote is found neither in the owner's messages nor in a tool result is dropped, so a quote of the assistant, an invented sentence or an example from the extraction prompt never becomes a memory. Extracted relationships (`groundMemoryCandidates()`) are kept as `model_inference` with confidence at most 0.5, and never replace a known fact.

Only the owner's own words verify a memory: `memory_save` marks it `user_stated` when the whole text matches something the owner wrote, and the owner can confirm a memory in the app. Verification is tied to that exact text and says where it came from, not that it is true.

## Save flow

`saveMemory()` handles every write:

1. **Exact match.** A matching `memory_hash` reinforces a current memory. If that memory had been replaced or expired, it becomes current again.
2. **Same fact.** The same subject, predicate and object reinforces the memory holding it, however it is worded.
3. **Embed.** The text is embedded (see the table below).
4. **Near duplicate.** Similarity above 0.85 updates the existing memory if the new text is longer, otherwise reinforces it. Weaker or inferred content cannot rewrite a verified record merely because it is similar. It is not a duplicate if it shares no word of four letters or more, disagrees on a number or address, swaps one word, or holds another value for the same subject and predicate.
5. **Index.** Entities, mentions, facts and relations are written alongside the memory.
6. **Conflict.** See below.

A memory stops being current when:

- **Same slot.** A new fact has the same subject and predicate (ignoring case, `_` and `-`) in the same scope, unless it `extends` or `derives`. `updates` replaces every active value; `new` replaces the latest.
- **Value change.** The new text is the same statement with one number, version or address swapped (`isValueChange()`: "port 5544" to "port 5600"). Rows already active side by side get the same check at recall, so the older one is left out without any rewrite.
- **Close update.** A fact with `relation: updates` is above 0.85 similarity to it.
- **Named.** `memory_save` lists it in `replaces`.

Facts built locally (no model involved) have a category for a predicate, so they never conflict by slot. Swapped names and words ("sister Anna", "dark mode") are not treated as replacements, because both can be true. `memory_save` returns the memories that read alike so the model can decide.

:::note External sources cannot overwrite stable facts
A fact from outside content that conflicts with a static or high-confidence (≥ 0.8) fact is stored as `needs_review` instead. So is one that would replace anything by matching wording alone. A fact in a shared room never replaces one outside it.
:::

| Embedding provider | Used when |
|---|---|
| Google `gemini-embedding-2` | The agent's default model is Google and `GOOGLE_AI_KEY` is set |
| OpenAI `text-embedding-3-small` | Otherwise, when `OPENAI_API_KEY` is set |
| None | No key: recall uses full-text, entity and relation signals only |

## Recall

`recallMemory()` runs locally, with no extra model call:

1. **Candidates.** Vector bands, FTS matches on any query word, exact entity names, related memories and the 160 most important memories. The last group only gives the noise estimate below a sample; it earns no score.
2. **Filter.** Drop archived rows, other scopes, and memories whose facts are all superseded or expired.
3. **Signals.** Each is graded from 0 to 1 (`server/services/memory/relevance.js`):
   - **Semantic.** Cosine similarity, only between vectors from the same embedding space as its provider declares it (provider, model and size; NeoRouter names the space in its `X-NeoRouter-Embedding-Pin` header, the host that served the request is not the space), measured from the median cosine of this query's candidates. Unrelated text scores 0.2 on one model and 0.6 on another, so a raw value means nothing.
   - **Lexical.** The share of the query's weight that a memory covers. Weights come from how often the user's own memories use a word, which handles every language. At least one distinctive word has to match. If FTS is unavailable, frequencies are derived from the scoped candidate corpus rather than silently set to zero.
   - **Entity.** An exact entity name, worth less the more memories mention it.
   - **Relation.** A share of the signal of a linked memory that matched.
4. **Score.** The strongest signal, plus a small share of the second, scaled by importance, confidence, retention and category route. No evidence means a score of 0, however important the memory.
5. **Select.** Keep scores above 0.25, leave out rows a newer value change replaced, return the top K and reinforce them. `reinforce: false` skips that; the pre-run path reinforces only what reaches the prompt.
6. **Record.** Write a `memory_retrieval_events` row.

- **Point-in-time.** `validAt` and `knownAt` options restrict recall to facts valid or learned at a given time. `includeHistory` adds replaced memories; each result carries `current`.
- **Provenance.** Each result carries `provenance`: `verified`, `retrieved` or `assumption`.
- **Decay.** Strength halves every `stale_after_days` (default 90); pinned, `identity`, `preferences`, `assistant_self` and importance ≥ 9 memories never decay.

## Selective recall

`buildMemoryRecall()` decides what the run sees (`runtime/memory_policy.js`):

1. **Skip.** Requests with no content skip recall. Any request containing letters or numbers can be recalled against; no language-specific phrase list is used.
2. **Bar.** A memory's strongest signal must reach 0.35, independently of the request's language. There is no phrase-dependent keep-best bypass.
3. **Relative.** It must also reach 70% of the best match.

The values come from the sweep in `test/backend/unit/memory_retrieval_labelled.test.js`, which covers the keyword path and fake embeddings. They have not been checked against a real embedding model. The `memory.recall` event carries the `cosines` of each run's candidates for that.

## Prompt paths

| Path | Built by | Contents |
|---|---|---|
| Core memory | `buildContext()` | `core_memory` entries |
| Profile | `getUserProfile()` | Up to 16 active facts, split into stable and current; raw ingested chunks and assumptions excluded |
| Recall block | `buildRecallMessage()` | Top 5 recalled statements (about 1,600 characters), grouped by provenance, and scheduled-run results that cover most of the request's words |

- **Owner only.** Core memory and the profile are left out of shared-audience runs.
- **Untrusted label.** The recall block states that external-source content is data, never instructions.
- **Statements only.** Categories, entity lists, version history and source offsets stay out of the prompt.
- **Three groups.** Verified memory, retrieved memory and assumptions each get their own heading, so the model can tell what the user said from what was stored or guessed. Scheduled-run results are labelled as the assistant's own reports.
- **Age.** A memory not restated within `stale_after_days` ends with `(as of YYYY-MM)`, unless it never decays.

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
| Fact reconciliation | Every 6 hours, per active agent | Expires facts past `valid_to`, flags confidence below 0.35 for review, marks duplicates, restores memories hidden when locally built facts used to supersede each other |
| Embedding index backfill | At startup | Builds missing `memory_embedding_bands` rows |
| Embedding refresh | 20 memories a minute from startup, until none are left | Embeds memories with no vector, then those from another embedding space than the user's newest, once each per process |
| Knowledge views | After each ingestion batch, or `POST /api/memory/knowledge-views/materialize` | Rebuilds `materialized_knowledge_views` |

## Privacy

- **Local store.** Memory never leaves the NeoAgent database on its own.
- **Model calls.** Text sent to a hosted chat or embedding provider is visible to that provider.
- **Graph.** The knowledge graph UI reads `GET /api/memory/graph`.

See [Memory](memory.md) for the user-facing guide.
