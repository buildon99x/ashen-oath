extends SceneTree
const Localization = preload("res://localization.gd")
## Scene-tree layout/interaction checks. Native screenshots are separate evidence.
var checks: int=0
func check(value: bool, context: String) -> void:
	checks+=1
	assert(value,context)
func _initialize() -> void:
	Localization.set_language("en")
	Localization.save_preferences()
	call_deferred("run_tests")
func run_tests() -> void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.muted=true
	scene.model.persist_meta=false
	scene.model.new_run(4421)
	scene.menu=false
	for tier in [2,3]:
		scene.model._milestone=true
		scene.model.start_battle(tier)
		for round_value in [1,2,3,4,5]:
			scene.model.round_number=round_value
			scene.model._prepare_intent()
			scene.refresh()
			await process_frame
			var threat: Dictionary=scene.model.preview_intent()
			var expected_names: Array[String]=[]
			for attack in threat.attacks: expected_names.append(attack.name)
			for child in scene.ui.get_children():
				if child is Label:
					for attack_name in expected_names.duplicate():
						if attack_name in child.text: expected_names.erase(attack_name)
					if child.position.x==40 and child.autowrap_mode!=TextServer.AUTOWRAP_OFF and child.position.y<530:
						check(child.position.y+child.size.y<=529,"Omen copy stays inside its panel")
				if child is Button and child.position.y==689:
					check(child.position.y+child.size.y<=790,"Action button stays above the log")
			check(expected_names.is_empty(),"Every prepared attack name is rendered")
			check(not threat.rhythm.is_empty(),"Boss timing is available before actions")
			if threat.attacks.size()==2:
				var marked: int=threat.attacks[1].targets[0]
				scene.selected_hero=marked
				scene.refresh()
				await process_frame
				var ward_button: bool=false
				for child in scene.ui.get_children():
					if child is Button and "WARD RITE" in child.text:
						ward_button=true
						check(child.size.y<=100,"Ward preview does not inflate the control")
				check(ward_button,"Marked hero sees the guard counter on its button")
				scene.perform(3)
				check(scene.model.preview_intent().attacks[1].status=="warded","Defend handler updates the secondary forecast")
				# Reset guards/acted state so the next layout case starts independently.
				for hero in scene.model.heroes:
					hero.guard=false
					hero.acted=false
	scene.model.parts[0].severed=true
	scene.selected_part=0
	scene.model.heroes[0].acted=true
	scene.restore_battle_selection()
	check(scene.selected_part==1 and scene.selected_hero==1,"Resume chooses an intact target and a ready hero")
	scene.cycle_part(-1)
	check(scene.selected_part==2,"Up skips a severed part instead of landing on an unusable target")
	scene.cycle_part(1)
	check(scene.selected_part==1,"Down wraps to the next intact part")
	scene.queue_free()
	await process_frame
	print("COUNTERPLAY UI CHECKS PASSED: ",checks," (headless layout/handlers, not visual QA)")
	quit()
