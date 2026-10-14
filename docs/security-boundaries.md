---
title: Security and permissions
sidebar_label: Security and permissions
description: What NeoAgent is allowed to do, where each capability runs, and the limits to know before connecting accounts.
---

# Security and permissions

**Server-side checks decide what the agent may do; model instructions are not a security boundary.**

NeoAgent reads web pages, email, messages, files, integration and MCP results, and any of it can carry prompt injection.

## 🛂 Tool permissions {#tool-permissions}

Set them under **Settings › Permissions**. Built-in tools outside these categories (reading files, browsing, memory, tasks, messaging) run without a prompt, subject to [run trust](#run-trust).

| Category | Tools | Default |
| --- | --- | --- |
| Shell Commands | `execute_command` | Ask me |
| File Writes | `write_file`, `edit_file`, `replace_file_range` | Ask me |
| Android Control | `android_shell`, `android_install_apk`, `android_open_intent`, `android_open_app` | Ask me |
| Desktop Control | `desktop_click`, `desktop_type`, `desktop_press_key`, `desktop_drag`, `desktop_launch_app`, `desktop_observe` | Ask me |
| Browser Scripting | `browser_evaluate` | Ask me |
| Credential Use | `credential_fill_browser`, `credential_http_request` | Ask me |
| Network Write Requests | `http_request` with any method except GET, HEAD or OPTIONS | Ask me |
| Call User | `call_user` | Ask me |
| Skill Changes | `create_skill`, `update_skill`, `delete_skill` | Block |
| External & MCP Tools | Integration tools, MCP tools and any other tool not built into NeoAgent | Ask me |

| Setting | Effect |
| --- | --- |
| Block | The tool never runs |
| Ask me | The run pauses until you decide |
| Allow | The tool runs without asking until you change it |

When a run pauses, the prompt states why and offers four answers:

- **Deny.** The call is blocked and the model is told not to retry.
- **Allow once.** This call only.
- **Allow session.** This tool for the rest of the run.
- **Always allow.** Sets the whole category to Allow.
- **30-second timeout.** An unanswered prompt blocks the call.

### Global security mode

| Mode | Behaviour |
| --- | --- |
| Default (recommended) | The category settings above apply |
| Always ask | Every categorized tool asks; Block still blocks |
| Allow all | No prompts and no Block; only manager limits and who-is-asking checks remain |

- **Server override.** `NEOAGENT_TOOL_SECURITY_MODE` (`default`, `always_ask` or `allow_all`) forces one mode for every account.
- **Managers win.** A category a [manager](agents-and-users.md) switched off stays off in every mode.

## 🧭 Run trust {#run-trust}

Server code tracks who each run acts for and what it has read, so a persuaded model cannot argue past these checks.

### Who is asking

| Run started from | Acts for |
| --- | --- |
| The app, CLI, voice, wearable, your own tasks, your WhatsApp self-chat, a DM from an approved sender | You |
| A group chat, or a DM let in by an **Anyone** policy | Someone else |
| A GitHub mention thread | The public, limited to a fixed tool list |

- **Runs for someone else** may reply in their chat, search the web and use media sent with the message; anything else asks.
- **Slash commands** such as `/memory` and `/tasks` answer only senders who act for you.
- **Channel memory.** Runs for someone else use memory scoped to that chat and never see your core memory.

### What it has read

A run becomes **tainted** once it reads outside content (any tool result except the agent's own bookkeeping, or an event-triggered task's payload), and then asks you before it:

| Call | Why |
| --- | --- |
| Messages or emails a recipient you did not name | Injected text could pick where data goes |
| Sends a write request (`POST`, `PUT`, …) to a host you did not name | Same, for webhooks and APIs |
| Puts a credential-shaped string or a server secret in an outbound argument | Credential exfiltration |
| Creates or edits a task, core memory or skill, or adds an MCP server | The injection would outlive the run |

- **Replies stay quiet.** Answers to the originating chat, and notifications to a task's configured target, do not ask.
- **Marked memories.** Memories saved by a tainted run are tagged external-source and cannot silently replace established facts.
- **Shared trust.** Subagents and delegated agents share their parent's trust record.
- **Allow all** skips taint checks but never the who-is-asking checks.

### Content handling

- **Fenced data.** Messages, channel history, voice transcripts and event payloads are wrapped as data; the fence cannot be closed from inside.
- **Invisible characters.** Unicode tag characters, supplementary variation selectors and bidi overrides are stripped from tool arguments and results.
- **No auto-loaded images.** Images in agent replies show as a link chip that opens only on tap.

## 🖥️ Where tools run

| Capability | Runs on |
| --- | --- |
| Browser, desktop, shell, workspace files | Your [cloud computer](devices.md), or **This device** in the desktop app |
| Android | A per-user Android emulator on the NeoAgent server, driven over ADB |
| Integrations | The NeoAgent server, with the stored account credentials |
| Credential broker | The NeoAgent server; secret values never reach the model |

### Cloud computer backends {#cloud-computer-backends}

| `TERMINAL_ENV` | Isolation |
| --- | --- |
| `qemu` (default) | Per-user micro-VM. The guest user has full sudo inside the VM only. |
| `docker` | Per-user container with resource limits and dropped capabilities. Shares the host kernel. |
| `host` | **None.** Every account's agent runs as the server's OS user. Shell and workspace files only. |

- **Guest token.** Each VM or container gets a random token; its guest agent rejects requests without it.
- **Network reach.** Guests can still reach the NeoAgent host over the network (`10.0.2.2` or `host.docker.internal`).

### This device

- **Outbound only.** The desktop app opens an authenticated connection to the server; no listener runs on your machine.
- **Four grants.** Screen, Mouse & keyboard, Workspace files and Commands & apps, each approved separately.
- **Grant options.** **Allow once**, **Always allow** or **Not now**; revoke any grant from the device panel.
- **Workspace files** stay inside the `NeoAgent Workspace` folder. **Commands & apps** reaches anything your OS user can.

## 🔐 Accounts and credentials

- **Read Only accounts.** Set an integration account's access mode to **Read Only** and its write tools are blocked server-side.
- **Credential broker.** `credential_fill_browser` and `credential_http_request` use Bitwarden items without showing secret values to the model.
- **Bound origins.** Fills need an HTTPS origin saved on the Bitwarden item; requests must match the bound origin, path and method.
- **Redacted responses.** The broker strips auth headers and redacts the secret from responses. Every use is audited.
- **Messaging access.** **Who can message** on each channel accepts **Approved only**, **Anyone** or **No one**.
- **Server-side secrets.** OAuth tokens and integration credentials stay on the server, bound to one user and agent.

## ⚠️ Known limits

- **Built-in read-only tools run freely** in runs that act for you.
- **Outbound reads are not filtered by destination.** Only credential-shaped data in them is checked.
- **Shell output is not checked** for credentials.
- **An approved DM sender** acts for you, with your memory and tools.
- **Signed-in browser sessions** on the cloud computer are available to the agent.
- **Run trust limits where data goes.** It cannot stop a model being misled inside a task you approved.
- **Multi-user is not a hostile-tenant boundary.** Do not host mutually hostile tenants on one server.

## 🧰 Deployment checklist

- **Dedicated OS account.** Run NeoAgent as an unprivileged user.
- **HTTPS** for any remote access.
- **Keep approvals on** for shell, file writes, desktop and Android until a workflow is understood.
- **Keep integrations Read Only** unless writes are required.
- **Avoid Allow all** for open-ended runs that browse the web or read messages.
- **Avoid `TERMINAL_ENV=host`** unless every account could be trusted with a shell on the server.
- **Back up secrets and data** securely, and test account recovery.

Implementation details are in [Runtime and tool execution](runtime-and-tools.md); report vulnerabilities through [SECURITY.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/SECURITY.md).
