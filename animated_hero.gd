class_name DirectionalHero
extends Node2D
## Original, foot-anchored, four-facing sprite-sheet animation.
## Position is the foot position. Clips never change this node's transform.

signal state_changed(animation: String)
signal animation_finished(animation: String)
signal animation_event(animation: String, event_name: String)

const GeneratedArt = preload("res://generated_actor_art.gd")
const ALPHA_SHADER: Shader = preload("res://assets/generated/actor_alpha.gdshader")

const MANIFEST_PATH: String = "res://assets/heroes/manifest.json"
const DEFAULT_MANIFEST: Dictionary = {
	"frame_size": [96, 112], "anchor": [48, 101],
	"directions": ["down", "left", "right", "up"],
	"state_order": ["idle", "walk", "attack", "hurt", "death"],
	"states": {
		"idle": {"frames": 6, "fps": 6, "loop": true},
		"walk": {"frames": 8, "fps": 10, "loop": true},
		"attack": {"frames": 8, "fps": 12, "loop": false},
		"hurt": {"frames": 3, "fps": 10, "loop": false},
		"death": {"frames": 6, "fps": 8, "loop": false}
	},
	"heroes": [
		{"id": "mara", "path": "res://assets/heroes/mara.png"},
		{"id": "ivo", "path": "res://assets/heroes/ivo.png"},
		{"id": "sable", "path": "res://assets/heroes/sable.png"}
	]
}

@export_range(0, 2) var hero_index: int = 0:
	set(value):
		hero_index = clampi(value, 0, 2)
		if is_node_ready():
			_load_texture()
		queue_redraw()
@export var autoplay: bool = true
@export var show_anchor: bool = false:
	set(value):
		show_anchor = value
		queue_redraw()
@export var playback_speed: float = 1.0
var facing: String = "down":
	set(value):
		if value in ["down", "left", "right", "up"]:
			facing = value
			queue_redraw()
var state: String = "idle"
var frame: int = 0
## Elapsed seconds in the current clip; frame = floor(time * clip FPS).
var time: float = 0.0
var atlas_texture: Texture2D
var manifest: Dictionary = DEFAULT_MANIFEST.duplicate(true)
var _finished: bool = false
var _impact_emitted: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var clean_alpha: ShaderMaterial = ShaderMaterial.new()
	clean_alpha.shader = ALPHA_SHADER
	material = clean_alpha
	reload_assets()

func reload_assets() -> void:
	if FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary:
			var data: Dictionary = parsed
			if data.has_all(["frame_size", "anchor", "directions", "state_order", "states", "heroes"]):
				manifest = data
	_load_texture()
	queue_redraw()

func _load_texture() -> void:
	var heroes: Array = manifest.get("heroes", DEFAULT_MANIFEST["heroes"])
	var record: Dictionary = heroes[clampi(hero_index, 0, heroes.size() - 1)]
	var path: String = str(record.get("path", ""))
	atlas_texture = load(path) as Texture2D if ResourceLoader.exists(path) else null

func _process(delta: float) -> void:
	if autoplay:
		advance(delta * maxf(playback_speed, 0.0))

func set_facing(direction: String) -> void:
	facing = direction

func play_state(animation: String, restart: bool = false) -> bool:
	var states: Dictionary = manifest["states"]
	if not states.has(animation):
		return false
	if animation == state and not restart:
		return true
	state = animation
	frame = 0
	time = 0.0
	_finished = false
	_impact_emitted = false
	state_changed.emit(state)
	queue_redraw()
	return true

func frame_count(animation: String = "") -> int:
	var clip: Dictionary = manifest["states"].get(state if animation.is_empty() else animation, {})
	return maxi(1, int(clip.get("frames", 1)))

func clip_fps(animation: String = "") -> float:
	var clip: Dictionary = manifest["states"].get(state if animation.is_empty() else animation, {})
	return maxf(0.001, float(clip.get("fps", 1.0)))

func clip_loops(animation: String = "") -> bool:
	var clip: Dictionary = manifest["states"].get(state if animation.is_empty() else animation, {})
	return bool(clip.get("loop", false))

func frame_size() -> Vector2:
	var dimensions: Array = manifest["frame_size"]
	return Vector2(float(dimensions[0]), float(dimensions[1]))

func foot_anchor() -> Vector2:
	var anchor: Array = manifest["anchor"]
	return Vector2(float(anchor[0]), float(anchor[1]))

func hero_id() -> String:
	var heroes: Array = manifest["heroes"]
	var record: Dictionary = heroes[clampi(hero_index, 0, heroes.size() - 1)]
	return str(record["id"])

func source_rect(animation: String = "", direction: String = "", frame_index: int = -1) -> Rect2:
	var selected_state: String = state if animation.is_empty() else animation
	var selected_direction: String = facing if direction.is_empty() else direction
	var directions: Array = manifest["directions"]
	var states: Array = manifest["state_order"]
	var direction_index: int = maxi(0, directions.find(selected_direction))
	var state_index: int = maxi(0, states.find(selected_state))
	var selected_frame: int = frame if frame_index < 0 else frame_index
	selected_frame = clampi(selected_frame, 0, frame_count(selected_state) - 1)
	var size_pixels: Vector2 = frame_size()
	return Rect2(Vector2(selected_frame * size_pixels.x, (direction_index * states.size() + state_index) * size_pixels.y), size_pixels)

func advance(delta: float) -> void:
	if delta <= 0.0 or _finished:
		return
	var count: int = frame_count()
	var fps: float = clip_fps()
	var duration: float = float(count) / fps
	var next_time: float = time + delta
	if state == "attack" and not _impact_emitted and next_time >= 4.0 / fps:
		_impact_emitted = true
		animation_event.emit("attack", "impact")
	if clip_loops():
		time = fposmod(next_time, duration)
		frame = mini(count - 1, int(floor(time * fps + 0.000001)))
	elif next_time >= duration:
		time = duration
		frame = count - 1
		_finished = true
		var completed: String = state
		animation_finished.emit(completed)
		# A completion listener may already have selected another animation.
		if state == completed and (completed == "attack" or completed == "hurt"):
			play_state("idle", true)
			advance(next_time - duration)
	else:
		time = next_time
		frame = mini(count - 1, int(floor(time * fps + 0.000001)))
	queue_redraw()

## Inspection-only seek: no combat events are emitted by scrubbing.
func seek_frame(frame_index: int) -> void:
	frame = clampi(frame_index, 0, frame_count() - 1)
	time = float(frame) / clip_fps()
	_finished = false
	_impact_emitted = state == "attack" and frame >= 4
	queue_redraw()

## Copy the playback clock without changing this preview's own facing or feet.
func sync_from(other: Node2D) -> void:
	state = other.state
	frame = other.frame
	time = other.time
	_finished = other._finished
	_impact_emitted = other._impact_emitted
	queue_redraw()

func _draw() -> void:
	if GeneratedArt.TEXTURE != null:
		GeneratedArt.draw_hero(self, hero_index, facing, state, frame, frame_count())
	elif atlas_texture != null:
		draw_texture_rect_region(atlas_texture, Rect2(-foot_anchor(), frame_size()), source_rect())
	else:
		# Keeps the scene inspectable before art import, without inventing a sprite.
		draw_rect(Rect2(-foot_anchor(), frame_size()), Color("27373c"), false, 1.0)
	if show_anchor:
		draw_circle(Vector2.ZERO, 3.0, Color("78c9be"), false, 0.7)
		draw_line(Vector2(-7, 0), Vector2(7, 0), Color("78c9be"), 0.7)
		draw_line(Vector2(0, -7), Vector2(0, 7), Color("78c9be"), 0.7)
