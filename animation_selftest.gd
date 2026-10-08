extends SceneTree
const Localization = preload("res://localization.gd")
## Run: godot --headless --path . --script res://animation_selftest.gd
## Before art is generated: append -- --runtime-only (assets not verified).

const HeroScript = preload("res://animated_hero.gd")
const STUDIO: PackedScene = preload("res://character_studio.tscn")
const DIRECTIONS: Array[String] = ["down", "left", "right", "up"]
const EXPECTED_COUNTS: Dictionary = {"idle": 6, "walk": 8, "attack": 8, "hurt": 3, "death": 6}
const EXPECTED_FPS: Dictionary = {"idle": 6, "walk": 10, "attack": 12, "hurt": 10, "death": 8}
var checks: int = 0
var failures: Array[String] = []
var event_log: Array[String] = []
var completed: Array[String] = []

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error("ANIMATION FAIL: " + description)

func _initialize() -> void:
	Localization.set_language("en")
	Localization.save_preferences()
	call_deferred("run_tests")

func run_tests() -> void:
	var hero: Node2D = HeroScript.new()
	hero.autoplay = false
	hero.position = Vector2(420, 530)
	root.add_child(hero)
	await process_frame
	hero.animation_event.connect(func(animation: String, event_name: String) -> void: event_log.append(animation + ":" + event_name))
	hero.animation_finished.connect(func(animation: String) -> void: completed.append(animation))
	_test_runtime(hero)
	if not "--runtime-only" in OS.get_cmdline_user_args():
		_test_atlases(hero)
	else:
		print("ASSET CHECKS SKIPPED: --runtime-only was requested")
	await _test_studio()
	hero.queue_free()
	await process_frame
	await _test_scene_transitions()
	if failures.is_empty():
		print("ANIMATION TESTS PASSED: %d checks (runtime, studio handlers%s)" % [checks, "" if "--runtime-only" in OS.get_cmdline_user_args() else ", original atlas pixels"])
		quit(0)
	else:
		print("ANIMATION TESTS FAILED: %d of %d" % [failures.size(), checks])
		quit(1)

func _test_runtime(hero: Node2D) -> void:
	check(hero.frame_size() == Vector2(96, 112), "96×112 source cells")
	check(hero.foot_anchor() == Vector2(48, 101), "shared source foot anchor")
	check(hero.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest-neighbor sampling")
	var all_rows: Dictionary = {}
	for direction in DIRECTIONS:
		hero.set_facing(direction)
		check(hero.facing == direction, "accept facing " + direction)
		for animation in EXPECTED_COUNTS:
			hero.play_state(animation, true)
			check(hero.frame_count() == int(EXPECTED_COUNTS[animation]), "frame count " + animation)
			check(is_equal_approx(hero.clip_fps(), float(EXPECTED_FPS[animation])), "clip FPS " + animation)
			var region: Rect2 = hero.source_rect()
			check(not all_rows.has(region.position.y), "unique row " + direction + "/" + animation)
			all_rows[region.position.y] = true
			check(region.position.x == 0 and region.size == Vector2(96, 112), "initial cell " + direction + "/" + animation)
			check(hero.scale == Vector2.ONE, "facing never flips or scales the node")
	check(all_rows.size() == 20, "all 20 direction/state rows addressed")
	hero.set_facing("right")
	hero.set_facing("invalid")
	check(hero.facing == "right", "invalid facing leaves facing unchanged")
	check(not hero.play_state("invalid", true), "invalid clip is rejected")
	for animation in ["idle", "walk"]:
		hero.play_state(animation, true)
		var duration: float = float(hero.frame_count()) / hero.clip_fps()
		hero.advance(duration * 17.0 + 0.5 / hero.clip_fps())
		check(hero.state == animation and hero.frame == 0, animation + " loops across a large delta")
		check(hero.position == Vector2(420, 530), animation + " keeps anchor position")
	for animation in ["attack", "hurt"]:
		hero.play_state(animation, true)
		var count: int = hero.frame_count()
		var fps: float = hero.clip_fps()
		for frame_index in range(count):
			check(hero.frame == frame_index, animation + " visits frame " + str(frame_index))
			hero.advance(1.0 / fps)
		check(hero.state == "idle" and hero.frame == 0, animation + " returns to idle once")
		check(completed.count(animation) == 1, animation + " completion signal once")
		check(hero.position == Vector2(420, 530), animation + " never displaces feet")
	check(event_log.count("attack:impact") == 1, "exactly one attack impact event")
	hero.play_state("death", true)
	hero.advance(20.0)
	check(hero.state == "death" and hero.frame == 5, "death holds final frame")
	for index in range(12):
		hero.advance(100.0)
	check(completed.count("death") == 1, "death completes only once")
	check(hero.frame == 5 and hero.position == Vector2(420, 530), "death remains frozen without displacement")
	hero.play_state("idle", true)
	hero.advance(0.2)
	check(hero.state == "idle" and hero.frame == 1, "restart revives frozen sprite")
	hero.play_state("attack", true)
	hero.seek_frame(5)
	check(hero.frame == 5 and event_log.size() == 1, "scrubbing does not fire attack events")
	hero.advance(1.0)
	check(event_log.size() == 1, "scrubbing past impact suppresses a false late event")
	hero.play_state("walk", true)
	hero.advance(0.36)
	hero.play_state("walk", false)
	check(hero.frame == 3, "same-state play without restart preserves animation clock")
	var preview: Node2D = HeroScript.new()
	preview.autoplay = false
	preview.position = Vector2(90, 120)
	preview.facing = "up"
	root.add_child(preview)
	preview.sync_from(hero)
	check(preview.frame == hero.frame and preview.state == hero.state, "preview synchronization copies playback")
	check(preview.facing == "up" and preview.position == Vector2(90, 120), "synchronization preserves own facing and feet")
	preview.queue_free()

func _test_atlases(hero: Node2D) -> void:
	check(FileAccess.file_exists(HeroScript.MANIFEST_PATH), "generated manifest exists")
	var heroes: Array = hero.manifest["heroes"]
	check(heroes.size() == 3, "three original hero sheets")
	var loaded_heroes: int = 0
	for record: Dictionary in heroes:
		var path: String = str(record["path"])
		check(FileAccess.file_exists(path), "atlas exists: " + path)
		if not FileAccess.file_exists(path):
			continue
		# Read original pixels before Godot’s importer expands transparent RGB borders.
		var atlas: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		check(atlas != null and not atlas.is_empty(), "atlas loads: " + path)
		if atlas == null or atlas.is_empty():
			continue
		loaded_heroes += 1
		check(atlas.get_size() == Vector2i(768, 2240), "8 columns × 20 rows: " + path)
		check(atlas.detect_alpha() != Image.ALPHA_NONE, "transparent alpha: " + path)
		var direction_hashes: Dictionary = {}
		for direction in DIRECTIONS:
			for animation in EXPECTED_COUNTS:
				var pixel_hashes: Dictionary = {}
				for frame_index in range(int(EXPECTED_COUNTS[animation])):
					var bounds: Rect2i = Rect2i(hero.source_rect(animation, direction, frame_index))
					var cell: Image = atlas.get_region(bounds)
					check(not cell.get_used_rect().size == Vector2i.ZERO, "%s %s/%s frame %d contains pixels" % [record["id"], direction, animation, frame_index])
					var used: Rect2i = cell.get_used_rect()
					check(used.position.x > 0 and used.position.y > 0 and used.end.x < 96 and used.end.y < 112, "%s %s/%s frame %d has unclipped edges" % [record["id"], direction, animation, frame_index])
					pixel_hashes[hash(cell.get_data())] = true
				check(pixel_hashes.size() > 1, "%s %s/%s contains animated pixel changes" % [record["id"], direction, animation])
				var declared_animations: Dictionary = record.get("animations", {})
				var declared_clip: Dictionary = declared_animations.get(animation + "_" + direction, {})
				if declared_clip.has("unique_frames"):
					check(pixel_hashes.size() == int(declared_clip["unique_frames"]), "pixel uniqueness matches manifest: %s/%s/%s" % [record["id"], direction, animation])
			var idle: Image = atlas.get_region(Rect2i(hero.source_rect("idle", direction, 0)))
			direction_hashes[hash(idle.get_data())] = true
		check(direction_hashes.size() == 4, "four genuinely distinct first-frame facings: " + str(record["id"]))
		var left: Image = atlas.get_region(Rect2i(hero.source_rect("idle", "left", 0)))
		var right: Image = atlas.get_region(Rect2i(hero.source_rect("idle", "right", 0)))
		left.flip_x()
		check(left.get_data() != right.get_data(), "left/right are not a mirrored row: " + str(record["id"]))
	check(loaded_heroes == 3, "all three source atlases inspected")

func _test_studio() -> void:
	var studio: Node2D = STUDIO.instantiate()
	root.add_child(studio)
	await process_frame
	studio.set_process(false)
	check(studio.previews.size() == 4, "studio creates four directional previews")
	if ResourceLoader.exists("res://assets/fonts/PixelifySans.ttf"):
		check(studio.ui.theme.default_font.resource_path == "res://assets/fonts/PixelifySans.ttf", "studio locally inherits shared Pixelify font")
	if ResourceLoader.exists("res://assets/ui/panel_normal.png"):
		check(studio.pause_button.get_theme_stylebox("normal") is StyleBoxTexture, "studio uses original pixel bevel frame")
	for index in range(3):
		studio.select_hero(index)
		check(studio.hero.hero_index == index, "hero button selects " + str(index))
		for preview: Node2D in studio.previews:
			check(preview.hero_index == index, "preview changes hero " + str(index))
	studio.select_state("walk")
	studio.hero.seek_frame(7)
	studio._update_status()
	studio.select_state("hurt")
	check(studio.hero.frame == 0 and not studio.paused, "shorter clip selection does not trigger slider scrubbing")
	studio.hero.advance(0.3)
	check(studio.hero.state == "idle", "studio hurt recovers")
	studio.select_state("death")
	studio.hero.advance(10.0)
	check(studio.hero.frame == 5, "studio death holds final frame")
	studio.reset_preview()
	check(studio.hero.state == "idle" and studio.hero.position == Vector2(900, 526), "studio reset restores idle and location")
	studio.select_state("attack")
	studio._scrub_frame(3)
	check(studio.paused and studio.hero.frame == 3, "frame scrub pauses accurately")
	for preview: Node2D in studio.previews:
		check(preview.frame == 3 and preview.state == "attack", "scrub synchronizes facing previews")
	studio.toggle_pause()
	check(not studio.paused, "pause control resumes")
	studio.cycle_speed()
	check(is_equal_approx(studio.playback_speed, 2.0), "speed cycles to 2×")
	studio.cycle_speed()
	check(is_equal_approx(studio.playback_speed, 0.5), "speed cycles to half speed")
	studio.cycle_speed()
	check(is_equal_approx(studio.playback_speed, 1.0), "speed returns to normal")
	for direction in DIRECTIONS:
		studio.select_facing(direction)
		check(studio.hero.facing == direction, "direction control: " + direction)
	# Exercise real held-key polling, movement, facing, and release-to-idle.
	var movement_keys: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
	var movement_directions: Array[String] = ["left", "right", "up", "down"]
	for index in range(movement_keys.size()):
		studio.reset_preview()
		var start: Vector2 = studio.hero.position
		var pressed: InputEventKey = InputEventKey.new()
		pressed.keycode = movement_keys[index]
		pressed.pressed = true
		Input.parse_input_event(pressed)
		Input.flush_buffered_events()
		studio._process(0.05)
		check(studio.hero.position != start, "arrow key moves actor: " + movement_directions[index])
		check(studio.hero.state == "walk" and studio.hero.facing == movement_directions[index], "arrow key selects directional walk: " + movement_directions[index])
		var released: InputEventKey = InputEventKey.new()
		released.keycode = movement_keys[index]
		released.pressed = false
		Input.parse_input_event(released)
		Input.flush_buffered_events()
		studio._process(0.01)
		check(studio.hero.state == "idle", "arrow release returns to idle: " + movement_directions[index])
	studio.select_state("death")
	var death_position: Vector2 = studio.hero.position
	var held: InputEventKey = InputEventKey.new()
	held.keycode = KEY_RIGHT
	held.pressed = true
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	studio._process(1.0)
	check(studio.hero.position == death_position and studio.hero.state == "death", "walking input cannot interrupt death")
	var unheld: InputEventKey = InputEventKey.new()
	unheld.keycode = KEY_RIGHT
	unheld.pressed = false
	Input.parse_input_event(unheld)
	Input.flush_buffered_events()
	studio.reset_preview()
	var keyboard_states: Dictionary = {KEY_SPACE: "attack", KEY_H: "hurt", KEY_K: "death", KEY_R: "idle"}
	for key in keyboard_states:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.pressed = true
		studio._unhandled_key_input(event)
		check(studio.hero.state == keyboard_states[key], "keyboard shortcut selects " + str(keyboard_states[key]))
	studio.set_checker(false)
	check(not studio.show_checker, "checkerboard hides")
	studio.set_checker(true)
	studio.set_anchors(false)
	check(not studio.hero.show_anchor, "foot anchor hides")
	studio.set_anchors(true)
	check(studio.hero.show_anchor, "foot anchor restores")
	for control: Node in studio.ui.get_children():
		if control is Button or control is HSlider:
			check(control.position.x >= 0 and control.position.y >= 0 and control.position.x + control.size.x <= 1440 and control.position.y + control.size.y <= 900, "studio control within logical viewport: " + control.name)
			if control is Button:
				var font: Font = control.get_theme_font("font")
				var font_size: int = control.get_theme_font_size("font_size")
				var width: float = font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				check(width <= control.size.x - 16, "button text fits: " + control.text)
	studio.queue_free()
	await process_frame

func _test_scene_transitions() -> void:
	# Use the actual current_scene lifecycle: changing scenes detaches the sender.
	# Repeating the route also catches stale input and queued scene callbacks.
	for cycle in range(3):
		var result: Error = change_scene_to_packed(STUDIO)
		check(result == OK, "real studio scene transition starts")
		if result != OK:
			return
		await scene_changed
		check(current_scene != null and current_scene.scene_file_path == "res://character_studio.tscn", "studio becomes SceneTree.current_scene")
		if cycle < 2:
			var escape: InputEventKey = InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			Input.parse_input_event(escape)
			Input.flush_buffered_events()
			var release: InputEventKey = InputEventKey.new()
			release.keycode = KEY_ESCAPE
			release.pressed = false
			Input.parse_input_event(release)
			Input.flush_buffered_events()
		else:
			var found_back: bool = false
			for control: Node in current_scene.ui.get_children():
				if control is Button and control.text == "ESC  Back to game":
					found_back = true
					control.pressed.emit()
					break
			check(found_back, "studio has an actionable Back to game button")
			if not found_back:
				return
		await scene_changed
		check(current_scene != null and current_scene.scene_file_path == "res://main.tscn", "Escape/back returns to real main scene, cycle " + str(cycle + 1))
		check(current_scene.ui.get_child_count() > 0 and current_scene.menu, "main scene renders menu after studio exit")
		current_scene.model.persist_meta = false
		await process_frame
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
