extends RefCounted
## Deterministically advance real animation markers for pre-existing scene tests.
## New timeline-specific tests inspect both sides of impact without this helper.
static func settle(scene) -> void:
	for iteration in range(8):
		if not scene.fx_busy(): return
		var event: Dictionary = scene.fx_director.current
		if event.kind == "hero" and scene.fx_director.impact_age < 0:
			scene.actors[int(event.hero_index)].advance(4.0/12.0)
		scene.fx_director.advance(1.0)
