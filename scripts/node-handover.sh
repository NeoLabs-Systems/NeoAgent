#!/bin/sh
# Hands a Node.js installation of NeoAgent over to the Go binary.
#
# NeoAgent's Node.js updater (`neoagent update`, or Update in the admin UI)
# checks out the new release and runs `npm install` in it. package.json in
# this tree exists only so that npm runs this script; .npmrc makes that
# install a dry run, so the old node_modules stay intact for the updater's
# rollback. The updater cannot run this release, so this script:
#   1. copies install.sh and itself out of the checkout (the rollback resets it),
#   2. starts the handover in the background, waiting for the updater to exit,
#   3. fails the npm install, so the updater rolls back at once and keeps the
#      Node.js version running meanwhile.
# The handover then runs install.sh, which installs the Go binary and runs
# `neoagent install`: it backs up the data, stops the Node.js server, points
# the launchd/systemd service at the binary and restores the old service if
# the new server does not answer. The data directory is reused as it is.
set -u

if [ "${1:-}" = "--after" ]; then
  updater="$2"; installer="$3"; channel="$4"
  while kill -0 "$updater" 2>/dev/null; do sleep 2; done
  sleep 3
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) handing over to the Go binary (channel ${channel})"
  NEOAGENT_RELEASE_CHANNEL="$channel" bash "$installer" </dev/null
  status=$?
  rm -f "$installer" "$0"
  exit "$status"
fi

# The updater is the Node.js CLI or the admin UI's update runner among this
# script's ancestors (npm and its shells sit in between).
updater=""
pid=$$
for _ in 1 2 3 4 5 6 7 8; do
  pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  [ -n "$pid" ] && [ "$pid" != "1" ] || break
  case "$(ps -o command= -p "$pid" 2>/dev/null)" in
    # Run as bin/neoagent.js, through the npm link (".../bin/neoagent update"),
    # or as the admin UI's update runner.
    *bin/neoagent.js*|*/neoagent\ update*|*update_runner.js*) updater="$pid"; break ;;
  esac
done
if [ -z "$updater" ]; then
  echo "NeoAgent no longer uses npm. Install or update it with install.sh: https://github.com/NeoLabs-Systems/NeoAgent" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
home="${NEOAGENT_HOME:-$HOME/.neoagent}"
logs="$home/data/logs"
mkdir -p "$logs"
channel="stable"
case "$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)" in beta) channel="beta" ;; esac
if grep -qs '^NEOAGENT_RELEASE_CHANNEL=beta' "$home/.env"; then channel="beta"; fi

work="$(mktemp -d "${TMPDIR:-/tmp}/neoagent-handover.XXXXXX")"
cp "$root/install.sh" "$work/install.sh"
cp "$0" "$work/node-handover.sh"
nohup sh "$work/node-handover.sh" --after "$updater" "$work/install.sh" "$channel" >>"$logs/handover.log" 2>&1 &

echo "NeoAgent now runs as a single program instead of Node.js. This update rolls back first and keeps NeoAgent running; the switch then finishes by itself in the background (progress: $logs/handover.log)." >&2
exit 1
