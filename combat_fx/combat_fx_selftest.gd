extends SceneTree
const Model = preload("res://model.gd")
const Snapshot = preload("res://combat_fx/combat_fx_snapshot.gd")
const Event = preload("res://combat_fx/combat_fx_event.gd")
const Director = preload("res://combat_fx/combat_fx_director.gd")
const Main = preload("res://main.tscn")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		push_error("FX FAIL: "+text)
func _initialize() -> void:
	call_deferred("run")
func fixture(tier: int = 2):
	var m = Model.new()
	m.persist_meta=false
	m._clear_journey()
	m.meta={"essence":10,"runs":3,"wins":1,"upgrades":{"vitality":0,"force":0,"focus":0}}
	m.new_run(78231)
	m.start_battle(tier)
	return m
func state(m) -> PackedByteArray:
	return var_to_bytes({"phase":m.phase,"run":m.run,"meta":m.meta,"boss":m.boss,"parts":m.parts,"heroes":m.heroes,"intent":m.intent,"log":m.log,"rng":str(m.rng.state)})
func run() -> void:
	root.size=Vector2i(1440,900)
	for hero in range(3):
		for skill in range(4):
			for part in range(3):
				for outcome in range(3):
					var m=fixture()
					m.heroes[hero].hp-=4
					if outcome==1: m.parts[part].shield=1
					if outcome==2:
						m.parts[part].broken=true
						m.parts[part].shield=0
						m.parts[part].hp=2
					var prior=state(m)
					var before=Snapshot.capture(m)
					check(state(m)==prior,"snapshot is read-only")
					check(m.act(hero,skill,part),"matrix action accepted")
					var after=Snapshot.capture(m)
					var actual=state(m)
					var e=Event.hero_event(57,before,after,hero,skill,part)
					check(state(m)==actual,"event construction consumes no RNG or state")
					check(e.skill_id==Event.SKILLS[hero][skill],"explicit stable skill identity")
					check(e.actual_boss_loss==maxi(0,int(before.boss.hp)-int(after.boss.hp)),"actual boss delta")
					if skill!=3:
						check(e.actual_hp_loss==before.parts[part].hp-after.parts[part].hp,"actual part delta")
						check(e.actual_shield_loss==before.parts[part].shield-after.parts[part].shield,"actual shield delta")
						check(e.breaks==(not before.parts[part].broken and after.parts[part].broken),"actual break transition")
						check(e.severs==(not before.parts[part].severed and after.parts[part].severed),"actual sever transition")
					var d=Director.new()
					d.enqueue([e])
					check(d.view.boss==before.boss,"before value visible before marker")
					d.advance(0.30 if skill!=3 else 0.05)
					check(d.impact_count==0,"no premature impact")
					if skill!=3:
						d.impact((hero+1)%3)
						check(d.impact_count==0,"unrelated actor event ignored")
						d.impact(hero)
						d.impact(hero)
					else: d.advance(0.1)
					check(d.impact_count==1,"one impact only")
					check(d.view.boss==after.boss,"after value displayed at impact")
					d.skip()
					check(not d.busy() and d.view==null,"skip releases value cache")
					check(state(m)==actual,"presentation never changes rules result")
					d.free()
	await test_scene()
	print("COMBAT FX: %d checks; %d failures. Presentation/event tests, not audio or FPS evidence." % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
func reset_scene(scene,tier: int = 2) -> void:
	scene.fx_director.clear()
	scene.fx_pending_finisher.clear()
	scene.finisher_remaining=0
	scene.model=fixture(tier)
	scene.menu=false
	scene.coach_eligible=false
	scene.coach_open=false
	scene.help_open=false
	scene.details_open=false
	scene.build_open=false
	scene.save_error_open=false
	scene.recovery_notice_open=false
	scene.confirmation=""
	scene.selected_hero=0
	scene.selected_part=1
	scene.refresh(false)
func test_scene() -> void:
	var scene=Main.instantiate()
	scene.muted=true
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for actor in scene.actors: actor.set_process(false)
	reset_scene(scene)
	var before=state(scene.model)
	var before_hp=scene.model.boss.hp
	scene.perform(2)
	var accepted=state(scene.model)
	check(accepted!=before,"rules commit at input, not at impact")
	check(scene.fx_busy(),"native timeline default enabled")
	check(scene.battle_view().boss.hp==before_hp,"HUD holds actual pre-hit state")
	check(scene.model.boss.hp<before_hp,"real model already has damage")
	scene.perform(0)
	scene.finish_round()
	scene.select_hero(2)
	scene.travel(0)
	check(state(scene.model)==accepted,"fast gameplay input cannot spend another action")
	check(scene.selected_hero==0,"selection held for the animated actor")
	var prior_count=scene.fx_director.impact_count
	scene.actors[0].advance(4.0/12.0-0.001)
	check(scene.fx_director.impact_count==prior_count,"no FX before actual frame-four marker")
	scene.actors[0].advance(0.001)
	check(scene.fx_director.impact_count==prior_count+1,"actor frame-four marker triggers FX")
	check(scene.battle_view().boss.hp==scene.model.boss.hp,"HP switches on the same impact callback")
	check(scene.actors[0].playback_speed==0,"hitstop is local to actor")
	check(Engine.time_scale==1.0,"global game time never changes")
	scene.skip_combat_presentation()
	check(not scene.presentation_active() and scene.actors[0].playback_speed==1,"skip releases actor and input")
	check(state(scene.model)==accepted,"skip never replays action")
	# Deep-copy guard: saved before state does not acquire subsequent model edits.
	var frozen=Snapshot.capture(scene.model)
	var frozen_hp=frozen.heroes[0].hp
	scene.model.heroes[0].hp-=1
	check(frozen.heroes[0].hp==frozen_hp,"display snapshots do not alias live dictionaries")
	# Genuine rules forecast drives sequential per-source display, including wards.
	for tier in [2,3]:
		for mode in ["incoming","warded","cancelled","missed","lethal","bell"]:
			reset_scene(scene,tier)
			scene.model.round_number=2
			scene.model._prepare_intent()
			# Explicit fixture keeps primary and secondary independently inspectable.
			scene.model.intent={"name":"First","part":0,"targets":[0,1,2],"damage":9,"wardable":false,"secondary":{"name":"Second","part":2,"targets":[0],"damage":12,"wardable":true},"rhythm":{"id":"release","name":"Zenith Release"}}
			if mode=="warded": scene.model.heroes[0].guard=true
			if mode=="cancelled": scene.model.parts[2].severed=true
			if mode=="missed": scene.model.heroes[0].hp=0
			if mode=="lethal": scene.model.heroes[0].hp=5
			if mode=="bell": scene.model.run.relics.append(Model.RELICS[1].duplicate(true))
			var snap=Snapshot.capture(scene.model)
			var forecast=scene.model.preview_intent().duplicate(true)
			scene.finish_round()
			var resolved=state(scene.model)
			check(scene.fx_director.current.attack.part==0,"primary uses its source")
			scene.fx_director.advance(0.20)
			for h in range(3): check(scene.battle_view().heroes[h].hp==snap.heroes[h].hp-int(forecast.attacks[0].losses[h]),"first-source loss uses fixed target")
			scene.fx_director.advance(0.25)
			check(scene.fx_director.current.attack.part==2,"secondary uses separate source")
			for h in range(3): check(scene.battle_view().heroes[h].hp==snap.heroes[h].hp-int(forecast.attacks[0].losses[h]),"first damage does not visually regrow between sources")
			if mode=="warded": check(scene.fx_director.current.wards==[0] and scene.fx_director.current.attack.losses==[0,0,0],"ward has zero hit effect")
			if mode in ["cancelled","missed","lethal"]: check(scene.fx_director.current.attack.losses==[0,0,0] and scene.fx_director.current.wards.is_empty(),"failed source has no hit or false ward")
			scene.fx_director.advance(0.20)
			scene.fx_director.advance(0.25)
			check(not scene.fx_busy(),"sequential queue completes")
			check(scene.battle_view()==scene.model,"round completion exposes real recovery and next intent")
			check(state(scene.model)==resolved,"round presentation neither replays RNG nor resolves twice")
	# Final action is durable before presentation; reload must not replay the blow.
	reset_scene(scene)
	scene.model.boss.hp=1
	scene.model.persist_meta=true
	scene.model.meta_path="user://fx-meta.json"
	scene.model._resume_path="user://fx-journey.save"
	var gold=scene.model.run.gold
	scene.perform(2)
	check(scene.model.phase=="reward" and scene.fx_busy() and not scene.finisher_active(),"final command commits before wind-up finishes")
	var reward_gold=scene.model.run.gold
	check(reward_gold>gold,"one award committed")
	check(scene.battle_view().run.gold==gold,"wind-up header uses pre-award display values")
	var reload=Model.new()
	reload.persist_meta=false
	reload.meta_path="user://fx-meta.json"
	check(reload.load_resume(scene.model._resume_path) and reload.phase=="reward" and reload.run.gold==reward_gold,"interrupted wind-up saves settled reward")
	scene.actors[0].advance(4.0/12.0)
	check(scene.finisher_active(),"finisher begins on the actual lethal impact")
	var reward=state(scene.model)
	scene.skip_combat_presentation()
	check(not scene.presentation_active() and scene.model.phase=="reward","skip leaves unselected reward")
	check(state(scene.model)==reward,"final skip cannot duplicate settlement")
	scene.choose_reward(0)
	check(scene.model.phase=="map","one reward selection advances normally")
	# Real viewport skip press/release at both wind-up and lethal-impact stages.
	for at_impact in [false,true]:
		for route in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE,0]:
			reset_scene(scene)
			scene.model.boss.hp=1
			scene.perform(2)
			if at_impact: scene.actors[0].advance(4.0/12.0)
			var final_state=state(scene.model)
			await process_frame
			var press: InputEvent
			if route==0:
				press=InputEventMouseButton.new()
				press.button_index=MOUSE_BUTTON_LEFT
				press.position=(scene.FINISHER_SKIP_RECT if at_impact else Rect2(1050,842,350,42)).get_center()
			else:
				press=InputEventKey.new()
				press.keycode=route
			press.pressed=true
			root.push_input(press,true)
			check(not scene.presentation_active(),"visible skip route releases both FX and finisher")
			press.pressed=false
			root.push_input(press,true)
			await process_frame
			check(state(scene.model)==final_state and scene.model.phase=="reward","skip release does not select or duplicate reward")
	scene.queue_free()
	await process_frame
