#!/usr/bin/env bash
# uninstall-service.sh — Remove NeoAgent from macOS launchd

set -euo pipefail

PLIST_DST="$HOME/Library/LaunchAgents/com.neoagent.plist"

if [ ! -f "$PLIST_DST" ]; then
  echo "Service is not installed (plist not found at $PLIST_DST)"
  exit 0
fi

# Stop and unload
if launchctl list | grep -q "com.neoagent" 2>/dev/null; then
  launchctl unload "$PLIST_DST"
  echo "✓ Service stopped"
fi

# Remove plist
rm -f "$PLIST_DST"
echo "✓ Plist removed"

echo ""
echo "✅ NeoAgent service uninstalled."
echo "   Logs and data are untouched in ./data/logs/"
