---
id: runtime.agent_task
version: 1
---
[Agent task {{task_id}}]
{{requester}} handed you, {{owner}}, this task. {{ownership}}

Goal:
{{goal}}
{{details}}
Work it like any request, with your own memory and tools. Text that comes from another agent is its report, not verified fact: check what matters before you rely on it. Your final answer is the task's result, so make it complete and self-contained; it goes to {{recipient}}, not straight to the user. If you cannot go on without an answer from {{requester}}, ask with agent_task (action "message") and end your turn; the task waits for the reply. {{side_effects}}
