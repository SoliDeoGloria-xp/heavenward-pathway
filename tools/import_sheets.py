#!/usr/bin/env python3
"""Turn raw generated monster and boss sheets into game sheets.

    python3 tools/import_sheets.py <raw_dir> [<raw_dir> ...]

Raw input (as delivered by the art generator): one PNG per animation named
<id>_idle.png, <id>_move.png, <id>_attack.png, <id>_hit_death.png; a single row of poses on a
painted checkerboard, any canvas size, no alpha.

Output, per <id> that has at least an idle sheet:
  assets/sprites/mobs/<id>.png   real alpha, one animation per row, every frame in an equal cell,
                                 feet on the cell's bottom edge, centred
  data/sprites.json              <id> -> {tex, hframes, vframes, height, anims, fps, missing}
The game reads data/sprites.json (see Combat._mob_actor), so new monsters need no code.
Requires Pillow, numpy and scipy.
"""
import json, re, sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from artkit import finish, HEIGHT, TIER_HEIGHT, PX_PER_UNIT

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "mobs"
ANIMS = ["idle", "move", "attack", "hit_death"]
# standing height in sheet pixels: the art bible's height for the tier at 48 px per world unit
BODY_H = {tier: round(HEIGHT[TIER_HEIGHT[tier]] * PX_PER_UNIT) for tier in TIER_HEIGHT}

# sheets used as scenery, not as a foe: their standing height in world units
SCENERY_HEIGHT = {"chained_lions": 2.2}

def game_heights() -> dict:
    """A creature the game draws taller than its tier (data/mobs.json "size") gets a sheet that
    tall, so no sprite is ever stretched past 48 px per unit."""
    mobs = json.loads((ROOT / "data" / "mobs.json").read_text())
    scale = float(json.loads((ROOT / "data" / "progression.json").read_text())["mob"]["greater_scale"])
    out: dict = {}
    for md in mobs.values():
        if isinstance(md, dict) and "sprite" in md:
            px = round(float(md.get("size", 1.0)) * (scale if md.get("greater") else 1.0) * PX_PER_UNIT)
            out[md["sprite"]] = max(out.get(md["sprite"], 0), px)
    return out
BG_MIN, BG_SPREAD = 178, 16        # checkerboard squares: bright and nearly grey
MIN_FRAME_MASS = 0.12              # a blob smaller than this share of the median frame is a stray particle
MAX_SHEET = 2048
MIN_PIECE = 0.6                    # no cut may leave a piece narrower than this share of a pose
SPLIT_WIDER_THAN = 1.7             # a run this many times the usual pose width is two poses touching
VALLEY_DEPTH = 0.38                # ...if a column between them is nearly empty
# A delivered action row is replaced by one generated from the idle poses when it is missing,
# could not be cut into clean poses, or shows a different-looking creature than the idle row.
MIN_LOOK_MATCH = 0.60              # colour-histogram overlap between a row's first pose and the idle pose
MAX_POSE_WIDTH = {"move": 1.55, "attack": 2.4, "hit_death": 1.6}   # widest pose, in idle-pose widths
# Rows judged by eye to show a different character than the idle row (the histogram cannot tell).
FORCE_GENERATED = {"giant_grim": ("move", "attack", "hit_death"), "simple_sloth_presumption": ("move", "attack", "hit_death"),
                   "sloth_greater": ("move", "attack", "hit_death")}


def cut_out(im: Image.Image) -> np.ndarray:
    """Checkerboard -> alpha. Only background connected to the border is removed, so light
    highlights inside a sprite survive."""
    rgb = np.asarray(im.convert("RGB")).astype(np.int16)
    bg_like = (rgb.min(axis=2) >= BG_MIN) & (rgb.max(axis=2) - rgb.min(axis=2) <= BG_SPREAD)
    labels, _ = ndimage.label(bg_like)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    outside = np.isin(labels, edge[edge != 0])
    outside = ndimage.binary_dilation(outside, iterations=1) & (bg_like | (rgb.min(axis=2) >= BG_MIN - 30))   # eat the pale fringe
    solid = ndimage.binary_opening(~outside, iterations=1)                                                     # drop specks
    rgba = np.dstack([rgb.astype(np.uint8), np.where(solid, 255, 0).astype(np.uint8)])
    return rgba

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

def frames_of(rgba: np.ndarray) -> list[np.ndarray]:
    """Split one row of poses. Columns with no pixels separate frames; stray particles join
    the nearest pose."""
    cols = (rgba[..., 3] > 0).sum(axis=0)
    runs, start = [], None
    for x, n in enumerate(list(cols) + [0]):
        if n and start is None:
            start = x
        elif not n and start is not None:
            runs.append([start, x]); start = None
    merged: list[list[int]] = []
    for r in runs:                                   # close hairline gaps inside one pose
        if merged and r[0] - merged[-1][1] < 6:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    mass = [int(cols[a:b].sum()) for a, b in merged]
    if not mass:
        return []
    typical = float(np.median(mass))
    keep: list[list[int]] = []
    for r, m in zip(merged, mass):
        if m < typical * MIN_FRAME_MASS and keep and r[0] - keep[-1][1] < 40:
            keep[-1][1] = r[1]                       # particle to the right of a pose
        elif m < typical * MIN_FRAME_MASS:
            continue
        else:
            keep.append(list(r))
    keep = split_touching(keep, cols)
    out = []
    for a, b in keep:
        part = rgba[:, a:b]
        rows = np.where((part[..., 3] > 0).any(axis=1))[0]
        out.append(part[rows[0]:rows[-1] + 1])
    return out

def split_touching(runs: list[list[int]], cols: np.ndarray) -> list[list[int]]:
    """Poses whose effects touch come out as one wide run. Cut such a run at the emptiest
    columns near where the pose boundaries should fall."""
    widths = sorted(b - a for a, b in runs)
    if len(runs) >= 3:
        typical = float(np.median(widths))
    else:                                            # nearly everything merged: find the pose count that cuts cleanest
        a, b = min(r[0] for r in runs), max(r[1] for r in runs)
        best = min(range(4, 8), key=lambda n: sum(int(cols[a + round((b - a) * i / n) - 6:a + round((b - a) * i / n) + 6].min()) for i in range(1, n)) / (n - 1))
        typical = (b - a) / best
        runs = [[a, b]]
    out: list[list[int]] = []
    for a, b in runs:
        n = max(2, round((b - a) / typical)) + 1
        if (b - a) < typical * SPLIT_WIDER_THAN:
            out.append([a, b]); continue
        # poses are dense columns, the effects joining them are thin: cut at the deepest thin
        # columns, keeping every piece at least most of a pose wide
        win = max(3, int(typical * 0.12))
        smooth = np.convolve(cols[a:b].astype(float), np.ones(win) / win, mode="same")
        peak = float(smooth.max())
        min_piece = typical * MIN_PIECE
        cuts = [a]
        for x in sorted(range(len(smooth)), key=lambda i: smooth[i]):
            if smooth[x] > peak * VALLEY_DEPTH or len(cuts) > n:
                break
            if all(abs(a + x - c) >= min_piece for c in cuts + [b]):
                cuts.append(a + x)
        cuts = sorted(cuts) + [b]
        out += [[cuts[i], cuts[i + 1]] for i in range(len(cuts) - 1)]
    return out

# ------------------------------------------------------------------ actions generated from the idle poses
def _look(im: Image.Image) -> np.ndarray:
    a = np.asarray(im).reshape(-1, 4)
    a = a[a[:, 3] > 0][:, :3] // 32
    h = np.bincount(a[:, 0] * 64 + a[:, 1] * 8 + a[:, 2], minlength=512).astype(float)
    return h / max(1.0, h.sum())

def needs_generating(name: str, anim: str, rows: dict) -> bool:
    if anim not in rows or anim in FORCE_GENERATED.get(name, ()):
        return True
    idle, row = rows["idle"], rows[anim]
    idle_w = float(np.median([f.width for f in idle]))
    if max(f.width for f in row) > idle_w * MAX_POSE_WIDTH[anim]:
        return True
    return float(np.minimum(_look(idle[0]), _look(row[0])).sum()) < MIN_LOOK_MATCH

def _pose(im: Image.Image, dx: float = 0, dy: float = 0, lean: float = 0.0, sx: float = 1.0, sy: float = 1.0, white: float = 0.0, alpha: float = 1.0) -> Image.Image:
    """One generated pose: the idle picture leaned (sheared from the feet), squashed, moved,
    whitened or faded. The feet stay on the bottom edge."""
    pad = int(im.height * 0.35) + 12
    w, h = im.width + pad * 2, im.height + pad
    src = Image.new("RGBA", (w, h), (0, 0, 0, 0)); src.alpha_composite(im, (pad, pad))
    cx, foot = w / 2.0, float(h)
    # output (x, y) -> source: undo move, squash about the feet, then shear about the feet
    a, b = 1.0 / sx, lean / sy
    c = cx - a * (cx + dx) - b * (foot + dy)
    e = 1.0 / sy
    f = foot - e * (foot + dy)
    out = src.transform((w, h), Image.AFFINE, (a, b, c, 0.0, e, f), Image.BICUBIC)
    px = np.asarray(out).astype(np.float32)
    if white:
        px[..., :3] = px[..., :3] * (1 - white) + 255 * white
    px[..., 3] *= alpha
    out = Image.fromarray(px.clip(0, 255).astype(np.uint8), "RGBA")
    box = out.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox() or (0, 0, 1, 1)
    return out.crop((box[0], box[1], box[2], h))

def _accent(im: Image.Image) -> tuple:
    """The creature's most vivid colour, for its strike arc and its death motes."""
    a = np.asarray(im).reshape(-1, 4).astype(np.int32)
    a = a[a[:, 3] > 200][:, :3]
    vivid = (a.max(axis=1) - a.min(axis=1)) * a.max(axis=1)
    r, g, b = a[np.argsort(vivid)[-max(1, len(a) // 40):]].mean(axis=0)
    return min(255, int(r * 0.85 + 60)), min(255, int(g * 0.85 + 60)), min(255, int(b * 0.85 + 60))

def gen_move(idle: list, u: float) -> list:
    steps = [(0, 0.05), (-2, 0.09), (-3, 0.04), (0, -0.05), (-2, -0.09), (-3, -0.04)]
    return [_pose(idle[i % len(idle)], dy=dy * u, lean=lean) for i, (dy, lean) in enumerate(steps)]

def gen_attack(idle: list, u: float) -> list:
    base = idle[0]
    frames = [_pose(base, dx=-4 * u, lean=-0.12), _pose(base, dx=7 * u, lean=0.20, sx=1.04), _pose(base, dx=9 * u, lean=0.24, sx=1.06),
              _pose(base, dx=5 * u, lean=0.12), _pose(base)]
    color = _accent(base)
    for i, strength in ((1, 150), (2, 235), (3, 110)):       # a crescent in front of the creature as the blow lands
        f = frames[i]
        size = int(base.height * 0.8)
        canvas = Image.new("RGBA", (f.width + size // 2, max(f.height, size)), (0, 0, 0, 0))
        canvas.alpha_composite(f, (0, canvas.height - f.height))
        arc = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        from PIL import ImageDraw
        d = ImageDraw.Draw(arc)
        x0, y0 = f.width - size // 2, canvas.height - size
        d.pieslice((x0, y0, x0 + size, y0 + size), -70, 60, fill=color + (strength,))
        d.ellipse((x0 - size * 0.22, y0 - size * 0.05, x0 + size * 0.78, y0 + size * 1.05), fill=(0, 0, 0, 0))
        canvas.alpha_composite(arc)
        frames[i] = canvas
    return frames

def gen_hit_death(idle: list, u: float) -> list:
    base = idle[0]
    frames = [_pose(base, dx=-4 * u, lean=-0.10, white=0.6), _pose(base, dx=-2 * u, lean=-0.05, white=0.25),
              _pose(base, sx=1.06, sy=0.8, alpha=0.92), _pose(base, sx=1.16, sy=0.55, alpha=0.7), _pose(base, sx=1.28, sy=0.3, alpha=0.4)]
    rng = np.random.default_rng(len(base.tobytes()) % 9973)
    w, h = max(8, int(base.width * 0.8)), max(8, int(base.height * 0.6))
    motes = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    from PIL import ImageDraw
    d = ImageDraw.Draw(motes)
    color = _accent(base)
    for _ in range(26):
        x, y, r = rng.uniform(0, w), h - abs(rng.normal(0, h * 0.4)), rng.uniform(1, 2.6) * u
        d.ellipse((x - r, y - r, x + r, y + r), fill=color + (int(rng.uniform(120, 230)),))
    return frames + [motes]

GENERATORS = {"move": gen_move, "attack": gen_attack, "hit_death": gen_hit_death}

def tier_of(name: str, boss: bool) -> str:
    if boss:
        return "boss"
    return next((t for t in ("common", "rare", "elite", "greater") if name.endswith("_" + t)), "common")

def build(name: str, files: dict[str, Path], boss: bool) -> dict:
    target = max(BODY_H[tier_of(name, boss)], game_heights().get(name, 0))
    if name in SCENERY_HEIGHT:
        target = round(SCENERY_HEIGHT[name] * PX_PER_UNIT)
    rows: dict[str, list[Image.Image]] = {}
    for anim in ANIMS:
        if anim not in files:
            continue
        frames = frames_of(clear_holes(cut_out(Image.open(files[anim]))))
        if not frames:
            continue
        # each raw file is drawn at its own size: the first pose of every row is a standing one,
        # so scaling it to the same height keeps the creature the same size across animations
        ref_h = frames[0].shape[0] if anim != "hit_death" else max(f.shape[0] for f in frames[:2])
        k = target / ref_h
        rows[anim] = [Image.fromarray(f, "RGBA").resize((max(1, round(f.shape[1] * k)), max(1, round(f.shape[0] * k))), Image.LANCZOS) for f in frames]
    generated = []
    for anim in ANIMS[1:]:
        if needs_generating(name, anim, rows):
            rows[anim] = GENERATORS[anim](rows["idle"], target / 72.0)
            generated.append(anim)
    rows = {a: rows[a] for a in ANIMS}
    cols = max(len(r) for r in rows.values())
    cw = max(f.width for r in rows.values() for f in r) + 4
    ch = max(f.height for r in rows.values() for f in r) + 2
    shrink = min(1.0, MAX_SHEET / (cw * cols), MAX_SHEET / (ch * len(rows)))
    if shrink < 1.0:
        rows = {a: [f.resize((max(1, int(f.width * shrink)), max(1, int(f.height * shrink))), Image.LANCZOS) for f in r] for a, r in rows.items()}
        cw, ch, target = int(cw * shrink) + 1, int(ch * shrink) + 1, int(target * shrink)
    sheet = Image.new("RGBA", (cw * cols, ch * len(rows)), (0, 0, 0, 0))
    anims: dict[str, list[int]] = {}
    for r, (anim, frames) in enumerate(rows.items()):
        idx = []
        for c, f in enumerate(frames):
            sheet.alpha_composite(f, (c * cw + (cw - f.width) // 2, r * ch + ch - f.height))
            idx.append(r * cols + c)
        if anim == "idle": anims["idle"] = idx
        elif anim == "move": anims["walk"] = idx
        elif anim == "attack": anims["attack"] = idx
        else:
            anims["hurt"] = idx[:2] if len(idx) > 3 else idx[:1]
            anims["die"] = idx[2:] if len(idx) > 3 else idx[1:]
    for need, fallback in (("walk", "idle"), ("attack", "walk"), ("hurt", "idle"), ("die", "idle")):
        anims.setdefault(need, anims[fallback][:1] if need in ("hurt", "die") else anims[fallback])
    OUT.mkdir(parents=True, exist_ok=True)
    finish(sheet, cells=(cols, len(rows))).save(OUT / f"{name}.png", optimize=True)     # palette, outline, light: the art bible
    return {"tex": f"res://assets/sprites/mobs/{name}.png", "hframes": cols, "vframes": len(rows), "height": target, "cell": [cw, ch],
            "anims": anims, "generated": generated}

def main() -> int:
    table_path = ROOT / "data" / "sprites.json"
    table = json.loads(table_path.read_text()) if table_path.exists() else {}
    sets: dict[str, dict[str, Path]] = {}
    boss_ids = set()
    for d in sys.argv[1:]:
        for f in sorted(Path(d).rglob("*.png")):
            m = re.fullmatch(r"(.+)_(idle|move|attack|hit_death)", f.stem)
            if m:
                sets.setdefault(m.group(1), {})[m.group(2)] = f
                if "boss" in str(f.parent).lower():
                    boss_ids.add(m.group(1))
    for name, files in sorted(sets.items()):
        if "idle" not in files:
            print(f"skip {name}: no idle sheet"); continue
        table[name] = build(name, files, name in boss_ids)
        info = table[name]
        print(f"{name:28s} {info['hframes']}x{info['vframes']} cells {info['cell'][0]}x{info['cell'][1]}" + (f"  generated: {', '.join(info['generated'])}" if info["generated"] else ""))
    table_path.write_text(json.dumps(dict(sorted(table.items())), indent=1) + "\n")
    return 0

if __name__ == "__main__":
    sys.exit(main())
