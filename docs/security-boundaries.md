---
title: Security and permissions
sidebar_label: Security and permissions
description: What NeoAgent is allowed to do, where each capability runs, and the limitations you must know before connecting accounts.
---

# Security and permissions

*Authorization comes from server-enforced boundaries — not from asking the model nicely.*

NeoAgent reads untrusted content from websites, email, messages, files,
integrations, and MCP servers. Any of that content can contain prompt
injection. Model instructions help, but published detectors and prompt
defenses are routinely bypassed by adaptive attacks, so authorization comes
from server-enforced boundaries and operator choices.

## 🛂 Tool permissions

Sensitive tools are grouped into categories for shell commands, file writes,
privileged Android actions, desktop control, browser evaluation, network
writes, and skill mutation.

Each category can be:

| Policy | Result |
| --- | --- |
| Deny | The tool does not run |
| Require approval | The run pauses for a user decision |
| Allow | The tool runs for the current session |
| Always allow | The stored policy permits future runs |

The default is approval for sensitive categories. Skill mutation is
denied by default. Users can also select a global default, always-ask, or
allow-all mode.

Approval prompts time out after 30 seconds. A denied or timed-out call is
reported to the model as blocked rather than executed.

## 🧭 Run trust

Every run records who it acts for and whether outside content has reached it.
The checks are deterministic and run outside the model, so a persuaded model
cannot talk its way past them.

**Who is asking.** Runs started in the app, the CLI, your own schedules, your
WhatsApp self-chat, or a DM from a sender you allowlisted act for you. Runs
started from a group chat, or from a DM let in by an *open* access policy, act
for someone else. Such a run can chat in its own conversation, search the web,
and work on the media that came with the message. Anything else, such as
reading your files or memory, running commands, messaging other chats, or
creating tasks, asks you first. Slash commands like `/memory` and `/tasks`
answer only senders who act for you, and these runs use channel-scoped memory
instead of yours.

**What it has read.** A run becomes *tainted* once it reads outside content:
web pages, email, integration or MCP results, command output, or the payload
of an event-triggered task. A tainted run asks you before it:

| Call | Why |
| --- | --- |
| Messages or emails a recipient you did not name | Injected text can pick where data goes |
| Sends a write request to a host you did not name | Same, for webhooks and APIs |
| Puts a credential-shaped string or server secret in an outbound argument | Credential exfiltration |
| Creates or edits a task, core memory, a skill, or an MCP server | The injection would outlive the run |

Replies to the chat the run came from, and task notifications to the target
you configured, never ask. Ordinary memories saved by a tainted run are
marked as external-source, so they cannot silently overwrite established
facts. Subagents and delegated agents share their parent's trust.

The approval prompt says why it appeared. Allow-all mode skips the taint
checks but never the who-is-asking checks, because that mode is your choice
for your own requests.

**Content handling.** Messages, channel history, voice transcripts, and event
payloads are fenced as data, and the fence cannot be closed from inside.
Invisible Unicode (tag characters, variation-selector smuggling, bidi
overrides) is stripped from tool results and tool arguments, so what you
approve is what runs. The app does not auto-load images in agent replies:
they appear as a link chip that opens only on tap, which closes the
zero-click image-URL exfiltration channel.

## 🖥️ Where tools run

| Capability | Runtime |
| --- | --- |
| Browser, desktop, shell, and workspace files | Selected Computer provider: per-user QEMU guest or authenticated desktop app |
| Android | The selected host-attached ADB device or emulator |
| Integrations | NeoAgent server using stored account credentials |

Android commands do not run in the Linux computer. The cloud computer has
controlled sudo only inside the guest and no direct access to the NeoAgent
host. Local computer commands run with the signed-in desktop user's rights only
after the corresponding app-level permission is granted.

## 🔐 Account and integration controls

- Credentials remain on the server.
- Official integration accounts can be set to read-only.
- Users and agents have separate application data and assignments.
- Messaging allowlists restrict which chats and senders can trigger runs.
- A guest token authenticates communication with the isolated runtime.
- Local computer connections are outbound, session-authenticated, user-scoped,
  and never expose a listener on the desktop machine.
- Local file tools are confined to `NeoAgent Workspace`; local shell access is
  a separate, explicit permission because it can reach anything the OS user can.

## ⚠️ Important limitations

- Read-only tools do not require approval by default in runs that act for you.
- Outbound reads (web search, browsing, GET requests) are not filtered by
  destination; only credential-shaped data in them is checked.
- A DM sender you allowlist acts for you with your memory and tools.
- The computer browser can access its persistent signed-in sessions.
- ADB can expose broad access to the selected Android device.
- Run trust limits where injected instructions can send data or plant
  follow-ups. It cannot stop a model from being misled inside a task you
  approved.
- Multi-user application isolation does not make NeoAgent suitable for
  mutually hostile tenants on a shared host.

## 🧰 Deployment guidance

- Run NeoAgent as a dedicated unprivileged OS account.
- Use HTTPS for remote access.
- Keep shell, desktop, Android, and write categories on approval until the
  workflow is understood.
- Keep persistent computer browser sessions scoped to accounts the agent may use.
- Keep integrations read-only unless writes are required.
- Do not use allow-all for open-ended runs that browse the web or read messages.
- Back up secrets and user data securely and test account recovery.

The implementation details are documented in
[Runtime and tool execution](runtime-and-tools.md). Report vulnerabilities
through [SECURITY.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/SECURITY.md).
