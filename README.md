# Heavenward Pathway Online

*Heavenward Pathway Online* (HPO) is a Reformed, allegorical, Ragnarok-style mobile RPG after John Bunyan's *The Pilgrim's Progress*. This build is **single-player and offline**: it plays from the title screen through the first Calling (job change) and on into Act III, where Faithful joins.

- **Look:** classic Ragnarok Online, with 2D pixel sprites on a lit 3D map and a fixed three-quarter camera.
- **Controls:** Ragnarok M / Origin style for phones (landscape): floating joystick, Attack with a skill arc, Auto.
- **Engine:** Godot 4.3, Compatibility renderer (Android and mobile browsers).
- **Status:** the whole road is playable with delivered character and monster art, built scenery, hymn-tune music and sound effects. Tiles, props and portraits are still generated or built in code (see `ASSET_REREQUEST.md`).

## Play it

| Where | How |
| --- | --- |
| Phone browser | Open the GitHub Pages link (Settings → Pages) in landscape. Every push to `main` rebuilds it. |
| Android phone | Releases → the **debug-latest** draft → download `hpo-debug.apk` and install it. |
| Play Console (internal testing) | Follow `PLAY_CONSOLE.md`. |
| Desktop | Open the folder in Godot 4.3 and press Play. A mouse works as touch. |

## The road (about 2 h 20 min to the first Calling)

| Act | Map(s) | Set piece | Coach teaches | Quest XP (Base/Job) |
| --- | --- | --- | --- | --- |
| Prologue | Eden Isle | The Fall, played in the garden | The whole HUD, attributes, first skill, Manna | 330 / 35 |
| 1 | City of Destruction | First fight; Evangelist's roll | Fighting, First Steps, Auto, rest and Weariness | 240 / 70 |
| 2 | Slough of Despond, Wicket Gate | Worldly Wiseman's detour (a real choice) | Bad ground and stepping stones, Take Refuge | 200 / 60 |
| 3 | Interpreter's House | Five tableaux | Word Study, Prayer of Rest | 200 / 40 |
| 4 | The Cross | The burden falls | Status changes, Steady Footing | 150 / 30 |
| 5 | Hill Difficulty | Two field bosses; the Arbour and the lost roll | Buffs (Watchful Eye), boss telegraphs | 470 / 230 |
| 6 | Palace Beautiful, the Yard, Lions' Path, Lions' Gate | Calling trial; Muster against Giant Grim with AI companions | Armor of God, companions, the Calling | 620 / 390 |
| | | | **Total to the Calling** | **2,210 / 855 = Base 10 / Job 10** |
| 7 | Valley of Humiliation | Apollyon | Weaknesses, the Codex, ranged foes | 700 / 300 |
| 8 | Valley of the Shadow of Death | The fiends; Faithful joins at daybreak | All-Prayer | 700 / 300 |

Quest XP alone reaches Base 10 and Job 10. Monster XP (3 + level; Greater ×4) is extra, about 20% on top, so a player who skips optional objectives (Obstinate, the six Dreamer's Pages) can make it up by fighting. At the end you choose one of six Callings (Valiant, Watcher, Expositor, Shepherd, Steward, Wayfarer), each with three skills and its own robe colour.

The game saves by itself to one slot on the device (at every map and objective); the title screen offers **Continue**. On the Lord's Day (device time) the game offers only quiet reading.

## Gear, coin and the bench

Foes drop Denarii and road gear (four slots, Clay to Radiant). Vendors buy, sell and store. At the Palace armory, worn gear is refined to +5 and Fruit stones are cut from Manna. All of it is in `data/items.json`; the rules are in `scripts/systems/gear.gd`. The Armor of God is never gear.

## Adding a chapter (data, not code)

1. Copy a file in `data/maps/` and edit it: `look` (palette), `props` (geometry from the kit in `scripts/maps/data_map.gd`), `ents` (characters, spots, pages), `spawns`, `zones` (bad ground), `objectives` and `side` (optional objectives). Each objective has a `type` (`zone`, `path`, `talk`, `interact`, `choice`, `kill`, `boss`, `check`, `travel`, `exit`), its `xp` as `[base, job]`, and optional `on_start` / `on_done` effects (`show`, `hide`, `give`, `flag`, `say`, `burden`, `weary`, `heal`, `dialog`, `branch`).
2. Write its scenes in `data/dialogue.json`. A line may carry `fx` or `cam` for staging (`scripts/systems/cutscene.gd`), `choices`, and `if` / `unless` flags.
3. Add coach tips in `data/lessons.json`, monsters in `data/mobs.json`, and the act's budget in `data/acts.json`.
4. Point the previous map's `exit` objective at the new map, and add the map to `data/world.json`: a node (`kind`, `region`, `level`) and two edges, one each way, with the portal's position (`at`) and where it sets the pilgrim down (`arrive`). `scripts/systems/portals.gd` builds the portals from that file.
5. Run `python3 tools/validate_data.py`, then the autotest. The bot plays any data map without new test code.

**Towns, fields and danger zones** have no story objectives. `tools/gen_fields.py` holds a short spec for each (name, level range, look, spawn rows, landmark, cache, page, townsfolk) and the roads between them, and writes the maps, the world-graph nodes and edges, the new foes and the dialogue. Edit the spec and run it again; it overwrites only the maps it lists. A spawn row is `(foe, count, lowest level, highest level, notice, where)` with notice one of `aggressive`, `passive`, `alert`.

Only a place that needs hand-built geometry gets a script in `scripts/maps/<id>.gd` (Eden, the City, the Palace and the Lions' Gate have one).

## Testing

```
python3 tools/validate_data.py                     # XP budgets, exits, BSB cites, reserved names, references, the world graph
godot --headless --path . --import                  # once
HPO_SHOTS=/tmp/shots xvfb-run -a godot --path . --rendering-driver opengl3 -- --autotest
HPO_FROM=hill HPO_SHOTS=/tmp/shots xvfb-run -a godot --path . --rendering-driver opengl3 -- --autotest   # start the bot at one map
HPO_WALK=1 HPO_SHOTS=/tmp/shots xvfb-run -a godot --path . --rendering-driver opengl3 -- --autotest     # skip the story: walk every road, then towns, fields and a danger zone
HPO_WALK=wilds ...                                                                                     # only the towns, fields and danger zone
```

The autotest plays from the title to the Calling, saves screenshots, prints one `[pacing]` line per act, checks Save/Continue mid-map, leaves a chapter half told and returns, walks every road of the world graph on foot, and fails unless quest XP is exactly 2,210 / 855.

## Feel and effects (polish pass 1)

Built from the code-side items in the 100-improvement review.

- **Hit feel:** hit-stop (50 ms normal, 100 ms crit or kill), hit flash and squash and stretch on attacker and target, trauma camera shake (crits, kills and damage taken only), directional hit sparks, weight knockback, damage numbers sized by damage and staggered, crit star burst, "overcome" dissolve into light motes, input buffering, haptics.
- **Readability:**
  - Monsters pop a "!" when they notice you and a "?" when they lose you.
  - Strong attacks show a red telegraph circle; step out of it to make them miss.
  - The current target gets a gold outline and a ground ring.
  - Enemy and player health bars have a white damage trail.
  - A red edge pulse warns at low health.
- **Skills:** First Steps lunges with afterimages, dust and an impact burst; Take Refuge raises a dome of warm light with rising motes.
- **Progression:** staged Base and Job level-up (light column, spiral motes, ring, banner, EXP bar flash, badge on More), quest-step wax stamp, Manna motes flying to the portrait after Word Study.
- **Look:**
  - Lit-sprite shader (map key-light tint and top-to-bottom shading).
  - Per-map colour grading and vignette, plus a subtle tilt-shift blur at the top and bottom edges.
  - Fake bloom halos on lamps, the Tree of Life and the warp. Engine glow is unreliable on the Compatibility renderer, so halo cards stand in for it.
  - Light shafts and drifting petals in Eden; drizzle and flickering lamps in the City.
  - Swaying trees, water glints and soft edge fog at map borders.
  - Eden's light warms and dims as the two trees appear.
- **Status visuals:** a dark burden haze in the City and sweat drops while weary.
- **UI motion:** windows pop in, side sheets slide, and buttons dip on press. Skills grey out when Zeal is short. The HUD respects safe areas.
- **Settings:** Reduce motion, Reduce flashing, High-quality effects (blur and rain) and Vibration.

## Onboarding, stats and skills (onboarding pass)

- **The Dreamer** is the single guide voice (as Gielinor's guide in OSRS or Paimon in Genshin). His coach bubble rings the exact button to press, dims the rest of the screen for short explanations, and never blocks you when you need to act. Tips come in three levels, chosen in the first conversation and changeable in More → Guide: Full (new to MMOs), Light (played MMOs) and Off.
- **Pilgrim's Guide** (More → Guide): twelve short answers (moving, the screen, quests, levels, attributes, skills and Zeal, items, fighting, falling and rest, Manna, secrets and Waymarks, other pilgrims).
- **Attributes** start at 3 each; each Base Level gives 2 points. What each one does:

  | Attribute | Effect |
  | --- | --- |
  | Fortitude | basic attack and First Steps damage |
  | Diligence | attack speed |
  | Steadfastness | max Health, damage blocked |
  | Wisdom | max Zeal, skill power |
  | Sobriety | fewer misses |
  | Hope | critical chance, Zeal regeneration |

  Resetting is free in the demo. The numbers are demo tuning, not final balance.
- **Skills**: each Job Level gives 2 skill points. Pilgrim skills are Tend and Keep (Eden only, Lv 1), First Steps (Lv 5) and Take Refuge (Lv 5). Learned skills fill the skill bar by themselves; an empty dashed slot opens the Skills window.
- **Phone buttons** are told apart by shape and colour: gold discs are main actions (Attack, Act), blue discs are skills (with a name label and a Zeal-cost badge), slate squares are utilities (Auto with ON/OFF, Sit, item, page, More), and dashed rings are empty slots. Off the battlefield, Attack and empty slots are hidden.
- **Haptics**: every button gives a light tap; hits, level-ups and KO have their own patterns. The Android build now requests the VIBRATE permission (it was missing, so vibration never worked on Android). Mobile browsers use `navigator.vibrate` where supported. Turn it off in Settings → Vibration.
- New placeholder art: `tools/gen_onboarding_assets.py` (Dreamer portrait, lilies, serpent, cherubim, flaming sword, Tend and Guide icons).

## Controls (phone)

- **Left thumb:** drag anywhere in the lower-left to walk. Tap the ground to walk there.
- **Right thumb:**
  - **Attack** targets the nearest Slothling.
  - **First Steps** and **Take Refuge** are skills. The page button switches pages (2 pages of 4).
  - **Auto** toggles auto battle (auto-attack plus the auto-skill slots).
  - The **quick item** uses one item; long-press it to swap items.
  - **Sit** rests for faster recovery.
- **Act** (Talk, Tend, Gather, Name, Read, Behold, Enter) appears when you are near something. Tapping the thing itself also works.
- **Top right:** the minimap (tap it for The Way), **More** (Satchel, Equipment, Skills, Status, The Way, Settings, Chat log) and **Snap**.
- **Camera:** pinch to zoom; two-finger swipe to rotate in 45° steps. On desktop, use the mouse wheel to zoom and right-click to rotate.
- **Settings:** auto-loot, damage numbers, reduce motion, left-handed (mirrored) HUD, HUD opacity.

## Art and audio

**Every picture follows the art bible** (DECISIONS.md, "Art bible"; the rules are code in `tools/artkit.py`): 32 colours, an ink outline, light from the upper left, 48 sprite pixels per world unit. `tools/gen_world.py` draws the ground tiles, scenery props and skylines (`assets/tiles`, `assets/props/k_*.png`, `data/props.json`); `tools/gen_ui.py` draws the interface frames; `tools/conform.py` holds any other picture to the rules (`--check` in CI). To add art: drop the raw pack in a folder and run the import tool below; it comes out at the right size, palette and outline. To add a prop to a map, name it in the map's JSON (`{"t": "kit", "name": "well", "at": [x, z]}` for a drawn prop, `{"t": "art", "art": "forest_edge", ...}` for a delivered scene). Screens are checked by `HPO_GALLERY=1 ... --autotest` and `tools/shot_diff.py` (see its header; `--update` accepts a new look). Delivered art is cleaned by `tools/import_sheets.py` (monster and boss animation sheets → `assets/sprites/mobs/` and `data/sprites.json`) and `tools/import_art.py` (icons, standing NPCs, props); a monster uses a sheet by naming it in `data/mobs.json` (`sprite`, and `size` in world units). Verified art replaces them through `data/asset_overrides.json`: unzip a pack to `assets/p1/` and run `python3 tools/check_assets.py`. The contract and everything still to be drawn are in `ASSET_REREQUEST.md`. Music is arranged from public-domain hymn tunes by `tools/gen_music.py` and effects by `tools/gen_sfx.py`; a recording dropped into `assets/audio/music/` or `assets/audio/sfx/` under the same name replaces the synthesized one. Each skill's look is its `vfx` entry in `data/skills.json`. Scenery props are listed in `scripts/maps/data_map.gd`.

Scripture is cited as `[BSB: Book ch:v]`. `python3 tools/pull_bsb.py` fills `data/scripture.json` with the public-domain BSB text of the cited passages so Word Study can show them.

## Android signing for the Play Store

1. Create an upload keystore once and keep it safe:
   `keytool -genkeypair -v -keystore upload.keystore -alias hpo -keyalg RSA -keysize 2048 -validity 10000`
2. Add these repository secrets: `RELEASE_KEYSTORE_BASE64` (`base64 -w0 upload.keystore`), `RELEASE_KEYSTORE_PASSWORD` and `RELEASE_KEY_ALIAS`.
3. Run **Android release (Play Console AAB)** with a new `version_code`, then upload the AAB to an internal testing track.
4. **Before the first upload, confirm the package name** in `export_presets.cfg` (`package/unique_name`, currently `com.solideogloria.hpo`). Google Play never lets you change it later.

## Theology and content rules kept in code

- Scripture appears only as `[BSB: reference]` placeholders, with the text pulled by reference at build time and never hand-typed.
- No depiction or voice of the triune God. Shaddai and Emmanuel are never shown.
- Bunyan quotations are marked as public domain (1678).
- Lord's Day Mode, no prayer emote, no sacrament simulation, and a cosmetic-only shop follow the Master GDD (not part of this demo).

## Project layout

```
data/                 progression, acts, maps/*.json, dialogue, lessons, mobs, skills, jobs, word studies, scripture, asset overrides
scripts/g.gd          the one autoload: state, data access, XP, save/continue, settings, Lord's Day
scripts/audio.gd      music and sound hooks (silent when files are missing)
scripts/screens/      title, create, story (dream), world (loop, input, camera), end
scripts/systems/      combat, quests (objective runner), gear (items, coin, bench), lessons (coach), cutscene, folk
scripts/world/        map_kit (geometry primitives and feedback)
scripts/maps/         data_map (builds a map from JSON) and the four hand-built maps
scripts/ui/           hud, coach, joystick, touch buttons, UIKit
tools/                artkit.py (the art bible), gen_world.py, gen_ui.py, conform.py, shot_diff.py, validate_data.py, import_sheets.py, import_art.py, gen_music.py, gen_sfx.py, gen_backdrops.py, grade_tiles.py, check_assets.py, pull_bsb.py, gen_assets.py
```

See also `CHANGELOG.md`, `DECISIONS.md`, `PLAYTEST.md`, `PLAY_CONSOLE.md`, `ASSET_REREQUEST.md`.
