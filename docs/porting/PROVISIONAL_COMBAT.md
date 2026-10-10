# Ashen provisional combat checkpoint

Date: 2026-10-10. Engine: Godot 4.7.2. Base: designated branch `feat/severed-mechanics-port` at `65404c21fbb54e355bfce07b2a829d3fb43f11cb`.

This is a user-authorized, explicitly provisional Ashen Oath combat implementation. It is **not** a verified reproduction of The Severed Gods EA0.2.102 and does not complete the full [porting plan](ashen-oath-severed-gods-mechanics-porting-plan.md). The 28 composite target reference contracts remain unresolved and fail closed. Historical patch facts are separately pinned in [HISTORICAL_EFFECTS.md](HISTORICAL_EFFECTS.md).

## Recovery provenance

The October9 execution-environment loss destroyed the then-active worktree. The lost local `f005f2ab69af93824c6093a2f04b3c9bee183e29` was not found on the remote. This checkpoint adapts the preserved partial reconstruction to the current remote source; it is not a byte-identical restoration of the lost work. New tests below supersede, rather than reuse, pre-loss reported checks. Existing `main` and unrelated worktrees were not changed.

## Actual runtime route

`main.gd:begin_run` starts `ashen_provisional_v1`; `model.gd` dispatches actions, forecasts, turn advancement and special actions into `core/provisional_combat.gd`. `core/provisional_ui.gd` exposes actual EP allocation, Parry and manual Sever, with English/Korean copy. Existing saves without this profile retain the legacy combat route. The profile is saved in `run.ruleset`; combat queues, cursor, pending counters, per-hero EP/Boost/stance, the selected intact UI target and part break lifetimes travel in the same transactional checkpoint.

The model's no-argument `new_run` remains legacy for backwards compatibility with existing external model consumers; the playable menu explicitly selects the new profile. Unknown profile IDs are rejected. No existing user save is converted or rewritten as part of testing.

## Explicit temporary rules

The exact machine-readable values are in `rulesets/ashen_provisional_v1/profile.json`.

- EP: each battle starts at2, cap6. Allocate0–3 with bracket keys, mouse wheel or buttons. Allocation may be cancelled without spending. A valid attack uses1+allocated EP hits and pays MP once. A living hero who spent no EP recovers2 next round; one who spent EP recovers0.
- MP: hero maxima60/80/70, initially full. Current legacy Focus ranks add5 maxMP in this profile. Normal/skill/skill/Defend costs0/10/20/0. No passive round or battle-start MP gain. Existing camp/reward recovery remains transitional content.
- Turns: speeds30/20/10 against enemy1, descending with stable roster ties. Queue rebuilt at round start. Dead actors skipped. Space passes only the active hero or explicitly resolves the enemy. Enemy resolution can insert hero-only free normal counters before the queue continues. No recursive Parry on counters.
- Height: each attack has explicit heights. A mismatch remains legal but deals half damage (floor, minimum1). Broken legs temporarily lower other parts one height; severed legs keep the enemy collapsed. UI recomputes current heights.
- Parts: attacks against shields deal body damage and remove shields, but do not wound the limb. The hit that breaks remains a shielded hit; later Boost hits in the same action can wound the exposed limb. When limbHP reaches0, remaining hits stop. All allocated EP is paid for the valid action; the exact preview reveals the executed hit count before committing. A spent limb cannot be attacked again but remains selectable for manual Sever. Break prevents that limb from attacking through the next enemy phase; other intact sources still act. Surviving limbs recover shields only at a subsequent boundary after that enemy phase observed the break. Pass and Defend remain available with zero EP; an unspent round restores2. Pending counters may always be passed.
- Sever: current normal-turn hero, zero-HP broken limb,1EP plus that action. It permanently removes the linked attack, causes12+3×tier body damage, and adds1 transitional Karma. No automatic Sever occurs on limbHP0.
- Defend: halves all incoming damage until next round, rounding up. The historical v0.2.78 nominal MP grant15 is explicitly adopted, capped to actual missing MP. It does not inherit the old ritual Ward immunity.
- Parry:5MP and current action to select the chosen part's effective height. A matching incoming height prevents that damage and gives that living hero one free normal counter after the enemy attack batch. Mismatch takes full damage. Counter uses the same height, weakness and normal-attack relic path; the historical v0.1.137 hook is recorded separately.
- Enemy learning/difficulty: tier1 keeps a single-source omen. Tier2+ even rounds can direct two distinct limb attacks at the same hero; height, source and exact damage are visible before any input. Breaking one source plus matching the other height can avoid the combined threat, while Defend halves each incoming hit. Future omens exclude spent zero-HP limbs, but retain positive-HP temporary Breaks so a late Counter Break is still observed. If every limb is spent, retain a valid cancelled omen while the player recovers EP and explicitly Severs. This is an Ashen provisional pattern, not an original-game claim.
- Victory: bodyHP0 or all parts severed; pending counter actions cancel before rewards. Defeat and victory settle once through the existing transactional system.

These choices have not been measured against the target game. Historical facts do not verify their surrounding timing, caps, costs or formulas.

## Selection and information

Current actor and queue are visible. Skill cards show MP cost, reachable heights, hit count, body loss and shield loss. Defend shows actual capped recovery. The selected action's hover preview flashes the predicted body/limb HP segment and reports nextHP without consuming resources or RNG. Enemy omens show effective incoming height and per-hero losses. Break, posture change and manual Sever alter the forecast before resolution. Overlays block gameplay shortcuts. An unfinished journey's main-menu entry is Continue, without a competing accidental new-cycle button.

## Verification contract

`scripts/test.sh` uses a fresh HOME and XDG data/config/cache directory for **each** suite, a bounded timeout and error-log scanning. It does not use the user's normal save directories.

- `historical_effect_resolver_selftest.gd`: immutable closed source pins; integer/float JSON equality without accepting strings, booleans, fractions or extra fields.
- `provisional_combat_selftest.gd`: allocation/refund, valid-execution spending, MP-once, initiative/dead actors/ties/early enemy, exact forecast, multihit break/wound, delayed break recovery, posture, manual Sever, Defend caps, Parry success/failure/counters/relic hook, victory cancellation, malformed save refusal, exact pending-counter/Boost resume, legacy saves, damaged-primary recovery and repeated campaigns/settlement.
- `provisional_ui_selftest.gd`: actual menu and handlers, overlay locks, stale-hover invalidation, target switching, capped Defend copy, individual passes, counter controls, manual Sever, English/Korean bounds, Continue menu, resumed profile routing and legacy UI.
- Existing suites continue to protect legacy journeys, save recovery, art, animation, encounter telegraphs and localization. Their passing is not evidence of original-game parity.

Fresh machine test results and the native play record belong in `verification/provisional-combat/README.md`. Headless tests cannot establish visual quality or subjective fun.

## Still required by the complete plan

Fixed legacy skill loadouts, five passive relics, existing three heroes, the nine-crossing map, legacy reward/event menus and stat-only Ash upgrades remain transitional. They are not substitutes for BUILD-01–03 or PROG-01–04. Full skill acquisition/equipment/levels/morphs, relic-trigger synergies, Empower, hero choice/Sigil/NPCs, facilities/shops, Karma gates, Soul/unlocks and wider enemy compositions still need their source-backed definitions and implementation. Officially unfinished target-version features remain completion goals, with their provenance marked honestly.
