#!/usr/bin/env python3
"""The art bible as code (see DECISIONS.md, "Art bible"). Every picture the game shows goes
through finish() so it shares one palette, one outline, one light and one scale.

    from artkit import finish, quantize, PAL, PX_PER_UNIT, HEIGHT

Rules, in one place:
  PALETTE       32 colours. Nothing else may appear in a sprite, tile, prop or UI frame.
  OUTLINE       the outermost ring of every silhouette is INK, 1 px, drawn inside the shape.
  LIGHT         from the upper left. Drawn art is lit that way; imported art gets a mild ramp.
  ALPHA         on or off. Fades are drawn as a Bayer dissolve, never as soft alpha.
  SCALE         48 sprite pixels per world unit, for everything. HEIGHT gives standing heights.
  ANCHOR        feet on the bottom edge of the cell, body centred.
Requires Pillow, numpy, scipy.
"""
from __future__ import annotations
import numpy as np
from PIL import Image
from scipy import ndimage

PX_PER_UNIT = 48
# standing heights in world units (x48 = sprite pixels)
HEIGHT = {"pilgrim": 1.75, "npc": 1.75, "small": 1.25, "medium": 1.5, "large": 2.0, "boss": 3.5,
          "prop_low": 1.0, "prop_post": 2.5, "prop_tree": 4.0, "prop_building": 6.0}
TIER_HEIGHT = {"common": "small", "rare": "medium", "elite": "medium", "greater": "large", "boss": "boss"}

PAL = {
    # ink and stone
    "ink": "#1a1622", "slate": "#3d3a48", "iron": "#625e68", "stone": "#918a7e", "ash": "#c4bdac", "bone": "#f4efe4",
    # earth and wood
    "umber": "#3d2a25", "bark": "#6b4530", "oak": "#9a6a3f", "sand": "#c79a5e", "wheat": "#e8cf9a",
    # skin
    "tan": "#e0a67a", "blush": "#f6d3ae",
    # growing things
    "pine": "#1f3a33", "moss": "#35583a", "olive": "#6f7a3a", "leaf": "#4f8a45", "grass": "#8cb84f", "lime": "#cfe08a",
    # water and sky
    "deep": "#1f2a52", "royal": "#2f4f8f", "sky": "#4f8fc7", "mist": "#9fd3e8",
    # shadow and the uncanny
    "plum": "#2d2442", "violet": "#57407a", "lilac": "#9a7cc4",
    # blood and fire
    "wine": "#6a1f2a", "crimson": "#b33a35", "ember": "#e0704a",
    # gold and light
    "brass": "#b8862e", "gold": "#e8b83e", "glow": "#fbe58a",
}
NAMES = list(PAL)
RGB = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in PAL.values()], dtype=np.float64)
INK = tuple(int(v) for v in RGB[0])
# shading ramps, dark to light, for drawn art
RAMP = {
    "stone": ["ink", "slate", "iron", "stone", "ash", "bone"],
    "wood": ["ink", "umber", "bark", "oak", "sand", "wheat"],
    "leaf": ["ink", "pine", "moss", "leaf", "grass", "lime"],
    "dry": ["ink", "umber", "bark", "olive", "sand", "wheat"],
    "water": ["ink", "deep", "royal", "sky", "mist", "bone"],
    "night": ["ink", "ink", "plum", "violet", "lilac", "mist"],
    "sandstone": ["ink", "umber", "bark", "sand", "wheat", "bone"],
    "dusk": ["ink", "plum", "pine", "moss", "leaf", "grass"],
    "fire": ["ink", "wine", "crimson", "ember", "gold", "glow"],
    "gold": ["ink", "umber", "brass", "gold", "glow", "bone"],
    "cloth_red": ["ink", "wine", "crimson", "ember", "tan", "blush"],
    "cloth_blue": ["ink", "deep", "royal", "sky", "mist", "bone"],
    "skin": ["ink", "bark", "oak", "tan", "blush", "bone"],
    "dark": ["ink", "ink", "slate", "plum", "iron", "stone"],
}

def rgb(name: str) -> tuple:
    return tuple(int(v) for v in RGB[NAMES.index(name)])

def _oklab(c: np.ndarray) -> np.ndarray:
    c = c / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    l = 0.4122214708 * c[..., 0] + 0.5363325363 * c[..., 1] + 0.0514459929 * c[..., 2]
    m = 0.2119034982 * c[..., 0] + 0.6806995451 * c[..., 1] + 0.1073969566 * c[..., 2]
    s = 0.0883024619 * c[..., 0] + 0.2817188376 * c[..., 1] + 0.6299787005 * c[..., 2]
    l, m, s = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], axis=-1)

_LAB = _oklab(RGB)
_LUT = None
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float64) / 16.0 - 0.47

def _lut() -> np.ndarray:
    """Nearest palette entry for every 5-bit RGB colour, by distance in Oklab."""
    global _LUT
    if _LUT is None:
        g = (np.arange(32) * 8 + 4).astype(np.float64)
        grid = np.stack(np.meshgrid(g, g, g, indexing="ij"), axis=-1).reshape(-1, 3)
        lab = _oklab(grid)
        d = ((lab[:, None, :] - _LAB[None, :, :]) ** 2 * np.array([1.0, 1.25, 1.25])).sum(axis=2)
        _LUT = d.argmin(axis=1).astype(np.uint8)
    return _LUT

def indices(px: np.ndarray, dither: float = 0.0) -> np.ndarray:
    """RGB(A) array -> palette index per pixel. dither is the strength of the ordered pattern (0-1)."""
    c = px[..., :3].astype(np.float64)
    if dither:
        h, w = c.shape[:2]
        c = c + (np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w] * 48.0 * dither)[..., None]
    q = (c.clip(0, 255) // 8).astype(np.int32)
    return _lut()[q[..., 0] * 1024 + q[..., 1] * 32 + q[..., 2]]

def despeckle(idx: np.ndarray, solid: np.ndarray) -> np.ndarray:
    """A lone pixel unlike all four neighbours takes the colour of the one above: clean clusters."""
    p = np.pad(idx, 1, mode="edge")
    up, down, left, right = p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]
    lone = (idx != up) & (idx != down) & (idx != left) & (idx != right) & solid
    return np.where(lone, up, idx)

def harden(px: np.ndarray) -> np.ndarray:
    """Alpha becomes on/off. Half-transparent areas (a fading death pose) become a dissolve."""
    a = px[..., 3].astype(np.float64) / 255.0
    h, w = a.shape
    thresh = np.tile(BAYER + 0.47, (h // 4 + 1, w // 4 + 1))[:h, :w] * 0.9 + 0.05
    soft_area = ndimage.uniform_filter((a > 0.05).astype(np.float64) * a, 9) / np.maximum(ndimage.uniform_filter((a > 0.05).astype(np.float64), 9), 1e-6)
    fading = soft_area < 0.85                           # the whole region is see-through, not just its rim
    return np.where(fading, a > thresh, a >= 0.5)

def light_ramp(px: np.ndarray, solid: np.ndarray, amount: float = 0.07) -> np.ndarray:
    """Imported art cannot be relit, but it can lean the same way: a little brighter toward the
    upper left of each body, a little darker toward the lower right."""
    ys, xs = np.where(solid)
    if len(ys) == 0:
        return px
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    yy, xx = np.mgrid[0:px.shape[0], 0:px.shape[1]]
    t = ((xx - x0) / max(1, x1 - x0) + (yy - y0) / max(1, y1 - y0)) * 0.5      # 0 upper left .. 1 lower right
    out = px.astype(np.float64)
    out[..., :3] *= (1.0 + amount - 2.0 * amount * t.clip(0, 1))[..., None]
    return out.clip(0, 255)

def outline(idx: np.ndarray, solid: np.ndarray) -> np.ndarray:
    """The outline rule: every solid pixel that touches empty space (4 neighbours) becomes INK."""
    inner = ndimage.binary_erosion(solid, structure=ndimage.generate_binary_structure(2, 1), border_value=0)
    return np.where(solid & ~inner, 0, idx)

def to_image(idx: np.ndarray, solid: np.ndarray) -> Image.Image:
    out = np.zeros(idx.shape + (4,), dtype=np.uint8)
    out[..., :3] = RGB[idx].astype(np.uint8)
    out[..., 3] = np.where(solid, 255, 0)
    out[~solid, :3] = 0
    return Image.fromarray(out, "RGBA")

def quantize(im: Image.Image, dither: float = 0.0) -> Image.Image:
    """Palette only: for tiles and other pictures that fill their canvas."""
    px = np.asarray(im.convert("RGBA"))
    solid = px[..., 3] >= 128
    return to_image(indices(px, dither), solid)

def finish(im: Image.Image, ramp: bool = True, edge: bool = True, dither: float = 0.0, cells: tuple | None = None) -> Image.Image:
    """The whole rule set for a sprite: hard alpha, light ramp, palette, clean clusters, ink outline.
    cells=(cols, rows) treats a sheet cell by cell, so each pose gets its own light ramp."""
    px = np.asarray(im.convert("RGBA")).copy()
    if off_palette(im) == 0 and not ((px[..., 3] > 0) & (px[..., 3] < 255)).any():
        ramp = False                                    # already conforming: running again changes nothing
    solid = harden(px)
    if ramp:
        if cells:
            cw, ch = px.shape[1] // cells[0], px.shape[0] // cells[1]
            lit = px.astype(np.float64)
            for r in range(cells[1]):
                for c in range(cells[0]):
                    s = (slice(r * ch, (r + 1) * ch), slice(c * cw, (c + 1) * cw))
                    lit[s] = light_ramp(px[s], solid[s])
            px = lit
        else:
            px = light_ramp(px, solid)
    idx = despeckle(indices(px, dither), solid)
    if edge:
        idx = outline(idx, solid)
    return to_image(idx, solid)

def shadow_blob(size: int = 64) -> Image.Image:
    """The one shadow: an ink ellipse, 2:1, drawn as a dissolve so it needs no soft alpha."""
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.hypot((xx - size / 2 + 0.5) / (size * 0.46), (yy - size / 2 + 0.5) / (size * 0.30))
    out = np.zeros((size, size, 4), dtype=np.uint8)
    out[..., :3] = INK
    out[..., 3] = np.where(d < 0.72, 110, np.where(d < 1.0, 60, 0))
    return Image.fromarray(out, "RGBA")

def off_palette(im: Image.Image) -> int:
    """How many visible pixels are not palette colours (the check used by tools/check_assets.py)."""
    px = np.asarray(im.convert("RGBA"))
    vis = px[px[..., 3] > 0][:, :3].astype(np.int32)
    if len(vis) == 0:
        return 0
    key = vis[:, 0] * 65536 + vis[:, 1] * 256 + vis[:, 2]
    pal = (RGB[:, 0] * 65536 + RGB[:, 1] * 256 + RGB[:, 2]).astype(np.int32)
    return int((~np.isin(key, pal)).sum())

if __name__ == "__main__":       # print a swatch sheet
    sw = Image.new("RGB", (32 * 24, 40))
    for i, c in enumerate(RGB):
        sw.paste(tuple(int(v) for v in c), (i * 24, 0, i * 24 + 24, 40))
    sw.save("/tmp/palette.png"); print(len(PAL), "colours -> /tmp/palette.png")
