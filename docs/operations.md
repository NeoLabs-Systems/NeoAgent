# Operations and troubleshooting

Run service commands on the machine hosting NeoAgent.

## Service commands

```bash
neoagent status
neoagent start
neoagent stop
neoagent restart
neoagent logs
```

`status` is the first check for install, service, configuration, and health
problems. `logs` tails the server logs. Logs from a laptop or client do not
describe a NeoAgent instance running on another server.

## Release channels and updates

```bash
neoagent channel
neoagent channel stable
neoagent channel beta
neoagent update
```

Stable is intended for normal installations. Beta receives prerelease builds.
`update` follows the selected channel, updates the package or Git checkout,
verifies the bundled client, and restarts the service.

## Recovery

```bash
neoagent fix
```

Use `fix` for a damaged installation or failed source update. It preserves
runtime data, repairs application source and dependencies, and restarts the
service. It is not a substitute for a backup.

For configuration problems:

```bash
neoagent setup
neoagent restart
```

## Backups

Stop the service or take an application-consistent filesystem snapshot, then
back up:

| Path | Contents |
|---|---|
| `~/.neoagent/.env` | Server configuration and secrets |
| `~/.neoagent/data/` | SQLite database, sessions, logs, update state |
| `~/.neoagent/agent-data/` | Skills, memory files, daily data |

If `NEOAGENT_HOME` is set, these paths live under that directory instead.
Protect backups as credentials and personal data.

## Common failures

| Symptom | Check |
|---|---|
| Service does not start | `neoagent status`, then `neoagent logs` |
| Chat has no response | Provider connection, selected model, provider quota |
| Browser or shell unavailable | Docker installed and running, then first runtime boot |
| OAuth fails | Reachable HTTPS `PUBLIC_URL` and exact callback URI |
| Messaging receives nothing | Channel credentials, webhook, and allowlists |
| Task does not run | Enabled state, trigger account, next run, **Runs** |
| Android action fails | ADB visibility, selected device, tool approval |
| Paired device unavailable | Companion or extension connection on that machine |

When reporting a bug, include the NeoAgent version, server OS, installation
type, runtime profile, exact reproduction steps, and sanitized server logs.
