#!/usr/bin/env bash
# Captures the raw store screenshots that render.py turns into Play and README images.
#
# Taps are screen coordinates for a 1080x2220 portrait phone (Samsung Galaxy A6+,
# 3-button navigation). Flutter's constantly animating gauges keep uiautomator from
# ever reaching an idle state, so taps cannot be found by label; after a layout change
# update the coordinates below (one screenshot per step shows where things moved).
#
# Before running:
#   - AutoCare installed from a build that shows the real fonts (release with bundled
#     fonts, or profile), onboarding finished, Simulator Mode ON, "Kontak / Mesin Menyala" ON,
#     every other demo switch OFF.
#   - Timeline holds one refuel and one oil change (Linimasa > Catat Aktivitas).
#   - Phone in portrait with auto-rotate off, AutoCare open on the Kesehatan tab.
#
# Usage: tool/store_assets/capture.sh <out-dir>     (ADB=/path/to/adb to override)
set -euo pipefail

out=${1:?usage: capture.sh <out-dir>}
adb=${ADB:-adb}
mkdir -p "$out"

shot() { "$adb" exec-out screencap -p > "$out/$1.png"; echo "saved $out/$1.png"; }
tap() { "$adb" shell input tap "$1" "$2"; sleep "${3:-2}"; }
back() { "$adb" shell input keyevent KEYCODE_BACK; sleep 1; }

tab_y=1982
tab_health=144
tab_meter=342
tab_sensor=540
tab_timeline=737
tab_settings=935

tap $tab_health $tab_y;   shot 01-kesehatan
tap $tab_meter $tab_y 3;  shot 02-meter
tap $tab_sensor $tab_y;   shot 03-sensor

# The chart buffer only samples while a chart is open, so give it a few minutes.
tap 280 470
echo "waiting 180 s for the live chart to fill"
sleep 180
shot 04-grafik
tap 960 222 1             # close the chart

tap $tab_timeline $tab_y; shot 07-linimasa

tap $tab_settings $tab_y
tap 844 1646              # "Simulasikan Check Engine (DTC)" ON
tap $tab_health $tab_y
tap 540 1308 3            # "Pindai Diagnostik ECU" card (with 1 DTC)
tap 540 894 8             # "Mulai Pemindaian ECU", the simulated scan takes a few seconds
shot 05-diagnostik
tap 1016 137 3            # dictionary icon
tap 540 1540              # P0115 detail
shot 06-kamus-dtc
back; back; back

tap $tab_health $tab_y
tap 540 285 3             # connection banner opens the connection sheet
shot 08-simulator
back

echo "done; turn 'Simulasikan Check Engine' off again in Pengaturan"
