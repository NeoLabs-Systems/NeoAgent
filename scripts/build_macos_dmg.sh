#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <path-to-app-bundle> <output-dmg-path> [volume-name]"
  exit 1
fi

APP_BUNDLE="$1"
DMG_PATH="$2"
VOLUME_NAME="${3:-NeoAgent Installer}"
APP_NAME="$(basename "$APP_BUNDLE" .app)"
WORK_DIR="$(mktemp -d)"
STAGE_DIR="$WORK_DIR/stage"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$STAGE_DIR"
cp -R "$APP_BUNDLE" "$STAGE_DIR/"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg must be installed before running this script."
  exit 1
fi

rm -f "$DMG_PATH"
create-dmg \
  --volname "$VOLUME_NAME" \
  --window-pos 200 120 \
  --window-size 640 420 \
  --icon-size 128 \
  --icon "$APP_NAME.app" 170 210 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 470 210 \
  "$DMG_PATH" \
  "$STAGE_DIR"
