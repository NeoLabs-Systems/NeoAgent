# Setup

## Requirements

- **Node.js** 18+ — [nodejs.org](https://nodejs.org) or `nvm`
- **git**

## Quick start

```bash
git clone https://github.com/NeoLabs-Systems/NeoAgent.git
cd NeoAgent
./neo.sh install
```

The installer will:
1. Check Node.js and git
2. Walk you through `.env` configuration (API keys, port, session secret)
3. Install npm dependencies
4. Register a persistent system service (launchd on macOS, systemd on Linux)

Open **http://localhost:3060** when done.

---

## Manual start (no service)

```bash
cp .env.example .env   # or create manually — see docs/configuration.md
npm install
node server/index.js
```

---

## Service management

| Command | Action |
|---|---|
| `./neo.sh start` | Start service |
| `./neo.sh stop` | Stop service |
| `./neo.sh restart` | Restart |
| `./neo.sh update` | Pull latest + restart |
| `./neo.sh status` | Show PID / state |
| `./neo.sh logs` | Tail log files |
| `./neo.sh uninstall` | Remove service |

---

## Reverse proxy (optional)

Set `SECURE_COOKIES=true` and `ALLOWED_ORIGINS=https://yourdomain.com` in `.env` when terminating TLS with nginx / Caddy / Cloudflare Tunnel.

Example Caddy block:

```
yourdomain.com {
  reverse_proxy localhost:3060
}
```
