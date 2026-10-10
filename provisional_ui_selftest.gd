extends SceneTree
## UI handlers + saved-profile routing. Headless, not a native visual playtest.
const Model=preload("res://model.gd")
const Combat=preload("res://core/provisional_combat.gd")
const Localization=preload("res://localization.gd")
var checks: int=0
var failures: int=0
var scene
func check(ok: bool, context: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("PROVISIONAL UI FAIL: "+context)
func _initialize() -> void:
	call_deferred("run_tests")
func fresh():
	var m=Model.new()
	m.persist_meta=false
	m.new_run(811,Combat.ID)
	m.start_battle(1)
	return m
func reset_battle() -> void:
	scene.model=fresh()
	scene.menu=false
	scene.coach_open=false
	scene.coach_eligible=false
	scene.help_open=false
	scene.build_open=false
	scene.confirmation=""
	scene.recovery_notice_open=false
	scene.save_error_open=false
	scene.finisher_remaining=0
	scene.restore_battle_selection()
	scene.refresh(false)
func button_containing(text: String) -> Button:
	for c in scene.ui.get_children():
		if c is Button and not c.is_queued_for_deletion() and text in c.text: return c
	return null
func snapshot() -> Dictionary:
	var state: Dictionary=scene.model.describe().duplicate(true)
	state.erase("last_error")
	return state
func key(value: int) -> void:
	var e=InputEventKey.new()
	e.pressed=true
	e.keycode=value
	scene._unhandled_key_input(e)
func run_tests() -> void:
	Localization.set_language("en")
	Localization.save_preferences()
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.muted=true
	scene.model.persist_meta=false
	scene.begin_run()
	check(scene.model.provisional_combat(),"actual Begin chooses provisional combat")
	check(scene.model.phase=="map","Begin preserves map loop")
	reset_battle()
	await process_frame
	check(scene.selected_hero==0,"initial current actor selected")
	var before=snapshot()
	key(KEY_BRACKETRIGHT)
	check(scene.model.heroes[0].boost==1 and scene.model.heroes[0].ep==2,"keyboard allocates without spending")
	key(KEY_BRACKETLEFT)
	check(scene.model.heroes[0].boost==0,"keyboard cancels allocation")
	var skill_button=button_containing("Q ")
	check(skill_button!=null,"actual skill button exists")
	if skill_button:
		skill_button.mouse_entered.emit()
		check(scene.port_hover==0,"hover starts explicit action preview")
		check(snapshot()==before,"hover is read-only")
		var old_generation: int=scene.port_ui_generation
		scene.select_part(1)
		check(scene.port_hover==-1,"changing target clears old preview")
		scene.set_port_hover(0,old_generation)
		check(scene.port_hover==-1,"stale freed control cannot resurrect preview")
	for overlay in ["help_open","build_open","coach_open","recovery_notice_open","save_error_open"]:
		reset_battle()
		scene.refresh(false)
		scene.set(overlay,true)
		before=snapshot()
		key(KEY_BRACKETRIGHT)
		key(KEY_T)
		key(KEY_F)
		key(KEY_Q)
		key(KEY_SPACE)
		scene.change_boost(1)
		scene.provisional_special("parry")
		check(snapshot()==before,"overlay blocks battle input: "+overlay)
	reset_battle()
	scene.model.heroes[0].mp=int(scene.model.heroes[0].max_mp)-2
	scene.refresh(false)
	await process_frame
	var defend=button_containing("R / DEFEND")
	check(defend!=null and "MP +2" in defend.text,"Defend displays actual capped recovery")
	scene.perform(3)
	check(scene.model.heroes[0].guard and scene.model.heroes[0].mp==scene.model.heroes[0].max_mp,"actual Defend handler grants capped MP and guard")
	check(scene.selected_hero==1,"successful action selects next actor")
	var previous_round: int=scene.model.round_number
	scene.request_end_round()
	check(scene.model.active_actor()==2 and scene.model.round_number==previous_round,"Space passes only one hero")
	scene.request_end_round()
	check(scene.model.active_actor()==-1 and scene.model.round_number==previous_round,"enemy waits explicit resolution")
	scene.request_end_round()
	check(scene.model.round_number==previous_round+1 and scene.selected_hero==0,"enemy resolution returns correct actor next round")
	reset_battle()
	var source: int=scene.model.intent.part
	scene.select_part(source)
	scene.provisional_special("parry")
	check(scene.model.heroes[0].parry_height==scene.model.parts[source].level,"Parry handler chooses effective source height")
	scene.request_end_round()
	scene.request_end_round()
	scene.model.intent.targets=[0]
	scene.request_end_round()
	check(scene.model.run.combat.mode=="counter" and scene.selected_hero==0,"successful Parry opens current hero counter in UI")
	before=snapshot()
	scene.change_boost(1)
	scene.perform(1)
	check(snapshot()==before,"counter denies Boost and non-normal skill")
	scene.perform(0)
	check(scene.model.run.combat.mode=="turn" and scene.model.round_number==2,"normal counter completes and returns to turns")
	reset_battle()
	scene.provisional_special("parry")
	scene.request_end_round()
	scene.request_end_round()
	scene.model.intent.targets=[0,1]
	scene.request_end_round()
	check(scene.enemy_wards==[true,false,false],"multi-target feedback marks only actual parrying hero")
	check(scene.model.heroes[1].hp==41,"non-parrying second target takes actual damage")
	reset_battle()
	scene.request_end_round()
	for h: Dictionary in scene.model.heroes: h.hp=int(h.max_hp)-4
	var healing: Dictionary=scene.model.preview_action(1,2,0)
	check(healing.party_heal==[4,4,4],"Blood Lantern forecasts capped living-party recovery once")
	scene.perform(2)
	for h: Dictionary in scene.model.heroes: check(h.hp==h.max_hp,"Blood Lantern actual heal matches forecast")
	reset_battle()
	scene.model.parts[0].shield=0
	scene.model.parts[0].broken=true
	scene.model.parts[0].hp=0
	scene.model.boss.downed=true
	Combat._update_heights(scene.model)
	scene.select_part(0)
	check(button_containing("LIMB SPENT")!=null and button_containing("LIMB SPENT").disabled,"spent limb visibly disables damage farming")
	check(not button_containing("F / SEVER").disabled,"spent limb still offers manual Sever")
	check("body damage" in button_containing("F / SEVER").tooltip_text,"Sever explains rupture reward and EP recovery route")
	scene.provisional_special("sever")
	check(scene.model.parts[0].severed and scene.model.boss.collapsed,"manual Sever handler permanently changes posture")
	check(scene.model.heroes[0].ep==1 and scene.selected_hero==1,"Sever spends one EP and current action")
	check(scene.selected_part!=0,"manual Sever switches to intact target")
	for language in ["en","ko"]:
		Localization.set_language(language)
		reset_battle()
		await process_frame
		for child in scene.ui.get_children():
			if child is Control:
				check(child.position.x>=0 and child.position.y>=0 and child.position.x+child.size.x<=1441 and child.position.y+child.size.y<=901,"battle control bounds / "+language)
			if child is Button and child.has_meta("skill_index"):
				check(child.text.count("\n")<=5,"skill card line budget / "+language)
		for child in scene.ui.get_children():
			if child is Label and child.position==Vector2(40,435):
				check(child.position.y+child.size.y<=525,"omen legend clears EP controls / "+language)
		check("FOCUS" not in scene.display_text("FOCUS 60/60") and "MP" in scene.display_text("FOCUS 60/60"),"nonbattle resource label stays MP / "+language)
		check(button_containing("EP")!=null,"EP remains distinct resource / "+language)
		scene.help_open=true
		scene.refresh(false)
		await process_frame
		for child in scene.ui.get_children():
			if child is Label and child.position==Vector2(285,196):
				check(child.position.y+child.size.y<=713,"help text clears close control / %s bottom=%s" % [language,str(child.position.y+child.size.y)])
		check(button_containing("CLOSE GUIDE" if language=="en" else "안내 닫기")!=null,"localized guide close / "+language)
	Localization.set_language("en")
	reset_battle()
	scene.model.boss.tier=2
	scene.model.round_number=2
	Combat._prepare_intent(scene.model)
	scene.refresh(false)
	await process_frame
	scene.request_end_round()
	check(button_containing("INCOMING HP -23")!=null,"targeted hero Defend shows exact combined incoming loss before committing")
	for attack: Dictionary in scene.model.preview_intent().attacks:
		var found:=false
		for child in scene.ui.get_children():
			if child is Label and scene.display_text(str(attack.source)) in child.text and " / " in child.text: found=true
		check(found,"each converging omen identifies the actual limb source")
	reset_battle()
	for p: Dictionary in scene.model.parts:
		p.shield=0
		p.broken=true
		p.hp=0
	scene.model.boss.downed=true
	Combat._update_heights(scene.model)
	for h: Dictionary in scene.model.heroes: h.ep=0
	scene.refresh(false)
	await process_frame
	check(button_containing("LIMB SPENT").disabled and button_containing("F / SEVER").disabled,"zero-EP spent state visibly disables unavailable damage and Sever")
	check(not button_containing("SPACE / PASS").disabled and not button_containing("R / DEFEND").disabled,"zero-EP all-spent state keeps both recovery exits enabled")
	scene.request_end_round()
	scene.request_end_round()
	scene.request_end_round()
	scene.request_end_round()
	check(scene.model.heroes[0].ep==2 and not button_containing("F / SEVER").disabled,"UI Pass route restores EP and enables Sever")
	reset_battle()
	scene.menu=true
	scene.refresh(false)
	await process_frame
	check(button_containing("RESUME CURRENT JOURNEY")!=null and button_containing("BEGIN A NEW CYCLE")==null,"unfinished journey main menu offers Continue only")
	check(button_containing("+5 max MP")!=null,"next-cycle MP upgrade shows actual five-point gain")
	var path="user://provisional-ui-resume.save"
	scene.menu=false
	scene.model.allocate_boost(0,2)
	scene.select_part(2)
	check(scene.model.save_resume(path),"save allocated Boost")
	var restored=Model.new()
	restored.persist_meta=false
	check(restored.load_resume(path),"load allocated Boost")
	scene.model=restored
	scene.restore_battle_selection()
	scene.refresh(false)
	await process_frame
	check(scene.model.provisional_combat() and scene.selected_hero==0 and scene.model.heroes[0].boost==2,"resumed journey selects saved profile and actor")
	check(scene.selected_part==2,"resumed target remains the same as allocated Boost plan")
	check(button_containing("+ EP")!=null,"resumed profile renders provisional controls")
	var legacy=Model.new()
	legacy.persist_meta=false
	legacy.new_run(123)
	legacy.start_battle(1)
	scene.model=legacy
	scene.refresh(false)
	await process_frame
	check(not scene.model.provisional_combat() and button_containing("+ EP")==null,"legacy journeys keep legacy UI and combat")
	scene.audio.stop()
	scene.audio.stream=null
	scene.queue_free()
	await process_frame
	print("PROVISIONAL UI: %d checks; %d failures. Headless handlers, not visual QA." % [checks,failures])
	quit(0 if failures==0 else 1)
