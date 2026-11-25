#!/bin/sh
# A stand-in for adb used by both the Node scenario generator and the Go tests.
# It logs its arguments to $FAKE_ADB_LOG and answers like an emulator would.
fixtures="$(cd "$(dirname "$0")" && pwd)"
[ -n "$FAKE_ADB_FIXTURES" ] && fixtures="$FAKE_ADB_FIXTURES"
echo "$*" >> "$FAKE_ADB_LOG"
# Arguments: -s <serial> <command> ...
command="$3"
shift 3
rest="$*"
case "$command" in
  shell)
    case "$rest" in
      "getprop sys.boot_completed") echo 1 ;;
      "uiautomator dump"*) echo "UI hierchary dumped to: /sdcard/window_dump.xml" ;;
      "cat '/sdcard/window_dump.xml'") cat "$fixtures/window_dump.xml" ;;
      "pm list packages -3") printf 'package:com.a\npackage:com.b\n' ;;
      "pm list packages") printf 'package:android\npackage:com.a\n\n' ;;
      "echo hi") echo hi ;;
      "fail") echo "boom" >&2; exit 3 ;;
      *) echo ok ;;
    esac ;;
  exec-out) cat "$fixtures/screen.png" ;;
  install) echo "Performing Streamed Install"; echo "Success" ;;
  emu) [ -n "$FAKE_ADB_PID_FILE" ] && kill "$(cat "$FAKE_ADB_PID_FILE")" 2>/dev/null; echo OK ;;
  *) ;;
esac
exit 0
