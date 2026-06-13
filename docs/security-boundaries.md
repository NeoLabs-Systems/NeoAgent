# Security Boundaries

NeoAgent processes untrusted content from web pages, email, messaging
platforms, integrations, MCP servers, files, and other external systems. That
content may attempt prompt injection.

Prompt instructions, warning text added to tool results, and injection
detection heuristics are defense-in-depth signals for the model. They are not
authorization boundaries.

## What Is Enforced

| Capability | Enforced boundary |
|---|---|
| Browser, default backend | Runs in a per-user container. The container is started with resource limits and `no-new-privileges`, and no host filesystem mount is added by the runtime manager. |
| Browser, paired extension | Commands are sent to the explicitly paired Chrome extension. This controls that browser profile and is outside the container boundary. |
| Shell, default backend | `execute_command` runs in the same per-user container as the default browser backend. Arbitrary commands are allowed inside that container. |
| Shell, desktop companion | When the operator selects the desktop backend, commands run on the paired desktop with the permissions of the companion process. |
| Workspace file tools | `read_file`, `write_file`, `edit_file`, directory listing, and file search are restricted by server-side path checks to the user's workspace directory. |
| Android | Android tools and `adb shell` run from the NeoAgent host against the selected device or emulator. They are not currently routed through the browser/CLI container. |
| Official integrations | OAuth credentials remain server-side. Accounts configured as read-only have write tools blocked by server-side access checks. |
| Runtime API | The container endpoint is published on loopback. A configured guest token authenticates requests between the server and the runtime. |

The browser and shell container limits the effect of a successful prompt
injection on those two default backends. It does not prevent the model from
requesting a tool call.

## What Is Not Enforced

NeoAgent does not currently provide a general per-tool allowlist, per-run
capability grant, mandatory human approval gate, or separate least-privilege
worker for every tool. The main Node.js server selects and dispatches tools.
Memory, integrations, messaging, MCP orchestration, workspace access, and
Android orchestration remain server-side responsibilities.

The `before_tool_call` hook can block a call when application code registers a
policy, but no default hook turns it into a comprehensive authorization layer.
Do not treat the hook API itself as a security boundary.

Prompt-injection detection on messages and external tool results is heuristic.
It may warn the model or suppress an obviously suspicious inbound message, but
it can miss attacks and must not be the reason a deployment is considered
isolated.

## Deployment Guidance

- Run NeoAgent under a dedicated, unprivileged OS account.
- Prefer the container-backed browser and CLI defaults.
- Do not select the desktop shell backend on a machine containing data the
  agent should not be able to access.
- Treat a paired browser profile as accessible to the agent. Use a dedicated
  profile with only the accounts required for the task.
- Treat an ADB-connected Android device as accessible to the agent, including
  the capabilities exposed by `adb shell`.
- Keep integration accounts read-only unless write access is required.
- Run NeoAgent on a dedicated server or VM when host compromise would affect
  sensitive personal or work data.

For vulnerability reporting, see [Security Policy](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/SECURITY.md).
