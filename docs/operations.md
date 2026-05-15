# Operations

## Service State

```bash
neoagent status      # install root, config path, runtime paths, release channel, service state
neoagent logs        # first stop for unexpected behavior in UI, messaging, OAuth, or tasks
neoagent restart
```

## Release Channels

```bash
neoagent channel           # show current channel
neoagent channel stable    # switch to stable releases (recommended for most installs)
neoagent channel beta      # switch to prerelease builds
```

## Updates

```bash
neoagent update
```

Follows the configured release channel. On git installs, pulls the latest source and reinstalls dependencies when they change. On npm installs, reinstalls the global package from the matching npm tag. Verifies the bundled web client and restarts the service.

## Recovery

```bash
neoagent fix
```

Use when NeoAgent is in a broken state after a self-edit or corrupted install. On git installs: backs up runtime data, saves local tracked changes, resets source files, reinstalls dependencies, and restarts.

For configuration-only issues:

```bash
neoagent setup
neoagent restart
```

## Troubleshooting

| Symptom | First step |
|---|---|
| Service won't start | `neoagent logs` — look for startup errors |
| UI loads but agent doesn't respond | Confirm an AI provider key is set in **Settings → AI Providers** |
| OAuth integration fails | Confirm `PUBLIC_URL` is reachable and the redirect URI matches |
| Messaging not delivering | Check credentials in the messaging tab; confirm `PUBLIC_URL` for webhook-based platforms |
| Tasks not running | Confirm the task is enabled; check **Runs** and **Logs** for error output |
| Broken after update | `neoagent fix` — resets source, reinstalls, restarts |

## Runtime Data

| Path | Contents |
|---|---|
| `~/.neoagent/.env` | Server config and secrets |
| `~/.neoagent/data/` | Database, session data, logs, update status |
| `~/.neoagent/agent-data/` | Skills, memory, daily data |

Back up these paths before moving a server or doing manual repairs.
