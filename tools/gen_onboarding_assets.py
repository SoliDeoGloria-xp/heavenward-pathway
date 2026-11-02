#!/usr/bin/env python3
"""Placeholder art for the onboarding pass (Dreamer guide, Eden lilies, the Fall scene).

ORIGINAL procedural placeholder art in the same style as gen_assets.py. Replace with the
commissioned art and keep the file names and sizes:
  portraits/dreamer.png   256x320 bust (guide cut-in, also used small in coach bubbles)
  portraits/pilgrim.png   256x320 neutral pilgrim bust (player side of conversations)
  sprites/serpent.png     2 frames 48x32 (idle sway)
  sprites/lily.png        2 frames 24x32 (0 drooping, 1 in bloom)
  fx/cherub.png           128x128 winged light (cherubim are never shown with faces)
  fx/flame_sword.png      32x128 flaming blade
  icons/tend.png, icons/guide.png  64x64
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
import gen_assets as ga


def rimmed(im, col=(34, 24, 40, 255), grow=5):
    a = im.split()[3].filter(ImageFilter.MaxFilter(grow))
    rim = Image.new('RGBA', im.size, col); rim.putalpha(a)
    rim.alpha_composite(im)
    return rim


def portrait_dreamer():
    """John Bunyan's narrator: brown travelling hood, grey beard, quill and open book."""
    W, H = 256, 320
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
    g.polygon([(24, 320), (52, 196), (128, 168), (204, 196), (232, 320)], fill=(112, 84, 56, 255))      # cloak
    g.polygon([(52, 150), (128, 22), (204, 150), (196, 210), (60, 210)], fill=(98, 72, 48, 255))       # hood
    g.ellipse((80, 70, 176, 182), fill=(232, 196, 164, 255))                                          # face
    g.pieslice((80, 110, 176, 220), 0, 180, fill=(196, 190, 178, 255))                               # beard
    g.ellipse((101, 112, 113, 122), fill=ga.EYE); g.ellipse((143, 112, 155, 122), fill=ga.EYE)
    g.arc((100, 104, 116, 118), 200, 340, fill=(90, 70, 60, 255), width=3)                            # kind, sleepy lids
    g.arc((140, 104, 156, 118), 200, 340, fill=(90, 70, 60, 255), width=3)
    g.polygon([(56, 250), (128, 236), (128, 300), (56, 312)], fill=(250, 244, 226, 255))              # book
    g.polygon([(200, 250), (128, 236), (128, 300), (200, 312)], fill=(238, 230, 208, 255))
    for y in (254, 266, 278):
        g.line((70, y, 118, y - 6), fill=(150, 120, 80, 255), width=2)
    g.line((176, 210, 214, 150), fill=(240, 236, 226, 255), width=6)                                  # quill
    g.polygon([(214, 150), (226, 128), (206, 140)], fill=(240, 236, 226, 255))
    im = im.filter(ImageFilter.SMOOTH)
    rimmed(im).save(ga.out('portraits', 'dreamer.png'))


def portrait_pilgrim():
    W, H = 256, 320
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
    g.polygon([(30, 320), (60, 200), (128, 180), (196, 200), (226, 320)], fill=(79, 121, 184, 255))
    g.ellipse((76, 60, 180, 184), fill=(240, 206, 176, 255))
    g.chord((70, 40, 186, 150), 180, 360, fill=(106, 68, 40, 255))
    g.ellipse((102, 114, 114, 126), fill=ga.EYE); g.ellipse((142, 114, 154, 126), fill=ga.EYE)
    g.arc((112, 140, 144, 160), 20, 160, fill=(150, 90, 80, 255), width=3)
    g.line((206, 120, 172, 320), fill=(160, 112, 66, 255), width=10)
    im = im.filter(ImageFilter.SMOOTH)
    rimmed(im).save(ga.out('portraits', 'pilgrim.png'))


def serpent():
    W, H = 48, 32
    sheet = Image.new('RGBA', (W * 2, H), (0, 0, 0, 0))
    for f in range(2):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
        pts = []
        for i in range(24):
            x = 4 + i * 1.6
            y = 24 - i * 0.5 + math.sin(i * 0.55 + f * 1.2) * 4
            pts.append((x, y))
        g.line(pts, fill=(96, 128, 58, 255), width=5, joint='curve')
        hx, hy = pts[-1]
        g.ellipse((hx - 4, hy - 4, hx + 5, hy + 3), fill=(110, 140, 64, 255))
        g.point((hx + 2, hy - 2), fill=(240, 220, 90, 255))
        g.line((hx + 5, hy, hx + 8, hy + 1), fill=(200, 60, 50, 255))
        sheet.alpha_composite(ga.add_outline(ga.shade(im)), (f * W, 0))
    sheet.save(ga.out('sprites', 'serpent.png'))


def lily():
    W, H = 24, 32
    sheet = Image.new('RGBA', (W * 2, H), (0, 0, 0, 0))
    for f in range(2):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
        if f == 0:   # drooping, pale
            g.line((12, 31, 12, 16), fill=(118, 140, 80, 255), width=2)
            g.line((12, 16, 17, 20), fill=(118, 140, 80, 255), width=2)
            g.polygon([(15, 19), (21, 22), (18, 27), (14, 24)], fill=(214, 206, 180, 255))
            g.line((12, 26, 6, 22), fill=(118, 140, 80, 255), width=2)
        else:        # standing, white bloom
            g.line((12, 31, 12, 12), fill=(80, 150, 70, 255), width=2)
            g.line((12, 26, 5, 20), fill=(80, 150, 70, 255), width=2); g.line((12, 24, 19, 19), fill=(80, 150, 70, 255), width=2)
            for a in range(6):
                ang = math.radians(a * 60 - 90)
                g.ellipse((12 + math.cos(ang) * 4 - 3, 9 + math.sin(ang) * 4 - 3, 12 + math.cos(ang) * 4 + 3, 9 + math.sin(ang) * 4 + 3), fill=(255, 255, 250, 255))
            g.ellipse((10, 7, 14, 11), fill=(250, 214, 90, 255))
        sheet.alpha_composite(ga.add_outline(ga.shade(im, dark=0.9)), (f * W, 0))
    sheet.save(ga.out('sprites', 'lily.png'))


def cherub():
    S = 512
    big = Image.new('RGBA', (S, S), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    c = S // 2
    for side in (-1, 1):
        for k in range(4):
            r = 200 - k * 34
            box = (c + side * 40 - r, c - r + 30, c + side * 40 + r, c + r + 30)
            g.arc(box, 180 if side < 0 else 270, 270 if side < 0 else 360, fill=(255, 244, 210, 255 - k * 30), width=22)
    g.ellipse((c - 60, c - 60, c + 60, c + 60), fill=(255, 250, 230, 255))
    big = big.filter(ImageFilter.GaussianBlur(6))
    big.resize((128, 128), Image.LANCZOS).save(ga.out('fx', 'cherub.png'))


def flame_sword():
    W, H = 128, 512
    big = Image.new('RGBA', (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    g.polygon([(64, 8), (88, 360), (64, 420), (40, 360)], fill=(255, 140, 40, 255))
    g.polygon([(64, 60), (76, 340), (64, 390), (52, 340)], fill=(255, 236, 170, 255))
    g.rectangle((30, 420, 98, 436), fill=(200, 160, 70, 255)); g.rectangle((58, 436, 70, 500), fill=(120, 80, 40, 255))
    big = big.filter(ImageFilter.GaussianBlur(3))
    big.resize((32, 128), Image.LANCZOS).save(ga.out('fx', 'flame_sword.png'))


def icons():
    def tend(g, S):
        g.line((S * .5, S * .92, S * .5, S * .42), fill=(80, 150, 70, 255), width=int(S * .06))
        g.ellipse((S * .18, S * .38, S * .5, S * .62), fill=(110, 190, 90, 255))
        g.ellipse((S * .5, S * .26, S * .84, S * .52), fill=(110, 190, 90, 255))
        for i in range(4):
            x = S * (.22 + i * .14)
            g.ellipse((x, S * .06 + (i % 2) * S * .06, x + S * .07, S * .16 + (i % 2) * S * .06), fill=(140, 200, 255, 255))
    def guide(g, S):
        g.ellipse((S * .1, S * .1, S * .9, S * .9), fill=(255, 236, 170, 255))
        g.ellipse((S * .18, S * .18, S * .82, S * .82), fill=(70, 100, 170, 255))
        g.polygon([(S * .5, S * .2), (S * .6, S * .5), (S * .5, S * .8), (S * .4, S * .5)], fill=(255, 236, 170, 255))
    ga.icon('tend', tend); ga.icon('guide', guide)


if __name__ == '__main__':
    portrait_dreamer(); portrait_pilgrim(); serpent(); lily(); cherub(); flame_sword(); icons()
    print('onboarding assets generated')
