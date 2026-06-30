# NeoAgent Loop State

Last run: manual initialization

## High Priority

- Keep autonomous scheduled/event tasks under budget with report-only fallback at the warning threshold.
- Verify that risky autonomous work still gets final evidence verification before delivery.
- Watch for tasks that repeatedly hit `loop_budget_report_only` or `loop_budget_exhausted`.

## Watch List

- Add UI controls for per-task `loopBudget` once the runtime behavior is stable.
- Consider wiring `after_tool_call` if runtime governance needs post-tool accounting.
- Consider a first-class verifier subagent role for unattended code-change workflows.

## Recent Noise

-

---

Runtime state lives in SQLite. This file is the repository/operator summary for
loop maintenance.
