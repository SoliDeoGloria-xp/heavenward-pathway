#!/usr/bin/env python3
"""Fill data/scripture.json with the Berean Standard Bible text of every passage the game cites.

    python3 tools/pull_bsb.py            # downloads the public-domain BSB text and writes data/scripture.json

The BSB was dedicated to the public domain in 2023 (berean.bible). The game ships only references
unless this tool has run; Word Study then shows the passage itself. The build never fails because
of this step: with no network the file is left as it is.
"""
import json, re, sys, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ["https://bereanbible.com/bsb.txt"]
CITE = re.compile(r"\[BSB: ((?:[1-3] )?[A-Z][A-Za-z]+(?: of [A-Z][a-z]+)?) (\d+)(?::(\d+)(?:[–-](\d+))?)?\]")

def cited() -> set[tuple]:
    refs: set[tuple] = set()
    for p in (ROOT / "data").rglob("*.json"):
        if p.name == "scripture.json":
            continue
        text = p.read_text(encoding="utf-8")
        for m in CITE.finditer(text):
            refs.add(m.groups())
        if p.name == "word_studies.json":
            for study in json.loads(text).values():
                m = CITE.fullmatch("[BSB: %s]" % study["ref"])
                if m:
                    refs.add(m.groups())
    return refs

def download() -> dict[str, str]:
    for url in SOURCES:
        try:
            raw = urllib.request.urlopen(url, timeout=60).read().decode("utf-8-sig")
        except Exception as e:  # noqa: BLE001
            print(f"pull_bsb: could not fetch {url}: {e}")
            continue
        verses = {}
        for line in raw.splitlines():
            ref, tab, body = line.partition("\t")
            if tab and re.fullmatch(r"(?:[1-3] )?[A-Za-z ]+ \d+:\d+", ref.strip()):
                verses[ref.strip()] = body.strip()
        if verses:
            return verses
    return {}

def main() -> int:
    verses = download()
    if not verses:
        print("pull_bsb: no text downloaded; data/scripture.json left unchanged")
        return 0
    out, missing = {}, []
    for book, ch, v1, v2 in sorted(cited(), key=str):
        if v1 is None:
            continue   # whole-chapter references stay as references
        book_key = "Psalm" if book == "Psalms" else book
        keys = [f"{book_key} {ch}:{v}" for v in range(int(v1), int(v2 or v1) + 1)]
        label = f"{book} {ch}:{v1}" + (f"–{v2}" if v2 else "")
        if all(k in verses for k in keys):
            out[label] = " ".join(verses[k] for k in keys)
        else:
            missing.append(label)
    (ROOT / "data" / "scripture.json").write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"pull_bsb: wrote {len(out)} passages" + (f"; not found: {missing}" if missing else ""))
    return 0

if __name__ == "__main__":
    sys.exit(main())
