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

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "mobs"
ANIMS = ["idle", "move", "attack", "hit_death"]
BODY_H = {"common": 72, "rare": 78, "elite": 84, "greater": 96, "boss": 136}   # standing height in sheet pixels
BG_MIN, BG_SPREAD = 178, 16        # checkerboard squares: bright and nearly grey
MIN_FRAME_MASS = 0.12              # a blob smaller than this share of the median frame is a stray particle
MAX_SHEET = 2048
MIN_PIECE = 0.6                    # no cut may leave a piece narrower than this share of a pose
SPLIT_WIDER_THAN = 1.7             # a run this many times the usual pose width is two poses touching
VALLEY_DEPTH = 0.38                # ...if a column between them is nearly empty
# Raw rows whose poses overlap too much to cut cleanly: play another row instead until re-drawn.
REVIEW_FALLBACK = {"simple_sloth_presumption": {"walk": "idle", "attack": "idle"}, "sloth_greater": {"attack": "walk"},
                   "great_red_dragon": {"walk": "idle", "attack": "idle"}}
FPS = {"idle": 4.0, "walk": 8.0, "attack": 9.0, "hurt": 8.0, "die": 7.0}

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

def tier_of(name: str, boss: bool) -> str:
    if boss:
        return "boss"
    return next((t for t in ("common", "rare", "elite", "greater") if name.endswith("_" + t)), "common")

def build(name: str, files: dict[str, Path], boss: bool) -> dict:
    target = BODY_H[tier_of(name, boss)]
    rows: dict[str, list[Image.Image]] = {}
    for anim in ANIMS:
        if anim not in files:
            continue
        frames = frames_of(cut_out(Image.open(files[anim])))
        if not frames:
            continue
        # each raw file is drawn at its own size: the first pose of every row is a standing one,
        # so scaling it to the same height keeps the creature the same size across animations
        ref_h = frames[0].shape[0] if anim != "hit_death" else max(f.shape[0] for f in frames[:2])
        k = target / ref_h
        rows[anim] = [Image.fromarray(f, "RGBA").resize((max(1, round(f.shape[1] * k)), max(1, round(f.shape[0] * k))), Image.LANCZOS) for f in frames]
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
    for anim, use in REVIEW_FALLBACK.get(name, {}).items():
        anims[anim] = anims[use]
    for need, fallback in (("walk", "idle"), ("attack", "walk"), ("hurt", "idle"), ("die", "idle")):
        anims.setdefault(need, anims[fallback][:1] if need in ("hurt", "die") else anims[fallback])
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT / f"{name}.png", optimize=True)
    return {"tex": f"res://assets/sprites/mobs/{name}.png", "hframes": cols, "vframes": len(rows), "height": target, "cell": [cw, ch],
            "anims": anims, "fps": FPS, "missing": [a for a in ANIMS if a not in rows]}

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
        print(f"{name:28s} {info['hframes']}x{info['vframes']} cells {info['cell'][0]}x{info['cell'][1]}" + (f"  MISSING {info['missing']}" if info["missing"] else ""))
    table_path.write_text(json.dumps(dict(sorted(table.items())), indent=1) + "\n")
    return 0

if __name__ == "__main__":
    sys.exit(main())
