extends SceneTree
const Model = preload("res://model.gd")

func _initialize() -> void:
	if OS.get_cmdline_user_args().size() != 1:
		push_error("Pass one output trace path after --; use an empty isolated XDG profile.")
		quit(2)
		return
	var output_path: String = OS.get_cmdline_user_args()[0]
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	var actions: int = 0
	var reloads: int = 0
	var outcomes: Dictionary = {}
	for rank: int in range(6):
		for seed_number: int in range(1, 11):
			var m = Model.new()
			m.persist_meta = false
			m.meta = {"essence": 0, "upgrades": {"vitality": rank, "force": rank, "focus": rank}, "runs": 0, "wins": 0}
			var key: String = "%s-%s" % [rank, seed_number]
			m.meta_path = "user://parity-%s-meta.json" % key
			m._resume_path = "user://parity-%s-journey.save" % key
			m.new_run(seed_number * 977)
			var inputs: RandomNumberGenerator = RandomNumberGenerator.new()
			inputs.seed = seed_number * 131 + rank
			for step: int in range(500):
				output.store_line(JSON.stringify({"case": key, "step": step, "state": m._journey_snapshot(), "error": m.last_error}))
				if step % 17 == 7 or m.phase in ["victory", "defeat"]:
					var before: Dictionary = m._journey_snapshot()
					assert(m.save_resume(m._resume_path))
					var restored = Model.new()
					restored.persist_meta = false
					restored.meta_path = m.meta_path
					assert(restored.load_resume(m._resume_path))
					# Resume intentionally clears the transient rejected-command message.
					before.erase("last_error")
					var after: Dictionary = restored._journey_snapshot()
					after.erase("last_error")
					assert(after == before)
					m = restored
					reloads += 1
				if m.phase in ["victory", "defeat"]:
					break
				var accepted: bool = false
				match m.phase:
					"map": accepted = m.travel(inputs.randi_range(0, m.choices.size() - 1))
					"battle":
						var available: Array[int] = []
						for index: int in range(m.heroes.size()):
							if m.heroes[index].hp > 0 and not m.heroes[index].acted:
								available.append(index)
						if available.is_empty() or inputs.randi_range(0, 9) == 0:
							accepted = m.end_round()
						else:
							accepted = m.act(available[inputs.randi_range(0, available.size() - 1)], inputs.randi_range(0, 3), inputs.randi_range(0, m.parts.size() - 1))
					"reward": accepted = m.choose_reward(inputs.randi_range(0, m.rewards.size() - 1))
					"event", "camp", "relic": accepted = m.choose_event(inputs.randi_range(0, m.event.options.size() - 1))
				output.store_line(JSON.stringify({"accepted": accepted, "input_rng": str(inputs.state)}))
				actions += 1
			outcomes[m.phase] = int(outcomes.get(m.phase, 0)) + 1
	output.close()
	print("LEGACY PARITY: ", JSON.stringify({"cases": 60, "commands": actions, "reloads": reloads, "outcomes": outcomes}))
	quit()
