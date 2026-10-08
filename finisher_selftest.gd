extends SceneTree
const Localization = preload("res://localization.gd")
## CP10 deterministic scene/model checks. This is headless evidence, not visual QA.
## Run with a fresh writable XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME:
## runtime=$(mktemp -d /tmp/ashen-oath-finisher-selftest.XXXXXX)
## mkdir -p "$runtime"/{data,config,cache}
## XDG_DATA_HOME="$runtime/data" XDG_CONFIG_HOME="$runtime/config" XDG_CACHE_HOME="$runtime/cache" godot --headless --path . --script res://finisher_selftest.gd

const MAIN: PackedScene = preload("res://main.tscn")
const Model = preload("res://model.gd")
const MODEL_FIELDS: Array[String] = ["phase", "title", "heroes", "parts", "boss", "intent", "campaign", "choices", "rewards", "event", "run", "meta", "log", "round_number", "last_error", "_milestone", "_settled"]
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error("FINISHER FAIL: " + description)

func _initialize() -> void:
	Localization.set_language("en")
	Localization.save_preferences()
	call_deferred("run_tests")

func run_tests() -> void:
	var data_root: String = OS.get_environment("XDG_DATA_HOME").simplify_path()
	var save_root: String = ProjectSettings.globalize_path("user://").simplify_path()
	# Refuse accidental runs against the player's native journey.
	if data_root.is_empty() or data_root == "." or not save_root.begins_with(data_root + "/") or "cp8-native" in save_root:
		push_error("Use a fresh isolated XDG_DATA_HOME; refusing to touch the native journey.")
		quit(2)
		return
	root.size = Vector2i(1440, 900)
	var scene = make_scene()
	await process_frame
	test_no_false_finishers(scene)
	await test_kill_paths(scene)
	await test_guards_and_stale_buttons(scene)
	await test_input_routes(scene)
	await test_focused_action_space(scene)
	await test_battle_focus_regression(scene)
	await test_timeout_and_reward(scene)
	await test_save_and_reload(scene)
	await test_final_settlement(scene)
	await test_defeat_and_shader_reset(scene)
	scene.queue_free()
	await process_frame
	print("FINISHER TESTS: %d checks; %d failures (headless scene/model/input/save coverage, not visual QA)" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func make_scene():
	var scene = MAIN.instantiate()
	scene.muted = true
	root.add_child(scene)
	# Godot enables overridden _process on tree entry; freeze it after _ready.
	scene.set_process(false)
	for actor in scene.actors:
		actor.set_process(false)
	return scene

func start_fixture(scene, tier: int = 1, final_boss: bool = false) -> void:
	Localization.set_language("en")
	Localization.save_preferences()
	scene.apply_language_theme()
	scene.model = Model.new()
	scene.model._clear_journey()
	scene.model.persist_meta = false
	scene.model.meta = {"essence": 7, "upgrades": {"vitality": 0, "force": 0, "focus": 0}, "runs": 4, "wins": 2}
	scene.model.new_run(10429)
	if final_boss:
		scene.model.run.node = 8
		scene.model.run.stage = 8
		scene.model.run.battles_won = 2
		scene.model.run.bosses_defeated = 2
		scene.model.run.essence = 26
		scene.model.run.gold = 80
		scene.model._milestone = true
	check(scene.model.start_battle(tier), "fixture starts a battle")
	scene.menu = false
	scene.help_open = false
	scene.build_open = false
	scene.confirmation = ""
	scene.message = ""
	scene.muted = true
	scene.selected_hero = 0
	scene.selected_part = 0
	scene.finisher_remaining = 0.0
	scene.finisher_cuts = [false, false, false]
	scene.finisher_action = ""
	scene.finisher_awards = ""
	scene.refresh()

func reference_model(source):
	var result = Model.new()
	result.persist_meta = false
	for field in MODEL_FIELDS:
		var value: Variant = source.get(field)
		result.set(field, value.duplicate(true) if value is Array or value is Dictionary else value)
	result.rng.seed = source.rng.seed
	result.rng.state = source.rng.state
	return result

func model_snapshot(model) -> PackedByteArray:
	return var_to_bytes({"model": model.describe(), "rng_seed": str(model.rng.seed), "rng_state": str(model.rng.state), "milestone": model._milestone, "settled": model._settled})

func outcome_snapshot(model) -> PackedByteArray:
	# A rejected post-completion action may set last_error; it must not settle again.
	return var_to_bytes({"phase": model.phase, "run": model.run, "meta": model.meta, "log": model.log, "rewards": model.rewards, "rng": str(model.rng.state), "settled": model._settled})

func presentation_snapshot(scene) -> PackedByteArray:
	return var_to_bytes([scene.menu, scene.help_open, scene.build_open, scene.confirmation, scene.message, scene.muted, scene.selected_hero, scene.selected_part, scene.finisher_remaining, scene.finisher_cuts, scene.finisher_action, scene.finisher_awards, scene.fx_time, scene.fx_actor, scene.fx_part, scene.fx_kind, scene.fx_damage])

func check_award_label(scene, before_gold: int, before_ash: int, expected_text: String) -> void:
	var actual_delta: String = "+%d GOLD / +%d UNBANKED ASH" % [int(scene.model.run.gold) - before_gold, int(scene.model.run.essence) - before_ash]
	check(scene.finisher_awards == actual_delta, "award caption matches actual resolved gold and ash deltas")
	check(scene.finisher_awards == expected_text, "award caption has exact expected text: " + expected_text)
	var found: bool = false
	for child in scene.ui.get_children():
		if child is Label and not child.is_queued_for_deletion() and child.text == expected_text:
			found = true
	check(found, "actual reward delta label is present in finisher UI")

func live_buttons(scene) -> Array[Button]:
	var result: Array[Button] = []
	for child in scene.ui.get_children():
		if child is Button and not child.is_queued_for_deletion():
			result.append(child)
	return result

func reward_buttons(scene) -> Array[Button]:
	var result: Array[Button] = []
	for child in live_buttons(scene):
		if child.position.y == 520:
			result.append(child)
	return result

func hp_kill(scene) -> void:
	scene.model.boss.hp = 1
	scene.perform(0)
	check(scene.finisher_active() and scene.model.phase == "reward", "HP kill starts a presentation over an already-resolved reward")

func test_no_false_finishers(scene) -> void:
	start_fixture(scene)
	scene.perform(0)
	check(not scene.finisher_active() and scene.model.phase == "battle", "nonlethal hit does not start a finisher")
	start_fixture(scene)
	scene.model.boss.hp = 1
	scene.perform(3)
	check(not scene.finisher_active() and scene.model.phase == "battle", "Defend at 1 boss HP does not start a finisher")
	check(scene.model.heroes[0].guard, "Defend was accepted")
	for reason in ["acted", "dead", "focus", "severed", "skill", "hero", "phase"]:
		start_fixture(scene)
		scene.model.boss.hp = 1
		var skill: int = 0
		match reason:
			"acted": scene.model.heroes[0].acted = true
			"dead": scene.model.heroes[0].hp = 0
			"focus":
				scene.model.heroes[0].mp = 0
				skill = 2
			"severed": scene.model.parts[0].severed = true
			"skill": skill = -1
			"hero": scene.selected_hero = -1
			"phase": scene.model.phase = "map"
		var before: PackedByteArray = outcome_snapshot(scene.model)
		scene.perform(skill)
		check(not scene.finisher_active() and not scene.model.last_error.is_empty(), "rejected %s action never starts a finisher" % reason)
		check(outcome_snapshot(scene.model) == before, "rejected %s action leaves rewards and economy unchanged" % reason)
	print("FINISHER: nonlethal, guard and rejected-action checks finished")

func test_kill_paths(scene) -> void:
	for target in range(3):
		start_fixture(scene)
		for i in range(3):
			scene.model.parts[i].severed = i != target
		scene.model.parts[target].broken = true
		scene.model.parts[target].shield = 0
		scene.model.parts[target].hp = 1
		scene.selected_part = target
		var cuts: Array = []
		for part in scene.model.parts: cuts.append(part.severed)
		var expected = reference_model(scene.model)
		check(expected.act(0, 2, target), "reference killing sever is accepted")
		var rng_before: int = scene.model.rng.state
		var before_gold: int = scene.model.run.gold
		var before_ash: int = scene.model.run.essence
		scene.perform(2)
		check_award_label(scene, before_gold, before_ash, "+24 GOLD / +5 UNBANKED ASH")
		check(scene.model.boss.hp > 0 and scene.model._intact_parts().is_empty(), "last-part sever wins with positive boss HP: part %d" % target)
		check(scene.finisher_active() and scene.model.phase == "reward", "last-part sever starts the finisher: part %d" % target)
		check(scene.finisher_cuts == cuts and not scene.finisher_cuts[target], "snapshot preserves pre-hit cuts including the killing limb: part %d" % target)
		check(model_snapshot(scene.model) == model_snapshot(expected), "scene resolves the killing sever exactly like one model action")
		check(scene.model.rng.state == rng_before, "sever presentation does not consume RNG")
		check(scene.model.run.gold == 54 and scene.model.run.essence == 5, "gold and unbanked ash awarded exactly once before presentation")
		check(scene.model.run.battles_won == 1 and scene.model.run.bosses_defeated == 0, "fragment counters awarded once")
		check(scene.model.meta.essence == 7 and not scene.model._settled, "normal battle does not bank legacy ash")
		check(scene.fx_part == target and scene.fx_actor == 0 and scene.fx_kind == "slash", "final attack retains its original actor, target and type")
		check(scene.finisher_action == "MARA / SUNDERING ARC", "final action caption names the killing action")
		scene._process(0.0)
		check(scene.generated_monster.visible, "monster remains visible during presentation")
		for actor in scene.actors:
			check(actor.visible, "party remains visible during presentation")
		check(live_buttons(scene).size() == 2 and reward_buttons(scene).is_empty(), "only skip and language controls exist during presentation")
		var snapshot: PackedByteArray = model_snapshot(scene.model)
		await process_frame
		await process_frame
		check(scene.generated_monster.severed == cuts, "renderer receives the pre-hit silhouette, including killing legs")
		check(scene.generated_monster.selected_part == -1 and scene.generated_monster.dissolve == 0.0, "initial finisher holds the intact final-hit silhouette without a target ring")
		scene.advance_finisher(0.5)
		scene._process(0.0)
		await process_frame
		await process_frame
		check(scene.generated_monster.dissolve > 0.0 and scene.generated_monster.dissolve < 1.0, "finisher timer drives partial ash dissolve")
		check(scene.generated_monster.severed == cuts and model_snapshot(scene.model) == snapshot, "dissolve never regrows prior cuts or mutates the resolved reward")
		scene.finish_presentation()
		scene.finish_presentation()
		scene.advance_finisher(100.0)
		check(model_snapshot(scene.model) == snapshot, "skip and repeated completion never duplicate the sever reward")
		await process_frame
	start_fixture(scene)
	scene.model.parts[0].severed = true
	scene.selected_part = 1
	scene.model.boss.hp = 1
	var expected = reference_model(scene.model)
	check(expected.act(0, 0, 1), "reference HP kill is accepted")
	scene.perform(0)
	check(scene.model.boss.hp == 0 and not scene.model.parts[1].severed, "HP victory does not require severing the attacked part")
	check(scene.finisher_cuts == [true, false, false], "HP finisher retains previously severed legs")
	check(model_snapshot(scene.model) == model_snapshot(expected), "HP kill resolves exactly once before its finisher")
	start_fixture(scene)
	scene.model.run.relics.append(Model.RELICS[3].duplicate(true))
	var before_gold: int = scene.model.run.gold
	var before_ash: int = scene.model.run.essence
	hp_kill(scene)
	check_award_label(scene, before_gold, before_ash, "+32 GOLD / +5 UNBANKED ASH")
	print("FINISHER: HP kill and all three last-part sever paths finished")

func test_guards_and_stale_buttons(scene) -> void:
	start_fixture(scene)
	var language_before: String = Localization.get_language()
	var stale: Array[Button] = live_buttons(scene)
	var callback_hits: Array[int] = [0]
	stale.append(scene.button("stale reward", Rect2(65, 520, 410, 176), scene.choose_reward.bind(1)))
	stale.append(scene.button("stale closure", Rect2(5, 5, 10, 10), func(): callback_hits[0] += 1))
	scene.help_open = true
	scene.build_open = true
	scene.confirmation = "new_cycle"
	hp_kill(scene)
	check(not scene.help_open and not scene.build_open and scene.confirmation.is_empty(), "finisher closes help, build and confirmation overlays")
	var before: PackedByteArray = model_snapshot(scene.model)
	var ui_before: PackedByteArray = presentation_snapshot(scene)
	var actions: Array[Callable] = [scene.begin_run, scene.request_new_cycle, scene.request_end_round, scene.confirm_action, scene.upgrade.bind("force"), scene.select_hero.bind(2), scene.select_part.bind(2), scene.cycle_part.bind(1), scene.cycle_part.bind(-1), scene.perform.bind(0), scene.perform.bind(1), scene.perform.bind(2), scene.perform.bind(3), scene.finish_round, scene.travel.bind(0), scene.choose_reward.bind(0), scene.choose_reward.bind(1), scene.choose_reward.bind(2), scene.choose_event.bind(0)]
	for action in actions:
		action.call()
		check(model_snapshot(scene.model) == before, "active finisher guards model action " + str(action))
		check(presentation_snapshot(scene) == ui_before, "active finisher guards presentation action " + str(action))
	for old_button in stale:
		old_button.pressed.emit()
	check(Localization.get_language() == language_before, "queued stale language button is also swallowed")
	check(callback_hits[0] == 0, "generic stale button closure is gated")
	check(model_snapshot(scene.model) == before and presentation_snapshot(scene) == ui_before, "all queued stale battle and reward button emissions are swallowed")
	scene.refresh()
	check(model_snapshot(scene.model) == before, "repeated refresh is presentation-only")
	await process_frame
	print("FINISHER: public action guards and stale button emissions finished")

func key_event(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func mouse_event(point: Vector2, pressed: bool, button_index: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button_index
	event.pressed = pressed
	return event

func test_input_routes(scene) -> void:
	for skip_code in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		start_fixture(scene)
		hp_kill(scene)
		await process_frame
		var before: PackedByteArray = model_snapshot(scene.model)
		var ui_before: PackedByteArray = presentation_snapshot(scene)
		for code in [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_1, KEY_2, KEY_3, KEY_UP, KEY_DOWN, KEY_H, KEY_M, KEY_B, KEY_V]:
			root.push_input(key_event(code), true)
			check(root.is_input_handled(), "finisher consumes blocked key " + str(code))
			root.push_input(key_event(code, false), true)
		root.push_input(key_event(skip_code, true, true), true)
		root.push_input(key_event(skip_code, false), true)
		check(presentation_snapshot(scene) == ui_before, "held or released skip key cannot dismiss or open an overlay")
		for point in [Vector2(270, 608), Vector2(710, 608), Vector2(1150, 608)]:
			root.push_input(mouse_event(point, true), true)
			root.push_input(mouse_event(point, false), true)
		check(scene.finisher_active() and model_snapshot(scene.model) == before, "clicks in every future reward area cannot choose a reward")
		root.push_input(mouse_event(scene.FINISHER_SKIP_RECT.get_center(), true, MOUSE_BUTTON_RIGHT), true)
		root.push_input(mouse_event(scene.FINISHER_SKIP_RECT.get_center(), false, MOUSE_BUTTON_RIGHT), true)
		check(scene.finisher_active(), "right-click on skip does not dismiss")
		root.push_input(key_event(skip_code), true)
		check(not scene.finisher_active() and root.is_input_handled(), "fresh skip key is consumed before reward UI appears: " + str(skip_code))
		root.push_input(key_event(skip_code, true, true), true)
		root.push_input(key_event(skip_code, false), true)
		await process_frame
		check(model_snapshot(scene.model) == before and not scene.menu, "skip press, hold and release never choose a reward or toggle menu")
		check(reward_buttons(scene).size() == 3, "three rewards appear after key skip")
	start_fixture(scene)
	hp_kill(scene)
	await process_frame
	var before: PackedByteArray = model_snapshot(scene.model)
	root.push_input(mouse_event(scene.FINISHER_SKIP_RECT.get_center(), false), true)
	check(scene.finisher_active(), "orphan mouse release does not skip")
	root.push_input(mouse_event(scene.FINISHER_SKIP_RECT.get_center(), true), true)
	check(not scene.finisher_active() and root.is_input_handled(), "dedicated left-click skips and is consumed")
	root.push_input(mouse_event(scene.FINISHER_SKIP_RECT.get_center(), false), true)
	await process_frame
	check(model_snapshot(scene.model) == before, "skip click release never leaks into a reward")
	for point in [Vector2(270, 608), Vector2(710, 608), Vector2(1150, 608)]:
		start_fixture(scene)
		hp_kill(scene)
		await process_frame
		before = model_snapshot(scene.model)
		root.push_input(mouse_event(point, true), true)
		root.push_input(key_event(KEY_SPACE, true, true), true)
		scene._process(scene.FINISHER_DURATION)
		await process_frame
		root.push_input(mouse_event(point, false), true)
		root.push_input(key_event(KEY_SPACE, false), true)
		check(not scene.finisher_active() and model_snapshot(scene.model) == before, "held mouse/key release across natural timeout cannot select a newly created reward")
	start_fixture(scene)
	hp_kill(scene)
	scene._unhandled_key_input(key_event(KEY_Q))
	check(scene.finisher_active(), "fallback unhandled-key path also gates ordinary actions")
	scene._unhandled_key_input(key_event(KEY_SPACE))
	check(not scene.finisher_active() and scene.model.phase == "reward", "fallback unhandled-key path can skip without resolving a round")
	start_fixture(scene)
	hp_kill(scene)
	before = model_snapshot(scene.model)
	var skip: Button = null
	for candidate in live_buttons(scene):
		if "SKIP" in candidate.text: skip = candidate
	check(skip != null, "finisher exposes the explicit skip control")
	skip.pressed.emit()
	skip.pressed.emit()
	check(not scene.finisher_active() and model_snapshot(scene.model) == before, "skip button signal and repeated stale skip signal finish presentation only")
	print("FINISHER: viewport input, held/released keys and click isolation finished")

func test_focused_action_space(scene) -> void:
	for release_timing in ["before_deletion", "after_deletion", "after_timeout", "release_kills"]:
		start_fixture(scene)
		scene.model.boss.hp = 1
		await process_frame
		var action_button: Button = null
		for candidate in live_buttons(scene):
			if candidate.position == Vector2(40, 689):
				action_button = candidate
		check(action_button != null, "focused Space test finds actual Oathblade action button")
		if action_button == null: continue
		# Deliberately simulate a legacy/stale focused control even after normal
		# combat controls become non-focusable. The post-kill gate must still hold.
		action_button.focus_mode = Control.FOCUS_ALL
		action_button.grab_focus()
		check(root.gui_get_focus_owner() == action_button, "old action control owns actual GUI focus")
		root.push_input(key_event(KEY_SPACE), true)
		check(action_button.is_pressed() and scene.model.phase == "battle", "holding Space depresses focused action without prematurely executing it")
		var expected = reference_model(scene.model)
		check(expected.act(0, 0, 0), "focused-button reference kill is accepted")
		if release_timing == "release_kills":
			root.push_input(key_event(KEY_SPACE, false), true)
		else:
			# Trigger the action while the old control retains its held Space press.
			# This isolates post-kill input even if global Space opened a confirmation.
			scene.perform(0)
		check(scene.finisher_active() and model_snapshot(scene.model) == model_snapshot(expected), "focused-button kill starts exactly one full finisher: " + release_timing)
		var before: PackedByteArray = model_snapshot(scene.model)
		var remaining: float = scene.finisher_remaining
		if release_timing in ["after_deletion", "after_timeout"]:
			await process_frame
			check(not is_instance_valid(action_button), "old focused action is freed after refresh")
		if release_timing == "after_timeout":
			scene._process(scene.FINISHER_DURATION)
			await process_frame
			check(reward_buttons(scene).size() == 3, "timeout creates reward controls while old Space remains held")
		if release_timing != "release_kills":
			root.push_input(key_event(KEY_SPACE, true, true), true)
			root.push_input(key_event(KEY_SPACE, false), true)
		check(model_snapshot(scene.model) == before and not scene.menu, "held focused-action Space never leaks into a reward or menu: " + release_timing)
		if release_timing != "after_timeout":
			check(scene.finisher_active() and scene.finisher_remaining == remaining, "focused-action Space release never immediately skips the finisher: " + release_timing)
		scene.finish_presentation()
		await process_frame
		check(model_snapshot(scene.model) == before and reward_buttons(scene).size() == 3, "focused-action sequence leaves exactly one pending reward")
	print("FINISHER: focused old action button and Space-through-kill isolation finished")

func check_focusable_control(scene, title: String) -> void:
	var target: Button = null
	for candidate in live_buttons(scene):
		if candidate.text.begins_with(title):
			target = candidate
	check(target != null, "accessible dialog/menu control exists: " + title)
	if target == null: return
	check(target.focus_mode == Control.FOCUS_ALL, "dialog/menu preserves keyboard focus: " + title)
	if target.focus_mode == Control.FOCUS_ALL:
		target.grab_focus()
		check(root.gui_get_focus_owner() == target, "dialog/menu can actually receive keyboard focus: " + title)
		target.release_focus()

func test_battle_focus_regression(scene) -> void:
	start_fixture(scene)
	scene.model.boss.hp = 1
	await process_frame
	var old_action: Button = null
	for candidate in live_buttons(scene):
		check(candidate.focus_mode == Control.FOCUS_NONE, "normal battle control leaves Space to battle hotkeys: " + candidate.text.split("\n")[0])
		if candidate.position == Vector2(40, 689): old_action = candidate
	check(old_action != null, "Space/confirmation regression finds the old action control")
	if old_action != null:
		# Reproduce the original overlap when it is possible, without overriding
		# production focus policy. Press and release happen before queued deletion.
		if old_action.focus_mode != Control.FOCUS_NONE: old_action.grab_focus()
		var before: PackedByteArray = model_snapshot(scene.model)
		root.push_input(key_event(KEY_SPACE), true)
		check(scene.confirmation == "end_round", "battle Space opens the intended end-round confirmation")
		root.push_input(key_event(KEY_SPACE, false), true)
		check(model_snapshot(scene.model) == before and not scene.finisher_active(), "Space release cannot execute a stale focused attack through end-round confirmation")
		check(scene.confirmation == "end_round", "Space release preserves the pending end-round decision")
	start_fixture(scene)
	scene.menu = true
	scene.refresh()
	await process_frame
	check_focusable_control(scene, "BEGIN A NEW CYCLE")
	scene.menu = false
	scene.help_open = true
	scene.refresh()
	await process_frame
	check_focusable_control(scene, "CLOSE GUIDE")
	scene.help_open = false
	scene.build_open = true
	scene.refresh()
	await process_frame
	check_focusable_control(scene, "B / ESC / RETURN")
	scene.build_open = false
	scene.confirmation = "end_round"
	scene.refresh()
	await process_frame
	check_focusable_control(scene, "ENTER / END ROUND")
	check_focusable_control(scene, "ESC / KEEP PLAYING")
	print("FINISHER: battle Space/confirmation overlap and preserved menu/dialog accessibility finished")

func test_timeout_and_reward(scene) -> void:
	start_fixture(scene)
	hp_kill(scene)
	var before: PackedByteArray = model_snapshot(scene.model)
	var duration: float = scene.finisher_remaining
	scene.advance_finisher(-50.0)
	check(scene.finisher_remaining == duration, "negative delta cannot lengthen or finish presentation")
	scene.advance_finisher(0.0)
	scene.advance_finisher(duration - 0.01)
	check(scene.finisher_active() and reward_buttons(scene).is_empty(), "rewards stay hidden until the full duration elapses")
	scene._process(0.02)
	check(not scene.finisher_active() and scene.finisher_remaining == 0.0, "timeout clamps remaining time to zero")
	scene.advance_finisher(50.0)
	scene.finish_presentation()
	scene.finish_presentation()
	check(model_snapshot(scene.model) == before, "timeout and repeated completion preserve RNG, economy, log and reward options exactly")
	scene._process(0.0)
	check(not scene.generated_monster.visible, "monster is hidden after reward UI appears")
	for actor in scene.actors: check(not actor.visible, "battle actors hide on reward screen")
	await process_frame
	var buttons: Array[Button] = reward_buttons(scene)
	check(buttons.size() == 3, "timeout presents all three rewards")
	var expected = reference_model(scene.model)
	check(expected.choose_reward(2), "reference relic reward is accepted")
	if buttons.size() == 3:
		buttons[2].pressed.emit()
		check(model_snapshot(scene.model) == model_snapshot(expected), "first deliberate reward choice consumes RNG exactly once")
		var outcome: PackedByteArray = outcome_snapshot(scene.model)
		buttons[2].pressed.emit()
		check(outcome_snapshot(scene.model) == outcome, "repeated stale reward click cannot grant another relic")
	print("FINISHER: natural timeout, idempotent completion and one reward choice finished")

func test_save_and_reload(scene) -> void:
	start_fixture(scene)
	scene.model.persist_meta = true
	hp_kill(scene)
	var before: PackedByteArray = model_snapshot(scene.model)
	var save_path: String = "user://ashen_oath_journey.save"
	check(FileAccess.file_exists(save_path), "refresh saves the resolved reward while finisher is active")
	var record: Dictionary = scene.model._read_record(save_path)
	if not record.is_empty():
		var saved: Dictionary = record.journey
		check(saved.phase == "reward" and saved.run.battles_won == 1, "on-disk journey contains reward phase and one awarded battle")
		check(not saved.has("finisher_remaining") and not saved.has("finisher_cuts"), "presentation state is never serialized into the journey")
	else:
		check(false, "saved journey can be read")
	var resumed = make_scene()
	check(not resumed.finisher_active() and resumed.menu, "new scene loads into normal resume menu without replaying finisher")
	check(model_snapshot(resumed.model) == before, "new scene reloads exact reward, RNG, counters, gold, ash and log")
	resumed.menu = false
	resumed.refresh()
	resumed._process(5.0)
	await process_frame
	check(reward_buttons(resumed).size() == 3 and not resumed.finisher_active(), "resuming saved finisher goes straight to reward options")
	check(model_snapshot(resumed.model) == before, "time after reload cannot award the victory again")
	var expected = reference_model(resumed.model)
	check(expected.choose_reward(2), "reference reloaded relic reward is accepted")
	resumed.choose_reward(2)
	check(model_snapshot(resumed.model) == model_snapshot(expected), "reloaded reward uses the same RNG result exactly once")
	resumed.model.persist_meta = false
	resumed.queue_free()
	scene.model.persist_meta = false
	await process_frame
	print("FINISHER: autosave during presentation and fresh-scene resume finished")

func test_final_settlement(scene) -> void:
	start_fixture(scene, 3, true)
	scene.model.boss.hp = 1
	var expected = reference_model(scene.model)
	check(expected.act(0, 0, 0), "reference final boss kill is accepted")
	var before_gold: int = scene.model.run.gold
	var before_ash: int = scene.model.run.essence
	scene.perform(0)
	check_award_label(scene, before_gold, before_ash, "+36 GOLD / +12 UNBANKED ASH")
	check(scene.finisher_active() and scene.model.phase == "reward" and not scene.model._settled, "final boss still offers one reward before victory settlement")
	check(scene.model.run.bosses_defeated == 3 and scene.model.run.battles_won == 3, "final boss kill increments both counters once")
	check(scene.model.meta.runs == 4 and scene.model.meta.essence == 7, "finisher does not prematurely settle final run")
	scene.finish_presentation()
	check(model_snapshot(scene.model) == model_snapshot(expected), "final boss skip preserves exact resolved reward")
	check(expected.choose_reward(1), "reference final tribute choice is accepted")
	scene.choose_reward(1)
	check(scene.model.phase == "victory" and scene.model._settled, "final reward advances to settled victory")
	check(model_snapshot(scene.model) == model_snapshot(expected), "final reward and settlement match one model transition exactly")
	check(scene.model.meta.runs == 5 and scene.model.meta.wins == 3 and scene.model.meta.essence == 57, "final run banks battle ash, tribute and victory bonus exactly once")
	var outcome: PackedByteArray = outcome_snapshot(scene.model)
	scene.finish_presentation()
	scene.advance_finisher(100.0)
	scene.choose_reward(1)
	scene.model._settle_run(true)
	scene.model._settle_run(false)
	check(outcome_snapshot(scene.model) == outcome, "repeated completion, reward calls and settlement cannot duplicate final winnings")
	scene._process(0.0)
	for actor in scene.actors: check(actor.visible, "victory party remains visible after final reward")
	await process_frame
	print("FINISHER: final-boss reward and one-time legacy settlement finished")

func test_defeat_and_shader_reset(scene) -> void:
	start_fixture(scene)
	var monster = scene.generated_monster
	monster.configure(0, Vector2(865, 525), 0.9, [false, true, false], 0.0, 0.0, -1, 0.8)
	check(is_equal_approx(monster.dissolve, 0.8), "monster accepts explicit finisher dissolve")
	check(is_equal_approx(float(monster.material.get_shader_parameter("dissolve")), 0.8), "dissolve reaches shader parameter")
	monster.configure(1, Vector2(865, 525), 0.9, [false, false, false], 0.0, 0.0, 0)
	check(monster.dissolve == 0.0 and float(monster.material.get_shader_parameter("dissolve")) == 0.0, "ordinary configure resets dissolve instead of retaining the finisher")
	monster.configure(0, Vector2.ZERO, 1.0, [false, false, false], 0.0, 0.0, -1, -1.0)
	check(monster.dissolve == 0.0, "negative dissolve clamps to zero")
	monster.configure(0, Vector2.ZERO, 1.0, [false, false, false], 0.0, 0.0, -1, 2.0)
	check(monster.dissolve == 1.0, "excess dissolve clamps to one")
	for hero in scene.model.heroes:
		hero.hp = 1
		hero.guard = false
	scene.model.intent = {"name": "Test party wipe", "part": 0, "damage": 100, "targets": [0, 1, 2], "description": "Deterministic defeat fixture."}
	scene.finish_round()
	check(scene.model.phase == "defeat" and not scene.finisher_active(), "party death does not start the boss finisher")
	scene._process(0.0)
	check(scene.generated_monster.visible, "boss remains visible on defeat")
	for actor in scene.actors: check(actor.state == "death", "defeat preserves hero death state")
	# Run the presentation's render callback in its valid draw notification.
	# This checks configure() arguments without claiming rendered-pixel validation.
	var draw_checked: Array[bool] = [false]
	var probe: Callable = func():
		draw_checked[0] = true
	scene.draw.connect(probe, CONNECT_ONE_SHOT)
	scene.queue_redraw()
	await process_frame
	await process_frame
	check(draw_checked[0], "headless draw notification exercised defeat renderer")
	check(monster.dissolve == 0.0, "defeat renderer resets prior dissolve after the completed frame")
	scene.begin_run()
	check(scene.model.start_battle(1), "fresh cycle can start a battle after defeat")
	scene.refresh()
	scene._process(0.0)
	await process_frame
	await process_frame
	check(not scene.finisher_active() and monster.dissolve == 0.0, "fresh battle has no lingering finisher or dissolve")
	check(monster.severed == [false, false, false], "fresh battle restores intact monster parts")
	print("FINISHER: defeat, shader defaults and fresh-battle reset finished")
