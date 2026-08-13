# Runtime and tool execution

Tool security is checked before dispatch, independent of the model that
requested an action.

## Unified computer runtime

Browser, desktop, shell, and workspace tools use one provider selected for the
user's **Computer**: `CloudQemuComputerProvider` or the outbound authenticated
desktop-app bridge. Provider selection happens once at the runtime boundary;
the agent tools, control leases, file panels, shell, and browser/desktop loop
do not maintain parallel implementations or silently fall back.

The local provider supports macOS, Windows, and Linux desktop apps. Screen,
input, workspace files, and shell/app access are independent capabilities.
The desktop app can grant each capability once or persistently, deny it, or
revoke it later. Files exposed through the file tools are scoped to
`NeoAgent Workspace` in the local user's home directory. Shell commands run as
that signed-in OS user and never as the NeoAgent server host when the server is
remote.

Teach Mode remains cloud-only because its recorder depends on the guest's CDP,
AT-SPI, shell, and file event collectors.

## Cloud provider

The immutable Debian base image is paired with a persistent system overlay and
a separate sparse data disk for home, workspace, browser sessions, packages,
and Python environments. Temporary caches and logs may be cleaned. The guest
agent is authenticated with a generated token; VNC, QMP, and guest-agent ports
bind only to loopback and are exposed through authenticated same-origin
proxies.

The scheduler derives capacity from host RAM, logical CPUs, free storage, and
the configured reserves. Hardware acceleration uses KVM, HVF, or WHPX; TCG is
an explicit compatibility mode with reduced parallelism.

After the first provisioned boot, the runtime checksum-caches the guest kernel
and initramfs beside the per-user disks. Normal starts use verified direct boot
while retaining UEFI as the provisioning and recovery path. This keeps a
hardware-accelerated ready desktop within the ten-second startup budget on the
supported baseline.

## Control leases

User, agent, and Teach Mode input is mutually exclusive. A user takeover asks
the active run to pause and then grants user control. An active run keeps the
computer awake; an idle computer is shut down without deleting its disks.

## Android

Android remains a separate per-user provider that executes through ADB on the
NeoAgent host. Its device selection, screenshots, UI observation, input,
intents, application installation, and shell commands do not use the Linux
computer.

## Tool security hook

`before_tool_call` runs before execution. Sensitive categories use the user's
deny, approval, session-allow, or persistent-allow policy. Approval waits are
delivered through Socket.IO, and denial or timeout is returned to the agent as
a structured blocked result.

The runtime does not currently provide destination-level network egress
filtering. See [Security](security-boundaries.md) for deployment guidance.
