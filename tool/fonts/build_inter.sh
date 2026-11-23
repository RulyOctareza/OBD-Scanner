#!/usr/bin/env bash
# Rebuilds assets/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf from the
# static TTFs of an Inter release (https://github.com/rsms/inter, OFL; e.g.
# Inter-4.1.zip, folder extras/ttf): subset to Latin, Latin-1 and Latin
# Extended-A plus punctuation, currency, arrows, math and shapes with every
# OpenType feature kept (tabular figures stay a runtime feature: freezing
# them into the glyphs measured no faster on the SM-A605G), hinting dropped.
# Needs python3 with fontTools.
#
# Usage: tool/fonts/build_inter.sh <dir-with-Inter-*.ttf>
set -euo pipefail
SRC=${1:?usage: tool/fonts/build_inter.sh <dir-with-Inter-*.ttf>}
UNICODES="U+0020-007E,U+00A0-00FF,U+0100-017F,U+0192,U+0218-021B,U+02BB-02BC,U+02C6-02C7,U+02DA,U+02DC,U+2000-206F,U+2070-209F,U+20A0-20CF,U+2100-218F,U+2190-21FF,U+2200-22FF,U+2300-23FF,U+25A0-25FF,U+FEFF,U+FFFD"
for weight in Regular Medium SemiBold Bold; do
  python3 -m fontTools.subset "$SRC/Inter-$weight.ttf" \
    --output-file="assets/fonts/Inter-$weight.ttf" \
    --unicodes="$UNICODES" --layout-features='*' --name-IDs='*' \
    --name-languages='*' --notdef-outline --no-hinting
done
