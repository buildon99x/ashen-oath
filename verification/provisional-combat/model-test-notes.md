# Restored provisional combat: pure-model verification

Verified on 2026-10-10 with Godot **4.7.2.stable.official.ed1daf0bf**, using fresh isolated `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_CACHE_HOME`. Engine invocations were serialized and bounded by `timeout -k 5`.

## Results

- `provisional_combat_selftest.gd`: **15,386 checks, 0 failures**, exit 0. See [complete model log](provisional-model.log).
- `historical_effect_resolver_selftest.gd`: **48 checks, 0 failures**, exit 0. See [historical resolver log](historical.log).
- Seeds **81–100 each played twice**: **38 victories, 2 defeats**, **596 explicit Sever actions**, and **4,934 campaign steps**, plus separate Boost-allocation commands. Every command checked by the suite preserves save validity. Replays compare complete terminal snapshots, including RNG, logs, resources and rewards.
- Seed **97** reproducibly ends in defeat at node 6 after 94 steps and four won battles. The other nineteen seeds win. A valid, correctly settled defeat is not a combat-contract failure; the test reports outcomes rather than requiring all seeds to win.

These are new tests run against the restored files. The lost suite's **2,795 checks**, **20 wins** and **338 Severs** are not claimed for this code. This verification is not target-game parity, UI validation, native playtesting or evidence of human enjoyment.

## Coverage

- Profile identity/provisional disclosure, runtime constants, separate EP/MP and focus upgrades.
- Allocation/cancellation, invalid and double-click commands, exact spending, one MP charge per boosted action, EP caps, no natural MP recovery, and battle reset without MP refill.
- Fifty repeated exhaustive action-preview/intent-preview batches preserve the entire snapshot, including RNG and event history.
- Independently calculated actual multi-hit damage: shield → Break → limb HP, weakness/relic shields, matching and mismatched heights, and early-victory cancellation of remaining hits.
- Descending and tied initiative, round-boundary reordering, early enemy, death before a queued turn, and absent fallen actors.
- Temporary leg downing, late Break surviving a boundary until an enemy phase consumes it, shield/posture recovery, persistent zero-HP exposure, explicit one-EP Sever, permanent collapse, and removed future attack sources.
- Defend's actual capped MP/HP recovery, ceil-halved damage including wardable attacks, stance expiration, matching/mismatched Parry, once-per-living-hero batch Counters, later batch death removing eligibility, Counter restrictions and passing, actual normal-relic behavior, and historical normal-attack hook attribution.
- Victory/defeat cancellation, no duplicate rewards or settlement, and post-combat revival with a completed old initiative queue.
- Missing/malformed provisional fields, resource bounds, unknown profiles, duplicate/missing actors, dead active actors, inactive Boost, malformed Counter queues, invalid part states, and a rejected checkpoint preserving committed file bytes.
- Exact save/resume with allocated Boost, early-enemy delayed Break, pending Counter action/pass, and pending random relic reward; damaged-primary backup recovery; exact legacy save continuation without provisional fields.
- Twenty seeded full campaigns with exact replay, per-command validation, 1,500-step softlock bound, settlement idempotence, and fresh-cycle resource/stance/combat resets.

## Defects found and verified fixed

The initial restored save validator accepted three impossible battle states: an omitted living hero, a dead current hero, and Boost on an inactive hero. The integration owner fixed these; all negative reproductions now pass. A follow-on validation regression rejected revived heroes after battle because an old completed queue omitted them. The membership requirement is now limited to live battles; both a focused revival test and naturally occurring campaign revivals pass.

The first test draft also compared JSON numeric arrays using Godot's strict nested container equality. The test now normalizes those profile arrays to integers; runtime mechanics were unchanged by that test correction.

## Reproduce

```sh
ISO=$(mktemp -d /tmp/ashen-provisional-tests.XXXXXX)
mkdir -p "$ISO/home" "$ISO/config" "$ISO/data" "$ISO/cache"
export HOME="$ISO/home" XDG_CONFIG_HOME="$ISO/config"
export XDG_DATA_HOME="$ISO/data" XDG_CACHE_HOME="$ISO/cache"
timeout -k 5 120 /workspace/shared/ashen-tools-20261010/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --path . --script res://provisional_combat_selftest.gd
```

Require exit 0 **and** absence of `ERROR:`, `SCRIPT ERROR`, and `FAIL:` in the log. Full repository regression, graphical/native testing, and any later changes remain the integration owner's separate checks.
