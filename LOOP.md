# NeoAgent Loop Operations

NeoAgent uses agent loops for chat, scheduled tasks, integration events,
messaging triggers, and delegated work. The product should
keep the agent autonomous by default while enforcing runtime guardrails for
cost, repeated failure, and risky side effects.

## Active Loops

### Product Automation Runtime
- Cadence: user-defined schedules, integration polls, webhooks, and messaging events.
- State: SQLite `agent_runs`, task lifecycle events, and `STATE.md`.
- Budget: per-task `taskConfig.loopBudget` plus defaults in `loop-budget.md`.
- Phase: autonomous until the task budget is exhausted or paused.
- Handoff: exhausted budget, paused task loop, repeated failures, delivery errors, or approval-required tools.

### NeoAgent Maintenance Triage
- Cadence: manual or daily during active development.
- State: `STATE.md`.
- Phase: report-only until the repository loop is calibrated.
- Handoff: architecture, auth/security, release, billing, and large refactors.

## Safety Gates

- Keep scheduled/event tasks autonomous under budget.
- At 100% budget or a pause flag, skip the task before calling the model.
- Require verification for risky autonomous work such as code edits, shell/device actions, external writes, and repeated failed attempts.
- Keep write, shell, Android, desktop, and high-impact integration actions on approval unless the task is explicitly trusted.
- Prefer isolated worktrees or disposable checkouts for unattended source changes.

## Connectors

NeoAgent supports official integrations and MCP tools. Start unattended loops
with read-only scopes where possible; only expand connector permissions after
the loop has stable logs and clear escalation behavior.

## Budget And Observability

- Runtime task budget defaults: `loop-budget.md`.
- Operator state: `STATE.md`.
- Repository run log: `loop-run-log.md`.
- Product run history: SQLite `agent_runs`, `agent_steps`, `agent_model_usage`, and task lifecycle events.
- Kill switch: set `taskConfig.loopBudget.paused = true` or `taskConfig.loopPaused = true` for a task.

## Worktrees

Unattended code-changing loops should use an isolated worktree or disposable
checkout, run the relevant verifier/tests, and only then propose a PR, comment,
or final delivery. Ordinary chat, research, memory, and messaging tasks do not
require worktree isolation.
