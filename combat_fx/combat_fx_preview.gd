extends "res://main.gd"
## Inspection-only scene. Fixtures never read/write a real played journey.
var preview_case: int = 1
var preview_region: int = 0
var preview_paused: bool = false
var preview_legacy: bool = false
const CASES: Array[String] = ["Shield chip","Break","Sever","Ward","Cancelled","Final strike"]
func _ready() -> void:
	super._ready()
	for actor in actors: actor.set_process(false)
	reset_preview()
func _process(delta: float) -> void:
	var step: float = 0.0 if preview_paused else delta
	super._process(step)
	for actor in actors: actor.advance(step*actor.playback_speed)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				preview_case=(preview_case+1)%CASES.size(); reset_preview()
			KEY_F2:
				preview_region=(preview_region+1)%3; reset_preview()
			KEY_F3:
				preview_paused=not preview_paused; refresh(false)
			KEY_F4:
				preview_paused=true
				super._process(1.0/60.0)
				for actor in actors: actor.advance((1.0/60.0)*actor.playback_speed)
				refresh(false)
			KEY_F5:
				reset_preview()
				if preview_case in [3,4]: finish_round()
				else: perform(2)
			KEY_F6:
				preview_legacy=not preview_legacy; reset_preview()
			_:
				super._input(event)
				return
		get_viewport().set_input_as_handled()
		return
	super._input(event)
func reset_preview() -> void:
	if not is_instance_valid(fx_director): return
	fx_director.clear()
	fx_pending_finisher.clear()
	finisher_remaining=0
	fx_time=0
	enemy_flash=0
	model=Model.new()
	model.persist_meta=false
	model._clear_journey()
	model.meta={"essence":0,"runs":1,"wins":0,"upgrades":{"vitality":0,"force":0,"focus":0}}
	model.new_run(78231)
	model.run.node=preview_region*3+1
	model.start_battle(2)
	menu=false
	coach_open=false
	coach_eligible=false
	recovery_notice_open=false
	save_error_open=false
	help_open=false
	build_open=false
	details_open=false
	confirmation=""
	selected_hero=0
	selected_part=1
	fx_legacy_mode=preview_legacy
	if preview_case==0: model.parts[1].shield=4
	if preview_case==1: model.parts[1].shield=1
	if preview_case==2:
		model.parts[1].shield=0; model.parts[1].broken=true; model.parts[1].hp=14
	if preview_case==3:
		model.heroes[0].guard=true
		model.intent={"part":2,"name":"Ward inspection","targets":[0],"damage":12,"wardable":true}
	if preview_case==4:
		model.parts[1].severed=true; model.parts[1].hp=0
		model.intent={"part":1,"name":"Cancelled inspection","targets":[0],"damage":12,"wardable":false}
	if preview_case==5: model.boss.hp=1
	for actor in actors: actor.play_state("idle",true)
	refresh(false)
func refresh(save_journey: bool = true) -> void:
	super.refresh(false) # Diagnostic fixtures are never saved.
	if not is_instance_valid(ui): return
	panel_at(Rect2(0,0,1440,91))
	raw_label("FX INSPECTION / 진단 장면 / "+CASES[preview_case]+" / "+REGION_NAMES[preview_region],Vector2(25,8),21,GOLD,1370)
	var stage: String = "legacy %.3fs" % (0.85-fx_time) if preview_legacy and fx_time>0 else "ready"
	if fx_busy(): stage="impact %.3fs" % fx_director.impact_age if fx_director.impact_age>=0 else "wind-up %.3fs" % fx_director.elapsed
	raw_label("F1 case · F2 arena · F3 pause · F4 +1/60s · F5 replay · F6 A/B  |  "+("LEGACY" if preview_legacy else "NEW")+" / "+("PAUSED" if preview_paused else "PLAY")+" / "+stage,Vector2(25,47),16,PALE,1370)
