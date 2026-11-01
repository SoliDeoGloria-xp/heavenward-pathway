# Heavenward Pathway Online: first-session demo

A playable demo of the opening of *Heavenward Pathway Online* (HPO), a Reformed, allegorical, Ragnarok-style mobile MMORPG after John Bunyan.

- **Look:** classic Ragnarok Online, with 2D pixel sprites on a lit 3D map, a fixed three-quarter camera and RO-style windows.
- **Controls:** Ragnarok M / Origin style for phones, with a floating joystick, an Attack button with a skill arc, and Auto.
- **Engine:** Godot 4.3, using the Compatibility renderer so it runs on Android and in mobile browsers.
- **Status:** offline single-player demo. Placeholder art, no audio.

## Play it

| Where | How |
| --- | --- |
| Phone browser | Open the GitHub Pages link (Settings → Pages) in landscape. Every push to `main` rebuilds it. |
| Android phone | Actions → latest **Build demo** run → download **hpo-android-debug-apk** → install the APK (allow "install unknown apps"). |
| Play Console (internal testing) | Run **Android release (Play Console AAB)** manually after adding the signing secrets (see below), then upload the `.aab`. |
| Desktop | Open the folder in Godot 4.3 and press Play. A mouse works as touch. |

## What the demo covers

1. Title, then an age gate (13+), then the one-world screen (no server choice).
2. Make Character: an 8-direction turntable, hair style and colour, robe colour, and the six-attribute hexagon. Divine names are blocked.
3. The Bunyan dream opening.
4. **Eden Isle** (the Dreamer's vision, no combat). Walk to the light, tend the vine, gather figs, name the lamb, then do the Word Study at the stone tablet (BSB placeholder, Manna +5). Base Level is capped at 5.
5. **The Fall**: fixed panels narrated by the Dreamer, ending with the cherubim. God is never shown or voiced.
6. **The City of Destruction**: 2D sprites fight on a 3D street.
   - Attack, First Steps, Take Refuge, Auto and quick items.
   - Drops, Base and Job level-ups, and the KO/rest flow: Weariness, 5% Manna spoilage, no XP loss.
7. **Evangelist**: Bunyan's public-domain lines with a portrait cut-in, then the parchment roll. Snapshot mode unlocks, and you follow the shining light to the warp.
8. **Onward**: story cards skip ahead to the end of Act II (Slough, Wicket Gate, Interpreter, the Cross, Hill Difficulty).
9. **Palace Beautiful, the first House**: a shared hub with other pilgrims (simulated offline) who wander, sit and chat. Speak with Watchful, rest at the hearth (required once before Act III), raise a Waymark, then answer the Muster Board.
10. **Muster: Giant Grim at the Lions' Gate**: the queue fills with two pilgrims and an AI Steward, then a party boss fight with telegraphed strikes, a wide slam, enrage at 50%, a defender, a healer and Fellowship Marks.

## World model (GDD v0.3, "Solo Journey, Shared House")

- **The Way is solo** (with story companions or invited friends). It holds the story, secrets and side paths.
  - **Secrets:** 2 per map, glinting only when you are close, counted by the ✦ next to the minimap and hidden from the minimap.
  - **Waymarks:** set phrases or BSB references that other pilgrims leave (Menu → Waymark), with Thanks.
  - **Passing pilgrims:** faint figures of other players walking the same road.
- **Houses are shared hubs**: Palace Beautiful in this demo; Mansoul and Beulah later. **Wilds are shared fields** (not in this demo).
- **Musters** are queued party and alliance fights, launched from the Muster Board. Empty places fill with AI Stewards after 60 s (6 s in the demo).
- Design doc: https://claude.ai/artifact/KUodVXBBgkqdsSDX59gLfR

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

## Replacing the placeholder art

`tools/gen_assets.py` draws all current art. Commissioned art can replace any file if it keeps the same name and layout.

| File(s) | Layout |
| --- | --- |
| `assets/sprites/pilgrim_body.png`, `pilgrim_robe.png` (greyscale, tinted in game), `pilgrim_hair_0..2.png` (greyscale), `pilgrim_staff.png` | 32×48 frames, 10 columns × 5 rows. Rows (directions): S, SW, W, NW, N. East-facing directions are mirrored. Columns: idle, walk×4, attack×2, sit, rest (KO), cast |
| `assets/sprites/mob_slothling.png` | 40×36 frames ×7: idle×2, move×2, hurt, die×2 |
| `assets/sprites/npc_evangelist.png` | 32×48 frames, 2 columns × 5 rows |
| `assets/sprites/npc_lamb.png` | 34×28 frames ×2 |
| `assets/portraits/*.png` | NPC dialog cut-ins, about 256×320 |
| `assets/ui/*.png` | 9-slice UI kit (windows, buttons, gauges, round HUD buttons, joystick, minimap frame) |
| `assets/icons/*.png` | 64×64 item, skill and menu icons |
| `assets/tiles/*.png` | Seamless 64×64 ground and wall textures |

The sprite sheet should be drawn at 2× and keep hard pixels. Import settings are lossless with no mipmaps; see `project.godot`.

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
main.tscn / scripts/main.gd   screen manager (title, create, story, world, end)
scripts/g.gd                  global state, fonts, theme, paper-doll compositing
scripts/screens/*.gd          title, create, story, world (3D maps, combat), end
scripts/ui/*.gd               HUD, UI kit, multi-touch buttons, floating joystick
scripts/actors/sprite_actor.gd  8-direction billboard sprites with shadows and name plates
scripts/autotest.gd           scripted full playthrough with screenshots (-- --autotest)
tools/gen_assets.py           placeholder art generator (Python + Pillow)
```

Fonts are Nunito and Cormorant Garamond, both under the SIL Open Font License (see `assets/fonts/`).
