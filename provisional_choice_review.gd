extends SceneTree
## Independent scripted choice comparison for Ashen's provisional combat.
## No target-game parity or human-playability claim. Run via the shell wrapper.
const CurrentModel = preload("res://model.gd")
const BASELINE_MODEL := "res://.runtime/choice-baseline/model.gd"
const PROFILE := "ashen_provisional_v1"
const BASELINE_COMMIT := "597788546b80f6deecfed0e0488f4bd37b26caff"
const MAX_CAMPAIGN_STEPS := 4000
const MAX_BATTLE_ROUNDS := 500
var output_dir := ""
var first_seed := 81
var last_seed := 100
var baseline_script
var campaigns: Array = []
var battles: Array = []
var failures: Array[String] = []
var fixture_index := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
		elif arg.begins_with("--first-seed="): first_seed = int(arg.trim_prefix("--first-seed="))
		elif arg.begins_with("--last-seed="): last_seed = int(arg.trim_prefix("--last-seed="))
	if output_dir.is_empty() or first_seed > last_seed:
		push_error("CHOICE REVIEW FAIL: provide --output and a valid seed range through scripts/review-provisional-choices.sh")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("CHOICE REVIEW FAIL: cannot create output directory")
		quit(2)
		return
	baseline_script = load(BASELINE_MODEL)
	if baseline_script == null:
		push_error("CHOICE REVIEW FAIL: baseline model missing; use the shell wrapper")
		quit(2)
		return
	for seed_value in range(first_seed,last_seed+1):
		var seed_campaigns: Array = []
		var plan: Dictionary = {}
		for variant: String in ["baseline","candidate"]:
			for strategy: String in ["A","B"]:
				var result: Dictionary = play_campaign(seed_value,variant,strategy,plan)
				if plan.is_empty(): plan = result.plan.duplicate(true)
				seed_campaigns.append(result)
				campaigns.append(result)
				print("CHOICE seed=%d code=%s strategy=%s result=%s steps=%d damage=%d rounds=%d rejected=%d softlock=%s" % [seed_value,variant,strategy,result.outcome,result.steps,result.damage_taken,result.enemy_phases,result.rejected,str(result.softlock)])
		_verify_matching_decisions(seed_value,seed_campaigns)
	var summary: Array = _summary()
	var report: Dictionary = {
		"schema":1,"baseline_commit":BASELINE_COMMIT,"engine":Engine.get_version_info().string,
		"seeds":{"first":first_seed,"last":last_seed},"classification":"ashen_provisional_scripted_comparison",
		"target_parity_verified":false,"human_playability_verified":false,
		"strategy_A":"Existing selftest offensive policy: explicit Sever first, Defend below 10 MP, up to 2 Boost, W on odd rounds/E on even rounds if affordable, best preview score.",
		"strategy_B":"Existing safe policy: threatened heroes Parry the height preventing most advertised damage, others Defend; strongest legal normal Counter. If every remaining limb has zero HP, finish via a legal direct Q or explicit Sever, otherwise Defend to recover EP.",
		"shared_plan":"One seeded campaign layout per seed; same fixed map and reward indices, first affordable event option. Shared prefixes of actual map/reward/event decisions are checked across all four runs.",
		"measurement":"damage_taken is the per-target HP loss actually applied by enemy resolution, before any same-boundary healing; rounds_started and enemy_phases are reported separately. Allocation commands are separate from attack counts.",
		"limits":{"campaign_steps":MAX_CAMPAIGN_STEPS,"battle_rounds":MAX_BATTLE_ROUNDS},
		"summary":summary,"campaigns":campaigns,"battles":battles,"failures":failures,
	}
	_write_json(output_dir.path_join("choice-review.json"),report)
	_write_csv(output_dir.path_join("campaigns.csv"),campaigns,["seed","variant","strategy","outcome","node","steps","battles_entered","battles_won","damage_taken","enemy_phases","direct_attacks","boost_attacks","boost_ep","severs","parries","defends","counters","passes","rejected","softlock","validation_failures"])
	_write_csv(output_dir.path_join("battles.csv"),battles,["seed","variant","strategy","node","name","tier","milestone","outcome","rounds_started","enemy_phases","damage_taken","body_damage","direct_attacks","boost_attacks","boost_ep","severs","parries","defends","counters","passes","counter_passes","allocation_commands","mp_spent","ep_spent","healing_received","deaths","rejected","softlock","start_hp","end_hp","start_mp","end_mp","start_ep","end_ep"])
	_write_summary(output_dir.path_join("summary.txt"),summary)
	for failure: String in failures: push_error("CHOICE REVIEW FAIL: " + failure)
	print("CHOICE REVIEW: %d campaigns, %d battles, %d failures. Scripted Ashen comparison only; no target parity or human-playability claim." % [campaigns.size(),battles.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)

func fresh(seed_value: int, variant: String):
	fixture_index += 1
	var m = baseline_script.new() if variant == "baseline" else CurrentModel.new()
	m.persist_meta = false
	m.meta_path = "user://choice-review-%d-meta.json" % fixture_index
	m._resume_path = "user://choice-review-%d-journey.save" % fixture_index
	m._save_revision = 0
	m.meta = {"essence":0,"upgrades":{"vitality":0,"force":0,"focus":0},"runs":1,"wins":0}
	if not m.new_run(seed_value,PROFILE): failures.append("Could not initialize %s seed %d" % [variant,seed_value])
	return m

func make_plan(m, seed_value: int) -> Dictionary:
	var route: Array = []
	for node: Dictionary in m.campaign:
		var pick := 0
		for i in range(node.choices.size()):
			if node.choices[i].kind in ["battle","boss"]: pick = i
		route.append(pick)
	return {"map_indices":route,"reward_index":0 if seed_value%2 == 0 else 2,"campaign_layout":m.campaign.duplicate(true)}

func play_campaign(seed_value: int, variant: String, strategy: String, shared_plan: Dictionary) -> Dictionary:
	var m = fresh(seed_value,variant)
	var plan: Dictionary = make_plan(m,seed_value) if shared_plan.is_empty() else shared_plan.duplicate(true)
	if m.campaign != plan.campaign_layout:
		failures.append("Campaign layout differs for seed %d %s/%s" % [seed_value,variant,strategy])
	var run_result: Dictionary = {"seed":seed_value,"variant":variant,"strategy":strategy,"plan":plan,"decisions":[],"battle_indices":[],"steps":0,"rejected":0,"softlock":false,"validation_failures":0}
	var battle: Dictionary = {}
	while m.phase not in ["victory","defeat"] and int(run_result.steps) < MAX_CAMPAIGN_STEPS:
		run_result.steps += 1
		if m.phase == "battle" and battle.is_empty(): battle = new_battle(m,seed_value,variant,strategy)
		if not battle.is_empty() and m.round_number > MAX_BATTLE_ROUNDS:
			run_result.softlock = true
			battle.softlock = true
			failures.append("Battle exceeded round bound: seed %d %s/%s node %d" % [seed_value,variant,strategy,m.run.node])
			break
		var accepted := false
		match m.phase:
			"map":
				var choice: int = int(plan.map_indices[int(m.run.node)])
				run_result.decisions.append({"node":int(m.run.node),"phase":"map","index":choice,"kind":str(m.choices[choice].kind)})
				accepted = m.travel(choice)
				if accepted and m.phase == "battle": battle = new_battle(m,seed_value,variant,strategy)
			"battle": accepted = battle_step(m,battle,strategy)
			"reward":
				var choice: int = int(plan.reward_index)
				run_result.decisions.append({"node":int(m.run.node),"phase":"reward","index":choice})
				accepted = m.choose_reward(choice)
			"event", "camp", "relic":
				var choice := -1
				for i in range(m.event.options.size()):
					if int(m.event.options[i].get("cost",0)) <= int(m.run.gold):
						choice = i
						break
				if choice >= 0:
					run_result.decisions.append({"node":int(m.run.node),"phase":m.phase,"index":choice})
					accepted = m.choose_event(choice)
		if not accepted:
			run_result.rejected += 1
			if not battle.is_empty(): battle.rejected += 1
			failures.append("Rejected decision seed %d %s/%s step %d: %s" % [seed_value,variant,strategy,run_result.steps,m.last_error])
			break
		if not m._valid_journey(m._journey_snapshot()):
			run_result.validation_failures += 1
			failures.append("Invalid snapshot seed %d %s/%s step %d" % [seed_value,variant,strategy,run_result.steps])
			break
		if not battle.is_empty() and m.phase != "battle":
			finish_battle(m,battle,"win" if m.phase == "reward" else m.phase)
			run_result.battle_indices.append(battles.size()-1)
			battle = {}
	if m.phase not in ["victory","defeat"] and int(run_result.rejected) == 0 and int(run_result.validation_failures) == 0:
		run_result.softlock = true
		failures.append("Campaign did not terminate seed %d %s/%s after %d steps" % [seed_value,variant,strategy,run_result.steps])
	if not battle.is_empty():
		battle.softlock = bool(run_result.softlock)
		finish_battle(m,battle,"softlock" if run_result.softlock else "blocked")
		run_result.battle_indices.append(battles.size()-1)
	run_result.outcome = m.phase if m.phase in ["victory","defeat"] else ("softlock" if run_result.softlock else "blocked")
	run_result.node = int(m.run.node)
	run_result.battles_entered = run_result.battle_indices.size()
	run_result.battles_won = int(m.run.battles_won)
	for key: String in ["damage_taken","enemy_phases","direct_attacks","boost_attacks","boost_ep","severs","parries","defends","counters","passes"]:
		run_result[key] = 0
		for index: int in run_result.battle_indices: run_result[key] += int(battles[index][key])
	run_result.final_hp = hero_values(m,"hp")
	run_result.final_mp = hero_values(m,"mp")
	run_result.final_ep = hero_values(m,"ep")
	return run_result

func hero_values(m, field: String) -> Array:
	var values: Array = []
	for h: Dictionary in m.heroes: values.append(int(h[field]))
	return values

func new_battle(m, seed_value: int, variant: String, strategy: String) -> Dictionary:
	return {"seed":seed_value,"variant":variant,"strategy":strategy,"node":int(m.run.node),"name":str(m.boss.name),"tier":int(m.boss.tier),"milestone":bool(m.boss.milestone),"start_hp":hero_values(m,"hp"),"start_mp":hero_values(m,"mp"),"start_ep":hero_values(m,"ep"),"rounds_started":1,"enemy_phases":0,"damage_taken":0,"damage_by_hero":[0,0,0],"body_damage":0,"direct_attacks":0,"boost_attacks":0,"boost_ep":0,"severs":0,"parries":0,"defends":0,"counters":0,"passes":0,"counter_passes":0,"allocation_commands":0,"mp_spent":0,"ep_spent":0,"healing_received":0,"deaths":0,"rejected":0,"softlock":false,"trace":[]}

func finish_battle(m, battle: Dictionary, outcome: String) -> void:
	battle.outcome = outcome
	battle.rounds_started = int(m.round_number)
	battle.end_hp = hero_values(m,"hp")
	battle.end_mp = hero_values(m,"mp")
	battle.end_ep = hero_values(m,"ep")
	battle.end_body_hp = int(m.boss.hp)
	battle.end_parts = m.parts.duplicate(true)
	battles.append(battle.duplicate(true))

func best_attack(m, actor: int, skill: int) -> int:
	var best := -1
	var best_score := -1
	for target in range(m.parts.size()):
		var p: Dictionary = m.preview_action(actor,skill,target)
		if not p.get("valid",false): continue
		var score: int = int(p.titan_damage)+2*int(p.damage)+(35 if p.breaks else 0)+(30 if p.execute_ready else 0)
		if score > best_score:
			best = target
			best_score = score
	return best

func first_sever(m, actor: int) -> int:
	if int(m.heroes[actor].ep) < 1: return -1
	for i in range(m.parts.size()):
		var p: Dictionary = m.parts[i]
		if not p.severed and p.broken and int(p.hp) == 0: return i
	return -1

func all_remaining_zero(m) -> bool:
	for p: Dictionary in m.parts:
		if not p.severed and int(p.hp) > 0: return false
	return true

func best_parry_target(m, actor: int) -> int:
	var by_height: Dictionary = {}
	var target_by_height: Dictionary = {}
	var forecast: Dictionary = m.preview_intent()
	for attack: Dictionary in forecast.attacks:
		if attack.get("source_status","") == "cancelled" or attack.get("status","") == "cancelled" or actor not in attack.targets: continue
		var part: int = int(attack.part)
		var height: String = str(m.parts[part].level)
		by_height[height] = int(by_height.get(height,0))+int(attack.damage)
		if not target_by_height.has(height): target_by_height[height] = part
	var best := -1
	var maximum := -1
	# Stable public height order is used only to break equal prevention ties.
	for height: String in ["LOW","MID","HIGH"]:
		if by_height.has(height) and int(by_height[height]) > maximum:
			maximum = int(by_height[height])
			best = int(target_by_height[height])
	return best

func battle_step(m, battle: Dictionary, strategy: String) -> bool:
	var actor: int = m.active_actor()
	if actor == -1: return command(m,battle,"enemy")
	if actor < 0: return false
	if m.run.combat.mode == "counter":
		var target: int = best_attack(m,actor,0)
		return command(m,battle,"counter",actor,0,target) if target >= 0 else command(m,battle,"pass",actor)
	if strategy == "A":
		var sever_target: int = first_sever(m,actor)
		if sever_target >= 0: return command(m,battle,"sever",actor,-1,sever_target)
		if int(m.heroes[actor].mp) < 10: return command(m,battle,"defend",actor,3,0)
		var boost: int = mini(2,int(m.heroes[actor].ep))
		if not command(m,battle,"allocate",actor,boost): return false
		var skill := 0
		var requested: int = 1 if m.round_number%2 == 1 else 2
		if int(m.heroes[actor].mp) >= int(m.heroes[actor].skills[requested].cost): skill = requested
		var target: int = best_attack(m,actor,skill)
		return command(m,battle,"attack",actor,skill,target) if target >= 0 else command(m,battle,"pass",actor)
	# Safe policy needs a terminal cleanup once no remaining source can ever act.
	# This uses identical logic on both variants: old legal stump Q, or new Sever.
	if all_remaining_zero(m):
		var target: int = best_attack(m,actor,0)
		if target >= 0: return command(m,battle,"attack",actor,0,target)
		var sever_target: int = first_sever(m,actor)
		if sever_target >= 0: return command(m,battle,"sever",actor,-1,sever_target)
		return command(m,battle,"defend",actor,3,0)
	var parry_target: int = best_parry_target(m,actor)
	if parry_target >= 0 and int(m.heroes[actor].mp) >= 5:
		return command(m,battle,"parry",actor,-1,parry_target)
	return command(m,battle,"defend",actor,3,0)

func command(m, battle: Dictionary, kind: String, actor: int = -1, skill: int = -1, target: int = -1) -> bool:
	var before_hp: Array = hero_values(m,"hp")
	var before_mp: Array = hero_values(m,"mp")
	var before_body: int = int(m.boss.hp)
	var mode_before: String = str(m.run.combat.mode)
	var round_before: int = int(m.round_number)
	var applied: Array = [0,0,0]
	var boost := 0
	if kind == "enemy": applied = m.preview_intent().losses.duplicate()
	if kind == "attack": boost = int(m.heroes[actor].boost)
	var accepted := false
	match kind:
		"enemy", "pass": accepted = m.end_round()
		"allocate": accepted = m.allocate_boost(actor,skill)
		"attack", "counter", "defend": accepted = m.act(actor,skill,target)
		"parry": accepted = m.parry(actor,target)
		"sever": accepted = m.sever(actor,target)
	battle.trace.append({"step":battle.trace.size()+1,"round":round_before,"mode":mode_before,"actor":actor,"command":kind,"skill_or_allocation":skill,"target":target,"accepted":accepted,"body_before":before_body,"body_after":int(m.boss.hp),"hp_before":before_hp,"hp_after":hero_values(m,"hp"),"mp_after":hero_values(m,"mp"),"ep_after":hero_values(m,"ep"),"applied_enemy_losses":applied,"error":"" if accepted else m.last_error})
	if not accepted: return false
	if not m._valid_journey(m._journey_snapshot()):
		failures.append("Invalid state after %s seed %d %s/%s node %d round %d" % [kind,battle.seed,battle.variant,battle.strategy,battle.node,round_before])
		return false
	match kind:
		"enemy": battle.enemy_phases += 1
		"pass":
			battle.passes += 1
			if mode_before == "counter": battle.counter_passes += 1
		"allocate": battle.allocation_commands += 1
		"attack":
			battle.direct_attacks += 1
			if boost > 0: battle.boost_attacks += 1
			battle.boost_ep += boost
			battle.ep_spent += boost
		"counter": battle.counters += 1
		"defend": battle.defends += 1
		"parry": battle.parries += 1
		"sever":
			battle.severs += 1
			battle.ep_spent += 1
	battle.body_damage += maxi(0,before_body-int(m.boss.hp))
	for i in range(m.heroes.size()):
		battle.damage_taken += int(applied[i])
		battle.damage_by_hero[i] += int(applied[i])
		battle.mp_spent += maxi(0,int(before_mp[i])-int(m.heroes[i].mp))
		battle.healing_received += maxi(0,int(m.heroes[i].hp)-int(before_hp[i])+int(applied[i]))
		if int(before_hp[i]) > 0 and int(m.heroes[i].hp) == 0: battle.deaths += 1
	return true

func _verify_matching_decisions(seed_value: int, results: Array) -> void:
	for i in range(results.size()):
		for j in range(i+1,results.size()):
			var a: Array = results[i].decisions
			var b: Array = results[j].decisions
			for step in range(mini(a.size(),b.size())):
				if a[step] != b[step]:
					failures.append("Map/reward/event plan diverged seed %d at choice %d between %s/%s and %s/%s" % [seed_value,step,results[i].variant,results[i].strategy,results[j].variant,results[j].strategy])
					break

func _summary() -> Array:
	var rows: Array = []
	for variant: String in ["baseline","candidate"]:
		for strategy: String in ["A","B"]:
			var row: Dictionary = {"variant":variant,"strategy":strategy,"campaigns":0,"wins":0,"defeats":0,"blocked":0,"softlocks":0,"rejected":0,"battles":0,"won_battles":0,"damage_taken":0,"enemy_phases":0,"direct_attacks":0,"boost_attacks":0,"boost_ep":0,"severs":0,"parries":0,"defends":0,"counters":0}
			for campaign: Dictionary in campaigns:
				if campaign.variant != variant or campaign.strategy != strategy: continue
				row.campaigns += 1
				if campaign.outcome == "victory": row.wins += 1
				elif campaign.outcome == "defeat": row.defeats += 1
				else: row.blocked += 1
				if campaign.softlock: row.softlocks += 1
				row.battles += int(campaign.battles_entered)
				row.won_battles += int(campaign.battles_won)
				for key: String in ["damage_taken","enemy_phases","direct_attacks","boost_attacks","boost_ep","severs","parries","defends","counters","rejected"]: row[key] += int(campaign[key])
			row.mean_damage_per_battle = float(row.damage_taken)/maxi(1,int(row.battles))
			row.mean_enemy_phases_per_battle = float(row.enemy_phases)/maxi(1,int(row.battles))
			rows.append(row)
	return rows

func _write_json(path: String, value: Variant) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write " + path)
		return
	file.store_string(JSON.stringify(value,"  ")+"\n")
	file.close()

func _write_csv(path: String, rows: Array, columns: Array) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write " + path)
		return
	var heading := PackedStringArray()
	for column: String in columns: heading.append(column)
	file.store_csv_line(heading)
	for row: Dictionary in rows:
		var line := PackedStringArray()
		for column: String in columns:
			var value: Variant = row.get(column,"")
			line.append(JSON.stringify(value) if value is Array or value is Dictionary else str(value))
		file.store_csv_line(line)
	file.close()

func _write_summary(path: String, rows: Array) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write " + path)
		return
	file.store_line("Ashen provisional scripted strategy comparison")
	file.store_line("Baseline: " + BASELINE_COMMIT)
	file.store_line("Seeds %d..%d. No target-game parity or human-playability claim." % [first_seed,last_seed])
	file.store_line("A = offensive/Sever policy; B = Parry/Defend/Counter policy with terminal cleanup.")
	for row: Dictionary in rows:
		file.store_line("%s/%s: %d wins, %d defeats; %d battles; damage %d; enemy phases %d; direct %d; boosted %d (%d EP); Sever %d; Parry %d; Defend %d; Counter %d; rejected %d; softlocks %d" % [row.variant,row.strategy,row.wins,row.defeats,row.battles,row.damage_taken,row.enemy_phases,row.direct_attacks,row.boost_attacks,row.boost_ep,row.severs,row.parries,row.defends,row.counters,row.rejected,row.softlocks])
	file.store_line("Totals are exposure-dependent: defeated campaigns play fewer battles. Compare matched seed/node battle rows before judging damage or speed.")
	file.store_line("All raw campaign/battle states and decision traces are in choice-review.json; no balance recommendation is inferred automatically.")
	file.store_line("Failures: %d" % failures.size())
	for failure: String in failures: file.store_line(failure)
	file.close()
