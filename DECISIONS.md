# Decisions and assumptions (build 0.2.0)

Made while building, where the brief and the design doc left room. Each can be changed in data.

## Progression past Base 10 (0.6.0, phase 3) — a proposal for the owner to tune

Levels 1 to 10 are untouched: their costs are the quest budget (2,210 Base / 855 Job to the Calling). From Base 10 the old rule (800 XP growing 1.12x a level, against foes that paid 3 + level) made level 98 cost about 19 million XP, some 50,000 even-level kills. It is replaced by a table built from a pacing plan, `data/progression.json` `pace`, by `tools/gen_progression.py`.

**The plan (target minutes for one level):** Base 10: 12 · 20: 30 · 30: 50 · 50: 90 · 70: 120 · 90: 160 · 98: 180, straight lines between. No level costs more than 3 hours. Base 10 to 99 is about 139 hours; to 26 (the top of this pass) about 7.5 hours after the Calling.

**The maths.** `cost(L) = minutes(L) / 60 x kills_per_hour(L) x kill_xp(L) / (1 - board_share)`

- `kill_xp(L) = 3 + L + (L - 10)^2 / 4` past level 10 (unchanged at 10 and below): 13 at level 10, 48 at 20, 93 at 26, 453 at 50, 2,037 at 98. A Greater foe pays four times that.
- `kills_per_hour` is about 365 at every level: an even-level foe (40 + 22 x level Health) falls in about 5 seconds to the standard build (each level's two points to Fortitude and Steadfastness, no gear, skills adding 40%), plus 5 seconds to reach the next.
- `board_share` 0.2: a fifth of all XP is expected from Gleanings.
- So: level 10 costs 1,190 XP (73 kills), level 20 11,040 (184), level 26 29,820 (257), level 50 309,190 (546), level 98 2,769,970 (1,088 kills, 3 hours).

**The level gap (field foes only).** Within 2 levels: full pay. Above: +5% a level, at most +25%. Below: -10% a level, never under 20%. Story fights are not touched, so the quest pacing stands.

**The first job** has its own table (`job_first`): 6 minutes for Job 1 rising to 66 for Job 49, about 29 hours, so Job 50 arrives near Base 47. Job XP stays half of Base XP from foes. Stat points (2 a Base level) and skill points (2 a Job level) are unchanged.

**Gleanings.** Each field has one at its region's town board: overcome 20 of its foes, then receive a quarter of what those foes pay again, plus Denarii. Never expires, can be taken again at once, nothing is lost by dropping it. Board XP has its own ledger line and is no part of the quest budget.

**The goals board** holds one set of three goals (100 field foes, 3 Gleanings, 2 finds) for 300 Denarii. A set never expires; a new one is posted only after the old is received and a new week has begun. Missing a week costs nothing. Flagged against the locked rule "no dailies, no FOMO": the owner asked for a weekly board that never punishes absence, and this is the reading that keeps both.

**What the balance report is, and is not.** The autotest recomputes the hours per band from the game's own stat, foe and XP code and fails if any band is more than 25% off the plan or any level to 26 has no field. It is a model: it proves the tables match the plan and that a later change to stats or foes will be caught. It does not prove a person plays at that speed. Nobody has hand-played these fields.

**The owner should decide:** the hours (139 to the cap; the anchors are one line of data), the 20% board share, and the Gleaning size.

## The save file (0.6.0)

- The journey is written to `user://save_<slot>.json` on entering a map, on every objective and Gleaning, **every 30 seconds while walking, and when the app goes to the background or closes**. Before this, time spent hunting in a field was saved only on leaving the map.
- **Continue returns the pilgrim to the very spot** (on maps that keep their state; Eden and the side maps begin again from their start).
- The file is written beside the old one and swapped in, and the old one is kept as `.bak`; a broken file falls back to its backup.
- Settings shows the slot and when it was last saved, with a **Save now** button.

## Towns, fields and danger zones (0.6.0, phase 2)

Owner's answers, 2026-11-10: the Base 10 cap before the Calling stays, so each region has two tiers; fast-travel points are called **Milestones** ("Waymark" stays the name of the messages pilgrims leave).

- **Two tiers per region.** Fields at the level of a first visit (City 1-8, Slough 5-8, House Gardens 6-9, Hill 7-10), and higher fields and danger zones to come back to after the Calling (up to 16, 20 and 26). Nothing stops a low pilgrim walking into a high field: the portal sign gives the levels and each foe's nameplate is coloured by how it compares with the pilgrim (grey, green, bone, gold, ember, crimson).
- **Three kinds of notice.** Aggressive foes attack on sight; passive ones only when struck; alert ones come to the help of their own family when one is struck nearby. Danger zones hold only aggressive foes.
- **A field has one rare Greater foe** that returns after four minutes. In story maps a Greater foe is still a set piece that appears once.
- **A danger zone's boss sleeps** until the pilgrim comes near, and returns ten minutes after it falls. Formalist and Hypocrisy are reused at level 26 at the end of the Way called Destruction (the same foe, scaled by the mob formulas).
- **Worldly Wiseman is not a boss.** The world plan suggested him for the Slough bog; he is a tempter the pilgrim answers with words, so the bog ends in a game-original foe instead.
- **Field finds pay Denarii, never Manna or quest XP.** Manna comes only through the means of grace, and the quest budget of 2,210 / 855 must stay exact. A field's Dreamer's Page pays nothing but itself.
- **A pilgrim who falls in a field or danger zone wakes in the last town**, weary. In a story map he still rises where the map begins.
- **Lord's Day.** Lord's Day Mode closes the whole road at the title screen, so a town needs no behaviour of its own on that day.
- **Palace Beautiful and the Lions' Path keep their hand-built form** (marked `later` in the world graph). The Palace gained a Milestone and a storage chest so that travel reaches it.
- **The Interpreter's House is the town of its region**: a keeper, a table to rest at, a board, a chest and a Milestone were added inside it.
- **Geography that departs from the world plan.** The Way called Danger and the Way called Destruction (Bunyan's two byways at the foot of the hill) replace "By-path Meadow" and "Lucre quarry", which belong to later parts of the book. The road fenced by the Wall called Salvation is a field of its own.
- **Every new map is built from the kit by `tools/gen_fields.py`**: correct in structure, plain to look at. They are placeholders for dressing by hand.

**Awaiting theological review** (flagged `"review": true` in `data/world.json` and `data/mobs.json`; no reviewer is appointed yet):

- Places: Sloth Meadow, Neighbours' Lane, The Old Cellars, The Old Cellars: the Vault, The Foot of Mount Sinai, The Slough Bog, The Slough Bog: the Deep Mire, The House Gardens, The Hill before the Cross, The Dusty Cellar, The Dusty Cellar: the Unswept Room, The Arbour Rest.
- Foes: Gossip, Mocker, Grudge, Hoarder, Miser, Bog Lurker, Sinker, Ember of the Mount, Legalist, Weedling, Dust Mote, Self-Trust, Scorner, Backward Glance, Heavy Heart, Dust Wraith, Prowler, Snare, Shade of the Wood, Ruin, Stumbler in the Dark, Pitfall, The Keeper of the Cellars, Dread of the Deep Mire, The Stirred Dust.
- Words: every townsperson's line, landmark inscription and field page in `data/dialogue.json` whose id begins with a new map's id (35 short scenes). They paraphrase and cite; no Scripture text is embedded. Monsters named for guilt and looking back stand in the field before the Cross (Backward Glance, Heavy Heart): confirm that is fitting so near that place.

## The world graph (0.6.0, phase 1)

- **A road is two one-way edges** in `data/world.json`. Kinds: `portal` (walk in), `door` (use an entity), `exit` (the map's own exit objective), `story` (a scripted scene change). Only Eden to the City is `story_oneway`.
- **A forward portal is the story's own exit light.** It opens when the map's last objective is done (flag `done_<map>`); before that the exit objective makes the same trip, so the chapter is told once. The way back is always open.
- **Recommended levels of story maps are what is true today** (City 5-6 up to the Shadow 11-12). The region bands from the world plan are stored beside them. (Answered in phase 2: the cap stays, regions have two tiers.)
- **The Palace's return portal is by the south path**, where the pilgrim arrives from the Hill, not on the west side as the build notes suggested: the validator requires an arrival point to be near the road back.
- **A finished story map keeps its always-present foes** (the City's Slothlings, the Lions' Path shades) and nothing else.
- No game-original names were added in this phase.

## Art bible (0.5.0)

One rule set for every picture in the game. It is code, not a wish: `tools/artkit.py` holds it, the import tools apply it, `tools/conform.py --check` fails CI when a picture breaks it.

**Palette: 32 colours, no others.** `ink` #1a1622 · `slate` #3d3a48 · `iron` #625e68 · `stone` #918a7e · `ash` #c4bdac · `bone` #f4efe4 · `umber` #3d2a25 · `bark` #6b4530 · `oak` #9a6a3f · `sand` #c79a5e · `wheat` #e8cf9a · `tan` #e0a67a · `blush` #f6d3ae · `pine` #1f3a33 · `moss` #35583a · `olive` #6f7a3a · `leaf` #4f8a45 · `grass` #8cb84f · `lime` #cfe08a · `deep` #1f2a52 · `royal` #2f4f8f · `sky` #4f8fc7 · `mist` #9fd3e8 · `plum` #2d2442 · `violet` #57407a · `lilac` #9a7cc4 · `wine` #6a1f2a · `crimson` #b33a35 · `ember` #e0704a · `brass` #b8862e · `gold` #e8b83e · `glow` #fbe58a.
They are grouped into shading ramps (dark to light) in `artkit.RAMP`: stone, wood, leaf, dry, water, night, dusk, fire, gold, cloth, skin, sandstone. A tint in map data now chooses a drawn variant (dark cobble, mire water); nothing is recoloured at run time except the map's single light tint, which multiplies sprites and props alike.

**Outline.** The outermost ring of every silhouette is `ink`, one pixel, drawn inside the shape. Where two parts of a drawn prop meet, the darker side drops one step: a soft inner line.

**Light.** From the upper left, toward the viewer. Drawn props and UI frames are lit that way. Imported art cannot be relit, so it gets a mild ramp (7% brighter at the upper left of each pose, 7% darker at the lower right).

**Alpha.** On or off. A fading pose is drawn as a Bayer dissolve. The exceptions are light effects in `assets/fx` (glows, shafts, motes: they are light, not objects) and the shadow.

**Shadow.** One blob for everything: an ink ellipse, 0.62 as deep as it is wide, in two flat steps of transparency, as wide as the body above it. The sun casts no other shadows.

**Scale: 48 sprite pixels per world unit, for everything** (`G.PX_PER_UNIT`). Ground tiles are 64 px and span 64/48 units, so a ground pixel is the size of a sprite pixel.

| Thing | World units | Sprite pixels |
|---|---|---|
| Pilgrim, NPC | 1.75 | 84 (in a 64×96 cell) |
| Small foe (common) | 1.25 | 60 |
| Medium foe (rare, elite) | 1.5 | 72 |
| Large foe (greater) | 2.0 | 96 |
| Boss | 3.5 | 168 |
| Low prop (crate, rock, bush) | about 1 | about 48 |
| Post (lamp, banner, pillar) | 2.5 to 4.2 | 120 to 200 |
| Tree | 4 to 5 | 200 to 230 |
| Building | 5.6 to 10 | 270 to 480 |

A foe the game draws taller than its tier (`size` in `data/mobs.json`, times 1.35 for Greater) gets a sheet that tall, so no sprite is stretched past the scale. Far skylines are the one scaled layer: they are distant.

**Anchor.** Feet on the bottom edge of the cell, body centred. Props stand on their bottom edge.

**Timing.** An action lasts the same time for every sprite, however many frames were drawn: idle 1.2 s, walk 0.64 s, attack 0.42 s, hurt 0.28 s, die 0.7 s, cast 0.5 s (`SpriteActor.ACTION_S`). Attack, hurt, die and cast play once and hold. A single-frame idle breathes (1.4%, 2.4 s).

**Interface.** Frames are 9-slice pictures from `tools/gen_ui.py` in the same palette: gold on parchment for windows, gold on umber for the HUD's dark boxes. Text colours are palette colours. Portraits are the speaker's own sprite, enlarged. Drawn backdrops (title, story, creation) are rendered at a quarter size and mapped onto the palette.

**Added in 0.5.0**

- **Pixel art is the style.** The delivered sheets are pixel art already; the smooth 3D shapes, flat vector portraits and glassy blue interface were the odd ones out, so they changed, not the sprites.
- **The delivered "tiles" are scenes, not seamless tiles** (a grove, a crystal rock, a wall, a fountain). They are used as props. Seamless ground tiles are drawn by `tools/gen_world.py`.
- **The delivered interface frames have ornaments on their edges**, which stretch badly, so the game's frames are drawn in the same gold-on-brown manner and the delivered ones are not used.
- **Walls, steps, bridge decks and Eden's plateaus stay solid shapes** with palette tiles on them. A billboard cannot enclose a room or be walked on.
- **Other pilgrims wear the delivered pilgrim art with re-dyed robes** (a palette swap). The Dreamer is the delivered elder, grey-haired, in a brown robe.
- **Banners carry a plain four-point star.** No figure and no emblem of office is drawn on them. The Cross stands empty; the Interpreter's picture shows the grave man of Bunyan's text, a human minister.
- **Portrait play.** The canvas is 1280×720 held sideways and 720×1280 held upright, so buttons keep their size. Supersedes "Landscape only" below.
- **Touch targets** are 56 units or more (the smallest is the 56-unit tab row); on a 1080-wide phone a unit is 1.5 px. Not yet measured on a device.

**Added in 0.4.0**

- **The player is a delivered picture, not a paper-doll.** Only a front pose exists per pilgrim, so every facing shows the front (mirrored left and right) and the actions are generated. Character creation offers two looks instead of hair and robe colours.
- **Music is instrumental arrangements of four hymn tunes** I am confident of note for note (New Britain, Slane, Old Hundredth, Eventide). Other hymns were left out rather than risk wrong melodies. No lyrics appear anywhere. The audio is synthesized and has not been listened to by a person.
- **The Shining Ones are pillars of light** with a name label and no figure.
- **Fantasy dressing** (crystals, glowing mushrooms, standing stones, watching eyes, will-o'-the-wisps) is scenery only; none of it is a game system or carries doctrine.
- **Old save files** (single-slot `save.json`) are not migrated to the three-slot files.

**Added in 0.3.0**

- **Gear never overlaps the Armor of God.** Slots are Hand, Garment, Cloak and Keepsake; no belt, breastplate, shoes, shield, helmet or sword exists as an item (the validator enforces it). Gear text calls it help for the road, not a measure of the pilgrim.
- **Refining is deterministic.** It costs Denarii, always succeeds and never damages the item, so there is no gambling loop.
- **Fruit stones are cut only from Manna**, and Manna comes only through the means of grace (Word Study, rest, the daily reading). They cannot be bought, dropped or earned by kills. The bench says plainly that fruit is borne, not earned (Galatians 5:22-23, John 15:5).
- **Weaknesses are mortification by the opposite virtue**: sloth gives way to Diligence, pride to Wisdom, gluttony and lust to Sobriety, doubt and envy to Hope, wrath to Steadfastness, greed to Fortitude.
- **All-Prayer costs no Zeal.** In the dark valley the pilgrim's own strength is useless; the skill is taught by the story, free, and is the only thing that harms the fiends (Ephesians 6:18).
- **Apollyon**: the pilgrim answers every accusation by admitting it and pointing to mercy, not merit. After the fight the Dreamer says he stood because he was held. The healing leaves are "brought to him" with no hand shown.
- **The daily portion has no streaks or penalties** and is not offered as merit: two small prompts and a modest gift.
- **Act III XP** (700 Base / 300 Job per valley) is my estimate; the design doc gives only a level range for Act III. Tune in `data/acts.json` and the map files.
- **Callings' extra skills and all gear numbers** are first-pass balance.

**From 0.2.0**

1. **Quest XP is the whole design budget; monster XP is extra.** The doc's chapter lists already sum to 2,210 / 855, so kill XP (3 + level) sits on top, tuned to about 20% (target 15–25%, checked by the validator). It lets a player who skips optional objectives still reach Base 10 / Job 10.
2. **Boss XP = objective reward + a small kill bonus**, so the total lands in the 150–250 band (Formalist 150, Presumption 150, Grim 200) without breaking the chapter budgets.
3. **The first-job ceremony is the end of this build.** The brief mentions Apollyon; the approved story doc places the Valley of Humiliation after the first job (Act III), so it is the next chapter, not this one.
4. **Optional objectives are part of the budget**: Obstinate, and one Dreamer's Page per act (as in the doc). Pages unlock nothing but the later cosmetic.
5. **The lamb's bell**: at the Fall the Dreamer tells you to take it; you wake without it (it was a dream) and it is returned at the Palace, as the doc's last Act II quest.
6. **Interpreter's fifth tableau** is the Picture of the grave man (the doc cuts the iron cage and names four). In "the Fire by the Wall" the one who pours the oil is never shown; only the fire is.
7. **Goodwill speaks about "the Lord of this way" in the third person** and is never identified with Christ. The Shining Ones announce forgiveness as messengers. The Cross scene shows only the cross, the tomb and light.
8. **Armor pieces are named** belt, breastplate, shoes, shield, helmet and sword (citing Ephesians 6:13–17) without a per-piece item name that includes a divine name.
9. **Worldly Wiseman's detour** is a short narrated consequence (Sinai, Evangelist's rebuke) plus Weariness, with the same XP either way, so the choice matters to the story but never loses the game.
10. **The Calling trial** lends the first skill of the job you pick for one fight against a Doubt; the final choice at the ceremony is free.
11. **A resting pilgrim is not noticed by foes** (they do not start a fight with someone sitting), so the rest lesson works in a field.
12. **Lord's Day Mode is mandatory on Sundays** (device time) with a tester bypass while `G.DEV_UNLOCK` is true. Set it to false for public launch.
13. ~~Landscape only.~~ Superseded in 0.5.0: both orientations are laid out.
14. **Save model**: one slot. Hand-scripted Eden restarts from its beginning on Continue; every later map resumes at its saved objective.
15. **Gear, refinement and drops** beyond keepsake items (Bronze Buckle, Grim's Broken Chain) are not built; the doc's Bronze/Silver gear and +5 refinement need the equipment system first.
16. **Scripture text is not embedded.** Dialogue paraphrases and cites `[BSB: ref]`; `tools/pull_bsb.py` fetches the cited passages for Word Study.
