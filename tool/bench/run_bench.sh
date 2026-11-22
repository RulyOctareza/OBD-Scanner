#!/usr/bin/env bash
# Builds the dev benchmark (lib/dev/bench) as its own package,
# com.autocare.autocare.bench, installed beside the real app, and runs it RUNS
# times on the connected phone, one cold start per run. Results: one JSON line
# per scenario in <out-dir>/runN.jsonl.
#
# Usage: tool/bench/run_bench.sh <out-dir> [--no-build]
# Env:   RUNS (default 3), TARGET_PLATFORM (default android-arm: the SM-A605G
#        reference phone has a 32-bit userspace).
set -euo pipefail

OUT=${1:?usage: tool/bench/run_bench.sh <out-dir> [--no-build]}
RUNS=${RUNS:-3}
PKG=com.autocare.autocare.bench
ACTIVITY=com.autocare.autocare.MainActivity
APK=build/app/outputs/flutter-apk/app-profile.apk
mkdir -p "$OUT"

if [[ "${2:-}" != "--no-build" ]]; then
  # Fresh Dart code is proven by tool/build_verified.sh (SRC_REV stamp).
  tool/build_verified.sh apk --profile \
    --target-platform "${TARGET_PLATFORM:-android-arm}" \
    -t lib/dev/bench/bench_main.dart \
    -P autocareBench=true | tee "$OUT/build.txt"
fi
ls -l "$APK" > "$OUT/apk.txt"
adb install -r "$APK" > /dev/null

# The screen must stay on for the whole run; the user's setting is restored.
old_stay_on=$(adb shell settings get global stay_on_while_plugged_in | tr -d '\r')
cleanup() {
  adb shell am force-stop "$PKG" || true
  adb shell settings put global stay_on_while_plugged_in "$old_stay_on" || true
}
trap cleanup EXIT
adb shell settings put global stay_on_while_plugged_in 7
adb shell input keyevent KEYCODE_WAKEUP

adb shell getprop ro.product.model > "$OUT/device.txt"
adb shell getprop ro.build.version.release >> "$OUT/device.txt"
adb shell getprop ro.product.cpu.abilist >> "$OUT/device.txt"

# Conditions that move Snapdragon 450 numbers as much as an optimization does.
conditions() {
  date '+time %F %T'
  adb shell dumpsys battery | grep -E 'AC powered|USB powered|level|temperature'
  echo "brightness $(adb shell settings get system screen_brightness | tr -d '\r') mode $(adb shell settings get system screen_brightness_mode | tr -d '\r')"
  echo "low_power $(adb shell settings get global low_power | tr -d '\r')"
  adb shell dumpsys media_session | grep -E 'package=|state=PlaybackState' | head -6
  adb shell dumpsys activity recents | grep -E 'Recent #[0-9]+' | head -6
  adb shell dumpsys thermalservice 2>/dev/null | grep -iE 'status|temperature\{' | head -6
}

# Foreground service and wake lock state of the bench process.
fgs_check() {
  echo "== $1"
  adb shell dumpsys activity services "$PKG" | grep -E 'ServiceRecord|isForeground|foregroundId' || echo 'no service'
  adb shell dumpsys power | grep -i 'AutoCare:ObdLink' || echo 'no ObdLink wake lock'
}

for i in $(seq 1 "$RUNS"); do
  adb shell am force-stop "$PKG"
  sleep 5
  conditions > "$OUT/run$i-conditions.txt" || true
  adb logcat -c
  adb shell am start -W -n "$PKG/$ACTIVITY" > "$OUT/run$i-am-start.txt"
  started=$SECONDS
  deadline=$((SECONDS + 420))
  checked_mid=0
  while true; do
    log=$(adb logcat -d -s flutter)
    if grep -q "AUTOCARE_BENCH_DONE" <<< "$log"; then break; fi
    # Link-up check of the foreground service and its wake lock, mid-run.
    if (( checked_mid == 0 && SECONDS - started > 60 )); then
      fgs_check "connected" > "$OUT/run$i-fgs.txt"
      checked_mid=1
    fi
    if grep -q "AUTOCARE_BENCH_FAILED" <<< "$log" || (( SECONDS > deadline )); then
      adb logcat -d > "$OUT/run$i-logcat.txt"
      echo "run $i failed, see $OUT/run$i-logcat.txt" >&2
      exit 1
    fi
    sleep 5
  done
  adb exec-out run-as "$PKG" cat app_flutter/bench_results.jsonl > "$OUT/run$i.jsonl" ||
    adb logcat -d -s flutter | sed -n 's/.*AUTOCARE_BENCH //p' > "$OUT/run$i.jsonl"
  fgs_check "after disconnect" >> "$OUT/run$i-fgs.txt"
  adb logcat -d > "$OUT/run$i-logcat.txt"
  grep "Displayed $PKG" "$OUT/run$i-logcat.txt" > "$OUT/run$i-displayed.txt" || true
  echo "run $i done"
done
