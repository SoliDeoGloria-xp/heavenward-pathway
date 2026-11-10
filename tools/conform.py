#!/usr/bin/env python3
"""Hold every picture already in assets/ to the art bible (tools/artkit.py).

    python3 tools/conform.py            # rewrite what does not conform
    python3 tools/conform.py --check    # only report; exit 1 if anything is off (used by CI)

Icons, sprites, props and portraits are sent through finish(): hard alpha, the 32 colours, the
ink outline. Running it again changes nothing. Light effects (assets/fx) keep their soft alpha:
they are light, not objects, and are tinted from the palette by the game. Fonts and audio are
not pictures. Requires Pillow, numpy, scipy.
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from artkit import finish, quantize, off_palette

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ["assets/icons", "assets/sprites", "assets/props", "assets/portraits"]     # silhouettes: palette + outline
FILLED = ["assets/tiles", "assets/ui"]                                                # full canvases and frames: palette only
SKIP = {"patch_mask.png"}

def soft(im: Image.Image) -> bool:
    a = np.asarray(im.convert("RGBA"))[..., 3]
    return bool(((a > 0) & (a < 255)).any())

def main() -> int:
    check = "--check" in sys.argv
    bad, fixed = [], 0
    for folder in SPRITES + FILLED:
        for f in sorted((ROOT / folder).rglob("*.png")):
            if f.name in SKIP:
                continue
            im = Image.open(f)
            sprite = folder in SPRITES
            if off_palette(im) == 0 and not (sprite and soft(im)):
                continue
            bad.append(f.relative_to(ROOT).as_posix())
            if not check:
                out = finish(im, ramp=False) if sprite else quantize(im)
                if folder == "assets/ui" and soft(im):          # frames may keep flat see-through panels
                    out.putalpha(im.convert("RGBA").getchannel("A"))
                out.save(f, optimize=True); fixed += 1
    if check:
        print(f"conform: {len(bad)} picture(s) off the art bible" + (": " + ", ".join(bad[:12]) if bad else ""))
        return 1 if bad else 0
    print(f"conform: {fixed} picture(s) brought to the palette and outline")
    return 0

if __name__ == "__main__":
    sys.exit(main())
