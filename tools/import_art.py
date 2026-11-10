#!/usr/bin/env python3
"""Clean single-image art (icons, standing NPCs, props) from a raw generated pack.

    python3 tools/import_art.py <raw_dir>

Raw input: PNGs on a painted checkerboard at the generator's canvas size. Each picture is cut
out (real alpha, enclosed checkerboard holes included), cropped, and fitted WITHOUT stretching:
  <raw>/icons/*.png      -> assets/icons/<name>.png          64x64
  *_npc.png, *_variant   -> assets/sprites/npc/<name>.png    64x96 cell, body 84 px, feet on the bottom edge
  other pictures         -> assets/props/<name>.png          longest side 384
Skipped and reported: "*_tile" (not seamless), UI frames/buttons/bars (need 9-slice work).
Names follow the locked glossary (RENAMES). Requires Pillow, numpy, scipy.
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from import_sheets import cut_out, clear_holes, BG_MIN, _pose
from artkit import finish, HEIGHT, PX_PER_UNIT, NAMES, RGB

ROOT = Path(__file__).resolve().parent.parent
RENAMES = {"marksman_npc": "watcher_npc", "marksman_aim": "arrow_of_truth", "virtue_gem": "fruit_stone", "oil_flask": "honey_from_the_rock",
           "faithfulness_heart": "fruit_love", "faithfulness": "fruit_faithfulness", "patience_candle": "fruit_patience", "edge_of_word": "edge_of_the_word",
           "shepherd_variant": "shepherdess_npc"}
SKIP_WORDS = ("_frame", "_button", "_slot", "_bar")
# How tall each delivered scene stands in the world, in units (x48 = pixels); others keep 8 units on the long side.
PROP_UNITS = {"wicket_gate": 4.4, "palace_beautiful": 10.0, "interpreter_house": 7.0, "celestial_gate": 9.0, "doubting_castle": 9.0, "hill_of_difficulty": 8.0,
              "valley_of_shadow": 7.0, "delectable_ridge": 6.0, "floating_isle": 6.0, "radiant_spire": 9.0, "vanity_fair_square": 5.0, "vanity_fair_stall": 3.4,
              "wooden_bridge": 1.8, "palace_interior": 5.0, "forest_edge": 5.0, "crystal_cavern": 2.6, "city_wall": 2.6, "meadow": 1.2, "eden_grass": 1.6,
              "stone_path": 1.2, "town_square": 3.0, "river_edge": 3.0, "hill_path": 3.0, "valley_path": 5.0, "inventory_bag": 1.0}
ICON, PROP_MAX, PAD = 64, 384, 2
# Playable looks: the pilgrim (two looks at character creation) and one per Calling. Each becomes a
# sheet on the character contract's layout, 10 columns x 5 rows (idle, walk 1-4, attack 1-2, sit,
# rest/KO, cast), at 64x96 per cell. Only a front pose was delivered, so every direction row
# repeats it (the game mirrors left/right) and the actions are generated from that pose.
PLAYABLE = {"pilgrim_npc": "pilgrim", "shepherd_variant": "pilgrim_b", "valiant_npc": "valiant", "marksman_npc": "watcher", "interpreter_npc": "expositor",
            "shepherd_npc": "shepherd", "steward_npc": "steward", "wayfarer_npc": "wayfarer", "faithful_npc": "faithful", "hopeful_npc": "hopeful"}
CELL_W, CELL_H, BODY = 64, 96, round(HEIGHT["pilgrim"] * PX_PER_UNIT)   # 84 px: 1.75 world units
ELDERS = ("evangelist_npc", "interpreter_npc")   # drawn young; the story needs old men, so their hair is greyed
HAIR_BAND = 0.42                                 # hair lies in the top part of a standing figure

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
    return finish(sheet, cells=(10, 5))

def stand(im: Image.Image) -> Image.Image:
    """A standing character in the same cell and at the same height as the player: feet on the bottom edge."""
    k = min(BODY / im.height, (CELL_W - 4) / im.width)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    cell.alpha_composite(im, ((CELL_W - im.width) // 2, CELL_H - im.height))
    return finish(cell)

# Other pilgrims on the road: the two delivered pilgrims with their robes re-dyed. Each swap moves
# one palette ramp onto another, so the result is still palette-only.
FOLK_DYES = [("umber", "bark", "oak"), ("deep", "royal", "sky"), ("pine", "moss", "leaf"), ("plum", "violet", "lilac"), ("slate", "iron", "stone"), ("wine", "crimson", "ember")]

def dye(im: Image.Image, src: tuple, dst: tuple) -> Image.Image:
    px = np.asarray(im.convert("RGBA")).copy()
    for a, b in zip(src, dst):
        ca, cb = RGB[NAMES.index(a)].astype(np.uint8), RGB[NAMES.index(b)].astype(np.uint8)
        px[(px[..., :3] == ca).all(axis=2) & (px[..., 3] > 0), :3] = cb
    return Image.fromarray(px, "RGBA")

def folk_sheets() -> int:
    player = ROOT / "assets" / "sprites" / "player"
    n = 0
    for base in ("pilgrim", "pilgrim_b"):
        im = Image.open(player / f"{base}.png")
        for d in (FOLK_DYES if base == "pilgrim" else (FOLK_DYES[0], FOLK_DYES[4])):     # the second pilgrim's hair shares the robe's ramp
            dye(im, FOLK_DYES[0], d).save(player / f"folk_{n}.png", optimize=True); n += 1
    return n

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
        if f.stem == "interpreter_npc":     # the Dreamer: the same elder, grey-haired, in a plain brown robe
            dye(player_sheet(grey_hair(im)), FOLK_DYES[5], FOLK_DYES[0]).save(ROOT / "assets" / "sprites" / "player" / "dreamer.png", optimize=True)
        if f.parent.name == "icons":
            out, im = ROOT / "assets" / "icons" / f"{stem}.png", finish(fit(im, ICON, ICON, False), ramp=False)
        elif stem.endswith("_npc"):
            if stem in ELDERS:
                im = grey_hair(im)
            out, im = ROOT / "assets" / "sprites" / "npc" / f"{stem[:-4]}.png", stand(im)
        else:
            stem = stem[:-5] if stem.endswith("_tile") else stem       # the pack's "tiles" are scenes, not seamless tiles
            k = PROP_UNITS[stem] * PX_PER_UNIT / im.height if stem in PROP_UNITS else min(1.0, PROP_MAX / max(im.size))
            out, im = ROOT / "assets" / "props" / f"{stem}.png", finish(im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS), ramp=False)
        if out.exists() and f.parent.name == "icons" and stem == f.stem and (ROOT / "tools" / "gen_assets.py").read_text().find(f'"{stem}"') >= 0:
            out = out.with_name(f"p1_{stem}.png")      # never overwrite a generated placeholder of the same name
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out, optimize=True)
        done.append(out.relative_to(ROOT).as_posix())
    print(f"import_art: {folk_sheets()} road-folk sheets")
    print(f"import_art: {len(done)} cleaned, {len(skipped)} skipped: {', '.join(skipped)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
