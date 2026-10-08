extends RefCounted
## Reference rules cannot silently inherit prototype values or marketing claims.
const TARGET_VERSION: String = "0.2.102"
const REQUIRED_RULES: Array[String] = [
	"ep.initial","ep.maximum","ep.gain_schedule","ep.spend_and_boost","ep.carryover",
	"mp.hero_baselines","mp.skill_costs","mp.recovery_order","turn.actor_order","turn.action_consumption",
	"defend.cost_mitigation_duration","parry.success_failure_cost","counter.order_targets_triggers",
	"targeting.skill_heights","targeting.posture_changes","break.shield_depletion","knockdown.duration_recovery",
	"sever.prerequisites_execution","sever.post_cut_changes","victory.conditions","enemy.behavior_selection",
	"skills.acquisition_equipment","skills.level_transform","effects.resolution_order","relics.capacity_duplicates",
	"relics.trigger_order","rewards.sequence","empower.acquisition_application"
]

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok":false,"errors":["Reference manifest is missing."],"rules":{}}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return {"ok":false,"errors":["Reference manifest is not an object."],"rules":{}}
	return validate(parsed)

static func validate(manifest: Dictionary) -> Dictionary:
	var errors: Array[String]=[]
	var unresolved: Array[String]=[]
	var usable: Dictionary={}
	if manifest.get("target_version","")!=TARGET_VERSION: errors.append("Target version differs from the adopted baseline.")
	var records: Variant=manifest.get("rules",{})
	var sources: Variant=manifest.get("sources",{})
	if not records is Dictionary or not sources is Dictionary:
		return {"ok":false,"errors":["Rules and sources must be objects."],"unresolved":REQUIRED_RULES.duplicate(),"rules":{}}
	for id in REQUIRED_RULES:
		var rule: Variant=records.get(id,null)
		if not rule is Dictionary:
			unresolved.append(id)
			continue
		if rule.get("status","")!="verified_rule":
			unresolved.append(id)
			continue
		var source_id: String=str(rule.get("source_id",""))
		var source: Variant=sources.get(source_id,null)
		if rule.get("target_version","")!=TARGET_VERSION or rule.get("value",null)==null:
			errors.append(id+": verified rule lacks a target-version value.")
			continue
		if not source is Dictionary or source.get("kind","") not in ["target_build_observation","official_complete_rule"]:
			errors.append(id+": marketing and historical deltas cannot activate a rule.")
			continue
		if str(source.get("url","")).is_empty() or str(rule.get("locator","")).is_empty():
			errors.append(id+": no reproducible evidence locator.")
			continue
		usable[id]=rule.value.duplicate(true) if rule.value is Array or rule.value is Dictionary else rule.value
	return {"ok":errors.is_empty() and unresolved.is_empty(),"errors":errors,"unresolved":unresolved,"rules":usable}

static func require_value(result: Dictionary,id: String) -> Dictionary:
	# Deliberately no default/fallback parameter, and no coercion of unknown to0.
	if not result.get("ok",false) or not result.get("rules",{}).has(id):
		return {"ok":false,"error":"Reference rule is unresolved: "+id}
	var value: Variant=result.rules[id]
	return {"ok":true,"value":value.duplicate(true) if value is Array or value is Dictionary else value}
