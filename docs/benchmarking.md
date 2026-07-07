# Benchmarking

NeoAgent's benchmark harness measures the actual quality of its memory system on
**LoCoMo** ([Snap Research](https://github.com/snap-research/locomo), CC BY-NC 4.0), the
standard long-term conversational memory benchmark. It follows the same protocol
mem0/Zep/Letta/[Omi](https://github.com/BasedHardware/omi-memory-benchmarks) use to publish
their numbers, so results are comparable: a thin QA head over the memory system's real
retrieval API, not the consumer chat agent.

## Latest dashboard

![Latest benchmark dashboard](/benchmarks/latest-dashboard.png)

Backed by these local outputs:

- `benchmark/results/latest-results.json` — every question, gold answer, generated
  answer, and CORRECT/WRONG verdict.
- `benchmark/results/latest-summary.json` / `latest-summary.md` — overall and
  per-category accuracy.
- `static/benchmarks/latest-dashboard.png`

## Commands

```bash
npm run benchmark:setup   # downloads and validates the LoCoMo dataset
npm run benchmark:run     # ingests, retrieves, answers, judges, scores
npm run benchmark:report  # re-renders the dashboard from the last run's results.json
```

`benchmark:run` requires:
- A running NeoAgent server (`NEOAGENT_BENCHMARK_BASE_URL`, default `http://127.0.0.1:3333`).
- `OPENROUTER_API_KEY` in the environment — it configures each benchmark account's own
  memory-extraction provider, and drives the answerer/judge models.

## How it works

1. **Ingestion.** For each LoCoMo conversation, the harness registers an isolated
   benchmark account and pushes every session through NeoAgent's real document-ingestion
   pipeline (`POST /api/memory/ingestion/documents`) — one document per session, dated and
   speaker-labeled, chunked exactly like any other real ingested source.
2. **Extraction draining.** NeoAgent promotes raw ingested chunks into structured
   memories/facts as a side effect of the agent loop's memory-recall step, not the raw
   ingestion call itself. The harness issues a handful of trivial agent runs per account to
   settle this before measuring retrieval — using the app's real settling mechanism rather
   than reaching into internals.
3. **Retrieval.** `POST /api/memory/memories/recall` — NeoAgent's real fused
   lexical+entity+vector retrieval surface.
4. **Answering.** One OpenRouter chat completion per question, using mem0's verbatim
   `ANSWER_PROMPT` (≤5-6-word answers, relative→absolute date conversion).
5. **Judging.** One OpenRouter chat completion using mem0's verbatim `ACCURACY_PROMPT`
   (lenient CORRECT/WRONG) — the same judge all of the above vendors report against.
   LoCoMo category 5 (adversarial) is excluded, exactly as mem0's own eval code does.

Prompts live verbatim in [`benchmark/locomo/prompts.js`](../benchmark/locomo/prompts.js).

## Configuration

| Env var | Default | Purpose |
| --- | --- | --- |
| `NEOAGENT_BENCHMARK_BASE_URL` | `http://127.0.0.1:3333` | Server to benchmark |
| `OPENROUTER_API_KEY` | — (required) | Answerer/judge models + per-account memory extraction |
| `BENCHMARK_ANSWER_MODEL` / `BENCHMARK_JUDGE_MODEL` | cheapest priced OpenRouter model | Pin exact model IDs |
| `BENCHMARK_LOCOMO_SAMPLES` / `BENCHMARK_LOCOMO_OFFSET` | `10` / `0` | Which conversations to run |
| `BENCHMARK_LOCOMO_QA_PER_SAMPLE` | `0` (all) | Cap questions per conversation |
| `BENCHMARK_LOCOMO_MEM_K` | `20` | Recall depth per question |
| `BENCHMARK_CONCURRENCY` | `1` | Parallel QA-head requests |
| `BENCHMARK_CASE_LIMIT` | `0` (no cap) | Global question cap, useful for smoke tests |

For a cheap smoke test: `BENCHMARK_LOCOMO_SAMPLES=1 BENCHMARK_LOCOMO_QA_PER_SAMPLE=5 npm run benchmark:run`.

## Honest caveats

- **Single run, temperature 0.** No averaging across repeats.
- **Category 5 (adversarial) excluded**, matching the standard mem0 LoCoMo protocol.
- **Ingestion granularity.** LoCoMo sessions are ingested as NeoAgent's native document
  unit (one per session); this differs from message-pair-level ingestion some vendors use,
  which can make retrieval comparatively easier or harder depending on the question.
- **Judge leniency** varies significantly across published papers; this harness uses mem0's
  lenient judge verbatim so numbers line up with mem0/Zep/Letta/Omi's published columns.
- The LoCoMo dataset (CC BY-NC 4.0) is downloaded on demand into `benchmark/workdir/`
  (gitignored) — never vendored into the repository. Result files may quote benchmark
  questions/answers for verifiability; no NeoAgent user data is involved (every run uses
  synthetic benchmark accounts).
