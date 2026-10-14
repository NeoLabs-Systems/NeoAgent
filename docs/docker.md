---
title: Docker
sidebar_label: Docker
description: Run NeoAgent with Docker Compose, keep its data in one volume, update by pulling, and pick a cloud computer backend.
---

# Docker

**Run NeoAgent as a container on a server, home server, NAS or VPS you control.**

## 🚀 Quick start

1. Make a folder and fetch the compose file:

```bash
mkdir neoagent && cd neoagent
curl -fsSLO https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/compose.yaml
```

2. Start NeoAgent:

```bash
docker compose up -d
```

3. Open `http://localhost:3333/app` and create the first account. It becomes the admin.
4. Continue with [First run](getting-started.md#first-run).

- **Image.** `ghcr.io/neolabs-systems/neoagent` for `linux/amd64` and `linux/arm64`.
- **Secrets.** The first start generates `SESSION_SECRET` and the cloud computer token in the data volume.
- **Health.** `docker compose ps` shows `healthy` once `/api/health` answers.
- **Claim it first.** Create the admin account before anyone else can reach the port.

:::warning Signing in from another device
Browsers sign in only from addresses listed in `ALLOWED_ORIGINS`; empty means localhost only. Set it in `compose.yaml` before opening NeoAgent from another machine, for example `http://192.168.1.20:3333,http://localhost:3333`.
:::

| Tag | Tracks |
| --- | --- |
| `latest` | Newest stable release |
| `beta` | Newest release, beta or stable |
| `X.Y.Z`, `X.Y` | One release, or the newest patch of a stable minor line |

## 💾 Where data lives

Everything NeoAgent writes goes to the `neoagent_neoagent-data` volume, mounted at `/data`.

| Path | Holds |
| --- | --- |
| `/data/.env` | Generated secrets and every setting saved in the app |
| `/data/data/neoagent.db` | Accounts, chats, tasks and settings (SQLite) |
| `/data/data/computers` | The cloud computer system image and each account's disks |
| `/data/agent-data` | Memory, skills and workspaces |

- **The container holds no state.** Remove and recreate it freely; the volume keeps everything.
- **Bind mount instead of a volume?** The folder must be writable by uid 1000, for example `sudo chown -R 1000:1000 ./neoagent-data`.
- **`/data/.env` wins.** Its values override the `environment:` block in `compose.yaml`.
- **Change a saved value.** Use **Admin › Configuration** or `neoagent env set` (see [Commands](#commands)).

## 🔄 Updating

```bash
docker compose pull
docker compose up -d
```

- **Data stays.** Database migrations run on start.
- **No self-update.** The Admin update button and `neoagent update` are off inside the image.
- **Switch channel or pin a version.** Change the `image:` tag, then run the two commands above.

## 🖥️ Cloud computer backends

Each account's cloud computer runs where the compose files say.

| Setup | Add | Needs | You get |
| --- | --- | --- | --- |
| **Default** | nothing | nothing | QEMU in software emulation: desktop, browser, shell, files, Teach Mode. Slower, one computer at a time |
| **KVM** | `compose.kvm.yaml` | Linux host with `/dev/kvm` | Same features with hardware acceleration; several computers at once as memory allows |
| **Docker** | `compose.docker.yaml` | Linux host, Docker socket, host networking | One container per account: browser, shell, files. No desktop or Teach Mode |

- **First start.** Each cloud computer installs its software once; the shared Debian image downloads on first use.
- **Disk.** Each computer gets an 8 GiB system disk plus a data disk of up to `NEOAGENT_COMPUTER_MAX_DISK_GIB`.

### ⚡ KVM

Compose reads the `.env` file next to `compose.yaml` for these values. NeoAgent never sees that file.

```bash
curl -fsSLO https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/compose.kvm.yaml
cat >> .env <<EOF
COMPOSE_FILE=compose.yaml:compose.kvm.yaml
KVM_GID=$(stat -c %g /dev/kvm)
EOF
docker compose up -d
```

### 🐳 Docker socket

```bash
curl -fsSLO https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/compose.docker.yaml
cat >> .env <<EOF
COMPOSE_FILE=compose.yaml:compose.docker.yaml
DOCKER_GID=$(stat -c %g /var/run/docker.sock)
EOF
docker compose up -d
```

- **Host networking.** NeoAgent listens on the host's port 3333 directly; set `PORT` to change it.
- **First computer.** The host builds the `neoagent-guest-agent` image once, which takes a few minutes.

:::danger The Docker socket is root
Mounting `/var/run/docker.sock` gives NeoAgent root-level control of the host. Use this backend only on a machine you dedicate to NeoAgent.
:::

:::note TERMINAL_ENV=host
It runs every account's commands inside the NeoAgent container, next to the database and secrets. No compose file sets it.
:::

## ⚙️ Settings that matter

Set these under `environment:` in `compose.yaml`, then run `docker compose up -d`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `ALLOWED_ORIGINS` | empty: localhost only | Browser addresses allowed to sign in; once set, list `http://localhost:3333` too |
| `PUBLIC_URL` | empty | HTTPS address behind a proxy; also turns on secure cookies and proxy trust |
| `NEOAGENT_ALLOW_SIGNUP` | on | `false` closes sign-up; the first account can always register |
| `TERMINAL_ENV` | `qemu` | Cloud computer backend; `compose.docker.yaml` sets `docker` |
| `NEOAGENT_COMPUTER_MAX_DISK_GIB` | `12` | Largest data disk per cloud computer |
| `NEOAGENT_HOME` | `/data` | Set by the image; where the volume is mounted |

- **Another port.** Change the left side of `"3333:3333"`, for example `"8080:3333"`.
- **Every other variable.** See [Configuration](configuration.md).
- **Not in the image.** Chromium for slide and video export, `ffmpeg` and `yt-dlp`.

## 🔒 HTTPS and reverse proxy

1. Point the proxy at `http://<docker-host>:3333`. It must pass WebSocket upgrades; Caddy does by default.
2. Set both addresses in `compose.yaml`:

```yaml
    environment:
      ALLOWED_ORIGINS: "https://agent.example.com,http://localhost:3333"
      PUBLIC_URL: "https://agent.example.com"
```

3. Run `docker compose up -d`.

- **Proxy on the same host.** Publish `"127.0.0.1:3333:3333"` so plain HTTP stays off the network.
- **Saved in the app before?** `/data/.env` wins; change the value in **Admin › Configuration**.
- **More detail.** [Reach it from other devices](getting-started.md#network-access) and [Configuration](configuration.md#core-server).

## 🧰 Commands {#commands}

| Command | Does |
| --- | --- |
| `docker compose logs -f neoagent` | Follows the server log |
| `docker compose exec neoagent neoagent doctor` | Runs read-only checks |
| `docker compose exec neoagent neoagent admin grant <username>` | Makes an account admin |
| `docker compose exec neoagent neoagent env set KEY value` | Writes a setting to `/data/.env`; apply it with `docker compose restart` |

- **Apps on phones and desktops.** Nearby-server discovery does not cross Docker's network; enter the address by hand.

## 🗄️ Backup and restore

Stop NeoAgent first so the database and computer disks are consistent.

```bash
docker compose stop
docker run --rm -v neoagent_neoagent-data:/data:ro -v "$PWD":/backup alpine \
  tar czf /backup/neoagent-backup.tgz -C /data .
docker compose start
```

Restore into the same volume:

```bash
docker compose down
docker run --rm -v neoagent_neoagent-data:/data -v "$PWD":/backup alpine \
  sh -c 'find /data -mindepth 1 -delete && tar xzf /backup/neoagent-backup.tgz -C /data'
docker compose up -d
```

- **Keep the archive private.** It contains `/data/.env` with the session secret and saved keys.
- **Size.** Cloud computer disks are included and can take several GB.
