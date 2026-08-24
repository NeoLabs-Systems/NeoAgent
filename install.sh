#!/usr/bin/env bash
# NeoAgent repository installer
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/install.sh)

set -euo pipefail

if [[ -t 1 ]]; then
  BOLD='\033[1m'; RESET='\033[0m'; RED='\033[1;31m'; GRN='\033[1;32m'
  CYN='\033[1;36m'; YEL='\033[1;33m'; DIM='\033[2m'
else
  BOLD=''; RESET=''; RED=''; GRN=''; CYN=''; YEL=''; DIM=''
fi

ok()   { echo -e "  ${GRN}✓${RESET}  $*"; }
info() { echo -e "  ${CYN}→${RESET}  $*"; }
err()  { echo -e "  ${RED}✗${RESET}  $*" >&2; }
ask()  {
  local var="$1" prompt="$2" default="${3:-}"
  [[ -n "$default" ]] \
    && echo -ne "  ${CYN}?${RESET}  ${prompt} ${DIM}[${default}]${RESET} " \
    || echo -ne "  ${CYN}?${RESET}  ${prompt} "
  read -r input </dev/tty
  [[ -z "$input" && -n "$default" ]] && input="$default"
  eval "$var=\"\$input\""
}

echo -e "${CYN}${BOLD}NeoAgent installer${RESET}"
echo

MISSING=()
command -v git  &>/dev/null && ok "git $(git --version | awk '{print $3}')"   || MISSING+=("git")
command -v node &>/dev/null && ok "Node.js $(node --version)"                  || MISSING+=("node (https://nodejs.org)")
command -v npm  &>/dev/null && ok "npm $(npm --version)"                       || MISSING+=("npm")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo
  err "Missing requirements:"
  for m in "${MISSING[@]}"; do echo "     • $m"; done
  echo
  exit 1
fi

DEFAULT_DIR="$HOME/NeoAgent"
ask INSTALL_DIR "Install directory" "$DEFAULT_DIR"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  info "Existing repo found at ${INSTALL_DIR} — pulling latest..."
  git -C "$INSTALL_DIR" pull --rebase origin "$(git -C "$INSTALL_DIR" rev-parse --abbrev-ref HEAD)"
  ok "Updated"
elif [[ -d "$INSTALL_DIR" && -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]]; then
  err "Directory ${INSTALL_DIR} exists and is not empty. Choose a different path or remove it."
  exit 1
else
  info "Cloning into ${INSTALL_DIR}..."
  git clone https://github.com/NeoLabs-Systems/NeoAgent.git "$INSTALL_DIR"
  ok "Cloned"
fi

echo
info "Installing Node.js dependencies..."
cd "$INSTALL_DIR"
npm install --omit=dev --no-audit --no-fund
ok "Dependencies ready"

echo
info "Installing the neoagent CLI globally..."
if ! npm link --ignore-scripts --no-audit --no-fund; then
  err "Could not install the global neoagent command. Check permissions for your npm global prefix: $(npm prefix --global)"
  exit 1
fi

GLOBAL_BIN_DIR="$(npm prefix --global)/bin"
GLOBAL_CLI="${GLOBAL_BIN_DIR}/neoagent"
if [[ ! -x "$GLOBAL_CLI" ]]; then
  err "Global CLI installation did not create ${GLOBAL_CLI}."
  exit 1
fi

case ":${PATH}:" in
  *":${GLOBAL_BIN_DIR}:"*) ;;
  *)
    err "The global CLI was installed at ${GLOBAL_CLI}, but ${GLOBAL_BIN_DIR} is not on PATH."
    echo "     Add this directory to PATH, then rerun the installer: ${GLOBAL_BIN_DIR}" >&2
    exit 1
    ;;
esac
hash -r
ok "Global CLI ready: ${GLOBAL_CLI}"

echo
info "Running the global NeoAgent manager..."
exec "$GLOBAL_CLI" install
