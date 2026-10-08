# Ashen Oath rules model

`model.gd` is a standalone Godot 4 `RefCounted` class named `OathModel`. It has no scene, asset, plugin or network dependencies. All content and rules here are original. UI code should treat its dictionaries as read-only and use commands to change state.

## Commands

All commands below return a boolean. A rejected command leaves gameplay unchanged and sets `last_error`; accepted commands clear it.

- `new_run(seed_value: int = 0)`: reset run-only state and open the first map crossing. A nonzero seed reproduces the campaign, relic draws and target selection. Zero uses the current Unix second. Abandoning an unfinished run forfeits its unbanked essence. Actual defeat and victory bank earnings.
- `travel(choice_index)`: select one of the current map paths, entering combat, a camp, an event or a relic shrine.
- `start_battle(tier = 1)`: direct testing/UI helper. Requires an active run and map/battle phase. Tier is clamped to 1–3. Normal `travel` selects whether this is a god-fragment or a milestone boss.
- `act(hero_index, skill_index, part_index = 0)`: one hero action. Index 3 is Defend and ignores its target. Attack skills require a living hero, unspent action, enough focus and an intact target.
- `end_round()`: resolve the displayed enemy intent, test party defeat, restore one focus to each hero, clear actions/guard, then prepare the next intent. Ending early forfeits unspent actions.
- `choose_reward(index)`: claim one battle reward and advance the route.
- `choose_event(index)`: resolve a camp/event/shrine option and advance the route. Unaffordable choices are rejected.
- `buy_upgrade(key)`: spend banked essence between runs; keys are `vitality`, `force`, `focus`. Five ranks maximum. Upgrades affect the next run.
- `upgrade_cost(key)`: next rank's price, or -1 for an unknown upgrade.
- `save_meta()` / `load_meta()`: persistent progression only. `meta_path` defaults to `user://ashen_oath_meta.json`. `persist_meta = false` disables automatic saving for tests; explicit save still works.
- `actions_remaining()`: count living, unspent heroes.
- `get_intent_attacks()`: ordered primary and optional secondary attack copies.
- `preview_intent()`: read-only exact sequential incoming HP/focus losses, with per-source `attacks` and `rhythm`; includes source break/sever, guards and fixed targets killed by an earlier attack. Hollow Bell healing and next-round focus regeneration occur afterward.
- `preview_action(hero_index, skill_index, part_index)`: read-only damage, shield, break/sever and guard forecast; does not spend resources or consume RNG.
- `has_relic(id)`: test a run relic.
- `describe()`: return a deep snapshot of all public state, including `round` and `round_number` aliases.

## Public live state

- `phase`: `title`, `map`, `battle`, `reward`, `camp`, `event`, `relic`, `victory`, or `defeat`
- `title`: current screen/encounter title
- `round_number`: one-based battle round
- `heroes`: three dictionaries in fixed order Mara (Ironbound), Ivo (Ash Cantor), Sable (Gloam Scout). Each has `name`, `role`, `hp`, `max_hp`, `mp`, `max_mp`, `acted`, `guard`, `skills`. MP is called focus in prose
- Each skill has `name`, `type`, `power`, `cost`, `description`, `break_power`. Types are `slash`, `blunt`, `pierce`, `arcane`, `guard`. Each hero has three attacks and Defend
- `parts`: three dictionaries in fixed order LOW legs, MID arm, HIGH head. Each has `name`, `level`, `hp`, `max_hp`, `shield`, `max_shield`, `armor`, `weakness`, `broken`, `severed`, `move`
- `boss`: `name`, `title`, `hp`, `max_hp`, `tier`, `milestone`
- `intent`: `name`, `part` (source part index), `damage` (base telegraphed damage), `targets` (hero indices), `description`
- `campaign`: nine crossing dictionaries with `index`, `name`, `tier`, `milestone`, `choices`, `completed`, `selected`. Milestones are indices 2, 5 and 8. The other crossings offer two seeded branches; a full route visits nine crossings
- `choices`: current map options; each has `name`, `kind`, `description`, `tier`. Kinds are `battle`, `boss`, `camp`, `event`, `relic`
- `rewards`: three choices with `name`, `description`, `kind` (`heal`, `gold`, `relic`)
- `event`: `name`, `description`, `options`. Each option has `name`, `description`, `effect` and optionally `cost`
- `run`: `seed`, `node`, `stage` (same zero-based index), `gold`, `karma`, `essence`, `relics`, `bosses_defeated`, `battles_won`, `path`; optionally `damage_bonus`. At victory, node/stage is 9. Relics are dictionaries with `id`, `name`, `description`
- `meta`: `essence`, `upgrades` dictionary, `runs`, `wins`. This persists independently of the current run
- `log`: up to 120 action-log strings, oldest first
- `last_error`: reason the last command was rejected

## Rules worth explaining in the UI

- A hero acts once per round. A basic attack costs no focus; Defend restores 2 focus and 3 HP, then halves incoming damage for that round. All heroes regain 1 focus when a new round begins
- Shielded parts resist HP damage through armor. Any hit removes shields; matching a weakness removes an additional shield. Some skills have extra shield damage
- Removing the last shield breaks the part. That strike cannot sever it, even if its remaining HP is tiny. A subsequent hit can bring the exposed part to zero HP and sever it
- A broken part stays broken. Broken-source enemy attacks deal half damage. Severing permanently disables that part's move and cancels it if already telegraphed. Severing also deals core rupture damage and grants 1 karma
- Defeat the core or sever all three parts to win. Dead heroes cannot act; healing rewards, rest and certain events revive them
- The low move hits the party; the middle move targets a revealed hero; the high move hits the party and drains unguarded focus. Damage rises after round five to discourage endless stalling
- Relics stack across the run but never duplicate. Once all five are owned, another relic reward grants 4 essence instead
- The event option “Seize their supplies” grants 24 gold and costs 2 karma. While karma is negative, each part in the next battle starts with 1 extra shield. Kind event choices and severing can restore karma
- Earned essence remains a run resource until defeat or victory. Settlement banks it once; explicitly abandoning a journey forfeits it. Gold, karma, damage bonuses and relics reset on each new run. Persistent upgrades do not reset
- Vitality grants +5 maximum HP to each hero per rank; Force grants +2 attack damage per rank; Focus grants +1 maximum focus per rank

## Verification

Run from the project directory:

```sh
godot --headless --path . --script res://selftest.gd
```

In a sandbox with a read-only home, prefix with writable `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` paths.

The self-test covers deterministic seeds, state snapshot isolation, action validation/economy, guard, focus costs, break-before-sever, disabling telegraphs, rewards, camp revival, event affordability and sacrifice, unique relics, karma consequences, defeat settlement, permanent upgrades, save/load, and a naturally played full nine-crossing victory.

## Journey persistence (checkpoint 2)
`save_resume(path)` writes a versioned, object-free Godot Variant snapshot atomically via a temporary file. `load_resume(path)` validates the envelope and restores the complete run, meta, action state and RNG seed/state. Default path is user://ashen_oath_journey.save. Main UI saves after every accepted choice/render refresh, and resumes from the title screen. `resume_selftest.gd` verifies exact next-round continuity.

## Boss counterplay (checkpoint 9)

Milestone Judge alternates Single Verdict and Split Verdict. On even rounds a distinct second intact source marks one fixed hero for 10 damage. Milestone Pale Sun cycles Gathering Light, Zenith Release and Fading Light. Release adds a distinct 12-damage Solar Brand; recovery halves the primary's prepared base damage. Both extra rites are completely stopped by the marked hero's Defend, independently weakened by their own source break and cancelled by its sever. With one source remaining, no additional rite can form. Bellkeeper and ordinary fragments retain the original single-source rules.

The primary `intent` keys remain compatible. Optional `secondary` and `rhythm` are saved in version-1 snapshots. Old pending attacks are restored unchanged; new rhythms start only when the next round is prepared. See `verification/cp9/ENCOUNTER_RULES.md` for exact ordering, rounding and UI fields.
