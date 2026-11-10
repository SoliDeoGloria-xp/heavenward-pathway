# Changelog

## 0.2.1 (versionCode 3) — first real art

- **Monsters and bosses** now use the delivered sheets (46 creatures cleaned and imported; the 17 in Acts I–II are wired in). Idle, walk, attack, hurt and death animations play from `data/sprites.json`.
- **Skill icons**: 20 skills use the P1 icons. **NPCs**: the Interpreter, Goodwill, Help and Watchful use P1 standees.
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
