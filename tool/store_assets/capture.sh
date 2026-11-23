#!/usr/bin/env bash
# Captures the raw store screenshots that render.py turns into Play and README images.
#
# Taps are screen coordinates for a 1080x2220 portrait phone (Samsung Galaxy A6+,
# 3-button navigation, Samsung Keyboard). Flutter's constantly animating gauges keep
# uiautomator from ever reaching an idle state, so taps cannot be found by label; after
# a layout change update the coordinates below (one screenshot per step shows where
# things moved). The form taps marked "keyboard open" depend on the keyboard's height.
#
# Before running:
#   - AutoCare freshly installed from a release build (tool/build_verified.sh apk), never
#     opened: the first shot is the welcome screen, which shows only before the first
#     choice. Do not run it on a phone whose AutoCare holds real history: the script
#     adds a sample refuel and oil change to Riwayat.
#   - Display font size at default (font_scale 1.0); the script checks this.
#
# The script turns auto-rotate off for the run and restores it on exit.
#
# Usage: tool/store_assets/capture.sh <out-dir>     (ADB=/path/to/adb, PKG=<package>)
set -euo pipefail

out=${1:?usage: capture.sh <out-dir>}
adb=${ADB:-adb}
pkg=${PKG:-com.autocare.autocare}
mkdir -p "$out"

shot() { "$adb" exec-out screencap -p > "$out/$1.png"; echo "saved $out/$1.png"; }
tap() { "$adb" shell input tap "$1" "$2"; sleep "${3:-2}"; }
back() { "$adb" shell input keyevent KEYCODE_BACK; sleep 1; }
# adb's "input text" takes %s for a space.
text() { "$adb" shell input text "$1"; sleep 1; }

font_scale=$("$adb" shell settings get system font_scale | tr -d '\r')
if [ "$font_scale" != "1.0" ]; then
  echo "font_scale is $font_scale; set the display font size to default first" >&2
  exit 1
fi
rotation=$("$adb" shell settings get system accelerometer_rotation | tr -d '\r')
trap '"$adb" shell settings put system accelerometer_rotation "$rotation"' EXIT
"$adb" shell settings put system accelerometer_rotation 0

tab_y=1999
tab_beranda=108
tab_live=324
tab_diagnostik=540
tab_riwayat=756
tab_pengaturan=972

"$adb" shell am start -n "$pkg/com.autocare.autocare.MainActivity" > /dev/null
sleep 6
shot 08-mulai
tap 540 871 8             # "Coba dengan simulator": Beranda with sample data
shot 01-beranda
"$adb" logcat -d | grep "AutoCare SRC_REV" | tail -n 1 || true

tap $tab_live $tab_y 3
tap 200 139 3;            shot 02-live-meter
tap 471 139 3;            shot 03-live-sensor

# The chart only samples while its sheet is open, so give it a few minutes.
tap 540 477
echo "waiting 180 s for the live chart to fill"
sleep 180
shot 04-grafik
back                      # close the chart

tap $tab_riwayat $tab_y
tap 901 1726              # Catat
tap 540 1768              # Isi BBM (Pertalite is preselected)
tap 540 1427 1;           text 30                   # Jumlah (liter)
tap 540 800 1;            text 300000               # Total harga (keyboard open)
tap 786 1241 6            # Simpan (keyboard open); waits out the snackbar
tap 901 1726              # Catat
tap 540 1957              # Servis (Ganti Oli Mesin is preselected)
tap 540 1427 1;           text "Oli%s10W-40%s+%sfilter%soli"  # Catatan
tap 540 965 1;            text 450000               # Biaya (keyboard open)
tap 786 1241 6            # Simpan (keyboard open)
shot 07-riwayat

tap $tab_pengaturan $tab_y
"$adb" shell input swipe 540 1600 540 500 300; sleep 1
"$adb" shell input swipe 540 1600 540 500 300; sleep 2   # at the end of the list
tap 540 1021              # Simulator: "Lampu Check Engine" ON (adds P0138)

tap $tab_diagnostik $tab_y
tap 312 803 20            # "Pindai sekarang"; the simulated scan takes a few seconds
shot 05-diagnostik
tap 583 137               # Kamus kode
tap 540 289 1;            text P0138                # search
back                      # hide the keyboard
tap 540 772               # P0138 detail sheet
shot 06-kamus-kode
back

tap $tab_beranda $tab_y
echo "done; Lampu Check Engine is still ON and Riwayat holds the two sample entries"
