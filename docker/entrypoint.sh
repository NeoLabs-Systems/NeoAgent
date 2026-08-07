#!/bin/sh
# Container entry point.
#
# The server bootstraps its own env file, secrets, data directories, and
# migrations on start, so the only thing left to arrange is the one-time claim
# that protects first-account creation: `neoagent claim` prints it when the
# instance has no owner yet and stays quiet once it does. A failure there must
# never stop the server, hence the guard.
set -e

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

neoagent claim || echo "[neoagent] Setup code unavailable; run 'neoagent claim' once the server is up."

exec node server/index.js
