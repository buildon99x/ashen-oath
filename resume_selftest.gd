extends SceneTree
const Model=preload("res://model.gd")
func _initialize() -> void:
	var m=Model.new()
	m.persist_meta=false
	m.new_run(7821)
	m.start_battle(2)
	assert(m.act(0,1,0))
	assert(m.save_resume("user://resume_test.save"))
	var n=Model.new()
	n.persist_meta=false
	assert(n.load_resume("user://resume_test.save"))
	assert(n.describe()==m.describe())
	assert(n.rng.state==m.rng.state)
	m.act(1,2,0)
	n.act(1,2,0)
	m.end_round()
	n.end_round()
	assert(n.describe()==m.describe())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://resume_test.save"))
	assert(not n.load_resume("user://resume_test_missing.save"))
	print("RESUME TEST PASSED: 7 assertions, including exact next-round continuity")
	quit(0)
