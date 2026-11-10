#!/usr/bin/env python3
"""Data validator for Heavenward Pathway Online. Run in CI and before every commit:

    python3 tools/validate_data.py

Checks (see the build brief): every objective has XP; every map has a start and a way out; XP sums
match the design budget per act (data/acts.json) and in total; boss XP is 150-250; required-kill
monster XP is 15-25% of quest XP; every Scripture cite is [BSB: Book ch:v]; no reserved (divine)
names are used as a speaker or entity; every referenced dialogue, entity, mob, skill and map exists.
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
errors: list[str] = []

def err(msg: str) -> None:
    errors.append(msg)

def load(name: str):
    try:
        return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001 - report any parse problem as a data error
        err(f"{name}.json: {e}")
        return {}

# Names that may never be a speaker or an entity (God is never depicted, voiced or made a character).
RESERVED = ["god", "jesus", "christ", "emmanuel", "immanuel", "shaddai", "lord", "yahweh", "jehovah", "holy spirit", "holyspirit", "messiah", "the spirit", "the father", "the son"]
ALLOWED_NAME_PHRASES = ["armor of god"]          # item and objective names from Ephesians 6
BOOKS = ("Genesis Exodus Leviticus Numbers Deuteronomy Joshua Judges Ruth|1 Samuel|2 Samuel|1 Kings|2 Kings|1 Chronicles|2 Chronicles|Ezra Nehemiah Esther Job "
         "Psalm Psalms Proverbs Ecclesiastes|Song of Songs|Isaiah Jeremiah Lamentations Ezekiel Daniel Hosea Joel Amos Obadiah Jonah Micah Nahum Habakkuk Zephaniah Haggai "
         "Zechariah Malachi Matthew Mark Luke John Acts Romans|1 Corinthians|2 Corinthians|Galatians Ephesians Philippians Colossians|1 Thessalonians|2 Thessalonians|"
         "1 Timothy|2 Timothy|Titus Philemon Hebrews James|1 Peter|2 Peter|1 John|2 John|3 John|Jude Revelation")
BOOK_SET = {b.strip() for part in BOOKS.split("|") for b in ([part] if part[:1].isdigit() or " of " in part else part.split())}
CITE = re.compile(r"\[BSB: ([1-3] )?([A-Z][A-Za-z]+(?: of [A-Z][a-z]+)?) (\d+)(?::(\d+)(?:[–-]\d+)?)?\]")
OTHER_VERSION = re.compile(r"\b(KJV|ESV|NIV|NASB|NKJV|NLT|CSB)\b")
OBJECTIVE_TYPES = {"zone", "path", "exit", "talk", "interact", "choice", "kill", "boss", "check", "travel", "script", "secret"}

def check_text(where: str, text: str) -> None:
    for m in re.finditer(r"\[BSB[^\]]*\]", text):
        full = CITE.fullmatch(m.group(0))
        book = ((full.group(1) or "") + full.group(2)) if full else ""
        if not full or book not in BOOK_SET:
            err(f"{where}: Scripture cite is not in the form [BSB: Book ch:v]: {m.group(0)}")
    if OTHER_VERSION.search(text):
        err(f"{where}: only the BSB may be cited: {text[:60]}")
    if re.search(r"\b[1-3]? ?[A-Z][a-z]+ \d+:\d+", re.sub(r"\[BSB[^\]]*\]", "", text)):
        err(f"{where}: verse reference outside a [BSB: ...] cite: {text[:70]}")

def check_name(where: str, name: str) -> None:
    low = name.lower()
    if any(p in low for p in ALLOWED_NAME_PHRASES):
        return
    for r in RESERVED:
        if re.search(rf"\b{re.escape(r)}\b", low):
            err(f"{where}: reserved name used as a character or entity: {name!r}")

def main() -> int:
    prog, acts, mobs, skills, jobs, dialogue, lessons = (load(n) for n in ("progression", "acts", "mobs", "skills", "jobs", "dialogue", "lessons"))
    maps = {p.stem: load(f"maps/{p.stem}") for p in sorted((DATA / "maps").glob("*.json"))}

    # ---- dialogue: speakers, cites
    for did, lines in dialogue.items():
        for i, line in enumerate(lines):
            where = f"dialogue {did}[{i}]"
            if not line.get("who") or not line.get("text"):
                err(f"{where}: needs who and text")
            check_name(where, line.get("who", ""))
            check_text(where, line.get("text", "") + " " + line.get("src", ""))
    for sid, s in skills.get("skills", {}).items():
        check_text(f"skill {sid}", s.get("does", ""))
        if s.get("job") != "pilgrim" and s.get("job") not in jobs.get("jobs", {}):
            err(f"skill {sid}: unknown job {s.get('job')}")
    for jid, j in jobs.get("jobs", {}).items():
        if len(j.get("skills", [])) != 3 or any(s not in skills["skills"] for s in j["skills"]):
            err(f"job {jid}: needs exactly 3 known skills")
    if len(jobs.get("jobs", {})) != 6:
        err("jobs.json: the first job change offers exactly six jobs")
    sprites = load("sprites")
    for mid, m in mobs.items():
        check_name(f"mob {mid}", m.get("name", ""))
        sheet = sprites.get(m.get("sprite", ""))
        if sheet is None or "size" not in m:
            err(f"mob {mid}: needs a sprite listed in sprites.json and a size")
        elif not (ROOT / sheet["tex"].replace("res://", "")).exists():
            err(f"mob {mid}: sheet file missing: {sheet['tex']}")
    for sid, s in skills.get("skills", {}).items():
        if not (ROOT / "assets" / "icons" / f"{s.get('icon')}.png").exists():
            err(f"skill {sid}: icon file missing: {s.get('icon')}")

    # ---- maps
    budget = {a: [0, 0] for a in acts.get("order", [])}
    kill_xp = 0
    rules = prog.get("mob_xp", {})
    def mob_xp(mid: str) -> int:
        m = mobs[mid]
        if m.get("boss"):
            return int(m.get("xp_bonus", 0))
        return (rules["base"] + rules["per_level"] * m["level"]) * (rules["greater_mult"] if m.get("greater") else 1)
    for mid_, d in maps.items():
        where = f"map {mid_}"
        for key in ("id", "act", "name", "start", "look", "objectives", "combat"):
            if key not in d:
                err(f"{where}: missing '{key}'")
        if d.get("act") not in budget:
            err(f"{where}: unknown act {d.get('act')}"); continue
        ent_ids = {e["id"] for e in d.get("ents", [])}
        scripted = (ROOT / "scripts" / "maps" / f"{mid_}.gd").exists()
        for e in d.get("ents", []):
            check_name(f"{where} ent {e['id']}", e.get("name", ""))
            if "dialog" in e and e["dialog"] not in dialogue:
                err(f"{where} ent {e['id']}: unknown dialogue {e['dialog']}")
        objs = d.get("objectives", [])
        if not objs:
            err(f"{where}: no objectives")
        # a way out: an exit or travel objective, an objective that ends on another screen, or the Fall scene (Eden)
        leaves = any(o.get("type") in ("exit", "travel") or "screen" in o.get("on_done", {}) for o in objs) or mid_ == "eden"
        if not leaves:
            err(f"{where}: no exit (softlock)")
        spawn_ats = {s.get("at", "") for s in d.get("spawns", [])}
        ids = set()
        for o in objs + d.get("side", []):
            ow = f"{where} objective {o.get('id')}"
            if o.get("id") in ids:
                err(f"{ow}: duplicate id")
            ids.add(o.get("id"))
            if o.get("type") not in OBJECTIVE_TYPES:
                err(f"{ow}: unknown type {o.get('type')}")
            xp = o.get("xp")
            if not (isinstance(xp, list) and len(xp) == 2 and all(isinstance(v, int) and v >= 0 for v in xp)):
                err(f"{ow}: every objective needs xp [base, job]"); continue
            if not o.get("text"):
                err(f"{ow}: needs text")
            check_text(ow, o.get("text", ""))
            budget[d["act"]][0] += xp[0]; budget[d["act"]][1] += xp[1]
            for k in ("dialog", "dialog_start"):
                if k in o and o[k] not in dialogue:
                    err(f"{ow}: unknown dialogue {o[k]}")
            done = o.get("on_done", {})
            if "dialog" in done and done["dialog"] not in dialogue:
                err(f"{ow}: unknown dialogue {done['dialog']}")
            if not scripted:
                for eid in [o.get("ent")] + done.get("show", []) + done.get("hide", []):
                    if eid and eid not in ent_ids:
                        err(f"{ow}: unknown entity {eid}")
            if o.get("type") in ("exit", "travel") and o.get("to") not in maps:
                err(f"{ow}: leads to unknown map {o.get('to')}")
            if o.get("type") == "kill":
                pool = [s for s in d.get("spawns", []) if s.get("at", "") in ("", o["id"])]
                if sum(s["count"] for s in pool) < o["count"] and not any(not mobs[s["mob"]].get("greater") for s in pool):
                    err(f"{ow}: not enough foes spawn to finish (softlock)")
                if pool:
                    kill_xp += round(o["count"] * sum(mob_xp(s["mob"]) * s["count"] for s in pool) / sum(s["count"] for s in pool))
            if o.get("type") == "path" and "kills" in o:
                pool = [s for s in d.get("spawns", []) if s.get("at", "") in ("", o["id"])]
                kill_xp += round(o["kills"] * sum(mob_xp(s["mob"]) * s["count"] for s in pool) / max(1, sum(s["count"] for s in pool)))
            if o.get("type") == "boss" or (o.get("type") == "script" and mid_ == "lions"):
                boss = mobs.get(o.get("mob", "grim"))
                if not boss or not boss.get("boss"):
                    err(f"{ow}: unknown boss {o.get('mob')}"); continue
                total = xp[0] + int(boss.get("xp_bonus", 0))
                lo, hi = rules["boss"]
                if not lo <= total <= hi:
                    err(f"{ow}: boss XP {total} is outside {lo}-{hi}")
                kill_xp += int(boss.get("xp_bonus", 0))
            if o.get("id") in spawn_ats:
                spawn_ats.discard(o["id"])
        for s in d.get("spawns", []):
            if s["mob"] not in mobs:
                err(f"{where}: spawn of unknown mob {s['mob']}")
        for at in spawn_ats - {""}:
            err(f"{where}: spawn group waits for unknown objective '{at}'")
        for tip in lessons.get(mid_, {}):
            if tip not in ids:
                err(f"lessons: {mid_}.{tip} has no matching objective")

    # ---- budgets
    total = [0, 0]
    for a in acts.get("order", []):
        plan = acts["acts"][a]
        if budget[a] != [plan["base"], plan["job"]]:
            err(f"act {a}: objectives pay {budget[a]} but the design budget is [{plan['base']}, {plan['job']}]")
        total[0] += budget[a][0]; total[1] += budget[a][1]
    want = [sum(prog.get("base_cost", [])), sum(prog.get("job_cost", []))]
    if total != want:
        err(f"total quest XP {total} must equal the Base 10 / Job 10 thresholds {want}")
    share = kill_xp / max(1, total[0])
    lo, hi = prog.get("mob_share_target", [0.15, 0.25])
    if not lo <= share <= hi:
        err(f"required-kill monster XP is {kill_xp} ({share:.0%} of quest XP); target is {lo:.0%}-{hi:.0%}")
    minutes = sum(acts["acts"][a]["minutes"] for a in acts.get("order", []))

    if errors:
        print(f"validate_data: {len(errors)} problem(s)")
        for e in errors:
            print("  -", e)
        return 1
    print(f"validate_data: OK · {len(maps)} maps · {len(dialogue)} dialogue scenes · quest XP {total[0]}/{total[1]} · required-kill mob XP {kill_xp} ({share:.0%}) · planned {minutes} min")
    return 0

if __name__ == "__main__":
    sys.exit(main())
