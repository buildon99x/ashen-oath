extends Node2D
## Presentation only. No model, persistence, global time scale or combat RNG writes.
signal impacted(event: Dictionary)
signal completed
const Anchors = preload("res://combat_fx/fx_anchors.gd")
const INK = Color("0e171e")
const GOLD = Color("d6b77d")
const TEAL = Color("78c9be")
const PALE = Color("e4e5db")
const RUPTURE = Color("ce785f")
var queue: Array[Dictionary] = []
var current: Dictionary = {}
var elapsed: float = 0.0
var impact_age: float = -1.0
var hold_remaining: float = 0.0
var impact_count: int = 0
var font: Font
var reduced: bool = true
var view

func busy() -> bool:
	return not current.is_empty()
func enqueue(events: Array) -> void:
	for event in events: queue.append(event)
	if not busy(): _next()
func _next() -> void:
	if queue.is_empty():
		current = {}
		view = null
		queue_redraw()
		completed.emit()
		return
	current = queue.pop_front()
	view = current.before
	if current.kind == "enemy":
		view = current.before.duplicate_view()
		view.heroes = current.display_before_heroes.duplicate(true)
	elapsed = 0.0
	impact_age = -1.0
	hold_remaining = 0.0
	queue_redraw()
func impact(hero: int = -1) -> void:
	if not busy() or impact_age >= 0.0: return
	if current.kind == "hero" and hero != int(current.hero_index): return
	impact_age = 0.0
	impact_count += 1
	view = current.after if current.kind != "enemy" else current.before
	if current.kind == "enemy":
		# A value-only copy carries cumulative per-source losses; next-round heals
		# and recovery are displayed only after the last source resolves.
		view = current.before.duplicate_view()
		view.heroes = current.display_heroes.duplicate(true)
	hold_remaining = 2.0/60.0 if current.kind == "hero" else 0.0
	impacted.emit(current)
	queue_redraw()
func advance(delta: float) -> void:
	if not busy(): return
	var step: float = maxf(delta,0.0)
	if hold_remaining > 0.0:
		var held: float = minf(step,hold_remaining)
		hold_remaining -= held
		step -= held
	elapsed += step
	if current.kind != "hero" and impact_age < 0.0 and elapsed >= (0.12 if current.kind == "guard" else 0.20): impact()
	if impact_age >= 0.0:
		impact_age += step
		var tail: float = 0.30 if current.kind == "hero" else 0.25
		if current.get("severs",false): tail = 0.40
		if impact_age >= tail: _next()
	elif elapsed >= 1.2:
		# Broken/missing actor marker cannot strand UI. Snap final state without
		# inventing an impact or replaying a command.
		_next()
	queue_redraw()
func skip() -> void:
	if not busy(): return
	queue.clear()
	current = {}
	view = null
	hold_remaining = 0.0
	queue_redraw()
	completed.emit()
func clear() -> void:
	queue.clear()
	current = {}
	view = null
	hold_remaining = 0.0
	queue_redraw()
func _pixel(point: Vector2, size: float, color: Color) -> void:
	draw_rect(Rect2((point/2.0).round()*2.0,Vector2(size,size)),color)
func _segment(a: Vector2,b: Vector2,width: float,color: Color) -> void:
	var distance: float = a.distance_to(b)
	for i in range(int(ceil(distance/3.0))+1): _pixel(a.lerp(b,minf(1,float(i)*3.0/maxf(1,distance))),width,color)
func _diamond(point: Vector2,radius: float,color: Color,width: float = 3.0) -> void:
	var p: Array = [Vector2(0,-radius),Vector2(radius,0),Vector2(0,radius),Vector2(-radius,0),Vector2(0,-radius)]
	for i in range(4): _segment(point+p[i],point+p[i+1],width,color)
func _number(point: Vector2,text: String,color: Color) -> void:
	if font == null: return
	draw_string_outline(font,point,text,HORIZONTAL_ALIGNMENT_CENTER,-1,27,7,INK)
	draw_string(font,point,text,HORIZONTAL_ALIGNMENT_CENTER,-1,27,color)
func _draw() -> void:
	if not busy(): return
	var target: Vector2 = current.to_anchor
	var source: Vector2 = current.from_anchor
	if current.kind == "enemy":
		_draw_enemy()
		return
	if current.kind == "guard":
		var p: float = clampf(elapsed/0.37,0,1)
		_diamond(target,26+sin(p*PI)*12,INK,7)
		_diamond(target,26+sin(p*PI)*12,Color(TEAL,1-p*0.7),3)
		if impact_age >= 0:
			for heal in current.heals: _number(Anchors.hero(heal.hero)+Vector2(-18,-42),"+%d" % heal.amount,TEAL)
		return
	var color: Color = TEAL if current.damage_type == "arcane" else (PALE if int(current.hero_index)==2 else GOLD)
	if impact_age < 0.0:
		# Wind-up approaches the locked pre-sever target, with no premature hit.
		var p: float = clampf(elapsed/(4.0/12.0),0,1)
		var head: Vector2 = source.lerp(target,clampf((p-0.35)/0.65,0,0.92))
		_segment(head-Vector2(14,4),head,6,INK)
		_segment(head-Vector2(12,2),head,2,color)
		return
	var p: float = clampf(impact_age/0.40,0,1)
	if current.skill_id == "mara_sundering_arc":
		# A stepped, thick C-shaped wedge, not a smooth neon ring.
		for layer in range(3):
			for i in range(32):
				var fraction: float = float(i)/31.0
				var angle: float = -2.3+fraction*4.5
				var radius: float = 42+sin(p*PI)*20
				var radial: Vector2 = Vector2(cos(angle),sin(angle))
				var point: Vector2 = target+radial*radius
				var thickness: float = 3+sin(fraction*PI)*13
				var width: float = thickness+4 if layer==0 else (thickness if layer==1 else 5)
				var shade: Color = INK if layer==0 else (GOLD if layer==1 else PALE)
				_pixel(point+(radial*3 if layer==2 else Vector2.ZERO)-Vector2.ONE*width/2,width,Color(shade,1-p))
	else:
		_segment(target+Vector2(-24,-22)*(1+p),target+Vector2(22,21)*(1+p),8,Color(INK,1-p))
		_segment(target+Vector2(-22,-20)*(1+p),target+Vector2(20,19)*(1+p),3,Color(color,1-p))
	if impact_age < 0.07: _diamond(target,(14 if current.weakness else 8) if reduced else 18,PALE,3)
	if current.breaks:
		_diamond(target,24+p*35,Color(INK,1-p),7)
		for i in range(8):
			var direction = Vector2(cos(i*TAU/8),sin(i*TAU/8))
			_pixel(target+direction*(22+p*62),5,Color(GOLD,1-p))
	elif current.severs:
		for i in range(18):
			var x: float = sin(float(i*29+int(current.presentation_seed)))*32
			var y: float = float(i%5)*11-22
			_pixel(target+Vector2(x*(1+p),y-p*(30+i%4*12)),4,Color(RUPTURE if i%3==0 else INK,1-p))
		_segment(target+Vector2(-24,-18),target+Vector2(8,4),3,Color(RUPTURE,1-p))
		_segment(target+Vector2(8,4),target+Vector2(-10,26),3,Color(RUPTURE,1-p))
	elif int(current.actual_shield_loss)>0:
		for i in range(4): _pixel(target+Vector2((i-1.5)*(10+p*18),-10-p*35),4,Color(GOLD,1-p))
	if int(current.actual_hp_loss)>0: _number(target+Vector2(-13,-30-p*30),str(current.actual_hp_loss),PALE)
	for heal in current.heals: _number(Anchors.hero(heal.hero)+Vector2(-18,-42-p*15),"+%d" % heal.amount,TEAL)
func _draw_enemy() -> void:
	var attack: Dictionary = current.attack
	var source: Vector2 = current.from_anchor
	var p: float = clampf(elapsed/0.45,0,1)
	if attack.status in ["cancelled","missed"]:
		_diamond(source,22*(1-p),Color(INK,1-p),7)
		_diamond(source,22*(1-p),Color(TEAL,1-p),2)
		return
	for hero in attack.targets:
		var target: Vector2 = Anchors.hero(hero)
		var loss: int = int(attack.losses[hero])
		if hero in current.wards:
			_diamond(target,28,INK,7)
			_diamond(target,28,Color(TEAL,1-p*0.5),3)
			if impact_age >= 0: _diamond(target,14*(1-p),PALE,2)
			continue
		if loss<=0: continue
		if impact_age < 0:
			var head: Vector2 = source.lerp(target,clampf(elapsed/0.20,0,1))
			_segment(head-Vector2(9,5),head,6,INK)
			_segment(head-Vector2(8,4),head,3,GOLD if attack.source_status=="staggered" else RUPTURE)
		else:
			_diamond(target,10+p*10,Color(RUPTURE,1-p),3)
			_number(target+Vector2(-12,-40-p*18),"-%d" % loss,RUPTURE)
