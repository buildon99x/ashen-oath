extends SceneTree
## Run as an absolute external script against the exported PCK.
## This script is excluded from the playable package.
func _initialize() -> void:
	var failed:=false
	for path in ["res://rulesets/ashen_provisional_v1/profile.json","res://rulesets/severed_historical_effects_v1/manifest.json","res://rulesets/severed_v0_2_102/evidence.json"]:
		if not FileAccess.file_exists(path):
			push_error("PACKAGE FAIL: missing "+path)
			failed=true
	var model_script=load("res://model.gd")
	if model_script==null:
		push_error("PACKAGE FAIL: model cannot load")
		quit(1)
		return
	var m=model_script.new()
	m.persist_meta=false
	if not m.new_run(410,"ashen_provisional_v1") or not m.start_battle(1): failed=true
	m.heroes[0].mp=0
	if not m.act(0,3,0) or m.heroes[0].mp!=15 or not m.heroes[0].guard:
		push_error("PACKAGE FAIL: shipped historical Defend rule did not resolve")
		failed=true
	if not m.save_resume("user://package-smoke.save"):
		push_error("PACKAGE FAIL: shipped model could not persist a valid checkpoint")
		failed=true
	print("PACKAGED COMBAT: JSON manifests, model load, actual Defend +15 and checkpoint %s." % ("FAILED" if failed else "PASSED"))
	quit(1 if failed else 0)
