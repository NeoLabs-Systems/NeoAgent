#!/usr/bin/env bash
# neo.sh — NeoAgent management script
# Usage: ./neo.sh [install|uninstall|start|stop|restart|update|status|logs|setup]

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
#  Globals
# ─────────────────────────────────────────────────────────────────────────────
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="NeoAgent"
SERVICE_LABEL="com.neoagent"
PLIST_SRC="$APP_DIR/com.neoagent.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.neoagent.plist"
SYSTEMD_UNIT="$HOME/.config/systemd/user/neoagent.service"
LOG_DIR="$APP_DIR/data/logs"
ENV_FILE="$APP_DIR/.env"
PORT="${PORT:-3060}"

# ─────────────────────────────────────────────────────────────────────────────
#  Colours & UI helpers
# ─────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD='\033[1m'    ; DIM='\033[2m'    ; RESET='\033[0m'
  RED='\033[1;31m'  ; YEL='\033[1;33m' ; GRN='\033[1;32m'
  CYN='\033[1;36m'  ; BLU='\033[1;34m' ; MAG='\033[1;35m'
else
  BOLD='' ; DIM='' ; RESET='' ; RED='' ; YEL='' ; GRN='' ; CYN='' ; BLU='' ; MAG=''
fi

banner() {
  echo -e "${CYN}${BOLD}"
  echo '  ███╗   ██╗███████╗ ██████╗      █████╗  ██████╗ ███████╗███╗   ██╗████████╗'
  echo '  ████╗  ██║██╔════╝██╔═══██╗    ██╔══██╗██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝'
  echo '  ██╔██╗ ██║█████╗  ██║   ██║    ███████║██║  ███╗█████╗  ██╔██╗ ██║   ██║   '
  echo '  ██║╚██╗██║██╔══╝  ██║   ██║    ██╔══██║██║   ██║██╔══╝  ██║╚██╗██║   ██║   '
  echo '  ██║ ╚████║███████╗╚██████╔╝    ██║  ██║╚██████╔╝███████╗██║ ╚████║   ██║   '
  echo '  ╚═╝  ╚═══╝╚══════╝ ╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   '
  echo -e "${RESET}"
  echo -e "  ${DIM}Proactive personal AI agent — ${APP_DIR}${RESET}"
  echo
}

line()    { echo -e "${DIM}────────────────────────────────────────────────────────────${RESET}"; }
ok()      { echo -e "  ${GRN}✓${RESET}  $*"; }
info()    { echo -e "  ${BLU}→${RESET}  $*"; }
warn()    { echo -e "  ${YEL}⚠${RESET}  $*"; }
err()     { echo -e "  ${RED}✗${RESET}  $*" >&2; }
heading() { echo; echo -e "  ${BOLD}${MAG}$*${RESET}"; line; }

ask() {
  # ask VAR "Prompt" "default"
  local var="$1" prompt="$2" default="${3:-}"
  if [[ -n "$default" ]]; then
    echo -ne "  ${CYN}?${RESET}  ${prompt} ${DIM}[${default}]${RESET} "
  else
    echo -ne "  ${CYN}?${RESET}  ${prompt} "
  fi
  read -r input
  if [[ -z "$input" && -n "$default" ]]; then
    eval "$var=\"\$default\""
  else
    eval "$var=\"\$input\""
  fi
}

ask_secret() {
  local var="$1" prompt="$2"
  echo -ne "  ${CYN}?${RESET}  ${prompt} ${DIM}(hidden)${RESET} "
  read -rs input
  echo
  eval "$var=\"\$input\""
}

confirm() {
  # confirm "question" → returns 0 for yes, 1 for no
  echo -ne "  ${CYN}?${RESET}  $* ${DIM}[Y/n]${RESET} "
  read -r yn
  [[ "$yn" =~ ^[Nn] ]] && return 1 || return 0
}

# ─────────────────────────────────────────────────────────────────────────────
#  Platform detection
# ─────────────────────────────────────────────────────────────────────────────
detect_platform() {
  case "$(uname -s)" in
    Darwin) PLATFORM="macos" ;;
    Linux)  PLATFORM="linux" ;;
    *)      PLATFORM="other" ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
#  Prereq checks
# ─────────────────────────────────────────────────────────────────────────────
check_node() {
  if command -v node &>/dev/null; then
    NODE_BIN="$(command -v node)"
    NODE_VER="$(node --version)"
    ok "Node.js ${NODE_VER} → ${NODE_BIN}"
    return 0
  else
    err "Node.js not found. Install from https://nodejs.org or via nvm/brew."
    return 1
  fi
}

check_git() {
  if command -v git &>/dev/null; then
    ok "git $(git --version | awk '{print $3}')"
    return 0
  else
    warn "git not found — update command will be unavailable."
    return 1
  fi
}

check_npm_deps() {
  if [[ ! -d "$APP_DIR/node_modules" ]]; then
    info "node_modules not found — running npm install..."
    npm install --omit=dev --no-audit --no-fund --prefix "$APP_DIR"
    ok "Dependencies installed"
  else
    ok "Dependencies present"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  .env setup wizard
# ─────────────────────────────────────────────────────────────────────────────
cmd_setup() {
  heading "Environment Setup"

  # Load existing values so they show as defaults
  declare -A current_env=()
  if [[ -f "$ENV_FILE" ]]; then
    while IFS='=' read -r key val; do
      [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
      current_env["$key"]="${val//\"/}"
    done < "$ENV_FILE"
    info "Found existing .env — current values shown as defaults."
  fi

  echo

  # --- Core ---
  echo -e "  ${BOLD}Core${RESET}"
  ask PORT   "Server port"              "${current_env[PORT]:-3060}"
  ask SECRET "Session secret (random)" "${current_env[SESSION_SECRET]:-$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom 2>/dev/null | head -c 48 || openssl rand -hex 24)}"

  # --- AI providers ---
  echo
  echo -e "  ${BOLD}AI Providers${RESET} ${DIM}(press Enter to skip)${RESET}"
  ask ANTHROPIC_KEY "Anthropic API key"  "${current_env[ANTHROPIC_API_KEY]:-}"
  ask OPENAI_KEY    "OpenAI API key"     "${current_env[OPENAI_API_KEY]:-}"
  ask XAI_KEY       "xAI (Grok) key"    "${current_env[XAI_API_KEY]:-}"
  ask GOOGLE_KEY    "Google AI key"      "${current_env[GOOGLE_AI_KEY]:-}"
  ask OLLAMA_URL    "Ollama base URL"    "${current_env[OLLAMA_URL]:-http://localhost:11434}"

  # --- Optional ---
  echo
  echo -e "  ${BOLD}Optional${RESET}"
  ask TELNYX_TOKEN    "Telnyx webhook token"   "${current_env[TELNYX_WEBHOOK_TOKEN]:-}"
  ask ALLOWED_ORIGINS "Allowed CORS origins"  "${current_env[ALLOWED_ORIGINS]:-}"

  # Write .env
  mkdir -p "$(dirname "$ENV_FILE")"
  {
    echo "# NeoAgent environment — generated $(date)"
    echo "NODE_ENV=production"
    echo "PORT=${PORT}"
    echo "SESSION_SECRET=${SECRET}"
    [[ -n "${ANTHROPIC_KEY:-}" ]] && echo "ANTHROPIC_API_KEY=${ANTHROPIC_KEY}"
    [[ -n "${OPENAI_KEY:-}"    ]] && echo "OPENAI_API_KEY=${OPENAI_KEY}"
    [[ -n "${XAI_KEY:-}"       ]] && echo "XAI_API_KEY=${XAI_KEY}"
    [[ -n "${GOOGLE_KEY:-}"    ]] && echo "GOOGLE_AI_KEY=${GOOGLE_KEY}"
    [[ -n "${OLLAMA_URL:-}"    ]] && echo "OLLAMA_URL=${OLLAMA_URL}"
    [[ -n "${TELNYX_TOKEN:-}"  ]] && echo "TELNYX_WEBHOOK_TOKEN=${TELNYX_TOKEN}"
    [[ -n "${ALLOWED_ORIGINS:-}" ]] && echo "ALLOWED_ORIGINS=${ALLOWED_ORIGINS}"
  } > "$ENV_FILE"
  chmod 600 "$ENV_FILE"

  echo
  ok ".env written to ${ENV_FILE}"
}

# ─────────────────────────────────────────────────────────────────────────────
#  Install
# ─────────────────────────────────────────────────────────────────────────────
_install_macos() {
  mkdir -p "$(dirname "$PLIST_DST")"
  mkdir -p "$LOG_DIR"

  local node_bin
  node_bin="$(command -v node)"

  # Patch plist
  sed \
    -e "s|/usr/local/bin/node|${node_bin}|g" \
    -e "s|/Users/neo/NeoAgent|${APP_DIR}|g" \
    -e "s|/Users/neo|${HOME}|g" \
    "$PLIST_SRC" > "$PLIST_DST"
  ok "Plist installed → ${PLIST_DST}"

  # Unload stale instance
  if launchctl list 2>/dev/null | grep -q "$SERVICE_LABEL"; then
    launchctl unload "$PLIST_DST" 2>/dev/null || true
    info "Unloaded previous instance"
  fi

  launchctl load "$PLIST_DST"
  sleep 2

  if launchctl list 2>/dev/null | grep -q "$SERVICE_LABEL"; then
    local pid
    pid="$(launchctl list | grep "$SERVICE_LABEL" | awk '{print $1}')"
    ok "Service running (PID: ${pid})"
  else
    warn "Service loaded but not yet visible — check logs"
  fi
}

_install_linux() {
  mkdir -p "$(dirname "$SYSTEMD_UNIT")"
  mkdir -p "$LOG_DIR"

  local node_bin
  node_bin="$(command -v node)"

  cat > "$SYSTEMD_UNIT" <<UNIT
[Unit]
Description=NeoAgent — Proactive personal AI agent
After=network.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
ExecStart=${node_bin} server/index.js
Restart=always
RestartSec=10
EnvironmentFile=-${ENV_FILE}
Environment=NODE_ENV=production
StandardOutput=append:${LOG_DIR}/neoagent.log
StandardError=append:${LOG_DIR}/neoagent.error.log

[Install]
WantedBy=default.target
UNIT

  systemctl --user daemon-reload
  systemctl --user enable neoagent
  systemctl --user start neoagent
  ok "systemd user service installed and started"
}

_install_fallback() {
  mkdir -p "$LOG_DIR"
  # Kill existing
  if [[ -f "$APP_DIR/data/neoagent.pid" ]]; then
    kill "$(cat "$APP_DIR/data/neoagent.pid")" 2>/dev/null || true
  fi
  lsof -ti tcp:"$PORT" 2>/dev/null | xargs kill -9 2>/dev/null || true
  sleep 1
  nohup node "$APP_DIR/server/index.js" \
    > "$LOG_DIR/neoagent.log" \
    2> "$LOG_DIR/neoagent.error.log" &
  echo $! > "$APP_DIR/data/neoagent.pid"
  ok "Started as background process (PID: $!)"
}

cmd_install() {
  heading "Installing ${APP_NAME}"
  detect_platform
  check_node || { err "Cannot install without Node.js."; exit 1; }
  check_git || true

  # Setup .env if missing
  if [[ ! -f "$ENV_FILE" ]]; then
    warn ".env not found — launching setup wizard..."
    echo
    cmd_setup
    echo
  fi

  check_npm_deps

  case "$PLATFORM" in
    macos) _install_macos ;;
    linux) _install_linux ;;
    *)     _install_fallback ;;
  esac

  echo
  echo -e "  ${GRN}${BOLD}✅ ${APP_NAME} installed and running!${RESET}"
  echo
  echo -e "  ${BLU}URL:${RESET}  http://localhost:${PORT:-3060}"
  echo -e "  ${BLU}Logs:${RESET} tail -f ${LOG_DIR}/neoagent.log"
  echo
  echo -e "  ${DIM}Tip: run  ./neo.sh <command>  to manage the service${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
#  Uninstall
# ─────────────────────────────────────────────────────────────────────────────
cmd_uninstall() {
  heading "Uninstalling ${APP_NAME}"
  detect_platform

  case "$PLATFORM" in
    macos)
      if [[ ! -f "$PLIST_DST" ]]; then
        warn "Service not installed (plist not found)."
        return 0
      fi
      if launchctl list 2>/dev/null | grep -q "$SERVICE_LABEL"; then
        launchctl unload "$PLIST_DST"
        ok "Service stopped"
      fi
      rm -f "$PLIST_DST"
      ok "Plist removed"
      ;;
    linux)
      if systemctl --user is-active --quiet neoagent 2>/dev/null; then
        systemctl --user stop neoagent
        ok "Service stopped"
      fi
      systemctl --user disable neoagent 2>/dev/null || true
      rm -f "$SYSTEMD_UNIT"
      systemctl --user daemon-reload
      ok "systemd unit removed"
      ;;
    *)
      if [[ -f "$APP_DIR/data/neoagent.pid" ]]; then
        kill "$(cat "$APP_DIR/data/neoagent.pid")" 2>/dev/null || true
        rm -f "$APP_DIR/data/neoagent.pid"
        ok "Process stopped"
      fi
      ;;
  esac

  echo
  ok "Logs and data are untouched in ./data/logs/"
  echo -e "  ${GRN}${BOLD}✅ ${APP_NAME} uninstalled.${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
#  Start / Stop / Restart
# ─────────────────────────────────────────────────────────────────────────────
cmd_start() {
  heading "Starting ${APP_NAME}"
  detect_platform

  case "$PLATFORM" in
    macos)
      if [[ ! -f "$PLIST_DST" ]]; then
        warn "Service not installed — run  ./neo.sh install  first."
        return 1
      fi
      launchctl load "$PLIST_DST" 2>/dev/null || true
      sleep 2
      _check_running_macos
      ;;
    linux)
      systemctl --user start neoagent
      sleep 1
      _check_running_linux
      ;;
    *)
      _install_fallback
      ;;
  esac
}

cmd_stop() {
  heading "Stopping ${APP_NAME}"
  detect_platform

  case "$PLATFORM" in
    macos)
      if [[ -f "$PLIST_DST" ]]; then
        launchctl unload "$PLIST_DST" 2>/dev/null || true
        ok "Service stopped"
      else
        lsof -ti tcp:"$PORT" 2>/dev/null | xargs kill -9 2>/dev/null && ok "Process killed" || warn "Nothing to stop"
      fi
      ;;
    linux)
      systemctl --user stop neoagent && ok "Service stopped" || warn "Service was not running"
      ;;
    *)
      if [[ -f "$APP_DIR/data/neoagent.pid" ]]; then
        kill "$(cat "$APP_DIR/data/neoagent.pid")" 2>/dev/null && ok "Process stopped" || warn "Process not found"
        rm -f "$APP_DIR/data/neoagent.pid"
      else
        lsof -ti tcp:"$PORT" 2>/dev/null | xargs kill -9 2>/dev/null && ok "Process killed" || warn "Nothing to stop"
      fi
      ;;
  esac
}

cmd_restart() {
  heading "Restarting ${APP_NAME}"
  detect_platform

  case "$PLATFORM" in
    macos)
      if [[ -f "$PLIST_DST" ]]; then
        launchctl unload "$PLIST_DST" 2>/dev/null || true
        sleep 1
        launchctl load "$PLIST_DST"
        sleep 2
        _check_running_macos
      else
        warn "Service not installed — starting directly..."
        _install_fallback
      fi
      ;;
    linux)
      systemctl --user restart neoagent
      sleep 1
      _check_running_linux
      ;;
    *)
      cmd_stop 2>/dev/null || true
      sleep 1
      _install_fallback
      ;;
  esac
}

_check_running_macos() {
  if launchctl list 2>/dev/null | grep -q "$SERVICE_LABEL"; then
    local pid
    pid="$(launchctl list | grep "$SERVICE_LABEL" | awk '{print $1}')"
    ok "Running (PID: ${pid})  →  http://localhost:${PORT:-3060}"
  else
    warn "Not running — check:  tail -f ${LOG_DIR}/neoagent.error.log"
  fi
}

_check_running_linux() {
  if systemctl --user is-active --quiet neoagent 2>/dev/null; then
    ok "Running (systemd)  →  http://localhost:${PORT:-3060}"
  else
    warn "Not running — check:  journalctl --user -u neoagent -n 50"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  Update (git pull + npm install + restart)
# ─────────────────────────────────────────────────────────────────────────────
cmd_update() {
  heading "Updating ${APP_NAME}"
  cd "$APP_DIR"

  # Git pull
  if command -v git &>/dev/null && [[ -d "$APP_DIR/.git" ]]; then
    info "Fetching latest..."
    git fetch origin 2>/dev/null

    local current new branch
    current="$(git rev-parse --short HEAD)"
    branch="$(git rev-parse --abbrev-ref HEAD)"
    git pull --rebase origin "$branch"
    new="$(git rev-parse --short HEAD)"

    if [[ "$current" == "$new" ]]; then
      ok "Already up-to-date (${current})"
    else
      ok "Updated ${current} → ${new}"
      git log --oneline "${current}..${new}" | sed 's/^/     /'
    fi
    echo

    # npm install if deps changed
    if ! git diff --quiet "$current" HEAD -- package.json package-lock.json 2>/dev/null; then
      info "package.json changed — updating dependencies..."
      npm install --omit=dev --no-audit --no-fund
      ok "Dependencies updated"
    elif [[ ! -d node_modules ]]; then
      info "node_modules missing — installing..."
      npm install --omit=dev --no-audit --no-fund
      ok "Dependencies installed"
    else
      ok "Dependencies unchanged"
    fi
  else
    # No git — just reinstall deps
    info "No git repo detected — refreshing dependencies..."
    npm install --omit=dev --no-audit --no-fund
    ok "Dependencies refreshed"
  fi

  echo
  cmd_restart
}

# ─────────────────────────────────────────────────────────────────────────────
#  Status
# ─────────────────────────────────────────────────────────────────────────────
cmd_status() {
  heading "${APP_NAME} Status"
  detect_platform

  # Version / git info
  if command -v git &>/dev/null && [[ -d "$APP_DIR/.git" ]]; then
    local sha branch
    sha="$(git -C "$APP_DIR" rev-parse --short HEAD 2>/dev/null)"
    branch="$(git -C "$APP_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    info "Version: ${sha} (${branch})"
  fi

  # Node
  if command -v node &>/dev/null; then
    info "Node:    $(node --version)"
  fi

  echo

  case "$PLATFORM" in
    macos)
      if launchctl list 2>/dev/null | grep -q "$SERVICE_LABEL"; then
        local pid
        pid="$(launchctl list | grep "$SERVICE_LABEL" | awk '{print $1}')"
        echo -e "  Service   ${GRN}${BOLD}● running${RESET}  (PID: ${pid})"
      else
        echo -e "  Service   ${RED}○ stopped${RESET}"
      fi
      ;;
    linux)
      if systemctl --user is-active --quiet neoagent 2>/dev/null; then
        echo -e "  Service   ${GRN}${BOLD}● running${RESET}  (systemd)"
        systemctl --user status neoagent --no-pager -n 0 2>/dev/null | grep -E 'Active:|Main PID:' | sed 's/^/     /'
      else
        echo -e "  Service   ${RED}○ stopped${RESET}"
      fi
      ;;
    *)
      # Check by port
      if lsof -ti tcp:"$PORT" &>/dev/null 2>&1; then
        local pid
        pid="$(lsof -ti tcp:"$PORT" | head -1)"
        echo -e "  Process   ${GRN}${BOLD}● running${RESET}  (PID: ${pid}, port ${PORT})"
      else
        echo -e "  Process   ${RED}○ not detected on port ${PORT}${RESET}"
      fi
      ;;
  esac

  echo
  echo -e "  ${BLU}URL:${RESET}  http://localhost:${PORT:-3060}"
  echo -e "  ${BLU}Logs:${RESET} ${LOG_DIR}/"
  echo
}

# ─────────────────────────────────────────────────────────────────────────────
#  Logs
# ─────────────────────────────────────────────────────────────────────────────
cmd_logs() {
  heading "Logs"
  local log="$LOG_DIR/neoagent.log"
  local err_log="$LOG_DIR/neoagent.error.log"

  if [[ ! -f "$log" && ! -f "$err_log" ]]; then
    warn "No log files found yet at ${LOG_DIR}/"
    return 0
  fi

  # Which log?
  echo -e "  1)  Combined (stdout)   ${DIM}neoagent.log${RESET}"
  echo -e "  2)  Errors only         ${DIM}neoagent.error.log${RESET}"
  echo -e "  3)  Both interleaved"
  echo
  ask LOG_CHOICE "Choose [1-3]" "1"

  echo
  line
  case "${LOG_CHOICE:-1}" in
    2) tail -f "$err_log" ;;
    3) tail -f "$log" "$err_log" ;;
    *) tail -f "$log" ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
#  Interactive menu
# ─────────────────────────────────────────────────────────────────────────────
show_menu() {
  banner
  detect_platform

  echo -e "  Platform: ${BOLD}${PLATFORM}${RESET}   Directory: ${DIM}${APP_DIR}${RESET}"
  echo

  local items=(
    "install   → Interactive setup + register as system service"
    "setup     → Configure .env (API keys, port, secrets)"
    "update    → Git pull + update deps + restart"
    "restart   → Restart service"
    "start     → Start service"
    "stop      → Stop service"
    "status    → Show service status"
    "logs      → Tail log files"
    "uninstall → Remove system service"
    "quit      → Exit"
  )

  for i in "${!items[@]}"; do
    local n=$(( i + 1 ))
    local cmd="${items[$i]%%→*}"
    local desc="${items[$i]#*→}"
    printf "  ${CYN}%2d)${RESET}  ${BOLD}%-12s${RESET}${DIM}→%s${RESET}\n" "$n" "$cmd" "$desc"
  done

  echo
  ask MENU_CHOICE "Choose [1-10]" ""
  echo

  case "${MENU_CHOICE:-}" in
    1|install)   cmd_install   ;;
    2|setup)     cmd_setup     ;;
    3|update)    cmd_update    ;;
    4|restart)   cmd_restart   ;;
    5|start)     cmd_start     ;;
    6|stop)      cmd_stop      ;;
    7|status)    cmd_status    ;;
    8|logs)      cmd_logs      ;;
    9|uninstall) cmd_uninstall ;;
    10|quit|q|"") echo -e "  ${DIM}Bye!${RESET}"; exit 0 ;;
    *) err "Unknown choice: ${MENU_CHOICE}"; exit 1 ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
#  Entrypoint
# ─────────────────────────────────────────────────────────────────────────────
COMMAND="${1:-}"

case "$COMMAND" in
  "")          show_menu    ;;
  install)     banner; cmd_install   ;;
  uninstall)   banner; cmd_uninstall ;;
  start)       banner; cmd_start     ;;
  stop)        banner; cmd_stop      ;;
  restart)     banner; cmd_restart   ;;
  update)      banner; cmd_update    ;;
  status)      banner; cmd_status    ;;
  logs)        banner; cmd_logs      ;;
  setup)       banner; cmd_setup     ;;
  help|--help|-h)
    banner
    echo -e "  ${BOLD}Usage:${RESET}  ./neo.sh [command]"
    echo
    echo -e "  ${BOLD}Commands:${RESET}"
    echo -e "    ${CYN}install${RESET}    Interactive setup + register as system service"
    echo -e "    ${CYN}setup${RESET}      Configure .env (API keys, port, secrets)"
    echo -e "    ${CYN}update${RESET}     Git pull + update dependencies + restart"
    echo -e "    ${CYN}restart${RESET}    Restart service"
    echo -e "    ${CYN}start${RESET}      Start service"
    echo -e "    ${CYN}stop${RESET}       Stop service"
    echo -e "    ${CYN}status${RESET}     Show service status"
    echo -e "    ${CYN}logs${RESET}       Tail log files"
    echo -e "    ${CYN}uninstall${RESET}  Remove system service"
    echo
    echo -e "  ${DIM}Run without arguments for the interactive menu.${RESET}"
    echo
    ;;
  *)
    err "Unknown command: ${COMMAND}"
    echo -e "  Run ${CYN}./neo.sh help${RESET} for usage."
    exit 1
    ;;
esac
