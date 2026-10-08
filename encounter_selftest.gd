extends SceneTree
## Model-only encounter contract tests. These do not constitute human/visual QA.
const Model = preload("res://model.gd")
var checks: int = 0
var failures: int = 0

func fresh(tier: int = 2, milestone: bool = true, seed_value: int = 413) -> OathModel:
	var m: OathModel = Model.new()
	m.persist_meta = false
	m.meta = {"essence": 0, "upgrades": {"vitality": 0, "force": 0, "focus": 0}, "runs": 0, "wins": 0}
	m.new_run(seed_value)
	m._milestone = milestone
	m.start_battle(tier)
	return m

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	_test_encounter_scope()
	_test_secondary_counterplay()
	_test_exact_sequential_resolution()
	_test_death_and_round_recovery()
	_test_fixed_targets_and_turn_order()
	_test_resume_compatibility()
	_test_permanent_sever()
	print("BOSS COUNTERPLAY MODEL: %d checks; %d failures. Model tests only, not human visual QA." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_encounter_scope() -> void:
	for tier: int in [1, 2, 3]:
		for milestone: bool in [false, true]:
			var m: OathModel = fresh(tier, milestone)
			for turn: int in range(1, 10):
				m.round_number = turn
				m._prepare_intent()
				var expected: int = 2 if milestone and ((tier == 2 and turn % 2 == 0) or (tier == 3 and turn % 3 == 2)) else 1
				check(m.get_intent_attacks().size() == expected, "Only Judge even rounds and Pale Sun release rounds add a second source")
				for key: String in ["name", "part", "damage", "targets", "description"]:
					check(m.intent.has(key), "Legacy primary intent key remains: " + key)
				check(m.intent.has("rhythm") == (tier >= 2 and milestone), "Only milestone Judge and Pale Sun use rhythm metadata")
				if tier == 2 and milestone:
					var split: bool = turn % 2 == 0
					check(m.intent.rhythm.id == ("split" if split else "single"), "Judge rhythm identifies every odd and even round")
					check(m.intent.rhythm.name == ("Split Verdict" if split else "Single Verdict"), "Judge current phase has its readable name")
					check(m.intent.rhythm.next == ("Single Verdict" if split else "Split Verdict"), "Judge always announces the next named phase")
					check(("Next round: " + str(m.intent.rhythm.next)) in m.intent.rhythm.description, "Judge description visibly announces next phase before commitment")
					if not split:
						check("Second Verdict" in m.intent.rhythm.description and "second intact source" in m.intent.rhythm.description and "Defend" in m.intent.rhythm.description, "Odd-round Judge warning explains next secondary and full Defend counterplay")
					check(m.preview_intent().rhythm == m.intent.rhythm and str(m.intent.rhythm.name) in m.intent.description, "Judge rhythm reaches forecast and legacy description UIs")
				if tier == 3 and milestone:
					var ids: Array[String] = ["gathering", "release", "recovery"]
					check(m.intent.rhythm.id == ids[(turn - 1) % 3], "Three named rhythm beats repeat in order")
					if turn % 3 == 1:
						check("Next round: Zenith Release" in m.intent.rhythm.description, "Gathering warns of next round's release")
					if turn % 3 == 0:
						var source: int = int(m.intent.part)
						var normal: int = (26 if source == 1 else (11 if source == 2 else 13)) + maxi(0, turn - 5)
						check(m.intent.damage == int(normal / 2), "Recovery halves familiar primary damage, with exact rounding")
				if expected == 2:
					check(m.intent.part != m.intent.secondary.part, "Secondary has a distinct intact source")
					check(m.intent.secondary.wardable and m.intent.secondary.targets.size() == 1, "Secondary targets exactly one hero and is wardable")
					check(m.intent.secondary.damage == (10 if tier == 2 else 12), "Secondary has fixed modest damage without added escalation")
					check(str(m.heroes[m.intent.secondary.targets[0]].name) in m.intent.secondary.description, "Secondary telegraph names its fixed hero")
					check("Defend" in m.intent.secondary.description and "sever" in m.intent.secondary.description, "Secondary tells player the counterplay")
	var m: OathModel = fresh(3)
	var original: Dictionary = m.intent.duplicate(true)
	var attacks: Array[Dictionary] = m.get_intent_attacks()
	attacks[0].targets.clear()
	attacks[0].name = "Mutated copy"
	check(m.intent == original, "Attacks accessor returns isolated copies")

func _test_secondary_counterplay() -> void:
	for tier: int in [2, 3]:
		var m: OathModel = fresh(tier)
		m.round_number = 2
		m._prepare_intent()
		var primary: int = m.intent.part
		var secondary: int = m.intent.secondary.part
		var target: int = m.intent.secondary.targets[0]
		m.parts[primary].severed = true
		var raw: int = int(m.intent.secondary.damage)
		check(m.preview_action(target, 3, -1).wards == [m.intent.secondary.name] and "WARD" in m.preview_action(target, 3, -1).summary, "Defend preview explicitly shows full ward for the marked hero")
		check(m.preview_action((target + 1) % 3, 3, -1).wards.is_empty(), "Unmarked hero Defend preview does not imply it protects the marked ally")
		check(m.preview_intent().losses[target] == raw, "Severing primary does not suppress the independent second source")
		m.parts[secondary].broken = true
		check(m.preview_intent().losses[target] == int(raw / 2), "Breaking secondary halves only that source")
		m.heroes[target].guard = true
		check(m.preview_intent().losses[target] == 0 and m.preview_intent().focus_losses[target] == 0, "Marked hero's guard wards all secondary HP and focus loss even when broken")
		check(m.preview_intent().attacks[1].status == "warded", "UI receives explicit warded status")
		m.heroes[target].guard = false
		m.heroes[(target + 1) % 3].guard = true
		check(m.preview_intent().losses[target] == int(raw / 2), "A different hero's guard does not ward the mark")
		m.parts[secondary].severed = true
		check(m.preview_intent().status == "cancelled" and m.preview_intent().losses == [0, 0, 0], "Each source can be severed independently; both cancelled produces zero loss")

# Independent oracle intentionally does not call model forecast helpers.
func oracle(m: OathModel) -> Dictionary:
	var hp: Array[int] = []
	var mp: Array[int] = []
	var losses: Array[int] = [0, 0, 0]
	var focus: Array[int] = [0, 0, 0]
	for h: Dictionary in m.heroes:
		hp.append(int(h.hp))
		mp.append(int(h.mp))
	var per_attack: Array = []
	for a: Dictionary in m.get_intent_attacks():
		var part: Dictionary = m.parts[int(a.part)]
		var this_hp: Array[int] = [0, 0, 0]
		var this_mp: Array[int] = [0, 0, 0]
		for t: Variant in a.targets:
			var target: int = int(t)
			if part.severed or hp[target] <= 0 or (a.get("wardable", false) and m.heroes[target].guard):
				continue
			var d: int = maxi(1, int(a.damage) / 2) if part.broken else int(a.damage)
			if m.heroes[target].guard:
				d = maxi(1, (d + 1) / 2)
			var h_loss: int = mini(d, hp[target])
			var m_loss: int = mini(1, mp[target]) if int(a.part) == 2 and not m.heroes[target].guard else 0
			hp[target] -= h_loss
			mp[target] -= m_loss
			losses[target] += h_loss
			focus[target] += m_loss
			this_hp[target] += h_loss
			this_mp[target] += m_loss
		per_attack.append({"losses": this_hp, "focus_losses": this_mp})
	return {"losses": losses, "focus_losses": focus, "hp": hp, "mp": mp, "attacks": per_attack}

func _test_exact_sequential_resolution() -> void:
	var cases: int = 0
	for primary_source: int in range(3):
		for secondary_source: int in range(3):
			for primary_state: int in range(3):
				for secondary_state: int in range(3):
					for guard_mask: int in range(8):
						for low_hp: int in [1, 9, 30]:
							var m: OathModel = fresh(3)
							m.intent = {"name": "Odd primary", "part": primary_source, "damage": 19, "targets": [0, 1, 2], "description": "Test primary", "secondary": {"name": "Odd secondary", "part": secondary_source, "damage": 11, "targets": [0], "description": "Test mark", "wardable": true}}
							m.parts[primary_source].broken = primary_state > 0
							m.parts[primary_source].severed = primary_state == 2
							m.parts[secondary_source].broken = secondary_state > 0
							m.parts[secondary_source].severed = secondary_state == 2
							m.heroes[0].hp = low_hp
							m.heroes[0].mp = 1
							m.heroes[1].mp = 0
							m.heroes[2].mp = 4
							for h: int in range(3):
								m.heroes[h].guard = (guard_mask & (1 << h)) != 0
							var snapshot: Dictionary = m.describe()
							var rng_state: int = m.rng.state
							var p: Dictionary = m.preview_intent()
							var expected: Dictionary = oracle(m)
							check(m.describe() == snapshot and m.rng.state == rng_state, "Forecast never mutates model or consumes RNG")
							check(p.losses == expected.losses and p.focus_losses == expected.focus_losses, "Aggregate exact HP/focus forecast agrees with independent sequential oracle")
							for a: int in range(2):
								check(p.attacks[a].losses == expected.attacks[a].losses and p.attacks[a].focus_losses == expected.attacks[a].focus_losses, "Per-source forecast is exact after earlier source, death, guard, rounding, or focus depletion")
							check(m.end_round(), "Matrix case resolves")
							for h: int in range(3):
								check(m.heroes[h].hp == expected.hp[h], "Resolved HP equals independently expected HP")
								check(m.heroes[h].mp == mini(m.heroes[h].max_mp, expected.mp[h] + 1), "Resolved focus equals expected loss plus the separately defined round regeneration")
							cases += 1
	print("Sequential forecast matrix: ", cases, " cases")

func _test_death_and_round_recovery() -> void:
	var m: OathModel = fresh(3)
	m.intent = {"name": "Fatal first rite", "part": 1, "damage": 19, "targets": [0], "description": "Test primary", "secondary": {"name": "Fixed second rite", "part": 2, "damage": 12, "targets": [0], "description": "Test mark", "wardable": true}}
	m.heroes[0].hp = 9
	var p: Dictionary = m.preview_intent()
	check(p.losses == [9, 0, 0] and p.focus_losses == [0, 0, 0], "First lethal hit caps HP, and dead second target loses no further HP or focus")
	check(p.attacks[1].status == "missed", "Sequential death explicitly marks second rite missed")
	m.end_round()
	check(m.heroes[0].hp == 0 and m.heroes[1].hp == 62 and m.heroes[2].hp == 66, "No mid-round retarget to a different living hero")
	m = fresh(3)
	m.heroes[0].hp = 5
	m.heroes[1].hp = 0
	m.heroes[2].hp = 0
	m.heroes[0].mp = 3
	m.intent = {"name": "Final choir", "part": 2, "damage": 11, "targets": [0], "description": "Test primary", "secondary": {"name": "Unused mark", "part": 1, "damage": 12, "targets": [0], "description": "Test mark", "wardable": true}}
	check(m.preview_intent().losses == [5, 0, 0] and m.preview_intent().focus_losses == [1, 0, 0], "Lethal primary head hit still applies its own single focus drain")
	m.end_round()
	check(m.phase == "defeat" and m.heroes[0].mp == 2, "Party defeat stops before round regeneration")
	m = fresh(2)
	m.run.relics = [Model.RELICS[1].duplicate(true)]
	m.heroes[0].hp = 40
	m.intent = {"name": "Round recovery check", "part": 0, "damage": 11, "targets": [0], "description": "Test primary"}
	check(m.preview_intent().losses[0] == 11, "Forecast reports incoming loss before separate Hollow Bell healing")
	m.end_round()
	check(m.heroes[0].hp == 32, "Hollow Bell still heals only after all prepared attacks")


func _test_fixed_targets_and_turn_order() -> void:
	var a: OathModel = fresh(2, true, 918)
	var b: OathModel = fresh(2, true, 918)
	for turn: int in [2, 4, 6, 8]:
		a.round_number = turn
		b.round_number = turn
		a._prepare_intent()
		b._prepare_intent()
		check(a.intent == b.intent and a.rng.state == b.rng.state, "Same seed and state prepare deterministic primary and secondary")
		check(a.intent.secondary.targets == [((turn / 2) - 1) % 3], "Verdict mark rotates predictably between currently living heroes")
	a = fresh(2)
	a.round_number = 2
	a._prepare_intent()
	var original: Dictionary = a.intent.duplicate(true)
	var marked: int = int(a.intent.secondary.targets[0])
	a.heroes[marked].hp = 0
	check(a.preview_intent().attacks[1].status == "missed", "Already-fallen marked hero is not replaced")
	check(a.intent == original, "Preview of dead target does not retarget prepared intent")
	a.end_round()
	check(a.heroes[marked].hp == 0, "Resolution does not attack or revive fallen marked target")
	# Move the marked hero's Defend before/after the two attacks. Final results agree.
	var outcomes: Array = []
	for order: Array in [[0, 1, 2], [1, 2, 0]]:
		var m: OathModel = fresh(2)
		m.round_number = 2
		m._prepare_intent()
		check(m.intent.secondary.targets == [0], "First verdict openly marks Mara")
		m.parts[int(m.intent.part)].shield = 1
		m.parts[int(m.intent.part)].hp = 1
		var primary: int = int(m.intent.part)
		for hero: int in order:
			check(m.act(hero, 3 if hero == 0 else 0, primary), "Chosen hero order remains available")
		check(m.parts[primary].severed, "Two attack actions break then permanently sever the primary")
		check(m.preview_intent().losses == [0, 0, 0], "Sever plus marked hero Defend avoids both prepared sources")
		m.end_round()
		outcomes.append([m.heroes.duplicate(true), m.parts.duplicate(true), m.boss.duplicate(true), m.intent.duplicate(true)])
	check(outcomes[0] == outcomes[1], "Guard before or after other heroes' attacks gives identical results; no timing trap")
	# Spending the marked hero offensively instead creates the intended cost.
	var m: OathModel = fresh(2)
	m.round_number = 2
	m._prepare_intent()
	var primary: int = int(m.intent.part)
	m.parts[primary].shield = 1
	m.parts[primary].hp = 1
	m.act(1, 0, primary)
	m.act(2, 0, primary)
	m.act(0, 0, int(m.intent.secondary.part))
	check(m.preview_intent().losses[0] == 10, "Ignoring marked hero's guard to attack has a visible, avoidable cost")

func _test_resume_compatibility() -> void:
	for tier: int in [2, 3]:
		var m: OathModel = fresh(tier)
		m.round_number = 2
		m._prepare_intent()
		m.act(0, 3)
		var path: String = "user://counterplay_%d.save" % tier
		check(m.save_resume(path), "New multi-source save succeeds")
		var loaded: OathModel = fresh()
		check(loaded.load_resume(path), "New multi-source save loads")
		check(loaded.describe() == m.describe() and loaded.rng.state == m.rng.state, "Round-trip preserves full intent, rhythm, guard, actions and RNG")
		check(loaded.preview_intent() == m.preview_intent(), "Round-trip preserves exact displayed losses")
		m.end_round()
		loaded.end_round()
		check(loaded.describe() == m.describe() and loaded.rng.state == m.rng.state, "New save continues deterministically across round boundary")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var old: OathModel = fresh(tier)
		old.round_number = 4 if tier == 2 else 1
		old.intent = {"name": "Saved Choir", "part": 2, "damage": 17, "targets": [1], "description": "The exact old visible attack"}
		old.heroes[1].guard = true
		var pending: Dictionary = old.intent.duplicate(true)
		check(old.save_resume(path), "Legacy-shaped pending intent saves under unchanged format")
		check(loaded.load_resume(path), "Legacy-shaped pending intent loads")
		check(loaded.intent == pending and loaded.get_intent_attacks().size() == 1, "Load does not augment or replace the old visible pending attack")
		check(loaded.preview_intent().losses == [0, 9, 0], "Old guarded 17-damage attack retains exact ceil-half damage")
		loaded.end_round()
		check(loaded.heroes[1].hp == 53, "Old saved attack resolves exactly once with old values")
		if tier == 3:
			check(loaded.intent.has("rhythm") and loaded.intent.rhythm.id == "release" and loaded.intent.has("secondary"), "Legacy Pale Sun acquires current rhythm only when preparing the next round")
		else:
			check(not loaded.intent.has("secondary"), "Legacy Judge prepares familiar next odd round")
			loaded.end_round()
			check(loaded.intent.has("secondary"), "Legacy Judge starts second verdict on its next even round")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_permanent_sever() -> void:
	for tier: int in [2, 3]:
		for remaining: int in range(3):
			var m: OathModel = fresh(tier)
			for p: int in range(3):
				m.parts[p].severed = p != remaining
			for turn: int in range(1, 10):
				m.round_number = turn
				m._prepare_intent()
				check(m.get_intent_attacks().size() == 1 and m.intent.part == remaining, "One surviving source never produces a fallback or resurrects a second source")
				if tier == 2:
					check("Second Verdict cannot form" in m.intent.rhythm.description, "Both Judge phases honestly disclose that its lost second source cannot return")
					check(m.intent.rhythm.next == ("Single Verdict" if turn % 2 == 0 else "Split Verdict"), "Judge retains clear phase timing even when the second rite is permanently disabled")
			m.parts[remaining].shield = 0
			m.parts[remaining].broken = true
			m.parts[remaining].hp = 1
			m.act(0, 0, remaining)
			check(m.phase == "reward" and not m.end_round(), "Severing last source ends battle, rather than enabling fallback retaliation")
			m._prepare_intent()
			check(m.intent.is_empty() and m.get_intent_attacks().is_empty(), "Preparing with no intact sources clears any stale attack")
