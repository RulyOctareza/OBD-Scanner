# Store assets

Regenerates every screenshot and promotional image used by the Play listing (`fastlane/metadata/android/`), the README (`docs/screenshots/`) and GitHub (`docs/assets/social-preview.png`).

1. Install AutoCare on the phone with the real fonts (a release build once the fonts are bundled, or `flutter build apk --profile --target-platform android-arm` for a 32-bit phone such as the Galaxy A6+), prepare it as described at the top of `capture.sh`, then:

   ```bash
   tool/store_assets/capture.sh /tmp/autocare-raw
   ```

   The captures still show the status bar and notification icons; they are cropped away in step 2, so keep the raw files out of git.

2. Render (needs Python with Pillow and Google Chrome):

   ```bash
   python3 tool/store_assets/render.py --raw /tmp/autocare-raw --fonts assets/fonts
   ```

   `--fonts` points at `Inter-Regular`, `Inter-SemiBold` and `Inter-Bold` (`.otf` or `.ttf`, OFL). Captions, screenshot order and the feature-graphic tagline are the `SHOTS` and `FEATURE` tables in `render.py`.

Play limits checked by the output: screenshots 1080×1920 without alpha (raw 1080×2220 is longer than Play's 2:1 limit), feature graphic 1024×500 without alpha, icon 512×512 PNG.
