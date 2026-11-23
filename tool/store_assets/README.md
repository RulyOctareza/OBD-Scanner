# Store assets

Regenerates every screenshot and promotional image used by the Play listing (`fastlane/metadata/android/`), the README (`docs/screenshots/`) and GitHub (`docs/assets/social-preview.png`).

1. Build a release APK with `tool/build_verified.sh apk`, install it fresh on the phone (`adb install`, after `adb uninstall com.autocare.autocare` if an older copy is there; answer the Play Protect prompt on the phone if it appears), do not open it, then:

   ```bash
   tool/store_assets/capture.sh /tmp/autocare-raw
   ```

   The script starts on the welcome screen, chooses the simulator, adds a sample refuel and oil change, turns on the simulated Check Engine light and scans. Read the requirements at the top of `capture.sh` first: it needs a never-opened install and the default font size, and its taps are coordinates for a 1080×2220 phone. The captures still show the status bar and notification icons; they are cropped away in step 2, so keep the raw files out of git.

2. Render (needs Python with Pillow and Google Chrome):

   ```bash
   python3 tool/store_assets/render.py --raw /tmp/autocare-raw
   ```

   Fonts come from `assets/fonts` (Inter, OFL), the same files the app bundles; `--fonts <dir>` overrides them. Captions, screenshot order and the feature-graphic tagline are the `SHOTS` and `FEATURE` tables in `render.py`. Outputs are overwritten, never cleared: if a shot is renamed or dropped, remove its old files by hand.

Play limits checked by the output: screenshots 1080×1920 without alpha (raw 1080×2220 is longer than Play's 2:1 limit), feature graphic 1024×500 without alpha, icon 512×512 PNG.
