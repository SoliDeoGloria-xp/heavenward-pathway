#!/usr/bin/env python3
"""Clean single-image art (icons, standing NPCs, props) from a raw generated pack.

    python3 tools/import_art.py <raw_dir>

Raw input: PNGs on a painted checkerboard at the generator's canvas size. Each picture is cut
out (real alpha, enclosed checkerboard holes included), cropped, and fitted WITHOUT stretching:
  <raw>/icons/*.png      -> assets/icons/<name>.png          64x64
  *_npc.png, *_variant   -> assets/sprites/npc/<name>.png    96x96, feet at bottom centre
  other pictures         -> assets/props/<name>.png          longest side 384
Skipped and reported: "*_tile" (not seamless), UI frames/buttons/bars (need 9-slice work).
Names follow the locked glossary (RENAMES). Requires Pillow, numpy, scipy.
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from import_sheets import cut_out, BG_MIN

ROOT = Path(__file__).resolve().parent.parent
RENAMES = {"marksman_npc": "watcher_npc", "marksman_aim": "arrow_of_truth", "virtue_gem": "fruit_stone", "oil_flask": "honey_from_the_rock",
           "faithfulness_heart": "fruit_love", "faithfulness": "fruit_faithfulness", "patience_candle": "fruit_patience", "edge_of_word": "edge_of_the_word",
           "shepherd_variant": "shepherdess_npc"}
SKIP_WORDS = ("_tile", "_frame", "_button", "_slot", "_bar")
ICON, NPC, PROP_MAX, PAD = 64, 96, 384, 2
HOLE_MIN_AREA = 120

def clear_holes(rgba: np.ndarray) -> np.ndarray:
    """Checkerboard seen through a ring or a bow is enclosed, so the border flood misses it.
    An enclosed pale region that holds both white and grey squares is checkerboard."""
    rgb = rgba[..., :3].astype(np.int16)
    pale = (rgb.min(axis=2) >= BG_MIN) & (rgb.max(axis=2) - rgb.min(axis=2) <= 16) & (rgba[..., 3] > 0)
    labels, n = ndimage.label(pale)
    for i in range(1, n + 1):
        region = labels == i
        if region.sum() < HOLE_MIN_AREA:
            continue
        v = rgb[region].min(axis=1)
        if (v >= 248).mean() > 0.15 and (v <= 240).mean() > 0.15:
            rgba[region, 3] = 0
    return rgba

def fit(im: Image.Image, w: int, h: int, bottom: bool) -> Image.Image:
    k = min((w - PAD * 2) / im.width, (h - PAD * 2) / im.height)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((w - im.width) // 2, h - im.height - PAD if bottom else (h - im.height) // 2))
    return canvas

def main() -> int:
    raw = Path(sys.argv[1])
    done, skipped = [], []
    for f in sorted(raw.rglob("*.png")):
        stem = RENAMES.get(f.stem, f.stem)
        if any(wd in f.stem for wd in SKIP_WORDS):
            skipped.append(f.stem); continue
        rgba = clear_holes(cut_out(Image.open(f)))
        ys, xs = np.where(rgba[..., 3] > 0)
        if len(ys) == 0:
            skipped.append(f.stem); continue
        im = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")
        if f.parent.name == "icons":
            out, im = ROOT / "assets" / "icons" / f"{stem}.png", fit(im, ICON, ICON, False)
        elif stem.endswith("_npc"):
            out, im = ROOT / "assets" / "sprites" / "npc" / f"{stem[:-4]}.png", fit(im, NPC, NPC, True)
        else:
            k = min(1.0, PROP_MAX / max(im.size))
            out, im = ROOT / "assets" / "props" / f"{stem}.png", im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        if out.exists() and f.parent.name == "icons" and stem == f.stem and (ROOT / "tools" / "gen_assets.py").read_text().find(f'"{stem}"') >= 0:
            out = out.with_name(f"p1_{stem}.png")      # never overwrite a generated placeholder of the same name
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out, optimize=True)
        done.append(out.relative_to(ROOT).as_posix())
    print(f"import_art: {len(done)} cleaned, {len(skipped)} skipped: {', '.join(skipped)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
