extends SceneTree
const Contract=preload("res://core/reference_contract.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("REFERENCE CONTRACT FAIL: "+message)
func _initialize() -> void:
	var real: Dictionary=Contract.read("res://rulesets/severed_v0_2_102/evidence.json")
	check(not real.ok and real.unresolved.size()==28,"unknown target rules cannot activate")
	check(real.rules.is_empty(),"marketing and patch facts are not runtime rules")
	check(not Contract.require_value(real,"ep.maximum").ok,"missing EP maximum never silently becomes zero or legacy focus")
	# Synthetic metadata fixture tests the validation boundary only. It is not
	# a catalog, a game formula or claimed primary evidence.
	var fixture: Dictionary={"target_version":Contract.TARGET_VERSION,"sources":{"test":{"kind":"official_complete_rule","url":"urn:test-only:synthetic-evidence"}},"rules":{}}
	for id in Contract.REQUIRED_RULES:
		fixture.rules[id]={"status":"verified_rule","target_version":Contract.TARGET_VERSION,"value":0,"source_id":"test","locator":"synthetic validation fixture, not a game observation"}
	check(Contract.validate(fixture).ok,"structurally complete fixture accepted")
	check(Contract.require_value(Contract.validate(fixture),"ep.initial").value==0,"a documented zero is distinct from an unknown value")
	for kind in ["marketing","official_patch_delta","historical_patch_delta"]:
		var copy: Dictionary=fixture.duplicate(true)
		copy.sources.test.kind=kind
		check(not Contract.validate(copy).ok,"cannot promote "+kind+" into a complete rule")
	for field in ["value","source_id","locator"]:
		var copy: Dictionary=fixture.duplicate(true)
		copy.rules["ep.maximum"][field]=null if field=="value" else ""
		check(not Contract.validate(copy).ok,"missing "+field+" rejected")
	var wrong: Dictionary=fixture.duplicate(true)
	wrong.rules["ep.maximum"].target_version="0.0.19"
	check(not Contract.validate(wrong).ok,"historical build cannot silently satisfy the target")
	wrong=fixture.duplicate(true);wrong.target_version="0.2.78"
	check(not Contract.validate(wrong).ok,"manifest baseline mismatch rejected")
	wrong=fixture.duplicate(true);wrong.rules.erase("sever.prerequisites_execution")
	check(not Contract.validate(wrong).ok,"no automatic-sever fallback for an unknown execution rule")
	var snapshot: Dictionary=Contract.validate(fixture)
	fixture.rules["ep.initial"].value=99
	check(snapshot.rules["ep.initial"]==0,"validation result does not track mutable authoring input")
	print("REFERENCE CONTRACT: %d checks; %d failures. Evidence admission only, not mechanics equivalence or fun validation." % [checks,failures])
	quit(0 if failures==0 else 1)
