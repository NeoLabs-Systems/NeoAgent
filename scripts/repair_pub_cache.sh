#!/usr/bin/env bash
set -euo pipefail

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
HOSTED_DIR="$PUB_CACHE/hosted/pub.dev"

if [[ ! -d "$HOSTED_DIR" ]]; then
  exit 0
fi

if ! find "$HOSTED_DIR" -maxdepth 2 -user root -print -quit | grep -q .; then
  exit 0
fi

echo "[neoagent] repairing Flutter pub cache ownership"
if ! sudo chown -R "$(id -un)" "$PUB_CACHE"; then
  echo "[neoagent] failed to repair $PUB_CACHE ownership" >&2
  exit 1
fi