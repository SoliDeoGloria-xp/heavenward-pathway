#!/usr/bin/env python3
"""Data validator for Heavenward Pathway Online. Run in CI and before every commit:

    python3 tools/validate_data.py

Checks (see the build brief): every objective has XP; every map has a start and a way out; XP sums
match the design budget per act (data/acts.json) and in total; boss XP is 150-250; required-kill
monster XP is 15-25% of quest XP; every Scripture cite is [BSB: Book ch:v]; no reserved (divine)
names are used as a speaker or entity; every referenced dialogue, entity, mob, skill and map exists.
World graph (data/world.json): every map is a node and can be reached; every road has a way back
unless marked story_oneway; every town has a Waymark; portals and arrival points are inside their
maps and clear of each other; level ranges rise without gaps.
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
        if len(j.get("skills", [])) < 3 or any(s not in skills["skills"] for s in j["skills"]):
            err(f"job {jid}: needs at least 3 known skills")
        if skills["skills"][j["skills"][0]]["kind"] != "active":
            err(f"job {jid}: its first skill is lent for the Calling trial and must be active")
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
        req = s.get("req", {}).get("skill")
        if req and req not in skills["skills"]:
            err(f"skill {sid}: requires unknown skill {req}")
        if s.get("fx", {}).get("type") == "passive" and "stat" not in s["fx"]:
            err(f"skill {sid}: a passive needs fx.stat")
        if not (ROOT / "assets" / "icons" / f"{s.get('icon')}.png").exists():
            err(f"skill {sid}: icon file missing: {s.get('icon')}")

    # ---- road gear: never a piece of the Armor of God, icons exist, the shop sells known things
    items = load("items")
    armor_words = ("belt", "breastplate", "shoe", "shield", "helmet", "sword")
    for gid, g in items.get("gear", {}).items():
        if any(wd in g["name"].lower() for wd in armor_words):
            err(f"gear {gid}: '{g['name']}' names a piece of the Armor of God, which is never road gear")
        if g["slot"] not in items["slots"] or not (ROOT / "assets" / "icons" / f"{g['icon']}.png").exists():
            err(f"gear {gid}: unknown slot or missing icon")
    for sid_ in items.get("shop", []):
        if sid_ not in items["gear"] and sid_ not in items["consumables"]:
            err(f"shop sells unknown item {sid_}")
    if len(items.get("stones", {})) != 9:
        err("items.json: there are nine Fruit stones (Galatians 5:22-23)")
    check_text("items stone_note", items.get("stone_note", ""))
    pilgrim_acts = {a for a in acts.get("order", []) if acts["acts"][a].get("pilgrim")}

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
                if pool and d["act"] in pilgrim_acts:
                    kill_xp += round(o["count"] * sum(mob_xp(s["mob"]) * s["count"] for s in pool) / sum(s["count"] for s in pool))
            if o.get("type") == "path" and "kills" in o:
                pool = [s for s in d.get("spawns", []) if s.get("at", "") in ("", o["id"])]
                kill_xp += 0 if d["act"] not in pilgrim_acts else round(o["kills"] * sum(mob_xp(s["mob"]) * s["count"] for s in pool) / max(1, sum(s["count"] for s in pool)))
            if o.get("type") == "boss" or (o.get("type") == "script" and mid_ == "lions"):
                boss = mobs.get(o.get("mob", "grim"))
                if not boss or not boss.get("boss"):
                    err(f"{ow}: unknown boss {o.get('mob')}"); continue
                total = xp[0] + int(boss.get("xp_bonus", 0))
                lo, hi = rules["boss"]
                if d["act"] in pilgrim_acts and not lo <= total <= hi:
                    err(f"{ow}: boss XP {total} is outside {lo}-{hi}")
                kill_xp += int(boss.get("xp_bonus", 0)) if d["act"] in pilgrim_acts else 0
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

    # ---- world graph (data/world.json): nodes are the maps, edges the roads between them
    world = load("world")
    nodes, edges, regions = world.get("nodes", {}), world.get("edges", []), world.get("regions", {})
    DEFAULT_BOUNDS = [-24, -14, 48, 28]
    PORTAL_CLEAR, ARRIVE_MIN, ARRIVE_MAX, TRIGGER = 3.0, 2.0, 6.0, 1.3
    def inside(mid: str, pt) -> bool:
        b = maps[mid].get("bounds", DEFAULT_BOUNDS)
        return b[0] <= pt[0] <= b[0] + b[2] and b[1] <= pt[1] <= b[1] + b[3]
    def dist(a, b) -> float:
        return ((a[0] - b[0]) ** 2 + (a[-1] - b[-1]) ** 2) ** 0.5
    for mid_ in maps:
        if mid_ not in nodes:
            err(f"world: map {mid_} is not a node of the world graph")
    for nid, n in nodes.items():
        if nid not in maps:
            err(f"world: node {nid} has no map file"); continue
        if n.get("kind") not in ("town", "field", "danger", "story", "instance"):
            err(f"world: node {nid} has unknown kind {n.get('kind')}")
        if n.get("region") not in regions:
            err(f"world: node {nid} is in unknown region {n.get('region')}")
        lv = n.get("level", [])
        if not (len(lv) == 2 and 1 <= lv[0] <= lv[1] <= prog.get("max_base", 99)):
            err(f"world: node {nid} needs a level range [low, high]")
        if n.get("kind") == "town" and not ("waymark" in n and inside(nid, n["waymark"])):
            err(f"world: town {nid} needs a Waymark point inside its bounds")
    links = {}
    for e in edges:
        a_, b_ = e.get("from"), e.get("to")
        ew = f"world edge {a_}->{b_}"
        if a_ not in nodes or b_ not in nodes or a_ not in maps or b_ not in maps:
            err(f"{ew}: unknown map"); continue
        if (a_, b_) in links:
            err(f"{ew}: listed twice")
        links[(a_, b_)] = e
        kind = e.get("kind")
        if kind not in ("portal", "door", "exit", "story"):
            err(f"{ew}: unknown kind {kind}")
        if "arrive" in e and not inside(b_, e["arrive"]):
            err(f"{ew}: arrival point {e['arrive']} is outside {b_}")
        if kind in ("portal", "door", "exit") and "arrive" not in e:
            err(f"{ew}: needs an arrival point")
        scripted = (ROOT / "scripts" / "maps" / f"{a_}.gd").exists()
        ent_at = {x["id"]: x["at"] for x in maps[a_].get("ents", [])}
        if kind in ("portal", "door") and "ent" in e and e["ent"] not in ent_at and not scripted:
            err(f"{ew}: unknown entity {e['ent']}")
        if kind == "door" and not ("ent" in e and "needs" in e):
            err(f"{ew}: a door needs an entity and the flag that opens it")
        if kind == "portal":
            if "at" not in e or not inside(a_, e["at"]):
                err(f"{ew}: portal needs a position inside {a_}"); continue
            if e.get("forward") and not any(o.get("type") == "exit" and o.get("to") == b_ and dist(o["zone"], e["at"]) < 0.1 for o in maps[a_]["objectives"]):
                err(f"{ew}: a forward portal stands on its map's exit zone")
            if not e.get("forward"):   # a way back must not sit on top of the story
                spots = [x for i, x in ent_at.items()] + [o["zone"] for o in maps[a_]["objectives"] if "zone" in o] + [pt for o in maps[a_]["objectives"] for pt in o.get("points", [])]
                for sp in spots:
                    if dist(sp, e["at"]) < PORTAL_CLEAR:
                        err(f"{ew}: portal at {e['at']} is within {PORTAL_CLEAR} of a story spot {sp}")
    for (a_, b_), e in links.items():
        back = links.get((b_, a_))
        if back is None:
            if not e.get("story_oneway"):
                err(f"world edge {a_}->{b_}: no way back (add the return edge or mark it story_oneway)")
            continue
        if "arrive" in e and back.get("kind") == "portal" and "at" in back:
            d_ = dist(e["arrive"], back["at"])
            if not ARRIVE_MIN <= d_ <= ARRIVE_MAX:
                err(f"world edge {a_}->{b_}: arrives {d_:.1f} from the portal back (want {ARRIVE_MIN}-{ARRIVE_MAX}, so the pilgrim is not bounced)")
        for other in edges:
            if other.get("from") == b_ and other.get("kind") == "portal" and other is not back and "arrive" in e and "at" in other and dist(e["arrive"], other["at"]) < TRIGGER:
                err(f"world edge {a_}->{b_}: arrives on top of the portal to {other.get('to')}")
    def reach(start: str) -> set:
        seen, todo = {start}, [start]
        while todo:
            cur_ = todo.pop()
            for (a_, b_) in links:
                if a_ == cur_ and b_ not in seen:
                    seen.add(b_); todo.append(b_)
        return seen
    start_node = world.get("start", "")
    if start_node in nodes:
        for nid in set(nodes) - reach(start_node):
            err(f"world: {nid} cannot be reached from {start_node}")
        towns = [n_ for n_, v in nodes.items() if v.get("kind") == "town"]
        for nid in nodes:
            if nid == start_node:
                continue
            got = reach(nid)
            for other in set(nodes) - got - {start_node}:
                err(f"world: no road from {nid} to {other}")
            if towns and not any(t in got for t in towns):
                err(f"world: no town can be reached from {nid}")
    else:
        err("world: 'start' must name a node")
    for mid_, d in maps.items():   # every scripted trip between maps is a road on the graph
        for o in d.get("objectives", []):
            if o.get("type") in ("exit", "travel") and (mid_, o.get("to")) not in links:
                err(f"map {mid_} objective {o.get('id')}: its trip to {o.get('to')} is not an edge of the world graph")
    # level ranges rise along the story and leave no gap; region bands are ordered and overlap only at the edges
    chain = [a for a in acts.get("order", []) if a in nodes]
    for prev, nxt in zip(chain, chain[1:]):
        lo0, hi0 = nodes[prev].get("level", [1, 1]); lo1, _hi1 = nodes[nxt].get("level", [1, 1])
        if lo1 < lo0 or lo1 > hi0 + 1:
            err(f"world: level range of {nxt} ({lo1}+) does not follow {prev} ({lo0}-{hi0})")
    bands = [(rid, r.get("band", [])) for rid, r in regions.items() if not r.get("prologue")]
    for (r0, b0), (r1, b1) in zip(bands, bands[1:]):
        if len(b0) != 2 or len(b1) != 2:
            err(f"world: regions {r0} and {r1} need a band [low, high]"); continue
        overlap = b0[1] - b1[0]
        if b1[0] < b0[0] or overlap < 0 or overlap > 0.5 * min(b0[1] - b0[0], b1[1] - b1[0]):
            err(f"world: band of {r1} {b1} overlaps badly with {r0} {b0}")
    for rid, r in regions.items():
        check_name(f"world region {rid}", r.get("name", ""))

    # ---- budgets
    total = [0, 0]
    for a in acts.get("order", []):
        plan = acts["acts"][a]
        if budget[a] != [plan["base"], plan["job"]]:
            err(f"act {a}: objectives pay {budget[a]} but the design budget is [{plan['base']}, {plan['job']}]")
        if a in pilgrim_acts:
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
    print(f"validate_data: OK · {len(maps)} maps · world graph {len(nodes)} nodes, {len(edges)} roads · {len(dialogue)} dialogue scenes · quest XP {total[0]}/{total[1]} · required-kill mob XP {kill_xp} ({share:.0%}) · planned {minutes} min")
    return 0

if __name__ == "__main__":
    sys.exit(main())
