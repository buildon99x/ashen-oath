extends SceneTree
## Exact forecasts and interrupted-input safeguards, not a visual playtest.
const Model = preload("res://model.gd")
var checks: int = 0
func check(value: bool, context: String) -> void:
	checks += 1
	assert(value, context)
func fresh(tier: int = 1):
	var m = Model.new()
	m.persist_meta = false
	m.meta = {"essence":0,"upgrades":{"vitality":0,"force":0,"focus":0},"runs":0,"wins":0}
	m.new_run(1)
	m.start_battle(tier)
	return m
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	# Every hero/attack/target, in shielded, exposed and one-HP sever states.
	for tier in [1,2,3]:
		for hero in range(3):
			for skill in range(3):
				for target in range(3):
					for state in range(3):
						var m = fresh(tier)
						if state > 0:
							m.parts[target].broken = true
							m.parts[target].shield = 0
						if state == 2: m.parts[target].hp = 1
						var before: Dictionary = m.describe()
						var rng_before: int = m.rng.state
						var p: Dictionary = m.preview_action(hero,skill,target)
						check(m.describe()==before and m.rng.state==rng_before,"Forecast is read-only")
						var hp: int = m.parts[target].hp
						var core: int = m.boss.hp
						var shield: int = m.parts[target].shield
						check(m.act(hero,skill,target),"Forecasted action is accepted")
						check(hp-m.parts[target].hp==p.damage and core-m.boss.hp==p.titan_damage and shield-m.parts[target].shield==p.shield_loss,"Damage and shield forecast match the actual action")
	for source in range(3):
		for source_state in range(3):
			var m = fresh(3)
			m.intent={"part":source,"damage":19,"targets":[0,1,2],"name":"Test omen"}
			m.parts[source].broken=source_state>0
			m.parts[source].severed=source_state==2
			m.heroes[1].guard=true
			var p: Dictionary=m.preview_intent()
			var hp: Array=[]
			var mp: Array=[]
			for hero in m.heroes:
				hp.append(hero.hp)
				mp.append(hero.mp)
			m.end_round()
			for h in range(3):
				check(hp[h]-m.heroes[h].hp==p.losses[h],"Omen predicts stagger, cancel and guard exactly")
	var abandoned=fresh()
	abandoned.run.essence=9
	abandoned.meta.essence=12
	abandoned.new_run(1)
	check(abandoned.meta.essence==12 and abandoned.run.essence==0 and abandoned.meta.runs==1,"Restart counts the abandoned cycle without farming unbanked essence")
	var collector=fresh()
	collector.run.relics=Model.RELICS.duplicate(true)
	collector._win_battle()
	check("4 unbanked ash" in collector.rewards[2].description,"Full collection advertises the real battle reward")
	collector._open_event("relic")
	check("4 unbanked ash" in collector.event.options[0].description,"Full collection advertises the real shrine reward")
	collector._open_event("event")
	check("7 unbanked ash" in collector.event.options[1].description,"Full collection advertises sacrifice plus echo correctly")
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.muted=true
	scene.model=fresh()
	scene.model.phase="title"
	scene.model.heroes.clear()
	scene.menu=true
	var escape=InputEventKey.new()
	escape.pressed=true
	escape.keycode=KEY_ESCAPE
	scene._unhandled_key_input(escape)
	check(scene.menu,"Escape cannot leave a fresh title screen blank")
	scene.begin_run()
	# This suite protects legacy saved-journey whole-round safeguards.
	scene.model=fresh()
	scene.model.start_battle(1)
	scene.request_end_round()
	check(scene.confirmation=="end_round" and scene.model.round_number==1,"Unspent actions open confirmation without advancing")
	var space=InputEventKey.new()
	space.pressed=true
	space.keycode=KEY_SPACE
	scene._unhandled_key_input(space)
	check(scene.model.round_number==1,"Repeated Space cannot accidentally confirm")
	scene._unhandled_key_input(escape)
	check(scene.confirmation.is_empty() and not scene.menu,"Escape cancels early-end dialog into battle")
	scene.request_end_round()
	scene.confirm_action()
	check(scene.model.round_number==2,"Explicit confirmation advances exactly one round")
	scene.request_new_cycle()
	check(scene.confirmation=="new_cycle" and scene.model.round_number==2,"New Cycle preserves current journey pending confirmation")
	scene.confirmation=""
	var inspect=InputEventKey.new()
	inspect.pressed=true
	inspect.keycode=KEY_B
	scene._unhandled_key_input(inspect)
	check(scene.build_open,"Build can be inspected during a battle")
	scene._unhandled_key_input(space)
	check(scene.model.round_number==2,"Build overlay blocks battle shortcuts")
	scene._unhandled_key_input(escape)
	check(not scene.build_open and not scene.menu,"Closing build returns to the same battle")
	scene.model.phase="victory"
	scene.refresh()
	await process_frame
	check(not scene.generated_monster.visible and scene.actors[0].visible and scene.actors[0].facing=="down","Victory shows the party instead of a living default monster")
	scene.audio.stop()
	scene.audio.stream=null
	scene.queue_free()
	await process_frame
	print("TACTICAL FORECAST / SAFEGUARD TESTS PASSED: ", checks)
	quit()
