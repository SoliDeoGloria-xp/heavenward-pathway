# Asset re-request (Grok P1 pack and what the game still needs)

The game always runs on the placeholders made by `tools/gen_assets.py`. Verified art replaces a
placeholder through `data/asset_overrides.json`, written by `tools/check_assets.py`. Nothing is
stretched to fit; a file that misses the contract is listed here instead.

**Status (2026-11-10).** Four zips received and processed: `HPO_Boss_Sheets`, `HPO_Monster_Sheets_Part1`, `HPO_Monster_Sheets_Part2`, `HPO_P1_RO_Assets`. Every file arrived as 1168×784 RGB with a painted checkerboard; the import tools cut them out, slice and normalise them. Raw files are not kept in the repository.

| Batch | Result |
|---|---|
| Monster + boss sheets (175 files, 46 creatures) | All imported to `assets/sprites/mobs/` + `data/sprites.json`. 17 are in use in Acts I–II; the rest wait for later acts |
| P1 icons (42) | All cleaned to 64×64 in `assets/icons/`; 20 used as skill icons |
| P1 NPC standees (11) | Cleaned to 96×96 in `assets/sprites/npc/`; Interpreter, Steward (Goodwill), Shepherd (Help), Valiant (Watchful) in use |
| P1 props (15) | Cleaned to `assets/props/`, not yet placed in maps (mixed perspectives) |
| P1 tiles (10), UI frames (11) | Not usable: see rows 2, 3, 9 below |

To process a new chunk: `python3 tools/import_sheets.py <folder>` for animation sheets, `cd tools && python3 import_art.py <folder>` for single pictures.

### Problems found in the sheets (please re-request)

| # | Sheet | Problem | Ask for |
|---|---|---|---|
| S1 | `envy_common`, `gluttony_common`, `wrath_common` | Only the idle sheet was delivered | `_move`, `_attack`, `_hit_death` |
| S2 | `simple_sloth_presumption` (move, attack), `sloth_greater` (attack), `great_red_dragon` (move, attack) | Poses and effects overlap, so frames cannot be cut apart. The game plays another row instead | Same rows with a clear empty gap between poses |
| S3 | `envy_elite`, `diabolus_mansoul`, `prince_air`, `gluttony_greater` | Some poses touch (wide cells); usable but may show a neighbour's edge | Clear gaps between poses |
| S4 | Many creatures | The creature looks different from one sheet to the next (for example Giant Grim idle vs attack, Sloth Greater idle vs move) | Give the generator the idle sheet as the reference for the other three |
| S5 | All sheets | One facing only (side or front). The game mirrors it left/right | Acceptable for monsters; say so if you want back views |
| S6 | All sheets | Each file drawn at a different size and pixel scale; normalised by downscaling, so pixels are not crisp 1× | Fixed canvas per frame (for example 6 frames of 128×128 on a 768×128 canvas), native pixels, real alpha |
| S7 | No sheets exist for a **Doubt** family | Doubt uses `envy_greater`; the Shades of Mistrust and Timorousness use `lust_rare` | A Doubt family (common, rare, elite, greater), or tell me which family to use |
| S8 | `formalist_hypocrisy` | Drawn as one robed cleric with a mitre | Confirm this is the look you want for Formalist and Hypocrisy (two travellers in Bunyan) |

## The contract

| Kind | Exact canvas | Rules |
|---|---|---|
| Character sheet | **320×240** (10 columns × 5 rows of **32×48** frames) | Rows S, SW, W, NW, N. Columns idle, walk 1–4, attack 1–2, sit, rest/KO, cast. Layers as separate files: `body`, `robe` (greyscale, tinted in game), `hair_0..2` (greyscale, tinted), `staff`. Native 1× pixels, PNG-32 with real alpha |
| Monster sheet | **7 frames in one row**, frame 32×32 (224×32) | idle 1–2, walk 1–2, hurt, die 1–2. PNG-32, real alpha |
| Icon | **64×64** | PNG-32, real alpha, no text |
| Ground tile | **64×64** | Seamless on all four edges, opaque |
| Portrait | **256×320** | PNG-32, real alpha, bust, facing right |
| Prop billboard | longest side ≤ 384, never above 2048 | 3/4 view to match the camera, PNG-32, real alpha, no text |

Add to every Grok prompt: *"Output at native pixel size (1 art pixel = 1 image pixel), exact canvas
W×H, real alpha transparency. Do NOT draw a checkerboard. No text."*

## Fails the contract: re-request

| # | Asset | What was delivered | Ask for |
|---|---|---|---|
| 1 | All 11 character standees (Pilgrim, Evangelist, Interpreter, Faithful, Hopeful, Shepherd ×2, Steward, Valiant, Watcher, Wayfarer) | One front-facing pose each, no layers, all sharing one young face | Full sheets on the character contract above. Evangelist and Interpreter as **elderly** men; each named character with a distinct face |
| 2 | All 10 "tiles" | Isometric islands with cut-off edges, not repeatable | Seamless 64×64: `grass`, `dirt`, `cobble`, `water`, `roof`, `wall`, `leaves`, `bark` (same file names as the placeholders) |
| 3 | `inventory_frame` | Baked text "INVENTORY" | Same frame with no text |
| 4 | `vanity_fair_stall`, `vanity_fair_square` | Baked signs (VANITY FAIR, FABRICS, PRODUCE, GOODS & SUNDRIES) | Text-free versions |
| 5 | `interpreter_scroll` | A red letter seal | Plain seal, no letter |
| 6 | `celestial_gate` | Close-up walk-in portal | A far-off view only (the Gate is seen from afar, never entered) |
| 7 | Stat icons | Fortitude, Diligence, Wisdom, Hope only | Add **Steadfastness** and **Sobriety**, 64×64 |
| 8 | Fruit stones | One generic purple gem | **9 distinct** fruit-shaped crystals, 64×64 |
| 9 | Dialogue frame, Zeal bar | Solid orange fill; gold bar | Parchment fill; **blue** Zeal bar (matches the HUD) |
| 10 | Every file as first delivered | 1168×784 canvas, RGB with a painted checkerboard, fake pixels 9–15 px wide | Fixed in the clean pack by cropping and downscaling; a true 1× set needs native-size output |

## New art this build needs (currently placeholders)

| Need | Placeholder in use | Spec |
|---|---|---|
| Monsters with their own look: several game monsters share one sheet (Slothling and Idle Whelp; Mire Sloth and Stumbler; Despondling and Loiterer; both Shades) | Shared sheet, lightly tinted | Monster sheet contract, one file per monster named as its id in `data/mobs.json` (for example `mob_mire_sloth.png`) |
| NPCs: Obstinate, Pliable, Help, Mr. Worldly Wiseman, Goodwill, Interpreter, three Shining Ones, Formalist, Hypocrisy, Watchful, Discretion, Prudence, Piety, Charity | Pilgrim paper-doll with different hair and robe colours | Character sheet contract (idle row is enough for standing NPCs: 320×240 with at least the idle column filled) |
| Props: Wicket Gate, the Cross, the sepulchre, the Arbour, chained lions, tableau pedestals, stepping stones | Boxes and spheres built in code (`scripts/maps/data_map.gd`) | Prop billboard contract. The Cross scene shows only the cross, the tomb and light |
| Job looks (Valiant, Watcher, Expositor, Shepherd, Steward, Wayfarer) | Robe tint per job | One `robe_<job>.png` layer per job on the character contract |
| Portraits: every named NPC above | Dreamer and Evangelist only | Portrait contract |
| Audio | Silent | `assets/audio/music/<id>.ogg` for `eden, city, slough, interpreter, cross, hill, palace, boss`; `assets/audio/sfx/<id>.ogg` for `quest, skill, bell` |

<!-- scan results below are written by tools/check_assets.py -->

## Last scan: `assets/p1`

No art pack found at that path. Unzip the cleaned pack there and run `python3 tools/check_assets.py` again.
