# NeoAgent Loop Operations

NeoAgent uses agent loops for chat, scheduled tasks, integration events,
messaging triggers, and delegated work. The product keeps the agent autonomous
by default while enforcing guardrails for repeated failure and risky side
effects.

## Active Loops

### Product Automation Runtime
- Cadence: user-defined schedules, integration polls, webhooks, and messaging events.
- State: SQLite `agent_runs`, task lifecycle events, and `STATE.md`.
- Phase: autonomous until completed, disabled, or explicitly paused.
- Handoff: paused task loop, repeated failures, delivery errors, or approval-required tools.

### NeoAgent Maintenance Triage
- Cadence: manual or daily during active development.
- State: `STATE.md`.
- Phase: report-only until the repository loop is calibrated.
- Handoff: architecture, auth/security, release, billing, and large refactors.

## Safety Gates

- Keep scheduled/event tasks autonomous until completion or an explicit pause.
- On a pause flag, skip the task before calling the model.
- Require verification for risky autonomous work such as code edits, shell/device actions, external writes, and repeated failed attempts.
- Keep write, shell, Android, desktop, and high-impact integration actions on approval unless the task is explicitly trusted.
- Prefer isolated worktrees or disposable checkouts for unattended source changes.

## Connectors

NeoAgent supports official integrations and MCP tools. Start unattended loops
with read-only scopes where possible; only expand connector permissions after
the loop has stable logs and clear escalation behavior.

## Control And Observability

- Operator state: `STATE.md`.
- Repository run log: `loop-run-log.md`.
- Product run history: SQLite `agent_runs`, `agent_steps`, `agent_model_usage`, and task lifecycle events.
- Kill switch: set `taskConfig.loopPaused = true` for a task. The legacy
  `taskConfig.loopBudget.paused` form is still recognized.

## Worktrees

Unattended code-changing loops should use an isolated worktree or disposable
checkout, run the relevant verifier/tests, and only then propose a PR, comment,
or final delivery. Ordinary chat, research, memory, and messaging tasks do not
require worktree isolation.
