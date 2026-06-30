# Benchmarking

NeoAgent includes an end-to-end benchmark harness that drives the app through
its authenticated HTTP surface instead of calling internal engine methods
directly. The harness configures OpenRouter models, submits benchmark tasks,
collects run events and usage data, and writes normalized result artifacts.

## Latest dashboard

![Latest benchmark dashboard](/benchmarks/latest-dashboard.png)

The generated image is backed by these local outputs:

- `benchmark/results/latest-results.json`
- `benchmark/results/latest-summary.json`
- `benchmark/results/latest-summary.md`
- `static/benchmarks/latest-dashboard.png`

## Commands

```bash
npm run benchmark:setup
npm run benchmark:run
npm run benchmark:report
```

## Model selection

The benchmark harness is OpenRouter-first. Edit the `OPENROUTER_MODEL_IDS`
variable in `benchmark/config.js` to pin exact model IDs, or leave it empty to
use the current cheap-tier OpenRouter models discovered at runtime.

## Benchmark coverage

- `GAIA`, `BrowseComp`, `WebArena`, `VisualWebArena`, and `SWE-bench` are wired
  as exact public-suite adapters. When their official datasets or external
  runners are not installed, they are reported as blocked instead of being
  approximated.
- `NeoAgent Representative Tasks` runs first-party agent tasks through
  `/api/agents` and scores them from the persisted run details.
- `NeoAgent Memory Retrieval` seeds memories over `/api/memory`, recalls them
  through the app routes, and scores retrieval quality with the same metric
  code used by the server evaluation module.

## Reproducibility

- Public-suite setup manifests are written under `benchmark/workdir/<suite>/`.
- The harness uses one benchmark account and persists per-run usage summaries
  through the existing NeoAgent run detail endpoints.
- Blocked suites are intentional and explicit. The harness never substitutes a
  simplified local task and labels it as a public benchmark result.

## Public benchmark prerequisites

### GAIA

- Access to the gated [GAIA dataset](https://huggingface.co/datasets/gaia-benchmark/GAIA).
- `HF_TOKEN` in the environment.
- A Python environment with `datasets` installed if you want `benchmark:setup`
  to export a normalized local cache automatically.
- Either an exact evaluator wired through
  `NEOAGENT_BENCHMARK_GAIA_RUNNER` or a repository-local exact runner added to
  the harness. The current adapter intentionally reports `blocked` until an
  official evaluator path is configured.

### BrowseComp

- A checkout of [openai/simple-evals](https://github.com/openai/simple-evals),
  which `benchmark:setup` can clone into `benchmark/workdir/browsecomp/`.
- Exact BrowseComp case extraction from that repo.
- An official evaluator command exposed through
  `NEOAGENT_BENCHMARK_BROWSECOMP_RUNNER`.

### WebArena

- Docker installed and running.
- The official [WebArena](https://webarena.dev/) environment and task sites.
- Browser automation dependencies required by the official runner.
- An exact runner command exposed through
  `NEOAGENT_BENCHMARK_WEBARENA_RUNNER`.

### VisualWebArena

- Docker installed and running.
- The official VisualWebArena environment.
- A vision-capable configured benchmark model.
- An exact runner command exposed through
  `NEOAGENT_BENCHMARK_VISUAL_WEBARENA_RUNNER`.

### SWE-bench

- Docker installed and running.
- A checkout of [SWE-bench](https://github.com/SWE-bench/SWE-bench), which
  `benchmark:setup` can clone into `benchmark/workdir/swebench/`.
- The official dataset/runtime and enough disk/network budget for repo/image
  setup.
- An exact runner command exposed through
  `NEOAGENT_BENCHMARK_SWEBENCH_RUNNER`.

On this machine, `docker` is currently missing, so exact `WebArena`,
`VisualWebArena`, and `SWE-bench` execution remain blocked until Docker and the
official runners are installed.
