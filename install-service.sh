#!/usr/bin/env bash
# install-service.sh — Install NeoAgent as a macOS launchd user service
# Starts automatically on login, restarts on crash.

set -euo pipefail

PLIST_SRC="$(cd "$(dirname "$0")" && pwd)/com.neoagent.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.neoagent.plist"
LOG_DIR="$(cd "$(dirname "$0")" && pwd)/data/logs"

# ── 1. Create log directory ───────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
echo "✓ Log directory: $LOG_DIR"

# ── 2. Patch the plist with the actual username if different from 'neo' ───────
ACTUAL_USER="$(whoami)"
ACTUAL_HOME="$HOME"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE_BIN="$(which node 2>/dev/null || echo '/usr/local/bin/node')"

# Write a patched copy to LaunchAgents
sed \
  -e "s|/usr/local/bin/node|${NODE_BIN}|g" \
  -e "s|/Users/neo/NeoAgent|${APP_DIR}|g" \
  -e "s|/Users/neo|${ACTUAL_HOME}|g" \
  "$PLIST_SRC" > "$PLIST_DST"

echo "✓ Plist installed: $PLIST_DST"

# ── 3. Unload old instance if running ─────────────────────────────────────────
if launchctl list | grep -q "com.neoagent" 2>/dev/null; then
  launchctl unload "$PLIST_DST" 2>/dev/null || true
  echo "  (unloaded previous instance)"
fi

# ── 4. Load and start ─────────────────────────────────────────────────────────
launchctl load "$PLIST_DST"
echo "✓ Service loaded and started"

# ── 5. Quick status check ─────────────────────────────────────────────────────
sleep 2
if launchctl list | grep -q "com.neoagent"; then
  PID=$(launchctl list | grep "com.neoagent" | awk '{print $1}')
  echo ""
  echo "✅ NeoAgent is running (PID: ${PID})"
  echo "   URL:  http://localhost:3060"
  echo "   Logs: $LOG_DIR/neoagent.log"
  echo "         $LOG_DIR/neoagent.error.log"
  echo ""
  echo "   Commands:"
  echo "     Stop:    launchctl unload ~/Library/LaunchAgents/com.neoagent.plist"
  echo "     Start:   launchctl load   ~/Library/LaunchAgents/com.neoagent.plist"
  echo "     Logs:    tail -f ${LOG_DIR}/neoagent.log"
  echo "     Uninstall: ./uninstall-service.sh"
else
  echo ""
  echo "⚠️  Service loaded but process not yet visible — check logs:"
  echo "   tail -f $LOG_DIR/neoagent.error.log"
fi
