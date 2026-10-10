extends RefCounted
## Reconstructed after environment loss and integrated against remote65404c2.
## Independent validation is recorded in verification/provisional-combat.
## Ashen temporary rules; NEVER a verified The Severed Gods 0.2.102 profile.
const HistoricalEffects = preload("res://core/historical_effect_resolver.gd")
static var historical_manifest: Dictionary = {}
const ID := "ashen_provisional_v1"
const HEIGHTS := ["LOW", "MID", "HIGH"]
const EP_INITIAL := 2
const EP_MAX := 6
const BOOST_MAX := 3
const EP_RECOVERY := 2
const DEFEND_MP := 15
const PARRY_MP := 5

static func initialize_party(m) -> void:
	for i in range(m.heroes.size()):
		var h: Dictionary = m.heroes[i]
		h.max_mp = [60,80,70][i] + int(m.meta.upgrades.focus) * 5
		h.mp = h.max_mp
		h.ep = EP_INITIAL
		h.boost = 0
		h.speed = [30,20,10][i]
		h.spent_ep = false
		h.parry_height = ""
		for k in range(4):
			var skill: Dictionary = h.skills[k]
			skill.cost = [0,10,20,0][k]
			skill.heights = [["LOW","MID"],["HIGH"],["MID","HIGH"]][i].duplicate() if k == 0 else (["LOW"] if k == 1 else HEIGHTS.duplicate())
			skill.normal = k == 0
			skill.description = "Ashen provisional: Boost adds one hit per EP; matching height deals full damage. MP is paid once."
			if skill.name == "Blood Lantern": skill.description += "\nBlood Lantern restores 7 HP to every living ally."
			if k == 3: skill.description = "Ashen provisional Defend: halve all incoming damage until next round; recover 15 MP."

static func begin(m) -> void:
	m.boss.hp = 220 + int(m.boss.tier) * 45
	m.boss.max_hp = m.boss.hp
	m.boss.speed = 1
	m.boss.downed = false
	m.boss.collapsed = false
	for p: Dictionary in m.parts:
		p.base_level = p.level
		p.break_round = 0
		p.break_consumed = false
	for h: Dictionary in m.heroes:
		h.ep = EP_INITIAL
		h.boost = 0
		h.spent_ep = false
		h.parry_height = ""
		h.acted = false
		h.guard = false
	m.run.combat = {"schema":1,"queue":[],"cursor":0,"counter_queue":[],"mode":"turn","events":[],"enemy_resolved":false}
	_build_queue(m)
	_prepare_intent(m)
	m._note("ASHEN PROVISIONAL COMBAT: EP / Boost / height / Parry / manual Sever. Original-game parity is unverified.")

static func _build_queue(m) -> void:
	var entries: Array = []
	for i in range(m.heroes.size()):
		if int(m.heroes[i].hp) > 0: entries.append({"actor":i,"speed":int(m.heroes[i].speed)})
	entries.append({"actor":-1,"speed":int(m.boss.speed)})
	entries.sort_custom(func(a,b): return a.speed > b.speed if a.speed != b.speed else (a.actor if a.actor >= 0 else 99) < (b.actor if b.actor >= 0 else 99))
	m.run.combat.queue = []
	for entry: Dictionary in entries: m.run.combat.queue.append(entry.actor)
	m.run.combat.cursor = 0
	m.run.combat.enemy_resolved = false

static func active(m) -> int:
	if m.phase != "battle": return -2
	var c: Dictionary = m.run.combat
	if c.mode == "counter": return int(c.counter_queue[0]) if not c.counter_queue.is_empty() else -2
	if int(c.cursor) >= c.queue.size(): return -2
	return int(c.queue[int(c.cursor)])

static func set_boost(m, hero: int, value: int) -> bool:
	if active(m) != hero or hero < 0 or m.run.combat.mode != "turn": return m._reject("Only the current hero can allocate Boost.")
	if value < 0 or value > mini(BOOST_MAX,int(m.heroes[hero].ep)): return m._reject("Boost needs stored EP (maximum 3).")
	m.heroes[hero].boost = value
	m.last_error = ""
	return true

static func _can_act(m, hero: int) -> bool:
	return m.phase == "battle" and hero >= 0 and hero < m.heroes.size() and active(m) == hero and int(m.heroes[hero].hp) > 0

static func effective_height(m, index: int) -> String:
	var p: Dictionary = m.parts[index]
	var level: int = HEIGHTS.find(str(p.base_level))
	if index != 0 and (bool(m.boss.downed) or bool(m.boss.collapsed)): level = maxi(0, level-1)
	return str(HEIGHTS[level])

static func _update_heights(m) -> void:
	for i in range(m.parts.size()): m.parts[i].level = effective_height(m,i)

static func preview(m, hero: int, skill_index: int, target: int) -> Dictionary:
	if hero < 0 or hero >= m.heroes.size() or skill_index < 0 or skill_index >= 4: return {"valid":false,"summary":"Choose a skill."}
	var h: Dictionary = m.heroes[hero]
	var skill: Dictionary = h.skills[skill_index]
	var counter: bool = m.run.combat.mode == "counter"
	var valid: bool = _can_act(m,hero) and int(h.mp) >= int(skill.cost) and (not counter or skill_index == 0)
	if skill_index == 3:
		return {"valid":valid,"guard":true,"heal":mini(3,int(h.max_hp)-int(h.hp)) if m.has_relic("cinder_heart") else 0,"focus":mini(DEFEND_MP,int(h.max_mp)-int(h.mp)),"wards":[],"summary":"HALVE ALL DAMAGE / +%d MP" % mini(DEFEND_MP,int(h.max_mp)-int(h.mp))}
	if target < 0 or target >= m.parts.size() or bool(m.parts[target].severed): return {"valid":false,"summary":"Choose an intact part."}
	var boost: int = 0 if counter else int(h.boost)
	valid = valid and boost <= int(h.ep)
	var simulation: Dictionary = _simulate_attack(m,h,skill,target,boost)
	simulation.valid = valid
	simulation.guard = false
	simulation.severs = false
	simulation.summary = "%d HITS / %d HP / -%d SHIELD%s" % [simulation.hits,simulation.damage,simulation.shield_loss," / HALF: HEIGHT" if not simulation.height_match else ""]
	if simulation.breaks: simulation.summary += " / BREAK"
	if simulation.execute_ready: simulation.summary += " / SEVER READY"
	return simulation

static func _simulate_attack(m, h: Dictionary, skill: Dictionary, target: int, boost: int) -> Dictionary:
	var p: Dictionary = m.parts[target].duplicate(true)
	var hp: int = int(m.boss.hp)
	var old_hp: int = int(p.hp)
	var old_shield: int = int(p.shield)
	var was_broken: bool = p.broken
	var allocated_hits: int = 1 + boost
	var hits: int = 0
	var height_match: bool = str(p.level) in skill.heights
	var weakness: bool = str(skill.type) == str(p.weakness)
	var party_heal: Array = []
	for ally: Dictionary in m.heroes:
		party_heal.append(mini(7,int(ally.max_hp)-int(ally.hp)) if skill.name=="Blood Lantern" and int(ally.hp)>0 else 0)
	var events: Array = []
	if bool(skill.normal): events.append({"kind":"normal_attack","hero":h.name})
	for hit in range(allocated_hits):
		if hp <= 0: break
		hits += 1
		var exposed: bool = p.broken
		var power: int = int(skill.power) + int(m.meta.upgrades.force)*2 + int(m.run.get("damage_bonus",0))
		if m.has_relic("red_thread"): power += 2
		var damage: int = maxi(1,int(floor(power * (1.5 if exposed else 0.6) * (1.0 if height_match else 0.5))))
		if exposed:
			p.hp = maxi(0,int(p.hp)-damage)
		else:
			var shield_hit: int = 1 + int(skill.break_power) + (1 if weakness else 0) + (1 if weakness and m.has_relic("glass_tooth") else 0)
			p.shield = maxi(0,int(p.shield)-shield_hit)
			if int(p.shield) == 0:
				p.broken = true
				p.break_round = m.round_number
				p.break_consumed = false
				events.append({"kind":"break","part":target})
		hp = maxi(0,hp-damage)
		events.append({"kind":"hit","part":target,"hit":hit+1,"damage":damage,"height_match":height_match,"weakness":weakness})
	return {"part_after":p,"boss_after":hp,"damage":old_hp-int(p.hp),"titan_damage":int(m.boss.hp)-hp,"shield_loss":old_shield-int(p.shield),"breaks":not was_broken and p.broken,"height_match":height_match,"weakness":weakness,"hits":hits,"allocated_hits":allocated_hits,"execute_ready":bool(p.broken) and int(p.hp)==0,"events":events,"party_heal":party_heal}

static func act(m, hero: int, skill_index: int, target: int) -> bool:
	if m.phase != "battle": return m._reject("There is no battle in progress.")
	var result: Dictionary = preview(m,hero,skill_index,target)
	if not result.get("valid",false): return m._reject("Wait for this hero's turn, choose an intact target, and check MP.")
	var h: Dictionary = m.heroes[hero]
	var skill: Dictionary = h.skills[skill_index]
	var counter: bool = m.run.combat.mode == "counter"
	if skill_index == 3:
		var adopted: Dictionary = _historical("official_3755930_v0.2.78","defend.mp_grant",{"resolved_boundary":"defend_grant"})
		if not adopted.get("ok",false): return m._reject("Historical Defend evidence is unavailable.")
		h.guard = true
		h.mp = mini(int(h.max_mp),int(h.mp)+int(adopted.effects[0].amount))
		h.hp = mini(int(h.max_hp),int(h.hp)+int(result.heal))
		_record(m,{"kind":"defend","hero":hero,"mp":result.focus,"historical_source":adopted.source_id,"target_version_verified":false})
		m._note("%s defends: incoming damage halved; +%d MP." % [h.name,result.focus])
	else:
		var boost: int = 0 if counter else int(h.boost)
		h.mp = int(h.mp)-int(skill.cost)
		h.ep = int(h.ep)-boost
		h.spent_ep = bool(h.spent_ep) or boost > 0
		m.parts[target] = result.part_after
		m.boss.hp = result.boss_after
		for effect: Dictionary in result.events: _record(m,effect)
		if counter:
			var hook: Dictionary = _historical("official_4129400_v0.1.137","counter.normal_attack_relic_event",{"resolved_boundary":"resolved_counter","uses_normal_attack":true})
			_record(m,{"kind":"historical_counter_hook","source":hook.get("source_id",""),"effects":hook.get("effects",[]),"target_version_verified":false})
		if result.breaks and target == 0:
			m.boss.downed = true
			_update_heights(m)
		m._note("%s %s: %d hits, %d titan HP, %d limb HP, %d shields.%s" % [h.name,"COUNTER" if counter else skill.name,result.hits,result.titan_damage,result.damage,result.shield_loss," SEVER READY." if result.execute_ready else ""])
		if skill.name == "Blood Lantern": m._heal_party(7,false)
	_finish_action(m,hero,counter)
	return true

static func parry(m, hero: int, target: int) -> bool:
	if not _can_act(m,hero) or m.run.combat.mode != "turn" or target < 0 or target >= m.parts.size() or m.parts[target].severed or int(m.heroes[hero].mp) < PARRY_MP:
		return m._reject("Parry needs your turn, an intact height target and 5 MP.")
	var h: Dictionary = m.heroes[hero]
	h.mp = int(h.mp)-PARRY_MP
	h.parry_height = effective_height(m,target)
	_record(m,{"kind":"parry_stance","hero":hero,"height":h.parry_height})
	m._note("%s prepares %s PARRY. A matching incoming height grants a free Counter; a mismatch takes full damage." % [h.name,h.parry_height])
	_finish_action(m,hero,false)
	return true

static func sever(m, hero: int, target: int) -> bool:
	if not _can_act(m,hero) or m.run.combat.mode != "turn" or target < 0 or target >= m.parts.size(): return m._reject("Sever requires the current hero's normal turn.")
	var p: Dictionary = m.parts[target]
	if p.severed or not p.broken or int(p.hp) != 0 or int(m.heroes[hero].ep) < 1: return m._reject("Sever requires an exposed zero-HP limb and 1 EP.")
	m.heroes[hero].ep = int(m.heroes[hero].ep)-1
	m.heroes[hero].spent_ep = true
	p.severed = true
	m.boss.hp = maxi(0,int(m.boss.hp)-(12+int(m.boss.tier)*3))
	if target == 0:
		m.boss.collapsed = true
		m.boss.downed = false
		_update_heights(m)
	m.run.karma = int(m.run.karma)+1
	_record(m,{"kind":"sever","part":target,"hero":hero})
	m._note("SEVERED: %s. %s is permanently removed." % [p.name,p.move])
	_finish_action(m,hero,false)
	return true

static func _record(m, effect: Dictionary) -> void:
	m.run.combat.events.append(effect)
	if m.run.combat.events.size() > 80: m.run.combat.events.pop_front()

static func _finish_action(m, hero: int, counter: bool) -> void:
	m.heroes[hero].boost = 0
	m.last_error = ""
	if int(m.boss.hp) <= 0 or m._intact_parts().is_empty():
		m.run.combat.counter_queue.clear()
		m.run.combat.mode = "complete"
		m._win_battle()
		return
	if counter:
		m.run.combat.counter_queue.pop_front()
		if m.run.combat.counter_queue.is_empty():
			m.run.combat.mode = "turn"
			_advance_cursor(m)
	else:
		m.heroes[hero].acted = true
		_advance_cursor(m)

static func _advance_cursor(m) -> void:
	m.run.combat.cursor = int(m.run.combat.cursor)+1
	while int(m.run.combat.cursor) < m.run.combat.queue.size():
		var actor: int = int(m.run.combat.queue[int(m.run.combat.cursor)])
		if actor == -1 or int(m.heroes[actor].hp) > 0: return
		m.run.combat.cursor = int(m.run.combat.cursor)+1
	_next_round(m)

static func end_turn(m) -> bool:
	if m.phase != "battle": return m._reject("There is no battle in progress.")
	var actor: int = active(m)
	if actor >= 0:
		m._note("%s passes the %s." % [m.heroes[actor].name,"Counter" if m.run.combat.mode == "counter" else "turn"])
		_finish_action(m,actor,m.run.combat.mode == "counter")
		return true
	if actor != -1: return m._reject("No actor is ready.")
	var forecast: Dictionary = preview_intent(m)
	m.run.combat.enemy_resolved = true
	for p: Dictionary in m.parts:
		if p.broken: p.break_consumed = true
	for i in range(m.heroes.size()):
		m.heroes[i].hp = maxi(0,int(m.heroes[i].hp)-int(forecast.losses[i]))
	for attack: Dictionary in forecast.attacks:
		m._note("%s: %s" % [attack.name,attack.description])
	for counter_actor: int in forecast.counters:
		if int(m.heroes[counter_actor].hp) > 0:
			m.run.combat.counter_queue.append(counter_actor)
			_record(m,{"kind":"successful_parry","hero":counter_actor,"npc_eligible":false})
	if m._living_heroes().is_empty():
		m.phase = "defeat"
		m.title = "The oath falls silent"
		m.run.combat.mode = "complete"
		m._settle_run(false)
		return true
	if not m.run.combat.counter_queue.is_empty():
		m.run.combat.mode = "counter"
		m._note("PARRY SUCCESS: choose Q and a reachable height for the hero's Counter. No NPC or recursive Counter.")
	else: _advance_cursor(m)
	m.last_error = ""
	return true

static func preview_intent(m) -> Dictionary:
	var result: Dictionary = {"status":"cancelled","losses":[0,0,0],"focus_losses":[0,0,0],"source":"","description":"","attacks":[],"rhythm":{},"counters":[]}
	var remaining: Array = []
	for h: Dictionary in m.heroes: remaining.append(int(h.hp))
	for attack: Dictionary in m.get_intent_attacks():
		var p: Dictionary = m.parts[int(attack.part)]
		var cancelled: bool = p.severed or p.broken or bool(m.run.combat.enemy_resolved)
		var status: String = "cancelled" if cancelled else "incoming"
		var losses: Array = [0,0,0]
		var lines: Array[String] = []
		var parried: Array = []
		if cancelled: lines.append("Source severed, broken, or already resolved: no attack.")
		for target_value: Variant in attack.targets:
			var target: int = int(target_value)
			var h: Dictionary = m.heroes[target]
			if cancelled or int(remaining[target]) <= 0: continue
			if str(h.parry_height) == effective_height(m,int(attack.part)):
				lines.append("%s PARRY: 0 HP / Counter" % h.name)
				parried.append(target)
				if target not in result.counters: result.counters.append(target)
				status = "warded"
				continue
			var damage: int = int(ceil(float(attack.damage)*(0.5 if h.guard else 1.0)))
			losses[target] = mini(int(remaining[target]),damage)
			remaining[target] = int(remaining[target])-int(losses[target])
			result.losses[target] += int(losses[target])
			lines.append("%s -%d HP%s" % [h.name,losses[target]," / guarded" if h.guard else ""])
		if not cancelled: result.status = status
		result.attacks.append({"name":attack.name,"part":attack.part,"source":p.name,"source_status":"cancelled" if cancelled else "incoming","status":status,"targets":attack.targets.duplicate(),"wardable":false,"damage":attack.damage,"losses":losses,"focus_losses":[0,0,0],"parried":parried,"description":"; ".join(lines),"counterplay":"Break cancels this phase; Sever removes the source. Defend halves; matching-height Parry counters."})
	var living_counters: Array = []
	for hero: int in result.counters:
		if int(remaining[hero]) > 0: living_counters.append(hero)
	result.counters = living_counters
	if int(result.losses[0])+int(result.losses[1])+int(result.losses[2]) > 0: result.status = "incoming"
	if not result.attacks.is_empty():
		result.source = str(result.attacks[0].source)
		result.description = str(result.attacks[0].description)
	return result

static func _next_round(m) -> void:
	if m.has_relic("hollow_bell"): m._heal_party(3,false)
	m.round_number += 1
	for h: Dictionary in m.heroes:
		if int(h.hp) > 0 and not bool(h.spent_ep): h.ep = mini(EP_MAX,int(h.ep)+EP_RECOVERY)
		h.spent_ep = false
		h.boost = 0
		h.guard = false
		h.parry_height = ""
		h.acted = false
	for p: Dictionary in m.parts:
		if p.broken and p.break_consumed and not p.severed and int(p.hp) > 0:
			p.broken = false
			p.shield = p.max_shield
		p.break_consumed = false
	m.boss.downed = bool(m.parts[0].broken) and not bool(m.parts[0].severed)
	_update_heights(m)
	_build_queue(m)
	_prepare_intent(m)
	m._note("ROUND %d: unspent heroes recover 2 EP; surviving broken limbs regain shields." % m.round_number)

static func _prepare_intent(m) -> void:
	var intact: Array = m._intact_parts()
	var part: int = int(intact[(m.round_number-1)%intact.size()]) if not intact.is_empty() else 0
	var living: Array = m._living_heroes()
	var target: int = int(living[(m.round_number-1)%living.size()]) if not living.is_empty() else 0
	m.intent = {"part":part,"name":m.parts[part].move,"damage":16+int(m.boss.tier)*5,"targets":[target],"wardable":false}
	if int(m.boss.tier) >= 2 and m.round_number%2 == 0 and intact.size() > 1:
		var other: int = int(intact[(intact.find(part)+1)%intact.size()])
		m.intent.secondary = {"part":other,"name":m.parts[other].move,"damage":12+int(m.boss.tier)*4,"targets":[living[(living.find(target)+1)%living.size()]],"wardable":false}

static func _historical(source: String, rule: String, event: Dictionary) -> Dictionary:
	if historical_manifest.is_empty(): historical_manifest = HistoricalEffects.read_manifest()
	return HistoricalEffects.resolve(historical_manifest,source,rule,event)
