# Combat presentation milestone M1

This branch starts at the user's Godot 4.7 migration (`793ad0d`) and retains the requested compact battle symbols and optional tooltips from CP13. It is an initial presentation milestone for review, not the complete FX plan.

## Rules boundary

`model.gd`, `project.godot`, and the user's Windows launcher are unchanged from `793ad0d`. `perform()` and `finish_round()` call the authoritative command exactly once, and save the final result immediately. Damage, focus, RNG, boss behavior, rewards, and the save format are unchanged.

The HUD and monster silhouette read copied values until the real hero `animation_event("attack", "impact")` at 4/12 seconds. No preview substitutes for a hero's actual before/after damage. Enemy events copy the exact sequential forecast used by the existing resolver, preserving source, fixed target, clipped loss, guard, cancellation, and missed targets. Recovery and the next omen become visible only after the last source.

A two-frame local actor/FX hold adds impact weight; `Engine.time_scale` is never changed. Inputs cannot spend additional actions while presentation runs. Space, Enter, Escape, or the visible skip button finish presentation without replaying any command. A lethal command is already saved as an unselected reward before the wind-up. Scene exit clears the queue.

## Current visual slice

- Mara's Sundering Arc: stepped, tapered pale/gold C-shaped strike.
- Shield chip, Break shards, Sever ash/crack, Ward barrier, and cancelled-source collapse have distinct basic shapes.
- Monster hit tint is restricted to the struck part; shared anchors account for the leg-sever height change.
- Per-source enemy feedback does not show hero hit flashes or damage numbers for Ward, cancelled, or missed attacks.
- Other hero skills still share generic typed effects. Nine finished skill presets, bespoke flipbook art, production audio, accessibility settings, boss-specific choreography, and performance qualification remain later work.

## Inspection scene

Open `combat_fx/combat_fx_preview.tscn` separately. Its conspicuous diagnostic header identifies fixture captures; these are not full campaign screenshots. It never saves fixtures.

- F1: next case (chip, Break, Sever, Ward, cancelled, final strike)
- F2: next arena
- F3: pause/play
- F4: one 1/60-second presentation step
- F5: reset and replay
- F6: legacy/new A/B timeline

The actual-game run and diagnostic captures are distinguished in `verification/fx-m1/`. Old scene tests now advance actual hero markers with the test-only `test_helpers.gd` before checking post-animation state. `combat_fx_selftest.gd` separately verifies pre-impact state, marker timing, idempotence, rapid input, source ordering, save continuity, and real viewport skip press/release.

## Verification limits

Official Godot 4.7.2 is the tested engine. The full source regression suite passes. Native normal-input Judge play reached the same reward/HP/Focus/gold as the no-FX baseline. Frame stepping verifies pre-impact versus impact state, but does not establish real-device 60fps/P95. The cloud renderer is llvmpipe and audio is Dummy. No real listening test or Windows runtime pass is claimed. The old 4.6.3 build-script pin remains a separately reported migration tooling issue.
