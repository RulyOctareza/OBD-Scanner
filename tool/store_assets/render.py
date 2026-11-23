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
        "id": ("Skor kesehatan mobil, langsung dari mesin",
               "Suhu, aki, kode error, dan jadwal oli dirangkum jadi satu skor."),
        "en": ("Your car's health at a glance",
               "Coolant, battery, trouble codes and oil schedule in one live score."),
    },
    {
        "name": "02-meter",
        "id": ("Meter kokpit yang bisa kamu atur",
               "Putaran mesin, kecepatan, Trip A dan B, plus petunjuk Hemat."),
        "en": ("A cockpit you can customise",
               "Engine speed, vehicle speed, Trip A and B, plus an economy hint."),
    },
    {
        "name": "03-sensor",
        "id": ("Semua sensor penting dalam satu layar",
               "Suhu, tegangan aki, MAP, MAF, beban mesin, dan lainnya."),
        "en": ("Every key sensor on one screen",
               "Temperatures, battery voltage, MAP, MAF, engine load and more."),
    },
    {
        "name": "04-grafik",
        "id": ("Grafik riwayat tiap sensor",
               "Tren 1 menit sampai 1 jam, lengkap dengan puncak dan rata-rata."),
        "en": ("A history chart for every sensor",
               "Trends from 1 minute to 1 hour, with peak and average."),
    },
    {
        "name": "05-diagnostik",
        "id": ("Baca dan hapus kode Check Engine",
               "DTC aktif, pending, dan permanen, plus status kesiapan emisi."),
        "en": ("Read and clear Check Engine codes",
               "Active, pending and permanent DTCs, plus emission readiness."),
    },
    {
        "name": "06-kamus-dtc",
        "id": ("Arti kode error, dalam Bahasa Indonesia",
               "Gejala, kemungkinan penyebab, dan rekomendasi tindakan."),
        "en": ("Trouble codes, explained",
               "Symptoms, likely causes and what to do next."),
    },
    {
        "name": "07-linimasa",
        "id": ("Riwayat perjalanan, BBM, dan servis",
               "Hitung km/L dan ingat jadwal ganti oli berikutnya."),
        "en": ("Trips, fuel and service history",
               "Track your km/L and never miss the next oil change."),
    },
    {
        # The real-adapter sheet would list the phone's bonded Bluetooth devices
        # (personal names), so the store set shows the simulator sheet instead.
        "name": "08-simulator",
        "id": ("Coba semua fitur tanpa mobil",
               "Mode Simulator memakai data demo: overheat, aki lemah, Check Engine."),
        "en": ("Try every feature without a car",
               "Simulator Mode uses demo data: overheating, weak battery, Check Engine."),
    },
]

FEATURE = {
    "id": ("Scanner OBD2 &amp; monitor kesehatan mobil",
           ["Skor kesehatan", "Kode Check Engine", "Live data", "Trip &amp; servis"]),
    "en": ("OBD2 scanner &amp; car health monitor",
           ["Health score", "Check Engine codes", "Live data", "Trips &amp; service"]),
}

BASE_CSS = """
@font-face { font-family: InterX; src: url('{regular}'); font-weight: 400; }
@font-face { font-family: InterX; src: url('{semibold}'); font-weight: 600; }
@font-face { font-family: InterX; src: url('{bold}'); font-weight: 700; }
* { box-sizing: border-box; }
html, body { margin: 0; overflow: hidden; background: #0f1115; }
body { font-family: InterX, sans-serif; color: #eeeeee; -webkit-font-smoothing: antialiased; }
.bg { position: absolute; inset: 0;
  background:
    radial-gradient(60% 40% at 85% 0%, rgba(47,128,237,.38), transparent 70%),
    radial-gradient(55% 35% at 0% 100%, rgba(34,197,94,.20), transparent 70%),
    linear-gradient(180deg, #11141a 0%, #0b0d11 100%); }
.grid { position: absolute; inset: 0; opacity: .35;
  background-image:
    linear-gradient(rgba(255,255,255,.035) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,.035) 1px, transparent 1px);
  background-size: 56px 56px; }
.phone { position: absolute; background: #05070a; border-radius: 64px; padding: 16px;
  box-shadow: 0 50px 100px rgba(0,0,0,.65), 0 0 0 2px rgba(255,255,255,.10) inset,
              0 0 120px rgba(47,128,237,.18); }
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


def framed(fonts, shot_png: Path, title: str, sub: str, page: Path, out: Path) -> None:
    page.write_text(f"""<!doctype html><html><head><meta charset="utf-8"><style>{css(fonts)}
html, body {{ width: 1080px; height: 1920px; }}
.cap {{ position: absolute; top: 118px; left: 84px; right: 84px; text-align: center; }}
.cap h1 {{ margin: 0 0 24px; font-size: 70px; line-height: 1.1; font-weight: 700; letter-spacing: -1.2px; }}
.cap p {{ margin: 0; font-size: 36px; line-height: 1.38; font-weight: 400; color: #aab0b9; }}
.phone {{ left: 170px; top: 520px; width: 740px; }}
</style></head><body><div class="bg"></div><div class="grid"></div>
<div class="cap"><h1>{html.escape(title)}</h1><p>{html.escape(sub)}</p></div>
<div class="phone"><img src="{shot_png.resolve().as_uri()}"></div>
</body></html>""", encoding="utf-8")
    chrome_render(page, out, 1080, 1920)


def feature_graphic(fonts, icon: Path, shot_png: Path, tagline: str, chips: list[str],
                    page: Path, out: Path, width: int, height: int, scale: float) -> None:
    s = scale
    chip_html = "".join(f'<span class="chip">{c}</span>' for c in chips)
    page.write_text(f"""<!doctype html><html><head><meta charset="utf-8"><style>{css(fonts)}
html, body {{ width: {width}px; height: {height}px; }}
.left {{ position: absolute; left: {round(64*s)}px; top: 50%; transform: translateY(-50%); width: {round(600*s)}px; }}
.brand {{ display: flex; align-items: center; gap: {round(20*s)}px; }}
.brand img {{ width: {round(92*s)}px; height: {round(92*s)}px; border-radius: {round(22*s)}px; box-shadow: 0 10px 30px rgba(0,0,0,.5); }}
.brand h1 {{ margin: 0; font-size: {round(66*s)}px; font-weight: 700; letter-spacing: -1.5px; }}
.tag {{ margin: {round(22*s)}px 0 {round(26*s)}px; font-size: {round(29*s)}px; line-height: 1.25; font-weight: 600;
  background: linear-gradient(90deg, #6aa6ff, #22c55e); -webkit-background-clip: text; color: transparent; }}
.chips {{ display: flex; flex-wrap: wrap; gap: {round(10*s)}px; }}
.chip {{ font-size: {round(19*s)}px; font-weight: 600; color: #cfd3d9; padding: {round(8*s)}px {round(14*s)}px;
  border-radius: 999px; background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.10); }}
.phone {{ right: {round(70*s)}px; top: {round(52*s)}px; width: {round(300*s)}px; padding: {round(9*s)}px; border-radius: {round(38*s)}px; }}
.phone img {{ border-radius: {round(30*s)}px; }}
</style></head><body><div class="bg"></div><div class="grid"></div>
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
            framed(fonts, cropped[shot["name"]], title, sub, tmp / f"{key}-{n}.html",
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
