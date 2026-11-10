# Asset re-request (Grok P1 pack and what the game still needs)

The game always runs on the placeholders made by `tools/gen_assets.py`. Verified art replaces a
placeholder through `data/asset_overrides.json`, written by `tools/check_assets.py`. Nothing is
stretched to fit; a file that misses the contract is listed here instead.

**Status of the P1 pack:** `HPO_P1_clean.zip` was not in the repository or in the build session, so
no P1 file is wired in yet. To integrate it: unzip it to `assets/p1/` (keep its `game/icon`,
`game/npc`, `game/prop`, `game/tile_like`, `game/ui` folders), run `python3 tools/check_assets.py`,
and commit the result. The findings below come from the earlier verification of the delivered pack.

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
| Monsters: Slothling, Idle Whelp, Scoffling, Mire Sloth, Glutton Grub, Despondling, Stumbler, Loiterer, Pretender, Simple, Sloth, Doubt, Shade of Mistrust, Shade of Timorousness | One Slothling sheet, tinted per monster | Monster sheet contract, one file per monster named as its id in `data/mobs.json` (for example `mob_mire_sloth.png`) |
| Bosses: Formalist and Hypocrisy, Presumption, Giant Grim | Scaled, tinted Slothling | Monster sheet at 64×64 frames (448×64) |
| NPCs: Obstinate, Pliable, Help, Mr. Worldly Wiseman, Goodwill, Interpreter, three Shining Ones, Formalist, Hypocrisy, Watchful, Discretion, Prudence, Piety, Charity | Pilgrim paper-doll with different hair and robe colours | Character sheet contract (idle row is enough for standing NPCs: 320×240 with at least the idle column filled) |
| Props: Wicket Gate, the Cross, the sepulchre, the Arbour, chained lions, tableau pedestals, stepping stones | Boxes and spheres built in code (`scripts/maps/data_map.gd`) | Prop billboard contract. The Cross scene shows only the cross, the tomb and light |
| Job looks (Valiant, Watcher, Expositor, Shepherd, Steward, Wayfarer) | Robe tint per job | One `robe_<job>.png` layer per job on the character contract |
| Portraits: every named NPC above | Dreamer and Evangelist only | Portrait contract |
| Audio | Silent | `assets/audio/music/<id>.ogg` for `eden, city, slough, interpreter, cross, hill, palace, boss`; `assets/audio/sfx/<id>.ogg` for `quest, skill, bell` |

<!-- scan results below are written by tools/check_assets.py -->

## Last scan: `assets/p1`

No art pack found at that path. Unzip the cleaned pack there and run `python3 tools/check_assets.py` again.
