#!/usr/bin/env bash
# NeoAgent installer: downloads the neoagent binary for this computer from the
# latest GitHub release and runs `neoagent install`. Existing data, including a
# Node.js installation's, is backed up and kept. The steps live in the shared
# NeoLabs installer; this only names the app.
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/install.sh)

set -euo pipefail

export APP_NAME=NeoAgent
export APP_CMD=neoagent
export APP_REPO=NeoLabs-Systems/NeoAgent
export APP_ENV=NEOAGENT
export APP_DATA=data/neoagent.db
export APP_TARGETS="macos-x64 macos-arm64 linux-x64"

SHARED="https://raw.githubusercontent.com/NeoLabs-Systems/neolabs-go/851626c3fb469a8bca9cee8aaa0e05aa30777df9/scripts/install-cli.sh"
if ! INSTALLER="$(curl -fsSL "$SHARED")" || [[ -z "$INSTALLER" ]]; then
  echo "Could not download the installer. Check the network and try again." >&2
  exit 1
fi
exec bash -c "$INSTALLER" neoagent-install
