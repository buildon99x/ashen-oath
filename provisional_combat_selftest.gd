extends SceneTree
## Fresh verification of the restored runtime. These are not the lost tests.
## Pure model only: no UI actions, no human-playability or target-game parity claim.
## Run with an isolated HOME/XDG and Godot 4.7.2 --headless --path . -s this file.
const Model = preload("res://model.gd")
const Combat = preload("res://core/provisional_combat.gd")
const ROOT := "user://provisional_combat_selftest/"
var checks := 0
var failures := 0
var fixture_index := 0
var campaign_wins := 0
var campaign_defeats := 0
var campaign_severs := 0
var campaign_commands := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	_test_profile_and_initialization()
	_test_allocation_and_preview_purity()
	_test_multi_hit_and_height()
	_test_mp_and_recovery()
	_test_initiative_and_delayed_break()
	_test_explicit_sever_and_posture()
	_test_defend()
	_test_parry_and_counter()
	_test_enemy_batch_and_death()
	_test_victory_cancellation()
	_test_validation()
	_test_exact_resume()
	_test_recovery_and_legacy()
	_test_campaigns()
	print("PROVISIONAL COMBAT: %d checks; %d failures; 20 seeds played twice; %d wins, %d defeats, %d explicit Severs, %d campaign commands. Pure-model tests of restored code; original-game parity and human playability unverified." % [checks, failures, campaign_wins, campaign_defeats, campaign_severs, campaign_commands])
	quit(0 if failures == 0 else 1)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func fresh(seed_value: int = 71, profile: String = Combat.ID, battle: bool = true):
	fixture_index += 1
	var prefix: String = ROOT + str(fixture_index)
	for extension: String in [".json", ".save"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + extension + suffix))
	var m = Model.new()
	m.persist_meta = false
	m.meta_path = prefix + ".json"
	m._resume_path = prefix + ".save"
	m._save_revision = 0
	m.meta = {"essence":0,"upgrades":{"vitality":0,"force":0,"focus":0},"runs":1,"wins":0}
	check(m.new_run(seed_value, profile), "fixture starts requested profile")
	if battle: check(m.start_battle(1), "fixture enters battle")
	return m

func snapshot(m) -> Dictionary:
	var value: Dictionary = m._journey_snapshot().duplicate(true)
	value.erase("last_error")
	return value

func accepted(m, ok: bool, description: String) -> void:
	check(ok, description)
	check(m._valid_journey(m._journey_snapshot()), description + ": save remains valid")

func rejected(m, command: Callable, description: String) -> void:
	var before: Dictionary = snapshot(m)
	check(not bool(command.call()), description + ": rejected")
	check(snapshot(m) == before, description + ": only rejection feedback can change")

func event_count(m, kind: String) -> int:
	var count := 0
	for effect: Dictionary in m.run.combat.events:
		if effect.kind == kind: count += 1
	return count

func pass_to_enemy(m) -> void:
	var attempts := 0
	while m.phase == "battle" and m.active_actor() >= 0 and attempts < 4:
		accepted(m, m.end_round(), "pass current hero")
		attempts += 1
	check(m.phase == "battle" and m.active_actor() == -1, "enemy becomes active")

func next_round(m) -> void:
	var round_before: int = m.round_number
	var attempts := 0
	while m.phase == "battle" and m.round_number == round_before and attempts < 8:
		accepted(m, m.end_round(), "advance one actor toward next round")
		attempts += 1
	check(m.phase == "battle" and m.round_number == round_before + 1, "round advances exactly once")

func make_exposed(m, part: int, hp: int) -> void:
	m.parts[part].shield = 0
	m.parts[part].broken = true
	m.parts[part].hp = hp
	m.parts[part].break_round = m.round_number
	m.parts[part].break_consumed = false
	if part == 0:
		m.boss.downed = true
		Combat._update_heights(m)

func add_relic(m, relic_id: String) -> void:
	for relic: Dictionary in Model.RELICS:
		if relic.id == relic_id:
			m.run.relics.append(relic.duplicate(true))
			return
	check(false, "known relic fixture " + relic_id)

func _test_profile_and_initialization() -> void:
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://rulesets/ashen_provisional_v1/profile.json"))
	check(profile.id == Combat.ID and not profile.target_parity_verified and not profile.byte_identity_to_lost_file_verified, "profile discloses provisional and reconstruction provenance")
	check(profile.ep.initial_each_battle == Combat.EP_INITIAL and profile.ep.maximum == Combat.EP_MAX and profile.ep.boost_maximum == Combat.BOOST_MAX and profile.ep.recovery_unboosted_round == Combat.EP_RECOVERY, "EP manifest agrees with runtime")
	check(profile.mp.defend_recovery == Combat.DEFEND_MP and profile.mp.parry_cost == Combat.PARRY_MP and profile.mp.natural_round_recovery == 0, "MP manifest agrees with runtime")
	check(profile.boost.normal_hits.map(func(value): return int(value)) == [1,2,3,4] and profile.boost.skill_hits.map(func(value): return int(value)) == [1,2,3,4] and profile.boost.mp_cost_paid_once, "manifest specifies multi-hit and once-only MP")
	var m = fresh()
	check(m.run.combat.queue == [0,1,2,-1] and m.active_actor() == 0, "initial descending initiative")
	for i in range(3):
		check(m.heroes[i].ep == 2 and m.heroes[i].boost == 0 and not m.heroes[i].spent_ep, "initial EP/Boost independent for hero %d" % i)
		check(m.heroes[i].mp == [60,80,70][i] and m.heroes[i].max_mp == [60,80,70][i], "initial MP maximum for hero %d" % i)
		check(m.heroes[i].speed == profile.turn.hero_speeds[i], "initial speed for hero %d" % i)
		for k in range(4): check(m.heroes[i].skills[k].cost == [0,10,20,0][k], "skill MP cost hero %d skill %d" % [i,k])
	check(m._valid_journey(snapshot(m)), "initial battle is save-valid")
	rejected(m, func(): return m.new_run(99, "unverified_0.2.102"), "unknown profile cannot replace active run")
	var upgraded = fresh(72, Combat.ID, false)
	upgraded.meta.upgrades.focus = 2
	accepted(upgraded, upgraded.new_run(72, Combat.ID), "new upgraded profile")
	for i in range(3): check(upgraded.heroes[i].max_mp == [70,90,80][i], "focus upgrades add five MP per rank")

func _test_allocation_and_preview_purity() -> void:
	var m = fresh()
	rejected(m, func(): return m.act(1,0,0), "out-of-turn attack")
	rejected(m, func(): return m.allocate_boost(1,1), "out-of-turn allocation")
	rejected(m, func(): return m.allocate_boost(0,-1), "negative allocation")
	rejected(m, func(): return m.allocate_boost(0,3), "allocation exceeds stored EP")
	accepted(m, m.allocate_boost(0,2), "allocate two EP")
	check(m.heroes[0].ep == 2 and m.heroes[0].mp == 60, "allocation is reservation without spending")
	accepted(m, m.allocate_boost(0,0), "cancel allocation")
	check(m.heroes[0].ep == 2 and m.heroes[0].boost == 0, "cancellation refunds nothing because nothing spent")
	accepted(m, m.allocate_boost(0,2), "reallocate")
	var before: Dictionary = snapshot(m)
	for iteration in range(50):
		for h in range(3):
			for skill in range(4):
				for part in range(3): m.preview_action(h,skill,part)
		m.preview_intent()
		check(snapshot(m) == before, "preview batch %d preserves resources/RNG/queue/events/log" % iteration)
	rejected(m, func(): return m.act(0,0,-1), "invalid target preserves allocation")
	rejected(m, func(): return m.act(0,4,0), "invalid skill preserves allocation")
	check(m.heroes[0].boost == 2, "invalid actions keep reserved Boost")

func _test_multi_hit_and_height() -> void:
	var m = fresh()
	accepted(m, m.allocate_boost(0,2), "Boost normal attack twice")
	var p: Dictionary = m.preview_action(0,0,0)
	check(p.hits == 3 and p.shield_loss == 2 and p.breaks and p.damage == 21 and p.titan_damage == 37, "independent three-hit oracle: shield, Break, then limb damage")
	var boss_before: int = m.boss.hp
	var limb_before: int = m.parts[0].hp
	accepted(m, m.act(0,0,0), "execute boosted normal attack")
	check(m.boss.hp == boss_before - 37 and m.parts[0].hp == limb_before - 21 and m.parts[0].shield == 0, "actual multi-hit matches independent damage oracle")
	check(m.heroes[0].ep == 0 and m.heroes[0].mp == 60 and m.heroes[0].boost == 0 and m.heroes[0].spent_ep, "valid attack spends Boost once, MP zero")
	check(m.run.combat.events.map(func(e): return e.kind) == ["normal_attack","hit","break","hit","hit"], "ordered hit/Break/normal-hook event trace")
	check(m.boss.downed and m.parts[2].level == "MID", "leg Break temporarily lowers head")
	check(m.preview_intent().losses == [0,0,0], "broken source cancels prepared attack")
	check(m.active_actor() == 1, "valid action advances initiative exactly once")
	rejected(m, func(): return m.act(0,0,0), "double-click cannot spend or hit twice")
	next_round(m)
	check(m.heroes[0].ep == 0 and m.heroes[1].ep == 4 and m.heroes[2].ep == 4, "spent hero receives no EP; unspent heroes recover two")
	check(not m.parts[0].broken and m.parts[0].shield == m.parts[0].max_shield and not m.boss.downed and m.parts[2].level == "HIGH", "consumed living Break restores shield/posture")
	var matched = fresh()
	var missed = fresh()
	make_exposed(matched,2,30)
	make_exposed(missed,2,30)
	matched.heroes[0].skills[0].heights = ["HIGH"]
	missed.heroes[0].skills[0].heights = ["LOW"]
	check(matched.preview_action(0,0,2).titan_damage == 21 and missed.preview_action(0,0,2).titan_damage == 10, "height damage independently floors 21 versus 10")
	accepted(matched, matched.act(0,0,2), "matching-height attack")
	accepted(missed, missed.act(0,0,2), "mismatched height remains legal")
	check(matched.parts[2].hp == 9 and missed.parts[2].hp == 20 and matched.boss.hp + 11 == missed.boss.hp, "height changes actual limb and body damage")
	for boost in range(4):
		var hit_model = fresh()
		hit_model.heroes[0].ep = 6
		accepted(hit_model, hit_model.allocate_boost(0,boost), "allocate hit-matrix Boost")
		accepted(hit_model, hit_model.act(0,0,1), "execute hit-matrix attack")
		check(event_count(hit_model,"hit") == boost+1 and hit_model.heroes[0].ep == 6-boost, "Boost %d means %d actual hits and exact spend" % [boost,boost+1])

func _test_mp_and_recovery() -> void:
	var m = fresh()
	accepted(m, m.allocate_boost(0,2), "reserve boosted paid skill")
	accepted(m, m.act(0,1,0), "execute boosted paid skill")
	check(m.heroes[0].mp == 50 and m.heroes[0].ep == 0 and event_count(m,"hit") == 3, "three-hit skill pays ten MP once")
	m.heroes[1].mp = 9
	accepted(m, m.allocate_boost(1,2), "reserve next hero Boost")
	rejected(m, func(): return m.act(1,1,1), "unaffordable skill")
	check(m.heroes[1].ep == 2 and m.heroes[1].boost == 2 and m.heroes[1].mp == 9, "unaffordable skill spends nothing")
	next_round(m)
	check(m.heroes[0].mp == 50 and m.heroes[1].mp == 9, "round transition grants no natural MP")
	m.heroes[0].ep = 5
	m.heroes[1].ep = 6
	m.heroes[2].hp = 0
	m.heroes[2].ep = 1
	next_round(m)
	check(m.heroes[0].ep == 6 and m.heroes[1].ep == 6 and m.heroes[2].ep == 1, "EP caps six and fallen heroes recover none")
	check(2 not in m.run.combat.queue, "fallen hero omitted from next initiative")
	m.heroes[0].ep = 6
	m.heroes[0].mp = 23
	accepted(m, m.start_battle(2), "start another battle")
	check(m.heroes[0].ep == 2 and m.heroes[0].mp == 23 and m.heroes[0].boost == 0, "battle resets EP allocation without MP recovery")

func _test_initiative_and_delayed_break() -> void:
	var m = fresh()
	m.boss.speed = 50
	Combat._build_queue(m)
	check(m.run.combat.queue == [-1,0,1,2], "fast enemy acts before heroes")
	accepted(m, m.end_round(), "resolve early enemy")
	check(m.active_actor() == 0 and m.heroes[0].hp == 57 and m.run.combat.enemy_resolved, "early enemy dealt exactly 21 once")
	accepted(m, m.allocate_boost(0,2), "reserve after early enemy")
	accepted(m, m.act(0,0,0), "Break after enemy already acted")
	check(m.parts[0].broken and not m.parts[0].break_consumed, "late Break not consumed retroactively")
	accepted(m, m.end_round(), "pass second hero")
	accepted(m, m.end_round(), "pass third hero across boundary")
	check(m.round_number == 2 and m.active_actor() == -1 and m.parts[0].broken and m.parts[0].shield == 0 and m.boss.downed, "late Break persists across first boundary")
	m.intent = {"part":0,"name":"Gravewake","damage":21,"targets":[0],"wardable":false}
	var hp_before: int = m.heroes[0].hp
	accepted(m, m.end_round(), "later enemy observes broken source")
	check(m.heroes[0].hp == hp_before and m.parts[0].break_consumed and m.parts[0].broken, "later enemy phase cancels then marks Break consumed")
	next_round(m)
	check(not m.parts[0].broken and not m.boss.downed and m.parts[2].level == "HIGH", "consumed late Break recovers at following boundary")
	var ties = fresh()
	for h: Dictionary in ties.heroes: h.speed = 20
	ties.boss.speed = 20
	Combat._build_queue(ties)
	check(ties.run.combat.queue == [0,1,2,-1], "equal speed ties use stable roster then enemy")
	ties.heroes[1].speed = 99
	accepted(ties, ties.end_round(), "pass with speed changed mid-round")
	check(ties.run.combat.queue == [0,1,2,-1], "speed change does not reorder current round")
	next_round(ties)
	check(ties.run.combat.queue == [1,0,2,-1], "speed change takes effect at next round")

func _test_explicit_sever_and_posture() -> void:
	var m = fresh()
	make_exposed(m,0,1)
	accepted(m, m.act(0,0,0), "wound exposed limb to zero")
	check(m.parts[0].hp == 0 and not m.parts[0].severed and m.boss.downed and not m.boss.collapsed, "zero limb HP does not auto-Sever")
	var hp_before: int = m.boss.hp
	var karma_before: int = m.run.karma
	accepted(m, m.sever(1,0), "explicit Sever on next actor")
	check(m.parts[0].severed and m.heroes[1].ep == 1 and m.heroes[1].spent_ep and m.boss.hp == hp_before-15 and m.run.karma == karma_before+1, "Sever costs one EP/action and awards exact rupture/karma")
	check(m.boss.collapsed and not m.boss.downed and m.parts[1].level == "LOW" and m.parts[2].level == "MID", "leg Sever creates permanent one-height collapse")
	rejected(m, func(): return m.sever(1,0), "duplicate Sever by previous actor")
	rejected(m, func(): return m.sever(2,0), "duplicate Sever by current actor")
	rejected(m, func(): return m.act(2,0,0), "removed limb cannot be attacked")
	check(m.preview_intent().losses == [0,0,0], "Sever cancels already-prepared source")
	next_round(m)
	check(m.boss.collapsed and m.parts[2].level == "MID", "permanent collapse survives round reset")
	for round_index in range(6):
		for attack: Dictionary in m.get_intent_attacks(): check(attack.part != 0, "future intent excludes severed source")
		for h: Dictionary in m.heroes: h.hp = h.max_hp
		next_round(m)
	var waiting = fresh()
	make_exposed(waiting,0,0)
	next_round(waiting)
	check(waiting.parts[0].broken and waiting.parts[0].shield == 0 and not waiting.parts[0].severed and waiting.boss.downed, "zero-HP limb remains exposed for explicit Sever after round")
	waiting.heroes[0].ep = 0
	rejected(waiting, func(): return waiting.sever(0,0), "Sever requires one EP")
	rejected(waiting, func(): return waiting.sever(0,1), "healthy shielded limb cannot be Severed")

func _test_defend() -> void:
	var m = fresh()
	m.heroes[0].mp = 54
	m.heroes[0].hp = 40
	accepted(m, m.allocate_boost(0,2), "reserve before Defend")
	var p: Dictionary = m.preview_action(0,3,0)
	check(p.focus == 6 and p.heal == 0 and p.valid, "Defend previews actual capped MP gain and no base heal")
	accepted(m, m.act(0,3,0), "Defend")
	check(m.heroes[0].mp == 60 and m.heroes[0].hp == 40 and m.heroes[0].ep == 2 and m.heroes[0].boost == 0 and not m.heroes[0].spent_ep, "Defend caps MP and clears unspent allocation without spending")
	m.intent.wardable = true
	check(m.preview_intent().losses == [11,0,0], "Defend ceil-halves 21, including wardable rites")
	pass_to_enemy(m)
	accepted(m, m.end_round(), "resolve guarded enemy")
	check(m.heroes[0].hp == 29 and not m.heroes[0].guard and m.heroes[0].ep == 4, "Defend applies actual eleven damage and expires next round")
	m.intent = {"part":0,"name":"Gravewake","damage":21,"targets":[0],"wardable":false}
	check(m.preview_intent().losses[0] == 21, "expired guard gives full forecast damage")
	var relic = fresh()
	add_relic(relic,"cinder_heart")
	relic.heroes[0].hp = relic.heroes[0].max_hp-2
	relic.heroes[0].mp = 0
	check(relic.preview_action(0,3,0).heal == 2, "relic heal preview caps to missing HP")
	accepted(relic, relic.act(0,3,0), "Defend with healing relic")
	check(relic.heroes[0].hp == relic.heroes[0].max_hp and relic.heroes[0].mp == 15, "Defend relic heals two and grants nominal fifteen from zero")

func pending_counter():
	var m = fresh()
	accepted(m, m.allocate_boost(0,2), "reserve before Parry")
	accepted(m, m.parry(0,0), "prepare matching LOW Parry")
	check(m.heroes[0].mp == 55 and m.heroes[0].ep == 2 and m.heroes[0].boost == 0, "Parry costs five MP and cancels unspent Boost")
	check(m.preview_intent().losses == [0,0,0] and m.preview_intent().counters == [0], "matching Parry predicts no damage and one hero Counter")
	pass_to_enemy(m)
	accepted(m, m.end_round(), "resolve matching Parry enemy")
	check(m.run.combat.mode == "counter" and m.run.combat.counter_queue == [0] and m.active_actor() == 0 and m.round_number == 1 and m.heroes[0].hp == 78, "enemy pauses at pending Counter without premature round recovery")
	return m

func _test_parry_and_counter() -> void:
	var m = pending_counter()
	rejected(m, func(): return m.allocate_boost(0,1), "Counter cannot allocate Boost")
	rejected(m, func(): return m.parry(0,0), "Counter cannot recursively Parry")
	rejected(m, func(): return m.act(0,1,0), "Counter cannot use paid skill")
	rejected(m, func(): return m.act(0,3,0), "Counter cannot Defend")
	rejected(m, func(): return m.sever(0,0), "Counter cannot Sever")
	rejected(m, func(): return m.act(1,0,0), "Counter only belongs to matching hero")
	var preview: Dictionary = m.preview_action(0,0,2)
	check(preview.valid and preview.hits == 1 and not preview.height_match and preview.titan_damage == 4, "Counter shares height penalty and single-hit normal rules")
	var before_events: int = event_count(m,"normal_attack")
	accepted(m, m.act(0,0,2), "execute free normal Counter")
	check(m.heroes[0].mp == 55 and m.heroes[0].ep == 4 and m.heroes[0].boost == 0, "Counter costs no MP/EP before ordinary unspent recovery")
	check(event_count(m,"normal_attack") == before_events+1 and event_count(m,"historical_counter_hook") == 1 and event_count(m,"successful_parry") == 1, "Counter emits one normal relic hook and no recursive/NPC counter")
	var hook: Dictionary = {}
	for effect: Dictionary in m.run.combat.events:
		if effect.kind == "historical_counter_hook": hook = effect
	check(hook.get("effects",[]) == [{"kind":"relic_hook","event":"normal_attack"}] and hook.get("target_version_verified",true) == false, "Counter adopts attributed historical hook without claiming target parity")
	check(m.round_number == 2 and m.run.combat.mode == "turn" and m.run.combat.counter_queue.is_empty(), "Counter completes exactly one enemy slot")
	var wrong = fresh()
	accepted(wrong, wrong.parry(0,2), "prepare wrong HIGH Parry")
	check(wrong.preview_intent().losses == [21,0,0] and wrong.preview_intent().counters.is_empty(), "wrong height predicts full damage and no Counter")
	pass_to_enemy(wrong)
	accepted(wrong, wrong.end_round(), "resolve wrong-height Parry")
	check(wrong.heroes[0].hp == 57 and wrong.heroes[0].mp == 55 and wrong.run.combat.mode == "turn" and event_count(wrong,"successful_parry") == 0, "wrong-height Parry actually takes full damage")
	var low_mp = fresh()
	low_mp.heroes[0].mp = 4
	rejected(low_mp, func(): return low_mp.parry(0,0), "Parry cannot be paid with insufficient MP")
	var relic = pending_counter()
	add_relic(relic,"red_thread")
	var enhanced: Dictionary = relic.preview_action(0,0,0)
	check(enhanced.titan_damage == 9, "Counter normal damage includes Red Thread floor(16*0.6)")
	accepted(relic, relic.act(0,0,0), "Counter with normal-attack damage relic")
	check(relic.boss.hp == relic.boss.max_hp-9 and event_count(relic,"normal_attack") == 1, "Counter applies normal relic damage once")
	var glass = pending_counter()
	add_relic(glass,"glass_tooth")
	glass.parts[1].max_shield = 4
	glass.parts[1].shield = 4
	check(glass.preview_action(0,0,1).shield_loss == 3, "Counter includes Glass Tooth weakness shield hook")
	accepted(glass, glass.act(0,0,1), "Counter with weakness relic")
	check(glass.parts[1].shield == 1 and event_count(glass,"normal_attack") == 1, "Counter applies normal weakness relic exactly once")
	var skipped = pending_counter()
	accepted(skipped, skipped.end_round(), "pass Counter")
	check(skipped.round_number == 2 and skipped.heroes[0].mp == 55 and event_count(skipped,"normal_attack") == 0, "passing Counter resumes without replay/damage/hook")

func _test_enemy_batch_and_death() -> void:
	var m = fresh()
	m.boss.speed = 50
	Combat._build_queue(m)
	m.heroes[0].hp = 1
	m.intent = {"part":0,"name":"First","damage":21,"targets":[0],"wardable":false,"secondary":{"part":1,"name":"Second","damage":15,"targets":[0],"wardable":false}}
	check(m.preview_intent().losses == [1,0,0], "sequential enemy preview caps loss and skips already dead target")
	accepted(m, m.end_round(), "early enemy kills first queued hero")
	check(m.heroes[0].hp == 0 and m.active_actor() == 1, "dead queued actor skipped immediately")
	next_round(m)
	check(m.run.combat.queue == [-1,1,2] and m.heroes[0].ep == 2, "dead hero absent from rebuilt queue and no recovery")
	var batch = fresh()
	batch.intent = {"part":0,"name":"Low A","damage":21,"targets":[0,1],"wardable":false,"secondary":{"part":0,"name":"Low B","damage":15,"targets":[0,1],"wardable":false}}
	accepted(batch, batch.parry(0,0), "first party Parry")
	accepted(batch, batch.parry(1,0), "second party Parry")
	accepted(batch, batch.end_round(), "third hero passes before batch")
	check(batch.preview_intent().counters == [0,1] and batch.preview_intent().losses == [0,0,0], "multiple matching attacks yield one Counter per living hero")
	accepted(batch, batch.end_round(), "resolve multiple successful Parries")
	check(batch.run.combat.counter_queue == [0,1], "two eligible living heroes queue once in attack order")
	accepted(batch, batch.act(0,0,2), "first batched Counter")
	check(batch.active_actor() == 1 and batch.round_number == 1, "second Counter remains pending in same round")
	accepted(batch, batch.end_round(), "pass second batched Counter")
	check(batch.round_number == 2 and event_count(batch,"successful_parry") == 2 and event_count(batch,"normal_attack") == 1, "batch resumes one next round without recursive Counters")
	var lethal = fresh()
	lethal.heroes[0].hp = 10
	lethal.intent = {"part":0,"name":"Parried first","damage":21,"targets":[0],"wardable":false,"secondary":{"part":2,"name":"Lethal high","damage":20,"targets":[0],"wardable":false}}
	accepted(lethal, lethal.parry(0,0), "Parry one attack before later lethal hit")
	check(lethal.preview_intent().losses[0] == 10 and lethal.preview_intent().counters.is_empty(), "later batch death removes earlier Counter eligibility")
	pass_to_enemy(lethal)
	accepted(lethal, lethal.end_round(), "resolve mixed-height lethal batch")
	check(lethal.heroes[0].hp == 0 and lethal.run.combat.counter_queue.is_empty(), "fallen parrier receives no Counter")
	var defeat = fresh()
	for h: Dictionary in defeat.heroes: h.hp = 1
	defeat.run.essence = 7
	defeat.intent.targets = [0,1,2]
	pass_to_enemy(defeat)
	accepted(defeat, defeat.end_round(), "lethal party-wide enemy attack")
	check(defeat.phase == "defeat" and defeat.run.combat.mode == "complete" and defeat.meta.essence == 7 and defeat.meta.runs == 2, "defeat settles once with complete combat")
	var settled: Dictionary = snapshot(defeat)
	defeat._settle_run(false)
	check(snapshot(defeat) == settled, "repeated defeat settlement is idempotent")

func _test_victory_cancellation() -> void:
	var m = pending_counter()
	m.run.combat.counter_queue.append(1)
	m.boss.hp = 1
	var gold_before: int = m.run.gold
	accepted(m, m.act(0,0,1), "Counter kills enemy")
	check(m.phase == "reward" and m.run.combat.mode == "complete" and m.run.combat.counter_queue.is_empty() and m.run.gold == gold_before+24 and m.run.battles_won == 1, "victory cancels remaining Counters and awards battle exactly once")
	rejected(m, func(): return m.act(1,0,1), "pending Counter cannot attack after victory")
	rejected(m, func(): return m.end_round(), "enemy cannot resolve after victory")
	rejected(m, func(): return m.sever(1,0), "Sever cannot award after victory")
	var revival = fresh()
	revival.heroes[1].hp = 0
	Combat._build_queue(revival)
	revival.boss.hp = 1
	accepted(revival,revival.act(0,0,1),"win with fallen hero absent from initiative")
	accepted(revival,revival.choose_reward(0),"healing reward revives hero after combat ended")
	check(revival.phase == "map" and revival.heroes[1].hp == 24, "post-combat revival does not require stale queue membership")
	var ordinary = fresh()
	ordinary.boss.hp = 1
	var before_hp: int = ordinary.heroes[0].hp
	accepted(ordinary, ordinary.allocate_boost(0,2), "allocate before lethal first hit")
	accepted(ordinary, ordinary.act(0,0,1), "normal action kills before enemy phase")
	check(event_count(ordinary,"hit") == 1 and ordinary.phase == "reward" and ordinary.heroes[0].hp == before_hp, "lethal first hit cancels later hits and scheduled enemy damage")

func invalid_case(m, changed: Dictionary, name: String) -> void:
	check(not m._valid_journey(changed), "save rejects " + name)

func _test_validation() -> void:
	var m = fresh()
	var original: Dictionary = snapshot(m)
	check(m._valid_journey(original), "validation baseline accepted")
	for field: String in ["ep","boost","speed","spent_ep","parry_height"]:
		var changed: Dictionary = original.duplicate(true)
		changed.heroes[0].erase(field)
		invalid_case(m,changed,"missing hero " + field)
	for value: Variant in [-1,7,1.5,"2",null]:
		var changed: Dictionary = original.duplicate(true)
		changed.heroes[0].ep = value
		invalid_case(m,changed,"invalid EP " + str(value))
	for value: Variant in [-1,3,1.5,"1",null]:
		var changed: Dictionary = original.duplicate(true)
		changed.heroes[0].boost = value
		invalid_case(m,changed,"invalid Boost " + str(value))
	for entry: Array in [["speed",-1],["speed",1000],["speed",1.5],["spent_ep",1],["parry_height","UPPER"]]:
		var changed: Dictionary = original.duplicate(true)
		changed.heroes[0][entry[0]] = entry[1]
		invalid_case(m,changed,"invalid hero %s=%s" % [entry[0],str(entry[1])])
	for field: String in ["heights","normal"]:
		var changed: Dictionary = original.duplicate(true)
		changed.heroes[0].skills[0].erase(field)
		invalid_case(m,changed,"missing skill " + field)
	for heights: Array in [[],["UPPER"],["LOW","MID","HIGH","LOW"]]:
		var changed: Dictionary = original.duplicate(true)
		changed.heroes[0].skills[0].heights = heights
		invalid_case(m,changed,"invalid skill heights " + str(heights))
	for field: String in ["base_level","break_round","break_consumed"]:
		var changed: Dictionary = original.duplicate(true)
		changed.parts[0].erase(field)
		invalid_case(m,changed,"missing limb " + field)
	for field: String in ["schema","queue","cursor","counter_queue","mode","events","enemy_resolved"]:
		var changed: Dictionary = original.duplicate(true)
		changed.run.combat.erase(field)
		invalid_case(m,changed,"missing combat " + field)
	var bad: Dictionary = original.duplicate(true)
	bad.run.ruleset = "claimed_target_profile"
	invalid_case(m,bad,"unknown profile")
	for queue: Array in [[0,0,2,-1],[0,1,2],[-2,0,1,-1],[],[0,1,2,-1,3]]:
		bad = original.duplicate(true)
		bad.run.combat.queue = queue
		invalid_case(m,bad,"illegal/duplicate actor queue " + str(queue))
	for cursor: Variant in [-1,4,1.5,null]:
		bad = original.duplicate(true)
		bad.run.combat.cursor = cursor
		invalid_case(m,bad,"invalid cursor " + str(cursor))
	bad = original.duplicate(true)
	bad.run.combat.mode = "counter"
	invalid_case(m,bad,"empty Counter mode")
	bad = original.duplicate(true)
	bad.run.combat.counter_queue = [0]
	invalid_case(m,bad,"Counter queue outside Counter mode")
	bad = original.duplicate(true)
	bad.run.combat.events = [{"damage":3}]
	invalid_case(m,bad,"event without kind")
	bad = original.duplicate(true)
	bad.parts[0].broken = true
	invalid_case(m,bad,"broken limb still holding shield")
	bad = original.duplicate(true)
	bad.parts[0].severed = true
	invalid_case(m,bad,"severed healthy shielded limb")
	bad = original.duplicate(true)
	bad.run.combat.mode = "complete"
	invalid_case(m,bad,"completed combat still in battle phase")
	# These semantic checks prevent an accepted save from stranding or omitting actors.
	bad = original.duplicate(true)
	bad.run.combat.queue = [0,2,-1]
	invalid_case(m,bad,"living hero omitted from initiative")
	bad = original.duplicate(true)
	bad.heroes[0].hp = 0
	invalid_case(m,bad,"dead current actor")
	bad = original.duplicate(true)
	bad.heroes[1].boost = 1
	invalid_case(m,bad,"Boost reserved on inactive hero")
	check(m.save_resume(m._resume_path), "save valid baseline before rejected checkpoint")
	var committed_bytes: PackedByteArray = FileAccess.get_file_as_bytes(m._resume_path)
	m.heroes[1].boost = 1
	check(not m.save_resume(m._resume_path) and m.save_status == "error", "invalid inactive allocation cannot be committed")
	check(FileAccess.get_file_as_bytes(m._resume_path) == committed_bytes, "invalid checkpoint preserves committed save bytes")
	m.heroes[1].boost = 0
	var pending = pending_counter()
	var counter_state: Dictionary = snapshot(pending)
	check(pending._valid_journey(counter_state), "pending Counter save accepted")
	for queue: Array in [[0,0],[-1],[3],[]]:
		bad = counter_state.duplicate(true)
		bad.run.combat.counter_queue = queue
		invalid_case(pending,bad,"invalid Counter actors " + str(queue))
	bad = counter_state.duplicate(true)
	bad.run.combat.enemy_resolved = false
	invalid_case(pending,bad,"Counter before enemy resolved")
	bad = counter_state.duplicate(true)
	bad.heroes[0].hp = 0
	invalid_case(pending,bad,"dead Counter actor")

func reader(m):
	var n = Model.new()
	n.persist_meta = false
	n.meta_path = m.meta_path
	n._resume_path = m._resume_path
	return n

func _test_exact_resume() -> void:
	var m = fresh()
	accepted(m, m.allocate_boost(0,2), "allocate before save")
	check(m.save_resume(m._resume_path), "write allocated Boost checkpoint")
	var n = reader(m)
	check(n.load_resume(m._resume_path), "resume allocated Boost checkpoint")
	check(snapshot(n) == snapshot(m) and n.provisional_combat(), "allocated resume restores exact state/RNG/resources/queue/profile")
	check(n.preview_action(0,1,0) == m.preview_action(0,1,0), "resumed allocation has exact same forecast")
	accepted(m, m.act(0,1,0), "advance original allocated state")
	accepted(n, n.act(0,1,0), "advance resumed allocated state")
	check(snapshot(n) == snapshot(m), "next boosted action exactly reproduces uninterrupted model")
	for step in range(5):
		accepted(m,m.end_round(),"advance original continuation")
		accepted(n,n.end_round(),"advance resumed continuation")
		check(snapshot(n) == snapshot(m), "post-save continuation %d stays exact" % step)
	var early = fresh()
	early.boss.speed = 50
	Combat._build_queue(early)
	accepted(early,early.end_round(),"resolve early enemy before checkpoint")
	accepted(early,early.allocate_boost(0,2),"reserve after early enemy before checkpoint")
	accepted(early,early.act(0,0,0),"late Break before checkpoint")
	check(early.save_resume(early._resume_path), "save late Break after early enemy")
	var early_resumed = reader(early)
	check(early_resumed.load_resume(early._resume_path), "resume late Break after early enemy")
	check(snapshot(early_resumed) == snapshot(early), "resume preserves delayed Break consumption and early enemy progress")
	for step in range(7):
		accepted(early,early.end_round(),"continue original delayed Break")
		accepted(early_resumed,early_resumed.end_round(),"continue resumed delayed Break")
		check(snapshot(early_resumed) == snapshot(early), "delayed Break resume continuation %d stays exact" % step)
	var pending = pending_counter()
	check(pending.save_resume(pending._resume_path), "save pending Counter")
	var resumed = reader(pending)
	check(resumed.load_resume(pending._resume_path), "load pending Counter")
	check(snapshot(resumed) == snapshot(pending) and resumed.active_actor() == 0 and resumed.run.combat.mode == "counter", "pending Counter resumes exactly")
	var hp_before: int = resumed.heroes[0].hp
	accepted(pending,pending.act(0,0,2),"original pending Counter action")
	accepted(resumed,resumed.act(0,0,2),"resumed pending Counter action")
	check(snapshot(resumed) == snapshot(pending) and resumed.heroes[0].hp == hp_before, "pending Counter continuation never replays enemy damage")
	var reward = fresh()
	reward.boss.hp = 1
	accepted(reward,reward.act(0,0,1),"win before reward checkpoint")
	check(reward.save_resume(reward._resume_path), "save pending reward")
	var reward_resumed = reader(reward)
	check(reward_resumed.load_resume(reward._resume_path), "resume pending reward")
	check(snapshot(reward_resumed) == snapshot(reward), "pending reward resume does not repeat win award")
	accepted(reward,reward.choose_reward(2),"original random relic reward")
	accepted(reward_resumed,reward_resumed.choose_reward(2),"resumed random relic reward")
	check(snapshot(reward_resumed) == snapshot(reward), "saved reward preserves exact RNG and next map")
	rejected(reward_resumed,func(): return reward_resumed.choose_reward(2),"resumed reward cannot be claimed twice")
	var passed = pending_counter()
	check(passed.save_resume(passed._resume_path), "save skippable Counter")
	var resumed_pass = reader(passed)
	check(resumed_pass.load_resume(passed._resume_path), "resume skippable Counter")
	accepted(passed,passed.end_round(),"pass original Counter")
	accepted(resumed_pass,resumed_pass.end_round(),"pass resumed Counter")
	check(snapshot(passed) == snapshot(resumed_pass) and resumed_pass.round_number == 2, "passing saved Counter resumes exact round")

func _test_recovery_and_legacy() -> void:
	var m = fresh()
	accepted(m,m.allocate_boost(0,2),"reserve allocation in backup fixture")
	check(m.save_resume(m._resume_path), "first checkpoint for recovery")
	var protected: Dictionary = snapshot(m)
	accepted(m,m.act(0,1,0),"move beyond backup checkpoint")
	check(m.save_resume(m._resume_path), "second checkpoint protects prior copy")
	var file = FileAccess.open(m._resume_path,FileAccess.WRITE)
	file.store_string("{truncated primary")
	file.close()
	var n = reader(m)
	check(n.load_resume(m._resume_path), "damaged primary recovers backup")
	check(n.recovery_status == "recovered" and n.provisional_combat() and snapshot(n) == protected, "recovered backup retains exact provisional allocation/profile")
	var legacy = fresh(77,"legacy")
	accepted(legacy,legacy.act(0,1,0),"legacy attack before persistence")
	check(legacy.save_resume(legacy._resume_path), "save legacy checkpoint")
	var old = reader(legacy)
	check(old.load_resume(legacy._resume_path), "resume legacy checkpoint")
	check(snapshot(old) == snapshot(legacy) and not old.provisional_combat() and not old.run.has("combat"), "legacy resume remains exact legacy model")
	for h: Dictionary in old.heroes: check(not h.has("ep") and not h.has("boost") and not h.has("parry_height"), "legacy hero gains no provisional fields")
	accepted(legacy,legacy.end_round(),"original legacy enemy round")
	accepted(old,old.end_round(),"resumed legacy enemy round")
	check(snapshot(old) == snapshot(legacy), "legacy next action remains identical")

func campaign_step(m, seed_value: int) -> bool:
	match m.phase:
		"map":
			var pick := 0
			for i in range(m.choices.size()):
				if m.choices[i].kind in ["battle","boss"]: pick = i
			return m.travel(pick)
		"battle":
			var actor: int = m.active_actor()
			if actor == -1: return m.end_round()
			if actor < 0: return false
			if m.run.combat.mode == "turn":
				for part in range(3):
					if not m.parts[part].severed and m.parts[part].broken and int(m.parts[part].hp) == 0 and int(m.heroes[actor].ep) >= 1:
						var done: bool = m.sever(actor,part)
						if done: campaign_severs += 1
						return done
				if int(m.heroes[actor].mp) < 10: return m.act(actor,3,0)
				accepted(m,m.allocate_boost(actor,mini(2,int(m.heroes[actor].ep))),"campaign reserves Boost")
			var skill: int = 0
			if m.run.combat.mode == "turn":
				var requested: int = 1 if m.round_number%2 == 1 else 2
				if int(m.heroes[actor].mp) >= int(m.heroes[actor].skills[requested].cost): skill = requested
			var target := -1
			var score := -1
			for part in range(3):
				var p: Dictionary = m.preview_action(actor,skill,part)
				if not p.get("valid",false): continue
				var candidate: int = int(p.titan_damage) + 2*int(p.damage) + (35 if p.breaks else 0) + (30 if p.execute_ready else 0)
				if candidate > score:
					target = part
					score = candidate
			return m.act(actor,skill,target) if target >= 0 else false
		"reward": return m.choose_reward(0 if seed_value%2 == 0 else 2)
		"event", "camp", "relic":
			for option in range(m.event.options.size()):
				if int(m.event.options[option].get("cost",0)) <= int(m.run.gold): return m.choose_event(option)
	return false

func play_campaign(seed_value: int) -> Dictionary:
	var m = fresh(seed_value,Combat.ID,false)
	var steps := 0
	while m.phase not in ["victory","defeat"] and steps < 1500:
		steps += 1
		var ok: bool = campaign_step(m,seed_value)
		campaign_commands += 1
		accepted(m,ok,"seed %d command %d (%s)" % [seed_value,steps,m.phase])
		if not ok: break
	check(steps < 1500 and m.phase in ["victory","defeat"], "seed %d terminates without softlock" % seed_value)
	# Victory is an observed balance outcome, not a guaranteed rules invariant.
	check(m._settled and m.meta.runs == 2 and m.meta.wins == (1 if m.phase == "victory" else 0), "seed %d settles the observed outcome correctly" % seed_value)
	if m.phase == "victory": campaign_wins += 1
	elif m.phase == "defeat": campaign_defeats += 1
	print("CAMPAIGN seed=%d outcome=%s node=%d steps=%d battles=%d final_battle_sever_events=%d" % [seed_value,m.phase,m.run.node,steps,m.run.battles_won,event_count(m,"sever")])
	var completed: Dictionary = snapshot(m)
	var banked: int = m.meta.essence
	var runs: int = m.meta.runs
	var wins: int = m.meta.wins
	m._settle_run(m.phase == "victory")
	check(snapshot(m) == completed and m.meta.essence == banked and m.meta.runs == runs and m.meta.wins == wins, "seed %d settlement cannot double-bank" % seed_value)
	rejected(m,func(): return m.choose_reward(0),"seed %d settled reward cannot be repeated" % seed_value)
	accepted(m,m.new_run(seed_value+1000,Combat.ID),"start next cycle after seed %d" % seed_value)
	check(m.phase == "map" and not m.run.has("combat") and m.parts.is_empty() and m.intent.is_empty() and m.boss.is_empty(), "new cycle clears all pending combat")
	check(m.meta.essence == banked and m.meta.runs == runs and m.meta.wins == wins, "new cycle preserves settled vault")
	for h: Dictionary in m.heroes: check(h.ep == 2 and h.boost == 0 and not h.spent_ep and h.parry_height == "" and h.mp == h.max_mp, "next cycle hero has fresh EP/MP/stance")
	return completed

func _test_campaigns() -> void:
	for seed_value in range(81,101):
		var first: Dictionary = play_campaign(seed_value)
		var second: Dictionary = play_campaign(seed_value)
		check(first == second, "seed %d repeated campaign reproduces exact terminal state/RNG/log/rewards" % seed_value)
