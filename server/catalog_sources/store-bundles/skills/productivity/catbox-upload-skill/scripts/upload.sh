#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: upload.sh <file_path> [--service litterbox|catbox] [--time 1h|12h|24h|72h] [--userhash HASH]

Options:
  --service   Upload target. Defaults to litterbox.
  --time      Litterbox retention window. Defaults to 24h.
  --userhash  Optional Catbox account hash for uploads associated with an account.
  -h, --help  Show this help text.

Limits:
  litterbox: 1 GB
  catbox:    200 MB
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_value() {
  local option="$1"
  local value="${2-}"
  [[ -n "$value" ]] || fail "$option requires a value"
}

SERVICE="litterbox"
TIME="24h"
USERHASH=""
FILE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service)
      require_value "$1" "${2-}"
      SERVICE="$2"
      shift 2
      ;;
    --time)
      require_value "$1" "${2-}"
      TIME="$2"
      shift 2
      ;;
    --userhash)
      require_value "$1" "${2-}"
      USERHASH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      fail "unknown option: $1"
      ;;
    *)
      [[ -z "$FILE_PATH" ]] || fail "only one file path is supported"
      FILE_PATH="$1"
      shift
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  [[ -z "$FILE_PATH" ]] || fail "only one file path is supported"
  FILE_PATH="$1"
  shift
fi

[[ $# -eq 0 ]] || fail "only one file path is supported"

[[ -n "$FILE_PATH" ]] || {
  usage
  fail "file path is required"
}

command -v curl >/dev/null 2>&1 || fail "curl is not installed"
[[ -f "$FILE_PATH" ]] || fail "file not found: $FILE_PATH"
[[ -r "$FILE_PATH" ]] || fail "file is not readable: $FILE_PATH"

case "$SERVICE" in
  litterbox|catbox)
    ;;
  *)
    fail "service must be either 'litterbox' or 'catbox'"
    ;;
esac

case "$TIME" in
  1h|12h|24h|72h)
    ;;
  *)
    fail "time must be one of: 1h, 12h, 24h, 72h"
    ;;
esac

FILE_SIZE_BYTES="$(wc -c < "$FILE_PATH" | tr -d '[:space:]')"
LITTERBOX_LIMIT_BYTES=1073741824
CATBOX_LIMIT_BYTES=209715200

if [[ "$SERVICE" == "litterbox" ]] && (( FILE_SIZE_BYTES > LITTERBOX_LIMIT_BYTES )); then
  fail "litterbox uploads are limited to 1 GB"
fi

if [[ "$SERVICE" == "catbox" ]] && (( FILE_SIZE_BYTES > CATBOX_LIMIT_BYTES )); then
  fail "catbox uploads are limited to 200 MB"
fi

CURL_FILE_PATH="${FILE_PATH//;/\\;}"

if [[ "$SERVICE" == "litterbox" ]]; then
  ENDPOINT="https://litterbox.catbox.moe/resources/internals/api.php"
  RESPONSE="$(
    curl --silent --show-error --fail \
      --user-agent 'NeoAgent catbox-upload-skill/1.0' \
      -F 'reqtype=fileupload' \
      -F "time=$TIME" \
      -F "fileToUpload=@$CURL_FILE_PATH" \
      "$ENDPOINT"
  )"
else
  ENDPOINT="https://catbox.moe/user/api.php"
  if [[ -n "$USERHASH" ]]; then
    RESPONSE="$(
      curl --silent --show-error --fail \
        --user-agent 'NeoAgent catbox-upload-skill/1.0' \
        -F 'reqtype=fileupload' \
        -F "userhash=$USERHASH" \
        -F "fileToUpload=@$CURL_FILE_PATH" \
        "$ENDPOINT"
    )"
  else
    RESPONSE="$(
      curl --silent --show-error --fail \
        --user-agent 'NeoAgent catbox-upload-skill/1.0' \
        -F 'reqtype=fileupload' \
        -F "fileToUpload=@$CURL_FILE_PATH" \
        "$ENDPOINT"
    )"
  fi
fi

RESPONSE="$(printf '%s' "$RESPONSE" | tr -d '\r\n')"
[[ "$RESPONSE" =~ ^https?:// ]] || fail "upload failed: $RESPONSE"

printf '%s\n' "$RESPONSE"
