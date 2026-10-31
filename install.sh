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

RUNTIME_DIR="${NEOAGENT_HOME:-$HOME/.neoagent}"
EXISTING_RUNTIME=false
# A .env alone is not an installation: an earlier, interrupted run of this
# installer creates it. setup-state.json means setup never finished, so it
# runs again instead of adopting the half-configured runtime.
if [[ ! -f "$RUNTIME_DIR/setup-state.json" ]] \
  && [[ -f "$RUNTIME_DIR/data/neoagent.db" \
    || ( -d "$RUNTIME_DIR/agent-data" && -n "$(ls -A "$RUNTIME_DIR/agent-data" 2>/dev/null)" ) ]]; then
  EXISTING_RUNTIME=true
  info "Existing runtime data found at ${RUNTIME_DIR}; it will be preserved."
fi

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

RELEASE_CHANNEL=""
while [[ "$RELEASE_CHANNEL" != "stable" && "$RELEASE_CHANNEL" != "beta" ]]; do
  ask RELEASE_CHANNEL "Release channel (stable/beta)" "stable"
  RELEASE_CHANNEL="$(echo "$RELEASE_CHANNEL" | tr '[:upper:]' '[:lower:]')"
done
if [[ "$RELEASE_CHANNEL" == "beta" ]]; then
  INSTALL_BRANCH="beta"
else
  INSTALL_BRANCH="main"
fi
ok "Channel: ${RELEASE_CHANNEL} (git branch ${INSTALL_BRANCH})"

NEOAGENT_ORIGIN_PATTERN='^(https://github\.com/|ssh://git@github\.com/|git@github\.com:)NeoLabs-Systems/NeoAgent(\.git)?/?$'
if [[ -d "$INSTALL_DIR/.git" ]]; then
  ORIGIN_URL="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ ! "$ORIGIN_URL" =~ $NEOAGENT_ORIGIN_PATTERN ]]; then
    err "${INSTALL_DIR} is a git repository but not a NeoAgent checkout (origin: ${ORIGIN_URL:-none})."
    echo "     Choose a different install directory; this one was left untouched." >&2
    exit 1
  fi
  info "Existing repo found at ${INSTALL_DIR} — replacing it with origin/${INSTALL_BRANCH}..."
  git -C "$INSTALL_DIR" fetch origin --tags
  git -C "$INSTALL_DIR" reset --hard HEAD
  git -C "$INSTALL_DIR" clean -fd
  git -C "$INSTALL_DIR" checkout -B "$INSTALL_BRANCH" "origin/$INSTALL_BRANCH"
  git -C "$INSTALL_DIR" reset --hard "origin/$INSTALL_BRANCH"
  ok "Source checkout replaced"
elif [[ -d "$INSTALL_DIR" && -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]]; then
  err "Directory ${INSTALL_DIR} exists and is not empty. Choose a different path or remove it."
  exit 1
else
  info "Cloning into ${INSTALL_DIR}..."
  git clone --branch "$INSTALL_BRANCH" https://github.com/NeoLabs-Systems/NeoAgent.git "$INSTALL_DIR"
  ok "Cloned (${INSTALL_BRANCH})"
fi

echo
info "Installing Node.js dependencies..."
cd "$INSTALL_DIR"
npm install --omit=dev --no-audit --no-fund
ok "Dependencies ready"

echo
info "Installing the neoagent CLI globally..."
# Distribution Node.js (Arch, Fedora, Debian packages) puts npm's global prefix
# in /usr, which a normal user cannot write. Use ~/.local then, the usual
# per-user place, instead of asking for sudo.
NPM_PREFIX="$(npm prefix --global)"
if [[ ! -w "$NPM_PREFIX" ]] || [[ -d "$NPM_PREFIX/lib/node_modules" && ! -w "$NPM_PREFIX/lib/node_modules" ]]; then
  info "npm's global folder (${NPM_PREFIX}) is not writable; using ~/.local instead"
  mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
  npm config set prefix "$HOME/.local" --location=user
fi
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

# Not on PATH yet: add it for new terminals and for the rest of this run.
case ":${PATH}:" in
  *":${GLOBAL_BIN_DIR}:"*) ;;
  *)
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      if [[ -f "$rc" || "$rc" == "$HOME/.bashrc" ]] && ! grep -qs "${GLOBAL_BIN_DIR}" "$rc"; then
        printf '\n# Added by the neoagent installer\nexport PATH="%s:$PATH"\n' "$GLOBAL_BIN_DIR" >> "$rc"
      fi
    done
    if [[ -d "$HOME/.config/fish" ]]; then
      mkdir -p "$HOME/.config/fish/conf.d"
      printf 'fish_add_path %s\n' "$GLOBAL_BIN_DIR" > "$HOME/.config/fish/conf.d/neoagent.fish"
    fi
    export PATH="${GLOBAL_BIN_DIR}:$PATH"
    info "Added ${GLOBAL_BIN_DIR} to PATH (open a new terminal to use neoagent there)"
    ;;
esac
hash -r
ok "Global CLI ready: ${GLOBAL_CLI}"

echo
info "Running the global NeoAgent manager..."
if [[ "$EXISTING_RUNTIME" == "true" ]]; then
  "$GLOBAL_CLI" channel "$RELEASE_CHANNEL"
  exec "$GLOBAL_CLI" install --adopt-existing
fi
exec "$GLOBAL_CLI" install --channel "$RELEASE_CHANNEL"
