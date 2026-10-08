# Boss encounter rules — checkpoint 9

## Concrete rules

- Bellkeeper (tier 1 milestone) and all ordinary fragments retain their existing single-source attacks, source selection, targets, damage, and escalation.
- The milestone Veiled Judge retains the existing primary. It alternates **Single Verdict** on odd rounds and **Split Verdict** on even rounds. Every odd round explicitly warns of the next Split Verdict and its marked-hero Defend counterplay; every even round names the following Single Verdict. With fewer than two intact sources, both descriptions explicitly say Second Verdict cannot form. On even rounds it also prepares **Second Verdict**, from the next intact part after the primary in circular part order, for **10 damage** to one fixed living hero. It requires a distinct second intact source.
- The milestone Pale Sun repeats a three-beat rhythm:
  1. **Gathering Light**: existing primary attack. Warns that the next round is Zenith Release, with a second wardable source if one remains.
  2. **Zenith Release**: existing primary plus **Solar Brand**, from a distinct intact source, for **12 damage** to one fixed living hero.
  3. **Fading Light**: one existing primary at half its usual prepared base damage, rounded down with a minimum of 1. At round 3 this is legs 6 / arm 13 / head 5. Existing late-round escalation is included in the base before halving. Source break and hero guard apply after this recovery reduction.
- A second rite's marked hero can **Defend** to cancel all its damage and focus loss. Guarding another hero does not protect the mark. Breaking that rite's own source independently halves its damage, and severing its own source cancels it permanently.
- A head-sourced attack retains the existing single focus drain on each unguarded target it actually strikes. A warded or already-dead target loses no focus. An attack that itself kills a previously living target still applies its own focus drain, matching existing rules.
- Prepared targets and sources never change within a round. If the primary kills the secondary's target, the secondary misses and does not retarget. Neither attack can come from a severed source. There is no second rite when only one source remains. Severing the final part still wins immediately; preparing with no sources clears stale intent.
- Secondary targets are deterministic without extra RNG: Judge verdict number 0,1,2... and Pale release number 0,1,2... select that index modulo the current ordered list of living heroes, at preparation time. Normal primary targeting retains its existing seeded RNG.
- No hero HP, boss HP, part HP, shields, player damage, focus cost, permanent sever, relic value, or reward value changed.

## Data contract

### Prepared `intent`

The legacy primary keys remain: `name`, `part`, `damage`, `targets`, `description`. Existing callers and old saves can continue using them. `description` also describes the new beat/secondary where relevant.

Optional `secondary` is a dictionary with the same five keys plus `wardable: true`. It always has one target and a different source from the primary.

Judge and Pale Sun each supply optional `rhythm` as `{id, name, description, next}`. Judge IDs are `single` and `split`, with names `Single Verdict` and `Split Verdict`. Pale Sun IDs are `gathering`, `release`, and `recovery`, with the human-readable beat names above. Every `next` is the next readable phase name. Judge descriptions announce the next phase on odd and even rounds, and its odd phase explains the upcoming wardable second source. One-source warnings explicitly say that no second rite can form.

### `get_intent_attacks() -> Array[Dictionary]`

Returns independent copies in resolution order: primary, then secondary if present. The primary copy excludes nested `secondary` and `rhythm` and supplies `wardable: false` by default. It does not invent new attacks for old saves.

### `preview_intent() -> Dictionary`

Retains `status`, `losses`, `focus_losses`, `source`, and `description`. Adds `attacks` and a copy of `rhythm` (empty dictionary for legacy intents, Bellkeeper, and ordinary fragments).

Each `attacks` entry has:

- `name`, `part`, `source` (part's readable name), `targets`, `damage` (prepared base), `wardable`
- `source_status`: `incoming`, `staggered`, or `cancelled`
- `status`: one of those, plus `warded` or `missed`
- `losses[3]`, `focus_losses[3]`: exact actual HP/focus loss attributable to this source after all preceding sources
- `description`: actual loss/ward/cancellation/no-retarget details
- `counterplay`: readable summary, including the named marked hero's Defend option

Top-level arrays sum the ordered per-source arrays. They cap to remaining HP/focus sequentially, skip a target killed by an earlier source, use floor after source break and ceil after ordinary guard, and fully cancel wardable attacks for their guarding target. Forecasts consume no RNG and mutate no state.

Top-level `source` remains the primary's name for compatibility; multi-source UI must render `attacks`. Top-level status is `incoming` if any nonstaggered attack does damage, otherwise `staggered` if damage remains, then `cancelled` if all sources are severed, otherwise `warded` when any rite is warded, otherwise `missed`. Outside battle/without intent it is `none`.

Losses exclude separate post-attack Hollow Bell healing and next-round +1 focus. Those occur only after all attacks, and neither occurs after a party wipe. The end-round resolver uses the same sequential forecast for exact agreement.

### `preview_action(...)`

Existing keys and behavior remain. A Defend preview additionally supplies `wards`, an array of live wardable rite names targeting that hero. Its summary becomes `WARD RITE + HALVE / +N HP` when marked, otherwise retains `HALVE INCOMING / +N HP`. This also provides a current ward hint for old saves whose stored guard-skill description is still the old generic text.

### Old saves

Save version remains 1. Load restores the exact pending legacy intent, targets, RNG, guard and acted state; it does not add a secondary or recompute a rhythm at load time. The currently visible saved attack resolves unchanged. New encounter preparation begins only at the next round boundary. New nested intent data round-trips unchanged.
