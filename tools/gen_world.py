#!/usr/bin/env python3
"""Draw the world kit: ground tiles, scenery props and far skylines, all by the art bible
(tools/artkit.py: 32 colours, ink outline, light from the upper left, 48 px per world unit).

    python3 tools/gen_world.py            # writes assets/tiles/*.png, assets/props/k_*.png, bd_*.png,
                                          # assets/fx/shadow.png and data/props.json

Everything here is drawn from shapes and seeded noise, so it can be regenerated at any time.
A painted picture of the same name and size dropped over a file replaces it; run
tools/conform.py afterwards so it is held to the same palette and outline.
Requires Pillow, numpy, scipy.
"""
from __future__ import annotations
import json, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
import artkit as ak

ROOT = Path(__file__).resolve().parent.parent
U = ak.PX_PER_UNIT
LIGHT = np.array([-0.55, -0.60, 0.58]); LIGHT /= np.linalg.norm(LIGHT)
RID = {name: i for i, name in enumerate(ak.RAMP)}
RAMP_IDX = np.array([[ak.NAMES.index(c) for c in ramp] for ramp in ak.RAMP.values()])

def noise(w: int, h: int, cell: int, seed: int, wrap: bool = False) -> np.ndarray:
    """Smooth value noise in 0..1. wrap=True makes it tile."""
    rng = np.random.default_rng(seed)
    gw, gh = max(2, w // cell + (0 if wrap else 2)), max(2, h // cell + (0 if wrap else 2))
    g = rng.random((gh, gw)).astype(np.float32)
    if wrap:
        g = np.pad(g, ((0, 1), (0, 1)), mode="wrap")
        big = np.asarray(Image.fromarray(g).resize(((gw + 1) * cell, (gh + 1) * cell), Image.BICUBIC))
        return big[cell // 2:cell // 2 + h, cell // 2:cell // 2 + w].clip(0, 1)
    return np.asarray(Image.fromarray(g).resize((gw * cell, gh * cell), Image.BICUBIC))[:h, :w].clip(0, 1)

class Art:
    """A small shape painter. Each shape writes a ramp and a 0..1 brightness; render() turns
    brightness into the ramp's palette steps, draws soft inner lines where shapes meet and the
    ink outline around the whole."""
    def __init__(self, w: float, h: float, seed: int = 1):
        self.w, self.h = int(round(w)), int(round(h))
        self.ramp = np.full((self.h, self.w), -1, dtype=np.int32)
        self.sh = np.zeros((self.h, self.w), dtype=np.float32)
        self.pid = np.zeros((self.h, self.w), dtype=np.int32)
        self.flat = np.zeros((self.h, self.w), dtype=bool)        # no dither, no grain (glowing things)
        self.n = 0
        self.seed = seed
        self.rng = np.random.default_rng(seed)
        self.Y, self.X = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        self.X += 0.5; self.Y += 0.5

    def put(self, mask: np.ndarray, ramp: str, shade, flat: bool = False, same: bool = False) -> None:
        if not same:
            self.n += 1
        self.ramp[mask] = RID[ramp]
        self.sh[mask] = shade[mask] if isinstance(shade, np.ndarray) else shade
        self.pid[mask] = self.n
        self.flat[mask] = flat

    def ball(self, cx, cy, rx, ry, ramp, lo=0.12, hi=1.0, same=False) -> None:
        dx, dy = (self.X - cx) / rx, (self.Y - cy) / ry
        d2 = dx * dx + dy * dy
        nz = np.sqrt(np.clip(1 - d2, 0, 1))
        lam = dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2]
        self.put(d2 <= 1, ramp, lo + (hi - lo) * np.clip(lam * 0.62 + 0.30, 0, 1), same=same)

    def cyl(self, cx, y0, y1, r0, r1, ramp, lo=0.15, hi=0.95, lean=0.0) -> None:
        """Upright round column from y0 (top) to y1 (bottom); r0/r1 radii; lean shifts the top sideways."""
        t = np.clip((self.Y - y0) / max(1e-6, y1 - y0), 0, 1)
        r = r0 + (r1 - r0) * t
        dx = (self.X - (cx + lean * (1 - t))) / np.maximum(r, 0.01)
        nz = np.sqrt(np.clip(1 - dx * dx, 0, 1))
        lam = dx * LIGHT[0] + nz * LIGHT[2] - 0.12 * (1 - t)
        self.put((np.abs(dx) <= 1) & (self.Y >= y0) & (self.Y <= y1) & (r > 0.3), ramp, lo + (hi - lo) * np.clip(lam * 0.7 + 0.30, 0, 1))

    def poly(self, pts, ramp, shade, flat=False, same=False) -> np.ndarray:
        im = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255)
        m = np.asarray(im) > 0
        self.put(m, ramp, shade, flat, same)
        return m

    def rect(self, x0, y0, x1, y1, ramp, shade, flat=False, same=False) -> np.ndarray:
        m = (self.X >= x0) & (self.X < x1) & (self.Y >= y0) & (self.Y < y1)
        self.put(m, ramp, shade, flat, same)
        return m

    def stroke(self, pts, ramp, shade, width=2.0, flat=False) -> None:
        im = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(im).line([(float(x), float(y)) for x, y in pts], fill=255, width=max(1, int(round(width))), joint="curve")
        self.put(np.asarray(im) > 0, ramp, shade, flat)

    def grain(self, amount=0.12, cell=5, mask=None) -> None:
        n = (noise(self.w, self.h, cell, self.seed * 7 + 3) - 0.5) * 2 * amount
        m = (self.ramp >= 0) & ~self.flat if mask is None else mask
        self.sh[m] = self.sh[m] + n[m]

    def bricks(self, mask, bw=12, bh=6, depth=0.22) -> None:
        row = (self.Y // bh).astype(np.int32)
        xo = self.X + (row % 2) * (bw / 2)
        mortar = ((self.Y % bh) < 1) | ((xo % bw) < 1)
        self.sh[mask & mortar] -= depth
        tone = ((row * 7 + (xo // bw).astype(np.int32) * 13) % 5 - 2) * 0.035
        self.sh[mask] += tone[mask]

    def planks(self, mask, pw=6, depth=0.2, across=False) -> None:
        a = self.Y if across else self.X
        self.sh[mask & ((a % pw) < 1)] -= depth
        self.sh[mask] += (((a // pw).astype(np.int32) * 5 % 3) - 1)[mask] * 0.04

    def lit_top(self, mask, amount=0.16) -> None:
        """Brighten the top edge and darken the bottom edge of a shape: reads as thickness."""
        up = np.roll(mask, 1, axis=0); up[0] = False
        down = np.roll(mask, -1, axis=0); down[-1] = False
        self.sh[mask & ~up] += amount
        self.sh[mask & ~down] -= amount

    def render(self, dither: float = 0.3, outline: bool = True) -> Image.Image:
        solid = self.ramp >= 0
        b = np.tile(ak.BAYER, (self.h // 4 + 1, self.w // 4 + 1))[:self.h, :self.w]
        lv = self.sh * 4.0 + 0.9 + np.where(self.flat, 0, b * dither)
        lv = np.clip(np.round(lv), 1, 5).astype(np.int32)
        # where two shapes meet, the darker side's edge pixel drops one step: a soft inner line
        for ax in (0, 1):
            other = np.roll(self.pid, -1, axis=ax)
            osolid = np.roll(solid, -1, axis=ax)
            edge = solid & osolid & (other != self.pid) & ~self.flat
            lv[edge] = np.maximum(1, lv[edge] - 1)
        idx = RAMP_IDX[np.clip(self.ramp, 0, None), lv]
        if outline:
            idx = ak.outline(idx, solid)
        return ak.to_image(idx, solid)

PROPS: dict[str, dict] = {}

def save(name: str, im: Image.Image, solid: float = 0.0, shadow: float = 0.0, glow: str = "", flat: bool = False) -> None:
    """solid = collision radius in world units (0 = walk through); shadow = blob width in world units."""
    box = im.getbbox()
    if box:
        im = im.crop((box[0], 0, box[2], im.height)) if not flat else im.crop(box)
    im.save(ROOT / "assets" / "props" / f"k_{name}.png", optimize=True)
    PROPS[name] = {"w": round(im.width / U, 3), "h": round(im.height / U, 3), "solid": solid, "shadow": shadow, **({"glow": glow} if glow else {}), **({"flat": True} if flat else {})}

# ------------------------------------------------------------------ growing things
def canopy(a: Art, cx, cy, rx, ry, ramp, n=11) -> None:
    a.ball(cx, cy, rx, ry, ramp, lo=0.1, hi=0.8)
    for i in range(n):
        ang = a.rng.uniform(0, math.tau); d = a.rng.uniform(0.25, 0.85)
        x, y = cx + math.cos(ang) * rx * d, cy + math.sin(ang) * ry * d * 0.9
        r = a.rng.uniform(0.28, 0.46) * min(rx, ry)
        a.ball(x, y, r * 1.15, r, ramp, lo=0.12, hi=1.0)

def tree(name: str, ramp: str, seed: int, kind: str = "round", fruit: str = "") -> None:
    if kind == "round":
        w, h = 3.4 * U, 4.2 * U; a = Art(w, h, seed)
        a.cyl(w / 2, h * 0.52, h - 1, w * 0.045, w * 0.075, "wood")
        a.cyl(w / 2 - w * 0.07, h * 0.80, h - 1, w * 0.02, w * 0.05, "wood", lean=w * 0.04)
        a.cyl(w / 2 + w * 0.07, h * 0.82, h - 1, w * 0.02, w * 0.05, "wood", lean=-w * 0.04)
        canopy(a, w / 2, h * 0.34, w * 0.44, h * 0.30, ramp, 13)
        if fruit:
            for i in range(11):
                ang = a.rng.uniform(0, math.tau); d = a.rng.uniform(0.2, 0.85)
                a.ball(w / 2 + math.cos(ang) * w * 0.4 * d, h * 0.36 + math.sin(ang) * h * 0.26 * d, 3.4, 3.4, fruit, lo=0.5, hi=1.0)
    elif kind == "tall":
        w, h = 2.2 * U, 4.8 * U; a = Art(w, h, seed)
        a.cyl(w / 2, h * 0.6, h - 1, w * 0.06, w * 0.09, "wood")
        for i in range(5):                  # a fir: tiers of boughs, widest at the bottom
            f = (4 - i) / 4
            y0, y1, half = h * (0.02 + 0.13 * (4 - i)), h * (0.26 + 0.13 * (4 - i)), w * (0.16 + 0.07 * (4 - i))
            m = a.poly([(w / 2, y0), (w / 2 + half, y1), (w / 2 + half * 0.5, y1 - 4), (w / 2, y1 + 3), (w / 2 - half * 0.5, y1 - 4), (w / 2 - half, y1)], ramp, 0.5)
            a.sh[m] = (0.66 - (a.X - (w / 2 - half)) / (2 * half) * 0.42 - (a.Y - y0) / (y1 - y0) * 0.12)[m]
    else:   # bush
        w, h = 1.5 * U, 1.5 * U; a = Art(w, h, seed)
        canopy(a, w / 2, h * 0.56, w * 0.42, h * 0.42, ramp, 9)
        a.ramp[a.Y > h - 2] = -1
    a.grain(0.06, 3)
    save(name, a.render(0.4), solid=0.45 if kind != "bush" else 0.0, shadow=2.4 if kind == "round" else 1.2)

def dead_tree(name: str, seed: int) -> None:
    w, h = 2.6 * U, 3.6 * U; a = Art(w, h, seed)
    def limb(x, y, ang, length, width):
        x2, y2 = x + math.cos(ang) * length, y - math.sin(ang) * length
        a.stroke([(x, y), ((x + x2) / 2 + a.rng.uniform(-4, 4), (y + y2) / 2), (x2, y2)], "dark", 0.55 if math.cos(ang) < 0 else 0.3, width)
        if width > 2.2:
            for s in (-1, 1):
                limb(x2, y2, ang + s * a.rng.uniform(0.35, 0.8), length * a.rng.uniform(0.5, 0.7), width * 0.6)
    a.cyl(w / 2, h * 0.45, h - 1, w * 0.04, w * 0.085, "dark", lo=0.2, hi=0.8, lean=a.rng.uniform(-6, 6))
    limb(w / 2, h * 0.5, math.pi / 2 + a.rng.uniform(-0.2, 0.2), h * 0.22, 5.5)
    limb(w / 2, h * 0.62, math.pi * 0.82, h * 0.2, 4.0)
    limb(w / 2, h * 0.58, math.pi * 0.2, h * 0.2, 4.0)
    a.grain(0.08, 3)
    save(name, a.render(0.2), solid=0.3, shadow=1.2)

def tuft(name: str, ramp: str, seed: int, flowers: str = "") -> None:
    w, h = 0.7 * U, 0.5 * U; a = Art(w, h, seed)
    for i in range(9):
        x = a.rng.uniform(3, w - 3); top = a.rng.uniform(2, h * 0.6)
        a.stroke([(x, h - 1), (x + a.rng.uniform(-4, 4), top)], ramp, a.rng.uniform(0.6, 1.0), 1.6)
    if flowers:
        for i in range(4):
            x, y = a.rng.uniform(4, w - 4), a.rng.uniform(3, h * 0.55)
            a.ball(x, y, 2.6, 2.6, flowers, lo=0.6, hi=1.0)
            a.rect(x - 0.5, y - 0.5, x + 0.5, y + 0.5, "gold", 0.9, flat=True)
    save(name, a.render(0.0, outline=bool(flowers)))

def reeds(name: str, seed: int) -> None:
    w, h = 0.9 * U, 1.3 * U; a = Art(w, h, seed)
    for i in range(8):
        x = a.rng.uniform(4, w - 4); top = a.rng.uniform(4, h * 0.5)
        a.stroke([(x, h - 1), (x + a.rng.uniform(-5, 5), top)], "dry", a.rng.uniform(0.3, 0.8), 1.6)
        if i % 3 == 0:
            a.ball(x, top + 3, 1.8, 4.5, "wood", lo=0.2, hi=0.6)
    save(name, a.render(0.0, outline=False))

def mushroom(name: str, ramp: str, seed: int) -> None:
    w, h = 1.2 * U, 1.5 * U; a = Art(w, h, seed)
    for cx, s in ((w * 0.38, 1.0), (w * 0.74, 0.62)):
        top = h - h * 0.86 * s
        a.cyl(cx, top + 6, h - 1, 3.2 * s, 4.6 * s, "stone", lo=0.55, hi=1.0)
        a.ball(cx, top + 9 * s, 15 * s, 10 * s, ramp, lo=0.3, hi=1.0)
        a.rect(cx - 15 * s, top + 11 * s, cx + 15 * s, top + 22 * s, "stone", 0.0)       # carve the underside
        a.ramp[(a.Y >= top + 11 * s) & (a.Y < top + 22 * s) & (np.abs(a.X - cx) > 4.0 * s) & (a.pid == a.n)] = -1
        for i in range(4):
            a.ball(cx + a.rng.uniform(-9, 9) * s, top + a.rng.uniform(3, 8) * s, 1.6, 1.3, "stone", lo=0.9, hi=1.0)
    save(name, a.render(0.2), glow=ramp)

# ------------------------------------------------------------------ stone
def rock(name: str, w_u: float, h_u: float, seed: int, ramp: str = "stone", moss: bool = False, solid: float = 0.0) -> None:
    w, h = w_u * U, h_u * U; a = Art(w, h, seed)
    a.ball(w / 2, h * 0.62, w * 0.47, h * 0.42, ramp, lo=0.1, hi=0.85)
    for i in range(4):
        x, y = w * a.rng.uniform(0.25, 0.75), h * a.rng.uniform(0.3, 0.6)
        a.ball(x, y, w * a.rng.uniform(0.16, 0.3), h * a.rng.uniform(0.18, 0.3), ramp, lo=0.15, hi=0.95)
    a.ramp[a.Y > h - 1.5] = np.where(a.ramp[a.Y > h - 1.5] >= 0, a.ramp[a.Y > h - 1.5], -1)
    if moss:
        m = (a.ramp >= 0) & (a.Y < h * 0.42) & (noise(a.w, a.h, 5, seed) > 0.42)
        a.put(m, "leaf", np.clip(a.sh + 0.05, 0, 1))
    a.grain(0.14, 4)
    save(name, a.render(0.35), solid=solid, shadow=w_u * 0.9)

def spire(name: str, h_u: float, seed: int, ramp: str = "dark") -> None:
    w, h = 2.2 * U, h_u * U; a = Art(w, h, seed)
    for cx, top, base in ((w * 0.5, 2, w * 0.3), (w * 0.24, h * 0.5, w * 0.17), (w * 0.78, h * 0.62, w * 0.15)):
        a.cyl(cx, top, h - 1, 0.5, base, ramp, lo=0.12, hi=0.9, lean=a.rng.uniform(-8, 8))
    a.grain(0.16, 5)
    cracks = noise(a.w, a.h, 3, seed + 5) > 0.72
    a.sh[cracks & (a.ramp >= 0)] -= 0.18
    save(name, a.render(0.3), solid=0.6, shadow=1.8)

def menhir(name: str, h_u: float, seed: int) -> None:
    w, h = 1.1 * U, h_u * U; a = Art(w, h, seed)
    lean = a.rng.uniform(-5, 5)
    a.poly([(w * 0.2 + lean, h * 0.08), (w * 0.62 + lean, 2), (w * 0.86 + lean * 0.5, h * 0.2), (w * 0.9, h - 1), (w * 0.1, h - 1)], "stone", 0.5)
    a.poly([(w * 0.62 + lean, 2), (w * 0.86 + lean * 0.5, h * 0.2), (w * 0.9, h - 1), (w * 0.68, h - 1)], "stone", 0.22)
    a.poly([(w * 0.2 + lean, h * 0.08), (w * 0.62 + lean, 2), (w * 0.56 + lean, h * 0.14), (w * 0.26 + lean, h * 0.17)], "stone", 0.85)
    a.grain(0.14, 4)
    rune = (np.abs(a.X - w * 0.42) < 1.2) & (a.Y > h * 0.35) & (a.Y < h * 0.6) | (np.abs(a.Y - h * 0.45) < 1.2) & (np.abs(a.X - w * 0.42) < 5)
    a.sh[rune & (a.ramp >= 0)] -= 0.3
    save(name, a.render(0.3), solid=0.45, shadow=1.0)

def cliff(name: str, w_u: float, h_u: float, seed: int, ramp: str = "stone", cap: str = "") -> None:
    """One mass of a ridge line: a broken rock face, optionally capped with grass or snow."""
    w, h = w_u * U, h_u * U; a = Art(w, h, seed)
    n = 5
    tops = [h * a.rng.uniform(0.04, 0.36) for _ in range(n + 1)]
    for i in range(n):
        x0, x1 = w * i / n - 3, w * (i + 1) / n + 3
        t0, t1 = tops[i], tops[i + 1]
        a.poly([(x0, t0 + 6), ((x0 + x1) / 2, min(t0, t1) - a.rng.uniform(0, 8)), (x1, t1 + 6), (x1, h), (x0, h)], ramp, 0.62 if i % 2 == 0 else 0.34)
    a.sh += ((a.Y / h) * -0.22).astype(np.float32)
    strata = (np.sin(a.Y * 0.36 + noise(a.w, a.h, 14, seed) * 7) > 0.9)
    a.sh[strata & (a.ramp >= 0)] -= 0.2
    a.grain(0.07, 9)
    if cap:
        solid = a.ramp >= 0
        first = np.argmax(solid, axis=0)
        depth = a.Y - first[None, :]
        edge = 5 + noise(a.w, a.h, 4, seed + 9) * 7
        m = solid & (depth < edge)
        a.put(m, cap, np.clip(0.55 + (noise(a.w, a.h, 3, seed + 2) - 0.5) * 0.5 + np.where(depth < 2.5, 0.25, 0), 0, 1))
    save(name, a.render(0.4), solid=0.0)

def pillar(name: str, h_u: float, broken: bool, seed: int) -> None:
    w, h = 1.2 * U, h_u * U; a = Art(w, h, seed)
    top = 8 if not broken else 0
    a.cyl(w / 2, top, h - 8, w * 0.27, w * 0.30, "stone", lo=0.25, hi=1.0)
    flute = ((a.X - w / 2) % 6 < 1) & (a.ramp >= 0)
    a.sh[flute] -= 0.14
    a.rect(w * 0.1, h - 9, w * 0.9, h - 1, "stone", 0.6); a.lit_top(a.pid == a.n)
    if not broken:
        a.rect(w * 0.1, 1, w * 0.9, 9, "stone", 0.75); a.lit_top(a.pid == a.n)
    else:
        jag = a.Y < 6 + noise(a.w, a.h, 4, seed) * 14
        a.ramp[jag] = -1
    a.grain(0.08, 4)
    save(name, a.render(0.3), solid=0.5, shadow=1.2)

def crystal(name: str, ramp: str, seed: int) -> None:
    w, h = 1.4 * U, 1.9 * U; a = Art(w, h, seed)
    shards = [(w * 0.5, 3, 9.5, 0), (w * 0.26, h * 0.34, 7, -8), (w * 0.76, h * 0.42, 6.5, 8), (w * 0.4, h * 0.6, 5, -3)]
    for cx, top, r, lean in shards:
        b = h - 2
        a.poly([(cx + lean, top), (cx - r + lean * 0.4, top + (b - top) * 0.3), (cx - r * 0.6, b), (cx, b)], ramp, 0.95, flat=True)
        a.poly([(cx + lean, top), (cx + r + lean * 0.4, top + (b - top) * 0.3), (cx + r * 0.6, b), (cx, b)], ramp, 0.55, flat=True)
        a.poly([(cx + lean, top), (cx - r * 0.25 + lean * 0.6, top + (b - top) * 0.34), (cx, b), (cx + r * 0.2 + lean * 0.6, top + (b - top) * 0.3)], ramp, 0.75, flat=True)
    a.ball(w * 0.5, h - 4, w * 0.46, 6, "dark", lo=0.3, hi=0.7)
    save(name, a.render(0.0), solid=0.4, shadow=1.2, glow=ramp)

# ------------------------------------------------------------------ made things
def lamp(name: str, flame: str = "fire") -> None:
    w, h = 0.9 * U, 3.1 * U; a = Art(w, h, 3)
    a.cyl(w / 2, h * 0.16, h - 5, 2.0, 2.6, "dark", lo=0.3, hi=0.9)
    a.rect(w / 2 - 6, h - 6, w / 2 + 6, h - 1, "dark", 0.5); a.lit_top(a.pid == a.n)
    a.poly([(w / 2 - 9, h * 0.15), (w / 2 + 9, h * 0.15), (w / 2 + 6, h * 0.03 + 8), (w / 2 - 6, h * 0.03 + 8)], flame, 0.95, flat=True)
    a.ball(w / 2, h * 0.105, 3.2, 5, flame, lo=1.0, hi=1.0)
    a.poly([(w / 2 - 11, h * 0.04 + 8), (w / 2 + 11, h * 0.04 + 8), (w / 2, 1)], "dark", 0.55)
    a.rect(w / 2 - 10, h * 0.15, w / 2 + 10, h * 0.15 + 3, "dark", 0.7)
    save(name, a.render(0.0), solid=0.2, shadow=0.7, glow=flame)

def torch(name: str) -> None:
    w, h = 0.6 * U, 2.0 * U; a = Art(w, h, 4)
    a.cyl(w / 2, h * 0.22, h - 1, 1.8, 2.4, "wood", lo=0.2, hi=0.8)
    a.rect(w / 2 - 5, h * 0.18, w / 2 + 5, h * 0.27, "dark", 0.6)
    a.ball(w / 2, h * 0.12, 6, 9, "fire", lo=0.55, hi=0.75)
    a.ball(w / 2, h * 0.14, 3.4, 6, "fire", lo=1.0, hi=1.0)
    save(name, a.render(0.0), shadow=0.5, glow="fire")

def banner(name: str, cloth: str) -> None:
    w, h = 1.3 * U, 3.6 * U; a = Art(w, h, 5)
    a.cyl(w * 0.2, 4, h - 1, 1.8, 2.2, "wood", lo=0.25, hi=0.85)
    a.ball(w * 0.2, 4, 3.4, 3.4, "gold")
    x0, x1, y0, y1 = w * 0.24, w * 0.95, h * 0.08, h * 0.52
    wave = np.sin((a.X - x0) * 0.22) * 0.16
    m = a.poly([(x0, y0), (x1, y0), (x1, y1), ((x0 + x1) / 2, y1 - 9), (x0, y1)], cloth, 0.6)
    a.sh[m] = (0.58 + wave)[m]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - 4          # a plain four-point star: no figure, no emblem of office
    a.poly([(cx, cy - 9), (cx + 3, cy - 3), (cx + 9, cy), (cx + 3, cy + 3), (cx, cy + 9), (cx - 3, cy + 3), (cx - 9, cy), (cx - 3, cy - 3)], "gold", 0.9, flat=True)
    a.rect(x0, y0, x1, y0 + 2.5, "gold", 0.7)
    save(name, a.render(0.25), shadow=0.6)

def fence(name: str) -> None:
    w, h = 1.6 * U, 1.0 * U; a = Art(w, h, 6)
    for y in (h * 0.3, h * 0.62):
        m = a.rect(0, y, w, y + 5, "wood", 0.55); a.lit_top(m, 0.2)
    for x in (w * 0.08, w * 0.5, w * 0.92):
        a.cyl(x, 3, h - 1, 2.6, 3.0, "wood", lo=0.25, hi=0.9)
    a.grain(0.08, 3)
    save(name, a.render(0.2))

def crate(name: str, barrel: bool) -> None:
    w, h = 0.95 * U, 1.0 * U; a = Art(w, h, 7 + int(barrel))
    if barrel:
        a.cyl(w / 2, 5, h - 1, w * 0.36, w * 0.36, "wood", lo=0.2, hi=0.95)
        m = a.pid == a.n
        bulge = 1 - np.abs((a.Y - h / 2) / (h / 2)) ** 2
        a.ramp[m & (np.abs(a.X - w / 2) > w * (0.36 + 0.07 * bulge))] = -1
        a.planks(a.ramp >= 0, 5, 0.14)
        for y in (h * 0.24, h * 0.72):
            a.rect(0, y, w, y + 3, "dark", 0.7)
            a.ramp[(a.pid == a.n) & ~m] = -1
        a.ball(w / 2, 6, w * 0.34, 4.5, "wood", lo=0.6, hi=0.9)
    else:
        m = a.rect(3, h * 0.26, w - 3, h - 1, "wood", 0.5); a.planks(m, 7, 0.16)
        a.poly([(3, h * 0.26), (w * 0.18, 3), (w - 3 + 0, 3), (w - 3, h * 0.26)], "wood", 0.82)
        for x0 in (3, w - 8):
            a.rect(x0, h * 0.26, x0 + 5, h - 1, "wood", 0.72)
        a.rect(3, h * 0.26, w - 3, h * 0.26 + 4, "wood", 0.72); a.rect(3, h - 5, w - 3, h - 1, "wood", 0.3)
    a.grain(0.07, 3)
    save(name, a.render(0.2), solid=0.45, shadow=0.9)

def house(name: str, seed: int, roof: str = "cloth_red", lit: bool = True) -> None:
    w, h = 6.6 * U, 5.6 * U; a = Art(w, h, seed)
    wy = h * 0.5
    wall = a.rect(w * 0.08, wy, w * 0.92, h - 1, "stone", 0.62); a.bricks(wall, 14, 7, 0.16)
    a.rect(w * 0.08, h - 9, w * 0.92, h - 1, "stone", 0.36); a.bricks(a.pid == a.n, 18, 5, 0.12)
    # timber frame
    for x in (w * 0.08, w * 0.5 - 3, w * 0.92 - 6):
        a.rect(x, wy, x + 6, h - 1, "wood", 0.45)
    # roof with tile rows, the left slope lit
    apex = (w * 0.5, h * 0.06)
    rm = a.poly([(w * 0.02, wy + 6), apex, (w * 0.98, wy + 6)], roof, 0.5)
    a.sh[rm] = np.where(a.X < w * 0.5, 0.66, 0.34)[rm]
    rows = ((a.Y + (a.X // 8 % 2) * 4) % 8 < 1.2) | (a.X % 8 < 1)
    a.sh[rm & rows] -= 0.18
    a.stroke([(w * 0.02, wy + 6), apex, (w * 0.98, wy + 6)], "wood", 0.5, 4)
    a.rect(w * 0.70, h * 0.10, w * 0.80, h * 0.34, "stone", 0.5); a.bricks(a.pid == a.n, 8, 5, 0.16)
    a.rect(w * 0.685, h * 0.09, w * 0.815, h * 0.115, "stone", 0.8)
    # door and windows
    dx = w * (0.24 if seed % 2 else 0.66)
    d = a.rect(dx, h * 0.66, dx + w * 0.13, h - 1, "wood", 0.4); a.planks(d, 6, 0.16)
    a.ball(dx + w * 0.105, h * 0.84, 1.8, 1.8, "gold")
    for wx in ((w * 0.62, w * 0.78) if seed % 2 else (w * 0.2, w * 0.38)):
        a.rect(wx - 2, h * 0.63, wx + w * 0.1 + 2, h * 0.80, "wood", 0.35)
        a.rect(wx, h * 0.645, wx + w * 0.1, h * 0.785, "gold" if lit else "night", 0.85 if lit else 0.2, flat=True)
        a.rect(wx + w * 0.05 - 1, h * 0.645, wx + w * 0.05 + 1, h * 0.785, "wood", 0.35)
        a.rect(wx, h * 0.71, wx + w * 0.1, h * 0.72, "wood", 0.35)
    a.grain(0.08, 4)
    save(name, a.render(0.3), shadow=6.0)

def cross_prop() -> None:
    w, h = 2.6 * U, 5.2 * U; a = Art(w, h, 11)
    m = a.rect(w / 2 - 8, 2, w / 2 + 8, h - 1, "wood", 0.52); a.planks(m, 5, 0.12)
    a.sh[m & (a.X < w / 2 - 4)] += 0.2; a.sh[m & (a.X > w / 2 + 4)] -= 0.2
    m2 = a.rect(w * 0.06, h * 0.2, w * 0.94, h * 0.2 + 15, "wood", 0.56); a.planks(m2, 5, 0.12, across=True); a.lit_top(m2, 0.2)
    a.ball(w / 2, h - 3, 22, 7, "stone", lo=0.2, hi=0.8)
    a.grain(0.07, 3)
    save("cross", a.render(0.2), solid=0.3, shadow=1.6)

def tomb() -> None:
    w, h = 4.6 * U, 2.8 * U; a = Art(w, h, 12)
    a.ball(w / 2, h * 0.7, w * 0.49, h * 0.66, "stone", lo=0.15, hi=0.85)
    for i in range(6):
        a.ball(w * a.rng.uniform(0.15, 0.85), h * a.rng.uniform(0.2, 0.6), w * 0.16, h * 0.2, "stone", lo=0.2, hi=0.9)
    a.ball(w * 0.42, h * 0.72, w * 0.13, h * 0.3, "dark", lo=0.0, hi=0.0)
    a.rect(w * 0.29, h * 0.72, w * 0.55, h - 1, "dark", 0.0, same=True)
    a.ball(w * 0.72, h * 0.72, w * 0.14, h * 0.27, "stone", lo=0.3, hi=1.0)       # the stone, rolled away
    a.grain(0.14, 5)
    moss = (a.ramp == RID["stone"]) & (a.Y < h * 0.3) & (noise(a.w, a.h, 5, 3) > 0.5)
    a.put(moss, "leaf", np.clip(a.sh, 0, 1))
    save("tomb", a.render(0.35), solid=1.6, shadow=4.0)

def arbour() -> None:
    w, h = 3.6 * U, 2.8 * U; a = Art(w, h, 13)
    for x in (w * 0.1, w * 0.9):
        a.cyl(x, h * 0.2, h - 1, 3.0, 3.6, "wood", lo=0.25, hi=0.9)
    m = a.rect(2, h * 0.16, w - 2, h * 0.16 + 7, "wood", 0.6); a.lit_top(m, 0.2)
    back = a.rect(w * 0.14, h * 0.24, w * 0.86, h * 0.62, "wood", 0.3)
    lattice = ((a.X + a.Y) % 9 < 1.5) | ((a.X - a.Y) % 9 < 1.5)
    a.ramp[back & ~lattice] = -1
    for i in range(16):
        a.ball(a.rng.uniform(4, w - 4), h * a.rng.uniform(0.04, 0.26), a.rng.uniform(7, 12), a.rng.uniform(5, 8), "leaf", lo=0.15, hi=1.0)
    for i in range(7):
        a.ball(a.rng.uniform(8, w - 8), h * a.rng.uniform(0.1, 0.3), 2.2, 2.2, "night", lo=0.6, hi=1.0)
    b = a.rect(w * 0.2, h * 0.74, w * 0.8, h * 0.80, "wood", 0.7); a.lit_top(b, 0.2)
    for x in (w * 0.24, w * 0.74):
        a.rect(x, h * 0.80, x + 5, h - 1, "wood", 0.4)
    a.grain(0.08, 3)
    save("arbour", a.render(0.3), shadow=3.2)

def pedestal() -> None:
    w, h = 1.3 * U, 1.1 * U; a = Art(w, h, 14)
    m = a.rect(w * 0.18, h * 0.2, w * 0.82, h - 7, "stone", 0.55); a.sh[m & (a.X > w * 0.6)] -= 0.2; a.sh[m & (a.X < w * 0.32)] += 0.18
    for y0, y1 in ((2, h * 0.22), (h - 9, h - 1)):
        t = a.rect(w * 0.06, y0, w * 0.94, y1, "stone", 0.7); a.lit_top(t, 0.18)
    a.grain(0.08, 4)
    save("pedestal", a.render(0.25), solid=0.6, shadow=1.2)

def wall_piece(name: str, h_u: float, seed: int, crenel: bool = True) -> None:
    w, h = 3.0 * U, h_u * U; a = Art(w, h, seed)
    top = 10 if crenel else 0
    m = a.rect(0, top, w, h, "stone", 0.56); a.bricks(m, 16, 8, 0.2)
    if crenel:
        for x in np.arange(0, w, 24):
            c = a.rect(x, 0, x + 14, top + 1, "stone", 0.66, same=True); a.bricks(c, 16, 8, 0.2)
    a.sh += (np.clip((a.Y - h * 0.55) / h, 0, 1) * -0.35).astype(np.float32)
    a.lit_top(a.ramp >= 0, 0.2)
    a.grain(0.1, 5)
    im = a.render(0.3)
    im.save(ROOT / "assets" / "props" / f"k_{name}.png", optimize=True)
    PROPS[name] = {"w": round(im.width / U, 3), "h": round(im.height / U, 3), "solid": 0.0, "shadow": 0.0}

def stepping_stone() -> None:
    w, h = 2.2 * U, 1.5 * U; a = Art(w, h, 15)
    a.ball(w / 2, h / 2, w * 0.48, h * 0.46, "stone", lo=0.45, hi=0.95)
    a.grain(0.14, 6)
    cracks = noise(a.w, a.h, 4, 77) > 0.74
    a.sh[cracks & (a.ramp >= 0)] -= 0.2
    save("stepping_stone", a.render(0.3), flat=True)

def decal(name: str, ramp: str, seed: int, w_u: float = 2.4) -> None:
    """A ragged patch that lies flat on the ground: worn earth, a darker sward, scattered pebbles."""
    w = h = int(w_u * U); a = Art(w, h, seed)
    d = np.hypot((a.X - w / 2) / (w * 0.46), (a.Y - h / 2) / (h * 0.40))
    n = noise(w, h, 9, seed)
    m = d + (n - 0.5) * 0.7 < 0.8
    fine = np.tile(ak.BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    m &= d + (n - 0.5) * 0.7 + fine * 0.3 < 0.72
    a.put(m, ramp, 0.42 + (noise(w, h, 4, seed + 1) - 0.5) * 0.35)
    save(name, a.render(0.4, outline=False), flat=True)

def pebbles(name: str, seed: int) -> None:
    w, h = int(1.2 * U), int(0.9 * U); a = Art(w, h, seed)
    for i in range(6):
        a.ball(a.rng.uniform(6, w - 6), a.rng.uniform(5, h - 5), a.rng.uniform(2.5, 5), a.rng.uniform(2, 3.6), "stone", lo=0.3, hi=1.0)
    save(name, a.render(0.0), flat=True)

def eyes() -> None:
    a = Art(14, 6, 1)
    for x in (3, 10):
        a.ball(x, 3, 2.6, 2.2, "fire", lo=0.6, hi=0.6)
        a.rect(x - 0.6, 1.5, x + 0.6, 4.5, "fire", 1.0, flat=True)
    save("eyes", a.render(0.0, outline=False), glow="fire")

def signpost() -> None:
    w, h = 1.4 * U, 1.9 * U; a = Art(w, h, 17)
    a.cyl(w / 2, h * 0.1, h - 1, 2.4, 2.8, "wood", lo=0.25, hi=0.9)
    m = a.poly([(w * 0.08, h * 0.16), (w * 0.8, h * 0.16), (w * 0.96, h * 0.27), (w * 0.8, h * 0.38), (w * 0.08, h * 0.38)], "wood", 0.72); a.planks(m, 6, 0.1, across=True)
    a.rect(w * 0.2, h * 0.25, w * 0.66, h * 0.25 + 2, "dark", 0.2); a.rect(w * 0.2, h * 0.31, w * 0.5, h * 0.31 + 2, "dark", 0.2)
    save("signpost", a.render(0.2), solid=0.2, shadow=0.7)

def waymark() -> None:
    w, h = 0.9 * U, 1.4 * U; a = Art(w, h, 23)
    a.cyl(w / 2, h * 0.2, h - 1, 2.2, 2.6, "wood", lo=0.25, hi=0.9)
    m = a.rect(w * 0.08, h * 0.2, w * 0.92, h * 0.46, "wood", 0.74); a.planks(m, 5, 0.1, across=True)
    a.rect(w * 0.2, h * 0.28, w * 0.7, h * 0.28 + 2, "dark", 0.2); a.rect(w * 0.2, h * 0.36, w * 0.56, h * 0.36 + 2, "dark", 0.2)
    a.ball(w / 2, h * 0.1, 3.4, 3.4, "water", lo=0.7, hi=1.0)
    save("waymark", a.render(0.2), shadow=0.6)

def burden() -> None:
    w, h = 0.9 * U, 0.8 * U; a = Art(w, h, 24)
    a.ball(w / 2, h * 0.58, w * 0.44, h * 0.4, "dark", lo=0.3, hi=1.0)
    a.ball(w * 0.4, h * 0.4, w * 0.26, h * 0.26, "dark", lo=0.3, hi=1.0)
    a.stroke([(w * 0.2, h * 0.5), (w * 0.5, h * 0.62), (w * 0.82, h * 0.48)], "wood", 0.6, 2)
    a.stroke([(w * 0.5, h * 0.2), (w * 0.5, h * 0.95)], "wood", 0.6, 2)
    a.grain(0.1, 3)
    save("burden", a.render(0.2))

def trellis() -> None:
    w, h = 2.6 * U, 1.9 * U; a = Art(w, h, 18)
    for x in (w * 0.1, w * 0.9):
        a.cyl(x, h * 0.12, h - 1, 2.6, 3.0, "wood", lo=0.25, hi=0.9)
    m = a.rect(2, h * 0.1, w - 2, h * 0.1 + 6, "wood", 0.62); a.lit_top(m, 0.2)
    a.stroke([(w * 0.14, h - 2), (w * 0.3, h * 0.5), (w * 0.5, h * 0.3), (w * 0.7, h * 0.24), (w * 0.86, h * 0.2)], "leaf", 0.3, 2.5)
    for i in range(12):
        f = i / 11
        a.ball(w * (0.16 + 0.7 * f) + a.rng.uniform(-4, 4), h * (0.62 - 0.42 * f ** 0.6) + a.rng.uniform(-5, 5), 6.5, 4.5, "leaf", lo=0.2, hi=1.0)
    save("trellis", a.render(0.3), shadow=2.2)

def table_set(name: str, kind: str) -> None:
    """Furniture for the Interpreter's rooms and the House Beautiful."""
    w, h = 2.4 * U, 1.5 * U; a = Art(w, h, 19)
    if kind == "table":
        t = a.poly([(w * 0.1, h * 0.36), (w * 0.9, h * 0.36), (w * 0.98, h * 0.52), (w * 0.02, h * 0.52)], "wood", 0.78); a.planks(t, 9, 0.1)
        a.rect(w * 0.02, h * 0.52, w * 0.98, h * 0.6, "wood", 0.42)
        for x in (w * 0.06, w * 0.88):
            a.rect(x, h * 0.6, x + 6, h - 1, "wood", 0.36)
    elif kind == "chairs":
        for x in (w * 0.14, w * 0.62):
            a.rect(x, h * 0.1, x + w * 0.22, h * 0.5, "wood", 0.5); a.planks(a.pid == a.n, 6, 0.14)
            s = a.rect(x - 2, h * 0.5, x + w * 0.22 + 2, h * 0.6, "wood", 0.75); a.lit_top(s, 0.15)
            for lx in (x, x + w * 0.22 - 4):
                a.rect(lx, h * 0.6, lx + 4, h - 1, "wood", 0.36)
    elif kind == "hearth":
        m = a.rect(w * 0.06, h * 0.06, w * 0.94, h - 1, "stone", 0.55); a.bricks(m, 12, 6, 0.2)
        a.ball(w / 2, h * 0.74, w * 0.26, h * 0.5, "dark", lo=0.0, hi=0.0); a.rect(w * 0.24, h * 0.74, w * 0.76, h - 1, "dark", 0.0, same=True)
        for i, (r, s) in enumerate(((13, 0.55), (9, 0.75), (5, 1.0))):
            a.ball(w / 2, h - 6 - i * 3, r, r * 1.25, "fire", lo=s, hi=s)
        a.rect(w * 0.02, 1, w * 0.98, h * 0.1, "wood", 0.7)
    elif kind == "picture":
        f = a.rect(w * 0.22, 1, w * 0.78, h - 1, "gold", 0.6); a.lit_top(f, 0.2)
        a.rect(w * 0.27, 6, w * 0.73, h - 6, "water", 0.3, flat=True)
        a.ball(w * 0.5, h * 0.36, 6, 6, "skin", lo=0.6, hi=0.9)                      # a grave man with a book, eyes lifted
        a.poly([(w * 0.39, h - 6), (w * 0.43, h * 0.5), (w * 0.57, h * 0.5), (w * 0.61, h - 6)], "stone", 0.75)
        a.rect(w * 0.46, h * 0.66, w * 0.54, h * 0.76, "wood", 0.6)
    elif kind == "broom":
        a.stroke([(w * 0.3, h - 3), (w * 0.62, 3)], "wood", 0.6, 3)
        a.poly([(w * 0.2, h - 1), (w * 0.26, h * 0.72), (w * 0.38, h * 0.76), (w * 0.44, h - 1)], "dry", 0.7)
    elif kind == "coins":
        for i in range(14):
            a.ball(w * 0.5 + a.rng.uniform(-16, 16), h - 5 - a.rng.uniform(0, 12), 4, 2.6, "gold", lo=0.5, hi=1.0)
    elif kind == "armed":
        for x in (w * 0.18, w * 0.82):
            a.cyl(x, 2, h - 1, 6, 7, "stone", lo=0.3, hi=1.0)
        a.rect(w * 0.1, 0, w * 0.9, 8, "stone", 0.75)
        a.rect(w * 0.26, 8, w * 0.74, h - 1, "gold", 0.95, flat=True)
    a.grain(0.06, 3)
    save(name, a.render(0.2), shadow=2.0 if kind in ("table", "hearth", "armed") else 0.0, glow="fire" if kind == "hearth" else ("gold" if kind == "armed" else ""))

def well() -> None:
    w, h = 1.9 * U, 2.2 * U; a = Art(w, h, 21)
    for x in (w * 0.16, w * 0.84):
        a.cyl(x, h * 0.2, h * 0.7, 2.4, 2.4, "wood", lo=0.25, hi=0.9)
    a.poly([(w * 0.02, h * 0.26), (w * 0.5, 2), (w * 0.98, h * 0.26)], "wood", 0.5); a.planks(a.pid == a.n, 6, 0.14)
    m = (a.pid == a.n) & (a.X < w / 2); a.sh[m] += 0.2
    a.cyl(w / 2, h * 0.62, h - 1, w * 0.4, w * 0.4, "stone", lo=0.2, hi=0.95); a.bricks(a.pid == a.n, 10, 6, 0.2)
    a.ball(w / 2, h * 0.62, w * 0.4, 7, "stone", lo=0.7, hi=0.95); a.ball(w / 2, h * 0.63, w * 0.3, 4.5, "water", lo=0.2, hi=0.5)
    a.grain(0.08, 4)
    save("well", a.render(0.3), solid=0.8, shadow=1.8)

# ------------------------------------------------------------------ small creatures and plants that had only placeholders
def _strip(frames: list, path: str) -> None:
    w, h = max(f.width for f in frames), max(f.height for f in frames)
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * w + (w - f.width) // 2, h - f.height))
    sheet.save(ROOT / "assets" / "sprites" / path, optimize=True)

def creatures() -> None:
    frames = []
    for graze in (False, True):                          # the lamb: head up, head down
        w, h = 46, 34; a = Art(w, h, 31)
        for x in (12, 17, 27, 32):
            a.rect(x, h - 10, x + 3, h - 1, "dark", 0.3)
        a.ball(22, 17, 15, 10, "stone", lo=0.72, hi=1.1)
        for i in range(7):
            a.ball(10 + i * 4.2, 11 + (i % 2) * 2, 5, 4.5, "stone", lo=0.8, hi=1.15)
        hx, hy = (37, 22) if graze else (38, 11)
        a.ball(hx, hy, 6, 5, "skin", lo=0.55, hi=0.95)
        a.ball(hx - 4, hy - 3, 3, 2, "skin", lo=0.4, hi=0.6)
        a.rect(hx + 1, hy - 1, hx + 2.6, hy + 0.6, "dark", 0.0, flat=True)
        frames.append(a.render(0.15))
    _strip(frames, "npc_lamb.png")
    frames = []
    for k in (0, 1):                                     # the serpent: two bends of one body
        w, h = 58, 30; a = Art(w, h, 32)
        pts = [(4 + i * 4, h - 8 - math.sin(i * 0.8 + k * math.pi) * 6) for i in range(11)]
        a.stroke(pts, "leaf", 0.35, 6); a.stroke([(x, y - 1.5) for x, y in pts], "leaf", 0.7, 2)
        a.ball(pts[-1][0] + 5, pts[-1][1] - 4, 6, 4.5, "leaf", lo=0.3, hi=0.8)
        a.rect(pts[-1][0] + 6, pts[-1][1] - 6, pts[-1][0] + 8, pts[-1][1] - 4, "fire", 1.0, flat=True)
        frames.append(a.render(0.1))
    _strip(frames, "serpent.png")
    frames = []
    for bloom in (False, True):                          # the lily: drooping, then open
        w, h = 30, 44; a = Art(w, h, 33)
        top = (20, 20) if not bloom else (15, 10)
        a.stroke([(15, h - 1), (14, h * 0.6), top], "leaf", 0.5, 2.4)
        a.poly([(14, h - 4), (4, h - 16), (12, h - 12)], "leaf", 0.7); a.poly([(16, h - 6), (26, h - 18), (18, h - 13)], "leaf", 0.4)
        if bloom:
            for ang in range(0, 360, 60):
                a.ball(15 + math.cos(math.radians(ang)) * 6, 10 + math.sin(math.radians(ang)) * 5, 5, 4, "stone", lo=0.85, hi=1.15)
            a.ball(15, 10, 2.6, 2.6, "gold", lo=0.8, hi=1.0)
        else:
            a.ball(21, 23, 4, 6, "stone", lo=0.55, hi=0.85)
        frames.append(a.render(0.0))
    _strip(frames, "lily.png")

# ------------------------------------------------------------------ ground tiles (64 x 64, seamless)
T = 64
def tile(name: str, ramp: str, base: float, seed: int, kind: str = "grain", spread: float = 0.5) -> None:
    n1 = noise(T, T, 16, seed, wrap=True); n2 = noise(T, T, 4, seed + 1, wrap=True)
    sh = base + (n1 - 0.5) * spread * 0.45 + (n2 - 0.5) * spread * 0.3
    rng = np.random.default_rng(seed)
    Y, X = np.mgrid[0:T, 0:T]
    if kind == "grass":                       # short blades: a lighter pixel over a darker one
        for _ in range(70):
            x, y = rng.integers(0, T, 2)
            sh[y, x] += 0.24; sh[(y + 1) % T, x] -= 0.2
            if rng.random() < 0.4:
                sh[(y - 1) % T, (x + 1) % T] += 0.2
    elif kind == "cobble":
        pts = rng.random((26, 2)) * T
        best = np.full((T, T), 1e9); second = np.full((T, T), 1e9); who = np.zeros((T, T), int)
        for i, (px, py) in enumerate(pts):
            dx = np.minimum(np.abs(X - px), T - np.abs(X - px)); dy = np.minimum(np.abs(Y - py), T - np.abs(Y - py))
            d = np.hypot(dx, dy * 1.25)
            closer = d < best
            second = np.where(closer, best, np.minimum(second, d)); who = np.where(closer, i, who); best = np.where(closer, d, best)
        gap = second - best
        sh = base + ((who * 37 % 7) - 3) * 0.03 + (n2 - 0.5) * 0.06
        sh = np.where(gap < 1.6, base - (0.2 if base > 0.65 else 0.3), sh)
        sh = np.where((gap >= 1.6) & (gap < 3.0) & (Y + X < T * 2), sh + 0.08, sh)
    elif kind == "plank":
        sh = base + (((Y // 8) * 5 % 3) - 1) * 0.06 + (noise(T, T, 2, seed, wrap=True) - 0.5) * 0.12
        sh = np.where((Y % 8 == 0) | ((X + (Y // 8) * 23) % 32 == 0), base - 0.34, sh)
    elif kind == "brick":
        row = Y // 8; xo = (X + (row % 2) * 8) % 16
        sh = base + (((row * 3 + (X + (row % 2) * 8) // 16 * 5) % 5) - 2) * 0.05 + (n2 - 0.5) * 0.12
        sh = np.where((Y % 8 == 0) | (xo == 0), base - 0.34, sh)
    elif kind == "roof":
        row = Y // 8; xo = (X + (row % 2) * 6) % 12
        sh = base + (Y % 8) * -0.035 + (n2 - 0.5) * 0.1
        sh = np.where((Y % 8 == 0) | (xo == 0), base - 0.3, sh)
    elif kind == "water":
        sh = base + np.sin((Y + np.sin(X * math.tau / T * 2) * 3) * math.tau / T * 4) * 0.16 + (n1 - 0.5) * 0.2
    elif kind == "bark":
        sh = base + np.sin(X * math.tau / T * 9 + n1 * 5) * 0.2 + (n2 - 0.5) * 0.14
    elif kind == "leaves":
        for _ in range(90):
            x, y = rng.integers(0, T, 2)
            for dx, dy, v in ((0, 0, 0.3), (1, 0, 0.18), (0, 1, -0.16), (1, 1, -0.2)):
                sh[(y + dy) % T, (x + dx) % T] += v
    elif kind == "carpet":
        sh = base + ((X + Y) % 16 < 2) * 0.12 + ((X - Y) % 16 < 2) * 0.12 + (n2 - 0.5) * 0.08
    elif kind == "rock":
        cracks = noise(T, T, 8, seed + 3, wrap=True)
        sh = np.where(np.abs(cracks - 0.5) < 0.035, base - 0.34, sh)
    b = np.tile(ak.BAYER, (T // 4, T // 4))
    lv = np.clip(np.round(sh * 4.0 + 0.9 + b * 0.22), 1, 5).astype(int)
    idx = RAMP_IDX[RID[ramp], lv]
    ak.to_image(idx, np.ones((T, T), bool)).convert("RGB").save(ROOT / "assets" / "tiles" / f"{name}.png", optimize=True)

def tiles() -> None:
    tile("grass", "leaf", 0.60, 1, "grass", 0.34); tile("grass_dry", "dry", 0.62, 2, "grass", 0.3); tile("grass_dark", "leaf", 0.36, 3, "grass", 0.3)
    tile("marsh", "leaf", 0.26, 4, "grass", 0.44); tile("grass_night", "dusk", 0.40, 5, "grass", 0.3)
    tile("dirt", "wood", 0.60, 6, "grain", 0.34); tile("dirt_dark", "wood", 0.34, 7, "grain", 0.34); tile("pit", "dark", 0.22, 8, "rock", 0.3)
    tile("sand", "dry", 0.9, 9, "grain", 0.2); tile("rock", "stone", 0.42, 10, "rock", 0.4); tile("rock_dark", "dark", 0.42, 11, "rock", 0.3)
    tile("cobble", "stone", 0.62, 12, "cobble"); tile("cobble_dark", "stone", 0.40, 13, "cobble"); tile("cobble_warm", "sandstone", 0.78, 14, "cobble")
    tile("plank", "wood", 0.56, 15, "plank"); tile("wall", "stone", 0.60, 16, "brick"); tile("wall_dark", "stone", 0.38, 17, "brick")
    tile("roof", "cloth_red", 0.50, 18, "roof"); tile("water", "water", 0.52, 19, "water"); tile("water_dark", "night", 0.45, 20, "water"); tile("mire", "dusk", 0.42, 25, "water")
    tile("carpet", "cloth_red", 0.12, 24, "carpet")
    tile("bark", "wood", 0.42, 21, "bark"); tile("leaves", "leaf", 0.55, 22, "leaves", 0.4); tile("snow", "water", 0.94, 23, "grain", 0.16)
    # the mask that mixes two ground tiles into patches (see MapKit.ground)
    m = noise(128, 128, 32, 99, wrap=True) * 0.7 + noise(128, 128, 8, 98, wrap=True) * 0.3
    Image.fromarray((m * 255).astype(np.uint8), "L").save(ROOT / "assets" / "tiles" / "patch_mask.png")

# ------------------------------------------------------------------ far skylines (two layers each, for parallax)
def backdrop(name: str, ramp: str, seed: int, kind: str, levels=(1, 2)) -> None:
    W, H = 1024, 256
    X = np.arange(W)
    rng = np.random.default_rng(seed)
    def line(base, amp, rough):
        y = np.full(W, base, dtype=np.float64)
        for k, a in ((2, 1.0), (5, 0.5), (11, 0.25), (23, 0.12 * rough), (47, 0.07 * rough)):
            y += np.sin(X / W * math.tau * k + rng.uniform(0, math.tau)) * amp * a
        return y
    for layer, (base, amp, lv) in enumerate(((0.42, 46, levels[0]), (0.66, 30, levels[1]))):
        y = line(H * base, amp, 2.2 if kind == "crags" else 1.0)
        if kind == "crags":
            y -= np.abs(np.sin(X * 0.09 + rng.uniform(0, 6))) * 26
        if kind == "city":
            y = np.repeat(H * base + rng.uniform(-amp, amp, W // 24 + 1), 24)[:W]
            y[(X // 24) % 5 == 2] -= 34
        Y = np.arange(H)[:, None]
        solid = Y >= y[None, :]
        depth = (Y - y[None, :])
        sh = lv + np.where(depth < 5, 1, 0) - np.where(depth > 60, 1, 0) + (noise(W, H, 6, seed + layer) > 0.62) * (depth > 5)
        if kind == "mountains" and layer == 0:
            snow = solid & (depth < 16 + noise(W, H, 5, seed) * 14) & (y[None, :] < H * 0.36)
            sh = np.where(snow, 5, sh)
        if kind == "city" and layer == 1:
            win = solid & (X[None, :] % 12 == 4) & (Y % 14 == 3) & (depth > 6) & (noise(W, H, 3, seed + 4) > 0.55)
        idx = RAMP_IDX[RID[ramp], np.clip(sh, 1, 5).astype(int)]
        if kind == "city" and layer == 1:
            idx = np.where(win | np.roll(win, 1, axis=0), ak.NAMES.index("gold"), idx)
        ak.to_image(idx, solid).save(ROOT / "assets" / "props" / f"bd_{name}_{'far' if layer == 0 else 'near'}.png", optimize=True)

def main() -> int:
    (ROOT / "assets" / "props").mkdir(parents=True, exist_ok=True)
    tiles(); creatures()
    for flora, ramp in (("green", "leaf"), ("dry", "dry"), ("night", "dusk"), ("dark", "dark")):
        tree(f"tree_{flora}_a", ramp, 11, "round"); tree(f"tree_{flora}_b", ramp, 12, "tall"); tree(f"tree_{flora}_c", ramp, 13, "round")
        tree(f"bush_{flora}", ramp, 14, "bush")
        tuft(f"tuft_{flora}_a", ramp, 15); tuft(f"tuft_{flora}_b", ramp, 16)
    for i, c in enumerate(("gold", "cloth_red", "night", "stone", "cloth_blue")):
        tuft(f"flowers_{c}", "leaf", 20 + i, flowers=c)
    tree("tree_fig", "leaf", 17, "round", "night"); tree("tree_fruit", "leaf", 18, "round", "cloth_red"); tree("tree_life", "gold", 19, "round", "fire")
    reeds("reeds", 26)
    for i in range(3):
        dead_tree(f"dead_tree_{'abc'[i]}", 30 + i)
    for c in ("night", "cloth_red", "water", "gold", "leaf"):
        mushroom(f"mushroom_{c}", c, 40)
        crystal(f"crystal_{c}", c, 41)
    rock("rock_a", 0.9, 0.6, 50); rock("rock_b", 1.4, 0.9, 51, moss=True, solid=0.5); rock("rock_c", 2.2, 1.5, 52, solid=0.9); rock("rock_dark", 1.6, 1.1, 53, "dark", solid=0.6)
    spire("spire_a", 5.0, 60); spire("spire_b", 7.0, 61); spire("spire_stone", 5.5, 62, "stone")
    menhir("menhir_a", 2.4, 70); menhir("menhir_b", 3.1, 71); menhir("menhir_c", 1.8, 72)
    for ramp_name, ramp in (("stone", "stone"), ("dark", "dark"), ("earth", "wood")):
        for i in range(3):
            cliff(f"cliff_{ramp_name}_{'abc'[i]}", 5.5, 4.2 + i * 0.9, 80 + i, ramp)
        cliff(f"cliff_{ramp_name}_low", 5.5, 2.2, 84, ramp)
    for cap in ("leaf", "water"):       # grass-topped and snow-topped
        for i in range(2):
            cliff(f"cliff_{'grass' if cap == 'leaf' else 'snow'}_{'ab'[i]}", 5.5, 4.4 + i, 90 + i, "stone" if cap == "water" else "wood", cap)
        cliff(f"cliff_{'grass' if cap == 'leaf' else 'snow'}_low", 5.5, 2.2, 94, "stone" if cap == "water" else "wood", cap)
    pillar("pillar", 4.2, False, 100); pillar("pillar_broken_a", 2.6, True, 101); pillar("pillar_broken_b", 1.5, True, 102)
    lamp("lamp", "fire"); lamp("lamp_cold", "water"); torch("torch")
    for c in ("cloth_red", "cloth_blue", "night", "gold", "leaf"):
        banner(f"banner_{c}", c)
    fence("fence"); crate("crate", False); crate("barrel", True)
    house("house_a", 1); house("house_b", 2, "cloth_blue"); house("house_c", 3, "wood"); house("house_dark", 4, "dark", lit=True)
    cross_prop(); tomb(); arbour(); pedestal(); stepping_stone(); eyes(); signpost(); trellis(); well(); waymark(); burden()
    wall_piece("wall", 2.4, 110); wall_piece("wall_high", 4.6, 111); wall_piece("wall_low", 1.2, 112, crenel=False)
    for k in ("table", "chairs", "hearth", "picture", "broom", "coins", "armed"):
        table_set(k, k)
    for i, r in enumerate(("wood", "dry", "leaf", "dark", "night", "stone")):
        decal(f"patch_{r}_a", r, 120 + i); decal(f"patch_{r}_b", r, 130 + i, 3.4)
    pebbles("pebbles_a", 140); pebbles("pebbles_b", 141)
    backdrop("hills", "leaf", 1, "hills", (2, 3)); backdrop("mountains", "water", 2, "mountains", (2, 3)); backdrop("crags", "night", 3, "crags", (1, 2)); backdrop("city", "dark", 4, "city", (2, 3))
    ak.shadow_blob().save(ROOT / "assets" / "fx" / "shadow.png")
    (ROOT / "data" / "props.json").write_text(json.dumps(dict(sorted(PROPS.items())), indent=1) + "\n")
    print(f"gen_world: {len(PROPS)} props, tiles and backdrops written")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
