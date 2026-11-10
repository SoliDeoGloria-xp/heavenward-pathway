# Decisions and assumptions (build 0.2.0)

Made while building, where the brief and the design doc left room. Each can be changed in data.

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
13. **Landscape only.** The HUD is built for landscape and the project locks sensor-landscape; portrait (1080×1920) is not supported.
14. **Save model**: one slot. Hand-scripted Eden restarts from its beginning on Continue; every later map resumes at its saved objective.
15. **Gear, refinement and drops** beyond keepsake items (Bronze Buckle, Grim's Broken Chain) are not built; the doc's Bronze/Silver gear and +5 refinement need the equipment system first.
16. **Scripture text is not embedded.** Dialogue paraphrases and cites `[BSB: ref]`; `tools/pull_bsb.py` fetches the cited passages for Word Study.
