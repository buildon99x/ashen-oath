class_name OathModel
extends RefCounted
## Pure rules model. All commands return true only when accepted.
## Read MODEL_API.md for the public UI contract. No scenes/assets are required.

const HERO_NAMES: Array[String] = ["Mara", "Ivo", "Sable"]
const UPGRADE_COSTS: Dictionary = {"vitality": 12, "force": 16, "focus": 14}
const LegacyContent = preload("res://legacy/legacy_content.gd")
const RELICS: Array[Dictionary] = LegacyContent.RELICS

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

# Every version-2 file contains BOTH the vault and its exact journey. A later
# UI save is redundant for settlement/purchase/new-cycle durability, not part
# of the transaction. Status is separate from command acceptance/last_error.
const DEFAULT_META_PATH: String = "user://ashen_oath_meta.json"
const DEFAULT_RESUME_PATH: String = "user://ashen_oath_journey.save"
const MAX_SAVE_BYTES: int = 4194304
var save_status: String = "idle"
var save_message: String = ""
var recovery_status: String = "none"
var recovery_message: String = ""
var _save_revision: int = 0
var _resume_path: String = DEFAULT_RESUME_PATH
var _unrestored_journey: Dictionary = {}


func _init() -> void:
	load_meta()


func new_run(seed_value: int = 0) -> bool:
	if (not _settled and not run.is_empty()) or (run.is_empty() and not _unrestored_journey.is_empty() and not bool(_unrestored_journey.settled)):
		# Abandoning is not a defeat: do not turn repeatable opening shrines into
		# free permanent growth. Only an actual defeat or victory banks earnings.
		meta.runs = int(meta.runs) + 1
		_settled = true
	var actual_seed: int = seed_value
	if actual_seed == 0:
		actual_seed = int(Time.get_unix_time_from_system())
	rng.seed = actual_seed
	_unrestored_journey.clear()
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
	if persist_meta:
		save_meta()
	return true


func _make_heroes() -> void:
	heroes.assign(LegacyContent.make_heroes(meta.upgrades))

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
		_note("%s defends: normal attacks halved, wardable rites cancelled; +2 focus, +%d HP." % [hero.name, recovery])
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
	# Resolve the same sequential forecast that the UI shows. Prepared targets
	# never change, even when an earlier attack kills a later attack's target.
	_resolve_attacks()
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


func get_intent_attacks() -> Array[Dictionary]:
	## Ordered copies; legacy saves still represent exactly one pending attack.
	var attacks: Array[Dictionary] = []
	if intent.is_empty():
		return attacks
	var primary: Dictionary = intent.duplicate(true)
	primary.erase("secondary")
	primary.erase("rhythm")
	primary["wardable"] = bool(primary.get("wardable", false))
	attacks.append(primary)
	if intent.get("secondary", null) is Dictionary and not intent.secondary.is_empty():
		attacks.append(intent.secondary.duplicate(true))
	return attacks


func preview_intent() -> Dictionary:
	## Exact, read-only sequential HP/focus loss; no recovery or next-round gains.
	var losses: Array[int] = [0, 0, 0]
	var focus_losses: Array[int] = [0, 0, 0]
	var result: Dictionary = {"status": "none", "losses": losses, "focus_losses": focus_losses, "source": "", "description": "No attack is prepared.", "attacks": [], "rhythm": intent.get("rhythm", {}).duplicate(true)}
	if phase != "battle" or intent.is_empty():
		return result
	var remaining_hp: Array[int] = []
	var remaining_focus: Array[int] = []
	for hero: Dictionary in heroes:
		remaining_hp.append(int(hero.hp))
		remaining_focus.append(int(hero.mp))
	var descriptions: Array[String] = []
	var all_cancelled: bool = true
	var any_warded: bool = false
	var any_damage: bool = false
	var any_full_damage: bool = false
	for attack: Dictionary in get_intent_attacks():
		var part_index: int = int(attack.part)
		var source: Dictionary = parts[part_index]
		var source_status: String = "cancelled" if source.severed else ("staggered" if source.broken else "incoming")
		var wardable: bool = bool(attack.get("wardable", false))
		var attack_losses: Array[int] = [0, 0, 0]
		var attack_focus_losses: Array[int] = [0, 0, 0]
		var lines: Array[String] = []
		var living_targets: int = 0
		var warded_targets: int = 0
		for target_value: Variant in attack.targets:
			var target: int = int(target_value)
			var hero: Dictionary = heroes[target]
			if remaining_hp[target] <= 0 or source_status == "cancelled":
				continue
			living_targets += 1
			if wardable and bool(hero.guard):
				warded_targets += 1
				lines.append("%s wards this rite: no damage or focus loss" % hero.name)
				continue
			var damage: int = maxi(1, int(float(attack.damage) * (0.5 if source_status == "staggered" else 1.0)))
			if bool(hero.guard):
				damage = maxi(1, int(ceil(float(damage) * 0.5)))
			var hp_loss: int = mini(remaining_hp[target], damage)
			var focus_loss: int = mini(1, remaining_focus[target]) if part_index == 2 and not bool(hero.guard) else 0
			remaining_hp[target] -= hp_loss
			remaining_focus[target] -= focus_loss
			attack_losses[target] += hp_loss
			attack_focus_losses[target] += focus_loss
			losses[target] += hp_loss
			focus_losses[target] += focus_loss
			any_damage = any_damage or hp_loss > 0
			any_full_damage = any_full_damage or (hp_loss > 0 and source_status == "incoming")
			lines.append("%s -%d HP%s%s" % [hero.name, hp_loss, " / -%d focus" % focus_loss if focus_loss > 0 else "", " / guarded" if hero.guard else ""])
		var status: String = source_status
		if source_status == "cancelled":
			lines.append("Source severed. This rite is cancelled.")
		elif living_targets == 0:
			status = "missed"
			lines.append("Its fixed target has fallen. This rite will not retarget.")
		elif warded_targets == living_targets:
			status = "warded"
		all_cancelled = all_cancelled and status == "cancelled"
		any_warded = any_warded or status == "warded"
		var counterplay: String = "Break %s to halve; sever it to cancel." % source.name
		if wardable:
			var target_names: Array[String] = []
			for target_value: Variant in attack.targets:
				target_names.append(str(heroes[int(target_value)].name))
			counterplay = "%s: Defend cancels this rite. %s" % [", ".join(target_names), counterplay]
		else:
			counterplay += " Defend halves damage to that hero."
		var detail: String = "\n".join(lines)
		result.attacks.append({"name": str(attack.name), "part": part_index, "source": str(source.name), "source_status": source_status, "status": status, "wardable": wardable, "targets": attack.targets.duplicate(), "damage": int(attack.damage), "losses": attack_losses, "focus_losses": attack_focus_losses, "description": detail, "counterplay": counterplay})
		descriptions.append("%s: %s" % [attack.name, detail])
	result.status = "incoming" if any_full_damage else ("staggered" if any_damage else ("cancelled" if all_cancelled else ("warded" if any_warded else "missed")))
	result.source = str(result.attacks[0].source)
	result.description = result.attacks[0].description if result.attacks.size() == 1 else "\n".join(descriptions)
	return result


func preview_action(hero_index: int, skill_index: int, part_index: int) -> Dictionary:
	## Forecast only. Never spend focus, consume RNG, or modify a target.
	if phase != "battle" or hero_index < 0 or hero_index >= heroes.size():
		return {"valid": false}
	var hero: Dictionary = heroes[hero_index]
	if skill_index < 0 or skill_index >= hero.skills.size():
		return {"valid": false}
	var skill: Dictionary = hero.skills[skill_index]
	var usable: bool = hero.hp > 0 and not hero.acted and hero.mp >= skill.cost
	if skill.type == "guard":
		var recovery: int = mini(int(hero.max_hp) - int(hero.hp), 3 + (3 if has_relic("cinder_heart") else 0))
		var wards: Array[String] = []
		for attack: Dictionary in get_intent_attacks():
			if bool(attack.get("wardable", false)) and hero_index in attack.targets and not bool(parts[int(attack.part)].severed):
				wards.append(str(attack.name))
		var summary: String = ("WARD RITE + HALVE / +%d HP" if not wards.is_empty() else "HALVE INCOMING / +%d HP") % recovery
		return {"valid": usable, "guard": true, "heal": recovery, "focus": mini(2, int(hero.max_mp) - int(hero.mp)), "wards": wards, "summary": summary}
	if part_index < 0 or part_index >= parts.size() or parts[part_index].severed:
		return {"valid": false}
	var part: Dictionary = parts[part_index]
	var weakness: bool = skill.type == part.weakness
	var shield_hit: int = 1 + int(skill.break_power) + (1 if weakness else 0) + (1 if weakness and has_relic("glass_tooth") else 0)
	var damage: int = int(skill.power) + int(meta.upgrades.force) * 2 + int(run.get("damage_bonus", 0)) + (2 if has_relic("red_thread") else 0)
	if part.broken:
		damage = int(damage * 1.35)
		if skill.name == "Sundering Arc": damage += 8
		elif skill.name == "Last Mercy": damage += 10
	else:
		damage = maxi(1, int(damage * 0.55) - int(part.armor))
	var remaining: int = maxi(0 if part.broken else 1, int(part.hp) - damage)
	var severs: bool = part.broken and remaining == 0
	var breaks: bool = not part.broken and int(part.shield) <= shield_hit
	var shield_loss: int = 0 if part.broken else mini(int(part.shield), shield_hit)
	var titan_damage: int = mini(int(boss.hp), damage + (12 + int(boss.tier) * 3 if severs else 0))
	var outcome: String = "SEVER" if severs else ("BREAK" if breaks else ("EXPOSED" if part.broken else "-%d SHIELD" % shield_loss))
	return {"valid": usable, "guard": false, "damage": int(part.hp) - remaining, "titan_damage": titan_damage, "shield_loss": shield_loss, "breaks": breaks, "severs": severs, "weakness": weakness, "summary": "%d DMG / %s" % [int(part.hp) - remaining, outcome]}


func _resolve_attacks() -> void:
	var forecast: Dictionary = preview_intent()
	for attack: Dictionary in forecast.attacks:
		if attack.status == "cancelled":
			_note("%s fails. Its source was severed." % attack.name)
			continue
		if attack.status == "missed":
			_note("%s fails. Its fixed target has fallen; it does not retarget." % attack.name)
			continue
		if attack.source_status == "staggered":
			_note("%s is staggered: %s deals half damage." % [attack.source, attack.name])
		for target: int in range(heroes.size()):
			var hero: Dictionary = heroes[target]
			var damage: int = int(attack.losses[target])
			if damage == 0:
				if bool(attack.wardable) and target in attack.targets and bool(hero.guard) and int(hero.hp) > 0:
					_note("%s wards %s completely." % [hero.name, attack.name])
				continue
			hero.hp = int(hero.hp) - damage
			hero.mp = int(hero.mp) - int(attack.focus_losses[target])
			_note("%s strikes %s for %d%s." % [attack.name, hero.name, damage, " (guarded)" if bool(hero.guard) else ""])
			if int(hero.hp) == 0:
				_note("%s has fallen. Rest or a healing reward can revive them." % hero.name)


func _prepare_intent() -> void:
	var available: Array[int] = _intact_parts()
	var alive: Array[int] = _living_heroes()
	if available.is_empty() or alive.is_empty():
		intent.clear()
		return
	var part_index: int = available[(round_number - 1) % available.size()]
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
	var rhythm: Dictionary = {}
	var secondary_name: String = ""
	var secondary_damage: int = 0
	var secondary_count: int = 0
	if bool(boss.get("milestone", false)) and tier == 2:
		var split: bool = round_number % 2 == 0
		var verdict_description: String = "Second Verdict marks one hero, who can Defend to cancel that rite. Next round: Single Verdict." if split else "One source acts. Next round: Split Verdict adds Second Verdict from a second intact source if one remains. Its marked hero can Defend to cancel that rite."
		if available.size() < 2:
			verdict_description = "Only one source remains. Second Verdict cannot form. Next round: Single Verdict." if split else "Next round: Split Verdict, but only one source remains. Second Verdict cannot form."
		rhythm = {"id": "split" if split else "single", "name": "Split Verdict" if split else "Single Verdict", "description": verdict_description, "next": "Single Verdict" if split else "Split Verdict"}
		if split:
			secondary_name = "Second Verdict"
			secondary_damage = 10
			secondary_count = int(round_number / 2) - 1
	elif bool(boss.get("milestone", false)) and tier == 3:
		var beat: int = (round_number - 1) % 3
		var names: Array[String] = ["Gathering Light", "Zenith Release", "Fading Light"]
		var ids: Array[String] = ["gathering", "release", "recovery"]
		var descriptions: Array[String] = [
			"Next round: Zenith Release adds a second source if one remains. Its marked hero can Defend to cancel it.",
			"Two sources can strike. The hero marked by Solar Brand can Defend to cancel that rite.",
			"Recovery: one source attacks at half its usual strength. Next round: Gathering Light."]
		if available.size() < 2:
			descriptions[0] = "Next round: Zenith Release. Only one source remains, so no second rite can form."
			descriptions[1] = "Only one source remains. Solar Brand cannot form. Next round: Fading Light."
		rhythm = {"id": ids[beat], "name": names[beat], "description": descriptions[beat], "next": names[(beat + 1) % 3]}
		if beat == 1:
			secondary_name = "Solar Brand"
			secondary_damage = 12
			secondary_count = int((round_number - 2) / 3)
		elif beat == 2:
			damage = maxi(1, int(damage / 2))
	intent = {"name": parts[part_index].move, "part": part_index, "damage": damage, "targets": targets, "description": "%s for %d damage. Break to halve it; sever to cancel it." % [detail, damage]}
	if not rhythm.is_empty():
		intent["rhythm"] = rhythm
		intent.description += " " + str(rhythm.name) + ": " + str(rhythm.description)
	if not secondary_name.is_empty() and available.size() > 1:
		var secondary_part: int = available[(available.find(part_index) + 1) % available.size()]
		var secondary_target: int = alive[secondary_count % alive.size()]
		var focus_detail: String = " and drains 1 focus" if secondary_part == 2 else ""
		var description: String = "Targets %s for %d damage%s. %s can Defend to cancel this rite. Break %s to halve it; sever to cancel it." % [heroes[secondary_target].name, secondary_damage, focus_detail, heroes[secondary_target].name, parts[secondary_part].name]
		intent["secondary"] = {"name": secondary_name, "part": secondary_part, "damage": secondary_damage, "targets": [secondary_target], "description": description, "wardable": true}
		intent.description += " Second source: %s from %s. %s" % [secondary_name, parts[secondary_part].name, description]
	elif not secondary_name.is_empty():
		intent.description += " No second source remains; the additional rite is silenced."
	var prepared: String = str(intent.name)
	if intent.has("secondary"):
		prepared += " + " + str(intent.secondary.name)
	if not rhythm.is_empty():
		prepared = str(rhythm.name) + " / " + prepared
	_note("Round %d · %s prepares %s." % [round_number, boss.name, prepared])


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
	if run.relics.size() >= RELICS.size():
		rewards[2].name = "Keep the relic echo"
		rewards[2].description = "All relics are claimed. Gain 4 unbanked ash instead."


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
	if run.relics.size() >= RELICS.size():
		for option: Dictionary in event.options:
			if option.effect == "relic":
				option.name = "Receive the relic echo"
				option.description = "All relics are claimed. Gain 4 unbanked ash and 1 karma."
			elif option.effect == "sacrifice":
				option.description = "Each living hero loses 8 HP (cannot kill). All relics claimed: gain 7 unbanked ash instead."


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
	if phase not in ["title", "victory", "defeat"] or (run.is_empty() and not _unrestored_journey.is_empty() and not bool(_unrestored_journey.settled)):
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
	return _save_checkpoint(meta_path)


func load_meta() -> bool:
	var records: Array[Dictionary] = _records_at(meta_path)
	# The default pair is one profile. Explicit custom vaults remain isolated.
	if meta_path == DEFAULT_META_PATH or _resume_path != DEFAULT_RESUME_PATH:
		records.append_array(_records_at(_resume_path))
	var record: Dictionary = _latest_record(records)
	if record.is_empty():
		if _has_save_file(meta_path):
			_recovery("corrupt", "The ember vault could not be read. No saved progress was overwritten.")
		return false
	if _revision_conflict(records, int(record.revision)):
		_recovery("conflict", "Two saves disagree at the same checkpoint. Automatic recovery stopped; no save files were changed.")
		return false
	if int(record.version) == 1:
		var vault: Dictionary = _latest_record(_records_at(meta_path))
		var journey: Dictionary = _latest_record(_records_at(_resume_path)) if meta_path == DEFAULT_META_PATH or _resume_path != DEFAULT_RESUME_PATH else {}
		if not journey.is_empty() and not journey.journey.is_empty():
			var relation: int = _legacy_relation(vault.meta, journey.meta) if not vault.is_empty() else -1
			if relation in [0, -1]:
				record = journey
			elif relation == 1 and bool(journey.journey.settled):
				record = journey.duplicate(true)
				record.meta = vault.meta.duplicate(true)
				record.journey.meta = vault.meta.duplicate(true)
	meta = record.meta.duplicate(true)
	_unrestored_journey = record.journey.duplicate(true)
	_save_revision = int(record.revision)
	_report_recovered_file(record, records)
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

func save_resume(path: String = DEFAULT_RESUME_PATH) -> bool:
	if run.is_empty():
		return false
	_resume_path = path
	return _save_checkpoint(path)


func load_resume(path: String = DEFAULT_RESUME_PATH) -> bool:
	# An explicit missing snapshot is not a request to resume another file.
	if path != DEFAULT_RESUME_PATH and not _has_save_file(path):
		return false
	_resume_path = path
	var records: Array[Dictionary] = _records_at(meta_path)
	records.append_array(_records_at(path))
	var newest: Dictionary = _latest_record(records)
	if newest.is_empty():
		if _has_save_file(path):
			_recovery("corrupt", "The saved journey is damaged and could not be resumed. The vault was kept.")
		return false
	if int(newest.version) == 2:
		# The entire latest transaction wins, including a smaller post-purchase
		# balance or an empty journey. Never merge/max individual currencies.
		if _revision_conflict(records, int(newest.revision)):
			_recovery("conflict", "Two saves disagree at the same checkpoint. Automatic recovery stopped; no save files were changed.")
			return false
		meta = newest.meta.duplicate(true)
		_save_revision = int(newest.revision)
		_report_recovered_file(newest, records)
		if newest.journey.is_empty():
			_clear_journey()
			return false
		_restore_journey(newest.journey)
		return true
	# Version 1 had no transaction number. Runs/wins and upgrade ranks are
	# monotonic evidence; Ash is NOT (purchases spend it). A newer standalone
	# vault cannot safely resume an older unfinished run: it may be settled or
	# abandoned already. Keep its balance and retire that stale snapshot.
	var vault: Dictionary = _latest_record(_records_at(meta_path))
	var journey: Dictionary = _latest_record(_records_at(path))
	if journey.is_empty() or journey.journey.is_empty():
		if _has_save_file(path):
			_recovery("corrupt", "The saved journey is damaged and could not be resumed. The vault was kept.")
		return false
	var snapshot: Dictionary = journey.journey.duplicate(true)
	if not vault.is_empty():
		var relation: int = _legacy_relation(vault.meta, journey.meta)
		if relation == 2 or (relation == 1 and not bool(snapshot.settled)):
			meta = vault.meta.duplicate(true)
			_clear_journey()
			_recovery("legacy_reconciled", "Recovered the newer ember vault. An older or conflicting journey was retired to prevent banking it twice.")
			return false
		if relation == 1:
			snapshot.meta = vault.meta.duplicate(true)
			_recovery("legacy_reconciled", "Recovered the newer ember vault, including its purchased upgrades.")
		elif relation == -1:
			_recovery("legacy_reconciled", "Recovered the newer journey and its matching ember vault.")
	_restore_journey(snapshot)
	_report_recovered_file(journey, records)
	return true


func clear_recovery_notice() -> void:
	recovery_status = "none"
	recovery_message = ""

func retry_save() -> bool:
	# Repair both copies from one coherent state after a transient I/O failure.
	# Revision/conflict guards still apply; this is never a force overwrite.
	if not _save_checkpoint(meta_path): return false
	return true if _resume_path == meta_path else _save_checkpoint(_resume_path)


func _recovery(status: String, message: String) -> void:
	recovery_status = status
	recovery_message = message


func _save_failed(message: String) -> bool:
	save_status = "error"
	save_message = message + " Changes are still in memory; saving must succeed before closing."
	return false


func _journey_snapshot() -> Dictionary:
	if run.is_empty():
		# load_meta remains profile-only. Saving that profile must not silently
		# erase the coherent journey it has not restored into live state yet.
		var pending: Dictionary = _unrestored_journey.duplicate(true)
		if not pending.is_empty():
			pending.meta = meta.duplicate(true)
		return pending
	var snapshot: Dictionary = describe()
	snapshot["save_version"] = 1
	snapshot["rng_seed"] = str(rng.seed)
	snapshot["rng_state"] = str(rng.state)
	snapshot["milestone"] = _milestone
	snapshot["settled"] = _settled
	return snapshot


func _save_checkpoint(path: String) -> bool:
	var records: Array[Dictionary] = _records_at(meta_path)
	if _resume_path != meta_path:
		records.append_array(_records_at(_resume_path))
	var revision: int = _save_revision
	for record: Dictionary in records:
		revision = maxi(revision, int(record.revision))
	if _revision_conflict(records, revision):
		_recovery("conflict", "Two saves disagree at the same checkpoint. Automatic recovery stopped; no save files were changed.")
		return _save_failed("The save data failed validation.")
	if revision > _save_revision:
		_recovery("conflict", "A newer checkpoint was saved by another window. Reload the saved journey before retrying.")
		return _save_failed("A newer checkpoint exists. Reload it before retrying.")
	var transaction: Dictionary = {"version": 2, "revision": revision + 1, "meta": meta.duplicate(true), "journey": _journey_snapshot()}
	if not _valid_transaction(transaction):
		return _save_failed("The save data failed validation.")
	var bytes: PackedByteArray = var_to_bytes(transaction)
	var envelope: Dictionary = {"version": 2, "payload": Marshalls.raw_to_base64(bytes), "sha256": _digest(bytes)}
	var encoded: PackedByteArray = JSON.stringify(envelope).to_utf8_buffer()
	if not _write_checked(path + ".tmp", encoded):
		return _save_failed("The checkpoint could not be written.")
	# Copy rather than move the previous good primary: an interrupted backup
	# rotation never removes the only committed checkpoint. Do not replace a
	# good backup with a corrupt primary. Uncommitted .tmp files are ignored.
	if not _read_record(path).is_empty():
		var previous: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not _write_checked(path + ".bak.tmp", previous) or not _replace_file(path + ".bak.tmp", path + ".bak"):
			return _save_failed("The previous checkpoint could not be protected.")
	if not _replace_file(path + ".tmp", path):
		return _save_failed("The checkpoint could not be committed.")
	_save_revision = revision + 1
	save_status = "saved"
	save_message = "Journey and ember vault saved together."
	return true


func _write_checked(path: String, bytes: PackedByteArray) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK and FileAccess.get_file_as_bytes(path) == bytes and not _read_record(path).is_empty()


func _replace_file(source: String, destination: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination)) == OK


func _digest(bytes: PackedByteArray) -> String:
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _has_save_file(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


func _records_at(path: String) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for source: String in [path, path + ".bak"]:
		var record: Dictionary = _read_record(source)
		if not record.is_empty():
			record["source"] = source
			record["backup"] = source != path
			record["damaged_primary"] = source != path and _read_record(path).is_empty()
			records.append(record)
	return records


func _latest_record(records: Array[Dictionary]) -> Dictionary:
	var latest: Dictionary = {}
	for record: Dictionary in records:
		if latest.is_empty() or int(record.version) > int(latest.version) or (int(record.version) == int(latest.version) and int(record.revision) > int(latest.revision)):
			latest = record
	return latest


func _revision_conflict(records: Array[Dictionary], revision: int) -> bool:
	var digest: String = ""
	for record: Dictionary in records:
		if int(record.version) != 2 or int(record.revision) != revision:
			continue
		if not digest.is_empty() and digest != record.digest:
			return true
		digest = record.digest
	return false


func _report_recovered_file(selected: Dictionary, records: Array[Dictionary]) -> void:
	var recovered: bool = bool(selected.get("backup", false))
	for record: Dictionary in records:
		recovered = recovered or bool(record.get("damaged_primary", false))
	for path: String in [meta_path, _resume_path]:
		recovered = recovered or (FileAccess.file_exists(path) and _read_record(path).is_empty())
	if recovered:
		_recovery("recovered", "A damaged or interrupted save was recovered from a complete checkpoint. Some recent actions may need to be repeated.")


func _read_record(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var length: int = file.get_length()
	if length < 4 or length > MAX_SAVE_BYTES:
		file.close()
		return {}
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		return {}
	if bytes[0] == 123: # JSON object: legacy vault or checksummed v2 bundle.
		var json: JSON = JSON.new()
		if json.parse(bytes.get_string_from_utf8()) != OK:
			return {}
		var parsed: Variant = json.data
		if not parsed is Dictionary:
			return {}
		if parsed.get("version", 1) == 2:
			if not parsed.get("payload", null) is String or not parsed.get("sha256", null) is String:
				return {}
			var payload: PackedByteArray = Marshalls.base64_to_raw(parsed.payload)
			if payload.is_empty() or _digest(payload) != parsed.sha256:
				return {}
			var transaction: Variant = bytes_to_var(payload)
			if not _valid_transaction(transaction):
				return {}
			transaction["digest"] = parsed.sha256
			return transaction
		if parsed.get("version", 1) == 1 and _valid_meta(parsed.get("meta", null)):
			return {"version": 1, "revision": 0, "meta": _normalized_meta(parsed.meta), "journey": {}, "digest": ""}
		return {}
	# FileAccess.store_var's length-prefixed, object-free version-1 format.
	if bytes.decode_u32(0) != bytes.size() - 4:
		return {}
	var snapshot: Variant = bytes_to_var(bytes.slice(4))
	if not _valid_journey(snapshot):
		return {}
	return {"version": 1, "revision": 0, "meta": snapshot.meta, "journey": snapshot, "digest": ""}


func _legacy_relation(vault: Dictionary, journey_meta: Dictionary) -> int:
	if vault == journey_meta:
		return 0
	var ahead: bool = false
	var behind: bool = false
	for key: String in ["runs", "wins"]:
		ahead = ahead or int(vault[key]) > int(journey_meta[key])
		behind = behind or int(vault[key]) < int(journey_meta[key])
	for key: String in UPGRADE_COSTS:
		ahead = ahead or int(vault.upgrades[key]) > int(journey_meta.upgrades[key])
		behind = behind or int(vault.upgrades[key]) < int(journey_meta.upgrades[key])
	if ahead and not behind:
		return 1
	if behind and not ahead:
		return -1
	return 2 # No trustworthy ordering, including a balance-only discrepancy.


func _restore_journey(snapshot: Dictionary) -> void:
	var s: Dictionary = snapshot.duplicate(true)
	_unrestored_journey.clear()
	phase = s.phase
	title = s.title
	heroes.assign(s.heroes)
	parts.assign(s.parts)
	campaign.assign(s.campaign)
	choices.assign(s.choices)
	rewards.assign(s.rewards)
	log.assign(s.log)
	boss = s.boss
	intent = s.intent
	event = s.event
	run = s.run
	meta = s.meta
	round_number = int(s.round_number)
	_milestone = bool(s.milestone)
	_settled = bool(s.settled)
	rng.seed = int(s.rng_seed)
	rng.state = int(s.rng_state)
	last_error = ""


func _clear_journey() -> void:
	_unrestored_journey.clear()
	phase = "title"
	title = "Ashen Oath"
	heroes.clear()
	parts.clear()
	campaign.clear()
	choices.clear()
	rewards.clear()
	log.clear()
	boss.clear()
	intent.clear()
	event.clear()
	run.clear()
	round_number = 0
	_milestone = false
	_settled = true
	last_error = ""


func _whole(value: Variant, low: int = 0, high: int = 9223372036854775807) -> bool:
	if value is int:
		return value >= low and value <= high
	return value is float and is_finite(value) and value == floor(value) and value >= low and value <= high


func _normalized_meta(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {"essence": int(value.essence), "runs": int(value.runs), "wins": int(value.wins), "upgrades": {}}
	for key: String in UPGRADE_COSTS:
		normalized.upgrades[key] = int(value.upgrades[key])
	return normalized


func _valid_meta(value: Variant) -> bool:
	if not value is Dictionary or not value.get("upgrades", null) is Dictionary:
		return false
	for key: String in ["essence", "runs", "wins"]:
		if not _whole(value.get(key, null)):
			return false
	if int(value.wins) > int(value.runs):
		return false
	for key: String in UPGRADE_COSTS:
		if not _whole(value.upgrades.get(key, null), 0, 5):
			return false
	return true


func _valid_transaction(value: Variant) -> bool:
	if not value is Dictionary or value.get("version", 0) != 2 or not _whole(value.get("revision", null), 1):
		return false
	if not _valid_meta(value.get("meta", null)) or not value.get("journey", null) is Dictionary:
		return false
	return value.journey.is_empty() or (_valid_journey(value.journey) and value.journey.meta == value.meta)


func _named(value: Variant) -> bool:
	return value is Dictionary and value.get("name", null) is String


func _valid_option(value: Variant) -> bool:
	return _named(value) and value.get("description", null) is String and value.get("kind", "") in ["battle", "boss", "camp", "event", "relic"] and _whole(value.get("tier", null), 1, 3)


func _valid_attack(value: Variant) -> bool:
	if not _named(value) or not _whole(value.get("part", null), 0, 2) or not _whole(value.get("damage", null)) or not value.get("targets", null) is Array:
		return false
	if value.targets.is_empty() or value.targets.size() > 3:
		return false
	for target: Variant in value.targets:
		if not _whole(target, 0, 2):
			return false
	return not value.has("wardable") or value.wardable is bool


func _valid_journey(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var s: Dictionary = value
	if s.get("save_version", 0) != 1 or s.get("phase", "") not in ["map", "battle", "reward", "event", "camp", "relic", "victory", "defeat"]:
		return false
	if not s.get("title", null) is String or not _valid_meta(s.get("meta", null)):
		return false
	for key: String in ["heroes", "parts", "campaign", "choices", "rewards", "log"]:
		if not s.get(key, null) is Array:
			return false
	for key: String in ["boss", "intent", "event", "run"]:
		if not s.get(key, null) is Dictionary:
			return false
	if s.heroes.size() != 3 or s.campaign.size() != 9 or s.log.size() > 120:
		return false
	if not s.get("settled", null) is bool or not s.get("milestone", null) is bool or not _whole(s.get("round_number", null)):
		return false
	if bool(s.settled) != (s.phase in ["victory", "defeat"]):
		return false
	for key: String in ["rng_seed", "rng_state"]:
		if not s.get(key, null) is String or not s[key].is_valid_int() or str(int(s[key])) != s[key]:
			return false
	for line: Variant in s.log:
		if not line is String:
			return false
	for hero: Variant in s.heroes:
		if not _named(hero) or not hero.get("role", null) is String or not hero.get("skills", null) is Array or hero.skills.size() != 4:
			return false
		for key: String in ["hp", "max_hp", "mp", "max_mp"]:
			if not _whole(hero.get(key, null)):
				return false
		if int(hero.max_hp) <= 0 or hero.hp > hero.max_hp or hero.mp > hero.max_mp or not hero.get("acted", null) is bool or not hero.get("guard", null) is bool:
			return false
		for skill: Variant in hero.skills:
			if not _named(skill) or not skill.get("description", null) is String or skill.get("type", "") not in ["slash", "blunt", "pierce", "arcane", "guard"]:
				return false
			for key: String in ["power", "cost", "break_power"]:
				if not _whole(skill.get(key, null)):
					return false
	for index: int in range(9):
		var node: Variant = s.campaign[index]
		if not _named(node) or node.get("index", -1) != index or not node.get("choices", null) is Array or node.choices.size() < 1 or node.choices.size() > 2:
			return false
		if not _whole(node.get("tier", null), 1, 3) or not node.get("completed", null) is bool or not node.get("milestone", null) is bool or not _whole(node.get("selected", null), -1, node.choices.size() - 1):
			return false
		for choice: Variant in node.choices:
			if not _valid_option(choice):
				return false
	for choice: Variant in s.choices:
		if not _valid_option(choice):
			return false
	for key: String in ["seed", "node", "stage", "gold", "karma", "essence", "bosses_defeated", "battles_won"]:
		if not _whole(s.run.get(key, null), (-9223372036854775807 - 1) if key in ["seed", "karma"] else 0):
			return false
	if s.run.node != s.run.stage or not _whole(s.run.node, 0, 9) or (s.phase != "victory" and int(s.run.node) == 9):
		return false
	if not s.run.get("relics", null) is Array or not s.run.get("path", null) is Array or s.run.relics.size() > RELICS.size() or s.run.path.size() > 9:
		return false
	if s.run.has("damage_bonus") and not _whole(s.run.damage_bonus):
		return false
	var relic_ids: Array[String] = []
	for relic: Variant in s.run.relics:
		if not _named(relic) or not relic.get("id", null) is String or not relic.get("description", null) is String or relic.id in relic_ids:
			return false
		relic_ids.append(relic.id)
	for step: Variant in s.run.path:
		if not _named(step) or not _whole(step.get("node", null), 0, 8) or step.get("kind", "") not in ["battle", "boss", "camp", "event", "relic"]:
			return false
	if not s.parts.is_empty() or not s.boss.is_empty():
		if s.parts.size() != 3 or not _named(s.boss):
			return false
		for key: String in ["hp", "max_hp", "tier"]:
			if not _whole(s.boss.get(key, null)):
				return false
		if int(s.boss.max_hp) < 1 or s.boss.hp > s.boss.max_hp or not _whole(s.boss.tier, 1, 3) or not s.boss.get("milestone", null) is bool or not s.boss.get("title", null) is String:
			return false
		for part: Variant in s.parts:
			if not _named(part) or part.get("level", "") not in ["LOW", "MID", "HIGH"] or not part.get("move", null) is String or part.get("weakness", "") not in ["slash", "blunt", "pierce", "arcane"]:
				return false
			for key: String in ["hp", "max_hp", "shield", "max_shield", "armor"]:
				if not _whole(part.get(key, null)):
					return false
			if int(part.max_hp) < 1 or part.hp > part.max_hp or part.shield > part.max_shield or not part.get("broken", null) is bool or not part.get("severed", null) is bool:
				return false
	if not s.intent.is_empty():
		if s.parts.size() != 3 or not _valid_attack(s.intent):
			return false
		if s.intent.has("secondary") and not _valid_attack(s.intent.secondary):
			return false
		if s.intent.has("rhythm"):
			if not _named(s.intent.rhythm) or not s.intent.rhythm.get("id", null) is String or not s.intent.rhythm.get("description", null) is String or not s.intent.rhythm.get("next", null) is String:
				return false
	if s.phase == "battle" and (s.parts.size() != 3 or s.intent.is_empty() or int(s.round_number) < 1):
		return false
	if s.phase == "map" and (s.choices.is_empty() or s.choices != s.campaign[int(s.run.node)].choices):
		return false
	for reward: Variant in s.rewards:
		if not _named(reward) or not reward.get("description", null) is String or reward.get("kind", "") not in ["heal", "gold", "relic"]:
			return false
	if s.phase == "reward" and s.rewards.size() != 3:
		return false
	if not s.event.is_empty():
		if not _named(s.event) or not s.event.get("description", null) is String or not s.event.get("options", null) is Array or s.event.options.size() < 1 or s.event.options.size() > 3:
			return false
		for option: Variant in s.event.options:
			if not _named(option) or not option.get("description", null) is String or option.get("effect", "") not in ["rest", "sharpen", "relic", "offering", "shelter", "sacrifice", "seize"] or not _whole(option.get("cost", 0)):
				return false
	if s.phase in ["camp", "event", "relic"] and s.event.is_empty():
		return false
	return true
