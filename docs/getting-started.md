---
title: Installation
sidebar_label: Installation
description: Install NeoAgent, pick a setup mode, create the first account, and verify the service.
---

# Installation

**Install NeoAgent on a machine you control, create the admin account, and finish onboarding in the app.**

## 🧰 Before you start

- **A machine you control.** A PC, home server, NAS or VPS. Keep it on if tasks, messaging or remote access should keep working.
- **An AI model.** An API key, a local Ollama server, or an account you already have. See [Models](models.md).
- **About 1 GB for the cloud computer.** Its system image downloads on first use.
- **Hardware virtualization, ideally.** The cloud computer runs in QEMU with KVM, HVF or WHPX; without them it falls back to slower emulation.

## 📦 Pick an install path

| Path | Best for | You need |
| --- | --- | --- |
| [Desktop app](#desktop-app) | macOS, Windows or Linux, no terminal | Nothing else |
| [Docker](docker.md) | Servers and NAS boxes that already run containers | Docker |
| [Repository installer](#repository-installer) | macOS and Linux servers | Git, Node.js 20.19 or newer, npm |

:::note npm packages
NeoAgent is no longer published to the npm registry; use one of the paths above.
:::

### 🖥️ Desktop app {#desktop-app}

1. Download the installer from the [latest release](https://github.com/NeoLabs-Systems/NeoAgent/releases/latest): `.dmg` for macOS, `.exe` for Windows, `.AppImage`, `.deb` or an Arch `.pkg.tar.zst` for Linux.
2. Open the app and choose **Set up NeoAgent on this computer**.
3. Pick **Quickstart** or **Full setup**, and the **Stable** or **Beta** backend channel.
4. Wait while the app downloads, verifies and starts a signed runtime. Node.js, npm and Git are not required.
5. Choose **Create your account**.

- **Server already running elsewhere.** The same screen lists **Nearby NeoAgent servers** and offers **Enter an address manually**.
- **Manage it later.** **Settings › System** starts, stops and restarts the local server, switches its channel and shows its logs.
- **No terminal command.** Desktop installs do not put `neoagent` on your `PATH`; the runtime lives under `~/.neoagent`.

### 🐳 Docker

Follow the [Docker guide](docker.md), then continue with [First run](#first-run).

### ⌨️ Repository installer {#repository-installer}

A bash script for macOS and Linux:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/install.sh)
```

1. Checks for `git`, `node` and `npm`.
2. Asks for the install directory (default `~/NeoAgent`) and the release channel (`stable` or `beta`).
3. Clones the repository, installs dependencies and links the `neoagent` command.
4. Runs `neoagent install`, which asks for a [setup mode](#setup-modes) and starts NeoAgent as a background service.

- **Existing data is kept.** A database or agent data under `~/.neoagent` (or `NEOAGENT_HOME`) is reused, not reset.
- **Autostart.** A launchd agent on macOS, a systemd user service on Linux. Without either, run `neoagent start` after a reboot.
- **Come back later.** `neoagent` on its own resumes an interrupted setup, installs if nothing is there, or opens a menu of common actions.

:::warning Re-running the installer
If the install directory already holds a NeoAgent checkout, the installer resets it to the release branch and discards local edits there.
:::

## 🧩 Setup modes {#setup-modes}

| Mode | What it does |
| --- | --- |
| **Quickstart** (default) | Private data folder, a free port (3333 when available), autostart, then asks how to connect an AI: sign in with an account, paste an API key, or decide later |
| **Full setup** | Steps through Installation and network, AI providers, Integrations, Voice and media, and Review; offers to download the cloud computer now and to add yt-dlp |

```bash
neoagent setup --quick    # safe defaults
neoagent setup --full     # every section; needs an interactive terminal
neoagent setup --resume   # continue an interrupted setup
```

- **Automation.** Add `--json` to `install`, `setup`, `status` or `doctor` for versioned JSON events.
- **Optional parts.** Integrations, voice, media download and the cloud computer image can wait. Core setup and sign-in work without them.

## 🎬 First run {#first-run}

1. Open `http://localhost:3333/app`, or the address the installer printed.
2. Create the first account. It becomes the server's admin.
3. Walk through onboarding:

| Step | What happens |
| --- | --- |
| **Intro** | A short landscape video; skip it any time. Windows and Linux go straight to **Continue to setup**. |
| **Welcome** | Lists the steps ahead. |
| **Model** | Pick a default model or **Auto**. With none available, add a provider key on the spot or use **Sign in with OpenRouter**. NeoAgent can't answer until a model works. |
| **Computer** | Desktop app only. **Cloud computer** (private sandbox, always on) or **This computer**, with Screen, Mouse & keyboard, Workspace files, and Commands & apps permissions. |
| **Messaging** | Optional. Connect one messaging platform, for example by scanning the WhatsApp QR code. |
| **Routines** | Optional. Switch on suggested tasks. Phones ask for notification permission. |
| **Ready** | Send a first message or open NeoAgent. |

- **Redo it.** **Settings › General › Redo onboarding**.
- **Check permissions first.** Review **Settings › Permissions** before allowing shell, file-write, desktop or Android actions.

## 👥 Accounts and sign-up

- **Claim the server first.** The first account becomes admin, so create it before anyone else can reach the address.
- **Sign-up is open by default.** To hand out access yourself, turn on **Admin › Configuration › Access › Require a sign-up key** (or set `NEOAGENT_ALLOW_SIGNUP=false`) and create keys under **Sign-up keys**.
- **One account per person.** Each account gets its own agents, memory and cloud computer.
- **More admins.** `neoagent admin grant <username>`.
- **Headless first account.** `neoagent account create --username <name> --password <password>` works only while no account exists.

## 🌐 Reach it from other devices {#network-access}

NeoAgent serves plain HTTP on its port.

- **Local network.** The desktop and Android apps find servers on your LAN through `_neoagent._tcp.local`.

:::warning HTTPS outside your own network
Expose NeoAgent beyond your LAN only through a TLS reverse proxy such as Caddy, nginx or Traefik.
:::

1. Point the proxy at `http://127.0.0.1:3333` (your `PORT`).
2. Tell NeoAgent its public address, then restart:

```bash
neoagent env set PUBLIC_URL https://agent.example.com
neoagent env set ALLOWED_ORIGINS https://agent.example.com,http://localhost:3333
neoagent env set SECURE_COOKIES true
neoagent env set TRUST_PROXY true
neoagent restart
```

| Variable | Why |
| --- | --- |
| `PUBLIC_URL` | OAuth callbacks, email links and the address NeoAgent hands out |
| `ALLOWED_ORIGINS` | Browsers can sign in and save changes only from listed origins; once set, list `localhost` too |
| `SECURE_COOKIES` | Session cookies travel over HTTPS only; plain-HTTP sign-ins are refused |
| `TRUST_PROXY` | Reads the client address and protocol from the proxy's headers |

- **Set them explicitly.** Both cookie settings default to on for an `https://` `PUBLIC_URL`, but the installer writes them as `false`.
- **From the app.** **Admin › Configuration › General** edits the public URL, allowed origins and secure cookies.
- **Reference.** [Core server settings](configuration.md#core-server).

## ✅ Check the installation

```bash
neoagent status
neoagent doctor
neoagent logs
```

| Command | Shows |
| --- | --- |
| `status` | Service state, version, channel and health; `--details` adds folders, versions and process IDs |
| `doctor` | Read-only checks, each with the command that fixes it |
| `logs` | Follows `~/.neoagent/data/logs/neoagent.log` and `neoagent.error.log` |

Run them on the machine that hosts NeoAgent; a laptop's logs say nothing about a server elsewhere.

## ➡️ Next steps

- [Models](models.md): a fresh install has none configured
- [Integrations](integrations.md): accounts and messaging channels
- [Automation](automation.md): schedules and event triggers
- [Agents and users](agents-and-users.md): specialist agents and more people
- [Security and permissions](security-boundaries.md): read before the server is reachable by anyone but you
- [Operations](operations.md): updates, backups and recovery
