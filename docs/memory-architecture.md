# Memory architecture

NeoAgent memory separates source material, readable memories, structured
facts, and retrieval telemetry. The design keeps current facts useful while
retaining provenance and history.

## Data model

### Memories

`memories` stores the readable unit used for recall. Each row is scoped by user
and agent and includes category, source reference, importance, confidence,
summary, embedding metadata, archive state, and timestamps.

### Facts and relations

`memory_facts` stores atomic subject-predicate-object facts. Facts can have
event time, validity bounds, learned time, status, and a superseded fact ID.

`memory_relations` links memories with:

- `updates` for replacement;
- `extends` for compatible additional detail; and
- `derives` for supported inference.

When a new fact conflicts with an active fact for the same subject and
predicate, the previous fact is superseded unless the new fact is an extension
or derivation. External-source conflicts with stable or high-confidence facts
can be held for review.

### Sources and provenance

Integration ingestion stores source documents separately from memory.
Documents are split into position-aware chunks. `memory_source_links` connects
an extracted memory to its source chunk and document.

This keeps source evidence available without injecting complete documents into
every prompt.

## Ingestion

Conversation consolidation is a structured model pass after the run. It
extracts a bounded list of durable candidates and excludes secrets, routine
tool output, unsupported guesses, and thread-only details.

Integration ingestion runs through durable jobs with source cursors and
freshness metadata. Chunk extraction attempts are tracked so failed work can be
retried without treating incomplete content as processed.

## Retrieval

The local candidate stage combines:

- Approximate semantic candidates from embedding bands
- SQLite full-text and lexical matches
- Entity mentions
- Memory relations
- Importance, confidence, freshness, and access signals

Superseded and expired facts are excluded from normal current recall. Selected
results can include a bounded version-history note and source location.

When the top result is missing, weak, or ambiguous, the AI engine can generate
query variants and temporal intent, merge the resulting candidates, and rerank
only those candidates. Confident retrieval avoids this additional model call.

Retrieval events record candidate counts, result IDs, estimated context size,
and latency. Enhancement events record why planning was used and which results
survived.

## Prompt context

Memory reaches the model through three bounded paths:

1. Core memory for explicit always-relevant values
2. An auto-maintained static and dynamic profile built from active facts
3. Query-specific recalled memories

All paths are scoped to the selected user and agent. Subagents receive the
agent scope supplied by their parent run.

## Privacy and trust

Memory remains in NeoAgent storage, but hosted models and embedding providers
receive the text sent to them. External source content is marked as untrusted
data in recalled context.

Memory quality claims require reproducible evaluation. The repository includes
retrieval evaluation and benchmark tooling, but the documentation does not
claim parity or superiority based on architecture alone.
