# Installation

NeoAgent supports macOS and Linux hosts. It installs as a long-running service,
so use a machine that remains online when you expect automations, messaging, or
remote access to work.

## Requirements

- Node.js 20 or newer with npm
- A macOS or Linux user account that can install packages
- Enough disk and memory for the models and runtime you choose
- QEMU for the isolated browser and terminal runtime

The installer attempts to install QEMU with Homebrew, `apt`, `dnf`, or `yum`.
If the host uses another package manager, install QEMU first.

```bash
# macOS
brew install qemu

# Ubuntu or Debian
sudo apt-get update
sudo apt-get install -y qemu-system qemu-utils
```

## Install NeoAgent

```bash
npm install -g neoagent
neoagent install
```

`neoagent install` checks the host, creates the runtime configuration, installs
application dependencies and supported system tools, prepares the isolated
runtime, and registers a launchd or systemd user service when available.

Read the post-install actions printed by the command. They describe anything
the installer could not complete automatically.

Open `http://localhost:3333` on the server. For remote access, configure HTTPS
and `PUBLIC_URL` before connecting integrations or mobile clients.

## First run

1. Create the first user account.
2. Open **Settings > AI Providers**.
3. Configure a hosted provider or connect local Ollama.
4. Select a model and send a message in **Chat**.
5. Open **Settings > Tool Permissions** and review the approval policy before
   enabling browser, shell, file-write, desktop, or Android actions.

The first isolated-runtime boot downloads and prepares an Ubuntu image. It can
take several minutes and is not required for a basic model-only chat.

## Check the installation

```bash
neoagent status
neoagent logs
```

`status` reports the install path, configuration, release channel, service
state, and server health. Use `logs` on the machine running NeoAgent; logs from
another computer do not describe the remote server.

## Global npm permission errors

If `npm install -g` fails with `EACCES` on macOS, install Node through
[nvm](https://github.com/nvm-sh/nvm) so global packages live in your user
directory. Running the npm command with `sudo` also works, but makes later
package ownership harder to manage.

## Next steps

- [Configure models](models.md)
- [Create specialist agents](agents-and-users.md)
- [Connect accounts and messaging](integrations.md)
- [Set up automation](automation.md)
- [Review deployment security](security-boundaries.md)
