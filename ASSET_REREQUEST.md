# Asset re-request (Grok P1 pack and what the game still needs)

The game always runs on the placeholders made by `tools/gen_assets.py`. Verified art replaces a
placeholder through `data/asset_overrides.json`, written by `tools/check_assets.py`. Nothing is
stretched to fit; a file that misses the contract is listed here instead.

**Status (0.5.0).** Every delivered picture is now imported through the art bible (DECISIONS.md): 32 colours, ink outline, 48 pixels per world unit. Ask the generator for art in these terms and it will drop in without a visible seam.

### Style line to put at the front of every art prompt

> 16-bit JRPG pixel art in the manner of Ragnarok Online. Crisp pixels, no anti-aliasing, no soft gradients, no glow. One-pixel dark outline (#1a1622). Light from the upper left. Limited palette of earthy browns, parchment, muted greens, slate greys, deep purples, with gold and crimson accents. Front three-quarter view. Plain flat magenta (#ff00ff) background, nothing else in the frame. Feet on the bottom edge.

### What still needs new source art (the tools cannot invent it)

| # | What | Why it matters | Ask for |
|---|---|---|---|
| A1 | **Pilgrim and Calling sheets with real directions and walk frames** | Only one front pose exists per character. Every direction shows the front; walking, striking, sitting and casting are that one picture leaned and squashed. This is the largest remaining tell | Per character: 5 rows (front, front-side, side, back-side, back) × 10 columns (idle, walk 1–4, attack 1–2, sit, fallen, cast), each frame 64×96, body 84 px tall |
| A2 | **Drawn walk, attack and death rows** for the 24 creatures marked `generated` in `data/sprites.json` | Their motion is a lean and a squash of the idle picture | Give the generator the idle sheet as reference; 6 frames per row |
| A3 | **Elderly Evangelist, Interpreter and the Dreamer; distinct named NPCs** (Pliable, Obstinate, Worldly Wiseman, Goodwill, Help, Watchful, the damsels of the House, Faithful) | The elders are a young face with greyed hair; road folk are the pilgrim in re-dyed robes | One standing figure each, 64×96 |
| A4 | **Painted trees, rocks, houses, cliffs and ground tiles** | The world kit is drawn by code (`tools/gen_world.py`): clean and consistent, but plainer than the delivered grove and palace beside it | Single props on magenta; ground as true seamless 64×64 tiles |
| A5 | **Skill and item icons for the 30 that still use drawn-by-code icons** | They were held to the palette and outline but are simple shapes | 64×64 each |
| A6 | **A Doubt family** and a second traveller for Formalist and Hypocrisy | Doubt borrows envy and lust sheets; Bunyan has two men, the sheet shows one | As A2 |
| A7 | **Story plates** for the dream, the Fall, the Cross and the ending | These are code-drawn scenes mapped onto the palette | 320×180 each |

**Batches received (2026-11-10):** `HPO_Boss_Sheets`, `HPO_Monster_Sheets_Part1`, `HPO_Monster_Sheets_Part2`, `HPO_P1_RO_Assets` (the second copy sent was identical). 46 creature sheets, 42 icons, 11 standing figures, 25 scenes (the pack's ten "tiles" are scenes and are used as props). The 11 interface frames are not used: their edge ornaments do not stretch.

To process a new chunk: `python3 tools/import_sheets.py <folder>` for animation sheets, `cd tools && python3 import_art.py <folder>` for single pictures.

### How the sheets were completed

Every creature now has all five actions (idle, walk, attack, hurt, death). Where a delivered row was missing, could not be cut into clean poses, or showed a different-looking creature than its idle row, `tools/import_sheets.py` **generated that action from the idle poses** (lean and bob for walking, a lunge with a strike arc, a white flash for hurt, a collapse into motes for death). `data/sprites.json` lists the generated rows per creature under `generated`. 22 of the 46 creatures have at least one generated row; Giant Grim, Presumption and the greater Sloth are fully generated from their idle look.

Evangelist and the Interpreter were drawn young; their hair is turned silver by `tools/import_art.py` so they read as old men.

### Still worth re-requesting (the game no longer waits on these)

| # | What | Why |
|---|---|---|
| S1 | Hand-drawn walk, attack and death rows for the creatures listed as `generated` | Generated motion is simple; drawn frames will look better. Give the generator the idle sheet as the reference so the creature stays the same, and ask for a clear empty gap between poses |
| S2 | A fixed canvas per frame (for example 6 frames of 128×128 on 768×128), native pixels, real alpha | Each file was drawn at its own size, so everything is normalised by downscaling and is not pixel-crisp |
| S3 | A **Doubt** family (common, rare, elite, greater) | Doubt uses `envy_greater`; the Shades of Mistrust and Timorousness use `lust_rare` |
| S4 | Confirm `formalist_hypocrisy` | Drawn as one robed cleric with a mitre; Bunyan has two travellers |
| S5 | Truly elderly Evangelist and Interpreter, and distinct faces for named NPCs | Silver hair on a young face is a stopgap |

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
| Audio | Synthesized hymn-tune loops and effects | Recorded music for `eden, city, slough, interpreter, cross, hill, palace, boss, valley, shadow` and recorded effects, same file names |
| Player and Calling sheets | One front pose each, actions generated | Full sheets on the character contract: 5 facings × idle, walk 1–4, attack 1–2, sit, rest, cast, for the pilgrim (two looks) and the six Callings |

<!-- scan results below are written by tools/check_assets.py -->

## Last scan: `assets/p1`

No art pack found at that path. Unzip the cleaned pack there and run `python3 tools/check_assets.py` again.
