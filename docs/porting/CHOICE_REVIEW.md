# Provisional combat choice review

Date: 2026-10-10. Scope: the current **Ashen provisional** combat candidate. This is a bounded scripted comparison and static review, not a completion claim, human-fun measurement, or evidence of The Severed Gods EA 0.2.102 parity. Growth and exploration rules are outside this review.

## Evidence and reproducibility

- Baseline: commit `597788546b80f6deecfed0e0488f4bd37b26caff`.
- Candidate: the working-tree sources identified by [source-metadata.json](../../verification/provisional-combat/choice-review/source-metadata.json). At review time the candidate combat SHA-256 was `7e7e371a4d5424181b154817910bd7804b985a91025fb42378dd9d1480f17cce`; the current model, combat and comparison-harness hashes matched the recorded hashes.
- Engine recorded by the run: Godot `4.7.2.stable.official.ed1daf0bf`.
- [Campaign CSV](../../verification/provisional-combat/choice-review/campaigns.csv), [battle CSV](../../verification/provisional-combat/choice-review/battles.csv), [execution log](../../verification/provisional-combat/choice-review/review.log), [raw summary](../../verification/provisional-combat/choice-review/summary.txt).
- Harness: [provisional_choice_review.gd](../../provisional_choice_review.gd) and [review-provisional-choices.sh](../../scripts/review-provisional-choices.sh). The wrapper reconstructs the baseline model/combat under `.runtime/choice-baseline`, removing only the duplicate model `class_name` and changing its combat preload. Shared resolver/content dependencies are hashed in the metadata.
- Twenty seeds, 81–100, each run as baseline/candidate × strategy A/B: **80 campaigns and 427 battle rows**. These are one deterministic run per combination, not 80 independent random samples. Full action traces remain in the local `.runtime` result JSON; they are not needed in the public repository.

The supplied run reports zero rejected commands, softlocks and invalid-save states. Independent CSV checks reconciled every campaign's action/damage totals and won-battle counts against its battle rows, verified 427 unique `(variant, strategy, seed, node)` keys, and verified matched encounter name/tier/milestone values. No Godot process was started for this review.

## Policies and measurements

**A: offensive/Sever.** The existing campaign-selftest policy: Sever an eligible limb first; Defend below 10 MP; otherwise allocate up to 2 EP, prefer W on odd rounds or E on even rounds when affordable, and select the best preview score. If no attack is valid, Pass. This is a fixed heuristic, not optimal play.

**B: former safe policy.** Each threatened hero Parries the single height preventing the most advertised damage; other heroes Defend. A Counter chooses the best legal normal-attack target. The same terminal-cleanup rule applies to both variants: if every remaining limb has zero HP, use a legal direct Q, otherwise Sever if affordable or Defend to recover EP. The recorded runs did not reach this cleanup: B recorded zero direct attacks and zero Severs in both variants.

A shared seeded map plan and reward indices are used; common map/reward/event decision prefixes are checked across variants and strategies. A defeat ends that run, so it cannot contribute later battle rows.

`damage_taken` is cumulative enemy HP damage actually applied by resolution before same-boundary healing. It is not net party HP change. `enemy_phases` counts resolved enemy batches and is the speed measure used below; it is not elapsed player time or merely the displayed round number. Damage can exceed initial party HP because heroes heal between or within battles.

## Campaign-level observations

| Code / policy | Campaign wins | Defeats | Battles entered | Applied HP damage | Enemy phases | Severs | Counters |
|---|---:|---:|---:|---:|---:|---:|---:|
| Baseline A | 19/20 | 1 | 113 | 5,150 | 477 | 298 | 0 |
| Baseline B | 20/20 | 0 | 114 | 0 | 3,635 | 0 | 3,481 |
| Candidate A | 17/20 | 3 | 110 | 4,487 | 502 | 301 | 0 |
| Candidate B | 8/20 | 12 | 90 | 8,897 | 4,025 | 0 | 3,207 |

Baseline B's zero-damage completion of all twenty campaigns confirms the former safe-policy concern within this sample. Candidate B no longer provides that general zero-damage route. However, these totals have **unequal exposure**: candidate B reaches only 90 battles, versus baseline B's 114. Candidate A's lower total damage also cannot by itself be called improved balance; it completes fewer campaigns and takes more enemy phases.

## Matched seed/node comparisons

For each row below, retain only battle keys visited by **both** compared runs. Values are left → right. A `win` is a battle victory, not a campaign victory.

| Comparison | Matched battles | Applied HP damage | Enemy phases | Battle wins |
|---|---:|---:|---:|---:|
| Baseline A → Candidate A | 110 | 5,042 → 4,487 | 461 → 502 | 109 → 107 |
| Baseline B → Candidate B | 90 | 0 → 8,897 | 2,907 → 4,025 | 90 → 78 |
| Baseline A → Baseline B | 113 | 5,150 → 0 | 477 → 3,615 | 112 → 113 |
| Candidate A → Candidate B | 87 | 3,061 → 8,393 | 366 → 3,872 | 85 → 75 |

Matching removes the straightforward later-battle exposure difference, but **does not reset combatants to identical starting states**. Earlier damage, MP use, deaths and healing carry forward. Nor does matching remove survivorship bias from later nodes.

As a sensitivity check, matched rows with identical recorded starting HP/MP/EP arrays give:

| Comparison | Equal-resource pairs | Applied HP damage | Enemy phases |
|---|---:|---:|---:|
| Baseline A → Candidate A | 45 | 1,778 → 1,247 | 166 → 179 |
| Baseline B → Candidate B | 51 | 0 → 2,418 | 1,919 → 2,251 |
| Candidate A → Candidate B | 30 | 360 → 1,270 | 98 → 1,329 |

This controls the recorded resource arrays only; it is not a full-state replay experiment. The shared deterministic reward/event route avoids intentionally giving one policy different rewards. It should not be assumed that the unrecorded full battle state has been equalized.

Candidate A/B show tradeoffs rather than universal dominance: among their 87 common battles, B takes more damage in 43, equal damage in 21, and less damage in 23. B resolves more enemy phases in all 87. Nevertheless, B wins two battles where A loses, at `(seed 91, node 7)` and `(seed 99, node 6)`; A wins twelve where B loses. A's aggregate result is stronger for this fixed-policy comparison, but it is not an optimal-policy proof.

### Where the former safe policy changes

Baseline B and candidate B, matched by seed/node:

| Tier | Matched battles | Applied HP damage | Enemy phases |
|---|---:|---:|---:|
| 1 | 38 | 0 → 0 | 1,602 → 1,746 |
| 2 | 35 | 0 → 5,790 | 887 → 1,359 |
| 3 | 17 | 0 → 3,107 | 418 → 920 |

Tier 1 retains the single-source, zero-damage Parry learning route. The observed break from that route is in tiers 2 and 3. In contrast, candidate A's matched tier-3 damage rises from 1,805 to 2,136 over 33 battles even though its aggregate matched damage decreases; a single overall damage total hides this difficulty shift.

## Source/test review

No additional blocking correctness regression was identified in the text-only review after the reported fixes. The following paths are consistent with the candidate code and checked source tests:

- New attacks reject zero-HP limbs, and an already-valid multi-hit action stops before another hit once its limb reaches zero. Allocated EP is still paid once; the forecast exposes the executed hit count.
- Future intent selection filters zero-HP limbs locally, without redefining `_intact_parts()` or creating an accidental all-zero-HP automatic victory. Positive-HP temporary Breaks remain eligible, preserving delayed suppression. An all-spent fallback retains a valid cancelled intent.
- Counter Pass remains legal when no damaging target exists. With zero EP and `spent_ep=true`, the first boundary clears the spent flag; an unspent round then restores EP, allowing explicit Sever. The source tests cover save/reload of this path and all-Sever victory with body HP remaining.
- Tier-2 even-round primary/secondary attacks share a target. The focused fixture verifies 26 + 20 advertised damage, one-height Parry leaving the other hit, Defend applying 13 + 10 = 23, and alternate-source Break plus matching Parry avoiding both.
- Defend's new incoming-loss preview uses a duplicate hero override, including capped Cinder Heart healing before damage. It does not temporarily mutate the live hero. A 1-HP hero healing 3 correctly previews an HP-capped loss of 4.
- The earlier Boost-matrix expectation of four executed hits into a 30-HP arm was corrected to the spent-limb cutoff. The comparison's A fallback was aligned with the selftest's Pass behavior.

Repository logs report [15,814 model checks](../../verification/provisional-combat/choice-candidate/provisional_combat_selftest.log) and [175 UI checks](../../verification/provisional-combat/choice-candidate/provisional_ui_selftest.log), both with zero failures. Those are scoped automated results, not proof that all design choices are meaningful or that the full port is finished. The separate native-input evidence below complements these automated checks.

## Controlled native-input comparison

The integration owner also recorded [two native branches from the same round-2 Veiled Judge checkpoint](../../verification/provisional-combat/NATIVE_QA.md#choice-repair-controlled-native-branches), copied into isolated QA profiles rather than player-save locations. These branch names are separate from the scripted A/B policies above. The initial boss body HP was 310; both advertised attacks targeted Ivo, at MID (26) and HIGH (20).

- **Parry-only:** Mara/Sable Defended and Ivo paid 5 MP for MID Parry. Ivo took 20 HP damage from the HIGH attack; the boss stayed at 310. The alternative Defend card forecast 23 damage, consistent with the model oracle, but Defend was not executed as a third native branch.
- **Break + Parry:** Mara used Boost 1 W on the head (1 EP, 10 MP, 6 body damage and Break); Ivo paid 5 MP for MID Parry; Sable used Boost 2 Q on the exposed head (2 EP, 57 body damage, limb HP to zero). Incoming damage was zero and a Counter remained available. The boss reached 247 body HP.
- **Escape and Sever:** With the zero-HP head selected, attack cards were disabled. Space passed Counter; round-3 Mara then paid 1 EP to Sever, changing body HP 247→229, Karma 5→6 and Mara EP 3→2. English/Korean help and controls were also inspected through native input.

This verifies one resource-using counterplay and the spent-limb escape in actual input play. It is a deliberately selected two-branch checkpoint comparison, not a broad balance sample, an optimality test or a human-enjoyment result. Screenshots remain private and are not linked or included here.

## Remaining limits and useful next evidence

1. The candidate combines spent-target rejection, intra-action hit cutoff, future-source filtering and converging attacks. This comparison does not isolate each change's individual contribution.
2. A never uses Parry; B does not proactively Break the alternate source. The intended mixed counterplay is therefore not represented by an optimized third campaign policy; the native fork above checks it at only one checkpoint. A poor result for the old safe heuristic is not evidence that reasonable adaptive play is too difficult.
3. Winning without Sever remains possible: candidate B wins eight campaigns with no Sever. Explicit Sever need not be mandatory for every winning strategy; this result does not demonstrate that Sever is globally optimal or sufficiently attractive to human players.
4. B's long fights and A's added defeats still need broader observed input play and decision-quality review. A round count is not a measure of boredom, clarity or enjoyment.
5. A stronger causal test would clone the same full battle-start snapshot into both variants, and separately compare adaptive Break + Parry, Defend, and offensive choices. Repeated runs of the same deterministic seed/policy would verify reproducibility, not increase independent sample size.

The supported conclusion is narrow: **the old general zero-damage policy no longer succeeds universally, and the spent-limb/Sever escape path is preserved.** Final balance, the preferred mixture of tactical choices, native usability and the overall port remain open evaluation questions.
