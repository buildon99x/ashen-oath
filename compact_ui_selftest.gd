extends SceneTree
const FxTest = preload("res://combat_fx/test_helpers.gd")
## CP13 isolated layout/input/preferences regression. This is not native visual QA.
const L = preload("res://localization.gd")
const Model = preload("res://model.gd")
const Icons = preload("res://compact_battle_icons.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, context: String) -> void:
	checks += 1
	if not value:
		failures.append(context)
		push_error("COMPACT UI: "+context)

func _initialize() -> void:
	call_deferred("run_tests")

func key(code: int, pressed: bool = true, shift: bool = false) -> InputEventKey:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	return event

func fixture(scene, tier: int = 3, round_value: int = 2) -> void:
	scene.model = Model.new()
	scene.model._clear_journey()
	scene.model.persist_meta = false
	scene.model.meta = {"essence":20,"upgrades":{"vitality":0,"force":0,"focus":0},"runs":4,"wins":2}
	scene.model.new_run(4529)
	scene.model._milestone = true
	scene.model.start_battle(tier)
	scene.model.round_number = round_value
	scene.model._prepare_intent()
	scene.menu = false
	scene.coach_open = false
	scene.coach_eligible = false
	scene.help_open = false
	scene.build_open = false
	scene.details_open = false
	scene.recovery_notice_open = false
	scene.save_error_open = false
	scene.confirmation = ""
	scene.finisher_remaining = 0
	scene.selected_hero = 0
	scene.selected_part = 0
	scene.refresh(false)

func find_control(scene, id: String) -> Control:
	for control in scene.detail_controls:
		if control.get_meta("inspect_id","") == id: return control
	return null

func live_labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	for child in node.get_children():
		if child.is_queued_for_deletion(): continue
		if child is Label: result.append(child)
		result.append_array(live_labels(child))
	return result

func visible_stat(scene, kind: String, pos: Vector2, expected: String) -> bool:
	for label in live_labels(scene.ui):
		if label.position == pos and label.get_meta("symbol","") == kind:
			return label.text == expected
	return false

func check_layout(scene, context: String) -> void:
	check_texture_bounds(scene.ui,context)
	check(L.missing_sources().is_empty(),context+" all display copy localized: "+str(L.missing_sources()))
	for control in scene.ui.get_children():
		if control.is_queued_for_deletion(): continue
		if control is Control: check(control.tooltip_text.is_empty(),context+" no native tooltip can survive Off")
		if control is Button:
			var rect: Rect2 = control.get_meta("layout_rect")
			check(control.size.x <= rect.size.x+1 and control.size.y <= rect.size.y+1,context+" button size stable: "+control.text)
			check(control.focus_mode == Control.FOCUS_NONE,context+" battle button cannot capture Space release")
		if control is Label:
			var font: Font = control.get_theme_font("font")
			var font_size: int = control.get_theme_font_size("font_size")
			if control.autowrap_mode == TextServer.AUTOWRAP_OFF:
				for line: String in control.text.split("\n"):
					check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= control.size.x+1,context+" label fits: "+line)
			check(control.position.x+control.size.x<=1441 and control.position.y+control.size.y<=901,context+" label bounds")
			for index in range(control.text.length()):
				var cp: int = control.text.unicode_at(index)
				if cp not in [10,13,9]: check(font.has_char(cp),context+" shaped glyph U+%04X" % cp)

func check_texture_bounds(node: Node, context: String) -> void:
	for control in node.get_children():
		if control.is_queued_for_deletion(): continue
		if control is TextureRect and control.has_meta("compact_size"):
			var expected: Vector2 = control.get_meta("compact_size")
			var minimum: Vector2 = control.get_combined_minimum_size()
			check(control.texture != null,context+" compact texture is loaded")
			check(control.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,context+" compact textures ignore source-image minimum")
			check(control.size.is_equal_approx(expected),context+" actual texture bounds match intended size: "+str(control.size)+" / "+str(expected))
			check(minimum.x<=expected.x and minimum.y<=expected.y,context+" texture minimum cannot enlarge intended bounds")
			if control.has_meta("hero_card_rect"):
				var card: Rect2 = control.get_meta("hero_card_rect")
				check(card.encloses(control.get_rect()),context+" portrait remains inside its hero card")
				check(control.position.x+control.size.x<=card.position.x+64,context+" portrait stays clear of hero name and HP")
				check(control.position.y+control.size.y<689,context+" portrait cannot cover skill buttons")
		check_texture_bounds(control,context)

func check_essential(scene, context: String) -> void:
	var threat: Dictionary = scene.model.preview_intent()
	for i in range(threat.attacks.size()):
		var attack: Dictionary = threat.attacks[i]
		var y: float = 226+i*128
		check(visible_stat(scene,"source",Vector2(67,y+29),scene.display_text(attack.source)),context+" source remains visible")
		for n in range(attack.targets.size()):
			var h: int = attack.targets[n]
			var row_y: float = y+55+n*21
			check(visible_stat(scene,"target",Vector2(67,row_y),scene.display_text(scene.model.heroes[h].name)),context+" marked target remains visible")
			check(visible_stat(scene,"hp",Vector2(175,row_y),str(-int(attack.losses[h]))),context+" exact target HP loss visible")
			check(visible_stat(scene,"focus",Vector2(265,row_y),str(-int(attack.focus_losses[h]))),context+" exact target Focus loss visible")
	for i in range(3):
		var h: Dictionary = scene.model.heroes[i]
		check(visible_stat(scene,"hp",Vector2(131+i*455,629),"%d/%d" % [h.hp,h.max_hp]),context+" hero HP visible")
		check(visible_stat(scene,"focus",Vector2(322+i*455,629),"%d/%d" % [h.mp,h.max_mp]),context+" hero Focus visible")
		var part: Dictionary = scene.model.parts[i]
		check(visible_stat(scene,"hp",Vector2(1221,224+i*119),"%d/%d" % [part.hp,part.max_hp]),context+" part HP visible")
		check(visible_stat(scene,"sever" if part.severed else ("break" if part.broken else "shield"),Vector2(1123,224+i*119),str(part.shield)),context+" shields/status visible")
	for i in range(3):
		var prediction: Dictionary = scene.model.preview_action(scene.selected_hero,i,scene.selected_part)
		var skill: Dictionary = scene.model.heroes[scene.selected_hero].skills[i]
		check(visible_stat(scene,str(skill.type),Vector2(83+i*250,723),str(prediction.get("damage",0))),context+" exact part damage visible")
		check(visible_stat(scene,"focus",Vector2(220+i*250,725),str(skill.cost)),context+" exact cost visible")
	if not threat.rhythm.is_empty():
		check(visible_stat(scene,"next",Vector2(67,491),scene.display_text(threat.rhythm.next)),context+" next rhythm visible")

func run_tests() -> void:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	check(not data.is_empty() and ProjectSettings.globalize_path("user://").begins_with(data+"/"),"isolated profile required")
	if not failures.is_empty(): quit(2); return
	root.size = Vector2i(1440,900)
	if "--write-pref-off" in OS.get_cmdline_user_args():
		L.set_language("en")
		L.tooltips_enabled = false
		check(L.save_preferences(),"write disabled preference for separate process")
		finish(); return
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.muted = true
	await process_frame
	if "--check-pref-off" in OS.get_cmdline_user_args():
		check(not L.tooltips_enabled and L.get_language() == "en","new process restores Off and language")
		fixture(scene)
		await process_frame
		scene.show_detail_popup(find_control(scene,"skill_0"))
		check(not is_instance_valid(scene.tooltip_panel),"restart Off suppresses hover")
		root.push_input(key(KEY_T),true)
		root.push_input(key(KEY_T,false),true)
		check(L.tooltips_enabled,"T reenables preference after restart")
		scene.queue_free(); await process_frame; finish(); return
	check(L.tooltips_enabled,"fresh profile defaults tooltips on")
	for kind: String in Icons.PATHS:
		check(Icons.texture(kind) != null and Icons.texture(kind).get_width()==24,"SVG symbol renders: "+kind)
	var legacy = ConfigFile.new()
	legacy.set_value("display","language","en")
	check(legacy.save("user://legacy-display.cfg") == OK,"legacy preference fixture")
	L.tooltips_enabled = false
	check(L.load_preferences("user://legacy-display.cfg") and L.tooltips_enabled,"pre-tooltip preferences migrate to On")
	legacy.set_value("display","tooltips","invalid")
	legacy.save("user://invalid-display.cfg")
	L.tooltips_enabled = false
	check(L.load_preferences("user://invalid-display.cfg") and L.tooltips_enabled,"invalid tooltip value safely defaults On")
	for language: String in ["ko","en"]:
		L.set_language(language)
		scene.apply_language_theme()
		for enabled: bool in [true,false]:
			L.tooltips_enabled = enabled
			for tier: int in [1,2,3]:
				for round_value: int in [1,2,3]:
					L.clear_diagnostics()
					fixture(scene,tier,round_value)
					await process_frame
					await process_frame
					var context: String = "%s tips %s tier %d round %d" % [language,enabled,tier,round_value]
					check_layout(scene,context)
					check_essential(scene,context)
					for control in scene.detail_controls:
						scene.show_detail_popup(control)
						await process_frame
						check(is_instance_valid(scene.tooltip_panel)==enabled,context+" hover respects preference")
						if enabled:
							var panel: Control = scene.tooltip_panel
							check(panel.position.x>=0 and panel.position.x+panel.size.x<=1440 and panel.position.y>=0 and panel.position.y+panel.size.y<=900,context+" tooltip fits viewport")
							check(panel.get_child(0).get_theme_font("font").has_char("맹".unicode_at(0)),context+" Korean-safe popup font")
					scene.hide_detail_popup()
			fixture(scene)
			var marked: int = scene.model.preview_intent().attacks[1].targets[0]
			scene.selected_hero = marked
			scene.model.heroes[marked].mp = 0
			scene.refresh(false)
			await process_frame
			check(find_control(scene,"skill_3").get_meta("wards",false),"guard counter exposed without hover")
			check(visible_stat(scene,"focus",Vector2(942,747),"+2"),"guard Focus gain remains visible")
			scene.perform(3)
			FxTest.settle(scene)
			await process_frame
			check_essential(scene,"warded exact zeros")
			scene.model.parts[0].broken = true
			scene.model.parts[0].shield = 0
			scene.model.parts[2].severed = true
			scene.model.parts[2].hp = 0
			scene.model.heroes[1].hp = 0
			scene.refresh(false)
			await process_frame
			check_essential(scene,"broken/severed/fallen")
		# Real keyboard path, independent of Button focus and action activation.
		L.tooltips_enabled = true
		fixture(scene)
		await process_frame
		var before: Dictionary = scene.model.describe()
		var rng_before: int = scene.model.rng.state
		root.push_input(key(KEY_2),true); root.push_input(key(KEY_2,false),true)
		check(is_instance_valid(scene.tooltip_panel) and scene.tooltip_owner.get_meta("inspect_id","")=="hero_1","number-key selection shows hero details")
		root.push_input(key(KEY_DOWN),true); root.push_input(key(KEY_DOWN,false),true)
		check(is_instance_valid(scene.tooltip_panel) and scene.tooltip_owner.get_meta("inspect_id","")=="part_1","arrow-key selection shows part details")
		scene.selected_hero=0; scene.selected_part=0; scene.refresh(false)
		await process_frame
		root.push_input(key(KEY_TAB),true); root.push_input(key(KEY_TAB,false),true)
		check(is_instance_valid(scene.tooltip_panel) and scene.inspection_index==0,"Tab inspects first control")
		check(root.gui_get_focus_owner()==null,"Tab inspection does not focus a battle Button")
		root.push_input(key(KEY_TAB,true,true),true); root.push_input(key(KEY_TAB,false,true),true)
		check(scene.inspection_index==scene.detail_controls.size()-1,"Shift+Tab wraps inspection")
		check(scene.model.describe()==before and scene.model.rng.state==rng_before,"inspection changes no model/RNG")
		root.push_input(key(KEY_ESCAPE),true); root.push_input(key(KEY_ESCAPE,false),true)
		check(not is_instance_valid(scene.tooltip_panel) and not scene.menu,"Escape dismisses tooltip before menu")
		scene.inspect_by_id("skill_0")
		root.push_input(key(KEY_L),true); root.push_input(key(KEY_L,false),true)
		check(not is_instance_valid(scene.tooltip_panel),"language switch destroys stale popup")
		scene.inspect_by_id("skill_0")
		check(is_instance_valid(scene.tooltip_panel),"tooltip can reopen in changed language")
		check(scene.tooltip_panel.get_child(0).text.contains(scene.display_text("Oathblade")),"popup uses changed language")
		root.push_input(key(KEY_T),true); root.push_input(key(KEY_T,false),true)
		check(not L.tooltips_enabled and not is_instance_valid(scene.tooltip_panel),"T Off immediately closes open popup")
		check(scene.model.describe()==before,"language and tooltip settings spend no actions")
		root.push_input(key(KEY_TAB),true); root.push_input(key(KEY_TAB,false),true)
		check(not is_instance_valid(scene.tooltip_panel),"Tab while Off never creates a popup")
		root.push_input(key(KEY_D),true); root.push_input(key(KEY_D,false),true)
		await process_frame; await process_frame
		check(scene.details_open and not is_instance_valid(scene.tooltip_panel),"D opens details with tooltips Off")
		check_texture_bounds(scene.ui,"Details icon keys after container layout")
		var descriptions: String = ""
		for label in live_labels(scene.ui): descriptions += label.text+"\n"
		check(descriptions.contains(scene.display_text("SYMBOL GUIDE")) and descriptions.contains(scene.display_text(scene.model.heroes[0].skills[0].description)),"Details retains symbol meanings and full skill descriptions")
		check(L.missing_sources().is_empty(),"Details translated: "+str(L.missing_sources()))
		root.push_input(key(KEY_PAGEDOWN),true); root.push_input(key(KEY_PAGEDOWN,false),true)
		await process_frame
		check(scene.details_scroll.scroll_vertical>0,"Details can be scrolled using keyboard")
		scene.perform(0)
		FxTest.settle(scene)
		root.push_input(key(KEY_Q),true); root.push_input(key(KEY_Q,false),true)
		root.push_input(key(KEY_SPACE),true); root.push_input(key(KEY_SPACE,false),true)
		check(scene.model.describe()==before,"Details blocks combat and stale action calls")
		root.push_input(key(KEY_ESCAPE),true); root.push_input(key(KEY_ESCAPE,false),true)
		await process_frame
		check(not scene.details_open and not scene.menu,"Escape closes Details cleanly")
		root.push_input(key(KEY_B),true); root.push_input(key(KEY_B,false),true)
		check(scene.build_open,"Build still accessible with Off")
		root.push_input(key(KEY_ESCAPE),true); root.push_input(key(KEY_ESCAPE,false),true)
		L.tooltips_enabled = true
		scene.inspect_by_id("skill_0")
		root.push_input(key(KEY_SPACE),true)
		root.push_input(key(KEY_SPACE,false),true)
		check(scene.confirmation=="end_round" and scene.model.describe()==before,"Space still confirms early end without stale focused attack")
		check(not is_instance_valid(scene.tooltip_panel),"confirmation clears popup")
		root.push_input(key(KEY_ESCAPE),true); root.push_input(key(KEY_ESCAPE,false),true)
		await process_frame
		check(scene.confirmation.is_empty(),"cancel round confirmation")
		scene.inspect_by_id("skill_0")
		root.push_input(key(KEY_H),true); root.push_input(key(KEY_H,false),true)
		check(scene.help_open and not is_instance_valid(scene.tooltip_panel),"Help clears popup")
		root.push_input(key(KEY_ESCAPE),true); root.push_input(key(KEY_ESCAPE,false),true)
		await process_frame
		scene.model.boss.hp = 1
		scene.inspect_by_id("skill_0")
		scene.perform(0)
		FxTest.settle(scene)
		check(scene.finisher_active() and not is_instance_valid(scene.tooltip_panel),"finisher clears inspected popup")
		var reward: Dictionary = scene.model.describe()
		root.push_input(key(KEY_TAB),true); root.push_input(key(KEY_TAB,false),true)
		root.push_input(key(KEY_T),true); root.push_input(key(KEY_T,false),true)
		check(scene.finisher_active() and scene.model.describe()==reward and not is_instance_valid(scene.tooltip_panel),"Tab/T locked throughout finisher")
		root.push_input(key(KEY_SPACE),true); root.push_input(key(KEY_SPACE,false),true)
		check(not scene.finisher_active() and scene.model.describe()==reward,"skip release cannot choose reward")
	# Existing menu/language tooltips obey the same preference, including focus.
	L.tooltips_enabled = false
	scene.menu = true
	scene.refresh(false)
	await process_frame
	var found_toggle: bool = false
	for control in scene.ui.get_children():
		if not control is Button or control.is_queued_for_deletion(): continue
		if control.text == scene.display_text("T / Tooltips off"): found_toggle = true
		if control.has_meta("detail_text"):
			control.grab_focus()
			control.mouse_entered.emit()
			check(not is_instance_valid(scene.tooltip_panel) and control.tooltip_text.is_empty(),"menu focus/hover tooltips respect Off")
			control.release_focus()
	check(found_toggle,"tooltip switch discoverable on main menu")
	scene.help_open = true
	scene.refresh(false)
	await process_frame
	found_toggle = false
	for control in scene.ui.get_children():
		if control is Button and control.position == Vector2(285,716): found_toggle = control.text==scene.display_text("T / Tooltips off")
	check(found_toggle,"tooltip switch discoverable in Guide")
	scene.queue_free()
	await process_frame
	# Two real Godot processes, using this same isolated test-only profile.
	for mode: String in ["--write-pref-off","--check-pref-off"]:
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://compact_ui_selftest.gd","--",mode],output,true)
		var log_text: String = "\n".join(output)
		check(status==0 and not "SCRIPT ERROR" in log_text and not "ERROR:" in log_text,"separate-process preference restart "+mode+": "+log_text)
	finish()

func finish() -> void:
	print("COMPACT UI SELFTEST: %d checks; %d failures (isolated headless layout/input/preferences, not native visual QA)" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
