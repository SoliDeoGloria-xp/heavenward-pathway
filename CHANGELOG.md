# Changelog

## 0.4.0 (versionCode 5) — the world, the pilgrims, music and effects

- **The pilgrim is drawn art now.** The player uses the delivered pilgrim pictures (two looks at creation) and each Calling has its own look: Valiant, Watcher, Expositor, Shepherd, Steward, Wayfarer. Walk, attack, sit, rest and cast are generated from the single delivered pose. Hair and robe colour choices are gone with the old paper-doll.
- **Every map rebuilt with scenery.** Rock ridges and far skylines frame each place; the Slough has dead trees, fog, will-o'-the-wisps and a lit Wicket Gate; the Interpreter's five pictures are small scenes; the Cross has steps, flowers and a rock tomb; the Hill climbs between rising cliffs; the Valley of Humiliation has a stream, a bridge and a ring of standing stones where Apollyon waits; the Valley of the Shadow has crags, watching eyes, a burning pit and crystals marking the path. Ground tiles are toned down everywhere.
- **Music.** Ten looping themes arranged from four public-domain hymn tunes: New Britain ("Amazing Grace"), Slane ("Be Thou My Vision"), Old Hundredth (the Doxology) and Eventide ("Abide with Me"). Instrumental, synthesized. Bosses switch to a battle arrangement.
- **Sound.** 23 effects: steps, taps, hits, deaths, heals, buffs, arrows, prayer, loot, pages, portals, boss roar, KO.
- **Every skill has its own effect** (twelve styles, thirty colourings) and matching sound.
- **Staging.** Bosses enter with a camera turn, a roar and battle music; found gear pops out in its rarity's colour.
- **HUD.** Dialogue hides the controls; the map banner waits for dialogue; foe names show only for your target; unused skill slots are hidden; the "step complete" mark sits under the tracker.
- **Codex.** Found Dreamer's Pages can be read again. **Saves.** Three slots.
- The three Shining Ones are now figures of light with no drawn form.

## 0.3.0 (versionCode 4) — the loot loop, deeper combat, Act III

- **Road gear.** Four slots (Hand, Garment, Cloak, Keepsake), rarity Clay to Radiant, drops from foes, "Wear the best". The Armor of God stays separate: given whole, never gear.
- **Denarii, vendors, storage.** A Provisioner in the City and a Steward at the Palace buy, sell and store. Honey from the Rock restores Zeal.
- **The armory bench.** Refine worn gear to +5 (always succeeds, never harms the piece). Cut one of nine Fruit stones from Manna and set it in your garment.
- **Combat.** Each family of sin gives way to a virtue (damage rises with the matching attribute). Ranged foes. Status marks: Slowed (sloth, gluttony) and Doubting (doubt, envy). Apollyon throws volleys below half Health.
- **Skill trees.** Each Calling now has six skills (four active, two passive) with prerequisites; the skill bar grows pages as needed.
- **Act III.** The Valley of Humiliation (Apollyon) and the Valley of the Shadow of Death, where the staff is useless and All-Prayer is taught; Faithful joins at daybreak. The Calling no longer ends the game.
- **Codex.** A bestiary with each foe's family and the virtue it gives way to, and a small daily portion (read a passage, overcome ten foes) with no streaks.
- **Sound.** Eight synthesized placeholder effects (hit, hurt, skill, quest, level, coin, equip, bell). Music is still silent.
- Not in this version: portrait mode, placed scenery art beyond two backdrops, music.

## 0.2.1 (versionCode 3) — first real art

- **Monsters and bosses** now use the delivered sheets (46 creatures cleaned and imported; the 17 in Acts I–II are wired in). Idle, walk, attack, hurt and death animations play from `data/sprites.json`.
- **Skill icons**: 20 skills use the P1 icons. **NPCs**: the Interpreter, Goodwill, Help and Watchful use P1 standees.
- Every creature has a complete, consistent action set: rows that were missing, uncuttable or off-model are generated from the idle poses (listed as `generated` in `data/sprites.json`). Evangelist uses his standee, with silver hair.
- New tools: `tools/import_sheets.py` (animation sheets) and `tools/import_art.py` (icons, standees, props). Both remove the painted checkerboard, crop, and fit without stretching.
- Fixed: status chips could stack when several things changed in one frame.

## 0.2.0 (versionCode 2) — Acts I–II, single-player

**Story.** The road is now playable from Eden to the first Calling: City of Destruction (extended), the Slough of Despond and Wicket Gate, the Interpreter's House, the Cross, the Hill Difficulty, Palace Beautiful with the Calling trial, the Lions' Path and the Muster against Giant Grim. The "skip ahead" story cards are gone. Six Dreamer's Pages and the lamb's bell carry the personal thread.

**Progression.** Quest XP follows the design budget exactly (2,210 Base / 855 Job). Monster XP is 3 + level (Greater ×4), bosses 150–200 in all. First job change at Base 10 + Job 10: six Callings, three skills each, robe colour per job. New Pilgrim skills: Prayer of Rest, Watchful Eye, Steady Footing. Armor of God given at the Palace.

**Systems.** Local save and Continue (one slot, autosave at every map and objective). Lord's Day Mode. Settings: music and sound volume, text size, tester bypass for Lord's Day. Audio hooks with silent fallbacks. Online-only UI hidden behind `G.ONLINE`.

**Code.** `world.gd` (2,190 lines) split into `world.gd` plus combat, quests, lessons, cutscene, folk, map kit and per-map scripts. Maps, objectives, XP, dialogue, coach tips, monsters, skills and jobs are data. New tools: `validate_data.py`, `check_assets.py`, `pull_bsb.py`.

**CI.** Validator and script-parse job gate the builds; a playthrough job runs the autotest; the debug APK goes to a draft Release instead of an Actions artifact.

## 0.1.0 — first-session demo

Title, age gate, character creation, Eden Isle, the Fall, City of Destruction, Palace Beautiful preview, Lions' Gate Muster.
