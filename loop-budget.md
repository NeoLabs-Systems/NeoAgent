# NeoAgent Loop Budget

## Runtime Defaults

| Loop | Max runs/day | Max tokens/day | Max sub-agent spawns/run |
|---|---:|---:|---:|
| Scheduled/event task | 24 | 250k | Agent setting `subagent_max_children_per_run` |
| Maintenance triage | 1 | 100k | 0 |

## Per-Task Override

Store overrides in `taskConfig.loopBudget`:

```json
{
  "loopBudget": {
    "maxRunsPerDay": 12,
    "maxTokensPerDay": 150000,
    "paused": false
  }
}
```

Set `loopBudget.paused = true` or `loopPaused = true` to skip a task before it
calls the model.

## On Budget Exceed

1. At the daily cap, skip execution and record `loop_budget_exhausted`.
2. Investigate repeated budget events from Runs or the task lifecycle timeline.

## Kill Switch

- Per task: `taskConfig.loopBudget.paused = true`
- Legacy-compatible alias: `taskConfig.loopPaused = true`
