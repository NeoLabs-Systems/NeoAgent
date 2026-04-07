# Automation

NeoAgent is built for proactive work: tasks that run later, repeat on a schedule, use tools, and notify you when there is something useful to report.

## Scheduler

Use the **Scheduler** section in the UI to create recurring tasks. A scheduled task has:

| Field | Purpose |
|---|---|
| Name | Human-readable task label |
| Cron expression | Five-field cron schedule |
| Prompt | Self-contained instruction for the future run |
| Enabled state | Active or paused |
| Model override | Optional model for this task |

Scheduled prompts should include the condition for notifying you. For example, ask NeoAgent to message you only when a monitored thing changes, fails, or needs attention.

## Tool Capabilities

Automation can use the same tool surface as normal chat runs:

| Capability | Examples |
|---|---|
| Browser | Navigate, click, type, extract page content, take screenshots, evaluate page JavaScript |
| Files | Read, write, search, and summarize host files through skills |
| CLI | Run shell commands in a persistent terminal through skills |
| Memory | Store durable facts and retrieve useful context |
| Messaging | Send a proactive result through a connected platform |
| MCP | Use tools exposed by configured remote MCP servers |
| Official integrations | Use structured OAuth-backed app tools where available |
| Recordings | List, open, and search recording transcripts |
| Health | Read synced Android Health Connect metrics as summaries |
| Android | Drive a server-attached emulator or device through UI and ADB tools |
| Subagents | Spawn async helper agents inside a longer run |
| Outputs | Generate artifacts, Grok images, Mermaid graphs, and markdown tables |

Prefer official integrations and structured MCP tools over browser automation when both can answer the task. They are usually less brittle and easier to audit.

See [Capabilities](capabilities.md) for the broader tool inventory.

## Safety Expectations

NeoAgent runs on your server and can touch real files, messaging surfaces, browser sessions, and connected services. Keep scheduled prompts narrow and self-contained.

For sensitive automations:

- Use allowlists for messaging platforms.
- Keep secrets in server config, not prompts or skills.
- Prefer read-only checks unless the task explicitly needs to mutate data.
- Ask for notification only when a condition is met to avoid noisy repeated messages.
- Review run history in **Runs** and service logs in **Logs** when behavior is surprising.
- Remember that browser, CLI, Android runtime, and local file tools run on the NeoAgent server or configured worker, not necessarily on your current laptop.
