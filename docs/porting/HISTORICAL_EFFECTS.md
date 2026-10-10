# Reconstructed historical effect adapter

Rebuilt on 2026-10-10 for the Ashen provisional combat compatibility API. The
lost historical resolver was not recovered byte for byte. This replacement is
new code, checked against public patch evidence, with no original-game source,
assets, purchase, download or original-build execution.

## Evidence and limits

- [Official Steam community page](https://steamcommunity.com/app/3755930/?l=russian),
  section `v0.2.78 > Gameplay & Balance`, dated `21 Aug`: Defend's nominal MP
  grant increased from 10 to 15. The page shell is Russian; the patch text is
  English. The older `/allnews/` route did not extract in this pass.
- [Official Steam announcement feed](https://store.steampowered.com/news/posts/?enddate=1778507195&feed=steam_community_announcements),
  `The Severed Gods Playtest`, author `quan.le`, `v0.1.137`, dated `11 May`,
  `Balance / Tuning`: normal-attack counters activate normal-attack relics;
  successful Parry allows the Hero's action and excludes NPC actions.

Both were re-read on 2026-10-10. Publication labels above reproduce the page's
visible day/month, without treating a feed retrieval as original-build play.
The playtest app ID in the compatibility source ID is retained from the
reconstructed runtime contract; the feed itself identifies the playtest title.

These are historical patch deltas, not complete EA 0.2.102 rules. The 28
unresolved contracts in `severed_v0_2_102/evidence.json` remain unchanged and
`reference_contract.gd` still refuses to activate that profile. No v0.1.143
height contract was added: it is unnecessary for this compatibility surface
and was not independently established in this reconstruction.

## Contract

`core/historical_effect_resolver.gd` provides `read_manifest()` and
`resolve(manifest, source_id, rule_id, event)`. The versioned source manifest is
`rulesets/severed_historical_effects_v1/manifest.json`.

- `official_3755930_v0.2.78` / `defend.mp_grant`, with
  `resolved_boundary = defend_grant`, returns the nominal 15-MP descriptor.
  Ashen owns recipient selection, caps, timing, mitigation and action cost.
- `official_4129400_v0.1.137` / `counter.normal_attack_relic_event`, with
  `resolved_boundary = resolved_counter` and boolean `uses_normal_attack = true`,
  returns a `relic_hook` descriptor whose event is `normal_attack`. This does
  not grant MP, implement a relic or specify ordering.
- The optional `parry.successful_action_scope` on that playtest source accepts
  only `resolved_boundary = resolved_successful_parry`; it describes hero-only
  scope with NPC actions disabled. It does not determine success or alter a
  turn queue. The provisional runtime is not required to consume this rule.

The resolver has no model or save dependency and mutates no input. Unknown,
incomplete, mismatched or altered source/effect pins fail closed with `ok =
false`, an empty effects list, and `target_version_verified = false`. Successful
responses also keep that flag false and include their historical source version.
The caller explicitly adopts a historical descriptor into Ashen's temporary
rules; no automatic merging of different original-game versions occurs.

## Verification

`historical_effect_resolver_selftest.gd` isolates the descriptor API, invalid
boundaries and types, source/version tampering, independent output copies and
the still-unresolved target contract. It does not run a battle or touch a played
save. Run it only in the coordinated isolated test profile:

```sh
godot --headless --path . --script res://historical_effect_resolver_selftest.gd
```

On 2026-10-10 the coordinated, isolated Godot 4.7.2 run passed **48 checks,
0 failures**, exit 0. It caught and prompted a fix for JSON float versus integer
pin comparison: exact recursive comparison now admits equivalent numeric JSON
values while rejecting boolean/string substitutions, fractional amounts and
extra descriptor fields. The test safely reports failed positives rather than
accessing missing result fields. JSON validation and diff checks also passed.
These results establish descriptor compatibility only; they do not establish
native play, original-game parity or byte-identical recovery.
