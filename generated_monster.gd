class_name GeneratedMonster
extends Node2D
## Generated monster sprites with separately severable head, arms and legs.
const FxAnchors = preload("res://combat_fx/fx_anchors.gd")
const Art = preload("res://generated_actor_art.gd")
var variant: int=0
var severed: Array=[false,false,false]
var render_scale: float=1.0
var elapsed: float=0.0
var flash: float=0.0
var selected_part: int=-1
var dissolve: float=0.0
var _shader: ShaderMaterial
var _target_ring: Node2D

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var shader: Shader=Shader.new()
	shader.code="""
shader_type canvas_item;
uniform vec4 source_rect;
uniform vec3 cuts;
uniform float alpha_floor = 0.10;
uniform float dissolve = 0.0;
uniform int hit_target = -1;
uniform float hit_strength = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = (UV - source_rect.xy) / source_rect.zw;
	bool head = p.y < 0.37 && p.x > 0.24 && p.x < 0.70;
	bool arms = !head && p.y > 0.30 && p.y < 0.82 && (p.x < 0.28 || p.x > 0.72);
	bool legs = p.y >= 0.76 && !arms;
	if (tex.a < alpha_floor || (head && cuts.z > 0.5) || (arms && cuts.y > 0.5) || (legs && cuts.x > 0.5)) discard;
	// Erode only the surviving silhouette; severed parts never regrow.
	vec2 cell = floor(p * vec2(85.0, 94.0));
	float ash = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	if (dissolve > 0.0 && ash < dissolve) discard;
	float edge = dissolve > 0.0 ? 1.0 - smoothstep(dissolve, dissolve + 0.12, ash) : 0.0;
	COLOR.rgb = mix(COLOR.rgb, vec3(0.95, 0.76, 0.46), edge * 0.75);
	bool target_hit = (hit_target == 0 && legs) || (hit_target == 1 && arms) || (hit_target == 2 && head);
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0,0.94,0.77), target_hit ? hit_strength : 0.0);
	COLOR.a *= 1.0 - dissolve * 0.65;
}
"""
	_shader=ShaderMaterial.new()
	_shader.shader=shader
	material=_shader
	_target_ring=Node2D.new()
	_target_ring.draw.connect(_draw_target_ring)
	add_child(_target_ring)

func configure(which: int, feet: Vector2, size_scale: float, parts: Array, clock: float, hit: float, target: int, death_progress: float=0.0) -> void:
	variant=clampi(which,0,2)
	position=feet
	render_scale=size_scale
	severed=parts.duplicate()
	elapsed=clock
	flash=hit
	selected_part=target
	dissolve=clampf(death_progress,0.0,1.0)
	var source: Rect2=Art.MONSTER_REGIONS[variant]
	var ts: Vector2=Art.TEXTURE.get_size()
	_shader.set_shader_parameter("source_rect",Vector4(source.position.x/ts.x,source.position.y/ts.y,source.size.x/ts.x,source.size.y/ts.y))
	_shader.set_shader_parameter("cuts",Vector3(float(severed[0]),float(severed[1]),float(severed[2])))
	_shader.set_shader_parameter("dissolve",dissolve)
	_shader.set_shader_parameter("hit_target",selected_part)
	_shader.set_shader_parameter("hit_strength",clampf(flash,0.0,0.45))
	queue_redraw()
	_target_ring.queue_redraw()

func _draw() -> void:
	var source: Rect2=Art.MONSTER_REGIONS[variant]
	var height: float=366.0*render_scale
	var width: float=source.size.x/source.size.y*height
	var sink: float=64.0*render_scale if severed[0] else 0.0
	var bob: float=sin(elapsed*1.4)*1.1*render_scale
	var dest: Rect2=Rect2(Vector2(-width/2.0,-height+sink+bob),Vector2(width,height))
	draw_set_transform(Vector2(0,dissolve*12.0*render_scale),dissolve*0.06)
	draw_texture_rect_region(Art.TEXTURE,dest,source,Color.WHITE)
	draw_set_transform(Vector2.ZERO)

func _draw_target_ring() -> void:
	if selected_part<0 or selected_part>2 or severed[selected_part]: return
	var offsets: Array[Vector2]=FxAnchors.PARTS
	var sink: float=64.0*render_scale if severed[0] else 0.0
	var target: Vector2=offsets[selected_part]*render_scale+Vector2(0,sink)
	_target_ring.draw_arc(target,25*render_scale,elapsed,elapsed+4.9,30,Color("14202a"),5)
	_target_ring.draw_arc(target,25*render_scale,elapsed,elapsed+4.9,30,Color("e4c383"),2)
	_target_ring.draw_arc(target,30*render_scale,-elapsed,-elapsed+1.4,12,Color(0.9,0.76,0.50,0.55),1)
