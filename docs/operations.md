# Operations

NeoAgent is a self-hosted service, so operations are part of the product. The CLI exposes the common service, release, and recovery tasks.

## Service State

```bash
neoagent status
neoagent logs
neoagent restart
```

`neoagent status` reports the install root, config path, runtime data paths, release channel, and service state. `neoagent logs` is the first place to look when the service starts but the UI, messaging, OAuth, or tasks behave unexpectedly.

## Release Channels

```bash
neoagent channel
neoagent channel stable
neoagent channel beta
```

The release channel controls what `neoagent update` follows. Use `stable` for normal self-hosted installs and `beta` when you intentionally want prerelease builds.

## Updates

```bash
neoagent update
```

On git installs, the updater follows the channel branch policy and reinstalls dependencies if the source changes. On npm installs, it attempts a global package reinstall from the matching npm tag.

After updating, NeoAgent verifies that the bundled web client exists and restarts the service.

## Recovery

```bash
neoagent fix
```

Use `neoagent fix` if a self-edit or broken local install leaves NeoAgent in a bad state. On git installs it backs up runtime data, saves local tracked changes, resets tracked source files, reinstalls dependencies, and restarts the service.

If the failure is configuration-only, rerun:

```bash
neoagent setup
neoagent restart
```

## Runtime Data

| Path | Purpose |
|---|---|
| `~/.neoagent/.env` | Server config and secrets |
| `~/.neoagent/data/` | Database, session data, logs, and update status |
| `~/.neoagent/agent-data/` | Skills, memory, and daily data |

Back up these paths before moving a server or doing manual repair work.
