class_name OathModel
extends RefCounted
## Pure rules model. All commands return true only when accepted.
## Read MODEL_API.md for the public UI contract. No scenes/assets are required.

const HERO_NAMES: Array[String] = ["Mara", "Ivo", "Sable"]
const UPGRADE_COSTS: Dictionary = {"vitality": 12, "force": 16, "focus": 14}
const RELICS: Array[Dictionary] = [
	{"id": "red_thread", "name": "Red Thread", "description": "+2 damage on every attack"},
	{"id": "hollow_bell", "name": "Hollow Bell", "description": "Restore 3 party HP after each round"},
	{"id": "glass_tooth", "name": "Glass Tooth", "description": "+1 shield damage when exploiting a weakness"},
	{"id": "pilgrim_coin", "name": "Pilgrim Coin", "description": "+8 gold after every battle"},
	{"id": "cinder_heart", "name": "Cinder Heart", "description": "Defend restores 3 extra HP"}
]

var phase: String = "title"
var title: String = "Ashen Oath"
var heroes: Array[Dictionary] = []
var parts: Array[Dictionary] = []
var boss: Dictionary = {}
var intent: Dictionary = {}
var campaign: Array[Dictionary] = []
var choices: Array[Dictionary] = []
var rewards: Array[Dictionary] = []
var event: Dictionary = {}
var run: Dictionary = {}
var meta: Dictionary = {"essence": 0, "upgrades": {"vitality": 0, "force": 0, "focus": 0}, "runs": 0, "wins": 0}
var log: Array[String] = []
var round_number: int = 0
var persist_meta: bool = true
var meta_path: String = "user://ashen_oath_meta.json"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_error: String = ""
var _milestone: bool = false
var _settled: bool = true


func _init() -> void:
	load_meta()


func new_run(seed_value: int = 0) -> bool:
	if not _settled and not run.is_empty():
		_settle_run(false)
	var actual_seed: int = seed_value
	if actual_seed == 0:
		actual_seed = int(Time.get_unix_time_from_system())
	rng.seed = actual_seed
	run = {"seed": actual_seed, "node": 0, "stage": 0, "gold": 30, "karma": 0, "essence": 0, "relics": [], "bosses_defeated": 0, "battles_won": 0, "path": []}
	_settled = false
	_milestone = false
	log.clear()
	parts.clear()
	boss.clear()
	intent.clear()
	rewards.clear()
	event.clear()
	round_number = 0
	_make_heroes()
	_make_campaign()
	_note("The oath is sworn. Nine crossings stand between you and the last sun.")
	_open_map()
	return true


func _skill(skill_name: String, damage_type: String, power: int, cost: int, description: String, break_power: int = 0) -> Dictionary:
	return {"name": skill_name, "type": damage_type, "power": power, "cost": cost, "description": description, "break_power": break_power}


func _make_heroes() -> void:
	heroes.clear()
	var vitality: int = int(meta.upgrades.vitality) * 5
	var focus: int = int(meta.upgrades.focus)
	var guard_skill: Dictionary = _skill("Defend", "guard", 0, 0, "Halve incoming damage this round. Restore 2 focus and 3 HP.")
	heroes.append({"name": "Mara", "role": "Ironbound", "hp": 78 + vitality, "max_hp": 78 + vitality, "mp": 6 + focus, "max_mp": 6 + focus, "acted": false, "guard": false, "skills": [
		_skill("Oathblade", "slash", 14, 0, "14 slash damage. Exploit SLASH weakness to remove 2 shields."),
		_skill("Anvil Blow", "blunt", 12, 2, "12 blunt damage. Remove 1 extra shield.", 1),
		_skill("Sundering Arc", "slash", 24, 3, "24 slash damage. +8 damage against a broken part."), guard_skill.duplicate(true)]})
	heroes.append({"name": "Ivo", "role": "Ash Cantor", "hp": 62 + vitality, "max_hp": 62 + vitality, "mp": 8 + focus, "max_mp": 8 + focus, "acted": false, "guard": false, "skills": [
		_skill("Ash Spark", "arcane", 13, 0, "13 arcane damage. Exploit ARCANE weakness to remove 2 shields."),
		_skill("Hollow Hymn", "arcane", 10, 2, "10 arcane damage. Remove 2 extra shields.", 2),
		_skill("Blood Lantern", "arcane", 21, 3, "21 arcane damage. Restore 7 HP to every living ally."), guard_skill.duplicate(true)]})
	heroes.append({"name": "Sable", "role": "Gloam Scout", "hp": 66 + vitality, "max_hp": 66 + vitality, "mp": 7 + focus, "max_mp": 7 + focus, "acted": false, "guard": false, "skills": [
		_skill("Needle Shot", "pierce", 13, 0, "13 pierce damage. Exploit PIERCE weakness to remove 2 shields."),
		_skill("Raking Hook", "slash", 10, 1, "10 slash damage. Remove 1 extra shield.", 1),
		_skill("Last Mercy", "pierce", 23, 3, "23 pierce damage. +10 damage against a broken part."), guard_skill.duplicate(true)]})


func _make_campaign() -> void:
	campaign.clear()
	var locations: Array[String] = ["The Cinder Causeway", "The Hollow Orchard", "Gate of the Bellkeeper", "The Salt Reliquary", "The Drowned Steps", "Court of the Veiled Judge", "The Sunless Road", "The Last Pilgrim", "Throne of the Pale Sun"]
	for index: int in range(9):
		var tier: int = int(index / 3) + 1
		var options: Array[Dictionary] = []
		var milestone: bool = index % 3 == 2
		if milestone:
			options.append({"name": ["The Bellkeeper", "The Veiled Judge", "The Pale Sun"][tier - 1], "kind": "boss", "description": "Face a sovereign. Sever its limbs to silence its rites.", "tier": tier})
		else:
			var kind_sets: Array[Array] = [["battle", "camp"], ["event", "relic"], ["battle", "event"], ["camp", "relic"]]
			var pair: Array = kind_sets[(index + rng.randi_range(0, 3)) % kind_sets.size()]
			for kind_value: Variant in pair:
				var kind: String = str(kind_value)
				var descriptions: Dictionary = {"battle": "Challenge a god-fragment. Earn gold, essence and a chosen reward.", "camp": "Rest by a dying flame. Recover the party or sharpen your weapons.", "event": "An oath waits to be answered. Choose its price and its consequence.", "relic": "Search a silent shrine for a relic that lasts this run."}
				var labels: Dictionary = {"battle": "Hunt a god-fragment", "camp": "Rest at the ember camp", "event": "Meet the oathless pilgrim", "relic": "Enter the relic shrine"}
				options.append({"name": labels[kind], "kind": kind, "description": descriptions[kind], "tier": tier})
		campaign.append({"index": index, "name": locations[index], "tier": tier, "milestone": milestone, "choices": options, "completed": false, "selected": -1})


func _open_map() -> void:
	phase = "map"
	last_error = ""
	var index: int = int(run.node)
	title = str(campaign[index].name)
	choices.assign(campaign[index].choices)
	event.clear()
	rewards.clear()


func travel(choice_index: int) -> bool:
	if phase != "map" or choice_index < 0 or choice_index >= choices.size():
		return _reject("Choose an available path on the map.")
	var choice: Dictionary = choices[choice_index]
	var node: Dictionary = campaign[int(run.node)]
	node.selected = choice_index
	run.path.append({"node": run.node, "kind": choice.kind, "name": choice.name})
	_note("Crossing %d: %s." % [int(run.node) + 1, choice.name])
	_milestone = str(choice.kind) == "boss"
	if str(choice.kind) in ["boss", "battle"]:
		return start_battle(int(choice.tier))
	_open_event(str(choice.kind))
	return true


func start_battle(tier: int = 1) -> bool:
	if heroes.is_empty():
		return _reject("Begin a run before entering battle.")
	if phase not in ["map", "battle"]:
		return _reject("Finish the current choice before entering battle.")
	tier = clampi(tier, 1, 3)
	phase = "battle"
	round_number = 1
	var max_hp: int = 108 + tier * 38
	if not _milestone:
		max_hp = int(max_hp * 0.77)
	var karma_shields: int = 1 if int(run.karma) < 0 else 0
	var names: Array[String] = ["The Bellkeeper", "The Veiled Judge", "The Pale Sun"]
	var epithets: Array[String] = ["A prayer trapped inside bronze", "Mercy has forgotten its name", "The final light demands a sacrifice"]
	boss = {"name": names[tier - 1] if _milestone else ["Cinder Colossus", "Hollow Adjudicator", "Sunless Remnant"][tier - 1], "title": epithets[tier - 1], "hp": max_hp, "max_hp": max_hp, "tier": tier, "milestone": _milestone}
	title = str(boss.name)
	parts.clear()
	var part_names: Array[String] = ["Rooted Legs", "Offering Arm", "Crowned Head"]
	var levels: Array[String] = ["LOW", "MID", "HIGH"]
	var weaknesses: Array[String] = ["blunt", "slash", "arcane"]
	if tier == 2:
		weaknesses = ["pierce", "arcane", "slash"]
	elif tier == 3:
		weaknesses = ["slash", "pierce", "arcane"]
	var moves: Array[String] = ["Gravewake", "Tithe of Iron", "Choir of Ash"]
	for index: int in range(3):
		var hp: int = 27 + tier * 6 + index * 3
		var shield: int = 2 + tier + karma_shields
		if not _milestone:
			hp -= 6
			shield = maxi(2, shield - 1)
		parts.append({"name": part_names[index], "level": levels[index], "hp": hp, "max_hp": hp, "shield": shield, "max_shield": shield, "armor": tier + 1, "weakness": weaknesses[index], "broken": false, "severed": false, "move": moves[index]})
	for hero: Dictionary in heroes:
		hero.acted = false
		hero.guard = false
		hero.mp = mini(int(hero.max_mp), int(hero.mp) + 2)
	_note("%s rises. Break a part's shields, then strike its exposed flesh to sever it." % boss.name)
	if karma_shields > 0:
		_note("A cruel oath is remembered: negative karma gives every enemy part +1 shield.")
	_prepare_intent()
	last_error = ""
	return true


func act(hero_index: int, skill_index: int, part_index: int = 0) -> bool:
	if phase != "battle":
		return _reject("There is no battle in progress.")
	if hero_index < 0 or hero_index >= heroes.size():
		return _reject("Choose a hero.")
	var hero: Dictionary = heroes[hero_index]
	if int(hero.hp) <= 0 or bool(hero.acted):
		return _reject("That hero cannot act this round.")
	if skill_index < 0 or skill_index >= hero.skills.size():
		return _reject("Choose an available skill.")
	var skill: Dictionary = hero.skills[skill_index]
	if int(hero.mp) < int(skill.cost):
		return _reject("Not enough focus for that skill.")
	if str(skill.type) == "guard":
		hero.acted = true
		hero.guard = true
		hero.mp = mini(int(hero.max_mp), int(hero.mp) + 2)
		var recovery: int = 3 + (3 if has_relic("cinder_heart") else 0)
		hero.hp = mini(int(hero.max_hp), int(hero.hp) + recovery)
		_note("%s defends: incoming damage halved; +2 focus, +%d HP." % [hero.name, recovery])
		last_error = ""
		return true
	if part_index < 0 or part_index >= parts.size() or bool(parts[part_index].severed):
		return _reject("Choose a part that has not been severed.")
	var part: Dictionary = parts[part_index]
	var was_broken: bool = bool(part.broken)
	var weakness_hit: bool = str(skill.type) == str(part.weakness)
	var shield_damage: int = 1 + int(skill.break_power) + (1 if weakness_hit else 0)
	if weakness_hit and has_relic("glass_tooth"):
		shield_damage += 1
	var damage: int = int(skill.power) + int(meta.upgrades.force) * 2 + int(run.get("damage_bonus", 0))
	if has_relic("red_thread"):
		damage += 2
	if was_broken:
		damage = int(damage * 1.35)
		if str(skill.name) == "Sundering Arc":
			damage += 8
		elif str(skill.name) == "Last Mercy":
			damage += 10
	else:
		part.shield = maxi(0, int(part.shield) - shield_damage)
		damage = maxi(1, int(damage * 0.55) - int(part.armor))
		if int(part.shield) == 0:
			part.broken = true
			_note("BREAK! %s is exposed. The next strike can sever it." % part.name)
	hero.mp = int(hero.mp) - int(skill.cost)
	hero.acted = true
	var previous_hp: int = int(part.hp)
	part.hp = maxi(0 if was_broken else 1, previous_hp - damage)
	var dealt: int = previous_hp - int(part.hp)
	boss.hp = maxi(0, int(boss.hp) - damage)
	_note("%s uses %s on %s: %d damage%s." % [hero.name, skill.name, part.name, dealt, " · WEAKNESS" if weakness_hit and not was_broken else ""])
	if was_broken and int(part.hp) <= 0:
		part.severed = true
		var rupture: int = 12 + int(boss.tier) * 3
		boss.hp = maxi(0, int(boss.hp) - rupture)
		run.karma = int(run.karma) + 1
		_note("SEVERED: %s. %s is silenced forever. %d rupture damage." % [part.name, part.move, rupture])
	if str(skill.name) == "Blood Lantern":
		_heal_party(7, false)
		_note("Blood Lantern restores 7 HP to every living ally.")
	last_error = ""
	if int(boss.hp) <= 0 or _intact_parts().is_empty():
		_win_battle()
	return true


func end_round() -> bool:
	if phase != "battle":
		return _reject("There is no round to end.")
	var source_part: int = int(intent.part)
	if bool(parts[source_part].severed):
		_note("%s fails. Its source was severed." % intent.name)
	elif bool(parts[source_part].broken):
		_note("%s is staggered: %s deals half damage." % [parts[source_part].name, intent.name])
		_resolve_intent(0.5)
	else:
		_resolve_intent(1.0)
	if _living_heroes().is_empty():
		phase = "defeat"
		title = "The oath falls silent"
		_note("The party falls. %d essence returns to the ember vault." % int(run.essence))
		_settle_run(false)
		return true
	if has_relic("hollow_bell"):
		_heal_party(3, false)
	round_number += 1
	for hero: Dictionary in heroes:
		hero.acted = false
		hero.guard = false
		hero.mp = mini(int(hero.max_mp), int(hero.mp) + 1)
	_prepare_intent()
	last_error = ""
	return true


func _resolve_intent(multiplier: float) -> void:
	for target_value: Variant in intent.targets:
		var target: int = int(target_value)
		var hero: Dictionary = heroes[target]
		if int(hero.hp) <= 0:
			continue
		var damage: int = maxi(1, int(float(intent.damage) * multiplier))
		if bool(hero.guard):
			damage = maxi(1, int(ceil(float(damage) * 0.5)))
		hero.hp = maxi(0, int(hero.hp) - damage)
		if int(intent.part) == 2 and not bool(hero.guard):
			hero.mp = maxi(0, int(hero.mp) - 1)
		_note("%s strikes %s for %d%s." % [intent.name, hero.name, damage, " (guarded)" if bool(hero.guard) else ""])
		if int(hero.hp) == 0:
			_note("%s has fallen. Rest or a healing reward can revive them." % hero.name)


func _prepare_intent() -> void:
	var available: Array[int] = _intact_parts()
	if available.is_empty():
		return
	var part_index: int = available[(round_number - 1) % available.size()]
	var alive: Array[int] = _living_heroes()
	var targets: Array[int] = []
	var tier: int = int(boss.tier)
	var damage: int = 7 + tier * 2 + maxi(0, round_number - 5)
	var detail: String = "Hits every living hero"
	if part_index == 1:
		targets.append(alive[rng.randi_range(0, alive.size() - 1)])
		damage = 17 + tier * 3 + maxi(0, round_number - 5)
		detail = "Targets %s" % heroes[targets[0]].name
	else:
		targets.assign(alive)
		if part_index == 2:
			damage -= 2
			detail += " and drains 1 focus from unguarded heroes"
	intent = {"name": parts[part_index].move, "part": part_index, "damage": damage, "targets": targets, "description": "%s for %d damage. Break to halve it; sever to cancel it." % [detail, damage]}
	_note("Round %d · %s prepares %s." % [round_number, boss.name, intent.name])


func _win_battle() -> void:
	phase = "reward"
	title = "A god is unmade"
	var gold: int = 18 + int(boss.tier) * 6 + (8 if has_relic("pilgrim_coin") else 0)
	var essence: int = (6 if _milestone else 3) + int(boss.tier) * 2
	run.gold = int(run.gold) + gold
	run.essence = int(run.essence) + essence
	run.battles_won = int(run.battles_won) + 1
	if _milestone:
		run.bosses_defeated = int(run.bosses_defeated) + 1
	_note("%s falls. +%d gold, +%d essence." % [boss.name, gold, essence])
	rewards = [
		{"name": "Mend the oath", "description": "Restore 24 HP and 3 focus to all heroes. Revive fallen allies.", "kind": "heal"},
		{"name": "Take the tribute", "description": "Gain 25 gold and 2 extra essence.", "kind": "gold"},
		{"name": "Claim a relic", "description": "Gain a random unclaimed relic for the rest of this run.", "kind": "relic"}
	]


func choose_reward(index: int) -> bool:
	if phase != "reward" or index < 0 or index >= rewards.size():
		return _reject("Choose one of the offered rewards.")
	var kind: String = str(rewards[index].kind)
	if kind == "heal":
		_heal_party(24, true)
		_restore_focus(3)
	elif kind == "gold":
		run.gold = int(run.gold) + 25
		run.essence = int(run.essence) + 2
	else:
		_grant_relic()
	_note("Reward: %s." % rewards[index].name)
	_advance()
	return true


func _open_event(kind: String) -> void:
	phase = kind
	last_error = ""
	if kind == "camp":
		title = "A flame that remembers"
		event = {"name": title, "description": "The fire bends toward your hands. You may tend your wounds or temper your resolve.", "options": [
			{"name": "Rest together", "description": "Heal 30 HP, restore all focus, and revive fallen allies.", "effect": "rest"},
			{"name": "Temper the blades", "description": "Spend 15 gold. All attacks gain +2 damage this run.", "effect": "sharpen", "cost": 15}
		]}
	elif kind == "relic":
		title = "The shrine of small mercies"
		event = {"name": title, "description": "Something ancient has been left here for the next foolish pilgrim.", "options": [
			{"name": "Take its relic", "description": "Receive a random unclaimed relic. Gain 1 karma.", "effect": "relic"},
			{"name": "Leave an offering", "description": "Spend 10 gold. Gain 5 essence and heal the party by 12 HP.", "effect": "offering", "cost": 10}
		]}
	else:
		title = "The oathless pilgrim"
		event = {"name": title, "description": "A pilgrim carries a bell with no tongue. 'A little warmth,' they ask, 'and I will tell the dark your names.'", "options": [
			{"name": "Offer shelter", "description": "Spend 12 gold. Heal 18 HP, revive fallen allies, and gain 2 karma.", "effect": "shelter", "cost": 12},
			{"name": "Share your ember", "description": "Each living hero loses 8 HP (cannot kill). Gain a relic and 3 essence.", "effect": "sacrifice"},
			{"name": "Seize their supplies", "description": "+24 gold, -2 karma. Negative karma adds 1 shield to enemy parts.", "effect": "seize"}
		]}


func choose_event(index: int) -> bool:
	if phase not in ["camp", "event", "relic"] or index < 0 or index >= event.options.size():
		return _reject("Choose an available event option.")
	var option: Dictionary = event.options[index]
	var cost: int = int(option.get("cost", 0))
	if int(run.gold) < cost:
		return _reject("You need %d gold for that choice." % cost)
	run.gold = int(run.gold) - cost
	match str(option.effect):
		"rest":
			_heal_party(30, true)
			_restore_focus(99)
		"sharpen":
			run["damage_bonus"] = int(run.get("damage_bonus", 0)) + 2
		"relic":
			_grant_relic()
			run.karma = int(run.karma) + 1
		"offering":
			run.essence = int(run.essence) + 5
			_heal_party(12, true)
		"shelter":
			_heal_party(18, true)
			run.karma = int(run.karma) + 2
		"sacrifice":
			for hero: Dictionary in heroes:
				if int(hero.hp) > 0:
					hero.hp = maxi(1, int(hero.hp) - 8)
			_grant_relic()
			run.essence = int(run.essence) + 3
		"seize":
			run.gold = int(run.gold) + 24
			run.karma = int(run.karma) - 2
	_note("%s." % option.name)
	_advance()
	return true


func _advance() -> void:
	campaign[int(run.node)].completed = true
	run.node = int(run.node) + 1
	run.stage = run.node
	if int(run.node) >= campaign.size():
		phase = "victory"
		title = "The dawn belongs to no god"
		run.essence = int(run.essence) + 10
		_note("Nine crossings. Three fallen sovereigns. The oath is fulfilled. +10 essence.")
		_settle_run(true)
	else:
		_open_map()
	last_error = ""


func _heal_party(amount: int, revive: bool) -> void:
	for hero: Dictionary in heroes:
		if revive or int(hero.hp) > 0:
			hero.hp = mini(int(hero.max_hp), int(hero.hp) + amount)


func _restore_focus(amount: int) -> void:
	for hero: Dictionary in heroes:
		hero.mp = mini(int(hero.max_mp), int(hero.mp) + amount)


func _grant_relic() -> void:
	var available: Array[Dictionary] = []
	for relic: Dictionary in RELICS:
		if not has_relic(str(relic.id)):
			available.append(relic)
	if available.is_empty():
		run.essence = int(run.essence) + 4
		_note("Every relic is claimed. Its echo becomes 4 essence.")
		return
	var selected: Dictionary = available[rng.randi_range(0, available.size() - 1)].duplicate(true)
	run.relics.append(selected)
	_note("Relic claimed: %s. %s." % [selected.name, selected.description])


func has_relic(relic_id: String) -> bool:
	for relic_value: Variant in run.get("relics", []):
		if str(relic_value.id) == relic_id:
			return true
	return false


func _living_heroes() -> Array[int]:
	var indices: Array[int] = []
	for index: int in range(heroes.size()):
		if int(heroes[index].hp) > 0:
			indices.append(index)
	return indices


func _intact_parts() -> Array[int]:
	var indices: Array[int] = []
	for index: int in range(parts.size()):
		if not bool(parts[index].severed):
			indices.append(index)
	return indices


func actions_remaining() -> int:
	var count: int = 0
	for hero: Dictionary in heroes:
		if int(hero.hp) > 0 and not bool(hero.acted):
			count += 1
	return count


func _settle_run(won: bool) -> void:
	if _settled:
		return
	meta.essence = int(meta.essence) + int(run.essence)
	meta.runs = int(meta.runs) + 1
	if won:
		meta.wins = int(meta.wins) + 1
	_settled = true
	if persist_meta:
		save_meta()


func upgrade_cost(key: String) -> int:
	if not UPGRADE_COSTS.has(key):
		return -1
	return int(UPGRADE_COSTS[key]) + int(meta.upgrades[key]) * 8


func buy_upgrade(key: String) -> bool:
	if phase not in ["title", "victory", "defeat"]:
		return _reject("Permanent upgrades are available between runs.")
	var cost: int = upgrade_cost(key)
	if cost < 0 or int(meta.upgrades[key]) >= 5:
		return _reject("That upgrade is unavailable or already at its maximum rank.")
	if int(meta.essence) < cost:
		return _reject("Not enough banked essence.")
	meta.essence = int(meta.essence) - cost
	meta.upgrades[key] = int(meta.upgrades[key]) + 1
	_note("Permanent upgrade: %s, rank %d." % [key, int(meta.upgrades[key])])
	if persist_meta:
		save_meta()
	last_error = ""
	return true


func save_meta() -> bool:
	var file: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	if file == null:
		return _reject("The ember vault could not be saved.")
	file.store_string(JSON.stringify({"version": 1, "meta": meta}))
	file.close()
	return true


func load_meta() -> bool:
	if not FileAccess.file_exists(meta_path):
		return false
	var file: FileAccess = FileAccess.open(meta_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("meta", null) is Dictionary:
		return false
	var saved: Dictionary = parsed.meta
	meta.essence = maxi(0, int(saved.get("essence", 0)))
	meta.runs = maxi(0, int(saved.get("runs", 0)))
	meta.wins = maxi(0, int(saved.get("wins", 0)))
	var upgrades: Dictionary = saved.get("upgrades", {}) if saved.get("upgrades", {}) is Dictionary else {}
	for key: String in UPGRADE_COSTS:
		meta.upgrades[key] = clampi(int(upgrades.get(key, 0)), 0, 5)
	return true


func describe() -> Dictionary:
	## Deep snapshot for UI/debugging. The named public variables are live views.
	return {"phase": phase, "title": title, "heroes": heroes, "parts": parts, "boss": boss, "intent": intent, "campaign": campaign, "choices": choices, "rewards": rewards, "event": event, "run": run, "meta": meta, "log": log, "round": round_number, "round_number": round_number, "actions_remaining": actions_remaining(), "last_error": last_error}.duplicate(true)


func _reject(message: String) -> bool:
	last_error = message
	return false


func _note(message: String) -> void:
	log.append(message)
	if log.size() > 120:
		log.pop_front()

func save_resume(path: String = "user://ashen_oath_journey.save") -> bool:
	if run.is_empty():
		return false
	var snapshot: Dictionary=describe()
	snapshot["save_version"]=1
	snapshot["rng_seed"]=str(rng.seed)
	snapshot["rng_state"]=str(rng.state)
	snapshot["milestone"]=_milestone
	snapshot["settled"]=_settled
	var file: FileAccess=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		return false
	file.store_var(snapshot,false)
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))==OK

func load_resume(path: String = "user://ashen_oath_journey.save") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess=FileAccess.open(path,FileAccess.READ)
	if file==null:
		return false
	var value: Variant=file.get_var(false)
	file.close()
	if not value is Dictionary:
		return false
	var s: Dictionary=value
	if s.get("save_version",0)!=1 or s.get("phase","") not in ["map","battle","reward","event","camp","relic","victory","defeat"]:
		return false
	for key in ["heroes","parts","campaign","choices","rewards","log"]:
		if not s.get(key,null) is Array:
			return false
	for key in ["boss","intent","event","run","meta"]:
		if not s.get(key,null) is Dictionary:
			return false
	if s.heroes.size()!=3 or s.campaign.size()!=9 or not s.meta.get("upgrades",null) is Dictionary:
		return false
	phase=s.phase
	title=s.get("title","Ashen Oath")
	heroes.assign(s.heroes)
	parts.assign(s.parts)
	campaign.assign(s.campaign)
	choices.assign(s.choices)
	rewards.assign(s.rewards)
	log.assign(s.log)
	boss=s.boss
	intent=s.intent
	event=s.event
	run=s.run
	meta=s.meta
	round_number=int(s.get("round_number",1))
	_milestone=bool(s.get("milestone",false))
	_settled=bool(s.get("settled",false))
	rng.seed=int(s.get("rng_seed","0"))
	rng.state=int(s.get("rng_state","0"))
	last_error=""
	return true
