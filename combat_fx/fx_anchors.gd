extends RefCounted
const FEET: Array[Vector2] = [Vector2(420,480),Vector2(520,510),Vector2(620,540)]
const PARTS: Array[Vector2] = [Vector2(0,-52),Vector2(0,-190),Vector2(0,-309)]
static func hero(index: int) -> Vector2:
	return FEET[clampi(index,0,2)] + Vector2(18,-54)
static func monster(part: int, cuts: Array, scale_factor: float = 0.9) -> Vector2:
	return Vector2(865,525) + PARTS[clampi(part,0,2)]*scale_factor + Vector2(0,64*scale_factor if not cuts.is_empty() and cuts[0] else 0)
static func cuts(parts: Array) -> Array:
	var result: Array = []
	for part in parts: result.append(bool(part.severed))
	return result
