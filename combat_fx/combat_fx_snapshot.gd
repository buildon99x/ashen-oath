extends RefCounted
## Display-only value copy. Never a second rules engine and never persisted.
var phase: String
var run: Dictionary
var meta: Dictionary
var boss: Dictionary
var heroes: Array
var parts: Array
var intent: Dictionary
var log: Array
var round_number: int
var threat: Dictionary
var predictions: Array = []
var action_count: int

static func capture(model):
	var snapshot = load("res://combat_fx/combat_fx_snapshot.gd").new()
	for field in ["run","meta","boss","heroes","parts","intent","log"]:
		snapshot.set(field, model.get(field).duplicate(true))
	snapshot.phase = model.phase
	snapshot.round_number = model.round_number
	snapshot.action_count = model.actions_remaining()
	snapshot.threat = model.preview_intent().duplicate(true)
	for hero in range(model.heroes.size()):
		var skills: Array = []
		for skill in range(model.heroes[hero].skills.size()):
			var targets: Array = []
			for part in range(model.parts.size()):
				targets.append(model.preview_action(hero,skill,part).duplicate(true))
			skills.append(targets)
		snapshot.predictions.append(skills)
	return snapshot

func actions_remaining() -> int:
	return action_count
func preview_intent() -> Dictionary:
	return threat.duplicate(true)
func preview_action(hero: int, skill: int, part: int) -> Dictionary:
	if hero < 0 or hero >= predictions.size() or skill < 0 or skill >= predictions[hero].size(): return {"valid":false}
	if part < 0 or part >= predictions[hero][skill].size(): return {"valid":false}
	return predictions[hero][skill][part].duplicate(true)

func duplicate_view():
	var copy = load("res://combat_fx/combat_fx_snapshot.gd").new()
	for field in ["run","meta","boss","heroes","parts","intent","log","threat","predictions"]:
		copy.set(field,get(field).duplicate(true))
	copy.phase=phase
	copy.round_number=round_number
	copy.action_count=action_count
	return copy
