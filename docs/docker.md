# Docker install

Docker Compose is the fastest way to run NeoAgent on a server you administer.
The container runs the same server as a native install, keeps its state in one
named volume, and exposes the `neoagent` CLI for configuration and diagnostics.

Requirements: Docker Engine 24 or newer (or Docker Desktop) with the Compose v2
plugin. Nothing else — Node.js, npm, and Flutter are not needed on the host.

## Install

```bash
git clone https://github.com/NeoLabs-Systems/NeoAgent.git
cd NeoAgent
docker compose up -d
docker compose logs -f neoagent
```

The first start builds the image, creates the data volume, generates the
session and admin secrets, applies the database schema, and prints the address
together with a one-time setup code:

```
Open http://localhost:3333 and enter the one-time setup code: <code>
```

Open that address, enter the code, and create the owner account. The code
expires 15 minutes after the container starts. Print a new one at any time:

```bash
docker compose exec neoagent neoagent claim
```

## Choose a port

Create a `.env` file next to `docker-compose.yml`:

```bash
NEOAGENT_PORT=8080
```

Then `docker compose up -d`. The container always listens on 3333 internally;
`NEOAGENT_PORT` only changes the published host port.

## Configure

Deployment settings are read from the same `.env` file (or the shell
environment) when the container starts:

| Variable | Purpose |
|---|---|
| `NEOAGENT_PORT` | Published host port. Default `3333`. |
| `PUBLIC_URL` | Public base URL for OAuth callbacks and external links. |
| `SECURE_COOKIES` | Set `true` behind HTTPS or a TLS-terminating proxy. |
| `TRUST_PROXY` | Set `true` when a reverse proxy sets `X-Forwarded-*`. |
| `ALLOWED_ORIGINS` | Comma-separated additional CORS origins. |
| `TZ` | Container time zone. Default `UTC`. |

Everything else — provider API keys, integration credentials, email delivery —
belongs to the runtime configuration inside the volume. Connect AI providers in
**Settings → AI Providers**, or use the CLI:

```bash
docker compose exec neoagent neoagent env set OPENAI_API_KEY sk-...
docker compose restart neoagent
```

`neoagent env list` shows the current values with secrets masked. See
[Configuration](configuration.md) for the full key reference. For container
options that this compose file does not cover, add a `docker-compose.override.yml`
next to it; Compose merges it automatically.

## Use the CLI

The CLI is installed in the container and reads the same configuration and
database as the server:

```bash
docker compose exec neoagent neoagent status
docker compose exec neoagent neoagent doctor
docker compose exec neoagent neoagent admin
```

Lifecycle commands belong to Compose in this installation. `neoagent start`,
`stop`, `restart`, `update`, `repair`, `uninstall`, `install`, and `logs`
report the Compose command to run on the host instead of acting on a service
the container does not own.

## Update

```bash
git pull
docker compose up -d --build
```

The data volume is preserved, and schema migrations run on the next start.

Container installs update by rebuilding the image, so the in-app self-update and
release-channel controls are disabled (`NEOAGENT_DEPLOYMENT_MODE=managed` is set
in the image) and `neoagent update` reports the Compose command instead.

## Back up

All persistent state lives in the `neoagent_neoagent-home` volume: the runtime
`.env`, `data/neoagent.db`, and the agent workspaces under `agent-data`.

```bash
docker compose stop neoagent
docker run --rm -v neoagent_neoagent-home:/data -v "$PWD:/backup" \
  busybox tar czf /backup/neoagent-backup.tar.gz -C /data .
docker compose start neoagent
```

Restore by extracting the archive back into a fresh volume before the first
start. See [Operations](operations.md) for the wider backup and recovery guide.

## Optional: isolated browser and CLI

The agent's browser and shell tools run each user's session in a separate
container. In a Docker install those containers are created through the host
Docker daemon, so the overlay in `docker-compose.isolation.yml` mounts the
daemon socket into the NeoAgent container.

**Mounting the Docker socket grants the container root-equivalent control of
the host.** Enable it only on a machine where that is acceptable, and read
[Security boundaries](security-boundaries.md) first.

```bash
sudo install -d -o 1000 -g 1000 -m 700 /var/lib/neoagent/agent-data
docker compose -f docker-compose.yml -f docker-compose.isolation.yml up -d
```

The first command creates the agent data directory owned by the container user.
It is mounted at the same path inside and outside the container because the
Docker daemon resolves each session's workspace bind mount against the host
filesystem.

If the socket is not in group id 999 on your host, set the real one:

```bash
NEOAGENT_DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
```

One limitation: NeoAgent normally installs iptables rules that block sandbox
containers from reaching cloud instance-metadata endpoints. A container cannot
write host firewall rules, so the server logs a warning and skips them. Apply
equivalent rules on the host, or set `NEOAGENT_VM_EGRESS_FIREWALL=0` once your
own host rules are in place.

Without this overlay the server runs normally; only the isolated browser and
CLI tools are unavailable, and the startup log carries a
`Could not set up isolated network` warning for each of the two runtimes. The
Chrome extension and desktop companion remain available as alternatives.

## Behind a reverse proxy

Terminate TLS at the proxy, forward WebSocket upgrades, and set:

```bash
PUBLIC_URL=https://agent.example.com
SECURE_COOKIES=true
TRUST_PROXY=true
```

Bind the published port to the loopback interface (`127.0.0.1:3333:3333` in a
`docker-compose.override.yml`) so only the proxy can reach the server.

## Remove

```bash
docker compose down      # stop and remove the container, keep the data volume
docker compose down -v   # also delete the data volume and everything in it
```
