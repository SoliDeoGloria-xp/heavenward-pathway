#!/usr/bin/env python3
"""Generate placeholder pixel-art and UI assets for the Pilgrim's Progress Online Godot demo.

All art here is ORIGINAL placeholder art drawn procedurally. It is meant to be replaced
by the commissioned sprite/UI art (Art Asset Brief v2). File names and sheet layouts are
the contract the game code relies on; keep them when replacing art.

Sprite sheet contract (characters):
  frame 32x48 px, 10 columns x 5 rows
  rows    = directions: 0 S, 1 SW, 2 W, 3 NW, 4 N   (E-side directions are mirrored in code)
  columns = 0 idle, 1-4 walk, 5-6 attack, 7 sit, 8 rest(KO), 9 cast
  layers  = body (skin, legs, face), robe (greyscale, tinted), hair_<n> (greyscale, tinted), staff
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets')
random.seed(7)

def out(*p):
    path = os.path.join(ROOT, *p)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path

OUTLINE = (34, 24, 30, 255)

def add_outline(img, color=OUTLINE):
    """1px outline around opaque pixels (8-neighbour), pixel-art style."""
    w, h = img.size
    src = img.load()
    res = img.copy()
    dst = res.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                continue
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                nx, ny = x+dx, y+dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                    dst[x, y] = color
                    break
    return res

def shade(img, light=(1.12), dark=0.78, split=0.55):
    """Cel shade: right/bottom part darker, top-left lighter (2-3 tones)."""
    w, h = img.size
    px = img.load()
    ys = [y for y in range(h) for x in range(w) if px[x, y][3] > 0]
    xs = [x for y in range(h) for x in range(w) if px[x, y][3] > 0]
    if not xs:
        return img
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or (r, g, b) == OUTLINE[:3]:
                continue
            fx = (x - x0) / max(1, x1 - x0)
            fy = (y - y0) / max(1, y1 - y0)
            k = 1.0
            if fx + fy * 0.6 > split + 0.55:
                k = dark
            elif fx + fy < 0.35:
                k = light
            px[x, y] = (min(255, int(r*k)), min(255, int(g*k)), min(255, int(b*k)), a)
    return img

# ---------------------------------------------------------------- characters
FW, FH, COLS, ROWS = 32, 48, 10, 5
SKIN = (246, 215, 188, 255)
LEG = (110, 76, 48, 255)
EYE = (42, 32, 48, 255)
BLUSH = (232, 150, 140, 255)
GREY_ROBE = (225, 225, 225, 255)
GREY_HAIR = (205, 205, 205, 255)
STAFF = (154, 112, 70, 255)

def frame_pose(col):
    """Return pose parameters for a column."""
    p = dict(bob=0, legA=0, legB=0, sit=False, rest=False, atk=0, cast=False)
    if 1 <= col <= 4:
        ph = col - 1
        p['bob'] = -1 if ph in (1, 3) else 0
        p['legA'] = [0, -2, 0, 2][ph]
        p['legB'] = -p['legA']
    elif col in (5, 6):
        p['atk'] = 1 if col == 5 else 2
    elif col == 7:
        p['sit'] = True
    elif col == 8:
        p['rest'] = True
    elif col == 9:
        p['cast'] = True
    return p

def draw_char_layer(layer, d, col, hair_style=0):
    """Draw one layer for direction d (0..4) and column col into a 32x48 RGBA image."""
    im = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    if frame_pose(col)['rest']:
        side = draw_char_layer(layer, 2, 0, hair_style)
        # lie down: rotate the side idle frame and drop it to the ground
        rot = side.rotate(90, expand=True)  # 48x32
        im2 = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
        rot = rot.resize((32, 21), Image.NEAREST)
        im2.alpha_composite(rot, (0, FH - 23))
        return im2
    p = frame_pose(col)
    g = ImageDraw.Draw(im)
    cx = 16
    bob = p['bob'] + (6 if p['sit'] else 0)
    side = d in (1, 2, 3)
    back = d in (3, 4)
    # body geometry
    head = (6, 4 + bob, 26, 24 + bob)
    if layer == 'body':
        # legs
        if p['sit']:
            g.rectangle((9, 41, 23, 44), fill=LEG)
        else:
            if d == 2:
                g.rectangle((13 + p['legA'], 39 + bob, 16 + p['legA'], 46), fill=LEG)
                g.rectangle((16 + p['legB'], 39 + bob, 19 + p['legB'], 46), fill=LEG)
            else:
                g.rectangle((11, 39 + bob, 14, 46 + min(0, p['legA'])), fill=LEG)
                g.rectangle((18, 39 + bob, 21, 46 + min(0, p['legB'])), fill=LEG)
        # hands
        if p['cast']:
            g.ellipse((5, 22 + bob, 9, 26 + bob), fill=SKIN)
            g.ellipse((23, 22 + bob, 27, 26 + bob), fill=SKIN)
        elif not back or d == 3:
            hx = 24 if d in (0, 1) else (20 if d == 2 else 24)
            g.ellipse((hx, 30 + bob - p['atk']*2, hx + 4, 34 + bob - p['atk']*2), fill=SKIN)
            if d == 0:
                g.ellipse((5, 31 + bob, 9, 35 + bob), fill=SKIN)
        # head
        g.ellipse(head, fill=SKIN)
        if not back:
            ex = {0: (11, 19), 1: (9, 16), 2: (8, None)}[d]
            ey = 15 + bob
            for x in ex:
                if x is None:
                    continue
                g.rectangle((x, ey, x + 1, ey + 3), fill=EYE)
                g.point((x, ey), fill=(255, 255, 255, 255))
            if d == 0:
                g.rectangle((8, 20 + bob, 10, 20 + bob), fill=BLUSH)
                g.rectangle((22, 20 + bob, 24, 20 + bob), fill=BLUSH)
                g.point((16, 21 + bob), fill=(140, 70, 60, 255))
            elif d == 1:
                g.rectangle((6, 20 + bob, 8, 20 + bob), fill=BLUSH)
    elif layer == 'robe':
        top, bot = 25 + bob, (40 if not p['sit'] else 42)
        if side:
            g.polygon([(12, top), (20, top), (24, bot), (8, bot)], fill=GREY_ROBE)
        else:
            g.polygon([(11, top), (21, top), (25, bot), (7, bot)], fill=GREY_ROBE)
        # belt + collar detail (darker greys survive tint as shading)
        g.line((8, bot - 7, 24, bot - 7), fill=(160, 160, 160, 255))
        if not back:
            g.line((16, top, 16, bot - 8), fill=(250, 250, 250, 255))
        # sleeves
        if p['cast']:
            g.polygon([(10, top + 1), (6, top - 1), (7, top + 4)], fill=GREY_ROBE)
            g.polygon([(22, top + 1), (26, top - 1), (25, top + 4)], fill=GREY_ROBE)
        else:
            g.rectangle((7, top + 2, 10, top + 9), fill=(205, 205, 205, 255))
            g.rectangle((22, top + 2, 25, top + 9), fill=(205, 205, 205, 255))
    elif layer.startswith('hair'):
        if back:
            g.ellipse((5, 3 + bob, 27, 23 + bob), fill=GREY_HAIR)
        elif d == 2:
            g.chord((5, 3 + bob, 27, 23 + bob), 180, 360, fill=GREY_HAIR)
            g.rectangle((15, 6 + bob, 26, 16 + bob), fill=GREY_HAIR)
        else:
            g.chord((5, 3 + bob, 27, 23 + bob), 180, 360, fill=GREY_HAIR)
            # fringe
            for i, x in enumerate(range(7, 26, 4)):
                g.polygon([(x, 10 + bob), (x + 4, 10 + bob), (x + 2, 13 + bob + (i % 2))], fill=GREY_HAIR)
            if d == 1:
                g.rectangle((20, 8 + bob, 26, 17 + bob), fill=GREY_HAIR)
        if hair_style == 1:  # long
            g.rectangle((5, 12 + bob, 9, 30 + bob), fill=GREY_HAIR)
            g.rectangle((23, 12 + bob, 27, 30 + bob), fill=GREY_HAIR)
            if back:
                g.rectangle((7, 14 + bob, 25, 32 + bob), fill=GREY_HAIR)
        elif hair_style == 2:  # tied
            if d in (2, 3, 4, 1):
                bx = {1: 24, 2: 25, 3: 22, 4: 16}[d]
                g.ellipse((bx - 4, 6 + bob, bx + 4, 14 + bob), fill=GREY_HAIR)
            else:
                g.ellipse((22, 2 + bob, 29, 9 + bob), fill=GREY_HAIR)
    elif layer == 'staff':
        if p['cast']:
            g.line((26, 4 + bob, 26, 30 + bob), fill=STAFF, width=2)
        elif d == 4:
            g.line((24, 8 + bob, 23, 44), fill=STAFF, width=2)
        else:
            a = p['atk']
            if a == 0:
                g.line((27, 6 + bob, 25, 46), fill=STAFF, width=2)
            elif a == 1:
                g.line((30, 10 + bob, 22, 40 + bob), fill=STAFF, width=2)
            else:
                g.line((31, 24 + bob, 12, 34 + bob), fill=STAFF, width=2)
    return im

def char_sheet(layer, hair_style=0):
    sheet = Image.new('RGBA', (FW * COLS, FH * ROWS), (0, 0, 0, 0))
    for d in range(ROWS):
        for c in range(COLS):
            fr = draw_char_layer(layer, d, c, hair_style)
            if layer != 'staff':
                fr = shade(fr)
            fr = add_outline(fr)
            sheet.alpha_composite(fr, (c * FW, d * FH))
    return sheet

def build_characters():
    char_sheet('body').save(out('sprites', 'pilgrim_body.png'))
    char_sheet('robe').save(out('sprites', 'pilgrim_robe.png'))
    for hs in range(3):
        char_sheet('hair', hs).save(out('sprites', 'pilgrim_hair_%d.png' % hs))
    char_sheet('staff').save(out('sprites', 'pilgrim_staff.png'))

# ---------------------------------------------------------------- NPCs / mobs
def npc_evangelist():
    """Single front-facing sheet (5 dirs x idle) reusing the pilgrim body with a dark robe and beard."""
    sheet = Image.new('RGBA', (FW * 2, FH * ROWS), (0, 0, 0, 0))
    for d in range(ROWS):
        for c in range(2):
            col = 0 if c == 0 else 2  # idle, mid-walk (breathing bob)
            body = draw_char_layer('body', d, col)
            robe = draw_char_layer('robe', d, col)
            robe = tint(robe, (60, 74, 120))
            hair = tint(draw_char_layer('hair', d, col, 0), (230, 226, 214))
            fr = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
            fr.alpha_composite(shade(body)); fr.alpha_composite(shade(robe)); fr.alpha_composite(shade(hair))
            g = ImageDraw.Draw(fr)
            if d in (0, 1):  # beard + book
                g.pieslice((9, 12, 23, 30), 0, 180, fill=(232, 228, 216, 255))
                g.rectangle((19, 28, 25, 35), fill=(255, 247, 224, 255))
                g.line((19, 28, 19, 35), fill=(184, 147, 62, 255))
            g.line((16, 23, 16, 40), fill=(200, 166, 74, 255))
            fr = add_outline(fr)
            sheet.alpha_composite(fr, (c * FW, d * FH))
    sheet.save(out('sprites', 'npc_evangelist.png'))

def tint(img, rgb):
    px = img.load()
    w, h = img.size
    res = img.copy(); q = res.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a:
                q[x, y] = (r * rgb[0] // 255, g * rgb[1] // 255, b * rgb[2] // 255, a)
    return res

def mob_slothling():
    """7 frames, 40x36: 0-1 idle, 2-3 move, 4 hurt, 5-6 fade-out (die)."""
    W, H = 40, 36
    sheet = Image.new('RGBA', (W * 7, H), (0, 0, 0, 0))
    for f in range(7):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
        squash = [0, 2, 1, -1, 0, 0, 0][f]
        top = 6 + squash
        body = (150, 160, 128, 255) if f != 4 else (220, 160, 150, 255)
        g.ellipse((4, top, 36, 40 + squash), fill=body)
        g.rectangle((4, 24, 36, 33), fill=body)
        g.ellipse((8, top + 4, 18, top + 9), fill=(196, 204, 172, 255))  # highlight
        # sleepy eyes
        ey = top + 13
        g.arc((10, ey - 2, 17, ey + 3), 20, 160, fill=EYE, width=1)
        g.arc((23, ey - 2, 30, ey + 3), 20, 160, fill=EYE, width=1)
        g.ellipse((17, ey + 6, 23, ey + 10), fill=(110, 70, 74, 255))
        im = im.crop((0, 0, W, H))
        im = add_outline(shade(im))
        if f >= 5:
            a = 150 if f == 5 else 60
            px = im.load()
            for y in range(H):
                for x in range(W):
                    r, gg, b, al = px[x, y]
                    if al:
                        px[x, y] = (min(255, r + 60), min(255, gg + 60), min(255, b + 60), min(al, a))
        sheet.alpha_composite(im, (f * W, 0))
    sheet.save(out('sprites', 'mob_slothling.png'))

def lamb():
    W, H = 34, 28
    sheet = Image.new('RGBA', (W * 2, H), (0, 0, 0, 0))
    for f in range(2):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
        b = f
        g.rectangle((9, 19, 11, 26), fill=(60, 50, 46, 255)); g.rectangle((20, 19, 22, 26), fill=(60, 50, 46, 255))
        for (x, y, r) in ((10, 12, 6), (16, 10, 7), (22, 12, 6), (14, 16, 6), (20, 16, 6)):
            g.ellipse((x - r, y - r + b, x + r, y + r + b), fill=(252, 250, 242, 255))
        g.ellipse((24, 6 + b, 32, 14 + b), fill=(70, 60, 56, 255))
        g.point((29, 9 + b), fill=(255, 255, 255, 255))
        im = add_outline(shade(im, dark=0.9))
        sheet.alpha_composite(im, (f * W, 0))
    sheet.save(out('sprites', 'npc_lamb.png'))

def portrait_evangelist():
    """Large NPC cut-in portrait (placeholder bust), 256x320, soft painted look."""
    W, H = 256, 320
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
    g.polygon([(30, 320), (60, 200), (128, 176), (196, 200), (226, 320)], fill=(52, 66, 112, 255))
    g.polygon([(110, 186), (146, 186), (138, 320), (118, 320)], fill=(200, 166, 74, 255))
    g.ellipse((70, 50, 186, 180), fill=(236, 200, 168, 255))
    g.pieslice((66, 90, 190, 230), 0, 180, fill=(236, 232, 222, 255))
    g.chord((62, 34, 194, 150), 180, 360, fill=(232, 228, 218, 255))
    g.ellipse((96, 104, 110, 116), fill=EYE); g.ellipse((146, 104, 160, 116), fill=EYE)
    g.line((92, 96, 114, 92), fill=(200, 196, 186, 255), width=4); g.line((142, 92, 164, 96), fill=(200, 196, 186, 255), width=4)
    g.rectangle((150, 236, 206, 300), fill=(255, 247, 224, 255)); g.line((150, 236, 150, 300), fill=(184, 147, 62, 255), width=4)
    im = im.filter(ImageFilter.SMOOTH)
    # dark rim
    alpha = im.split()[3].filter(ImageFilter.MaxFilter(5))
    rim = Image.new('RGBA', (W, H), (34, 24, 40, 255)); rim.putalpha(alpha)
    rim.alpha_composite(im)
    rim.save(out('portraits', 'evangelist.png'))

# ---------------------------------------------------------------- tiles
def noise_tile(base, specks, size=64, tufts=None):
    im = Image.new('RGBA', (size, size), base)
    px = im.load()
    for _ in range(size * size // 3):
        x, y = random.randrange(size), random.randrange(size)
        c = random.choice(specks)
        px[x, y] = c
    if tufts:
        g = ImageDraw.Draw(im)
        for _ in range(10):
            x, y = random.randrange(size), random.randrange(size)
            col = random.choice(tufts)
            for dx in (-1, 0, 1):
                xx = (x + dx) % size
                g.line((xx, y, xx + dx, (y - 2 - abs(dx))), fill=col)
    return im

def build_tiles():
    grass = noise_tile((112, 176, 76, 255), [(98, 160, 64, 255), (126, 190, 86, 255), (104, 168, 70, 255)],
                       tufts=[(84, 140, 52, 255), (148, 206, 100, 255)])
    g = ImageDraw.Draw(grass)
    for _ in range(4):
        x, y = random.randrange(64), random.randrange(64)
        g.point((x, y), fill=random.choice([(250, 230, 110, 255), (244, 150, 190, 255), (255, 255, 255, 255)]))
    grass.save(out('tiles', 'grass.png'))
    dirt = noise_tile((196, 168, 112, 255), [(180, 150, 96, 255), (210, 184, 128, 255)])
    dirt.save(out('tiles', 'dirt.png'))
    cob = Image.new('RGBA', (64, 64), (120, 110, 96, 255)); g = ImageDraw.Draw(cob)
    for row in range(4):
        off = 8 if row % 2 else 0
        for col in range(5):
            x = col * 16 - off; y = row * 16
            c = random.choice([(170, 160, 140), (160, 150, 132), (182, 172, 150)])
            for xx in (x, x + 64):
                g.rounded_rectangle((xx + 1, y + 1, xx + 14, y + 14), 3, fill=c + (255,))
                g.line((xx + 2, y + 2, xx + 10, y + 2), fill=(200, 192, 172, 255))
    cob.save(out('tiles', 'cobble.png'))
    water = noise_tile((86, 160, 210, 255), [(110, 182, 226, 255), (76, 146, 198, 255)])
    g = ImageDraw.Draw(water)
    for _ in range(6):
        x, y = random.randrange(64), random.randrange(64)
        g.line((x, y, x + 6, y), fill=(200, 232, 250, 255))
    water.save(out('tiles', 'water.png'))
    roof = Image.new('RGBA', (64, 64), (150, 70, 52, 255)); g = ImageDraw.Draw(roof)
    for y in range(0, 64, 8):
        g.line((0, y, 64, y), fill=(110, 48, 36, 255))
        for x in range((y // 8 % 2) * 8, 64, 16):
            g.line((x, y, x, y + 8), fill=(120, 56, 40, 255))
    roof.save(out('tiles', 'roof.png'))
    wall = noise_tile((200, 186, 150, 255), [(188, 174, 140, 255), (210, 198, 164, 255)])
    g = ImageDraw.Draw(wall)
    for y in range(0, 64, 16):
        g.line((0, y, 64, y), fill=(150, 132, 100, 255))
    wall.save(out('tiles', 'wall.png'))
    leaf = noise_tile((80, 150, 62, 255), [(64, 128, 50, 255), (104, 176, 80, 255), (120, 190, 92, 255)])
    leaf.save(out('tiles', 'leaves.png'))
    bark = noise_tile((112, 80, 52, 255), [(96, 66, 42, 255), (130, 96, 64, 255)])
    bark.save(out('tiles', 'bark.png'))

# ---------------------------------------------------------------- UI kit
def grad(w, h, c0, c1):
    im = Image.new('RGBA', (w, h))
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(4))
        ImageDraw.Draw(im).line((0, y, w, y), fill=c)
    return im

def rounded_mask(w, h, r):
    m = Image.new('L', (w * 4, h * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * 4 - 1, h * 4 - 1), r * 4, fill=255)
    return m.resize((w, h), Image.LANCZOS)

def panel(name, w, h, r, c0, c1, border, inner=(255, 255, 255, 140)):
    body = grad(w, h, c0, c1)
    m = rounded_mask(w, h, r)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); im.paste(body, (0, 0), m)
    g = ImageDraw.Draw(im)
    big = Image.new('RGBA', (w * 4, h * 4), (0, 0, 0, 0))
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * 4 - 1, h * 4 - 1), r * 4, outline=border, width=5)
    ImageDraw.Draw(big).rounded_rectangle((6, 6, w * 4 - 7, h * 4 - 7), max(1, r * 4 - 6), outline=inner, width=3)
    im.alpha_composite(big.resize((w, h), Image.LANCZOS))
    im.save(out('ui', name))

def round_button(name, size, c0, c1, ring, shadow=True):
    S = size * 4
    big = Image.new('RGBA', (S, S), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    if shadow:
        g.ellipse((10, 22, S - 10, S - 2), fill=(10, 14, 30, 110))
    body = grad(S, S, c0, c1)
    m = Image.new('L', (S, S), 0); ImageDraw.Draw(m).ellipse((8, 8, S - 12, S - 16), fill=255)
    big.paste(body, (0, 0), m)
    g.ellipse((8, 8, S - 12, S - 16), outline=ring, width=max(6, S // 30))
    g.arc((24, 22, S - 28, S - 34), 200, 320, fill=(255, 255, 255, 170), width=max(4, S // 50))
    big.resize((size, size), Image.LANCZOS).save(out('ui', name))

def build_ui():
    panel('window.png', 48, 48, 7, (255, 255, 255, 245), (232, 238, 249, 245), (92, 110, 152, 255))
    panel('title.png', 48, 24, 6, (226, 234, 248, 255), (164, 184, 222, 255), (92, 110, 152, 255))
    panel('btn.png', 32, 32, 6, (255, 255, 255, 255), (214, 222, 236, 255), (110, 124, 160, 255))
    panel('btn_pressed.png', 32, 32, 6, (204, 214, 232, 255), (246, 248, 252, 255), (92, 110, 152, 255))
    panel('btn_gold.png', 32, 32, 6, (255, 238, 186, 255), (226, 186, 92, 255), (122, 84, 20, 255))
    panel('chip.png', 24, 24, 11, (24, 28, 44, 170), (24, 28, 44, 170), (150, 160, 190, 160), inner=(0, 0, 0, 0))
    panel('parchment.png', 48, 48, 6, (255, 250, 232, 255), (244, 232, 200, 255), (176, 140, 70, 255))
    panel('plate.png', 48, 48, 10, (250, 252, 255, 235), (220, 228, 244, 235), (92, 110, 152, 255))
    panel('slot.png', 32, 32, 5, (246, 248, 252, 255), (206, 214, 232, 255), (106, 120, 152, 255))
    panel('gauge_bg.png', 16, 12, 3, (36, 40, 52, 255), (52, 58, 72, 255), (20, 24, 32, 255), inner=(0, 0, 0, 0))
    for nm, c0, c1 in (('gauge_hp.png', (110, 240, 110, 255), (30, 160, 40, 255)),
                       ('gauge_hp_low.png', (255, 120, 120, 255), (190, 30, 30, 255)),
                       ('gauge_zeal.png', (120, 176, 255, 255), (36, 90, 210, 255)),
                       ('gauge_exp.png', (255, 226, 120, 255), (214, 160, 40, 255)),
                       ('gauge_job.png', (170, 220, 255, 255), (90, 160, 230, 255))):
        grad(8, 10, c0, c1).save(out('ui', nm))
    round_button('btn_attack.png', 176, (255, 252, 240, 255), (226, 214, 188, 255), (200, 160, 70, 255))
    round_button('btn_skill.png', 120, (248, 250, 255, 255), (200, 210, 232, 255), (92, 110, 152, 255))
    round_button('btn_small.png', 88, (248, 250, 255, 240), (206, 214, 232, 240), (92, 110, 152, 255))
    round_button('btn_auto_on.png', 88, (255, 240, 180, 255), (232, 180, 60, 255), (140, 96, 20, 255))
    # joystick
    S = 320; big = Image.new('RGBA', (S, S), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    g.ellipse((8, 8, S - 8, S - 8), fill=(255, 255, 255, 40), outline=(255, 255, 255, 150), width=8)
    big.resize((160, 160), Image.LANCZOS).save(out('ui', 'joy_base.png'))
    round_button('joy_knob.png', 72, (255, 255, 255, 230), (210, 218, 236, 230), (92, 110, 152, 255))
    # minimap frame
    S = 4 * 160; big = Image.new('RGBA', (S, S), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    g.rounded_rectangle((6, 6, S - 6, S - 6), 70, outline=(92, 110, 152, 255), width=14)
    g.rounded_rectangle((20, 20, S - 20, S - 20), 58, outline=(255, 255, 255, 200), width=6)
    big.resize((160, 160), Image.LANCZOS).save(out('ui', 'minimap_frame.png'))
    # warp swirl, target ring, shadow, light shaft, motes
    S = 256; big = Image.new('RGBA', (S, S), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    for i in range(36):
        a = i * 10
        r0 = 30 + i * 2.6
        x = S / 2 + math.cos(math.radians(a)) * r0; y = S / 2 + math.sin(math.radians(a)) * r0
        g.ellipse((x - 9, y - 9, x + 9, y + 9), fill=(140, 210, 255, 200 - i * 4))
    big.filter(ImageFilter.GaussianBlur(2)).save(out('fx', 'warp.png'))
    big = Image.new('RGBA', (128, 128), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    g.ellipse((6, 6, 122, 122), outline=(255, 214, 80, 255), width=6)
    g.ellipse((20, 20, 108, 108), outline=(255, 240, 170, 140), width=3)
    big.save(out('fx', 'ring.png'))
    big = Image.new('RGBA', (64, 64), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    for r in range(30, 0, -2):
        g.ellipse((32 - r, 32 - r, 32 + r, 32 + r), fill=(0, 0, 0, int(120 * (1 - r / 30) + 20)))
    big.save(out('fx', 'shadow.png'))
    big = Image.new('RGBA', (64, 64), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    for r in range(30, 0, -1):
        g.ellipse((32 - r, 32 - r, 32 + r, 32 + r), fill=(255, 248, 210, int(255 * (1 - r / 30) ** 2)))
    big.save(out('fx', 'glow.png'))
    big = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    g.ellipse((3, 3, 13, 13), fill=(255, 255, 255, 255)); big = big.filter(ImageFilter.GaussianBlur(1.2))
    big.save(out('fx', 'mote.png'))

# ---------------------------------------------------------------- icons (96px drawn, saved 64px)
ICON_RIM = (40, 34, 56, 255)
def icon(name, draw_fn):
    S = 96 * 4
    big = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    g = ImageDraw.Draw(big)
    draw_fn(g, S)
    a = big.split()[3].filter(ImageFilter.MaxFilter(13))
    rim = Image.new('RGBA', (S, S), ICON_RIM); rim.putalpha(a)
    rim.alpha_composite(big)
    rim.resize((64, 64), Image.LANCZOS).save(out('icons', name + '.png'))

def build_icons():
    def staff(g, S):
        g.line((S*.22, S*.82, S*.74, S*.18), fill=(160, 112, 66, 255), width=int(S*.07))
        g.ellipse((S*.66, S*.08, S*.86, S*.28), fill=(240, 220, 150, 255))
    def steps(g, S):
        for off in (0, .28):
            g.line([(S*(.18+off), S*.22), (S*(.42+off), S*.5), (S*(.18+off), S*.78)], fill=(90, 190, 100, 255), width=int(S*.1), joint='curve')
    def refuge(g, S):
        g.polygon([(S*.5, S*.08), (S*.86, S*.2), (S*.82, S*.55), (S*.5, S*.92), (S*.18, S*.55), (S*.14, S*.2)], fill=(206, 222, 255, 255))
        g.rectangle((S*.44, S*.28, S*.56, S*.72), fill=(60, 110, 200, 255)); g.rectangle((S*.3, S*.44, S*.7, S*.56), fill=(60, 110, 200, 255))
    def lock(g, S):
        g.arc((S*.3, S*.14, S*.7, S*.58), 180, 360, fill=(170, 176, 196, 255), width=int(S*.08))
        g.rounded_rectangle((S*.22, S*.4, S*.78, S*.86), int(S*.06), fill=(150, 156, 178, 255))
    def bread(g, S):
        g.ellipse((S*.1, S*.3, S*.9, S*.8), fill=(220, 168, 92, 255))
        for x in (.32, .5, .68):
            g.line((S*(x-.06), S*.5, S*(x+.06), S*.4), fill=(150, 96, 40, 255), width=int(S*.03))
    def fig(g, S):
        g.ellipse((S*.22, S*.3, S*.78, S*.9), fill=(140, 74, 122, 255)); g.polygon([(S*.36, S*.38), (S*.64, S*.38), (S*.5, S*.1)], fill=(140, 74, 122, 255))
        g.line((S*.5, S*.12, S*.62, S*.04), fill=(80, 140, 60, 255), width=int(S*.05))
    def scroll(g, S):
        g.rectangle((S*.2, S*.22, S*.8, S*.78), fill=(250, 240, 210, 255))
        g.ellipse((S*.12, S*.14, S*.3, S*.32), fill=(220, 200, 150, 255)); g.ellipse((S*.7, S*.68, S*.88, S*.86), fill=(220, 200, 150, 255))
        for y in (.38, .5, .62): g.line((S*.32, S*y, S*.68, S*y), fill=(150, 120, 80, 255), width=int(S*.03))
    def bag(g, S):
        g.rounded_rectangle((S*.16, S*.32, S*.84, S*.88), int(S*.12), fill=(170, 116, 70, 255))
        g.arc((S*.32, S*.1, S*.68, S*.5), 180, 360, fill=(130, 84, 46, 255), width=int(S*.06))
        g.rectangle((S*.42, S*.5, S*.58, S*.62), fill=(240, 200, 90, 255))
    def equip(g, S):
        g.polygon([(S*.3, S*.14), (S*.7, S*.14), (S*.86, S*.34), (S*.74, S*.42), (S*.72, S*.88), (S*.28, S*.88), (S*.26, S*.42), (S*.14, S*.34)], fill=(92, 130, 196, 255))
        g.line((S*.5, S*.16, S*.5, S*.86), fill=(230, 200, 110, 255), width=int(S*.04))
    def skills(g, S):
        g.rounded_rectangle((S*.18, S*.12, S*.82, S*.88), int(S*.06), fill=(120, 70, 150, 255))
        g.polygon([(S*.5, S*.28), (S*.57, S*.45), (S*.74, S*.47), (S*.61, S*.58), (S*.65, S*.75), (S*.5, S*.66), (S*.35, S*.75), (S*.39, S*.58), (S*.26, S*.47), (S*.43, S*.45)], fill=(255, 220, 110, 255))
    def status(g, S):
        pts = [(S*.5 + math.cos(math.radians(-90 + i*60))*S*.38, S*.5 + math.sin(math.radians(-90 + i*60))*S*.38) for i in range(6)]
        g.polygon(pts, fill=(220, 232, 252, 255))
        pts2 = [(S*.5 + math.cos(math.radians(-90 + i*60))*S*(.18 + .12*(i % 2)), S*.5 + math.sin(math.radians(-90 + i*60))*S*(.18 + .12*(i % 2))) for i in range(6)]
        g.polygon(pts2, fill=(80, 130, 210, 255))
    def quest(g, S):
        scroll(g, S); g.rectangle((S*.46, S*.26, S*.54, S*.56), fill=(220, 130, 20, 255)); g.ellipse((S*.45, S*.62, S*.55, S*.72), fill=(220, 130, 20, 255))
    def gear(g, S):
        for i in range(8):
            a = math.radians(i * 45)
            g.line((S*.5, S*.5, S*.5 + math.cos(a)*S*.4, S*.5 + math.sin(a)*S*.4), fill=(160, 170, 190, 255), width=int(S*.14))
        g.ellipse((S*.22, S*.22, S*.78, S*.78), fill=(170, 180, 200, 255)); g.ellipse((S*.38, S*.38, S*.62, S*.62), fill=(70, 76, 96, 255))
    def friends(g, S):
        g.ellipse((S*.16, S*.2, S*.44, S*.48), fill=(246, 210, 180, 255)); g.ellipse((S*.56, S*.24, S*.84, S*.52), fill=(246, 210, 180, 255))
        g.pieslice((S*.06, S*.5, S*.54, S*1.0), 180, 360, fill=(90, 150, 210, 255)); g.pieslice((S*.46, S*.54, S*.94, S*1.02), 180, 360, fill=(110, 180, 120, 255))
    def library(g, S):
        g.polygon([(S*.08, S*.24), (S*.5, S*.32), (S*.5, S*.86), (S*.08, S*.78)], fill=(250, 244, 226, 255))
        g.polygon([(S*.92, S*.24), (S*.5, S*.32), (S*.5, S*.86), (S*.92, S*.78)], fill=(236, 228, 206, 255))
        g.line((S*.5, S*.32, S*.5, S*.86), fill=(150, 110, 60, 255), width=int(S*.03))
    def church(g, S):
        g.polygon([(S*.5, S*.12), (S*.88, S*.44), (S*.12, S*.44)], fill=(170, 80, 60, 255))
        g.rectangle((S*.2, S*.44, S*.8, S*.88), fill=(236, 226, 200, 255)); g.rectangle((S*.42, S*.6, S*.58, S*.88), fill=(110, 76, 50, 255))
    def auto(g, S):
        g.arc((S*.14, S*.14, S*.86, S*.86), 30, 300, fill=(250, 220, 120, 255), width=int(S*.09))
        g.polygon([(S*.86, S*.2), (S*.9, S*.46), (S*.66, S*.38)], fill=(250, 220, 120, 255))
    def sit(g, S):
        g.ellipse((S*.36, S*.08, S*.6, S*.32), fill=(246, 210, 180, 255))
        g.polygon([(S*.36, S*.34), (S*.62, S*.34), (S*.68, S*.66), (S*.3, S*.66)], fill=(92, 130, 196, 255))
        g.rectangle((S*.3, S*.62, S*.86, S*.74), fill=(110, 76, 50, 255))
    def talk(g, S):
        g.rounded_rectangle((S*.1, S*.16, S*.9, S*.66), int(S*.14), fill=(255, 255, 255, 255)); g.polygon([(S*.26, S*.62), (S*.46, S*.64), (S*.24, S*.86)], fill=(255, 255, 255, 255))
        for x in (.32, .5, .68): g.ellipse((S*(x-.05), S*.36, S*(x+.05), S*.46), fill=(80, 90, 120, 255))
    def hand(g, S):
        for i, x in enumerate((.3, .42, .54, .66)):
            g.rounded_rectangle((S*x, S*(.14 + (0.06 if i in (0, 3) else 0)), S*(x+.1), S*.6), int(S*.05), fill=(246, 210, 180, 255))
        g.rounded_rectangle((S*.28, S*.44, S*.78, S*.88), int(S*.14), fill=(246, 210, 180, 255))
    def eye(g, S):
        g.ellipse((S*.08, S*.28, S*.92, S*.72), fill=(255, 255, 255, 255)); g.ellipse((S*.36, S*.32, S*.64, S*.68), fill=(70, 110, 170, 255)); g.ellipse((S*.45, S*.42, S*.55, S*.58), fill=(20, 20, 30, 255))
    def tag(g, S):
        g.polygon([(S*.12, S*.5), (S*.36, S*.18), (S*.88, S*.18), (S*.88, S*.82), (S*.36, S*.82)], fill=(250, 214, 120, 255)); g.ellipse((S*.3, S*.44, S*.42, S*.56), fill=(120, 80, 30, 255))
    def camera(g, S):
        g.rounded_rectangle((S*.1, S*.28, S*.9, S*.82), int(S*.1), fill=(90, 100, 130, 255)); g.rectangle((S*.36, S*.18, S*.64, S*.3), fill=(90, 100, 130, 255))
        g.ellipse((S*.34, S*.38, S*.66, S*.7), fill=(200, 220, 250, 255))
    def page(g, S):
        g.polygon([(S*.2, S*.4), (S*.5, S*.14), (S*.5, S*.3), (S*.8, S*.3), (S*.8, S*.5), (S*.5, S*.5), (S*.5, S*.66)], fill=(220, 230, 250, 255))
        g.polygon([(S*.8, S*.6), (S*.5, S*.86), (S*.5, S*.7), (S*.2, S*.7), (S*.2, S*.5), (S*.5, S*.5), (S*.5, S*.34)], fill=(160, 180, 220, 255))
    def warpi(g, S):
        for i in range(3):
            g.arc((S*(.1+i*.1), S*(.1+i*.1), S*(.9-i*.1), S*(.9-i*.1)), i*60, i*60+260, fill=(120, 200, 255, 255), width=int(S*.06))
    def menu(g, S):
        for y in (.26, .5, .74): g.rounded_rectangle((S*.16, S*(y-.06), S*.84, S*(y+.06)), int(S*.05), fill=(240, 244, 252, 255))
    for nm, fn in (('staff', staff), ('steps', steps), ('refuge', refuge), ('lock', lock), ('bread', bread), ('fig', fig),
                   ('scroll', scroll), ('bag', bag), ('equip', equip), ('skills', skills), ('status', status), ('quest', quest),
                   ('settings', gear), ('friends', friends), ('library', library), ('congregation', church), ('auto', auto),
                   ('sit', sit), ('talk', talk), ('hand', hand), ('eye', eye), ('tag', tag), ('camera', camera), ('page', page),
                   ('warp', warpi), ('menu', menu)):
        icon(nm, fn)

if __name__ == '__main__':
    build_tiles(); build_ui(); build_icons()
    build_characters(); npc_evangelist(); mob_slothling(); lamb(); portrait_evangelist()
    print('assets generated')

# ---------------------------------------------------------------- extra FX textures (polish pass)
def build_fx_extra():
    S = 128
    # star burst for crits
    big = Image.new('RGBA', (S*4, S*4), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    c = S*2
    pts = []
    for i in range(16):
        r = (S*1.9 if i % 2 == 0 else S*0.7)
        a = math.radians(i * 22.5 - 90)
        pts.append((c + math.cos(a)*r, c + math.sin(a)*r))
    g.polygon(pts, fill=(255, 240, 160, 255))
    g.ellipse((c-S*0.6, c-S*0.6, c+S*0.6, c+S*0.6), fill=(255, 255, 240, 255))
    big.filter(ImageFilter.GaussianBlur(6)).resize((S, S), Image.LANCZOS).save(out('fx', 'star.png'))
    # spark streak
    im = Image.new('RGBA', (64, 16), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
    for x in range(64):
        a = int(255 * (1 - abs(x - 40) / 40.0) ** 1.5) if x < 64 else 0
        g.line((x, 5, x, 10), fill=(255, 255, 255, max(0, a)))
    im.filter(ImageFilter.GaussianBlur(1.2)).save(out('fx', 'spark.png'))
    # light shaft (vertical soft gradient)
    im = Image.new('RGBA', (64, 256), (0, 0, 0, 0)); px = im.load()
    for y in range(256):
        for x in range(64):
            fx = 1 - abs(x - 31.5) / 32.0
            fy = min(1.0, y / 40.0) * (1 - y / 256.0)
            px[x, y] = (255, 246, 210, int(160 * (fx ** 2) * fy))
    im.save(out('fx', 'shaft.png'))
    # petal
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
    g.ellipse((6, 10, 26, 22), fill=(255, 210, 225, 255)); g.ellipse((10, 12, 20, 18), fill=(255, 235, 242, 255))
    im.filter(ImageFilter.GaussianBlur(0.6)).save(out('fx', 'petal.png'))
    # rain streak
    im = Image.new('RGBA', (8, 64), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
    g.line((4, 0, 4, 63), fill=(200, 210, 230, 160), width=2)
    im.save(out('fx', 'rain.png'))
    # sweat drop
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
    g.polygon([(16, 2), (24, 18), (8, 18)], fill=(150, 210, 255, 255)); g.ellipse((8, 10, 24, 28), fill=(150, 210, 255, 255))
    g.ellipse((12, 14, 16, 18), fill=(240, 250, 255, 255))
    im.save(out('fx', 'drop.png'))
    # telegraph disc (red, soft fill, bright rim)
    S2 = 256; big = Image.new('RGBA', (S2, S2), (0, 0, 0, 0)); g = ImageDraw.Draw(big)
    g.ellipse((8, 8, S2-8, S2-8), fill=(230, 40, 40, 70), outline=(255, 70, 60, 230), width=10)
    for r in range(0, 110, 22):
        g.ellipse((S2/2-r, S2/2-r, S2/2+r, S2/2+r), outline=(255, 90, 80, 60), width=3)
    big.save(out('fx', 'telegraph.png'))
    # soft puff
    im = Image.new('RGBA', (64, 64), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
    for r in range(28, 0, -2):
        g.ellipse((32-r, 32-r, 32+r, 32+r), fill=(255, 255, 255, int(200 * (1 - r/28.0) ** 1.2)))
    im.save(out('fx', 'puff.png'))
    # dome gradient (for Take Refuge), vertical
    im = Image.new('RGBA', (16, 128), (0, 0, 0, 0)); g = ImageDraw.Draw(im)
    for y in range(128):
        a = int(150 * (y / 127.0) ** 2)
        g.line((0, y, 16, y), fill=(255, 236, 170, a))
    im.save(out('fx', 'dome.png'))

if __name__ == '__main__':
    build_fx_extra()
