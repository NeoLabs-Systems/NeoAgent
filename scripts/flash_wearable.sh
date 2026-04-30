#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/firmware/neoagent_wearable_esp32s3_amoled"
TARGET="esp32s3"
DEFAULT_IDF_PATH="${HOME}/esp/esp-idf"
PORT=""
BAUD="${ESPBAUD:-921600}"
ERASE_FIRST=0
RUN_MONITOR=0
SKIP_BUILD=0

prefer_system_toolchain() {
  local preferred_bin
  for preferred_bin in /opt/homebrew/bin /usr/local/bin; do
    [[ -d "${preferred_bin}" ]] || continue
    case ":${PATH}:" in
      *":${preferred_bin}:"*) ;;
      *) PATH="${preferred_bin}:${PATH}" ;;
    esac
  done
  export PATH
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Flash the NeoAgent wearable firmware to a connected ESP32-S3 board.

Options:
  --port PORT       Serial device path to use
  --baud BAUD       Flash baud rate (default: ${BAUD})
  --erase           Erase flash before flashing
  --monitor         Open idf.py monitor after flashing
  --skip-build      Skip the build step and only flash
  -h, --help        Show this help

Environment:
  IDF_PATH          Required by idf.py / ESP-IDF
  ESPPORT           Optional default serial port
  ESPBAUD           Optional default baud rate
EOF
}

ensure_idf_env() {
  if command -v idf.py >/dev/null 2>&1; then
    return 0
  fi

  local candidate_idf_path="${IDF_PATH:-${DEFAULT_IDF_PATH}}"
  local export_script="${candidate_idf_path}/export.sh"

  if [[ -f "${export_script}" ]]; then
    # shellcheck disable=SC1090
    . "${export_script}" >/dev/null
  fi

  if ! command -v idf.py >/dev/null 2>&1; then
    echo "idf.py is not available. Install ESP-IDF and export its environment first." >&2
    echo "Expected default install at: ${candidate_idf_path}" >&2
    return 1
  fi
}

pick_port() {
  if [[ -n "${PORT}" ]]; then
    printf '%s\n' "${PORT}"
    return 0
  fi
  if [[ -n "${ESPPORT:-}" ]]; then
    printf '%s\n' "${ESPPORT}"
    return 0
  fi

  local -a candidates=()
  local pattern
  for pattern in \
    /dev/cu.usbmodem* \
    /dev/cu.usbserial* \
    /dev/cu.wchusbserial* \
    /dev/ttyUSB* \
    /dev/ttyACM* \
    /dev/tty.usbmodem* \
    /dev/tty.usbserial*
  do
    for device in ${pattern}; do
      [[ -e "${device}" ]] || continue
      candidates+=("${device}")
    done
  done

  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "No serial device detected. Pass --port explicitly." >&2
    return 1
  fi
  if [[ ${#candidates[@]} -gt 1 ]]; then
    printf 'Multiple serial devices detected:\n' >&2
    printf '  %s\n' "${candidates[@]}" >&2
    echo "Pass --port explicitly." >&2
    return 1
  fi
  printf '%s\n' "${candidates[0]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    --baud)
      BAUD="${2:-}"
      shift 2
      ;;
    --erase)
      ERASE_FIRST=1
      shift
      ;;
    --monitor)
      RUN_MONITOR=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "Firmware project not found at ${PROJECT_DIR}" >&2
  exit 1
fi

prefer_system_toolchain
ensure_idf_env

PORT="$(pick_port)"

echo "[wearable-flash] project: ${PROJECT_DIR}"
echo "[wearable-flash] target:  ${TARGET}"
echo "[wearable-flash] port:    ${PORT}"
echo "[wearable-flash] baud:    ${BAUD}"

IDF_ARGS=(-C "${PROJECT_DIR}" -p "${PORT}" -b "${BAUD}")

if [[ "${ERASE_FIRST}" -eq 1 ]]; then
  idf.py "${IDF_ARGS[@]}" set-target "${TARGET}"
  idf.py "${IDF_ARGS[@]}" erase-flash
fi

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  if [[ ! -f "${PROJECT_DIR}/sdkconfig" ]]; then
    idf.py "${IDF_ARGS[@]}" set-target "${TARGET}"
  fi
  idf.py "${IDF_ARGS[@]}" build
fi

if [[ "${RUN_MONITOR}" -eq 1 ]]; then
  idf.py "${IDF_ARGS[@]}" flash monitor
else
  idf.py "${IDF_ARGS[@]}" flash
fi
