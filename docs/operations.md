---
title: Operations and troubleshooting
sidebar_label: Operations
description: Service commands, release channels, backups, recovery, and the failures you are most likely to hit.
---

# Operations and troubleshooting

**Day-two work on the machine that hosts NeoAgent: service control, updates, backups and recovery.**

Desktop app installs have no `neoagent` command; use **Settings › System** to start, stop and restart the local server and read its logs.

## 🕹️ Service commands

| Command | What it does |
| --- | --- |
| `neoagent` | Menu of common actions; resumes an unfinished setup |
| `neoagent status` | Service state, version, channel and health |
| `neoagent status --details` | Adds install folder, versions, settings file and process IDs for a support request |
| `neoagent doctor` | Read-only checks, each with the command that fixes it |
| `neoagent start` · `stop` · `restart` | Control the background service |
| `neoagent logs` | Follow the server logs |
| `neoagent version` | Print the installed version |
| `neoagent uninstall` | Stop NeoAgent starting with the computer; data stays |
| `neoagent help --all` | Every command and flag |

- **Port taken.** If another program holds the port, `start` and `restart` offer to move NeoAgent to the next free one.
- **Wrong machine.** Logs from a laptop or client say nothing about a NeoAgent server elsewhere.

### ♻️ Restarts keep work in progress

- **Chats resume.** Web and messaging runs cut off by a restart or update start again, told what they had already done.
- **Not resumed.** Runs interrupted more than an hour ago, sub-agents, scheduled tasks and live voice calls.

## 🔄 Release channels and updates

| Command | What it does |
| --- | --- |
| `neoagent channel` | Show the current channel |
| `neoagent channel stable` · `beta` | Switch channel |
| `neoagent update --notes` | Show what a waiting update changes, without installing it |
| `neoagent update` | Update to the latest version on the current channel |
| `neoagent update beta` | Switch channel and update in one step |

- **Stable** follows the `main` branch and suits normal installs.
- **Beta** gets prerelease builds from the `beta` branch, or the stable build when that is newer.

`neoagent update` runs these steps:

1. Backs up settings, database and agent data.
2. Downloads the new version from GitHub.
3. Reinstalls dependencies and rebuilds the bundled app.
4. Restarts NeoAgent and checks it answers with the new version.

If any step after the download fails, it puts the previous version back and restarts that instead.

- **From the app.** **Admin › Server › Updates** installs updates and switches channel; it is disabled when `NEOAGENT_DEPLOYMENT_MODE=managed`.
- **Old package installs.** `update` backs up, then moves a non-Git install to a checkout at `~/NeoAgent` (or `NEOAGENT_SOURCE_DIR`). Needs Git and npm.

### 🚚 Move an old install by hand

Back up first, then run the repository installer; it keeps existing runtime data and skips onboarding.

```bash
neoagent stop
BACKUP_ARCHIVE="$HOME/neoagent-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -C "$HOME" -czf "$BACKUP_ARCHIVE" .neoagent
bash <(curl -fsSL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/install.sh)
neoagent doctor
```

- **Source directory.** Keep the default `~/NeoAgent` unless it holds something else.
- **Custom runtime root.** If `NEOAGENT_HOME` points elsewhere, archive that directory instead of `~/.neoagent`.

## 💾 Backups

```bash
neoagent backup
```

1. Pauses NeoAgent if it is running.
2. Copies `.env`, `data/` and `agent-data/` to `~/.neoagent/backups/manual-<time>`.
3. Adds compressed, verified copies of the cloud computer disks (QEMU).
4. Starts NeoAgent again.

- **Automatic backups.** `update` and `repair` save a `pre-update-<time>` copy first. Only the three newest are kept.
- **By hand.** Stop the service or take a filesystem snapshot, then copy the paths below.
- **Treat backups as secrets.** They contain credentials and personal data.

| Path | Contents |
| --- | --- |
| `~/.neoagent/.env` | Settings and secrets |
| `~/.neoagent/data/` | SQLite database, logs, cloud computer disks, update state |
| `~/.neoagent/agent-data/` | Skills and memory files |

With `NEOAGENT_HOME` set, these live under that directory instead.

## 🚑 Recovery

```bash
neoagent repair    # "fix" works too
```

1. Stops NeoAgent and backs up your data.
2. In a Git checkout, discards local edits to NeoAgent's own source files.
3. Reinstalls dependencies and rebuilds the bundled app.
4. Prepares the cloud computer and repairs damaged disks.
5. Registers the background service again and starts it.

:::warning Not a backup
- **Keep your own backups.** `repair` keeps settings, accounts and data, but it is no substitute for a backup.
- **Save source edits first.** Commit or copy any changes to NeoAgent's source before running it.
:::

For setup problems:

```bash
neoagent setup --resume   # continue where an interrupted setup stopped
neoagent setup            # run setup again; existing values are kept
neoagent restart
```

- **No secrets in progress files.** An interrupted setup stores only non-secret values such as port and URLs.

## 🩺 Common failures

| Symptom | Check |
| --- | --- |
| Service does not start | `neoagent status`, then `neoagent logs` |
| Chat has no response | Provider key, selected model, provider quota, usage limits under **Settings › Usage** |
| Cloud computer unavailable | `neoagent doctor`; hardware virtualization for `qemu`, a running Docker for `docker`; then `neoagent repair` |
| Browser sign-in fails with "Origin not allowed" | Add that address to `ALLOWED_ORIGINS` |
| "Sign-in needs a secure connection" | Open the `https://` address; secure cookies refuse plain HTTP |
| OAuth fails | Reachable HTTPS `PUBLIC_URL` and the exact callback URI |
| Messaging receives nothing | Channel credentials, webhook and allowlists |
| Task does not run | Enabled state, trigger account, next run, **Runs** |
| Android action fails | ADB visibility, selected device, tool approval |
| Your own computer unavailable | The desktop app is running and connected on that machine |

When reporting a bug, include the NeoAgent version, server OS, install path (desktop app, Docker or installer), `TERMINAL_ENV`, exact steps, and sanitized logs. `neoagent status --details` collects most of it.
