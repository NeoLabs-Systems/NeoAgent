#!/usr/bin/env bash
# NeoAgent install smoke test
#
# Tests that the installation process works end-to-end via two paths:
#   A) npm pack → npm install -g → neoagent install
#   B) install.sh (the curl-pipe-to-bash script) → neoagent install
#
# Both paths use isolated temp directories so the existing ~/.neoagent
# and any running service are never touched.
#
# Usage:
#   bash test/install/install_smoke_test.sh [--path A|B|both] [--no-cleanup]
#
# Requires: node 20+, npm, git, curl

set -euo pipefail

# ── colours ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD='\033[1m'; RESET='\033[0m'; RED='\033[1;31m'; GRN='\033[1;32m'
  YEL='\033[1;33m'; CYN='\033[1;36m'; DIM='\033[2m'
else
  BOLD=''; RESET=''; RED=''; GRN=''; YEL=''; CYN=''; DIM=''
fi

pass()  { echo -e "  ${GRN}✓${RESET}  $*"; }
fail()  { echo -e "  ${RED}✗${RESET}  $*" >&2; }
info()  { echo -e "  ${CYN}→${RESET}  $*"; }
warn()  { echo -e "  ${YEL}▲${RESET}  $*"; }
title() { echo -e "\n${BOLD}${CYN}$*${RESET}"; }

# ── defaults ───────────────────────────────────────────────────────────────────
INSTALL_PATH="both"     # which path to test: A, B, or both
NO_CLEANUP=false
TEST_PORT=13337         # avoids colliding with a running instance on 3333
STARTUP_TIMEOUT=30      # seconds to wait for the server to become ready
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS=()              # accumulates "PASS <label>" or "FAIL <label>"

# ── argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)     INSTALL_PATH="$2"; shift 2 ;;
    --no-cleanup) NO_CLEANUP=true; shift ;;
    --timeout)  STARTUP_TIMEOUT="$2"; shift 2 ;;
    --port)     TEST_PORT="$2"; shift 2 ;;
    --static-only) INSTALL_PATH="static"; shift ;;
    --help|-h)
      echo "Usage: $0 [--path A|B|both] [--static-only] [--no-cleanup] [--timeout N] [--port N]"
      echo
      echo "  --path A|B|both   Which install path to test (default: both)"
      echo "  --static-only     Only run static checks (no live install, no temp dirs)"
      echo "  --no-cleanup      Keep temp directories after the test"
      echo "  --timeout N       Seconds to wait for server startup (default: 30)"
      echo "  --port N          Port for the test server (default: 13337)"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── cleanup registry ───────────────────────────────────────────────────────────
CLEANUP_PIDS=()
CLEANUP_DIRS=()

cleanup() {
  if [[ "$NO_CLEANUP" == "true" ]]; then
    warn "Skipping cleanup (--no-cleanup). Temp dirs:"
    for d in "${CLEANUP_DIRS[@]+"${CLEANUP_DIRS[@]}"}"; do info "  $d"; done
    return
  fi
  info "Cleaning up…"
  for pid in "${CLEANUP_PIDS[@]+"${CLEANUP_PIDS[@]}"}"; do
    kill "$pid" 2>/dev/null || true
  done
  for dir in "${CLEANUP_DIRS[@]+"${CLEANUP_DIRS[@]}"}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

# ── prerequisite check ─────────────────────────────────────────────────────────
check_prerequisites() {
  title "Prerequisites"
  local missing=()

  if command -v node &>/dev/null; then
    local node_major
    node_major=$(node --version | sed 's/v//' | cut -d. -f1)
    if [[ "$node_major" -ge 20 ]]; then
      pass "Node.js $(node --version)"
    else
      fail "Node.js $(node --version) — need 20+"; missing+=("node>=20")
    fi
  else
    fail "node not found"; missing+=("node")
  fi

  command -v npm  &>/dev/null && pass "npm $(npm --version)"   || { fail "npm not found";  missing+=("npm"); }
  command -v git  &>/dev/null && pass "git $(git --version | awk '{print $3}')" || { fail "git not found"; missing+=("git"); }
  command -v curl &>/dev/null && pass "curl $(curl --version | head -1 | awk '{print $2}')" || { fail "curl not found"; missing+=("curl"); }

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo
    fail "Missing: ${missing[*]}"
    echo "  Install the missing tools and re-run the test."
    exit 1
  fi
}

# ── wait for HTTP ──────────────────────────────────────────────────────────────
wait_for_http() {
  local url="$1" timeout="$2" i
  for ((i=0; i<timeout; i++)); do
    if curl -sf "$url" -o /dev/null 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# ── record result ──────────────────────────────────────────────────────────────
record() {
  local status="$1" label="$2"
  RESULTS+=("$status $label")
  if [[ "$status" == "PASS" ]]; then pass "$label"
  else fail "$label"
  fi
}

# ── write a minimal .env for non-interactive install ──────────────────────────
write_test_env() {
  local home_dir="$1"
  mkdir -p "$home_dir"
  cat > "$home_dir/.env" <<EOF
PORT=$TEST_PORT
SESSION_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
ADMIN_USERNAME=testadmin
ADMIN_PASSWORD=TestPass123!
NODE_ENV=test
NEOAGENT_RELEASE_CHANNEL=beta
EOF
  chmod 600 "$home_dir/.env"
}

# ── run neoagent install and start ────────────────────────────────────────────
# Runs `node bin/neoagent.js install` from the given repo directory with
# NEOAGENT_HOME pointing at the isolated runtime dir.
run_install_and_start() {
  local label="$1" repo_dir="$2" runtime_home="$3"
  local log_file="$runtime_home/install.log"

  info "Running install in $repo_dir …"
  # Pipe /dev/null to stdin so the installer detects non-interactive mode
  # and writes default config instead of launching the interactive wizard.
  if NEOAGENT_HOME="$runtime_home" node "$repo_dir/bin/neoagent.js" install \
      < /dev/null > "$log_file" 2>&1; then
    record "PASS" "$label: install command exited 0"
  else
    record "FAIL" "$label: install command failed (see $log_file)"
    return 1
  fi
}

# ── verify the running server ─────────────────────────────────────────────────
verify_server() {
  local label="$1" runtime_home="$2"
  local base="http://localhost:$TEST_PORT"

  info "Waiting up to ${STARTUP_TIMEOUT}s for server on port $TEST_PORT …"
  if wait_for_http "$base/" "$STARTUP_TIMEOUT"; then
    record "PASS" "$label: server reachable at $base"
  else
    record "FAIL" "$label: server did not respond within ${STARTUP_TIMEOUT}s"
    return 1
  fi

  # Auth status endpoint should return JSON with authenticated:false
  local status_resp
  status_resp=$(curl -sf "$base/api/auth/status" 2>/dev/null || echo "")
  if echo "$status_resp" | grep -q '"authenticated"'; then
    record "PASS" "$label: /api/auth/status returned valid JSON"
  else
    record "FAIL" "$label: /api/auth/status did not return expected JSON (got: $status_resp)"
  fi

  # Admin panel should exist (200 or redirect)
  local admin_code
  admin_code=$(curl -sf -o /dev/null -w "%{http_code}" "$base/admin" 2>/dev/null || echo "000")
  if [[ "$admin_code" == "200" || "$admin_code" == "301" || "$admin_code" == "302" ]]; then
    record "PASS" "$label: /admin responded HTTP $admin_code"
  else
    record "FAIL" "$label: /admin responded HTTP $admin_code (expected 200/301/302)"
  fi
}

# ── stop server started by the install ───────────────────────────────────────
stop_test_server() {
  local runtime_home="$1"
  local pid_file="$runtime_home/data/neoagent.pid"

  if [[ -f "$pid_file" ]]; then
    local pid
    pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      info "Stopped server PID $pid"
    fi
  fi
  # Kill anything left on TEST_PORT
  lsof -ti "TCP:$TEST_PORT" 2>/dev/null | xargs kill 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════════════════
# PATH A — npm pack → npm install -g → neoagent install
# This simulates what a user does with `npm install -g neoagent && neoagent install`
# except we pack the local source instead of downloading from the registry.
# ══════════════════════════════════════════════════════════════════════════════
run_path_a() {
  title "Path A — npm pack + global install"

  local tmp_npm_prefix tmp_runtime_home pack_dir tarball
  tmp_npm_prefix=$(mktemp -d /tmp/neoagent-test-npm-XXXXX)
  tmp_runtime_home=$(mktemp -d /tmp/neoagent-test-home-XXXXX)
  CLEANUP_DIRS+=("$tmp_npm_prefix" "$tmp_runtime_home")

  # Pack the local repo into a tarball
  pack_dir=$(mktemp -d /tmp/neoagent-pack-XXXXX)
  CLEANUP_DIRS+=("$pack_dir")
  info "Packing local repo…"
  npm pack --pack-destination "$pack_dir" "$REPO_ROOT" --quiet 2>/dev/null
  tarball=$(ls "$pack_dir"/neoagent-*.tgz 2>/dev/null | head -1)

  if [[ -z "$tarball" ]]; then
    record "FAIL" "Path A: npm pack produced no tarball"
    return
  fi
  pass "Packed: $(basename "$tarball")"

  # Install globally under tmp prefix
  info "Installing globally under $tmp_npm_prefix …"
  if npm install -g --prefix "$tmp_npm_prefix" "$tarball" --quiet 2>/dev/null; then
    record "PASS" "Path A: npm install -g succeeded"
  else
    record "FAIL" "Path A: npm install -g failed"
    return
  fi

  local neoagent_bin="$tmp_npm_prefix/bin/neoagent"
  if [[ ! -x "$neoagent_bin" ]]; then
    record "FAIL" "Path A: neoagent binary not found at $neoagent_bin"
    return
  fi
  pass "Binary: $neoagent_bin"

  # Write pre-seeded config so install skips interactive wizard
  write_test_env "$tmp_runtime_home"

  # Run install (the binary points back to the packed repo's lib/manager.js)
  if NEOAGENT_HOME="$tmp_runtime_home" "$neoagent_bin" install < /dev/null \
      > "$tmp_runtime_home/install.log" 2>&1; then
    record "PASS" "Path A: neoagent install exited 0"
  else
    record "FAIL" "Path A: neoagent install failed (see $tmp_runtime_home/install.log)"
    cat "$tmp_runtime_home/install.log" | tail -20
    return
  fi

  verify_server "Path A" "$tmp_runtime_home"
  stop_test_server "$tmp_runtime_home"
}

# ══════════════════════════════════════════════════════════════════════════════
# PATH B — install.sh (the curl-pipe-to-bash script)
# Runs the local install.sh which clones the repo (or reuses an existing dir)
# and then invokes `node bin/neoagent.js install`.
# ══════════════════════════════════════════════════════════════════════════════
run_path_b() {
  title "Path B — install.sh (curl-to-bash path)"

  local tmp_install_dir tmp_runtime_home
  tmp_install_dir=$(mktemp -d /tmp/neoagent-test-clone-XXXXX)
  tmp_runtime_home=$(mktemp -d /tmp/neoagent-test-home-XXXXX)
  CLEANUP_DIRS+=("$tmp_install_dir" "$tmp_runtime_home")
  rm -rf "$tmp_install_dir"   # install.sh clones into the dir; it must not pre-exist

  info "Running install.sh into $tmp_install_dir …"
  # install.sh prompts for install directory; we feed the answer via stdin.
  # It then calls `exec node ./bin/neoagent.js install`, which in non-interactive
  # mode (stdin closed after the one prompt reply) writes a default config.
  if NEOAGENT_HOME="$tmp_runtime_home" \
      bash "$REPO_ROOT/install.sh" < <(echo "$tmp_install_dir") \
      > "$tmp_runtime_home/install_sh.log" 2>&1; then
    record "PASS" "Path B: install.sh exited 0"
  else
    record "FAIL" "Path B: install.sh failed (see $tmp_runtime_home/install_sh.log)"
    tail -20 "$tmp_runtime_home/install_sh.log"
    return
  fi

  verify_server "Path B" "$tmp_runtime_home"
  stop_test_server "$tmp_runtime_home"
}

# ══════════════════════════════════════════════════════════════════════════════
# STATIC CHECKS — validate install.sh independently of a live install
# ══════════════════════════════════════════════════════════════════════════════
run_static_checks() {
  title "Static checks (install.sh)"

  local script="$REPO_ROOT/install.sh"

  # Script exists and is valid bash
  if bash -n "$script" 2>/dev/null; then
    record "PASS" "install.sh: syntax OK"
  else
    record "FAIL" "install.sh: syntax error"
  fi

  # set -euo pipefail present
  if grep -q 'set -euo pipefail' "$script"; then
    record "PASS" "install.sh: set -euo pipefail present"
  else
    record "FAIL" "install.sh: missing set -euo pipefail"
  fi

  # Missing-dep check is present
  if grep -q 'MISSING' "$script"; then
    record "PASS" "install.sh: missing-dependency check present"
  else
    record "FAIL" "install.sh: no missing-dependency check found"
  fi

  # HTTPS clone URL
  if grep -q 'https://github.com/NeoLabs-Systems/NeoAgent.git' "$script"; then
    record "PASS" "install.sh: HTTPS clone URL correct"
  else
    record "FAIL" "install.sh: HTTPS clone URL not found or wrong"
  fi

  # Delegates to node install
  if grep -q 'node.*bin/neoagent.js install' "$script"; then
    record "PASS" "install.sh: delegates to node bin/neoagent.js install"
  else
    record "FAIL" "install.sh: does not delegate to node install"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# STATIC CHECKS — neoagent CLI
# ══════════════════════════════════════════════════════════════════════════════
run_cli_checks() {
  title "Static checks (CLI)"

  local bin="$REPO_ROOT/bin/neoagent.js"

  if [[ -x "$bin" || -f "$bin" ]]; then
    record "PASS" "bin/neoagent.js: file exists"
  else
    record "FAIL" "bin/neoagent.js: not found"
    return
  fi

  if head -1 "$bin" | grep -q '#!/usr/bin/env node'; then
    record "PASS" "bin/neoagent.js: correct shebang"
  else
    record "FAIL" "bin/neoagent.js: missing or wrong shebang"
  fi

  # All documented CLI commands are in the runCLI switch
  for cmd in install start stop restart update status logs setup; do
    if grep -q "case '$cmd':" "$REPO_ROOT/lib/manager.js"; then
      record "PASS" "CLI: '$cmd' command registered"
    else
      record "FAIL" "CLI: '$cmd' command not found in manager.js switch"
    fi
  done

  # 'neoagent fix' is mentioned in docs/getting-started.md but has no case in runCLI
  if grep -q "case 'fix':" "$REPO_ROOT/lib/manager.js"; then
    record "PASS" "CLI: 'fix' command registered"
  else
    warn "CLI: 'fix' is documented (README, getting-started.md) but has no case in manager.js runCLI switch"
  fi

  # NEOAGENT_HOME respected by paths.js
  if grep -q 'process.env.NEOAGENT_HOME' "$REPO_ROOT/runtime/paths.js"; then
    record "PASS" "runtime/paths.js: NEOAGENT_HOME override present"
  else
    record "FAIL" "runtime/paths.js: NEOAGENT_HOME override missing"
  fi

  # Node version guard
  if grep -q 'major < 20' "$REPO_ROOT/lib/manager.js"; then
    record "PASS" "manager.js: Node.js version guard present"
  else
    record "FAIL" "manager.js: Node.js version guard missing"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
title "NeoAgent install smoke test"
echo -e "${DIM}  Repo: $REPO_ROOT${RESET}"
echo -e "${DIM}  Port: $TEST_PORT${RESET}"
echo -e "${DIM}  Path: $INSTALL_PATH${RESET}"

check_prerequisites
run_static_checks
run_cli_checks

case "$INSTALL_PATH" in
  A|a)      run_path_a ;;
  B|b)      run_path_b ;;
  both)     run_path_a; run_path_b ;;
  static)   : ;;  # static checks already ran above
  *)
    fail "Unknown --path value: $INSTALL_PATH (use A, B, both, or --static-only)"
    exit 1 ;;
esac

# ── summary ───────────────────────────────────────────────────────────────────
title "Summary"
PASS_COUNT=0
FAIL_COUNT=0
for r in "${RESULTS[@]}"; do
  if [[ "$r" == PASS* ]]; then
    pass "${r#PASS }"
    ((PASS_COUNT++)) || true
  else
    fail "${r#FAIL }"
    ((FAIL_COUNT++)) || true
  fi
done

echo
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "  ${GRN}${BOLD}All $PASS_COUNT checks passed.${RESET}"
  exit 0
else
  echo -e "  ${RED}${BOLD}$FAIL_COUNT of $((PASS_COUNT+FAIL_COUNT)) checks failed.${RESET}"
  exit 1
fi
