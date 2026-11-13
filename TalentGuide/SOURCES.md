# Sources and maintenance

The guide pack records talent names, ranks and allocation order from [WoW Forever Builds](https://wowforeverbuilds.com/guides) and [ForeverSpec](https://foreverspec.com/classes/), checked November 13, 2026. ForeverSpec supplies the 18 additional spec-specific leveling routes in version 0.2. Every profile includes its exact guide URL and publisher; use the Source button. The reviewed facts and URLs are in `tools/talent-guide-sources.json`. No article bodies or website artwork are bundled. Short explanatory notes in Engine.lua are addon-authored; live effect tooltips come from the game.

All 27 Leveling profiles preserve the source's allocation order. The 27 PvE profiles preserve target ranks only. Suggested progression for PvE is an addon heuristic, not an optimization result or an author-endorsed route. WoW Forever Builds profiles retain their Theorycraft status; ForeverSpec leveling profiles are labeled Community guide. Source warnings about older talent data are preserved in the Source tooltip.

## API references

Integration was checked against Blizzard UI source mirrored by Gethe on the `forever` branch:

- [Forever talent frame overrides](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua)
- [Shared talent frame](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua)
- [Trait API documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua)
- [Talent button purchase eligibility](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_TalentButtonSpend.lua)
- [PlayerSpells utility functions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/PlayerSpellsUtil.lua)

The addon reads the displayed configuration through `PlayerSpellsFrame.TalentsFrame:GetConfigID()`, then traverses `C_Traits` nodes, entries and definitions. It attaches separate mouse-transparent border frames to native talent buttons and appends tooltip context with HookScript. It does not overwrite Blizzard methods or use retired Classic talent globals.

## Updating

Review each guide against the current Forever release, update the source manifest and check date, then run `python tools/build_talent_guides.py` and the offline tests. Validate the result in game before claiming current build compatibility. Name/rank checks catch structural discrepancies, not numerical tuning changes. English-name matching should eventually be replaced with verified stable spell/definition identifiers for localization.


## Hybrid profile provenance

The addon-authored Cat/Bear compromise starts with the bundled Feral leveling target: remove five Furor ranks, reduce Shredding Attacks from three to one, add Lacerate, add five Natural Reaction ranks, and raise Feral Instinct from two to three. This remains exactly 51 points. Talent identities and maximum ranks come from the existing reviewed Forever guides. [Method's Cat/Bear discussion](https://www.method.gg/wow-forever/class-guides/feral-dps-druid/talents) informs the role tradeoffs (Bear threat/armor versus Cat throughput); this is not Method's exact allocation or leveling order. The manifest records this distinction as Raynna adaptation / Suggested hybrid.

Adaptive ranking is deterministic: eligible target ranks first, then source priority, with a small preference for finishing invested talents. The hybrid's Damage/Survival preference promotes the corresponding listed talents among eligible candidates. It never claims to simulate damage, survival, or future prerequisite legality.
