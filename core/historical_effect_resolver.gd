extends RefCounted
## Reconstructed historical patch adapter, not an EA 0.2.102 rules profile.
## Only describes a resolved effect. It never mutates actors, resources or turns.
const MANIFEST_PATH := "res://rulesets/severed_historical_effects_v1/manifest.json"
const PROFILE_ID := "severed_historical_effects_v1"
const TARGET_VERSION := "0.2.102"
const HISTORICAL_STATUS := "historical_not_target_verified"
const DEFEND_SOURCE := "official_3755930_v0.2.78"
const COUNTER_SOURCE := "official_4129400_v0.1.137"

# Closed compatibility surface. Adding an effect requires a new reviewed pin;
# editing a JSON amount or attaching another source cannot activate new rules.
const PINS := {
	"defend.mp_grant": {
		"source_id": DEFEND_SOURCE, "app_id": 3755930, "version": "0.2.78",
		"url": "https://steamcommunity.com/app/3755930/?l=russian",
		"requires": {"resolved_boundary": "defend_grant"},
		"effects": [{"kind": "nominal_mp_recovery", "amount": 15}],
	},
	"counter.normal_attack_relic_event": {
		"source_id": COUNTER_SOURCE, "app_id": 4129400, "version": "0.1.137",
		"url": "https://store.steampowered.com/news/posts/?enddate=1778507195&feed=steam_community_announcements",
		"requires": {"resolved_boundary": "resolved_counter", "uses_normal_attack": true},
		"effects": [{"kind": "relic_hook", "event": "normal_attack"}],
	},
	"parry.successful_action_scope": {
		"source_id": COUNTER_SOURCE, "app_id": 4129400, "version": "0.1.137",
		"url": "https://store.steampowered.com/news/posts/?enddate=1778507195&feed=steam_community_announcements",
		"requires": {"resolved_boundary": "resolved_successful_parry"},
		"effects": [{"kind": "action_scope", "actor_scope": "hero_only", "npc_actions": false}],
	},
}

static func read_manifest(path: String = MANIFEST_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func resolve(manifest: Dictionary, source_id: String, rule_id: String, event: Dictionary) -> Dictionary:
	var result := {
		"ok": false, "source_id": source_id, "rule_id": rule_id,
		"effects": [], "source_version": "", "evidence_status": HISTORICAL_STATUS,
		"target_version": TARGET_VERSION, "target_version_verified": false,
		"error": "Historical source or resolved event is unavailable.",
	}
	if not _matches_pin(manifest.get("schema_version"), 1) or not _matches_pin(manifest.get("profile_id"), PROFILE_ID):
		return result
	if not _matches_pin(manifest.get("target_version"), TARGET_VERSION) or not _matches_pin(manifest.get("target_version_verified"), false):
		return result
	if not PINS.has(rule_id):
		return result
	var pin: Dictionary = PINS[rule_id]
	if source_id != pin.source_id:
		return result
	var sources: Variant = manifest.get("sources")
	var rules: Variant = manifest.get("rules")
	if not sources is Dictionary or not rules is Dictionary:
		return result
	var source: Variant = sources.get(source_id)
	var rule: Variant = rules.get(rule_id)
	if not source is Dictionary or not rule is Dictionary:
		return result
	if not _matches_pin(source.get("kind"), "historical_patch_delta") or not _matches_pin(source.get("app_id"), pin.app_id):
		return result
	if not _matches_pin(source.get("version"), pin.version) or not _matches_pin(source.get("url"), pin.url):
		return result
	if not _matches_pin(rule.get("source_id"), source_id) or not _matches_pin(rule.get("status"), HISTORICAL_STATUS):
		return result
	var locator: Variant = rule.get("locator")
	if not locator is String or locator.strip_edges().is_empty():
		return result
	# JSON stores numbers as floats. Container equality is type-sensitive in
	# Godot, so compare recursively and permit only int/float numeric equality.
	if not _matches_pin(rule.get("requires"), pin.requires) or not _matches_pin(rule.get("effects"), pin.effects):
		return result
	for key: String in pin.requires:
		if not event.has(key):
			return result
		var expected: Variant = pin.requires[key]
		if typeof(event[key]) != typeof(expected) or event[key] != expected:
			return result
	result.ok = true
	result.error = ""
	result.source_version = pin.version
	result.effects = pin.effects.duplicate(true)
	return result

static func _matches_pin(actual: Variant, expected: Variant) -> bool:
	# Do not let boolean/string truthiness or extra dictionary fields satisfy a
	# pin. Numeric JSON representations are the one intentional type exception.
	if typeof(expected) == TYPE_INT:
		return typeof(actual) in [TYPE_INT, TYPE_FLOAT] and actual == expected
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key: Variant in expected:
			if not actual.has(key) or not _matches_pin(actual[key], expected[key]):
				return false
		return true
	if expected is Array:
		if actual.size() != expected.size():
			return false
		for index: int in range(expected.size()):
			if not _matches_pin(actual[index], expected[index]):
				return false
		return true
	return actual == expected
