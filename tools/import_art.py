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
from import_sheets import cut_out, BG_MIN, _pose

ROOT = Path(__file__).resolve().parent.parent
RENAMES = {"marksman_npc": "watcher_npc", "marksman_aim": "arrow_of_truth", "virtue_gem": "fruit_stone", "oil_flask": "honey_from_the_rock",
           "faithfulness_heart": "fruit_love", "faithfulness": "fruit_faithfulness", "patience_candle": "fruit_patience", "edge_of_word": "edge_of_the_word",
           "shepherd_variant": "shepherdess_npc"}
SKIP_WORDS = ("_tile", "_frame", "_button", "_slot", "_bar")
ICON, NPC, PROP_MAX, PAD = 64, 96, 384, 2
HOLE_MIN_AREA = 120
# Playable looks: the pilgrim (two looks at character creation) and one per Calling. Each becomes a
# sheet on the character contract's layout, 10 columns x 5 rows (idle, walk 1-4, attack 1-2, sit,
# rest/KO, cast), at 64x96 per cell. Only a front pose was delivered, so every direction row
# repeats it (the game mirrors left/right) and the actions are generated from that pose.
PLAYABLE = {"pilgrim_npc": "pilgrim", "shepherd_variant": "pilgrim_b", "valiant_npc": "valiant", "marksman_npc": "watcher", "interpreter_npc": "expositor",
            "shepherd_npc": "shepherd", "steward_npc": "steward", "wayfarer_npc": "wayfarer", "faithful_npc": "faithful", "hopeful_npc": "hopeful"}
CELL_W, CELL_H, BODY = 64, 96, 84
ELDERS = ("evangelist_npc", "interpreter_npc")   # drawn young; the story needs old men, so their hair is greyed
HAIR_BAND = 0.42                                 # hair lies in the top part of a standing figure

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

def grey_hair(im: Image.Image) -> Image.Image:
    """Turn brown hair silver: brown pixels in the head band keep their shading but lose their colour."""
    px = np.asarray(im).astype(np.float32)
    r, g, b, a = px[..., 0], px[..., 1], px[..., 2], px[..., 3]
    v = px[..., :3].max(axis=2); spread = v - px[..., :3].min(axis=2)
    band = np.zeros(a.shape, bool); band[: int(im.height * HAIR_BAND)] = True
    skin = (r > 200) & (g > 150)                                   # light warm tones are the face
    brown = band & (a > 0) & (r > g) & (g > b) & (spread > 35) & (v > 60) & ~skin
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    silver = np.clip(lum * 1.25 + 70, 0, 245)
    for ch, tint in enumerate((1.0, 1.0, 1.03)):
        px[..., ch] = np.where(brown, np.clip(silver * tint, 0, 255), px[..., ch])
    return Image.fromarray(px.astype(np.uint8), "RGBA")

def player_sheet(im: Image.Image) -> Image.Image:
    k = min(BODY / im.height, (CELL_W - 14) / im.width)
    base = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    lying = base.rotate(90, expand=True)
    poses = [base, _pose(base, dy=-1, lean=0.05), _pose(base, dy=-3, lean=0.02), _pose(base, dy=-1, lean=-0.05), _pose(base, dy=-3, lean=-0.02),
             _pose(base, dx=-3, lean=-0.10), _pose(base, dx=5, lean=0.16, sx=1.03), _pose(base, sy=0.74, sx=1.06), lying, _pose(base, dy=-2, lean=-0.04, white=0.22)]
    sheet = Image.new("RGBA", (CELL_W * 10, CELL_H * 5), (0, 0, 0, 0))
    for row in range(5):
        for col, p in enumerate(poses):
            if p.width > CELL_W or p.height > CELL_H:
                p = p.copy(); p.thumbnail((CELL_W, CELL_H), Image.LANCZOS)
            sheet.alpha_composite(p, (col * CELL_W + (CELL_W - p.width) // 2, row * CELL_H + CELL_H - p.height))
    return sheet

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
        if f.stem in PLAYABLE:
            dest = ROOT / "assets" / "sprites" / "player" / f"{PLAYABLE[f.stem]}.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            player_sheet(im).save(dest, optimize=True)
        if f.parent.name == "icons":
            out, im = ROOT / "assets" / "icons" / f"{stem}.png", fit(im, ICON, ICON, False)
        elif stem.endswith("_npc"):
            if stem in ELDERS:
                im = grey_hair(im)
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
