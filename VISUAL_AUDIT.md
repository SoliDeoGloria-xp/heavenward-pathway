# Visual consistency audit (0.4.0 → 0.5.0)

Taken from a fixed gallery of 49 pictures of 0.4.0 (every map from three spots, every main screen, the HUD upright) and contact sheets of every sprite, tile, prop, icon and frame. Each row is a mismatch that was on screen, and what 0.5.0 did about it. The rules that settle them are in DECISIONS.md, "Art bible".

## What was mismatched

| # | Where | Mismatch in 0.4.0 | Kind | 0.5.0 |
|---|---|---|---|---|
| 1 | Whole game | Three unrelated styles on one screen: pixel-art sprites, smooth-shaded 3D shapes, flat vector pictures | Style | One style: pixel art, by rule |
| 2 | Trees, bushes | Green spheres on a cylinder, smoothly lit | Style | Drawn sprites; the delivered grove painting at map edges |
| 3 | Houses, palace, gate, tomb, arbour | Boxes and prisms with a stretched wall texture; the palace was a grey block | Style | Drawn houses; the delivered palace, wall, gate and fountain paintings |
| 4 | Rocks, spires, standing stones, pillars, crystals, mushrooms | Spheres, cones, boxes, glowing cones | Style | Drawn sprites |
| 5 | Lamps, torches, banners, fences, crates, pedestals | Thin boxes and flat coloured planes | Style | Drawn sprites; fences stand along their line |
| 6 | The chained lions | Two boxes and two spheres each | Style | The delivered lion art |
| 7 | Ground | One blurred photographic-looking texture per map, tinted, a single flat colour to the horizon | Style, palette | Palette tiles at sprite scale, two per map in patches, with tufts, flowers, pebbles and worn patches |
| 8 | Roads, floors | Ruled rectangles with hard straight edges | Style | Ragged pixel edges |
| 9 | Water | Smoothly blended scrolling texture | Style | Palette tile that moves a pixel at a time |
| 10 | Other pilgrims (Pliable, the House folk, the muster company, the Dreamer) | Flat paper-doll figures beside the drawn player | Style | The delivered pilgrim art in re-dyed robes; the Dreamer is the delivered elder |
| 11 | Lamb, serpent, lilies | Tiny flat placeholders at double pixel size | Style, scale | Redrawn at scale |
| 12 | Dialogue portraits | Flat vector faces (Dreamer, Evangelist) four times the sprite's resolution | Style | The speaker's own sprite face, enlarged |
| 13 | Title, story plates, creation backdrop, ending | Smooth vector hills, circles and gradients | Style | Rendered at quarter size and mapped onto the palette |
| 14 | Interface | Glassy blue-white rounded panels, anti-aliased rings and pills; nothing in common with the art | Style, palette | Gold-and-parchment pixel frames (9-slice), square corners |
| 15 | Icons | 42 delivered pixel icons beside about 30 flat vector ones | Style | All held to palette and outline (the code-drawn ones are still simple: see below) |
| 16 | Foes | Pixel size differed by tier: a Slothling at 58 px per unit, Apollyon at 32. Bosses looked blown up | Scale | Every sheet rebuilt at 48 px per unit |
| 17 | NPC standees | 55 px per unit against the player's 48: slightly finer and shorter | Scale | Same 64×96 cell and 84 px body as the player |
| 18 | Props placed as billboards | Scaled to any height asked for in map data | Scale | Drawn at 48 px per unit; map data no longer sets a size |
| 19 | Ground and wall textures | Stretched to arbitrary sizes per surface | Scale | One world-space scale everywhere |
| 20 | Sprites | Chibi figures had dark outlines, painted monsters had none | Outline | One-pixel ink outline on every silhouette |
| 21 | Colour | Each source had its own colours; map data tinted textures to arbitrary hex values | Palette | 32 colours; a tint now picks a drawn variant |
| 22 | Sprites | A vertical brightness gradient applied in the shader to sprites only | Lighting | Removed; one light ramp at import |
| 23 | Shadows | Sprites had a blob; 3D shapes cast long sun shadows; billboards cast none | Lighting | One blob for all; sun shadows off |
| 24 | Sprite edges | Soft alpha on generated death frames, hard on everything else | Alpha | Hard everywhere; fades are a dissolve |
| 25 | Standees | Feet 2 px above the cell's bottom edge; the player's on it | Anchor | Feet on the bottom edge for all |
| 26 | Animation | Each sheet carried its own frame rates: the same action took different times per creature; death could loop | Timing | One table of durations; one-shot actions hold their last frame |
| 27 | Standing NPCs | Completely still | Timing | A slow breath |
| 28 | Camera | Eased a fixed fraction per physics tick: faster on fast screens, and no lead | Motion | Rate per second, with a small lead in the walking direction |
| 29 | HUD upright | Not laid out: everything shrank to a third and the world zoomed in on the pilgrim's feet | Layout | A real upright layout; switches when the phone turns |
| 30 | Windows | Some wider than an upright screen | Layout | Clamped to the screen |
| 31 | Cards inside windows | (found during the pass) dark text on dark cards after the reskin | Layout | Light card frame |
| 32 | End and title screens | Said "placeholder art" | Text | Removed |

## What is still not seamless

These are visible if you look for them. None can be fixed by processing; each needs new source art (ASSET_REREQUEST.md) or a design decision.

1. **Characters face front in every direction** and their walk, strike, sit and cast are generated from one pose. This is the largest remaining tell.
2. **24 creatures have generated motion** for one or more actions.
3. **The code-drawn kit is plainer than the delivered paintings.** A drawn house beside the delivered palace, or a drawn bush beside the delivered grove, shows it. Bushes and cliffs are the weakest.
4. **Delivered scenes are painted from a higher camera angle** (the palace, the fountain) than the straight-on drawn props.
5. **Walls, steps and plateaus are still solid shapes** with pixel tiles, lit by the 3D light, so they shade smoothly where sprites do not.
6. **Sprites are enlarged by a non-whole factor on most screens**, so pixel rows are not all the same thickness. Fixing it means locking zoom to whole multiples.
7. **Text is a smooth font**, not a pixel font. A pixel font at these sizes reads worse; left as is on purpose.
8. **Light effects** (glows, shafts, sparkles, skill effects) are soft by design and are not palette-locked.
9. **Elders are a young face with grey hair.** Named NPCs share a few figures.
10. **Maps are still level to walk on.** Depth comes from scenery, patches and skylines, not from terrain height.
11. **Hard quantising cost some detail** on the darkest painted monsters and the large scenes (a little speckle).
12. **Title and story plates** are code drawings pushed through the palette, not painted pixel art.
