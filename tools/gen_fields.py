#!/usr/bin/env python3
"""Writes the towns, fields and danger zones of regions 1 to 4 (0.6.0, phase 2) from the short
specs below: data/maps/<id>.json, their nodes and roads in data/world.json, their foes in
data/mobs.json and their words in data/dialogue.json.

    python3 tools/gen_fields.py          # rewrite every map listed here, then run validate_data.py

Running it again overwrites the maps it owns (MAPS below) and nothing else. Story maps are edited
only by adding the entities and roads named in ATTACH. Every game-original name carries
"review": true so it can be found for theological review (see DECISIONS.md).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

def load(name):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))

def save(name, obj):
    (DATA / f"{name}.json").write_text(json.dumps(obj, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")

BUNYAN = "After John Bunyan, The Pilgrim's Progress (1678)"
BUNYAN_PD = "John Bunyan, The Pilgrim's Progress (1678) · public domain"

# ------------------------------------------------------------------ foes added for the fields (all game-original names: review)
MOBS = {
    # id: (name, level, sprite, family, size, tint, kind)
    "gossip": ("Gossip", 4, "envy_common", "envy", 1.25, "#ffffff", ""),
    "mocker": ("Mocker", 5, "pride_common", "pride", 1.3, "#e8d8c0", "ranged"),
    "grudge": ("Grudge", 6, "wrath_common", "wrath", 1.3, "#ffffff", ""),
    "hoarder": ("Hoarder", 7, "greed_common", "greed", 1.3, "#ffffff", ""),
    "miser": ("Miser", 9, "greed_elite", "greed", 1.5, "#ffffff", ""),
    "bog_lurker": ("Bog Lurker", 9, "sloth_rare", "sloth", 1.5, "#c8d8b8", ""),
    "sinker": ("Sinker", 11, "gluttony_rare", "doubt", 1.5, "#ffffff", ""),
    "sinai_ember": ("Ember of the Mount", 12, "wrath_common", "wrath", 1.35, "#ffd8b0", "ranged"),
    "legalist": ("Legalist", 13, "pride_elite", "pride", 1.55, "#e0e0f0", ""),
    "weedling": ("Weedling", 6, "envy_common", "envy", 1.2, "#c8f0c0", ""),
    "dust_mote": ("Dust Mote", 7, "pride_common", "pride", 1.2, "#d8d0c0", ""),
    "self_trust": ("Self-Trust", 15, "pride_rare", "pride", 1.5, "#f0e0c8", ""),
    "scorner": ("Scorner", 16, "wrath_elite", "wrath", 1.5, "#e8e0d0", "ranged"),
    "backward_glance": ("Backward Glance", 17, "lust_common", "doubt", 1.3, "#ffffff", ""),
    "heavy_heart": ("Heavy Heart", 18, "envy_elite", "doubt", 1.5, "#ffffff", ""),
    "dust_wraith": ("Dust Wraith", 18, "lust_elite", "pride", 1.6, "#d8d0c0", "ranged"),
    "prowler": ("Prowler", 19, "wrath_rare", "wrath", 1.5, "#ffffff", ""),
    "snare": ("Snare", 20, "greed_rare", "greed", 1.5, "#ffffff", ""),
    "wood_shade": ("Shade of the Wood", 21, "lust_common", "doubt", 1.4, "#c0c8e0", "ranged"),
    "ruin": ("Ruin", 23, "wrath_elite", "wrath", 1.6, "#c8c0d8", ""),
    "dark_stumbler": ("Stumbler in the Dark", 24, "sloth_elite", "sloth", 1.6, "#b8b8d0", ""),
    "pitfall": ("Pitfall", 25, "greed_elite", "greed", 1.6, "#c0c0d8", ""),
}
BOSSES = {
    # id: (name, level, sprite, family, hp, atk, slam, xp_bonus, size)
    "cellar_keeper": ("The Keeper of the Cellars", 10, "greed_greater", "greed", 1000, 13, 19, 30, 2.6),
    "bog_dread": ("Dread of the Deep Mire", 16, "gluttony_greater", "doubt", 1900, 22, 31, 60, 2.8),
    "stirred_dust": ("The Stirred Dust", 20, "pride_greater", "pride", 2500, 27, 38, 80, 2.8),
}

# ------------------------------------------------------------------ looks, by country
LOOKS = {
    "city": {"bg": "#2a2832", "amb": "#a8a4c0", "amb_e": 0.38, "tint": [0.86, 0.87, 0.98], "sun_e": 0.55, "sun_c": "#c8c4d8", "post": [0.72, 1.08, [0.93, 0.95, 1.05]],
             "mini": "#8c9484", "ground": "grass_dark", "ground_b": "dirt_dark", "weather": "drizzle", "flora": "dark", "rock": "stone", "tufts": 60, "flowers": 2},
    "town_city": {"bg": "#2a2832", "amb": "#b0acc4", "amb_e": 0.42, "tint": [0.9, 0.9, 0.98], "sun_e": 0.6, "sun_c": "#d0ccd8", "post": [0.76, 1.06, [0.95, 0.96, 1.03]],
                  "mini": "#9c9484", "ground": "cobble", "ground_b": "cobble_dark", "weather": "drizzle", "flora": "dark", "rock": "stone", "tufts": 0, "flowers": 0, "patches": 10},
    "cellar": {"bg": "#16141a", "amb": "#9890a8", "amb_e": 0.42, "tint": [0.84, 0.82, 0.94], "sun_e": 0.35, "sun_c": "#b0a8c0", "post": [0.7, 1.08, [0.94, 0.92, 1.04]],
               "mini": "#4a4650", "ground": "cobble_dark", "ground_b": "dirt_dark", "weather": "", "flora": "dark", "rock": "dark", "tufts": 0, "flowers": 0, "patches": 8},
    "slough": {"bg": "#28302a", "amb": "#a8b0a8", "amb_e": 0.36, "tint": [0.88, 0.92, 0.9], "sun_e": 0.5, "sun_c": "#c8d0c8", "post": [0.7, 1.06, [0.94, 0.98, 0.98]],
               "mini": "#7a8a6a", "ground": "marsh", "ground_b": "grass_dark", "weather": "drizzle", "flora": "dark", "rock": "stone"},
    "bog": {"bg": "#1a201c", "amb": "#98a898", "amb_e": 0.38, "tint": [0.82, 0.9, 0.86], "sun_e": 0.4, "sun_c": "#b0c0b0", "post": [0.66, 1.08, [0.92, 0.98, 0.96]],
            "mini": "#4a5a48", "ground": "marsh", "ground_b": "mire", "weather": "drizzle", "flora": "dark", "rock": "dark", "tufts": 40, "flowers": 0},
    "sinai": {"bg": "#2a2420", "amb": "#c8b0a0", "amb_e": 0.4, "tint": [1.0, 0.9, 0.84], "sun_e": 0.6, "sun_c": "#ffc890", "post": [0.8, 1.1, [1.04, 0.96, 0.92]],
              "mini": "#8a7868", "ground": "rock", "ground_b": "dirt_dark", "weather": "", "flora": "dry", "rock": "earth", "tufts": 20, "flowers": 0},
    "town_gate": {"bg": "#2c3428", "amb": "#d8dcc8", "amb_e": 0.42, "tint": [0.98, 1.0, 0.92], "sun_e": 0.7, "sun_c": "#fff0c8", "post": [0.84, 1.04, [1.0, 1.0, 0.96]],
                  "mini": "#a8b088", "ground": "grass", "ground_b": "cobble_warm", "weather": "", "flora": "green", "rock": "stone", "tufts": 40, "flowers": 8},
    "garden": {"bg": "#34382a", "amb": "#f0e8d8", "amb_e": 0.44, "tint": [1.03, 1.0, 0.92], "sun_e": 0.78, "sun_c": "#fff0d0", "post": [0.88, 1.04, [1.02, 1.0, 0.96]],
               "mini": "#b0c088", "ground": "grass", "ground_b": "grass_dry", "weather": "petals", "flora": "green", "rock": "stone", "flowers": 18},
    "cross": {"bg": "#3a3a2c", "amb": "#f0e8d8", "amb_e": 0.44, "tint": [1.04, 1.0, 0.92], "sun_e": 0.8, "sun_c": "#fff0d0", "post": [0.86, 1.04, [1.02, 1.0, 0.96]],
              "mini": "#b8c08a", "ground": "grass", "ground_b": "grass_dry", "weather": "", "flora": "green", "rock": "stone"},
    "house_cellar": {"bg": "#1c1814", "amb": "#c8b8a0", "amb_e": 0.4, "tint": [0.98, 0.92, 0.84], "sun_e": 0.35, "sun_c": "#e8d0a8", "post": [0.78, 1.06, [1.02, 0.98, 0.92]],
                     "mini": "#6a5c48", "ground": "plank", "ground_b": "dirt_dark", "weather": "", "flora": "dry", "rock": "earth", "tufts": 0, "flowers": 0, "patches": 10},
    "hill": {"bg": "#34302a", "amb": "#d8ccb8", "amb_e": 0.4, "tint": [1.0, 0.95, 0.88], "sun_e": 0.66, "sun_c": "#ffd8a0", "post": [0.88, 1.06, [1.03, 0.99, 0.94]],
             "mini": "#a89878", "ground": "grass_dry", "ground_b": "dirt", "weather": "", "flora": "dry", "rock": "earth"},
    "wood": {"bg": "#1c221c", "amb": "#98a890", "amb_e": 0.36, "tint": [0.84, 0.9, 0.84], "sun_e": 0.42, "sun_c": "#b8c8a8", "post": [0.72, 1.08, [0.94, 0.98, 0.94]],
             "mini": "#4a5a40", "ground": "grass_dark", "ground_b": "leaves", "weather": "", "flora": "dark", "rock": "dark", "tufts": 60, "flowers": 0},
    "dark": {"bg": "#14141e", "amb": "#9090c0", "amb_e": 0.5, "tint": [0.82, 0.84, 1.0], "sun_e": 0.5, "sun_c": "#a0a0e0", "post": [0.7, 1.05, [0.9, 0.92, 1.08]],
             "mini": "#3a3a50", "ground": "rock_dark", "ground_b": "pit", "weather": "", "flora": "dark", "rock": "dark", "tufts": 30, "flowers": 0},
}
RIDGE_TINT = {"city": "#5a5a64", "slough": "#6a7264", "bog": "#4a5448", "sinai": "#8a6a58", "garden": "#a09a8a", "cross": "#a09a8a", "hill": "#8a8478", "wood": "#4a5444", "dark": "#3a3a50"}

# ------------------------------------------------------------------ shapes
FIELD = {"bounds": [-30, -16, 60, 32], "sides": {"W": [-28, 0], "E": [28, 0], "N": [0, -14], "S": [0, 14]}}
TOWN = {"bounds": [-18, -12, 36, 24], "sides": {"W": [-16, 0], "E": [16, 0], "N": [0, -10], "S": [0, 10]}}
FLOOR = {"bounds": [-24, -9, 48, 18], "sides": {"W": [-22, 0], "E": [22, 0]}}
QUAD = {"NW": [-26, -13, 22, 9.5], "NE": [4, -13, 22, 9.5], "SW": [-26, 3.5, 22, 9.5], "SE": [4, 3.5, 22, 9.5]}
INWARD = 2.6

def inward(pt, bounds):
    """A point INWARD units from a portal toward the middle of its map."""
    cx, cz = bounds[0] + bounds[2] / 2, bounds[1] + bounds[3] / 2
    dx, dz = cx - pt[0], cz - pt[1]
    n = (dx * dx + dz * dz) ** 0.5
    return [round(pt[0] + dx / n * INWARD, 1), round(pt[1] + dz / n * INWARD, 1)]

# ------------------------------------------------------------------ the places
# kind, id, name, review?, region, act, [lo, hi], look, music, then what is there
def field(id, name, review, region, act, level, look, music, spawns, landmark, secret, page, decor=(), burden=True):
    return {"shape": "field", "id": id, "name": name, "review": review, "region": region, "act": act, "level": level, "look": look, "music": music,
            "spawns": spawns, "landmark": landmark, "secret": secret, "page": page, "decor": list(decor), "burden": burden}

def floor(id, name, review, region, act, level, look, music, spawns, hazards, boss=None, burden=True):
    return {"shape": "floor", "id": id, "name": name, "review": review, "region": region, "act": act, "level": level, "look": look, "music": music,
            "spawns": spawns, "hazards": hazards, "boss": boss, "burden": burden}

def town(id, name, review, region, act, level, look, music, folk, keeper, rest, burden=True):
    return {"shape": "town", "id": id, "name": name, "review": review, "region": region, "act": act, "level": level, "look": look, "music": music,
            "folk": folk, "keeper": keeper, "rest": rest, "burden": burden}

# a spawn row: (mob, count, lo, hi, aggro, quadrant[, greater])
MAPS = [
    # ---------------- region 1: the City of Destruction (band 1-10)
    town("city_square", "The City Square", False, "city", "city", [1, 10], "town_city", "city",
         folk=[("Old Neighbour", [0, 4, 5], [-5, 5], "My father built this house, and his father before him. Evangelist says the whole street stands on sand. I have begun to look at the foundations at night.", "[BSB: Matthew 7:26]"),
               ("Lamplighter", [1, 1, 3], [10, 5.5], "I light every lamp on this square, and by midnight the street is dark again. They say there is a lamp for the feet that does not go out.", "[BSB: Psalm 119:105]"),
               ("Woman at the Well", [2, 0, 4], [-12, 3.5], "Draw from this well and you thirst again by noon. I have heard there is water of another kind, and I mean to ask where.", "[BSB: John 4:13–14]")],
         keeper=("Square Provisioner", "wayfarer"), rest=("well", "The Old Well")),
    field("sloth_meadow", "Sloth Meadow", True, "city", "city", [1, 4], "city", "city",
          spawns=[("slothling", 7, 1, 2, "passive", "NW"), ("slothling", 5, 2, 3, "passive", "SW"), ("whelp", 5, 2, 4, "passive", "NE"), ("whelp", 4, 3, 4, "alert", "SE"), ("whelp", 1, 4, 4, "passive", "SE", True)],
          landmark=("wall_low", "A Broken Wall", [-12, -8], "A field wall, fallen in and grown over with thorns. Someone has scratched the proverb into it: a little sleep, a little slumber, a little folding of the hands to rest.", "[BSB: Proverbs 6:10]"),
          secret=([17, 9], "A Rusted Sickle", "Left in the long grass at the edge of a harvest that was never brought in. A few coins lie under it, as forgotten as the work. Denarii +25.", 25),
          page=([-20, 10.5], "A page caught in the long grass. I had written of the sluggard's field: all grown over with thorns, its stone wall broken down. I looked at it, and took instruction.", "[BSB: Proverbs 24:30–32]"),
          decor=["trees", "bushes", "rocks"]),
    field("neighbours_lane", "Neighbours' Lane", True, "city", "city", [3, 6], "city", "city",
          spawns=[("gossip", 6, 3, 4, "alert", "NW"), ("scoffling", 4, 3, 5, "passive", "SW"), ("mocker", 5, 4, 6, "aggressive", "NE"), ("gossip", 5, 4, 6, "alert", "SE"), ("mocker", 1, 6, 6, "aggressive", "NE", True)],
          landmark=("signpost", "The Guild Notice", [10, -7], "A notice nailed up by the guild: whoever sets out for the Gate forfeits his seat. Under it, in another hand: what does it profit a man to gain the whole world?", "[BSB: Mark 8:36]"),
          secret=([-18, -9], "A Dropped Letter", "A letter never sent, begging a brother to come back from the road. A few coins were folded into it for his journey home. Denarii +30.", 30),
          page=([21, 11], "A page blown against a doorstep. I had written how his neighbours came out to see him run: some mocked, some threatened, and some called after him to return.", BUNYAN),
          decor=["houses", "crates", "bushes"]),
    field("evangelists_road", "Evangelist's Road", False, "city", "city", [5, 8], "city", "city",
          spawns=[("grudge", 6, 5, 6, "aggressive", "NW"), ("hoarder", 5, 6, 7, "passive", "SW"), ("grudge", 5, 6, 8, "aggressive", "NE"), ("hoarder", 5, 7, 8, "alert", "SE"), ("grudge", 1, 8, 8, "aggressive", "NE", True)],
          landmark=("signpost", "The Fingerpost", [0, -6], "The post points one way only: across the wide plain, toward a light. Beneath it are the words from his parchment roll: flee from the wrath to come.", "[BSB: Matthew 3:7]"),
          secret=([-16, 9.5], "A Traveller's Cache", "Under a flat stone, a purse left by someone who went on lighter. Denarii +35.", 35),
          page=([22, -10], "A page on the road out of the city. I wrote down the question he was asked, whether he saw yonder shining light, and his answer: I think I do. It was enough to walk by.", "[BSB: 2 Peter 1:19]"),
          decor=["rocks", "bushes", "dead_trees"]),
    floor("old_cellars_1", "The Old Cellars", True, "city", "city", [7, 9], "cellar", "city",
          spawns=[("hoarder", 5, 7, 8, "aggressive", [-16, -6, 14, 12]), ("miser", 4, 8, 9, "aggressive", [2, -6, 16, 12])],
          hazards=[([-4, -8, 3, 6], "a rotten floor", "pit", {"hurt": 6}), ([8, 2, 3, 6], "a rotten floor", "pit", {"hurt": 6})]),
    floor("old_cellars_2", "The Old Cellars: the Vault", True, "city", "city", [8, 10], "cellar", "city",
          spawns=[("miser", 6, 8, 10, "aggressive", [-16, -6, 18, 12]), ("hoarder", 3, 9, 10, "aggressive", [-10, -6, 12, 12])],
          hazards=[([-2, -8, 3, 7], "a rotten floor", "pit", {"hurt": 7}), ([-2, 2, 3, 6], "a rotten floor", "pit", {"hurt": 7})],
          boss={"mob": "cellar_keeper", "at": [15, 0], "lv": 10}),
    # ---------------- region 2: the Slough and the Gate (band 8-16)
    town("wicket_gate", "The Wicket Gate", False, "slough", "slough", [6, 16], "town_gate", "slough",
         folk=[("Pilgrim at Rest", [1, 2, 2], [-5, 5], "I knocked more than once before I had the courage to knock loudly. It was opened. Whoever comes is not cast out, the keeper told me.", "[BSB: John 6:37]"),
               ("Mender of the Road", [0, 1, 3], [10, 5.5], "Cartloads of good instruction have gone into that slough, and it is a slough still. But there are steps through the midst of it, for those who look.", BUNYAN),
               ("Watcher on the Wall", [2, 3, 5], [-12, 3.5], "From up here I have seen arrows shot from the castle yonder at those who stand knocking. That is why the keeper pulled you in so quickly.", BUNYAN)],
         keeper=("Gatehouse Provisioner", "steward"), rest=("table", "The Gatehouse Bench")),
    field("slough_shallows", "The Slough Shallows", False, "slough", "slough", [5, 8], "slough", "slough",
          spawns=[("mire_sloth", 6, 5, 6, "passive", "NW"), ("glutton_grub", 5, 5, 7, "passive", "SW"), ("despondling", 4, 6, 8, "aggressive", "NE"), ("mire_sloth", 5, 6, 8, "alert", "SE"), ("glutton_grub", 1, 8, 8, "passive", "SW", True)],
          landmark=("signpost", "A Leaning Marker", [-8, 6], "A marker, half sunk: the steps are in the midst of the slough. Look for them. Fear makes men miss them.", BUNYAN),
          secret=([18, -9], "A Lost Satchel", "Dropped by someone who turned back for home at the first mud. Denarii +35.", 35),
          page=([-21, -10], "A page drying on a reed. I had written why the ground is so bad here: the fears and doubts of one newly awakened settle in this place. It is not the pleasure of the Lord of the way that it should stay so.", BUNYAN),
          decor=["reeds", "dead_trees", "ponds", "fog"]),
    field("slough_deeps", "The Slough Deeps", False, "slough", "slough", [9, 13], "bog", "slough",
          spawns=[("bog_lurker", 6, 9, 10, "aggressive", "NW"), ("despondling", 5, 9, 11, "aggressive", "SW"), ("sinker", 5, 11, 12, "alert", "NE"), ("bog_lurker", 5, 11, 13, "aggressive", "SE"), ("sinker", 1, 13, 13, "aggressive", "NE", True)],
          landmark=("crate", "A Sunken Cart", [9, 7], "A cart of good instructions, sunk to the axle. Thousands like it lie under this ground. The mending of this place was never going to be done by cartloads.", BUNYAN),
          secret=([-19, 9], "A Reed Basket", "Wedged in the reeds above the waterline, and dry inside. Denarii +50.", 50),
          page=([20, -10.5], "A page weighted with a stone on the one dry hummock. I wrote the prayer of one sinking in deep mire where there is no foothold: rescue me from the mire, and do not let me sink.", "[BSB: Psalm 69:14]"),
          decor=["reeds", "dead_trees", "ponds", "fog"]),
    field("sinai_foot", "The Foot of Mount Sinai", True, "slough", "slough", [11, 15], "sinai", "slough",
          spawns=[("sinai_ember", 6, 11, 12, "aggressive", "NW"), ("legalist", 5, 12, 13, "passive", "SW"), ("sinai_ember", 5, 13, 14, "aggressive", "NE"), ("legalist", 5, 13, 15, "alert", "SE"), ("legalist", 1, 15, 15, "aggressive", "SE", True)],
          landmark=("menhir_b", "A Scorched Stone", [-9, -7], "Burned into the stone: whoever keeps the whole law and yet stumbles at one point is guilty of breaking all of it.", "[BSB: James 2:10]"),
          secret=([16, 10], "A Dropped Bundle", "Thrown down by someone who ran from the hill when it flashed. Denarii +55.", 55),
          page=([-22, 9.5], "A page scorched at the edges. I wrote how the hill hung so far over the road that he feared it would fall on his head, and fire flashed out of it. Under it I wrote: no one is justified by works of the law.", "[BSB: Galatians 2:16]"),
          decor=["rocks", "spires", "dead_trees"]),
    floor("slough_bog_1", "The Slough Bog", True, "slough", "slough", [12, 14], "bog", "slough",
          spawns=[("bog_lurker", 5, 12, 13, "aggressive", [-16, -6, 14, 12]), ("sinker", 4, 13, 14, "aggressive", [2, -6, 16, 12])],
          hazards=[([-6, -8, 5, 6], "the sucking mire", "mire", {"slow": 0.5, "drain": 2.0}), ([6, 2, 5, 6], "the sucking mire", "mire", {"slow": 0.5, "drain": 2.0})]),
    floor("slough_bog_2", "The Slough Bog: the Deep Mire", True, "slough", "slough", [14, 16], "bog", "slough",
          spawns=[("sinker", 6, 14, 15, "aggressive", [-16, -6, 18, 12]), ("bog_lurker", 3, 15, 16, "aggressive", [-10, -6, 12, 12])],
          hazards=[([-4, -8, 5, 7], "the sucking mire", "mire", {"slow": 0.5, "drain": 2.5}), ([-4, 2, 5, 6], "the sucking mire", "mire", {"slow": 0.5, "drain": 2.5})],
          boss={"mob": "bog_dread", "at": [15, 0], "lv": 16}),
    # ---------------- region 3: the Interpreter and the Cross (band 14-20)
    field("house_gardens", "The House Gardens", True, "interpreter_cross", "interpreter", [6, 9], "garden", "interpreter",
          spawns=[("weedling", 7, 6, 7, "passive", "NW"), ("dust_mote", 5, 6, 8, "passive", "SW"), ("weedling", 5, 7, 9, "alert", "NE"), ("dust_mote", 5, 8, 9, "aggressive", "SE"), ("weedling", 1, 9, 9, "alert", "NE", True)],
          landmark=("pedestal", "The Sundial", [8, -7], "Cut around the rim of the dial: make the most of the time, because the days are evil.", "[BSB: Ephesians 5:16]"),
          secret=([-17, 9], "A Gardener's Tin", "Tucked under a bench: twine, a pruning knife, and the gardener's small savings, left for whoever weeds this bed. Denarii +40.", 40),
          page=([21, 10.5], "A page pressed between two flowerpots. I wrote that one plants and another waters, and neither is anything: the increase is given.", "[BSB: 1 Corinthians 3:7]"),
          decor=["trees", "blooms", "bushes"]),
    field("wall_road", "The Road by the Wall called Salvation", False, "interpreter_cross", "cross", [14, 17], "cross", "cross",
          spawns=[("self_trust", 6, 14, 15, "passive", "NW"), ("scorner", 5, 14, 16, "aggressive", "SW"), ("self_trust", 5, 15, 17, "alert", "NE"), ("scorner", 5, 16, 17, "aggressive", "SE"), ("self_trust", 1, 17, 17, "aggressive", "NE", True)],
          landmark=("wall", "The Wall called Salvation", [0, -8], "The highway is fenced on either side with a wall, and the wall is called Salvation. Cut small beneath the name: not by works, so that no one may boast.", "[BSB: Ephesians 2:9]"),
          secret=([-20, 9], "A Mason's Mark", "Behind a loose stone at the foot of the wall, a mason's wage left long ago. Denarii +70.", 70),
          page=([22, -10], "A page held in a crack of the wall. I had written that the wall was called Salvation, and beside it the prophet's word: salvation is set up for walls and ramparts.", "[BSB: Isaiah 26:1]"),
          decor=["trees", "rocks", "blooms"], burden=False),
    field("cross_hill", "The Hill before the Cross", True, "interpreter_cross", "cross", [16, 19], "cross", "cross",
          spawns=[("backward_glance", 6, 16, 17, "passive", "NW"), ("heavy_heart", 5, 16, 18, "alert", "SW"), ("backward_glance", 5, 17, 19, "aggressive", "NE"), ("heavy_heart", 5, 18, 19, "aggressive", "SE"), ("heavy_heart", 1, 19, 19, "aggressive", "SE", True)],
          landmark=("menhir_a", "A Plain Stone", [10, 6], "A plain stone by the path, with one line: let us run with endurance, fixing our eyes on the author and perfecter of our faith.", "[BSB: Hebrews 12:1–2]"),
          secret=([-18, -9.5], "A Dropped Strap", "The broken strap of someone's burden, and the purse that hung from it. Whoever wore it did not come back for either. Denarii +80.", 80),
          page=([-21, 10], "A page lying face up in the grass. I wrote how he ran till he came to a place somewhat ascending. And beside it only this: far be it from me to boast, except in the cross.", "[BSB: Galatians 6:14]"),
          decor=["trees", "blooms", "rocks"], burden=False),
    floor("dusty_cellar_1", "The Dusty Cellar", True, "interpreter_cross", "interpreter", [16, 18], "house_cellar", "interpreter",
          spawns=[("dust_mote", 5, 16, 17, "aggressive", [-16, -6, 14, 12]), ("dust_wraith", 4, 17, 18, "aggressive", [2, -6, 16, 12])],
          hazards=[([-5, -8, 4, 6], "choking dust", "dirt_dark", {"slow": 0.7, "drain": 2.5}), ([7, 2, 4, 6], "choking dust", "dirt_dark", {"slow": 0.7, "drain": 2.5})], burden=False),
    floor("dusty_cellar_2", "The Dusty Cellar: the Unswept Room", True, "interpreter_cross", "interpreter", [18, 20], "house_cellar", "interpreter",
          spawns=[("dust_wraith", 6, 18, 19, "aggressive", [-16, -6, 18, 12]), ("dust_mote", 3, 19, 20, "aggressive", [-10, -6, 12, 12])],
          hazards=[([-3, -8, 4, 7], "choking dust", "dirt_dark", {"slow": 0.7, "drain": 3.0}), ([-3, 2, 4, 6], "choking dust", "dirt_dark", {"slow": 0.7, "drain": 3.0})],
          boss={"mob": "stirred_dust", "at": [15, 0], "lv": 20}, burden=False),
    # ---------------- region 4: the Hill Difficulty (band 18-26)
    town("arbour_rest", "The Arbour Rest", True, "hill", "hill", [7, 26], "hill", "hill",
         folk=[("Weary Pilgrim", [1, 3, 0], [-5, 5], "The arbour was made for refreshing, not for sleeping. I learned the difference the hard way, and went back down the hill for what I dropped.", BUNYAN + " · [BSB: 1 Thessalonians 5:6]"),
               ("Water Carrier", [2, 2, 2], [10, 5.5], "I carry the spring up from the foot of the hill. Drink. The way does not grow flatter, but those who wait and hope are given new strength.", "[BSB: Isaiah 40:31]"),
               ("Old Climber", [0, 5, 5], [-12, 3.5], "Two men went round this hill by easier ways, one to the left and one to the right. I have not seen either of them since.", BUNYAN + " · [BSB: Proverbs 14:12]")],
         keeper=("Hillside Provisioner", "shepherd"), rest=("arbour", "The Arbour"), burden=False),
    field("hill_slopes", "The Hill Slopes", False, "hill", "hill", [7, 10], "hill", "hill",
          spawns=[("stumbler", 6, 7, 8, "passive", "NW"), ("loiterer", 5, 8, 9, "passive", "SW"), ("pretender", 5, 8, 10, "aggressive", "NE"), ("stumbler", 5, 9, 10, "alert", "SE"), ("loiterer", 1, 10, 10, "passive", "SW", True)],
          landmark=("rock_b", "A Climber's Cairn", [-9, 7], "A cairn of small stones, one for each who passed. On the top stone: the end of a matter is better than its beginning, and patience is better than pride.", "[BSB: Ecclesiastes 7:8]"),
          secret=([18, -9.5], "A Staff in the Scree", "A walking staff wedged between two rocks, and a purse tied to it. Denarii +45.", 45),
          page=([-21, -10], "A page under a stone on the slope. I wrote how he fell from running to going, and from going to clambering upon his hands and his knees, because of the steepness of the place.", BUNYAN_PD),
          decor=["rocks", "trees", "bushes"], burden=False),
    field("spring_foot", "The Spring at the Foot of the Hill", False, "hill", "hill", [8, 10], "hill", "hill",
          spawns=[("loiterer", 6, 8, 9, "passive", "NW"), ("glutton_grub", 5, 8, 9, "passive", "SW"), ("loiterer", 5, 9, 10, "alert", "NE"), ("pretender", 4, 9, 10, "aggressive", "SE"), ("glutton_grub", 1, 10, 10, "passive", "SW", True)],
          landmark=("well", "The Spring", [6, -6], "Clear water rises here at the bottom of the hill. Someone has set a cup on the stone, and cut a line from the shepherd's psalm about being led beside quiet waters.", "[BSB: Psalm 23:2]"),
          secret=([-18, 9], "A Forgotten Flask", "Left full beside the water by someone in a hurry to take an easier road. Denarii +45.", 45),
          page=([20, 10.5], "A page weighted with a river stone. I wrote how he went to the spring and drank to refresh himself, and then began to go up the hill.", BUNYAN + " · [BSB: Isaiah 49:10]"),
          decor=["trees", "bushes", "ponds", "blooms"], burden=False),
    field("way_danger", "The Way called Danger", False, "hill", "hill", [18, 22], "wood", "hill",
          spawns=[("prowler", 6, 18, 19, "aggressive", "NW"), ("snare", 5, 19, 20, "passive", "SW"), ("wood_shade", 5, 20, 21, "aggressive", "NE"), ("prowler", 5, 20, 22, "alert", "SE"), ("snare", 1, 22, 22, "aggressive", "SW", True)],
          landmark=("signpost", "A Warning Board", [-10, -6], "A board at the mouth of the wood, the paint long gone. The proverb is cut into it instead: there is a way that seems right to a man, but its end is the way of death.", "[BSB: Proverbs 14:12]"),
          secret=([17, 9.5], "A Woodcutter's Cache", "In a hollow trunk, wrapped in oilcloth. The woodcutter did not come back for it. Denarii +90.", 90),
          page=([-22, 10], "A page nailed to a tree by a thorn. I wrote of the two who would not climb: one took the way which is called Danger, which led him into a great wood.", BUNYAN_PD),
          decor=["woods", "trees", "dead_trees", "fog", "mushrooms"], burden=False),
    floor("way_destruction_1", "The Way called Destruction", False, "hill", "hill", [22, 24], "dark", "shadow",
          spawns=[("ruin", 5, 22, 23, "aggressive", [-16, -6, 14, 12]), ("dark_stumbler", 4, 23, 24, "aggressive", [2, -6, 16, 12])],
          hazards=[([-6, -8, 4, 6], "a sheer drop", "pit", {"hurt": 16}), ([6, 2, 4, 6], "a sheer drop", "pit", {"hurt": 16})], burden=False),
    floor("way_destruction_2", "The Way called Destruction: the Dark Mountains", False, "hill", "hill", [24, 26], "dark", "shadow",
          spawns=[("pitfall", 6, 24, 25, "aggressive", [-16, -6, 18, 12]), ("dark_stumbler", 3, 25, 26, "aggressive", [-10, -6, 12, 12])],
          hazards=[([-4, -8, 4, 7], "a sheer drop", "pit", {"hurt": 18}), ([-4, 2, 4, 6], "a sheer drop", "pit", {"hurt": 18})],
          boss={"mob": "formalist", "at": [15, 0], "lv": 26}, burden=False),
]
SPEC = {m["id"]: m for m in MAPS}

# ------------------------------------------------------------------ roads: (a, a side or [x, z], b, b side or [x, z], flag that opens it)
ROADS = [
    ("city", [0, 10.5], "city_square", "N", None),
    ("city_square", "W", "sloth_meadow", "E", None),
    ("sloth_meadow", "W", "evangelists_road", "E", None),
    ("city_square", "E", "neighbours_lane", "W", None),
    ("neighbours_lane", "E", "old_cellars_1", "W", None),
    ("old_cellars_1", "E", "old_cellars_2", "W", None),
    ("slough", [-22, 7.5], "slough_shallows", "N", None),
    ("slough", [25.2, 6], "wicket_gate", "W", "gate_passed"),
    ("wicket_gate", "E", "sinai_foot", "W", None),
    ("wicket_gate", "S", "slough_deeps", "N", None),
    ("slough_deeps", "E", "slough_bog_1", "W", None),
    ("slough_bog_1", "E", "slough_bog_2", "W", None),
    ("interpreter", [6.5, 9.2], "house_gardens", "W", None),
    ("interpreter", [13, 9.2], "wall_road", "W", None),
    ("wall_road", "E", "cross_hill", "W", None),
    ("interpreter", [-13, -5], "dusty_cellar_1", "W", None),
    ("dusty_cellar_1", "E", "dusty_cellar_2", "W", None),
    ("hill", [4, 8.5], "arbour_rest", "N", None),
    ("arbour_rest", "E", "hill_slopes", "W", None),
    ("hill", [-23, -7.5], "spring_foot", "E", None),
    ("spring_foot", "W", "way_danger", "E", None),
    ("spring_foot", "S", "way_destruction_1", "W", None),
    ("way_destruction_1", "E", "way_destruction_2", "W", None),
]
# where a road sets the pilgrim down, when "a few steps inward" would put a wall or a table in the way
ARRIVE = {("wicket_gate", "slough"): [25.2, 3.3], ("dusty_cellar_1", "interpreter"): [-13, -2.4]}
STORY_BOUNDS = {"city": [-24, -14, 48, 28], "slough": [-26, -10, 52, 20], "interpreter": [-16, -8, 32, 18], "hill": [-28, -12, 56, 24]}

# The Interpreter's House is a town already standing: its services are added to the story map.
ATTACH_ENTS = {
    "interpreter": [
        {"id": "keeper", "kind": "npc", "name": "Keeper of the House", "at": [7.5, 5.5], "standee": "steward", "look": [0, 0, 0], "act": "Trade", "icon": "bag", "ui": "shop"},
        {"id": "rest", "kind": "spot", "name": "A Quiet Table", "at": [-8.5, 4.5], "act": "Rest", "icon": "sit", "ui": "rest_point", "prop": {"t": "kit", "name": "table"}},
        {"id": "board", "kind": "spot", "name": "Town Board", "at": [-12.5, 1.5], "act": "Read", "icon": "scroll", "ui": "board", "prop": {"t": "kit", "name": "signpost"}},
        {"id": "storage", "kind": "spot", "name": "Storage Chest", "at": [14, -5.5], "act": "Open", "icon": "bag", "ui": "storage", "prop": {"t": "kit", "name": "crate"}},
        {"id": "milestone", "kind": "milestone", "name": "Milestone", "at": [-10, 7], "act": "Travel", "icon": "warp", "ui": "milestone"},
        {"id": "lampkeeper", "kind": "npc", "name": "Keeper of the Lamp", "at": [4, 2.5], "look": [1, 4, 3], "act": "Talk", "icon": "talk", "dialog": "interpreter.folk0", "color": "#dfe9ff"},
        {"id": "sweeper", "kind": "npc", "name": "Sweeper of the Parlor", "at": [-3.5, 2.5], "look": [2, 1, 5], "act": "Talk", "icon": "talk", "dialog": "interpreter.folk1", "color": "#dfe9ff"},
    ],
}
ATTACH_TALK = {
    "interpreter.folk0": [{"who": "Keeper of the Lamp", "text": "He lit the candle before he showed you anything. Without light the pictures are only pictures. The unfolding of the word gives light.", "src": "[BSB: Psalm 119:130]"}],
    "interpreter.folk1": [{"who": "Sweeper of the Parlor", "text": "Dust is not laid by sweeping harder; that only raises it. Where the law made the trespass increase, grace increased all the more.", "src": BUNYAN + " · [BSB: Romans 5:20]"}],
}
MILESTONE_AT = {"interpreter": [-10, 7], "palace": [4, 8]}
# Palace Beautiful is hand-built and belongs to the later pass (regions 6 on). It keeps its hearth, steward and
# Muster board, and gains a Milestone and a storage chest now so that fast travel reaches it.
ATTACH_ENTS["palace"] = [
    {"id": "milestone", "kind": "milestone", "name": "Milestone", "at": [4, 8], "act": "Travel", "icon": "warp", "ui": "milestone"},
    {"id": "storage", "kind": "spot", "name": "Storage Chest", "at": [13, -1], "act": "Open", "icon": "bag", "ui": "storage", "prop": {"t": "kit", "name": "crate"}},
]
LATER = ["palace", "lions_path"]      # places whose full town or danger-zone dress waits for the later pass

# ------------------------------------------------------------------ builders
def ridge(look, z, bounds, seed):
    x0, x1 = bounds[0], bounds[0] + bounds[2]
    return {"t": "ridge", "from": [x0, z], "to": [x1, z], "h": 2.2, "seed": seed, "tint": RIDGE_TINT.get(look, "#6a7264"), "n": 12}

def decor_props(kinds, seed):
    out = []
    for qi, (q, a) in enumerate(QUAD.items()):
        for ki, k in enumerate(kinds):
            s = seed * 37 + qi * 7 + ki
            if k == "trees": out.append({"t": "trees", "area": a, "n": 4, "seed": s})
            elif k == "woods": out.append({"t": "trees", "area": a, "n": 7, "seed": s + 3})
            elif k == "bushes": out.append({"t": "bushes", "area": a, "n": 5, "seed": s})
            elif k == "rocks": out.append({"t": "rocks", "area": a, "n": 4, "seed": s})
            elif k == "reeds": out.append({"t": "reeds", "area": a, "n": 9, "seed": s})
            elif k == "dead_trees": out.append({"t": "dead_trees", "area": a, "n": 3, "seed": s})
            elif k == "blooms": out.append({"t": "blooms", "area": a, "n": 6, "seed": s, "color": ["#fff0a0", "#e0704a", "#9a7cc4", "#f4efe4"][qi]})
            elif k == "spires": out.append({"t": "spires", "area": a, "n": 2, "seed": s})
            elif k == "mushrooms": out.append({"t": "mushrooms", "area": a, "n": 3, "seed": s, "color": "#8fe0c0"})
            elif k == "crates": out.append({"t": "crates", "area": [a[0] + 2, a[1] + 2, a[2] - 4, 3], "n": 3, "seed": s})
            elif k == "fog": out.append({"t": "fog", "area": a, "n": 5, "tint": "#b8c8a8", "alpha": 0.13, "seed": s})
            elif k == "ponds" and qi in (1, 2):
                c = [a[0] + a[2] * 0.55, a[1] + a[3] * 0.5]
                out.append({"t": "water", "at": c, "size": [7, 4.5], "y": 0.04, "tint": "#5c6a4c"})
            elif k == "houses" and qi in (0, 1):
                for i in range(3):
                    out.append({"t": "house", "at": [a[0] + 3.5 + i * 7.5, a[1] + 0.6], "kind": "abc"[(i + qi) % 3]})
    return out

def base(m, shape, combat):
    sub = {"field": "Field · Recommended Level %d-%d", "floor": "Danger · Recommended Level %d-%d", "town": "Town · a safe place"}[m["shape"]]
    d = {"id": m["id"], "act": m["act"], "name": m["name"], "sub": sub % tuple(m["level"]) if "%d" in sub else sub,
         "layer": "House" if m["shape"] == "town" else "Wilds", "combat": combat, "start": inward(shape["sides"]["W"], shape["bounds"]), "bounds": shape["bounds"],
         "music": m["music"], "resumable": True, "look": dict(LOOKS[m["look"]]), "props": [], "ents": [], "objectives": [], "side": []}
    if m["burden"]:
        d["burden"] = True
    return d

def build_field(m, i):
    d = base(m, FIELD, True)
    b = FIELD["bounds"]
    d["enter_say"] = ["%s. The foes here suit Base Level %d to %d. Nothing here must be done: stay as long as you like." % (m["name"], m["level"][0], m["level"][1])]
    road = "dirt_dark" if m["look"] in ("city", "bog", "wood") else "dirt"
    d["props"] += [{"t": "path", "at": [0, 0], "size": [60, 3], "tile": road}, {"t": "path", "at": [0, 0], "size": [3, 30], "tile": road},
                   ridge(m["look"], b[1] - 0.6, b, 300 + i), ridge(m["look"], b[1] + b[3] + 0.6, b, 400 + i)]
    d["props"] += decor_props(m["decor"], i + 1)
    d["spawns"] = []
    for row in m["spawns"]:
        s = {"mob": row[0], "count": row[1], "lv": [row[2], row[3]], "aggro": row[4], "area": QUAD[row[5]] if isinstance(row[5], str) else row[5]}
        if len(row) > 6:
            s["greater"] = True
        d["spawns"].append(s)
    prop, title, at, text, src = m["landmark"]
    d["ents"].append({"id": "landmark", "kind": "spot", "name": title, "at": at, "act": "Read", "icon": "eye", "dialog": m["id"] + ".landmark", "prop": {"t": "kit", "name": prop}})
    pat, ptext, psrc = m["page"]
    d["ents"].append({"id": "page", "kind": "page", "name": "Something glints", "at": pat, "act": "Search", "icon": "eye"})
    d["side"].append({"id": "page", "type": "interact", "ent": "page", "dialog": m["id"] + ".page", "xp": [0, 0], "text": "The Dreamer's Page: %s" % m["name"], "page": True})
    sat, stitle, stext, coin = m["secret"]
    d["secrets"] = [{"id": "cache", "at": sat, "title": stitle, "text": stext, "reward": {"denarii": coin}}]
    talk = {m["id"] + ".landmark": [{"who": title, "text": text, "src": src}], m["id"] + ".page": [{"who": "The Dreamer", "text": ptext, "src": psrc}]}
    return d, talk

def build_floor(m, i):
    d = base(m, FLOOR, True)
    b = FLOOR["bounds"]
    d["cam_dist"] = 15
    d["enter_say"] = ["%s. A dangerous place: the foes here attack on sight and suit Base Level %d to %d." % (m["name"], m["level"][0], m["level"][1])]
    d["props"] += [{"t": "path", "at": [0, 0], "size": [48, 3], "tile": "dirt_dark"},
                   {"t": "wall", "from": [b[0], b[1]], "to": [b[0] + b[2], b[1]], "h": 3.6, "tint": "#8a8494"}, {"t": "wall", "from": [b[0], b[1] + b[3]], "to": [b[0] + b[2], b[1] + b[3]], "h": 1.2, "tint": "#8a8494"},
                   {"t": "stairs", "at": [-23.4, 0], "steps": 3, "w": 4}, {"t": "pillars", "points": [[-12, -7.4], [0, -7.4], [12, -7.4]], "ruined": True, "seed": 20 + i}]
    for x in (-18, -6, 6, 18):
        d["props"].append({"t": "torch", "at": [x, -7.6], "color": "#ffb050", "light": True})
    if m["boss"] is None:
        d["props"].append({"t": "stairs", "at": [21.6, 0], "steps": 3, "w": 4})
    d["zones"] = []
    for area, name, tile, effect in m["hazards"]:
        d["props"].append({"t": "path", "at": [area[0] + area[2] / 2, area[1] + area[3] / 2], "size": [area[2], area[3]], "tile": tile, "y": 0.02, "ragged": 0.2})
        d["zones"].append({"area": area, "name": name, **effect})
    d["spawns"] = [{"mob": r[0], "count": r[1], "lv": [r[2], r[3]], "aggro": r[4], "area": r[5]} for r in m["spawns"]]
    if m["boss"]:
        d["boss"] = m["boss"]
        d["props"].append({"t": "menhirs", "at": m["boss"]["at"], "r": 5.5, "n": 5})   # five stones leave the road in open
    return d, {}

def build_town(m, i):
    d = base(m, TOWN, False)
    d["start"] = inward(TOWN["sides"]["N"], TOWN["bounds"])
    d["enter_say"] = ["%s. No foe comes here. Trade, rest, read the board, and use the Milestone to return to any town you have reached." % m["name"]]
    d["props"] += [{"t": "path", "at": [0, 0], "size": [36, 3.4], "tile": "cobble_warm", "ragged": 0.25}, {"t": "path", "at": [0, 0], "size": [3.4, 24], "tile": "cobble_warm", "ragged": 0.25}]
    for x, k in ((-13, "a"), (-6.5, "b"), (6.5, "c"), (13, "a")):
        d["props"].append({"t": "house", "at": [x, -11], "kind": k, "flip": x > 0})
    for at in ([-3.5, -3.5], [3.5, -3.5], [-3.5, 3.5], [3.5, 3.5]):
        d["props"].append({"t": "lamp", "at": at, "color": "#ffd080"})
    d["props"] += [{"t": "trees", "area": [-17, 8, 6, 3], "n": 2, "seed": 50 + i}, {"t": "trees", "area": [11, 8, 6, 3], "n": 2, "seed": 60 + i},
                   {"t": "bushes", "area": [-17, -7, 4, 4], "n": 3, "seed": 70 + i}, {"t": "banner", "at": [-2.4, -8.2], "color": "#2f4f8f"}, {"t": "banner", "at": [2.4, -8.2], "color": "#2f4f8f"}]
    keeper, standee = m["keeper"]
    rest_prop, rest_name = m["rest"]
    rest_p = {"t": "arbour"} if rest_prop == "arbour" else {"t": "kit", "name": rest_prop}
    d["ents"] += [
        {"id": "keeper", "kind": "npc", "name": keeper, "at": [-8, -5], "standee": standee, "look": [0, 0, 0], "act": "Trade", "icon": "bag", "ui": "shop"},
        {"id": "storage", "kind": "spot", "name": "Storage Chest", "at": [-12, -5.5], "act": "Open", "icon": "bag", "ui": "storage", "prop": {"t": "kit", "name": "crate"}},
        {"id": "rest", "kind": "spot", "name": rest_name, "at": [9, -5.5], "act": "Rest", "icon": "sit", "ui": "rest_point", "prop": rest_p},
        {"id": "board", "kind": "spot", "name": "Town Board", "at": [6, 6.5], "act": "Read", "icon": "scroll", "ui": "board", "prop": {"t": "kit", "name": "signpost"}},
        {"id": "milestone", "kind": "milestone", "name": "Milestone", "at": [-6, -1.8], "act": "Travel", "icon": "warp", "ui": "milestone"},
    ]
    talk = {}
    for k, (who, look, at, text, src) in enumerate(m["folk"]):
        d["ents"].append({"id": "folk%d" % k, "kind": "npc", "name": who, "at": at, "look": look, "act": "Talk", "icon": "talk", "dialog": "%s.folk%d" % (m["id"], k), "color": "#dfe9ff"})
        talk["%s.folk%d" % (m["id"], k)] = [{"who": who, "text": text, "src": src}]
    return d, talk

def main():
    mobs, dialogue, world = load("mobs"), load("dialogue"), load("world")
    for mid, (name, lv, sprite, fam, size, tint, kind) in MOBS.items():
        mobs[mid] = {"name": name, "level": lv, "tint": tint, "sprite": sprite, "family": fam, "size": size, "review": True}
        if kind:
            mobs[mid]["kind"] = kind
    for mid, (name, lv, sprite, fam, hp, atk, slam, bonus, size) in BOSSES.items():
        mobs[mid] = {"name": name, "level": lv, "tint": "#ffffff", "sprite": sprite, "family": fam, "boss": True, "hp": hp, "atk": atk, "slam": slam, "xp_bonus": bonus, "size": size, "review": True}
    # every foe has a home: the first map whose tables or story list it
    homes = {}
    for m in MAPS:
        for row in m.get("spawns", []):
            homes.setdefault(row[0], m["id"])
        if m.get("boss"):
            homes.setdefault(m["boss"]["mob"], m["id"])
    story_homes = {}
    for p in sorted((DATA / "maps").glob("*.json")):
        sd = json.loads(p.read_text(encoding="utf-8"))
        if p.stem in SPEC:
            continue
        for s in sd.get("spawns", []):
            story_homes.setdefault(s["mob"], p.stem)
        for o in sd.get("objectives", []):
            if "mob" in o:
                story_homes.setdefault(o["mob"], p.stem)
    story_homes.setdefault("grim", "lions")
    for mid, md in mobs.items():
        md["home"] = story_homes.get(mid, homes.get(mid, md.get("home", "")))
        md.setdefault("aggro", "aggressive")

    builders = {"field": build_field, "floor": build_floor, "town": build_town}
    kinds = {"field": "field", "floor": "danger", "town": "town"}
    shapes = {"field": FIELD, "floor": FLOOR, "town": TOWN}
    for i, m in enumerate(MAPS):
        d, talk = builders[m["shape"]](m, i)
        save("maps/" + m["id"], d)
        dialogue.update(talk)
        node = {"kind": kinds[m["shape"]], "region": m["region"], "level": m["level"]}
        if m["shape"] == "town":
            node["milestone"] = [-6, -1.8]
        if m["review"]:
            node["review"] = True
        world["nodes"][m["id"]] = node
    dialogue.update(ATTACH_TALK)
    for mid, ents in ATTACH_ENTS.items():
        sd = load("maps/" + mid)
        have = {e["id"] for e in sd["ents"]}
        sd["ents"] += [e for e in ents if e["id"] not in have]
        save("maps/" + mid, sd)
    for nid, n in world["nodes"].items():   # the fast-travel point is a Milestone ("Waymark" is the pilgrims' messages)
        if "waymark" in n:
            n["milestone"] = n.pop("waymark")
        if nid in MILESTONE_AT:
            n["milestone"] = MILESTONE_AT[nid]
        if nid in LATER:
            n["later"] = True

    def spot(map_id, side):
        if isinstance(side, list):
            return side, STORY_BOUNDS[map_id]
        sh = shapes[SPEC[map_id]["shape"]]
        return sh["sides"][side], sh["bounds"]
    mine = set(SPEC)
    world["edges"] = [e for e in world["edges"] if e["from"] not in mine and e["to"] not in mine]
    for a, sa, b, sb, needs in ROADS:
        pa, ba = spot(a, sa); pb, bb = spot(b, sb)
        for frm, to, at, arrive in ((a, b, pa, inward(pb, bb)), (b, a, pb, inward(pa, ba))):
            e = {"from": frm, "to": to, "kind": "portal", "at": at, "arrive": ARRIVE.get((frm, to), arrive)}
            if needs and frm == a:
                e["needs"] = needs
            world["edges"].append(e)
    save("mobs", mobs); save("dialogue", dialogue); save("world", world)
    print("gen_fields: %d maps, %d foes, %d roads" % (len(MAPS), len(MOBS) + len(BOSSES), len(ROADS)))

if __name__ == "__main__":
    main()
