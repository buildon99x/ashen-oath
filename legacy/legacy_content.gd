extends RefCounted
## Preserved Ashen prototype content, NOT verified Severed Gods mechanics.
## Values and saved identifiers are unchanged; no target-game defaults live here.

const RELICS: Array[Dictionary] = [
	{"id": "red_thread", "name": "Red Thread", "description": "+2 damage on every attack"},
	{"id": "hollow_bell", "name": "Hollow Bell", "description": "Restore 3 party HP after each round"},
	{"id": "glass_tooth", "name": "Glass Tooth", "description": "+1 shield damage when exploiting a weakness"},
	{"id": "pilgrim_coin", "name": "Pilgrim Coin", "description": "+8 gold after every battle"},
	{"id": "cinder_heart", "name": "Cinder Heart", "description": "Defend restores 3 extra HP"}
]

static func _skill(skill_name: String, damage_type: String, power: int, cost: int, description: String, break_power: int = 0) -> Dictionary:
	return {"name": skill_name, "type": damage_type, "power": power, "cost": cost, "description": description, "break_power": break_power}


static func make_heroes(upgrades: Dictionary) -> Array[Dictionary]:
	var heroes: Array[Dictionary] = []
	var vitality: int = int(upgrades.vitality) * 5
	var focus: int = int(upgrades.focus)
	var guard_skill: Dictionary = _skill("Defend", "guard", 0, 0, "Halve incoming damage this round; cancel a wardable rite targeting this hero. Restore 2 focus and 3 HP.")
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

	return heroes
