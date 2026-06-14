# Memory

NeoAgent keeps useful context across conversations without treating the entire
chat transcript as permanent memory. Memory data is stored by the NeoAgent
server and scoped to a user and agent.

## What gets remembered

After a conversation, the model can extract durable information such as:

- Identity and stable preferences
- Ongoing projects and responsibilities
- Important contacts and relationships
- Events with meaningful dates
- Current context that will matter in a later conversation

Routine tool output, credentials, guesses, and one-off task narration should
not become long-term memory. The agent can also save an explicit fact with its
memory tool when a conversation requires it.

## Structured facts

A saved memory contains readable text plus structured facts. A fact records a
subject, relationship, value, category, confidence, and optional time bounds.
New information can:

- update and supersede an older fact;
- extend an existing fact with compatible detail; or
- record a supported inference at lower confidence.

Normal recall favors active facts and excludes superseded or expired facts.
Historical queries can still use version context when it is relevant.

## Retrieval

NeoAgent combines several local signals:

- Semantic similarity when embeddings are configured
- SQLite full-text and lexical matching
- Entity matches
- Fact relationships and current-version status
- Importance, confidence, freshness, and prior use

Confident results use this local fast path. Ambiguous retrieval can ask the
configured model to reformulate the search and rerank known candidates. The
model does not receive unrestricted access to the database.

Stable facts and current context also form a bounded user profile that is
available to the owning agent even when a narrow search would not retrieve it.

## Integration memory

Supported integrations can ingest source documents in the background. Source
content is chunked, indexed, and linked to extracted memories so recalled
context can retain provenance.

External source text is treated as data rather than instructions. Conflicts
with high-confidence or stable memories may require review instead of silently
replacing the existing fact.

## Manage memory

Open **Memory** to search and inspect stored items. NeoAgent supports editing,
archiving, bulk deletion, permanent deletion, core-memory management, and
conversation search.

Deleting a conversation is not the same as deleting extracted memory. Review
both areas when removing personal information.

## Storage and privacy

Memory is stored in NeoAgent's SQLite database and runtime data directories.
It is not sent to an external memory service. Content still leaves the server
when a hosted model or hosted embedding provider is used to process it.

Back up `~/.neoagent/data/` and `~/.neoagent/agent-data/` together. See
[Memory architecture](memory-architecture.md) for the implementation and
[Operations](operations.md) for backup guidance.
