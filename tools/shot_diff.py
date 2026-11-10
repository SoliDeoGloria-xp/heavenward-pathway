#!/usr/bin/env python3
"""Compare a gallery run with the golden pictures.

    HPO_GALLERY=1 HPO_SHOTS=/tmp/shots godot --path . -- --autotest      # take the pictures
    python3 tools/shot_diff.py /tmp/shots                               # compare with tests/golden
    python3 tools/shot_diff.py /tmp/shots --update                      # accept them as the new golden set

The gallery photographs every map from three fixed spots and every main screen, sideways and
upright (scripts/autotest.gd, gallery()). Each picture is reduced to a 96-pixel-wide thumbnail,
which is what is stored in tests/golden and compared, so rain, sparkles and wandering foes do
not trip the check while a missing map, a broken layout or a changed palette does.

Fails (exit 1) when a golden picture is missing from the run, a picture is blank, or a picture
differs from its golden thumbnail by more than LIMIT. New pictures with no golden are reported
and pass. A contact sheet of every changed picture (golden | now) is written beside the shots.
Requires Pillow and numpy.
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

GOLDEN = Path(__file__).resolve().parent.parent / "tests" / "golden"
THUMB_W = 96
LIMIT = 0.085          # mean absolute difference, 0..1, above which a picture has really changed
BLANK = 0.012          # a picture with less spread than this shows nothing
PREFIXES = ("map_", "ui_", "portrait_")

def thumb(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    return im.resize((THUMB_W, max(1, round(im.height * THUMB_W / im.width))), Image.BOX)

def main() -> int:
    shots = Path(sys.argv[1])
    update = "--update" in sys.argv
    now = {p.stem: p for p in sorted(shots.glob("*.png")) if p.stem.startswith(PREFIXES)}
    if not now:
        print(f"shot_diff: no gallery pictures in {shots}"); return 1
    if update:
        GOLDEN.mkdir(parents=True, exist_ok=True)
        for old in GOLDEN.glob("*.png"):
            old.unlink()
        for name, p in now.items():
            thumb(p).save(GOLDEN / f"{name}.png", optimize=True)
        print(f"shot_diff: {len(now)} golden thumbnails written to {GOLDEN}"); return 0
    failed, changed, fresh = [], [], []
    golden = {p.stem: p for p in GOLDEN.glob("*.png")}
    for name in sorted(golden):
        if name not in now:
            failed.append(f"{name}: missing from this run")
    for name, p in now.items():
        t = thumb(p)
        a = np.asarray(t, dtype=np.float32) / 255.0
        if a.std() < BLANK:
            failed.append(f"{name}: blank picture"); continue
        if name not in golden:
            fresh.append(name); continue
        g = Image.open(golden[name]).convert("RGB")
        if g.size != t.size:
            failed.append(f"{name}: size changed {g.size} -> {t.size}"); changed.append((name, g, t)); continue
        d = float(np.abs(a - np.asarray(g, dtype=np.float32) / 255.0).mean())
        if d > LIMIT:
            failed.append(f"{name}: differs by {d:.3f} (limit {LIMIT})"); changed.append((name, g, t))
    if changed:
        h = max(max(g.height, t.height) for _, g, t in changed)
        sheet = Image.new("RGB", (THUMB_W * 2 + 6, (h + 4) * len(changed)), (26, 22, 34))
        for i, (_, g, t) in enumerate(changed):
            sheet.paste(g, (0, i * (h + 4))); sheet.paste(t, (THUMB_W + 6, i * (h + 4)))
        sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
        sheet.save(shots / "_changed.png")
    print(f"shot_diff: {len(now)} pictures, {len(golden)} golden, {len(fresh)} new, {len(failed)} failed")
    for f in failed:
        print("  FAIL", f)
    if fresh:
        print("  new (no golden yet):", ", ".join(fresh))
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())
