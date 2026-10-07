extends SceneTree
var checks: int = 0
func check(value: bool, text: String) -> void:
	if not value:
		push_error("UI FAIL: " + text)
		quit(1)
	assert(value, text)
	checks += 1
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.model.persist_meta = false
	check(scene.menu, "menu opens")
	scene.begin_run()
	await process_frame
	check(scene.model.phase == "map", "new cycle reaches map")
	scene.model.start_battle(1)
	scene.refresh()
	await process_frame
	check(scene.ui.get_child_count() > 12, "battle controls rendered into scene tree")
	scene.select_hero(0)
	scene.select_part(0)
	scene.perform(1)
	await process_frame
	check(scene.model.heroes[0].acted, "skill handler spends actor action")
	scene.select_hero(1)
	scene.perform(3)
	scene.select_hero(2)
	scene.perform(3)
	await process_frame
	var old_round: int = scene.model.round_number
	scene.finish_round()
	await process_frame
	check(scene.model.round_number == old_round+1, "end round handler advances")
	scene.help_open=true
	scene.refresh()
	await process_frame
	var found: bool=false
	for child in scene.ui.get_children():
		if child is Button and child.text == "CLOSE GUIDE":
			found=true
	check(found,"guide has close button")
	scene.help_open=false
	for i in range(5):
		scene.menu=not scene.menu
		scene.refresh()
		await process_frame
	check(scene.ui.get_child_count()<40,"menu refresh does not accumulate controls")
	scene.menu=false
	for phase in ["map","battle","event","camp","relic","reward","victory","defeat"]:
		scene.model.phase=phase
		if phase in ["event","camp","relic"]:
			scene.model._open_event(phase)
		elif phase=="reward":
			scene.model._win_battle()
		scene.refresh()
		await process_frame
		for child in scene.ui.get_children():
			if child is Button:
				check(child.position.x+child.size.x<=1441 and child.position.y+child.size.y<=901,"button stays inside viewport in "+phase)
	for phase in ["map","event","camp","relic","reward"]:
		scene.model.phase=phase
		if phase in ["event","camp","relic"]: scene.model._open_event(phase)
		scene.refresh()
		await process_frame
		var portraits: int=0
		var frames: int=0
		for child in scene.ui.get_children():
			if child is TextureRect: portraits+=1
			if child is Panel: frames+=1
			if child is Label and child.autowrap_mode!=TextServer.AUTOWRAP_OFF:
				check(child.position.y+child.size.y<=900,"wrapped copy stays within view in "+phase)
		check(portraits==3,"three party portraits in "+phase)
		check(frames>=4,"framed narrative and party cards in "+phase)
	scene.model.meta.runs=1
	scene.model.phase="victory"
	scene.menu=false
	scene.refresh()
	await process_frame
	var correct_cycle: bool=false
	for child in scene.ui.get_children():
		if child is Label and child.text.begins_with("CYCLE 1  /"):
			correct_cycle=true
	check(correct_cycle,"victory header uses completed cycle number")
	scene.audio.stop()
	scene.audio.stream=null
	await create_timer(0.25).timeout
	scene.queue_free()
	await process_frame
	print("UI HANDLER TESTS PASSED: ",checks," (headless, not rendered visual QA)")
	quit(0)
