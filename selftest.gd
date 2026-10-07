extends SceneTree
## Run: godot --headless --path . --script res://selftest.gd

const Model = preload("res://model.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_seed()
	_test_combat()
	_test_choices()
	_test_defeat_and_meta()
	for seed_value: int in [1, 2, 3, 42, 2607, 999]:
		_test_complete_campaign(seed_value)
	print("ASHEN OATH MODEL: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func fresh(seed_value: int = 413) -> OathModel:
	var model: OathModel = Model.new()
	model.persist_meta = false
	model.meta = {"essence": 0, "upgrades": {"vitality": 0, "force": 0, "focus": 0}, "runs": 0, "wins": 0}
	model.new_run(seed_value)
	return model


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func _test_seed() -> void:
	var first: OathModel = fresh()
	var second: OathModel = fresh()
	check(first.campaign == second.campaign, "Same seed creates identical campaign")
	check(first.phase == "map" and first.campaign.size() == 9, "Nine-stage map starts run")
	check(first.heroes.size() == 3 and first.heroes[0].skills.size() == 4, "Three heroes each expose four actions")
	for index: int in [2, 5, 8]:
		check(bool(first.campaign[index].milestone), "Boss milestone at crossing %d" % (index + 1))
	first.start_battle(1)
	second.start_battle(1)
	check(first.intent == second.intent, "Seeded telegraphs are reproducible")
	var snapshot: Dictionary = first.describe()
	snapshot.heroes[0].hp = 1
	check(int(first.heroes[0].hp) != 1, "describe returns an isolated snapshot")


func _test_combat() -> void:
	var model: OathModel = fresh()
	check(model.start_battle(1), "Can start battle")
	check(model.actions_remaining() == 3, "Three actions at round start")
	check(not model.act(-1, 0, 0), "Reject invalid hero")
	check(not model.act(0, 99, 0), "Reject invalid skill")
	check(not model.act(0, 0, 99), "Reject invalid target")
	var hp_before: int = int(model.heroes[0].hp)
	check(model.act(0, 3, -1), "Defend requires no target")
	check(not model.act(0, 0, 0), "Hero cannot act twice")
	check(model.heroes[0].guard, "Defend sets guard")
	check(model.end_round(), "End round resolves attack")
	check(model.round_number == 2 and model.actions_remaining() == 3, "End round refreshes economy")
	check(int(model.heroes[0].hp) == hp_before - 5, "Defend halves tier-one nine-damage telegraph")
	model.heroes[1].mp = 0
	check(not model.act(1, 2, 2), "Focus cost is enforced")
	model.heroes[1].mp = 8
	model.parts[2].shield = 1
	model.parts[2].hp = 1
	check(model.act(1, 1, 2), "Weakness attack accepted")
	check(model.parts[2].broken and not model.parts[2].severed and int(model.parts[2].hp) == 1, "Breaking hit cannot sever in same strike")
	model.intent = {"name": "Choir of Ash", "part": 2, "damage": 20, "targets": [0, 1, 2], "description": "test"}
	check(model.act(2, 0, 2), "Follow-up attack accepted")
	check(model.parts[2].severed, "Follow-up strike severs broken part")
	var saved_hp: Array[int] = []
	for hero: Dictionary in model.heroes:
		saved_hp.append(int(hero.hp))
	model.end_round()
	for index: int in range(3):
		check(int(model.heroes[index].hp) == saved_hp[index], "Sever cancels prepared move for hero %d" % index)
	check(int(model.intent.part) != 2, "Severed move excluded from future intents")
	check(not model.act(0, 0, 2), "Cannot attack severed part")
	model.boss.hp = 1
	check(model.act(0, 0, 0), "Final strike accepted")
	check(model.phase == "reward" and int(model.run.essence) > 0, "Battle victory grants run essence and choices")
	check(int(model.meta.essence) == 0, "Unfinished run earnings do not modify banked essence")
	check(model.choose_reward(0) and model.phase == "map" and int(model.run.node) == 1, "Reward advances campaign once")
	check(not model.choose_reward(0), "Reward cannot be claimed twice")


func _test_choices() -> void:
	var model: OathModel = fresh()
	check(not model.travel(99), "Invalid map choice rejected")
	model._open_event("camp")
	model.heroes[0].hp = 0
	model.heroes[1].mp = 0
	check(model.choose_event(0), "Camp rest accepted")
	check(int(model.heroes[0].hp) == 30 and int(model.heroes[1].mp) == int(model.heroes[1].max_mp), "Camp revives and restores focus")
	model._open_event("event")
	model.run.gold = 0
	check(not model.choose_event(0) and model.phase == "event", "Cannot spend unavailable gold")
	model.heroes[0].hp = 3
	check(model.choose_event(1) and int(model.heroes[0].hp) == 1, "Sacrifice cannot kill a hero")
	check(model.run.relics.size() == 1, "Event grants a relic")
	for index: int in range(6):
		model._grant_relic()
	check(model.run.relics.size() == 5, "Relics never duplicate; overflow grants essence")
	var ruthless: OathModel = fresh()
	ruthless._open_event("event")
	check(ruthless.choose_event(2) and int(ruthless.run.karma) == -2 and int(ruthless.run.gold) == 54, "Seizing supplies exchanges karma for gold")
	ruthless.start_battle(1)
	var kind: OathModel = fresh()
	kind.start_battle(1)
	check(int(ruthless.parts[0].shield) == int(kind.parts[0].shield) + 1, "Negative karma hardens enemy shields")


func _test_defeat_and_meta() -> void:
	var model: OathModel = fresh()
	model.start_battle(1)
	model.run.essence = 30
	for hero: Dictionary in model.heroes:
		hero.hp = 1
	model.end_round()
	check(model.phase == "defeat", "Party wipe ends run")
	check(int(model.meta.essence) == 30 and int(model.meta.runs) == 1, "Defeat banks earned essence once")
	model._settle_run(false)
	check(int(model.meta.essence) == 30, "Settlement is idempotent")
	check(model.buy_upgrade("vitality"), "Banked essence buys permanent upgrade")
	check(int(model.meta.essence) == 18 and int(model.meta.upgrades.vitality) == 1, "Upgrade cost is deducted")
	check(not model.buy_upgrade("unknown"), "Unknown upgrade safely rejected")
	model.new_run(413)
	check(int(model.heroes[0].max_hp) == 83, "Permanent vitality applies to fresh run")
	check(int(model.run.essence) == 0 and int(model.meta.essence) == 18, "Run resources reset while meta persists")
	check(not model.buy_upgrade("force"), "Meta purchases blocked during active run")
	model.meta_path = "user://ashen_oath_test_meta.json"
	check(model.save_meta(), "Meta can save to disk")
	var loaded: OathModel = fresh()
	loaded.meta_path = model.meta_path
	check(loaded.load_meta() and loaded.meta == model.meta, "Meta round-trips through JSON")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(model.meta_path))


func _test_complete_campaign(seed_value: int) -> void:
	var model: OathModel = fresh(seed_value)
	var iterations: int = 0
	while model.phase not in ["victory", "defeat"] and iterations < 200:
		iterations += 1
		if model.phase == "map":
			# Prefer camps/relics to keep a full tactical route healthy.
			var pick: int = 0
			for index: int in range(model.choices.size()):
				if str(model.choices[index].kind) in ["camp", "relic"]:
					pick = index
			model.travel(pick)
		elif model.phase == "battle":
			for hero_index: int in range(3):
				if model.phase != "battle":
					break
				var hero: Dictionary = model.heroes[hero_index]
				if int(hero.hp) <= 0 or bool(hero.acted):
					continue
				var target: int = -1
				for part_index: int in range(3):
					if not bool(model.parts[part_index].severed):
						target = part_index
						break
				var skill: int = 0
				if bool(model.parts[target].broken) and int(hero.mp) >= int(hero.skills[2].cost):
					skill = 2
				elif not bool(model.parts[target].broken) and int(hero.mp) >= int(hero.skills[1].cost):
					skill = 1
				model.act(hero_index, skill, target)
			if model.phase == "battle":
				model.end_round()
		elif model.phase == "reward":
			model.choose_reward(0)
		else:
			model.choose_event(0 if int(model.run.gold) >= 12 else 1)
	check(model.phase == "victory", "Complete seeded nine-stage campaign naturally")
	check(int(model.run.bosses_defeated) == 3, "All three boss milestones defeated")
	check(int(model.run.node) == 9 and int(model.meta.wins) == 1, "Final victory settles completed run")
	check(int(model.meta.essence) == int(model.run.essence), "Victory banks all earned essence")
	print("Full route seed %d: %d turns/choices, %d essence, %d gold" % [seed_value, iterations, int(model.run.essence), int(model.run.gold)])
