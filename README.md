# Talent Guide — WoW Forever

Version 0.3.3 targets Forever 1.60.1 / Interface 16001. The installed client executable was identified as build 70888 on November 13, 2026; runtime compatibility still needs an in-game test. This is a separate addon from Raynna's Tracker, using the same brown parchment, gold borders, fonts and title treatment as Tracker and Bestiary. Its texture is bundled independently.

Talent status labels sit directly above their own icons in single-line, dark-backed badges. The next pick uses a solid gold NEXT PICK banner and animated inward pointers above neighboring icons. Level and availability details remain in the guide panel and tooltip.

## Install

Extract the release ZIP into `World of Warcraft/_forever_/Interface/AddOns/` so that `TalentGuide/TalentGuide.toc` sits directly beneath AddOns. Restart WoW and enable **Talent Guide** at character selection. Open your talents or type `/tg`.

## Use

- Choose your spec with the **Specialization** dropdown, then **Leveling** or **Level 60 / PvE**. Every class has all three specs in both modes. Selections are saved separately for each talent configuration; old selections are migrated.
- **Leveling:** published 51-point routes for all 27 specs, covering each level from 10 to 60 (or earlier with Legacy Talented).
- **PvE:** one sourced level-60 target build for each of all 27 specs, including tank and healer builds. The addon suggests an available target rank, preferring the selected tree and then earlier rows. These suggestions are **not a published or optimized leveling order**.
- Only the next pick is highlighted by default, with a prominent label on the talent. **Green / PICK NOW:** available now. **Amber / NEXT LV:** no unspent points, plan for your next point. **LOCKED:** points or requirements are unavailable. **RESPEC:** all points have been used but the build is incomplete. A route milestone earlier than your character level is explicitly labeled as a catch-up pick.
- **Build** toggles subtle borders on all unfinished build talents. The panel shows the recommended spell icon, rank, your level, unspent points and four route rows with icons.
- Hover a talent or a route row for the live spell tooltip and guide context. Page through the remaining route with the arrow buttons.
- Click **First point** to match your Legacy Talented setting: level 10 with no reduction, down to level 5 with the full reduction. This affects level labels only; purchase availability always comes from the game. The 51-point cap is unchanged.
- **Source** opens a selectable guide URL; press Ctrl+C to copy it, Escape to dismiss it. The addon does not connect to websites.
- Drag the title to move the compact 310 x 506 panel. It docks beside the talent window when space permits and otherwise fits inside it. `/tg reset` restores automatic positioning.
- The panel opens and closes with the talent UI, including N/Escape and parent-window closure. It remains hidden on the spellbook and inspection views. Closing its x hides it until the next talent-window opening. `/tg off` disables it persistently; `/tg` restores it.

## Recommendation scope

The original nine leveling routes and PvE sources are labeled **theorycraft**; the additional 18 leveling routes are published community guides from ForeverSpec. Several PvE sources flag older talent data. Hover Source for the publisher, status, date and warnings. These are suggested builds, not a verified universal best choice. PvP builds are not included. Guides are offline snapshots checked on November 13, 2026; changing the interface version does not refresh them.

This release matches English talent names. On enUS/enGB clients they come straight from the client; on every other locale `Localization.lua` identifies each talent by its position in the tree (tree, row, column), which is the same in every language, and supplies the English name the routes use. A talent whose maximum rank disagrees with that table is left untranslated, so stale tree data reports a mismatch rather than pointing at the wrong talent. Rebuild the table with `python tools/build_talent_positions.py`. It reads names, rank limits, purchased ranks, availability and prerequisite checks from the live trait APIs. If a recommended talent is missing, ambiguous or has a different maximum rank, the entire guide's highlighting pauses and identifies the mismatch. Matching names/ranks cannot detect every balance or spell-effect change.

Existing points are accounted for, including staged changes. Points outside the target build are flagged; the addon never spends, refunds or applies talents. A strict leveling route stops at its first missing rank rather than silently skipping it. PvE target progression may require a respec if the existing allocation cannot reach the build. Guidance hides in combat, while inspecting another player, and on inactive talent tabs.

## Verification

Offline Lua 5.1 tests cover all 55 profiles, every step of all 27 leveling routes, changed/missing talents, partial ranks, gear ranks, deviations, the API adapter, dropdown and activity selection, layout anchors, overlays, immediate open/close behavior, hidden parents, inspection/combat hiding, next-level labels, old-setting migration and separate dual-spec settings. Run `python tests/test_talent_guide.py` with `lupa` installed. Rebuild the manifest with `python tools/build_talent_guides.py`.

**An in-game smoke test is still required.** Check `/tg`, select each available profile, spend/stage/undo a point, change active talent tab, inspect another player, enter/leave combat, close/reopen talents, move the panel, and reload. Verify the first recommended node and its live tooltip on each class. Offline mocks cannot prove rendering, taint behavior or current guide quality in the actual client.

Version 0.2.1 recovers the legacy close-button saved disable once. Explicit `/tg off` remains persistent; `/tg reset` also re-enables the guide.


## Adaptive guidance and Cat/Bear hybrid (0.3.0)

Choose **Follow guide** for the original strict route, or **Adapt to my talents** to keep existing points and prioritize available target ranks. Only the next pick is checked against current client eligibility. The remaining list is a priority preview, recalculated after each change, not a promised future level-by-level allocation. Off-build points reduce the remaining 51-point budget; the panel explains when the exact target needs a respec. Nothing spends or refunds talents automatically.

Druids can select **Feral Cat / Bear** under Leveling, then choose **Balanced**, **Damage**, or **Survival**. This is an addon-authored 51-point compromise using the existing Feral route, with Bear utility added; it is not a reproduction of Method's build or an optimized endgame recommendation. The preference changes priority among currently legal targets, not the final point budget. Adaptation is always active for this hybrid.

The next pick has a pulsing gold frame. Purchased talents within target ranks show green **Good**; purchased talents outside the build or beyond target ranks show red **Not recommended**. Those ratings describe fit to the selected build, not absolute talent quality. Source mismatches still suspend all ratings and recommendations.

Use **/tg settings** to open **Raynna's mods → Talent Guide**. The page works standalone and contains enable, adaptive, animation, rating, full-build, scale, centering and appearance controls. The shared registry creates one category regardless of installation/load order. Appearance changes intentionally apply to installed registered Raynna addons, each saving its own preferences. Animation runs only on the next-pick frame while shown; idle talent polling was removed.
