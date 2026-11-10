#!/usr/bin/env python3
"""Paint the far skylines used behind maps (assets/props/bd_*.png, 1024x256, real alpha).

    python3 tools/gen_backdrops.py

Layered silhouettes drawn from seeded noise. They are tinted per map by the "tint" of the
billboard prop, so one picture serves several palettes. Replace any file with painted art of
the same name and size.
"""
from pathlib import Path
import numpy as np
from PIL import Image

W, H = 1024, 256
OUT = Path(__file__).resolve().parent.parent / "assets" / "props"

def ridge(rng, base, rough, peaks):
    x = np.linspace(0, 1, W)
    y = np.zeros(W)
    for octave, amp in enumerate([1.0, 0.5, 0.25, 0.12]):
        n = peaks * 2 ** octave
        pts = rng.uniform(-1, 1, n + 2)
        y += amp * np.interp(x * n, np.arange(n + 2), pts)
    y = base + rough * y
    edge = np.minimum(x, 1 - x) * 6          # sink toward both ends so the picture has no hard sides
    return y * np.clip(edge, 0, 1)

def layers(seed, specs, deco=None):
    rng = np.random.default_rng(seed)
    px = np.zeros((H, W, 4), np.float32)
    rows = np.arange(H)[:, None]
    for base, rough, peaks, color in specs:
        top = H - ridge(rng, base, rough, peaks) * H
        mask = rows >= top[None, :]
        shade = np.clip(1.0 - (rows - top[None, :]) / (H * 0.9), 0.55, 1.0)       # lighter at the crest
        for c in range(3):
            px[..., c] = np.where(mask, color[c] * shade, px[..., c])
        px[..., 3] = np.where(mask, 255, px[..., 3])
        if deco:
            deco(rng, px, top, color)
    return Image.fromarray(px.clip(0, 255).astype(np.uint8), "RGBA")

def towers(rng, px, top, color):
    for _ in range(26):
        x = int(rng.uniform(60, W - 60)); wdt = int(rng.uniform(8, 26)); hgt = int(rng.uniform(20, 90))
        y0 = int(top[x]) - hgt
        px[max(0, y0):int(top[x]) + 2, x:x + wdt, :3] = [c * 0.8 for c in color]; px[max(0, y0):int(top[x]) + 2, x:x + wdt, 3] = 255
        if rng.random() < 0.5:                                                        # a lit window
            px[max(0, y0) + 8:max(0, y0) + 12, x + wdt // 2 - 1:x + wdt // 2 + 2, :3] = (255, 150, 60)

def spikes(rng, px, top, color):
    for _ in range(40):
        x = int(rng.uniform(40, W - 40)); hgt = int(rng.uniform(20, 110)); half = int(rng.uniform(5, 14))
        for dy in range(hgt):
            wv = max(1, int(half * (dy / hgt)))
            y = int(top[x]) - hgt + dy
            if 0 <= y < H:
                px[y, x - wv:x + wv, :3] = [c * 0.75 for c in color]; px[y, x - wv:x + wv, 3] = 255

SETS = {
    "bd_mountains": (11, [(0.62, 0.22, 5, (150, 160, 190)), (0.44, 0.16, 7, (110, 124, 150)), (0.26, 0.10, 9, (80, 96, 110))], None),
    "bd_hills": (12, [(0.40, 0.10, 3, (150, 180, 150)), (0.26, 0.07, 4, (118, 152, 116)), (0.14, 0.05, 6, (90, 124, 88))], None),
    "bd_city": (13, [(0.30, 0.05, 4, (70, 62, 78)), (0.16, 0.04, 6, (48, 42, 56))], towers),
    "bd_crags": (14, [(0.42, 0.20, 8, (60, 58, 80)), (0.22, 0.12, 10, (36, 34, 52))], spikes),
}

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (seed, specs, deco) in SETS.items():
        layers(seed, specs, deco).save(OUT / f"{name}.png", optimize=True)
    print(f"gen_backdrops: wrote {len(SETS)} skylines")

if __name__ == "__main__":
    main()
