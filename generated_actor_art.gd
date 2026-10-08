class_name GeneratedActorArt
extends RefCounted
## Image-generated 4-facing poses, animated by an original in-engine mesh rig.
## The master texture is kept intact: all cropping, motion and masking is runtime.

const TEXTURE: Texture2D = preload("res://assets/generated/actors_master.webp")
const DIRECTIONS: Array[String] = ["down", "left", "right", "up"]
const HERO_REGIONS: Array = [
	[Rect2(38,20,239,290), Rect2(341,24,261,287), Rect2(662,22,273,290), Rect2(968,27,258,283)],
	[Rect2(30,316,261,292), Rect2(348,325,261,284), Rect2(650,325,260,283), Rect2(979,323,244,281)],
	[Rect2(28,615,264,251), Rect2(346,618,267,250), Rect2(641,620,274,248), Rect2(967,617,260,256)]
]
const PORTRAIT_REGIONS: Array[Rect2] = [Rect2(105,28,119,148),Rect2(98,336,143,145),Rect2(93,624,152,147)]
const MONSTER_REGIONS: Array[Rect2] = [Rect2(9,870,341,365),Rect2(350,862,282,374),Rect2(637,862,316,373)]

static func hero_region(index: int, facing: String) -> Rect2:
	return HERO_REGIONS[clampi(index,0,2)][maxi(0,DIRECTIONS.find(facing))]

static func hero_size(index: int, facing: String) -> Vector2:
	var region: Rect2 = hero_region(index,facing)
	var factor: float = minf(94.0/region.size.y,86.0/region.size.x)
	return region.size*factor

static func rig_offset(uv: Vector2, animation: String, frame_index: int, count: int, facing: String) -> Vector2:
	var phase: float=float(frame_index)/maxf(1.0,float(count))
	var wave: float=sin(phase*TAU)
	var upper: float=1.0-uv.y
	var side: float=(uv.x-0.5)*2.0
	var facing_sign: float=-1.0 if facing=="left" else 1.0
	var offset: Vector2=Vector2.ZERO
	match animation:
		"idle":
			offset.y=-wave*0.8*upper
			offset.x=side*wave*0.32*sin(uv.y*PI)
		"walk":
			var leg: float=smoothstep(0.62,1.0,uv.y)
			offset.x=wave*upper*1.4+wave*side*leg*2.8
			offset.y=-absf(wave)*1.8*upper-maxf(0.0,wave*side)*leg*3.1
		"attack":
			var poses: Array[float]=[-0.20,-0.48,-0.70,0.15,1.0,0.82,0.30,0.04]
			var thrust: float=poses[clampi(frame_index,0,7)]
			offset.x=facing_sign*thrust*(10.0*upper+5.0*sin(uv.y*PI))
			offset.y=-thrust*2.5*upper
		"hurt":
			var recoil: Array[float]=[-5.0,2.5,0.5]
			offset.x=facing_sign*recoil[clampi(frame_index,0,2)]*upper
			offset.y=absf(recoil[clampi(frame_index,0,2)])*0.25*upper
		"death":
			var fall: float=float(frame_index)/maxf(1.0,float(count-1))
			offset.y=-fall*upper
	return offset

static func draw_hero(canvas: CanvasItem, index: int, facing: String, animation: String, frame_index: int, count: int) -> void:
	var source: Rect2=hero_region(index,facing)
	var size_pixels: Vector2=hero_size(index,facing)
	var origin: Vector2=Vector2(-size_pixels.x*0.5,-size_pixels.y)
	var texture_size: Vector2=TEXTURE.get_size()
	var tint: Color=Color.WHITE
	if animation=="hurt" and frame_index==0: tint=Color(1.35,0.77,0.72)
	if animation=="death": tint=Color(0.7,0.73,0.78,1.0-0.18*float(frame_index)/maxf(1.0,count-1))
	# Shared vertices keep the skin continuous while feet, cloth and torso move.
	for row in range(12):
		for column in range(8):
			var points: PackedVector2Array=[]
			var uvs: PackedVector2Array=[]
			for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var uv: Vector2=Vector2((column+corner.x)/8.0,(row+corner.y)/12.0)
				var point: Vector2=origin+uv*size_pixels+rig_offset(uv,animation,frame_index,count,facing)
				if animation=="death":
					var fall: float=float(frame_index)/maxf(1.0,float(count-1))
					var angle: float=fall*PI*0.45*(-1.0 if facing=="left" else 1.0)
					point=point.rotated(angle)*(1.0-fall*0.15)
					point.y-=absf(sin(angle))*size_pixels.x*0.5*(1.0-fall*0.15)
				points.append(point)
				uvs.append((source.position+uv*source.size)/texture_size)
			canvas.draw_polygon(points,PackedColorArray([tint]),uvs,TEXTURE)
