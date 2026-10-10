extends SceneTree
## Isolated descriptor tests: no model, UI, game state or player save access.
const Resolver = preload("res://core/historical_effect_resolver.gd")
const Reference = preload("res://core/reference_contract.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HISTORICAL EFFECT FAIL: " + message)

func _initialize() -> void:
	var manifest: Dictionary = Resolver.read_manifest()
	var before := JSON.stringify(manifest)
	var defend_event := {"resolved_boundary": "defend_grant"}
	var counter_event := {"resolved_boundary": "resolved_counter", "uses_normal_attack": true}
	var defend := Resolver.resolve(manifest, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event)
	check(defend.ok, "known Defend source and boundary resolve")
	check(defend.effects == [{"kind": "nominal_mp_recovery", "amount": 15}], "nominal grant is exactly 15")
	check(defend.get("source_version", "") == "0.2.78" and not defend.target_version_verified, "historical version remains explicit")
	var counter := Resolver.resolve(manifest, Resolver.COUNTER_SOURCE, "counter.normal_attack_relic_event", counter_event)
	check(counter.ok and counter.effects == [{"kind": "relic_hook", "event": "normal_attack"}], "normal-attack counter emits only a hook")
	var parry := Resolver.resolve(manifest, Resolver.COUNTER_SOURCE, "parry.successful_action_scope", {"resolved_boundary": "resolved_successful_parry"})
	check(parry.ok and parry.effects == [{"kind": "action_scope", "actor_scope": "hero_only", "npc_actions": false}], "resolved successful Parry describes hero-only scope")
	check(JSON.stringify(manifest) == before, "resolution leaves input manifest unchanged")
	check(defend_event == {"resolved_boundary": "defend_grant"} and counter_event == {"resolved_boundary": "resolved_counter", "uses_normal_attack": true}, "resolution leaves events unchanged")
	if defend.ok and not defend.effects.is_empty():
		defend.effects[0].amount = 999
	check(Resolver.resolve(manifest, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event).effects == [{"kind": "nominal_mp_recovery", "amount": 15}], "returned effects are independent copies")
	for invalid_event in [{}, {"resolved_boundary": "defend_requested"}, {"resolved_boundary": "resolved_counter"}, {"resolved_boundary": true}]:
		check_denied(Resolver.resolve(manifest, Resolver.DEFEND_SOURCE, "defend.mp_grant", invalid_event), "unresolved or wrong Defend event")
	for invalid_event in [{}, {"resolved_boundary": "resolved_counter"}, {"resolved_boundary": "resolved_counter", "uses_normal_attack": false}, {"resolved_boundary": "resolved_counter", "uses_normal_attack": "true"}, {"resolved_boundary": "resolved_counter", "uses_normal_attack": 1}, {"resolved_boundary": "normal_attack", "uses_normal_attack": true}]:
		check_denied(Resolver.resolve(manifest, Resolver.COUNTER_SOURCE, "counter.normal_attack_relic_event", invalid_event), "counter preconditions are strict")
	check_denied(Resolver.resolve(manifest, Resolver.COUNTER_SOURCE, "parry.successful_action_scope", {"resolved_boundary": "parry_attempt"}), "Parry attempt cannot imply success")
	check_denied(Resolver.resolve(manifest, Resolver.COUNTER_SOURCE, "defend.mp_grant", defend_event), "another official source cannot supply Defend")
	check_denied(Resolver.resolve(manifest, "official_3755930_v0.2.102", "defend.mp_grant", defend_event), "target-version promotion is not allowed")
	check_denied(Resolver.resolve(manifest, Resolver.DEFEND_SOURCE, "ep.maximum", defend_event), "unknown rules have no fallback")
	check_denied(Resolver.resolve({}, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event), "missing manifest fails closed")
	check(Resolver.read_manifest("res://rulesets/no-such-historical-manifest.json").is_empty(), "missing manifest file returns no data")
	for field in ["schema_version", "profile_id", "target_version", "target_version_verified", "sources", "rules"]:
		var copy := manifest.duplicate(true)
		copy.erase(field)
		check_denied(Resolver.resolve(copy, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event), "missing manifest field " + field)
	for field in ["kind", "app_id", "version", "url"]:
		var copy := manifest.duplicate(true)
		copy.sources[Resolver.DEFEND_SOURCE][field] = "tampered"
		check_denied(Resolver.resolve(copy, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event), "changed source pin " + field)
	for field in ["source_id", "status", "locator", "requires", "effects"]:
		var copy := manifest.duplicate(true)
		copy.rules["defend.mp_grant"].erase(field)
		check_denied(Resolver.resolve(copy, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event), "missing rule field " + field)
	var tampered := manifest.duplicate(true)
	tampered.rules["defend.mp_grant"].effects[0].amount = 16
	check_denied(Resolver.resolve(tampered, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event), "edited amount cannot become source-backed")
	for invalid_amount in ["15", true, 15.5, null]:
		tampered = manifest.duplicate(true)
		tampered.rules["defend.mp_grant"].effects[0].amount = invalid_amount
		check_denied(Resolver.resolve(tampered, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event), "invalid numeric pin type or value")
	tampered = manifest.duplicate(true)
	tampered.rules["defend.mp_grant"].effects[0].bonus = true
	check_denied(Resolver.resolve(tampered, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event), "extra descriptor fields cannot satisfy pins")
	tampered = manifest.duplicate(true)
	tampered.target_version_verified = true
	check_denied(Resolver.resolve(tampered, Resolver.DEFEND_SOURCE, "defend.mp_grant", defend_event), "manifest cannot claim target verification")
	var reference := Reference.read("res://rulesets/severed_v0_2_102/evidence.json")
	check(not reference.ok and reference.unresolved.size() == 28 and reference.rules.is_empty(), "all 28 target contracts remain unresolved")
	check(not Reference.validate(manifest).ok, "historical manifest cannot activate the reference profile")
	print("HISTORICAL EFFECT RESOLVER: %d checks; %d failures. Historical descriptor compatibility only; no target-game parity claim." % [checks, failures])
	quit(0 if failures == 0 else 1)

func check_denied(result: Dictionary, message: String) -> void:
	check(not result.ok and result.effects.is_empty() and not result.target_version_verified, message)
