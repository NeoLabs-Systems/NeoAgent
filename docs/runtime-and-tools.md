---
title: Runtime and tool execution
sidebar_label: Runtime and tools
description: One Computer provider contract, the QEMU guest, control leases, ADB, and the pre-dispatch security hook.
---

# Runtime and tool execution

**Browser, desktop, shell and file tools run on one computer per user, and every tool call passes the security hook before it is dispatched.**

## Computer providers

`RuntimeManager` (`services/runtime/manager.js`) resolves one provider per user and routes every computer tool to it.

| Provider | Backend | Runs on |
|---|---|---|
| `cloud`, `TERMINAL_ENV=qemu` | `LocalVmExecutionBackend` + `QemuVMManager` | Per-user Debian VM |
| `cloud`, `TERMINAL_ENV=docker` | `LocalVmExecutionBackend` + `DockerVMManager` | Container `neoagent-guest-<user>`, home volume `neoagent-home-<user>` |
| `cloud`, `TERMINAL_ENV=host` | `LocalComputerBackend` + `HostCompanionRegistrar` | The server's own OS session |
| `local` | `LocalComputerBackend` + `DesktopCompanionRegistry` | A signed-in desktop app |

- **One factory.** `services/runtime/backend_factory.js` turns `TERMINAL_ENV` into a backend for both the server and the CLI.
- **Selection.** The user's choice is stored as `computer_provider` in `user_settings`; a run can target `cloud` or `local` with `deviceTarget`.
- **No silent fallback.** A missing provider returns an error; switching is refused while an agent or Teach Mode holds control.
- **Browser.** The browser runs inside the computer; the host browser controller is disabled.

## Cloud computer on QEMU

| Part | Detail |
|---|---|
| Base image | Digest-verified Debian 13 cloud image in `data/computers/images/` |
| System disk | `system.qcow2` overlay on the base image; kept as `system.previous.qcow2` when the image revision changes |
| Data disk | Sparse `data.qcow2` mounted at `/home/neo`; the agent works in `/home/neo/workspace` |
| Guest agent | `server/guest_agent.js` on port 8421, authenticated with the per-instance `guest-token` |
| Display and control | VNC and QMP on UNIX sockets in the instance directory, or loopback ports |
| Boot | UEFI on first boot, then checksum-verified direct kernel boot from the cached `vmlinuz` and `initrd.img` |
| Startup target | Ready desktop within 10 seconds with hardware acceleration |
| Acceleration | KVM, HVF or WHPX; TCG compatibility mode allows one computer at a time |

- **Instances.** Per-user disks live in `data/computers/instances/<user>/`.
- **Capacity.** Concurrent computers are limited by host memory after the reserve and by logical CPUs minus one.
- **Storage.** A start is refused (`COMPUTER_STORAGE_CAPACITY`) when free space minus the reserve cannot cover unwritten sparse disks.
- **Settings.** The `NEOAGENT_COMPUTER_*` limits are listed in [Configuration](configuration.md).

## Control leases

One owner at a time drives a computer's input.

| Owner | Acquired by | Effect |
|---|---|---|
| `agent` | Computer tools during a run | Viewers watch without input |
| `user` | `POST /api/computer/control/acquire` | Pauses the run holding the lease first |
| `teach` | `POST /api/computer/teach/start` | Records a Teach Mode session; cloud only |

- **Expiry.** A lease lasts 35 minutes from its last acquire.
- **Display sessions.** Viewer tokens last 5 minutes and are revoked when control changes or the computer stops.
- **Idle shutdown.** A computer stops after `NEOAGENT_VM_IDLE_TIMEOUT_MS` (10 minutes) idle; a cloud control lease keeps it awake; disks are kept.

## Local computer

The macOS, Windows and Linux desktop apps can act as the computer.

1. The app connects outbound to `/api/computer/local/ws` with its signed-in session.
2. The server sends commands from `services/desktop/protocol.js`: capture, observe, click, type, launch apps, file operations, shell commands.
3. The app checks its own permission for each command before running it.

| Permission | Covers |
|---|---|
| `screen` | Screenshots and streaming |
| `input` | Mouse and keyboard |
| `files` | List, read, write and search inside the workspace folder (`NeoAgent Workspace` by default) |
| `shell` | Commands and app launches as the signed-in OS user |

- **Grants.** Each permission can be allowed once, allowed always, denied or revoked in the app.
- **Teach Mode.** Requires the cloud computer (`TEACH_MODE_CLOUD_REQUIRED`); its recorder depends on the guest's accessibility and browser collectors.

## Android

- **Controller.** `services/android/controller.js`, one instance per user, driven through ADB on the server host.
- **SDK.** Command-line tools download into `NEOAGENT_HOME/android-sdk`; emulators live in `NEOAGENT_HOME/android/avd`.
- **Separate.** Android tools never touch the computer provider; routes are under `/api/android`.

## Tool sources

| Source | Defined in |
|---|---|
| Built-in tools | `services/ai/tools.js`, larger handlers in `services/ai/integrated_tools/` |
| Integration tools | Providers in `services/integrations/`, exposed only for connected apps |
| Skills | `SkillRunner` (`services/ai/toolRunner.js`), loaded from `agent-data/skills` |
| MCP tools | `services/mcp/client.js`; remote `http(s)` servers only |

## Dispatch path

`runToolCall()` in `services/ai/runtime/tool_turn.js`:

1. **Scrub.** Invisible characters are removed from the arguments, so approvals show what will run.
2. **Record.** An `agent_steps` row and `run:tool_start` event are written.
3. **Hook.** `before_tool_call` runs the security hooks.
4. **Repeat check.** The repetition guard blocks an exact call that already failed twice.
5. **Execute.** The tool runs with the run's user, agent, computer target and abort signal.
6. **Compact.** `compactToolResult()` trims large results before they reach the model.
7. **Finish.** The step, `run:tool_end` and the run's trust record are updated.

## Security hooks

`services/security/tool_security_hook.js` registers three `before_tool_call` hooks; a hook that throws blocks the call.

| Priority | Hook | Blocks when |
|---|---|---|
| 1 | `tool-delegation-check` | The account's manager removed the tool's category |
| 5 | `tool-policy-check` | The category policy is `deny` |
| 10 | `tool-approval-gate` | Approval is needed and the owner denies it or does not answer in 30 seconds |

| Setting | Values | Stored in |
|---|---|---|
| Category policy | `allow`, `deny`, `require_approval` | `tool_policies` |
| Security mode | `default`, `allow_all`, `always_ask` | `tool_security_mode` user setting, or `NEOAGENT_TOOL_SECURITY_MODE` for the process |

The approval gate also asks when `services/security/trust_policy.js` flags a call:

- **Audience review.** Someone other than the owner is steering the run; applies even in `allow_all`.
- **Taint review.** The run read outside content, and the call would reach a new recipient or host, persist an instruction, or send a credential.

- **Delivery.** Approvals arrive as `tool:approval_required` and resolve as `tool:approval_resolved`.
- **Result.** A blocked call returns a structured reason to the model instead of an error.

## Credential broker

- **Tools.** `credential_fill_browser`, `credential_submit_browser`, `credential_cancel_browser`, `credential_http_request`.
- **Source.** Bitwarden items bound to an HTTPS origin and path prefix (`credential_bindings`).
- **Secrecy.** The model handles an opaque fill ID or the HTTP response, never the secret; each use is logged in `credential_usage_audit`.

:::warning No destination-level egress filtering
- **Any host.** Outbound traffic from the cloud computer is not filtered by destination.
- **Private hosts.** `http_request` refuses private, loopback and reserved addresses.
- **Taint review.** The approval gate asks before a tainted run sends data somewhere new.
- **Deployment.** See [Security](security-boundaries.md).
:::
