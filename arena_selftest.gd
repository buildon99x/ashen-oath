extends SceneTree
const Localization = preload("res://localization.gd")
## Asset/selector/layout contracts only; native composition is checked separately.
var checks: int=0
var failures: int=0
func check(value: bool, context: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(context)
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
	scene.model.new_run(11)
	scene.menu=false
	check(scene.battle_arenas.size()==3,"Three region-specific arena textures")
	var hashes: Array[String]=[]
	for texture in scene.battle_arenas:
		check(texture.get_size()==Vector2(1586,992),"Every arena preserves the established aspect and staging dimensions")
		var digest: String=FileAccess.get_sha256(texture.resource_path)
		check(not digest.is_empty() and not digest in hashes,"Each arena is an independent asset, not a duplicate")
		hashes.append(digest)
	for node in range(9):
		scene.model.new_run(110+node)
		scene.model.run.node=node
		check(scene.model.start_battle(node/3+1),"Independent fixture starts from a new map")
		var before: Dictionary=scene.model.describe()
		var rng: int=scene.model.rng.state
		check(scene.current_biome()==node/3,"Region follows journey crossing")
		check(scene.battle_arena_texture()==scene.battle_arenas[node/3],"Battle selects its region texture")
		scene.refresh()
		await process_frame
		var named: bool=false
		for child in scene.ui.get_children():
			if child is Label and child.text.begins_with("ROUND "):
				named=scene.REGION_NAMES[node/3] in child.text
				check(scene.font.get_string_size(child.text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x<985,"Region caption fits the battle header")
		check(named,"Region is named in battle without relying on color")
		check(scene.model.describe()==before and scene.model.rng.state==rng,"Arena and caption lookup do not change rules or RNG")
		scene.model.boss.hp=1
		scene.selected_hero=0
		scene.selected_part=0
		scene.perform(0)
		check(scene.finisher_active() and scene.model.phase=="reward","Normal finishing hit prepares resolved reward")
		check(scene.battle_arena_texture()==scene.battle_arenas[node/3],"Finisher retains the just-fought region")
		scene.finish_presentation()
	for node in [-99,99]:
		scene.model.run.node=node
		check(scene.current_biome() in range(3),"Malformed display-only crossing is safely clamped")
	scene.queue_free()
	await process_frame
	print("REGION ARENA TESTS: %d checks; %d failures (assets/selector/layout, not native visual QA)" % [checks,failures])
	quit(0 if failures==0 else 1)
