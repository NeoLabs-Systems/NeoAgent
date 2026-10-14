---
title: Memory
sidebar_label: Memory
description: What NeoAgent remembers across conversations, how recall works, and how to inspect or delete it.
---

# Memory

**NeoAgent keeps durable facts about you across conversations, without making every transcript permanent.**

## 🧠 What gets remembered

After each completed run, the model reviews the conversation and saves what will matter later.

| Category | Examples |
| --- | --- |
| Identity and preferences | Name, language, how you like answers |
| Projects and tasks | Ongoing work, responsibilities, commitments |
| Contacts | People and how they relate to you |
| Events | Things with meaningful dates |
| Episodic and procedural | What happened, how you like things done |

- **Left out.** Secrets, credentials, raw tool output, routine narration, guesses and unverified claims.
- **On request.** The agent can also save a memory explicitly with `memory_save`.
- **Scoped.** Memory belongs to one user and one agent. Group-chat runs use memory scoped to that chat.

## 🧩 Structured facts

Each memory carries readable text plus facts: subject, relationship, value, category, confidence and optional time bounds.

| New information | Effect |
| --- | --- |
| A new value for the same subject and relationship | Supersedes the old fact, which keeps its history |
| Compatible extra detail | Extends the existing fact |
| A supported inference | Recorded with confidence capped at 0.6 |

- **Current by default.** Recall skips superseded and expired facts unless history or a past date is requested.
- **Protected facts.** Content from outside sources that contradicts a stable or high-confidence fact is flagged and left out of recall.

## 🔍 Recall

Before each reply, NeoAgent searches memory locally and adds the best matches to the prompt.

- **Signals.** Embedding similarity (when configured), SQLite full-text and keyword matches, entities, and linked memories.
- **Ranking.** Importance, confidence and past use, with a 90-day freshness decay. Identity, preferences and very important memories do not decay.
- **Deeper searches.** The agent calls `memory_recall` itself when the automatic matches are not enough.
- **Embeddings.** Google `gemini-embedding-2` with a Google default model and `GOOGLE_AI_KEY`, else OpenAI `text-embedding-3-small` with `OPENAI_API_KEY`.
- **No embedding key.** Recall falls back to text and keyword matching.

### Always in context

- **Core memory.** Key-value entries you control, added to every prompt.
- **Auto-maintained profile.** A short summary of stable and current facts, built from active memory.

## 📥 Memory from integrations

- **Gmail and Google Calendar.** Recent threads and upcoming events are read into memory in the background, every 10 minutes by default.
- **Interval.** `NEOAGENT_MEMORY_INGESTION_INTERVAL_MS`, also under **Admin › Configuration**.
- **Provenance.** Source text is chunked, marked as external, and linked to the memories drawn from it.
- **Data, not instructions.** External text never acts as a command, and it cannot quietly overwrite established facts.

## 🛠️ Manage memory

Open **Memory** in the app.

| Area | What you can do |
| --- | --- |
| **Memories** | Search, add, select, archive, or delete permanently |
| **Core** | Add, edit and delete core entries |
| **Transfer** | Generate a prompt for another AI, then paste its answer to import memories |
| **Inspect** | Open the **Retrieval Inspector** to see why memories match a query |
| **Knowledge Graph** | Browse the most-mentioned entities and the memories that link them |

:::caution Deleting a conversation keeps its memories
Memories extracted from a conversation stay after it is deleted, so remove both when erasing personal information.
:::

## 🔐 Storage and privacy

- **Local database.** Memory lives in NeoAgent's SQLite database under `~/.neoagent/data/`. No external memory service.
- **Model providers.** Content still leaves the server when a hosted model or hosted embedding provider processes it.
- **Backups.** Back up `~/.neoagent/data/` and `~/.neoagent/agent-data/` together. See [Operations](operations.md).

Implementation details: [Memory architecture](memory-architecture.md).
