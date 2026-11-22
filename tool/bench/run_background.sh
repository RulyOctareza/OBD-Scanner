#!/usr/bin/env bash
# Checks that the OBD link survives with the app in the background, which is
# what the native foreground service exists for: connect (fake adapter), go
# home for SCREEN_ON_S with the screen on, come back, go home again for
# SCREEN_OFF_S with the screen off, then remove the task as a swipe from
# recents does. The bench app reports link health every 30 s (logcat tag
# flutter, AUTOCARE_BENCH {"type":"bg",...}); snapshots of the service and
# its wake lock go to <out-dir>/snapshots.txt.
#
# Usage: tool/bench/run_background.sh <out-dir> [--no-build]
set -euo pipefail

OUT=${1:?usage: tool/bench/run_background.sh <out-dir> [--no-build]}
PKG=com.autocare.autocare.bench
ACTIVITY=com.autocare.autocare.MainActivity
SCREEN_ON_S=${SCREEN_ON_S:-300}
SCREEN_OFF_S=${SCREEN_OFF_S:-300}
mkdir -p "$OUT"

if [[ "${2:-}" != "--no-build" ]]; then
  tool/build_verified.sh apk --profile \
    --target-platform "${TARGET_PLATFORM:-android-arm}" \
    -t lib/dev/bench/bench_main.dart \
    -P autocareBench=true \
    --dart-define=BENCH_SCENARIO=background | tee "$OUT/build.txt"
fi
adb install -r build/app/outputs/flutter-apk/app-profile.apk > /dev/null

old_stay_on=$(adb shell settings get global stay_on_while_plugged_in | tr -d '\r')
cleanup() {
  adb logcat -d > "$OUT/logcat.txt" || true
  adb shell am force-stop "$PKG" || true
  adb shell settings put global stay_on_while_plugged_in "$old_stay_on" || true
  adb shell input keyevent KEYCODE_WAKEUP || true
}
trap cleanup EXIT
adb shell settings put global stay_on_while_plugged_in 7
adb shell input keyevent KEYCODE_WAKEUP

snapshot() {
  {
    echo "== $1 ($(date '+%T'))"
    echo "pid: $(adb shell pidof "$PKG" | tr -d '\r' || true)"
    adb shell dumpsys activity services "$PKG" | grep -E 'ServiceRecord|isForeground' || echo 'no service'
    adb shell dumpsys power | grep -i 'AutoCare:ObdLink' || echo 'no ObdLink wake lock'
    adb shell dumpsys power | grep -E 'mWakefulness=' || true
    adb logcat -d -s flutter | grep '"type":"bg"' | tail -2 | sed 's/.*AUTOCARE_BENCH //'
  } >> "$OUT/snapshots.txt"
}

adb shell am force-stop "$PKG"
sleep 3
adb logcat -c
adb shell am start -n "$PKG/$ACTIVITY" > /dev/null
deadline=$((SECONDS + 120))
until adb logcat -d -s flutter | grep -q AUTOCARE_BENCH_BG_READY; do
  if (( SECONDS > deadline )) || adb logcat -d -s flutter | grep -q AUTOCARE_BENCH_FAILED; then
    echo "bench did not connect" >&2
    exit 1
  fi
  sleep 3
done
snapshot "connected, app in front"

adb shell input keyevent KEYCODE_HOME
sleep "$SCREEN_ON_S"
snapshot "app in background ${SCREEN_ON_S}s, screen on"

adb shell am start -n "$PKG/$ACTIVITY" > /dev/null
sleep 5
adb exec-out screencap -p > "$OUT/returned-screen-on.png"
snapshot "back in front"

adb shell input keyevent KEYCODE_HOME
adb shell input keyevent KEYCODE_SLEEP
sleep "$SCREEN_OFF_S"
snapshot "app in background ${SCREEN_OFF_S}s, screen off"

# Removing the app's stack runs the same onTaskRemoved path as a swipe from
# recents. The phone's lock screen stays up after waking it.
adb shell input keyevent KEYCODE_WAKEUP
stack=$(adb shell am stack list | tr -d '\r' |
  awk -v pkg="$PKG/" '/^Stack id=/{split($2, a, "="); id=a[2]} index($0, pkg){print id; exit}')
if [[ -n "$stack" ]]; then
  adb shell am stack remove "$stack"
  sleep 5
  snapshot "task removed (stack $stack)"
else
  snapshot "task not found in am stack list"
fi
echo "background check done"
