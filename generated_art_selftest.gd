extends SceneTree
const Art=preload("res://generated_actor_art.gd")
const Hero=preload("res://animated_hero.gd")
const Monster=preload("res://generated_monster.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok: failures.append(description)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var image: Image=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/actors_master.webp"))
	check(image.get_size()==Vector2i(1254,1254),"original generated master dimensions")
	check(image.detect_alpha()!=Image.ALPHA_NONE,"generated alpha retained")
	for hero_index in range(3):
		var hashes: Dictionary={}
		for facing: String in Art.DIRECTIONS:
			var region: Rect2=Art.hero_region(hero_index,facing)
			check(Rect2(Vector2.ZERO,image.get_size()).encloses(region),"hero region inside master")
			var pose: Image=image.get_region(Rect2i(region))
			check(pose.get_used_rect().size.x>150 and pose.get_used_rect().size.y>150,"hero region has image pixels")
			hashes[hash(pose.get_data())]=true
			check(Art.hero_size(hero_index,facing).x<=86.01,"sprite width fits studio")
			for state: String in ["idle","walk","attack","hurt","death"]:
				var count: int={"idle":6,"walk":8,"attack":8,"hurt":3,"death":6}[state]
				var frames: Dictionary={}
				for frame in range(count):
					var mesh: PackedVector2Array=[]
					for uv: Vector2 in [Vector2(0.15,0.2),Vector2(0.8,0.5),Vector2(0.25,0.92),Vector2(0.5,1.0)]:
						mesh.append(Art.rig_offset(uv,state,frame,count,facing))
					frames[hash(mesh)]=true
				check(frames.size()>1,"generated rig animates: %s/%d/%s" %[facing,hero_index,state])
				check(Art.rig_offset(Vector2(0.5,1),state,0,count,facing).is_zero_approx(),"foot center stays fixed")
		check(hashes.size()==4,"four unique generated direction poses")
	for variant in range(3):
		var region: Rect2=Art.MONSTER_REGIONS[variant]
		check(Rect2(Vector2.ZERO,image.get_size()).encloses(region),"monster region inside master")
		var pose: Image=image.get_region(Rect2i(region))
		check(pose.get_used_rect().size.x>230 and pose.get_used_rect().size.y>300,"monster texture is populated")
		var monster: Node2D=Monster.new()
		root.add_child(monster)
		for part in range(3):
			var cuts: Array=[false,false,false]; cuts[part]=true
			monster.configure(variant,Vector2(600,500),0.9,cuts,0.2,0.0,part)
			check(monster.severed[part],"body sever state passed to generated monster")
		monster.queue_free()
	var hero: Node2D=Hero.new();root.add_child(hero)
	check(hero.material is ShaderMaterial,"generated actor alpha shader active")
	hero.queue_free()
	await process_frame
	print("GENERATED ART: %d checks; %d failures" %[checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
