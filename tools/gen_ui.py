#!/usr/bin/env python3
"""Draw the interface frames (assets/ui/*.png) by the art bible: the palette's gold and parchment,
an ink outline, light from the upper left. Every panel is a 9-slice: corners keep their size,
edges and centre stretch, so one small picture frames a window of any size.

    python3 tools/gen_ui.py

Margins used by the game are in scripts/ui/ui_kit.gd (UIKit.sb). Requires Pillow and numpy.
"""
from pathlib import Path
import numpy as np
from PIL import Image
import artkit as ak

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"
C = {n: ak.rgb(n) + (255,) for n in ak.NAMES}
CLEAR = (0, 0, 0, 0)

def canvas(w: int, h: int) -> np.ndarray:
    return np.zeros((h, w, 4), dtype=np.uint8)

def save(name: str, px: np.ndarray) -> None:
    Image.fromarray(px, "RGBA").save(OUT / f"{name}.png", optimize=True)

def panel(w: int, h: int, fill: str, rings: tuple, lower: str = "", studs: str = "", cut: int = 1) -> np.ndarray:
    """A framed box: rings are the border colours from the outside in; lower shades the bottom
    two rows of the fill (thickness); studs marks the corners; cut clips the corner pixels."""
    px = canvas(w, h)
    px[:, :] = C[fill]
    if lower:
        px[h - len(rings) - 2:h, :] = C[lower]
    for i, r in enumerate(rings):
        px[i, i:w - i] = C[r]; px[h - 1 - i, i:w - i] = C[r]; px[i:h - i, i] = C[r]; px[i:h - i, w - 1 - i] = C[r]
    if studs:
        k = len(rings)
        for y0, x0 in ((1, 1), (1, w - 2 - k), (h - 2 - k, 1), (h - 2 - k, w - 2 - k)):
            px[y0:y0 + k + 1, x0:x0 + k + 1] = C["ink"]
            px[y0 + 1:y0 + k, x0 + 1:x0 + k] = C[studs]
            px[y0 + 1, x0 + 1] = C["glow"]
    for i in range(cut):
        for j in range(cut - i):
            for y, x in ((i, j), (i, w - 1 - j), (h - 1 - i, j), (h - 1 - i, w - 1 - j)):
                px[y, x] = CLEAR
    return px

def disc(size: int, fill: str, rim: tuple, hi: str = "", lo: str = "", alpha: int = 255) -> np.ndarray:
    """A round button: rim colours from the outside in, a lit crescent upper left, a shaded one lower right."""
    px = canvas(size, size)
    yy, xx = np.mgrid[0:size, 0:size]
    c = size / 2 - 0.5
    d = np.hypot(xx - c, yy - c)
    r = size / 2 - 1
    px[d <= r] = C[fill][:3] + (alpha,)
    if hi:
        px[(d <= r - len(rim) - 1) & (np.hypot(xx - c - size * 0.07, yy - c - size * 0.07) > r - len(rim) - 1)] = C[hi]
    if lo:
        px[(d <= r - len(rim) - 1) & (np.hypot(xx - c + size * 0.07, yy - c + size * 0.07) > r - len(rim) - 1)] = C[lo]
    for i, col in enumerate(rim):
        px[(d <= r - i * 1.0) & (d > r - i - 1.0 - (1.0 if i else 0.4))] = C[col]
    return px

def gauge(name: str, top: str, mid: str, low: str) -> None:
    px = canvas(8, 10)
    px[:, :] = C[mid]; px[0:2, :] = C[top]; px[7:, :] = C[low]
    save(name, px)

def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    gold = ("ink", "brass", "gold", "brass", "umber")
    save("window", panel(48, 48, "wheat", gold, lower="sand", studs="gold", cut=2))
    save("parchment", panel(48, 48, "bone", ("bark", "sand"), lower="wheat", cut=2))
    save("title", panel(48, 24, "bark", ("ink", "brass", "umber"), lower="umber", cut=1))
    save("plate", panel(48, 48, "wheat", gold, lower="sand", studs="gold", cut=2))
    save("dark", panel(48, 48, "umber", ("ink", "brass", "ink"), cut=2))                 # quest and message boxes
    save("chip", panel(24, 24, "umber", ("ink", "brass", "ink"), cut=2))
    save("slot", panel(32, 32, "bark", ("ink", "brass", "umber"), lower="umber", cut=1))
    save("btn", panel(32, 32, "sand", ("ink", "wheat"), lower="oak", cut=2))
    save("btn_pressed", panel(32, 32, "oak", ("ink", "bark"), lower="oak", cut=2))
    save("btn_gold", panel(32, 32, "gold", ("ink", "glow"), lower="brass", cut=2))
    save("tab", panel(32, 32, "bark", ("ink", "oak"), lower="umber", cut=2))
    save("tab_on", panel(32, 32, "gold", ("ink", "glow"), lower="brass", cut=2))
    bg = canvas(16, 12); bg[:, :] = C["ink"]; bg[1:11, 1:15] = C["slate"]; bg[1:3, 1:15] = C["ink"]
    save("gauge_bg", bg)
    gauge("gauge_hp", "lime", "grass", "leaf"); gauge("gauge_hp_low", "ember", "crimson", "wine"); gauge("gauge_zeal", "mist", "sky", "royal")
    gauge("gauge_exp", "glow", "gold", "brass"); gauge("gauge_job", "lilac", "violet", "plum"); gauge("gauge_trail", "bone", "bone", "ash")
    save("btn_small", disc(88, "bark", ("ink", "brass", "gold", "umber"), hi="oak", lo="umber"))
    save("btn_auto_on", disc(88, "moss", ("ink", "grass", "lime", "pine"), hi="leaf", lo="pine"))
    save("btn_skill", disc(120, "umber", ("ink", "brass", "gold", "ink"), hi="bark", lo="ink"))
    save("btn_attack", disc(176, "gold", ("ink", "brass", "glow", "brass"), hi="glow", lo="brass"))
    save("joy_base", disc(160, "slate", ("ink", "brass", "ink"), alpha=110))
    save("joy_knob", disc(72, "sand", ("ink", "gold", "brass"), hi="wheat", lo="oak"))
    mm = panel(160, 160, "ink", ("ink", "brass", "gold", "brass", "ink"), studs="gold", cut=2)
    mm[5:155, 5:155] = CLEAR
    save("minimap_frame", mm)
    pal = canvas(32, 1)
    for i, n in enumerate(ak.NAMES):
        pal[0, i] = C[n]
    save("palette", pal)                                                                # read by UIKit.pixelate
    save("card", panel(32, 32, "bone", ("bark", "sand"), lower="wheat", cut=1))          # rows and cards inside a window
    print("gen_ui: frames written")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
