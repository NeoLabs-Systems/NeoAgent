#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-${ESPPORT:-/dev/cu.usbmodem101}}"

pkill -f "idf.py.*monitor|python.*usbmodem|miniterm|screen /dev/cu" >/dev/null 2>&1 || true
"$ROOT_DIR/dev/flash-waveshare-wearable.sh" "$PORT"
