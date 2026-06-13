# Security Boundaries

NeoAgent processes untrusted content from web pages, email, messaging
platforms, integrations, MCP servers, files, and other external systems. That
content may attempt prompt injection.

Prompt instructions, warning text added to tool results, and injection
detection heuristics are defense-in-depth signals for the model. They are not
authorization boundaries. The boundaries below are enforced in server-side
code and cannot be bypassed by any model-generated content.

## What Is Enforced

### Infrastructure isolation

| Capability | Enforced boundary |
|---|---|
| Browser, default backend | Runs in a per-user Docker container with resource limits (`no-new-privileges`, no host filesystem mount). |
| Browser, paired extension | Commands are sent to the explicitly paired Chrome extension. Controls that browser profile; outside the container boundary. |
| Shell, VM backend | `execute_command` runs in the same per-user container as the default browser backend. |
| Shell, desktop companion | Commands route through `ShellWorkerPool` — a `child_process.fork()` pool of isolated worker processes (`server/services/cli/shell_worker.js`). Workers carry **no server imports**: no database handle, no JWT secret, no app state. A compromised command result cannot read main-process memory. |
| Workspace file tools | `read_file`, `write_file`, `edit_file`, directory listing, and file search are restricted by server-side path checks to the user's workspace directory. |
| Android | `android_shell` and related tools run from the NeoAgent host via ADB against the selected device or emulator. |
| Official integrations | OAuth credentials remain server-side. Accounts configured as read-only have write tools blocked by server-side access checks. |
| Runtime API | The container endpoint is published on loopback. A guest token authenticates requests between the server and the runtime. |

### Tool policy system

The `before_tool_call` hook fires before every tool execution in both the
sequential and parallel engine paths. Two handlers are registered at startup
and cannot be removed by agent code:

**Priority 5 — per-category policy check** (`server/services/security/tool_security_hook.js`)

Every tool is mapped to one of seven sensitive categories:

| Category | Tools |
|---|---|
| `shell` | `execute_command` |
| `file_write` | `write_file`, `edit_file` |
| `android_privileged` | `android_shell`, `android_install_apk`, `android_open_intent`, `android_open_app` |
| `desktop_control` | `desktop_click`, `desktop_type`, `desktop_press_key`, `desktop_drag`, `desktop_launch_app`, `desktop_observe` |
| `browser_privileged` | `browser_evaluate` |
| `network_write` | `http_request` (POST/PUT/PATCH/DELETE only) |
| `skill_mutation` | `create_skill`, `update_skill`, `delete_skill`, `create_ai_widget`, `update_ai_widget`, `delete_ai_widget` |

Read-only tools (`think`, `web_search`, `browser_navigate`, `read_file`, etc.)
are in a static `SAFE_TOOLS` set and bypass all policy checks with a single
`Set.has()` call.

Per-category policy (stored in `tool_policies` table, one row per user per
category):

| Policy | Effect |
|---|---|
| `deny` | Tool call is blocked immediately. The model receives a structured error and can explain the restriction to the user. |
| `require_approval` | Execution suspends; the user receives a real-time prompt (bottom sheet + optional push notification). Decision options: Deny / Allow once / Allow session / Always allow. |
| `allow` | Tool runs without interruption. Grants expire at session end. |
| `allow_always` | Tool runs without interruption. Persisted to DB; never expires. |

Default policy for all categories is `require_approval`, except `skill_mutation` which defaults to `deny`.

**Priority 10 — approval gate** (`server/services/security/approval_gate_service.js`)

When a category policy is `require_approval`, execution is suspended and a
`tool:approval_required` event is emitted to the user's Socket.IO room. The
agent loop awaits the decision with a 30-second timeout. If no decision is
received, the tool is denied and the model is informed of the timeout.

### Global security mode

Users can override all per-category settings with a global mode (stored in
`user_settings` under key `tool_security_mode`):

| Mode | Behaviour |
|---|---|
| `default` | Per-category policies apply (recommended). |
| `allow_all` | All tool policy and approval checks are bypassed. The agent runs without interruption. |
| `always_ask` | Every sensitive tool requires approval regardless of per-category settings. |

### Agent-loop feedback

When a tool is blocked, the model receives a structured result:

```json
{ "tool": "execute_command", "status": "blocked", "blocked_by": "policy|user_denied|approval_timeout", "reason": "..." }
```

The `reason` field contains an actionable message the model can surface to the
user (e.g., pointing to Settings → Tool Permissions, or acknowledging that the
user denied the call and it should not retry).

## What Is Not Enforced

- **No per-tool allowlist at the schema/selection level.** A tool blocked by
  policy is still listed in the tool catalog. The block fires at execution
  time, not at selection time.
- **No mandatory approval for safe tools.** Tools in `SAFE_TOOLS` always
  execute without a policy check.
- **No network egress filtering.** The `http_request` tool (non-write methods)
  can reach any URL reachable from the server.
- **Prompt-injection detection is heuristic.** The detection layer may warn the
  model but cannot prevent every injection attempt.

## Deployment Guidance

- Run NeoAgent under a dedicated, unprivileged OS account.
- Prefer the container-backed browser and CLI defaults (VM backend).
- Do not select the desktop shell backend on a machine containing data the
  agent should not access.
- Use `require_approval` or `deny` for `shell` and `android_privileged` on
  machines where you run personal or work data alongside NeoAgent.
- Treat a paired browser extension as giving the agent control of that browser
  profile. Use a dedicated profile.
- Treat an ADB-connected Android device as accessible to the agent, including
  capabilities exposed by `adb shell`.
- Keep integration accounts read-only unless write access is required.
- The `allow_all` global mode is suitable only for trusted automated
  environments where the operator controls all input. Do not use it for
  open-ended agentic sessions that browse the web or read email.

For vulnerability reporting, see [Security Policy](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/SECURITY.md).
