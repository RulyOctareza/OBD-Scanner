#!/usr/bin/env python3
"""Builds every store and README image from raw phone screenshots.

Input: raw 1080x2220 screenshots (Samsung A6+ class, status bar 63 px, 3-button
nav bar 126 px) named after SHOTS below, taken with capture.sh in Simulator Mode.

Output:
  docs/screenshots/<name>.png                         cropped, 720 px wide (README, Pages)
  fastlane/metadata/android/<locale>/images/
      phoneScreenshots/<n>_<name>.png                 1080x1920 framed + caption, RGB
      featureGraphic.png                              1024x500, RGB
      icon.png                                        512x512, RGBA
  docs/assets/social-preview.png                      1280x640 (upload by hand on GitHub)
  docs/assets/app-icon.png                            192x192 (site header / favicon)

Framed images are HTML pages rendered by headless Chrome, so typography matches
the app (Inter). Play rejects alpha in screenshots and the feature graphic, and
screenshots longer than 2:1, which is why raw 1080x2220 captures are framed.

Usage:
  python3 tool/store_assets/render.py --raw <dir> --fonts <dir with Inter-*.otf|ttf>
"""

from __future__ import annotations

import argparse
import html
import os
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CHROME = os.environ.get(
    "CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
)

# Raw capture geometry (1080x2220 @ 420 dpi): 24 dp status bar, 48 dp nav bar.
STATUS_BAR_PX = 63
NAV_BAR_PX = 126

# Order = Play screenshot order. Captions stay short: Play shows them small.
SHOTS = [
    {
        "name": "01-kesehatan",
        "label": {"id": "Beranda", "en": "Home"},
        "id": ("Skor kesehatan mobil, langsung dari mesin",
               "Suhu mesin, aki, kode kerusakan, dan jadwal oli dalam satu skor."),
        "en": ("Your car's health at a glance",
               "Coolant, battery, trouble codes and oil schedule in one live score."),
    },
    {
        "name": "02-meter",
        "label": {"id": "Live · Meter", "en": "Live · Gauges"},
        "id": ("Meter yang bisa Anda atur",
               "Putaran mesin, kecepatan, Trip A dan B, plus petunjuk Hemat."),
        "en": ("A cockpit you can customise",
               "Engine speed, vehicle speed, Trip A and B, plus an economy hint."),
    },
    {
        "name": "03-sensor",
        "label": {"id": "Live · Sensor", "en": "Live · Sensors"},
        "id": ("Semua sensor penting dalam satu layar",
               "Suhu, tegangan aki, MAP, MAF, beban mesin, dan lainnya."),
        "en": ("Every key sensor on one screen",
               "Temperatures, battery voltage, MAP, MAF, engine load and more."),
    },
    {
        "name": "04-grafik",
        "label": {"id": "Live · Grafik sensor", "en": "Live · Sensor chart"},
        "id": ("Grafik riwayat tiap sensor",
               "Tren 1 menit sampai 1 jam, lengkap dengan puncak dan rata-rata."),
        "en": ("A history chart for every sensor",
               "Trends from 1 minute to 1 hour, with peak and average."),
    },
    {
        "name": "05-diagnostik",
        "label": {"id": "Diagnostik · Pindai", "en": "Diagnostics · Scan"},
        "id": ("Pindai dan hapus kode kerusakan",
               "Kode aktif, tertunda, dan permanen, plus kesiapan uji emisi."),
        "en": ("Scan and clear trouble codes",
               "Active, pending and permanent DTCs, plus emission readiness."),
    },
    {
        "name": "06-kamus-dtc",
        "label": {"id": "Diagnostik · Kamus kode", "en": "Diagnostics · Code dictionary"},
        "id": ("Arti kode kerusakan, dalam Bahasa Indonesia",
               "Gejala, kemungkinan penyebab, dan rekomendasi tindakan."),
        "en": ("Trouble codes, explained",
               "Symptoms, likely causes and what to do next."),
    },
    {
        "name": "07-linimasa",
        "label": {"id": "Riwayat", "en": "History"},
        "id": ("Riwayat perjalanan, isi BBM, dan servis",
               "Hitung km/L dan ingat jadwal ganti oli berikutnya."),
        "en": ("Trips, fuel and service history",
               "Track your km/L and never miss the next oil change."),
    },
    {
        # The real-adapter sheet would list the phone's bonded Bluetooth devices
        # (personal names), so the store set shows the simulator sheet instead.
        "name": "08-simulator",
        "label": {"id": "Mode simulator", "en": "Simulator mode"},
        "id": ("Coba semua fitur tanpa mobil",
               "Data contoh, termasuk mesin terlalu panas, aki lemah, dan lampu Check Engine."),
        "en": ("Try every feature without a car",
               "Sample data, including overheating, a weak battery and a Check Engine light."),
    },
]

FEATURE = {
    "id": ("Scanner OBD2 &amp; monitor kesehatan&nbsp;mobil",
           ["Skor kesehatan", "Kode kerusakan", "Data live", "Riwayat &amp; servis"]),
    "en": ("OBD2 scanner &amp; car health&nbsp;monitor",
           ["Health score", "Trouble codes", "Live data", "Trips &amp; service"]),
}

BASE_CSS = """
@font-face { font-family: InterX; src: url('{regular}'); font-weight: 400; }
@font-face { font-family: InterX; src: url('{semibold}'); font-weight: 600; }
@font-face { font-family: InterX; src: url('{bold}'); font-weight: 700; }
* { box-sizing: border-box; }
html, body { margin: 0; overflow: hidden; background: #0f1115; }
body { font-family: InterX, sans-serif; color: #eeeeee; -webkit-font-smoothing: antialiased; }
/* Calm direction chosen for the app: flat dark background, no glow, no
   gradients, one blue accent (colours from lib/core/theme). */
.bg { position: absolute; inset: 0; background: #0f1115; }
.eyebrow { color: #5aa2ff; font-weight: 600; letter-spacing: .4px; }
.phone { position: absolute; background: #05070a; border-radius: 64px; padding: 16px;
  border: 2px solid #262b33; box-shadow: 0 28px 56px rgba(0,0,0,.45); }
.phone img { display: block; width: 100%; border-radius: 50px; }
"""


def font_urls(font_dir: Path) -> dict[str, str]:
    urls = {}
    for weight, stem in (("regular", "Regular"), ("semibold", "SemiBold"), ("bold", "Bold")):
        for ext in ("otf", "ttf"):
            f = font_dir / f"Inter-{stem}.{ext}"
            if f.exists():
                urls[weight] = f.resolve().as_uri()
                break
        else:
            sys.exit(f"missing Inter-{stem}.otf/.ttf in {font_dir}")
    return urls


def css(fonts: dict[str, str]) -> str:
    return BASE_CSS.replace("{regular}", fonts["regular"]).replace(
        "{semibold}", fonts["semibold"]).replace("{bold}", fonts["bold"])


def chrome_render(page: Path, out: Path, width: int, height: int) -> None:
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
         "--force-device-scale-factor=1", "--allow-file-access-from-files",
         "--default-background-color=0f1115ff",
         f"--window-size={width},{height}", f"--screenshot={out}", page.as_uri()],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    with Image.open(out) as im:
        rgb = im.convert("RGB")
        if rgb.size != (width, height):
            rgb = rgb.crop((0, 0, width, height))
    rgb.save(out, optimize=True)


def crop_raw(raw: Path, out: Path) -> Path:
    with Image.open(raw) as im:
        if im.size != (1080, 2220):
            sys.exit(f"{raw}: expected 1080x2220, got {im.size}")
        cropped = im.convert("RGB").crop((0, STATUS_BAR_PX, 1080, 2220 - NAV_BAR_PX))
    small = cropped.resize((720, round(720 * cropped.height / cropped.width)), Image.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    small.save(out, optimize=True)
    return out


def framed(fonts, shot_png: Path, label: str, title: str, sub: str, page: Path,
           out: Path) -> None:
    page.write_text(f"""<!doctype html><html><head><meta charset="utf-8"><style>{css(fonts)}
html, body {{ width: 1080px; height: 1920px; }}
.cap {{ position: absolute; top: 96px; left: 84px; right: 84px; text-align: center; }}
.cap .eyebrow {{ font-size: 30px; margin: 0 0 20px; }}
.cap h1 {{ margin: 0 0 22px; font-size: 66px; line-height: 1.1; font-weight: 700; letter-spacing: -1.2px; }}
.cap p {{ margin: 0; font-size: 34px; line-height: 1.38; font-weight: 400; color: #aab0b9; }}
.phone {{ left: 170px; top: 540px; width: 740px; }}
</style></head><body><div class="bg"></div>
<div class="cap"><div class="eyebrow">{html.escape(label)}</div><h1>{html.escape(title)}</h1><p>{html.escape(sub)}</p></div>
<div class="phone"><img src="{shot_png.resolve().as_uri()}"></div>
</body></html>""", encoding="utf-8")
    chrome_render(page, out, 1080, 1920)


def feature_graphic(fonts, icon: Path, shot_png: Path, tagline: str, chips: list[str],
                    page: Path, out: Path, width: int, height: int, scale: float) -> None:
    s = scale
    chip_html = "".join(f'<span class="chip">{c}</span>' for c in chips)
    page.write_text(f"""<!doctype html><html><head><meta charset="utf-8"><style>{css(fonts)}
html, body {{ width: {width}px; height: {height}px; }}
.left {{ position: absolute; left: {round(64*s)}px; top: 50%; transform: translateY(-50%); width: {round(540*s)}px; }}
.brand {{ display: flex; align-items: center; gap: {round(20*s)}px; }}
.brand img {{ width: {round(92*s)}px; height: {round(92*s)}px; border-radius: {round(22*s)}px; }}
.brand h1 {{ margin: 0; font-size: {round(66*s)}px; font-weight: 700; letter-spacing: -1.5px; }}
.tag {{ margin: {round(22*s)}px 0 {round(26*s)}px; font-size: {round(29*s)}px; line-height: 1.25; font-weight: 600; color: #5aa2ff; }}
.chips {{ display: flex; flex-wrap: wrap; gap: {round(10*s)}px; }}
.chip {{ font-size: {round(19*s)}px; font-weight: 600; color: #cfd3d9; padding: {round(8*s)}px {round(14*s)}px;
  border-radius: 999px; background: #171a20; border: 1px solid #262b33; }}
.phone {{ right: {round(70*s)}px; top: {round(52*s)}px; width: {round(300*s)}px; padding: {round(9*s)}px; border-radius: {round(38*s)}px; }}
.phone img {{ border-radius: {round(30*s)}px; }}
</style></head><body><div class="bg"></div>
<div class="left"><div class="brand"><img src="{icon.resolve().as_uri()}"><h1>AutoCare</h1></div>
<div class="tag">{tagline}</div><div class="chips">{chip_html}</div></div>
<div class="phone"><img src="{shot_png.resolve().as_uri()}"></div>
</body></html>""", encoding="utf-8")
    chrome_render(page, out, width, height)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw", required=True, type=Path, help="folder with raw <name>.png captures")
    ap.add_argument("--fonts", type=Path, default=ROOT / "assets" / "fonts",
                    help="folder with Inter-Regular/SemiBold/Bold (.otf or .ttf)")
    args = ap.parse_args()

    fonts = font_urls(args.fonts)
    icon_src = ROOT / "assets" / "icon" / "app_icon.png"
    shots_dir = ROOT / "docs" / "screenshots"
    meta = ROOT / "fastlane" / "metadata" / "android"

    # Chrome reads the generated HTML pages from the gitignored build/ folder;
    # they are overwritten on every run.
    tmp = ROOT / "build" / "store_assets"
    tmp.mkdir(parents=True, exist_ok=True)
    cropped = {}
    for shot in SHOTS:
        raw = args.raw / f"{shot['name']}.png"
        if not raw.exists():
            print(f"skip {shot['name']}: no raw capture")
            continue
        cropped[shot["name"]] = crop_raw(raw, shots_dir / f"{shot['name']}.png")
    if not cropped:
        sys.exit("no raw captures found")

    for locale_dir, key in (("id", "id"), ("en-US", "en")):
        # Files are overwritten, never cleared: delete stale ones by hand if SHOTS shrinks.
        out_dir = meta / locale_dir / "images" / "phoneScreenshots"
        out_dir.mkdir(parents=True, exist_ok=True)
        n = 0
        for shot in SHOTS:
            if shot["name"] not in cropped:
                continue
            n += 1
            title, sub = shot[key]
            framed(fonts, cropped[shot["name"]], shot["label"][key], title, sub,
                       tmp / f"{key}-{n}.html",
                   out_dir / f"{n}_{shot['name']}.png")
        tagline, chips = FEATURE[key]
        hero = cropped.get("01-kesehatan") or next(iter(cropped.values()))
        feature_graphic(fonts, icon_src, hero, tagline, chips, tmp / f"{key}-feature.html",
                        meta / locale_dir / "images" / "featureGraphic.png", 1024, 500, 1.0)
        with Image.open(icon_src) as im:
            im.convert("RGBA").resize((512, 512), Image.LANCZOS).save(
                meta / locale_dir / "images" / "icon.png", optimize=True)
        print(f"{locale_dir}: {n} screenshots, feature graphic, icon")

    hero = cropped.get("01-kesehatan") or next(iter(cropped.values()))
    assets = ROOT / "docs" / "assets"
    assets.mkdir(parents=True, exist_ok=True)
    feature_graphic(fonts, icon_src, hero, FEATURE["id"][0], FEATURE["id"][1],
                    tmp / "social.html", assets / "social-preview.png", 1280, 640, 1.25)
    with Image.open(icon_src) as im:
        im.convert("RGBA").resize((192, 192), Image.LANCZOS).save(assets / "app-icon.png", optimize=True)
    print("docs: screenshots, social preview, app icon")


if __name__ == "__main__":
    main()
