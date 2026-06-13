# Supermemory Review and NeoAgent Memory Parity Plan

Date reviewed: 2026-06-13

Reviewed sources:

- Supermemory repository at commit `39ef7e1e5ea01b34d2cdd1801d0d227d445a985d`
- MemoryBench repository at commit `118209a746d97d0d85e5a7234267f0b6962857e9`
- Supermemory research page and March 22, 2026 benchmark post
- NeoAgent memory, AI engine, ingestion, database, and evaluation code

Primary sources:

- https://github.com/supermemoryai/supermemory
- https://github.com/supermemoryai/memorybench
- https://supermemory.ai/research/
- https://supermemory.ai/blog/we-broke-the-frontier-in-agent-memory-introducing-99-sota-memory-system/
- https://supermemory.ai/docs/concepts/graph-memory
- https://supermemory.ai/docs/concepts/memory-vs-rag
- https://supermemory.ai/docs/concepts/user-profiles
- https://supermemory.ai/docs/search/overview

## Executive Verdict

The useful conclusion is not "copy Supermemory" and not "add a Supermemory API call."

Supermemory's strongest production ideas are:

1. Separate raw source documents from extracted memories.
2. Store atomic, source-grounded facts instead of conversation-shaped blobs.
3. Model updates, extensions, derivations, and expiry explicitly.
4. Maintain a broad user profile separately from query-specific retrieval.
5. Retrieve current facts first, then attach graph and version context.
6. Use hybrid retrieval, candidate expansion, and reranking.
7. Evaluate answer quality, retrieval quality, latency, and context tokens together.

NeoAgent already had parts of this shape before this review:

- SQLite memories with embeddings and FTS5
- memory facts and entities
- temporal columns and supersession IDs
- core memory and conversation working state
- ingestion jobs and source documents
- hybrid semantic, lexical, and entity ranking
- per-user and per-agent isolation

The main problem was semantic depth, not the number of tables. Facts were generally sentence copies with a category used as the predicate. Automatic conversation extraction depended mostly on the main model voluntarily calling `memory_save`. Superseded facts could still compete in normal recall. There was no automatic static/dynamic profile built from active facts.

This review implements the first high-impact correction:

- automatic structured memory extraction during the existing post-conversation state pass
- atomic subject, predicate, object facts
- `new`, `updates`, `extends`, and `derives` relation classification
- confidence, importance, static/dynamic type, evidence, and temporal bounds
- automatic supersession of conflicting current facts
- exclusion of superseded and expired facts from normal recall
- labeled version history attached to the current result
- automatic static and dynamic user profile injection
- confidence-aware ranking
- prompt cache invalidation after consolidation
- correct agent-scoped memory retrieval for subagents

This materially improves NeoAgent, but it does not establish parity. Parity must be demonstrated on reproducible benchmarks and production constraints.

## The 99 Percent Claim

The quoted claim is not a valid target for NeoAgent's production architecture.

Supermemory's own March 22, 2026 post states:

- The result was from an experimental flow, not the production Supermemory engine.
- Three reader agents extracted structured findings from sessions.
- Three search agents reasoned over those findings.
- The 98.60 percent result counted a question correct if any of eight answer variants was correct.
- A twelve-answer decision forest plus aggregator produced one answer at 97.20 percent.
- The post now labels the release a parody and social experiment.

The 98.60 percent number is best-of-eight coverage, not single-answer user-visible accuracy. It is useful as an upper-bound experiment, but it is not a fair production memory score.

Supermemory's current research page reports a different result:

- 95 percent Recall@15 with aggregation
- about 720 retrieved context tokens
- 99.4 percent context reduction
- category recall from 90 to 100 percent on LongMemEval_s

That is retrieval recall, not end-to-end answer accuracy. The number near 99 percent in that report is context reduction, while 99 percent is also reported for the knowledge-update category. These metrics must not be collapsed into one "99 percent memory" claim.

The repository README reports 81.6 percent on LongMemEval. This appears to describe a production or earlier end-to-end result, while the research page describes a later retrieval-focused result. The difference reinforces the need to record:

- dataset version
- sample set
- retrieval `k`
- answering model
- judge model and prompt
- single answer versus best-of-N
- context token count
- search and total latency
- ingestion cost

NeoAgent should not claim parity from one headline accuracy number.

## What Supermemory Actually Does

### 1. It Separates Documents and Memories

Documents are the source of truth:

- conversations
- email
- web pages
- PDFs
- images
- videos
- code
- connector objects

Memories are extracted knowledge units:

- user facts
- preferences
- events
- project state
- relationships
- inferred facts

This distinction matters because a memory should retain provenance to its source. The system can update its interpretation without losing the original evidence.

Before this review, NeoAgent had `memory_ingestion_documents` and `memories`, but ingestion saved one compacted title and summary as one memory. The implementation now preserves source chunks, spans, and many-to-many chunk-to-memory links.

### 2. It Uses Fact-on-Fact Graph Relations

The public schemas expose:

- `version`
- `isLatest`
- `parentMemoryId`
- `rootMemoryId`
- `memoryRelations`
- `sourceCount`
- `isInference`
- `isForgotten`
- `isStatic`
- `forgetAfter`
- `forgetReason`

Relation types are:

- `updates`: replaces an older fact
- `extends`: adds compatible detail
- `derives`: records an inference

This is not a conventional entity-relation-entity knowledge graph. The primary graph edges connect facts to other facts.

That is useful for agent memory because the important question is often not "what entities exist?" but "which version of this claim is current, what did it replace, and what evidence supports it?"

### 3. It Treats Time as Part of Truth

Supermemory distinguishes:

- when a fact was learned
- when it became valid
- when it stopped being valid
- when it should be forgotten
- whether it is the latest version

This avoids a common RAG failure:

1. The user once liked a product.
2. The product failed.
3. The user switched to another product.
4. Similarity search retrieves the old positive statement.

NeoAgent already had `valid_from`, `valid_to`, `learned_at`, `invalidated_at`, `status`, and `supersedes_fact_id`, but the old extractor rarely produced canonical predicates that could identify conflicts. The schema therefore had more capability than the extraction layer could use.

### 4. It Maintains Static and Dynamic Profiles

Supermemory profiles separate:

- static facts: identity, role, durable preferences
- dynamic facts: current projects, recent focus, temporary state

This solves a retrieval blind spot. A narrow search for a project update will not necessarily retrieve the user's communication style, timezone, role, or stable tool preferences. Profile context provides the broad baseline while search supplies question-specific detail.

NeoAgent now builds this profile from active facts and injects a bounded version into the system prompt.

### 5. It Uses More Than Vector Similarity

The documented retrieval stack includes:

- semantic vector search
- keyword or hybrid search
- metadata and container filtering
- query rewriting
- result merging and deduplication
- reranking
- relationship expansion
- current-version filtering
- optional source document and neighboring chunk context

The production value is in the combination. Embeddings provide broad semantic matching. Lexical search protects exact names, IDs, dates, and technical terms. Graph expansion provides temporal and relational context. Reranking removes noise before prompt injection.

NeoAgent now combines approximate semantic, FTS, entity, relation, importance, usage, freshness, confidence, and temporal signals. When direct retrieval is structurally weak or ambiguous, a bounded structured planner generates query variants and temporal intent, then a configured model reranks only known candidates. Confident retrieval stays on the zero-LLM fast path.

### 6. It Scopes Memory Strictly

Supermemory uses container tags as vector and access namespaces. NeoAgent's user, agent, and scope fields provide the corresponding boundary.

NeoAgent should keep its native scoping instead of importing Supermemory's container abstraction. The existing model is more expressive for:

- agent scope
- conversation scope
- task scope
- channel scope
- shared scope

### 7. It Runs Ingestion Asynchronously

The self-hosted documentation describes:

- immediate acceptance of additions
- background extraction and indexing
- search traffic prioritized over ingestion
- bounded ingestion concurrency and memory use
- local embedding workers

NeoAgent's integration ingestion is asynchronous, but conversation consolidation now waits for the existing post-turn structured pass. This favors immediate cross-turn consistency. If latency becomes material, it should move to a durable per-conversation queue with read-your-writes behavior rather than untracked fire-and-forget work.

### 8. It Measures Multiple Dimensions

MemoryBench reports:

- answer accuracy
- search latency
- context token count
- per-question-type accuracy
- Hit@K
- Precision@K
- Recall@K
- F1@K
- MRR
- NDCG

This is the correct direction. Accuracy alone rewards expensive ensembles and oversized context.

## Important Limits of the Public Supermemory Repository

The reviewed repository does not expose the complete hosted production engine.

It contains:

- public schemas
- client integrations
- MCP
- UI
- documentation
- SDK wrappers
- graph visualization

The self-hosted documentation explicitly says the hosted platform uses proprietary models tuned for long-horizon extraction. The reviewed checkout does not contain a directly reusable implementation of the hosted extraction and ranking stack.

Therefore:

- there is no complete production algorithm to copy
- direct code copying would not reproduce hosted quality
- integrating the hosted API would create an external source of truth, privacy dependency, and network dependency
- a native NeoAgent implementation is the correct architecture

Supermemory can still be used as a benchmark comparison provider, not as NeoAgent's primary memory store.

## NeoAgent Audit Before This Change

### Existing Strengths

1. Local-first storage in the existing SQLite database.
2. User and agent isolation in queries and indexes.
3. FTS5 plus embeddings plus entity matching.
4. Source references and confidence fields.
5. Temporal fact columns.
6. Integration ingestion jobs and freshness policies.
7. Conversation summaries and working state.
8. Manual core memory with confirmation.
9. UI and API support for memory inspection.

### Critical Gaps Before This Review

These describe the baseline that motivated the implementation below.

#### Extraction

- Conversation memory was not consolidated automatically in a reliable, structured way.
- Local fact extraction used sentence splitting and the memory category as a predicate.
- Entity extraction was regex-based and could not establish canonical semantic identity.
- Assistant statements could become memory if the model called `memory_save` incorrectly.
- There was no evidence field in the normal conversational extraction path.

#### Temporal Updates

- Conflicts required matching subject and predicate, but weak extraction rarely produced stable predicates.
- Superseded facts remained eligible as memory rows in normal recall.
- Historical context was not attached to the current fact.
- Expiry influenced freshness but did not always exclude a memory immediately.

#### Retrieval

- Embedding search scanned at most 800 recent memories in JavaScript.
- Old but important memories outside that window were invisible to semantic scoring.
- Embeddings were JSON stored in SQLite, with no approximate nearest-neighbor index.
- There was no query rewriting.
- There was no cross-encoder or LLM reranking stage.
- Confidence did not affect ranking.
- Source-document chunks and extracted memories were not searched as a unified result set.

#### Profiles

- Core memory required explicit management.
- There was no automatic broad user profile from active facts.
- Dynamic and static context were not separated.

#### Ingestion

- A source document generally became one title and compacted summary memory.
- There was no semantic chunk graph or source-span citation model.
- Materialized knowledge views are deterministic grouped summaries, not model-maintained profiles.

#### Evaluation

- `representative_tasks.json` checks event coverage, not memory answer quality.
- There was no LongMemEval, LoCoMo, or ConvoMem retrieval harness.
- There was no retrieval metric collection.
- There was no memory latency or context-token budget.

## Implemented in This Review

### Structured Post-Turn Consolidation

The existing conversation-state model call now also returns `memory_candidates`.

Each candidate includes:

- standalone memory text
- subject
- predicate
- object
- relation
- category
- confidence
- importance
- static flag
- valid-from time
- valid-to time
- forget-after time
- source-grounded evidence

The prompt explicitly excludes:

- secrets and credentials
- assistant guesses
- questions
- unverified claims
- raw tool output
- routine task narration
- thread-only details

This is implemented in:

- `server/services/memory/consolidation.js`
- `server/services/ai/engine.js`

### Temporal Fact Reconciliation

Structured facts now drive the existing temporal schema.

When the same canonical subject and predicate receives a different object:

- `updates` supersedes the previous active fact
- `extends` keeps both facts active
- `derives` keeps the inference separate
- unclassified conflicting values default to update behavior

The new fact records:

- relation metadata
- static status
- evidence
- source type
- validity bounds
- previous fact ID for updates

### Current-First Recall With Version Context

Normal recall now excludes:

- superseded facts
- expired facts

The current result includes labeled previous-value context. This supports both:

- "Where does Neo live now?"
- "Where did Neo live before Berlin?"

without allowing the old value to outrank the current value.

### Auto-Maintained Profile

Active facts are divided into:

- stable facts
- current context

The profile is bounded and injected into the system prompt. Cache entries are invalidated after consolidation so the next turn can see the update.

### Confidence-Aware Ranking

Candidate score now includes confidence. A low-confidence derived memory cannot rank exactly like a verified high-confidence fact with otherwise identical signals.

### Subagent Recall Fix

The subagent call passed the options object as the third `topK` argument to `recallMemory`. It now passes `4` as `topK` and the agent scope as the fourth argument.

### Persistent Approximate Semantic Index

The newest-800-memory scan has been removed.

NeoAgent now stores ten versioned locality-sensitive hash bands per embedding in SQLite. Search uses:

1. ten independent 14-bit bands
2. Hamming-distance-zero, one, and two probes
3. direct indexed SQLite lookups per band
4. vote aggregation in memory
5. exact cosine reranking over the bounded candidate set

This keeps the existing single-database deployment model and does not require a native vector extension or a second vector service.

Index versioning is explicit. Existing embeddings are rebuilt incrementally in the background when the index geometry changes. New and updated memories are indexed synchronously.

Synthetic measurements on this development machine:

- 100,000 memories
- 1,000,000 band rows
- 500 semantic candidates
- mean candidate lookup: 7.87 ms
- p95 candidate lookup: 9.17 ms
- synthetic recall@500 for a planted cosine-0.80 neighbor: 98.0 percent
- cosine-0.85 neighbor recall: 99.5 percent

These measurements validate the candidate index, not full end-to-end retrieval. Full retrieval also includes the embedding API call, FTS/entity retrieval, temporal filtering, exact scoring, provenance attachment, and SQLite telemetry.

### Hybrid Candidate Expansion and Context Budget

Recall now unions:

- approximate semantic candidates
- FTS candidates
- entity candidates
- relation neighbors
- a bounded importance and recency baseline

It then applies exact semantic scoring, lexical/entity scores, confidence, importance, usage, freshness, scope, and temporal validity.

Fact relation neighbors are expanded before final ranking. Prompt injection is bounded to approximately 750 memory-context tokens rather than blindly injecting every returned summary.

### First-Class Relations and Provenance

NeoAgent now persists:

- memory-to-memory `updates`, `extends`, and `derives` relations
- source documents
- source chunks
- stable character spans
- chunk-to-memory links
- source timestamps
- extraction method
- source relevance
- evidence metadata

Recall results expose source document, chunk, and span information. Recalled context includes a compact citation label. Source refresh removes obsolete chunks but preserves a memory that is still supported by another source.

### Structure-Aware Ingestion

External documents no longer collapse into one compact summary.

The ingestion path now:

1. preserves raw normalized source documents
2. uses message boundaries when structured messages are available
3. otherwise uses headings and paragraph boundaries
4. only uses character limits to split an oversized structural block
5. embeds and indexes every resulting chunk
6. links each memory back to its exact source span

Repository AST boundaries and format-specific email quote parsing remain future specialization work.

### Embedding Lineage

New embeddings record:

- provider
- model
- dimensions
- generated time
- approximate-index version

Legacy embeddings are marked as having an unknown provider and are incrementally reindexed.

### Reinforcement and Trust Boundaries

Repeated identical evidence now raises confidence on the existing memory and active fact instead of becoming a no-op.

External-source memories:

- carry an explicit `external_source` trust label
- are excluded from the automatic user profile
- are presented to the model as untrusted data, never instructions

Conversation-consolidated facts carry a separate user-or-verified-conversation trust label. The old phrase-based storage rejection policy was removed; durable-memory selection is handled by structured model output and source metadata rather than scenario regexes.

### Retrieval Evaluation and Telemetry

`npm run benchmark:memory` runs deterministic retrieval evaluation against an existing NeoAgent memory corpus. It accepts NeoAgent relevance IDs and MemoryBench-style question/session identifiers and reports:

- Hit@K
- Precision@K
- Recall@K
- F1@K
- MRR
- NDCG
- category breakdown
- latency mean, median, p95, p99, and maximum
- estimated context tokens
- candidate counts

Production recall also records privacy-preserving events with a query hash, candidate source counts, relation expansion count, result IDs, latency, and context-token estimate. Raw queries are not stored in telemetry.

### Tests

Regression coverage now verifies:

- malformed extraction output is rejected
- candidates are normalized and deduplicated
- updates supersede old facts
- current recall excludes stale values
- version history remains available
- static profiles contain only the current value
- extensions remain active
- expired memories are excluded
- the post-conversation engine path persists extracted candidates
- semantic recall can recover an old target behind more than 800 newer rows
- retrieval metrics use explicit relevance identifiers
- source chunks preserve structural and message boundaries
- source citations survive recall
- updates and extensions create graph edges
- relation expansion contributes candidates
- repeated evidence reinforces confidence
- external documents cannot become automatic profile facts
- storage does not use phrase-based scenario filters

## Remaining Work Required for Parity

### Phase 0: Establish a Reproducible Baseline

The local retrieval harness and an executable MemoryBench provider are implemented. Held-out runs remain mandatory before a parity claim.

The provider supplies:

- isolated temporary NeoAgent data per question
- one agent and user per benchmark container
- session ingestion with original timestamps
- deterministic wait for consolidation completion
- production retrieval planning and reranking through `AgentEngine.buildMemoryRecall`
- a clear method to reset the container
- compact source-aware answer prompts

Install it into a MemoryBench checkout with:

```bash
NEOAGENT_REPO_PATH=/absolute/path/to/NeoAgent \
  npm run benchmark:memorybench:install -- /absolute/path/to/memorybench
```

The adapter and bridge have been smoke-tested as an actual TypeScript-loaded provider, including isolated empty-index search and container cleanup. A representative ingestion/search run still requires configured extraction and embedding credentials.

Run at minimum:

- LongMemEval_s
- LoCoMo
- ConvoMem

Record:

- answering model
- judge model
- extraction model
- embedding model
- dataset commit or checksum
- category accuracy
- Recall@5, Recall@10, Recall@15
- MRR and NDCG
- search p50, p95, p99
- ingestion latency
- context tokens
- extraction and answering cost

Do not tune on the full test set. Keep a development subset and a held-out final run.

### Phase 1: Provenance and Graph Completeness

Implemented in this review:

#### `memory_relations`

- source memory ID
- target memory ID
- relation type
- confidence
- evidence source ID
- created time

The existing memory-level relation schema is now populated and used for retrieval expansion. `supersedes_fact_id` remains the direct fact-version pointer.

#### Source chunks and links

- memory or fact ID
- source document ID
- source span or message IDs
- relevance score
- source timestamp
- extraction model and prompt version

This enables:

- citations
- reprocessing
- deletion propagation
- confidence recalculation
- auditing incorrect memories

#### Embedding Version Metadata

Store:

- model ID
- vector dimensions
- embedding version
- generated time

Implemented for new embeddings, with legacy-provider marking and versioned index backfill.

### Phase 2: Scalable Retrieval

Implemented. There is no fixed recent-memory semantic cutoff.

Required behavior:

1. Retrieve lexical and entity candidates from SQLite indexes.
2. Retrieve semantic candidates from an ANN index.
3. Merge with reciprocal rank fusion.
4. Expand update and relation neighbors.
5. Apply temporal and scope filters.
6. Rerank only the top candidate set.
7. Enforce a context token budget.

Implementation options must be tested against NeoAgent's deployment constraints. The preferred shape is an embedded local vector index or a SQLite extension that does not create a second application database.

Current evidence:

- no fixed recent-memory cutoff: verified by regression test
- index candidate lookup p95 at 100,000 memories: 9.17 ms
- planted-neighbor candidate recall at cosine 0.80: 98.0 percent

Still required:

- end-to-end p95 including remote query embedding
- exact-brute-force comparison on real benchmark embeddings
- Recall@15 on held-out LongMemEval data

### Phase 3: Retrieval Planning and Reranking

Implemented as a confidence-triggered path. It produces structured intent, not phrase filters:

- entities
- requested time frame
- current versus historical intent
- expected fact predicates
- query variants
- whether source documents are needed

It runs only when cheap retrieval confidence is insufficient. Default retrieval remains one embedding request plus local indexes and performs no retrieval model call.

The configured model reranks at most 24 merged candidates through `engine.js`. It receives:

- query
- candidate fact
- validity interval
- relation context
- source evidence

It returns a bounded structured ordering and cannot introduce unknown memories. Planner or reranker failure falls back to deterministic retrieval. Enhancement reason, plan, candidate counts, selected IDs, latency, and run linkage are recorded without retaining the raw query.

Still required:

- measurable MRR and NDCG improvement on the development set
- less than 150 ms added p95 for local reranking, or explicit cost and latency accounting for remote reranking
- no accuracy regression on adversarial or abstention questions

### Phase 4: Source Document Processing

Implemented:

1. content normalization
2. structure-aware chunking
3. source-span preservation
4. embeddings per chunk
5. document-to-memory provenance links

Still required:

- memory extraction across related chunks
- repository AST or symbol-aware boundaries
- email quote-chain and attachment-aware boundaries
- neighboring-chunk expansion when a source answer crosses boundaries

Chunking should be content-aware:

- email threads by message and quoted history
- chat by turn windows
- calendar by event
- repositories by AST or symbol boundaries
- documents by headings and paragraphs

Do not use one universal character cutoff as the primary boundary.

### Phase 5: Forgetting and Reinforcement

Implemented:

- expire facts at `forget_after`
- downrank old episodes
- preserve high-value episodes
- strengthen repeated compatible preferences

Still required:

- lower confidence on unsupported derivations
- flag conflicting high-confidence facts for review
- propagate source deletion where required

Forgetting must not mean destructive deletion by default. Expired and superseded facts should remain available for historical questions and audit.

### Phase 6: Memory Observability

Implemented retrieval event logging:

- query hash
- selected candidates
- component scores
- relation expansion
- token count
- latency by stage

Still required:

- answering outcome linkage
- an operator-facing retrieval inspector
- stage-specific timing beyond total local retrieval

The UI should let an operator answer:

- Why was this memory stored?
- Which source supports it?
- What did it replace?
- Why was it retrieved?
- Why was another result excluded?
- When will it expire?

### Phase 7: Security and Memory Poisoning

Memory is a persistent attack surface.

Required controls:

- distinguish user-authored, assistant-authored, tool-derived, and external-source facts
- never treat external content instructions as user preferences
- preserve source trust level
- require stronger evidence for identity, security, financial, and health facts
- prevent secrets from entering extracted memories
- enforce user and agent scope in every relation and source query
- test deletion and IDOR behavior for new tables

## Production Acceptance Standard

NeoAgent should be called "as good as Supermemory" only when all of the following are true on a fixed, published configuration:

### Quality

- LongMemEval_s Recall@15 at least 95 percent
- knowledge-update recall at least 98 percent
- no more than one percentage point current-value regression from adding history context
- LoCoMo single-hop, multi-hop, temporal, and adversarial results reported separately
- ConvoMem personalization score reported
- single-answer evaluation only

### Efficiency

- mean injected memory context at or below 800 tokens
- p95 local retrieval below 200 ms at 100,000 memories
- no more than one extraction model call per completed conversational turn
- no retrieval LLM call on the default fast path

### Reliability

- read-your-writes behavior for the next conversation turn
- deterministic user and agent isolation
- source-backed update history
- expired facts excluded from current recall
- historical questions can still recover prior values
- failed consolidation never blocks the user's main response

### Honesty

Every published result must include:

- exact commit
- exact dataset
- exact models
- exact prompts
- sample count
- latency
- context tokens
- cost
- failures
- whether any ensemble or retry was used

## Recommended Order of Work

1. Run the local retrieval harness on a development relevance set.
2. Record MemoryBench LongMemEval_s, LoCoMo, and ConvoMem baselines.
3. Measure planner/reranker quality, latency, token use, and trigger rate.
4. Add format-specific ingestion boundaries and cross-chunk extraction.
5. Add retrieval inspection and answer-outcome linkage.
6. Harden poisoning, deletion propagation, and high-confidence conflict review.
7. Re-run held-out benchmarks and only then make parity claims.

## Bottom Line

NeoAgent should adopt Supermemory's useful architecture principles, not its marketing number and not its hosted API as a second brain.

The immediate quality problem was that NeoAgent's temporal schema was fed weak facts. That path is now materially stronger: conversations produce atomic, evidenced, time-aware facts; updates replace prior current values; prior values remain available as history; and active facts form an automatic profile.

The 800-row vector ceiling is gone, source provenance is first-class, relations participate in retrieval, external content is trust-separated, difficult queries can be planned and reranked, and retrieval can now be measured through both the local harness and MemoryBench. The next limiting factors are real benchmark evidence, planner/reranker measurement, and format-specific extraction quality.

There is still no defensible basis for claiming Supermemory-level quality until held-out LongMemEval_s, LoCoMo, and ConvoMem results satisfy the production acceptance standard above. The implementation is now capable of being evaluated against that standard instead of relying on architecture claims alone.
