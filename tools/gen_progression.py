#!/usr/bin/env python3
"""Builds the XP tables past Base 10 from a pacing plan (0.6.0, phase 3) and prints the maths.

    python3 tools/gen_progression.py          # rewrite data/progression.json "base_table" and "job_first"
    python3 tools/gen_progression.py --check  # exit 1 if the tables in the file are not what the plan gives

The plan is data/progression.json "pace". Levels 1 to 10 are not touched: their costs are the quest
budget (2,210 / 855). From Base 10 on, the cost of a level is

    cost(L) = minutes(L) / 60 x kills_per_hour(L) x kill_xp(L) / (1 - board_share)

minutes(L)        target minutes for the level, read off the anchors (straight lines between them)
kills_per_hour(L) 3600 / (time to overcome an even-level foe + overhead), with the standard build below
kill_xp(L)        what an even-level foe pays (the same formula the game uses)
board_share       the part of all XP expected to come from Gleanings at the town boards

The autotest's balance report recomputes the same hours from the game's own code and fails if a
band is more than 25% off its target, so a change to stats, foes or tables that breaks the pacing is caught.
"""
import json
import sys
from pathlib import Path

PATH = Path(__file__).resolve().parent.parent / "data" / "progression.json"

def lerp_anchors(anchors, x):
    for (x0, y0), (x1, y1) in zip(anchors, anchors[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return anchors[-1][1] if x > anchors[-1][0] else anchors[0][1]

def kill_xp(p, lv):
    r = p["mob_xp"]
    over = max(0, lv - int(r["quad_from"]))
    return int(r["base"]) + int(r["per_level"]) * lv + over * over // int(r["quad_div"])

def kills_per_hour(p, lv):
    """The standard build: every level's two points go one to Fortitude and one to Steadfastness."""
    pace, mob, weak = p["pace"], p["mob"], p["weakness"]
    start = 3
    stat = {"for": start + lv - 1, "ste": start + lv - 1, "dil": start, "sob": start, "hop": start, "wis": start}
    atk = 4 + 2 * stat["for"] + lv
    interval = max(0.6, 1.2 - 0.04 * stat["dil"])
    miss = max(0.0, 0.11 - 0.012 * stat["sob"])
    crit = 0.06 + 0.015 * stat["hop"]
    fams = weak["families"]
    weakness = sum(1.0 + min(weak["cap"], weak["per_point"] * max(0, stat[s] - start)) for s in fams.values()) / len(fams)
    dps = atk * (1 - miss) * (1 + crit) / interval * pace["skill_factor"] * weakness
    hp = mob["hp_base"] + mob["hp_per_lv"] * lv
    return 3600.0 / (hp / dps + pace["overhead_s"])

def build(p):
    pace = p["pace"]
    top = int(p["max_base"])
    base, rate = [], {}
    for lv in range(10, top):
        per_hour = kills_per_hour(p, lv) * kill_xp(p, lv) / (1 - pace["board_share"])
        rate[lv] = per_hour
        base.append(int(round(lerp_anchors(pace["anchors"], lv) / 60.0 * per_hour / 10.0)) * 10)
    # the first job: its 49 levels are spread over the hours in "job_anchors", earned beside the Base levels
    job, lv, left = [], 10, lerp_anchors(pace["anchors"], 10)   # minutes left in the current Base level
    for jl in range(1, int(p["max_job"])):
        need = lerp_anchors(pace["job_anchors"], jl)
        got = 0.0
        while need > 1e-9:
            step = min(need, left)
            got += step / 60.0 * rate[min(lv, top - 1)] * p["mob"]["job_share"]
            need -= step; left -= step
            if left <= 1e-9:
                lv = min(lv + 1, top - 1); left = lerp_anchors(pace["anchors"], lv)
        job.append(int(round(got / 10.0)) * 10)
    return base, job

def main():
    p = json.loads(PATH.read_text(encoding="utf-8"))
    base, job = build(p)
    if "--check" in sys.argv:
        ok = p.get("base_table") == base and p.get("job_first") == job
        print("gen_progression: tables match the plan" if ok else "gen_progression: data/progression.json tables do not match the plan; run tools/gen_progression.py")
        return 0 if ok else 1
    p["base_table"], p["job_first"] = base, job
    PATH.write_text(json.dumps(p, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print("level  minutes  kills/h  xp/kill      cost   kills   hours so far")
    hours = 0.0
    for i, lv in enumerate(range(10, int(p["max_base"]))):
        mins = lerp_anchors(p["pace"]["anchors"], lv); hours += mins / 60
        if lv in (10, 12, 15, 16, 20, 25, 26, 30, 40, 50, 60, 70, 80, 90, 98):
            share = base[i] * (1 - p["pace"]["board_share"])
            print("%5d  %7.0f  %7.0f  %7d  %8d  %6.0f  %8.1f" % (lv, mins, kills_per_hour(p, lv), kill_xp(p, lv), base[i], share / kill_xp(p, lv), hours))
    print("Base 10 to 99: %.0f hours · dearest level %.1f hours · first job 1 to 50: %.0f hours" % (hours, max(lerp_anchors(p["pace"]["anchors"], l) for l in range(10, 99)) / 60, sum(lerp_anchors(p["pace"]["job_anchors"], j) for j in range(1, 50)) / 60))
    return 0

if __name__ == "__main__":
    sys.exit(main())
