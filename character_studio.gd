extends Node2D
## In-game animation viewer. Arrows move the character; no model/save mutation.

const HeroScript = preload("res://animated_hero.gd")
const GOLD: Color = Color("d6b77d")
const TEAL: Color = Color("78c9be")
const INK: Color = Color("0e171e")
const PALE: Color = Color("e4e5db")
const MUTED: Color = Color("91a6a7")
const DIRECTIONS: Array[String] = ["down", "left", "right", "up"]
const STATES: Array[String] = ["idle", "walk", "attack", "hurt", "death"]
const HERO_NAMES: Array[String] = ["MARA", "IVO", "SABLE"]
const HERO_TITLES: Array[String] = ["Ironbound", "Ash Cantor", "Gloam Scout"]
const INITIAL_FOOT: Vector2 = Vector2(900, 526)

var ui: Control
var hero: Node2D
var previews: Array[Node2D] = []
var selected_hero: int = 0
var paused: bool = false
var show_checker: bool = true
var show_anchors: bool = true
var playback_speed: float = 1.0
var frame_slider: HSlider
var status_label: Label
var title_label: Label
var fps_label: Label
var event_label: Label
var pause_button: Button
var speed_button: Button
var hero_buttons: Array[Button] = []
var state_buttons: Dictionary = {}
var direction_buttons: Dictionary = {}
var _motion_owned: bool = false
var _event_seconds: float = 0.0
var _pixel_frames: Dictionary = {}

func _ready() -> void:
	RenderingServer.set_default_clear_color(INK)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero = HeroScript.new()
	hero.autoplay = false
	hero.show_anchor = show_anchors
	hero.position = INITIAL_FOOT
	hero.scale = Vector2(2.5, 2.5)
	add_child(hero)
	for index in range(DIRECTIONS.size()):
		var preview: Node2D = HeroScript.new()
		preview.autoplay = false
		preview.facing = DIRECTIONS[index]
		preview.show_anchor = show_anchors
		preview.position = Vector2(515 + 256 * index, 832)
		preview.scale = Vector2(1.4, 1.4)
		add_child(preview)
		previews.append(preview)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Local inheritance keeps the studio consistent without changing ThemeDB.
	var studio_theme: Theme = Theme.new()
	if ResourceLoader.exists("res://assets/fonts/PixelifySans.ttf"):
		studio_theme.default_font = load("res://assets/fonts/PixelifySans.ttf") as Font
	studio_theme.default_font_size = 16
	ui.theme = studio_theme
	add_child(ui)
	_build_ui()
	hero.state_changed.connect(_on_state_changed)
	hero.animation_event.connect(_on_animation_event)
	_refresh_ui()

func _process(delta: float) -> void:
	_handle_movement(delta)
	if not paused:
		hero.advance(delta * playback_speed)
	for preview in previews:
		preview.sync_from(hero)
	if _event_seconds > 0.0:
		_event_seconds = maxf(0.0, _event_seconds - delta)
		if is_zero_approx(_event_seconds):
			event_label.text = "Clips hold their foot anchor; movement is controlled separately"
	_update_status()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	match key:
		KEY_ESCAPE:
			# Scene changes detach this node immediately; consume input first.
			get_viewport().set_input_as_handled()
			_return_to_game()
			return
		KEY_1, KEY_2, KEY_3:
			select_hero(key - KEY_1)
		KEY_SPACE:
			select_state("attack")
		KEY_H:
			select_state("hurt")
		KEY_K:
			select_state("death")
		KEY_R:
			reset_preview()
		KEY_P:
			toggle_pause()
		KEY_C:
			set_checker(not show_checker)
		KEY_A:
			set_anchors(not show_anchors)
		_:
			return
	get_viewport().set_input_as_handled()

func _handle_movement(delta: float) -> void:
	if paused or hero.state in ["attack", "hurt", "death"]:
		return
	var direction: Vector2 = Vector2.ZERO
	# Cardinal walking makes the four independently generated facings explicit.
	if Input.is_key_pressed(KEY_LEFT):
		direction = Vector2.LEFT
	elif Input.is_key_pressed(KEY_RIGHT):
		direction = Vector2.RIGHT
	elif Input.is_key_pressed(KEY_UP):
		direction = Vector2.UP
	elif Input.is_key_pressed(KEY_DOWN):
		direction = Vector2.DOWN
	if direction == Vector2.ZERO:
		if _motion_owned:
			_motion_owned = false
			if hero.state == "walk":
				hero.play_state("idle")
		return
	var new_facing: String = "left" if direction.x < 0.0 else "right" if direction.x > 0.0 else "up" if direction.y < 0.0 else "down"
	if hero.facing != new_facing:
		hero.set_facing(new_facing)
		_refresh_ui()
	_motion_owned = true
	hero.play_state("walk")
	hero.position += direction * delta * 155.0 * playback_speed
	hero.position.x = clampf(hero.position.x, 530.0, 1268.0)
	hero.position.y = clampf(hero.position.y, 460.0, 541.0)

func select_hero(index: int) -> void:
	selected_hero = clampi(index, 0, HERO_NAMES.size() - 1)
	hero.hero_index = selected_hero
	for preview in previews:
		preview.hero_index = selected_hero
	reset_preview()

func select_state(animation: String) -> void:
	_motion_owned = false
	hero.play_state(animation, true)
	paused = false
	_refresh_ui()

func select_facing(direction: String) -> void:
	hero.set_facing(direction)
	_refresh_ui()

func reset_preview() -> void:
	hero.position = INITIAL_FOOT
	hero.play_state("idle", true)
	paused = false
	_motion_owned = false
	_refresh_ui()

func toggle_pause() -> void:
	paused = not paused
	_refresh_ui()

func cycle_speed() -> void:
	playback_speed = 2.0 if is_equal_approx(playback_speed, 1.0) else 0.5 if is_equal_approx(playback_speed, 2.0) else 1.0
	_refresh_ui()

func set_checker(enabled: bool) -> void:
	show_checker = enabled
	var control: CheckBox = ui.get_node("Checker") as CheckBox
	control.set_pressed_no_signal(enabled)
	queue_redraw()

func set_anchors(enabled: bool) -> void:
	show_anchors = enabled
	hero.show_anchor = enabled
	for preview in previews:
		preview.show_anchor = enabled
	var control: CheckBox = ui.get_node("Anchors") as CheckBox
	control.set_pressed_no_signal(enabled)
	queue_redraw()

func _scrub_frame(value: float) -> void:
	paused = true
	hero.seek_frame(int(value))
	for preview in previews:
		preview.sync_from(hero)
	_refresh_ui()

func _on_state_changed(_animation: String) -> void:
	_refresh_ui()

func _on_animation_event(_animation: String, event_name: String) -> void:
	event_label.text = "Animation event: %s  /  frame 05  /  foot position unchanged" % event_name.to_upper()
	_event_seconds = 1.4

func _return_to_game() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _build_ui() -> void:
	_label("A S H E N   O A T H", Vector2(38, 21), 25, GOLD)
	_label("CHARACTER STUDIO  /  GENERATED ART + ANIMATION RIG", Vector2(40, 57), 13, TEAL)
	_button("ESC  Back to game", Rect2(1182, 28, 220, 42), _return_to_game)
	_label("THE WANDERERS", Vector2(54, 130), 16, GOLD)
	for index in range(HERO_NAMES.size()):
		var entry: Button = _button("%d  %s  /  %s" % [index + 1, HERO_NAMES[index], HERO_TITLES[index]], Rect2(54, 165 + index * 57, 294, 49), select_hero.bind(index), 15)
		hero_buttons.append(entry)
	_label("ANIMATION", Vector2(54, 355), 14, TEAL)
	for index in range(STATES.size()):
		var column: int = index % 3
		var row: int = int(index / 3)
		var state_name: String = STATES[index]
		state_buttons[state_name] = _button(state_name.capitalize(), Rect2(54 + column * 101, 386 + row * 48, 92, 39), select_state.bind(state_name), 16)
	_button("R  Reset", Rect2(256, 434, 92, 39), reset_preview, 15)
	_label("FACING", Vector2(54, 495), 14, TEAL)
	for index in range(DIRECTIONS.size()):
		var direction_name: String = DIRECTIONS[index]
		direction_buttons[direction_name] = _button(direction_name.capitalize(), Rect2(54 + index * 76, 525, 66, 39), select_facing.bind(direction_name), 15)
	pause_button = _button("P  Pause", Rect2(54, 594, 141, 42), toggle_pause, 16)
	speed_button = _button("Speed  1×", Rect2(207, 594, 141, 42), cycle_speed, 16)
	_check("Anchors", "A  Show foot anchors", Vector2(52, 663), true, set_anchors)
	_check("Checker", "C  Transparency checker", Vector2(52, 703), true, set_checker)
	_label("ARROWS   Move in four directions\nSPACE   Attack     H   Hurt\nK   Death     R   Reset", Vector2(54, 761), 15, MUTED, Vector2(298, 73))
	title_label = _label("", Vector2(420, 129), 25, PALE, Vector2(750, 37))
	_label("Image-generated poses  /  2.5× preview  /  live mesh animation", Vector2(420, 167), 14, MUTED)
	_label("Hold arrow keys to walk", Vector2(1130, 138), 15, TEAL, Vector2(250, 30))
	event_label = _label("Clips hold their foot anchor; movement is controlled separately", Vector2(420, 547), 13, MUTED, Vector2(970, 25))
	status_label = _label("", Vector2(412, 597), 16, GOLD, Vector2(270, 32))
	frame_slider = HSlider.new()
	frame_slider.position = Vector2(695, 598)
	frame_slider.size = Vector2(442, 26)
	frame_slider.min_value = 0
	frame_slider.max_value = 5
	frame_slider.step = 1
	frame_slider.focus_mode = Control.FOCUS_NONE
	frame_slider.value_changed.connect(_scrub_frame)
	ui.add_child(frame_slider)
	fps_label = _label("", Vector2(1157, 597), 14, TEAL, Vector2(226, 29))
	for index in range(DIRECTIONS.size()):
		_label(DIRECTIONS[index].to_upper(), Vector2(412 + 256 * index, 674), 13, GOLD, Vector2(210, 24))
	_label("FOUR DISTINCT FACINGS  /  synchronized frames, no runtime mirroring", Vector2(397, 862), 13, MUTED)
	_label("Foot anchor  48, 101 px", Vector2(40, 862), 13, MUTED)

func _update_status() -> void:
	status_label.text = "%s  /  %s  /  %02d OF %02d" % [hero.state.to_upper(), hero.facing.to_upper(), hero.frame + 1, hero.frame_count()]
	frame_slider.set_block_signals(true)
	frame_slider.max_value = hero.frame_count() - 1
	frame_slider.set_value_no_signal(hero.frame)
	frame_slider.set_block_signals(false)
	fps_label.text = "%d FPS  ·  %s" % [int(hero.clip_fps()), "LOOP" if hero.clip_loops() else "ONE SHOT"]

func _refresh_ui() -> void:
	if ui == null or pause_button == null:
		return
	title_label.text = "%s  /  %s" % [HERO_NAMES[selected_hero], HERO_TITLES[selected_hero]]
	pause_button.text = "P  Play" if paused else "P  Pause"
	speed_button.text = "Speed  %s×" % ("0.5" if is_equal_approx(playback_speed, 0.5) else str(int(playback_speed)))
	for index in range(hero_buttons.size()):
		_mark_active(hero_buttons[index], index == selected_hero)
	for state_name in state_buttons:
		_mark_active(state_buttons[state_name], state_name == hero.state)
	for direction_name in direction_buttons:
		_mark_active(direction_buttons[direction_name], direction_name == hero.facing)
	_update_status()

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(0)
	result.content_margin_left = 10
	result.content_margin_right = 10
	return result

func _pixel_frame(variant: String) -> StyleBox:
	if _pixel_frames.has(variant):
		return _pixel_frames[variant]
	var path: String = "res://assets/ui/panel_" + variant + ".png"
	if not ResourceLoader.exists(path):
		return _style(Color("142129"), GOLD if variant == "gold" else TEAL if variant == "hover" else Color("34434a"))
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = load(path) as Texture2D
	result.texture_margin_left = 8
	result.texture_margin_right = 8
	result.texture_margin_top = 8
	result.texture_margin_bottom = 8
	result.content_margin_left = 10
	result.content_margin_right = 10
	result.content_margin_top = 8
	result.content_margin_bottom = 8
	_pixel_frames[variant] = result
	return result

func _button(text: String, bounds: Rect2, action: Callable, font_size: int = 17) -> Button:
	var control: Button = Button.new()
	control.text = text
	control.position = bounds.position
	control.size = bounds.size
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", PALE)
	control.add_theme_stylebox_override("hover", _pixel_frame("hover"))
	control.add_theme_stylebox_override("pressed", _pixel_frame("gold"))
	control.pressed.connect(action)
	ui.add_child(control)
	_mark_active(control, false)
	return control

func _mark_active(control: Button, active: bool) -> void:
	control.add_theme_color_override("font_color", GOLD if active else PALE)
	control.add_theme_stylebox_override("normal", _pixel_frame("gold" if active else "normal"))

func _label(text: String, location: Vector2, font_size: int, color: Color, dimensions: Vector2 = Vector2(980, 34)) -> Label:
	var control: Label = Label.new()
	control.text = text
	control.position = location
	control.size = dimensions
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)
	ui.add_child(control)
	return control

func _check(node_name: String, text: String, location: Vector2, value: bool, action: Callable) -> void:
	var control: CheckBox = CheckBox.new()
	control.name = node_name
	control.text = text
	control.position = location
	control.size = Vector2(298, 34)
	control.focus_mode = Control.FOCUS_NONE
	control.button_pressed = value
	control.add_theme_font_size_override("font_size", 16)
	control.add_theme_color_override("font_color", PALE)
	control.toggled.connect(action)
	ui.add_child(control)

func _checker(bounds: Rect2, cell: int = 24) -> void:
	draw_rect(bounds, Color("142027"))
	if not show_checker:
		return
	for column in range(int(ceil(bounds.size.x / cell))):
		for row in range(int(ceil(bounds.size.y / cell))):
			if (column + row) % 2 == 0:
				var tile: Rect2 = Rect2(bounds.position + Vector2(column * cell, row * cell), Vector2(cell, cell)).intersection(bounds)
				draw_rect(tile, Color("1b2930"))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 900), INK)
	draw_line(Vector2(38, 92), Vector2(1402, 92), Color("314046"), 1.0)
	draw_style_box(_pixel_frame("normal"), Rect2(36, 110, 330, 738))
	draw_style_box(_pixel_frame("normal"), Rect2(394, 110, 1010, 467))
	_checker(Rect2(407, 211, 984, 330))
	# A floor ellipse gives a stable foot reference while preserving sprite alpha.
	if hero != null:
		var shadow: PackedVector2Array = PackedVector2Array()
		for point in range(32):
			var angle: float = TAU * float(point) / 32.0
			shadow.append(hero.position + Vector2(cos(angle) * 47.0, sin(angle) * 9.0))
		draw_colored_polygon(shadow, Color(0.02, 0.04, 0.05, 0.45))
	draw_style_box(_pixel_frame("normal"), Rect2(394, 584, 1010, 60))
	for index in range(DIRECTIONS.size()):
		var bounds: Rect2 = Rect2(394 + index * 256, 661, 242, 187)
		draw_style_box(_pixel_frame("gold" if hero != null and hero.facing == DIRECTIONS[index] else "normal"), bounds)
		_checker(Rect2(bounds.position + Vector2(8, 40), Vector2(226, 137)), 16)
	draw_line(Vector2(54, 335), Vector2(348, 335), Color("314046"), 1.0)
	draw_line(Vector2(54, 579), Vector2(348, 579), Color("314046"), 1.0)
