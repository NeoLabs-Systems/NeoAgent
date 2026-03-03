#!/usr/bin/env bash
# restart.sh — Pull latest from git and restart NeoAgent service

set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.neoagent.plist"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-3333}"

cd "$APP_DIR"

echo "── NeoAgent restart ──────────────────────────────────────"

# ── 1. Git pull ────────────────────────────────────────────────
echo "→ Pulling latest from git..."
git fetch origin
CURRENT=$(git rev-parse --short HEAD)
git pull --rebase origin "$(git rev-parse --abbrev-ref HEAD)"
NEW=$(git rev-parse --short HEAD)

if [ "$CURRENT" = "$NEW" ]; then
  echo "  Already up-to-date ($CURRENT)"
else
  echo "  Updated $CURRENT → $NEW"
  git log --oneline "$CURRENT".."$NEW" | sed 's/^/    /'
fi

# ── 2. Install/update dependencies if package.json changed ────
if ! git diff --quiet "$CURRENT" HEAD -- package.json package-lock.json 2>/dev/null; then
  echo "→ package.json changed — running npm install..."
  npm install --omit=dev --no-audit --no-fund
  echo "  ✓ Dependencies updated"
elif [ ! -d node_modules ]; then
  echo "→ node_modules missing — running npm install..."
  npm install --omit=dev --no-audit --no-fund
  echo "  ✓ Dependencies installed"
else
  echo "  Dependencies unchanged, skipping npm install"
fi

# ── 3. Restart service ────────────────────────────────────────
if [ -f "$PLIST" ]; then
  echo "→ Restarting launchd service..."
  launchctl unload "$PLIST" 2>/dev/null || true
  sleep 1
  launchctl load "$PLIST"
  sleep 2

  if launchctl list | grep -q "com.neoagent"; then
    PID=$(launchctl list | grep "com.neoagent" | awk '{print $1}')
    echo ""
    echo "✅ NeoAgent restarted (PID: ${PID})"
    echo "   http://localhost:${PORT}"
    echo "   Logs: tail -f ${APP_DIR}/data/logs/neoagent.log"
  else
    echo ""
    echo "⚠️  Service loaded but not yet running — check:"
    echo "   tail -f ${APP_DIR}/data/logs/neoagent.error.log"
  fi
else
  echo "→ Service not installed — starting directly..."
  # Fallback: kill any existing node process on this port and restart
  lsof -ti tcp:"$PORT" | xargs kill -9 2>/dev/null || true
  sleep 1
  nohup node server.js > data/logs/neoagent.log 2> data/logs/neoagent.error.log &
  echo "✅ NeoAgent started (PID: $!)"
  echo "   http://localhost:${PORT}"
  echo "   Run ./install-service.sh to make it persistent"
fi
