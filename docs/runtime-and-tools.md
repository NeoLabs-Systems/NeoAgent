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
| Built-in tools | `services/ai/tools/definitions/` for schemas and metadata, `tools/handlers/` for code, larger handlers in `services/ai/integrated_tools/` |
| Integration tools | Providers in `services/integrations/`, exposed only for connected apps |
| Skills | `SkillRunner` (`services/ai/toolRunner.js`), loaded from `agent-data/skills` |
| MCP tools | `services/mcp/client.js`; remote `http(s)` servers only |

## Coding tools

The tools a run codes with work through the workspace service and `executeCliCommand`, so they behave the same in a guest VM, on a desktop companion, and in host mode. Their output is bounded, and the shell stays the escape hatch.

| Tool | Does | Notes |
|---|---|---|
| `repo_overview` | Root, branch, dirty files, layout, languages, manifests, docs, test command | `services/workspace/repo_inspect.js` |
| `search_files` | Text or regex search, grouped by file, with context lines and globs | `rg` when installed, otherwise `grep`; `services/workspace/code_search.js` |
| `read_file`, `read_files` | Lines or ranges of files | A whole-file read stops after 400 lines and says where |
| `edit_file` | Exact-text edits to one file | All or nothing; a failed match reports the nearby lines; `services/workspace/text_edits.js` |
| `repo_diff` | Changed files and a bounded diff | By default the run's own changes, read from its checkpoints; `services/workspace/repo_diff.js` |
| `run_tests` | Runs the tests, returns counts and only the failures | The full log is an artifact; asks for approval as `shell` does; `services/workspace/run_tests.js` |

- **Containment.** The read tools run without approval, so their scripts check the physical path and refuse anything outside the workspace. `run_tests` is approved as `shell` is, and `repo_diff` follows the repositories the run itself changed, so those two may leave it.
- **No state change.** `repo_overview` and `repo_diff` leave the tree, index, and branch alone. `repo_diff` reads the working tree through a throwaway index, which writes only unreachable objects, as a checkpoint does.
- **Test results.** `parseTestOutput` (`services/ai/test_output.js`) returns null when a run counts nothing, so "no tests found" never reads as a clean pass. Cancelled tests count as failed, and chained runs add up.
- **Writes.** `WorkspaceManager` writes through a temporary file and a rename, keeping the file's mode and following symlinks.

## Dispatch path

`runToolCall()` in `services/ai/runtime/tool_turn.js`:

1. **Scrub and type.** Invisible characters are removed from the arguments, so approvals show what will run, and near misses of the tool's declared types are fixed (`"5.0"` for an integer, `"true"`, a JSON string for an array, an enum value in the wrong case) in `tools/coerce_args.js`. Anything else is left for the tool to reject.
2. **Record.** An `agent_steps` row and `run:tool_start` event are written.
3. **Policy gate.** A call missing an argument its schema requires is answered with what is missing, and nothing runs; it never counts toward a repeat or a rest. `before_tool_call` runs the security hooks, and the decision goes on the run ledger. Nothing a tool returned can raise what a later call may do.
4. **Repeat check.** A read repeated with nothing changed is suppressed, and an exact call that already failed twice is blocked. A remote tool (`latencyClass: 'remote'`: search, HTTP, messaging, integrations, MCP) that fails three times in a row with the same error rests for a minute, or as long as the service's `retry-after` asks. Tools on the agent's own computer never rest: their failures depend on what they were asked. A re-read after an edit runs normally.
5. **Tracking.** File and shell changes are snapshotted with Git before and after, so `repo_diff` shows what the run changed. This needs Python 3 and Git on the computer; without them the change still runs. `workspace_rollback` does not restore a shared workspace: correct the specific edits instead.
6. **Execute.** The tool runs with the run's user, agent, computer target and abort signal. A tool that reads a file the agent made (a message attachment, an upload, an image to analyse) names that argument in its metadata (`fileArgs`): the file is first fetched from the agent's computer through `/workspace/files/download`, kept as an owned artifact, and the tool gets the artifact's path. The shell starts in the workspace unless a `cwd` is given.
7. **Compact.** `compactToolResult()` trims large results before they reach the model: 12,000 characters by default, 24,000 for files and 16,000 for commands and the browser. A stored setting below that is ignored, since a smaller budget is paid back in turns. What is cut is saved; `read_artifact` reads it by line range or finds lines with `query`.
8. **Finish.** The step, `run:tool_end` and the run's trust record are updated.

## Security hooks

`services/security/tool_security_hook.js` registers three `before_tool_call` hooks; a hook that throws blocks the call.

| Priority | Hook | Blocks when |
|---|---|---|
| 1 | `tool-delegation-check` | The account's manager removed the tool's category |
| 5 | `tool-policy-check` | The category policy is `deny` |
| 10 | `tool-approval-gate` | Approval is needed and the owner denies it or does not answer in time: 30 seconds in the app, 5 minutes when it is also asked in a chat |

| Setting | Values | Stored in |
|---|---|---|
| Category policy | `allow`, `deny`, `require_approval` | `tool_policies` |
| Security mode | `default`, `allow_all`, `always_ask` | `tool_security_mode` user setting, or `NEOAGENT_TOOL_SECURITY_MODE` for the process |

The approval gate also asks when `services/security/trust_policy.js` flags a call:

- **Audience review.** Someone other than the owner is steering the run; applies even in `allow_all`.
- **Taint review.** The run read outside content, and the call would reach a new recipient or host, persist an instruction, or send a credential.

- **Delivery.** Approvals arrive as `tool:approval_required` and resolve as `tool:approval_resolved`. A run that came from a chat also asks there; the first answer from either place decides.
- **Result.** A blocked call returns a structured reason to the model instead of an error.

### Approving from a chat

`services/messaging/chat_approvals.js` puts the approval up in the chat the run came from and removes it once answered or expired, where the platform allows deleting.

| Platform | How it asks | How it is answered |
|---|---|---|
| WhatsApp | Poll, deleted for everyone afterwards | Vote |
| Discord | Message with reactions, deleted afterwards | ✅ allow, 🔁 always allow, 🚫 don't allow |
| Telegram | Inline buttons, deleted afterwards | Tap |
| Slack, Teams, Google Chat, Matrix, Signal, LINE, Mattermost, iMessage, IRC | Text | Reply with an option's word, in the app's language or `allow`, `always`, `deny` |

Typed answers also work on WhatsApp, Discord and Telegram. They are consumed only while an approval is open in that chat and only from someone who may decide; otherwise the message reaches the agent as usual.

**Who may decide.** Only someone who speaks for the owner: an allowlisted DM sender, the account's self chat, the linked person on a shared account, or a person listed by name under group senders. Other group members, anyone admitted by an open policy, and per-group member rules can talk to the agent but not approve, so nobody can approve what the audience review held for them. Other people's answers are ignored silently.

**Where it does not ask.** Public threads (GitHub), runs with no chat (app, schedules), a DM from an unvetted sender, and a group with nobody listed by name. Those stay app-only, so a request is not shown to people who could not answer it. A group sees only what is being asked; a DM also sees the reason and a short detail with credentials hidden.

**Wording.** `services/security/approval_copy.js` writes each approval once, in the owner's language, for the app and chats alike. An approval that times out is deleted and a short note says it was skipped.

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
