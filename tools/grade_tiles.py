#!/usr/bin/env python3
"""Tone down the generated ground tiles so maps are not garish (run after tools/gen_assets.py).

    python3 tools/grade_tiles.py

Each tile is desaturated and slightly darkened once; a PNG text tag marks graded files so a
second run changes nothing.
"""
from pathlib import Path
from PIL import Image, ImageEnhance, PngImagePlugin

TILES = Path(__file__).resolve().parent.parent / "assets" / "tiles"
GRADE = {"grass": (0.62, 0.9), "dirt": (0.55, 0.92), "cobble": (0.5, 0.95), "roof": (0.7, 0.95), "leaves": (0.75, 0.95), "wall": (0.8, 1.0), "bark": (0.8, 1.0)}

def main() -> None:
    for name, (sat, bright) in GRADE.items():
        p = TILES / f"{name}.png"
        im = Image.open(p)
        if im.info.get("graded") == "1":
            continue
        out = ImageEnhance.Brightness(ImageEnhance.Color(im.convert("RGB")).enhance(sat)).enhance(bright)
        if im.mode == "RGBA":
            out.putalpha(im.getchannel("A"))
        meta = PngImagePlugin.PngInfo(); meta.add_text("graded", "1")
        out.save(p, pnginfo=meta)
        print("graded", name)

if __name__ == "__main__":
    main()
