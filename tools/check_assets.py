#!/usr/bin/env python3
"""Check art against the HPO art contract and wire in everything that passes.

    python3 tools/check_assets.py [pack_dir]      # default pack_dir: assets/p1

Put a cleaned art pack (for example the unzipped HPO_P1_clean.zip) at assets/p1. Every PNG is
checked; files that pass and share a name with a placeholder (assets/icons/<name>.png,
assets/tiles/<name>.png, assets/sprites/<name>.png, assets/portraits/<name>.png) are written to
data/asset_overrides.json, which the game's texture loader (G.tex) reads, so placeholders stay as
the fallback. Failures are listed in ASSET_REREQUEST.md with the exact spec to ask for.
Art is never stretched to fit: a wrong-size file fails.
"""
import json, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CONTRACT = {                       # kind -> (width, height, placeholder folder)
    "icon": (64, 64, "icons"),
    "tile": (64, 64, "tiles"),
    "sheet": (320, 240, "sprites"),        # 10 columns x 5 rows of 32x48 frames
    "portrait": (256, 320, "portraits"),
}
FOLDER_KIND = {"icon": "icon", "icons": "icon", "tile": "tile", "tiles": "tile", "sheet": "sheet", "sheets": "sheet", "sprites": "sheet",
               "portrait": "portrait", "portraits": "portrait"}
SEAM_TOLERANCE = 28                # mean colour step allowed across a tile's wrap-around edge
MIN_CLEAR = 0.02                   # icons, sheets and portraits need some fully transparent pixels
MARK = "<!-- scan results below are written by tools/check_assets.py -->"

def check(path: Path, kind: str) -> list[str]:
    w, h, _ = CONTRACT[kind]
    im = Image.open(path)
    problems = []
    if im.size != (w, h):
        problems.append(f"size {im.size[0]}x{im.size[1]}, contract is {w}x{h}")
    if kind != "tile":
        if im.mode != "RGBA":
            problems.append(f"mode {im.mode}: needs real alpha (PNG-32), not a painted checkerboard")
        else:
            alpha = im.getchannel("A")
            clear = sum(1 for a in alpha.getdata() if a == 0) / (im.size[0] * im.size[1])
            if clear < MIN_CLEAR:
                problems.append("no transparent background (fake transparency)")
    elif im.size == (w, h):
        rgb = im.convert("RGB")
        step = 0
        for i in range(w):
            for a, b in ((rgb.getpixel((0, i)), rgb.getpixel((w - 1, i))), (rgb.getpixel((i, 0)), rgb.getpixel((i, h - 1)))):
                step += sum(abs(x - y) for x, y in zip(a, b)) / 3
        if step / (2 * w) > SEAM_TOLERANCE:
            problems.append("not seamless: visible seam when repeated")
    if kind == "sheet" and im.size == (w, h) and im.mode == "RGBA":
        empty = [(c, r) for r in range(5) for c in range(10) if im.crop((c * 32, r * 48, c * 32 + 32, r * 48 + 48)).getchannel("A").getextrema()[1] == 0]
        if empty:
            problems.append(f"{len(empty)} of 50 frames are empty (needs 5 directions x idle, walk1-4, attack1-2, sit, KO, cast)")
    return problems

def main() -> int:
    pack = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets" / "p1"
    overrides, failed, unplaced = {}, [], []
    files = sorted(pack.rglob("*.png")) if pack.exists() else []
    for f in files:
        kind = next((FOLDER_KIND[p] for p in reversed(f.relative_to(pack).parts[:-1]) if p in FOLDER_KIND), None)
        if kind is None:
            unplaced.append(f); continue
        problems = check(f, kind)
        rel = f.relative_to(ROOT).as_posix() if ROOT in f.resolve().parents else f.as_posix()
        if problems:
            failed.append((rel, kind, problems)); continue
        placeholder = ROOT / "assets" / CONTRACT[kind][2] / f.name
        if placeholder.exists():
            overrides[f"res://assets/{CONTRACT[kind][2]}/{f.name}"] = "res://" + rel
        else:
            unplaced.append(f)
    (ROOT / "data" / "asset_overrides.json").write_text(json.dumps(overrides, indent=1) + "\n")
    lines = [MARK, "", f"## Last scan: `{pack.relative_to(ROOT) if ROOT in pack.resolve().parents else pack}`", ""]
    if not files:
        lines.append("No art pack found at that path. Unzip the cleaned pack there and run `python3 tools/check_assets.py` again.")
    else:
        lines += [f"- {len(files)} PNGs scanned, **{len(overrides)} wired in** (data/asset_overrides.json), {len(failed)} failed, {len(unplaced)} passed or unclassified but have no placeholder of the same name.", ""]
        if failed:
            lines += ["| File | Kind | Problem | Ask for |", "|---|---|---|---|"]
            for rel, kind, problems in failed:
                w, h, _ = CONTRACT[kind]
                lines.append(f"| `{rel}` | {kind} | {'; '.join(problems)} | {w}x{h} PNG-32, native 1x pixels, real alpha, no text |")
        if unplaced:
            lines += ["", "Not wired (no placeholder with the same file name; rename to match or add a use in map data):", ""]
            lines += [f"- `{f.name}`" for f in unplaced[:80]]
    doc = ROOT / "ASSET_REREQUEST.md"
    head = doc.read_text(encoding="utf-8").split(MARK)[0] if doc.exists() else "# Asset re-request\n\n"
    doc.write_text(head + "\n".join(lines) + "\n", encoding="utf-8")
    print(f"check_assets: {len(files)} scanned, {len(overrides)} wired, {len(failed)} failed, {len(unplaced)} unplaced")
    return 0

if __name__ == "__main__":
    sys.exit(main())
