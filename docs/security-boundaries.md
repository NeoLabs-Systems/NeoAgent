# Security and permissions

NeoAgent reads untrusted content from websites, email, messages, files,
integrations, and MCP servers. Any of that content can contain prompt
injection. Model instructions and injection warnings help, but authorization
must come from server-enforced boundaries and operator choices.

## Tool permissions

Sensitive tools are grouped into categories for shell commands, file writes,
privileged Android actions, desktop control, browser evaluation, network
writes, and skill mutation.

Each category can be:

| Policy | Result |
|---|---|
| Deny | The tool does not run |
| Require approval | The run pauses for a user decision |
| Allow | The tool runs for the current session |
| Always allow | The stored policy permits future runs |

The default is approval for sensitive categories. Skill mutation is
denied by default. Users can also select a global default, always-ask, or
allow-all mode.

Approval prompts time out after 30 seconds. A denied or timed-out call is
reported to the model as blocked rather than executed.

## Where tools run

| Capability | Runtime |
|---|---|
| Browser, desktop, shell, and workspace files | Selected Computer provider: per-user QEMU guest or authenticated desktop app |
| Android | The selected host-attached ADB device or emulator |
| Integrations | NeoAgent server using stored account credentials |

Android commands do not run in the Linux computer. The cloud computer has
controlled sudo only inside the guest and no direct access to the NeoAgent
host. Local computer commands run with the signed-in desktop user's rights only
after the corresponding app-level permission is granted.

## Account and integration controls

- Credentials remain on the server.
- Official integration accounts can be set to read-only.
- Users and agents have separate application data and assignments.
- Messaging allowlists restrict which chats and senders can trigger runs.
- A guest token authenticates communication with the isolated runtime.
- Local computer connections are outbound, session-authenticated, user-scoped,
  and never expose a listener on the desktop machine.
- Local file tools are confined to `NeoAgent Workspace`; local shell access is
  a separate, explicit permission because it can reach anything the OS user can.

## Important limitations

- Read-only tools do not require approval by default.
- Outbound network access is not filtered by destination.
- The computer browser can access its persistent signed-in sessions.
- ADB can expose broad access to the selected Android device.
- Prompt-injection detection cannot identify every malicious instruction.
- Multi-user application isolation does not make NeoAgent suitable for
  mutually hostile tenants on a shared host.

## Deployment guidance

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
