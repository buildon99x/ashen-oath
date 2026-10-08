extends SceneTree
const FxTest = preload("res://combat_fx/test_helpers.gd")
## CP12 bilingual scene-tree, shaping, layout and lifecycle checks. Native QA is separate.
const L = preload("res://localization.gd")
const Model = preload("res://model.gd")
var checks: int = 0
var failures: Array[String] = []
var contexts: int = 0

func check(value: bool, context: String) -> void:
	checks += 1
	if not value:
		failures.append(context)
		push_error("LOCALIZED UI: " + context)

func _initialize() -> void:
	call_deferred("run_tests")

func fixture(scene, seed_value: int = 21) -> void:
	scene.model = Model.new()
	if scene.model.has_method("_clear_journey"): scene.model._clear_journey()
	scene.model.persist_meta = false
	scene.model.meta = {"essence": 200, "upgrades": {"vitality": 0, "force": 0, "focus": 0}, "runs": 0, "wins": 0}
	scene.model.new_run(seed_value)
	scene.menu = false
	scene.coach_open = false
	scene.coach_eligible = false
	scene.recovery_notice = ""
	scene.recovery_notice_open = false
	scene.save_error_open = false
	scene.dismissed_save_error = ""
	scene.model.clear_recovery_notice()
	scene.model.save_status = "idle"
	scene.model.save_message = ""
	scene.help_open = false
	scene.build_open = false
	scene.confirmation = ""
	scene.finisher_remaining = 0.0
	scene.message = ""
	scene.selected_hero = 0
	scene.selected_part = 0

func check_display(scene, context: String) -> void:
	contexts += 1
	check(L.missing_sources().is_empty(), context + " untranslated canonical text: " + str(L.missing_sources()))
	for control in scene.ui.get_children():
		if control.is_queued_for_deletion(): continue
		if not control is Label and not control is Button: continue
		var text: String = control.text
		var font: Font = control.get_theme_font("font")
		var font_size: int = control.get_theme_font_size("font_size")
		if L.get_language() == "en":
			check(not text.contains(" MP") and not text.to_lower().contains("essence"), context + " consistent Focus/Ash: " + text)
		else:
			for offset: int in range(text.length()):
				var codepoint: int = text.unicode_at(offset)
				if codepoint in [9,10,13]: continue
				check(font.has_char(codepoint), context + " missing glyph U+%04X" % codepoint)
		check(control.position.y + control.size.y <= 901, context + " control exceeds bottom: " + text)
		if control is Button:
			check(control.position.x + control.size.x <= 1441, context + " button exceeds right: " + text)
			if control.has_meta("layout_rect"):
				var intended: Rect2 = control.get_meta("layout_rect")
				check(control.size.x <= intended.size.x + 1 and control.size.y <= intended.size.y + 1, context + " button inflated: " + text + " " + str(control.size))
			for line: String in text.split("\n"):
				var width: float = font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
				var margins: float = control.get_theme_stylebox("normal").get_minimum_size().x
				check(width <= control.size.x-margins+1, context + " button line too wide: " + line)
		elif control.autowrap_mode == TextServer.AUTOWRAP_OFF:
			for line: String in text.split("\n"):
				check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= control.size.x+1, context + " label line too wide: " + line)
		if control is Label and control.position.x == 40 and control.position.y < 530 and control.autowrap_mode != TextServer.AUTOWRAP_OFF:
			check(control.position.y + control.size.y <= 529, context + " omen copy stays inside panel: " + str(control.size))
		if not control.tooltip_text.is_empty() and L.get_language() == "ko":
			var tooltip_font: Font = control.get_theme_font("font", "TooltipLabel")
			check(tooltip_font != null and tooltip_font.has_char("맹".unicode_at(0)), context + " tooltip has Korean font")

func draw_case(scene, context: String) -> void:
	L.clear_diagnostics()
	scene.refresh(false)
	await process_frame
	await process_frame
	check_display(scene, context)

func run_tests() -> void:
	root.size = Vector2i(1440,900)
	L.set_language("ko")
	L.save_preferences()
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.muted = true
	scene.set_process(false)
	await process_frame
	check(L.get_language() == "ko", "Fresh main starts in Korean")
	for language: String in ["ko", "en"]:
		L.set_language(language)
		scene.apply_language_theme()
		check(scene.get_window().title == scene.display_text("ASHEN OATH — The Hollow Crown"), language + " main Window.title follows display language")
		fixture(scene)
		scene.menu = true
		await draw_case(scene, language + " active journey menu")
		for child in scene.ui.get_children():
			if child is Button and child.position.y == 729: check(child.disabled, "Legacy upgrades disabled during active journey")
		scene.model.phase = "title"
		await draw_case(scene, language + " title upgrades")
		for child in scene.ui.get_children():
			if child is Button and child.position.y == 729: check(not child.disabled, "Affordable legacy upgrades enabled between runs")
		scene.model.meta.upgrades = {"vitality": 5, "force": 5, "focus": 5}
		await draw_case(scene, language + " maximum upgrades")
		for child in scene.ui.get_children():
			if child is Button and child.position.y == 729: check(child.disabled and ("MAX" in child.text or "최고" in child.text), "Max-rank card shows cap and is disabled")
		fixture(scene)
		await draw_case(scene, language + " map")
		for kind: String in ["camp", "event", "relic"]:
			scene.model._open_event(kind)
			await draw_case(scene, language + " " + kind)
			scene.model.run.relics = Model.RELICS.duplicate(true)
			scene.model._open_event(kind)
			await draw_case(scene, language + " " + kind + " full inventory")
		for tier: int in [1,2,3]:
			fixture(scene)
			scene.model._milestone = true
			scene.model.start_battle(tier)
			for round_number: int in [1,2,3]:
				scene.model.round_number = round_number
				scene.model._prepare_intent()
				await draw_case(scene, "%s battle tier %d round %d" % [language,tier,round_number])
			for focus_left: int in [0,5,6]:
				scene.selected_hero = 0
				scene.model.heroes[0].mp = focus_left
				scene.model.heroes[0].max_mp = 6
				await draw_case(scene, language + " capped Defend recovery")
				var found: bool = false
				for child in scene.ui.get_children():
					if child is Label and child.position == Vector2(942,747) and child.get_meta("symbol", "") == "focus":
						var gain: int = mini(2,6-focus_left)
						found = child.text == "+%d" % gain
				check(found, "Defend displays actual capped Focus gain")
		fixture(scene)
		scene.model.start_battle(1)
		scene.help_open = true
		await draw_case(scene, language + " guide")
		for child in scene.ui.get_children():
			if child is Label and child.position.y == 200: check(child.position.y+child.size.y <= 710, language + " guide body clears close button: " + str(child.size))
		scene.help_open = false
		scene.model.run.relics = Model.RELICS.duplicate(true)
		scene.build_open = true
		await draw_case(scene, language + " full build")
		scene.build_open = false
		scene.confirmation = "end_round"
		await draw_case(scene, language + " end-round confirmation")
		scene.confirmation = "new_cycle"
		await draw_case(scene, language + " abandon confirmation")
		scene.confirmation = ""
		scene.coach_open = true
		await draw_case(scene, language + " first battle coach")
		for child in scene.ui.get_children():
			if child is Label and child.position.y == 253: check(child.position.y+child.size.y <= 657, language + " coach body clears dismiss button: " + str(child.size))
		scene.coach_open = false
		scene.model.boss.hp = 1
		scene.perform(0)
		FxTest.settle(scene)
		await draw_case(scene, language + " finisher")
		var reward_snapshot: Dictionary = scene.model.describe()
		var finisher_time: float = scene.finisher_remaining
		var language_event: InputEventMouseButton = InputEventMouseButton.new()
		language_event.button_index = MOUSE_BUTTON_LEFT
		language_event.pressed = true
		language_event.position = scene.LANGUAGE_RECT.get_center()
		scene._input(language_event)
		check(scene.finisher_active() and scene.finisher_remaining == finisher_time, "Live language button does not skip finisher")
		check(scene.model.describe() == reward_snapshot, "Language click during finisher does not alter resolved rewards")
		scene.toggle_language()
		scene.finish_presentation()
		await draw_case(scene, language + " reward")
		for phase: String in ["victory", "defeat"]:
			scene.model.phase = phase
			await draw_case(scene, language + " " + phase)
	await test_save_notices(scene)
	# Contextual coach and language switches never consume turns or mutate rules.
	fixture(scene)
	scene.model.phase = "title"
	scene.model.run.clear()
	scene.model._settled = true
	scene.model.meta.runs = 0
	scene.begin_run()
	check(not scene.coach_open, "First map does not force the battle coach")
	scene.model.start_battle(1)
	scene.refresh(false)
	check(scene.coach_open, "Coach appears before actions in first battle of explicitly begun cycle")
	var before: Dictionary = scene.model.describe()
	var rng_state: int = scene.model.rng.state
	scene.perform(0)
	FxTest.settle(scene)
	check(scene.model.describe() == before, "Coach blocks accidental combat hotkeys")
	scene.toggle_language()
	check(scene.model.describe() == before and scene.model.rng.state == rng_state, "Language switch changes no model state or RNG")
	check(scene.coach_open, "Language switch preserves contextual modal")
	scene.dismiss_first_battle_coach()
	check(bool(scene.model.run.get("first_battle_coach_seen",false)), "Coach dismissal marker persists in optional run metadata")
	check(scene.model.round_number == 1 and scene.model.actions_remaining() == 3, "Dismissal spends no turns or actions")
	scene.refresh(false)
	check(not scene.coach_open, "Dismissed coach does not reopen")
	fixture(scene)
	scene.model.start_battle(1)
	scene.refresh(false)
	check(not scene.coach_open, "Progressed/resumed journeys are never forced into coach")
	scene.coach_eligible = true
	scene.model.act(0,0,0)
	scene.refresh(false)
	check(not scene.coach_open, "First-battle coach does not interrupt after an action")
	fixture(scene)
	scene.model.phase = "defeat"
	scene.menu = true
	scene.refresh(false)
	var has_review_label: bool = false
	for child in scene.ui.get_children():
		if child is Button and not child.is_queued_for_deletion() and child.text == scene.display_text("REVIEW LAST JOURNEY"):
			has_review_label = true
	check(has_review_label, "Completed journey offers result review rather than a misleading playable resume")
	# A first journey resumed before its first battle still receives the coach.
	fixture(scene)
	scene.model.meta.essence = 0
	scene.model.persist_meta = true
	check(scene.model.retry_save(), "First map checkpoint persists before leaving the process")
	var resumed_scene = load("res://main.tscn").instantiate()
	root.add_child(resumed_scene)
	await process_frame
	check(resumed_scene.coach_eligible and resumed_scene.menu, "Fresh process restores first-battle eligibility without interrupting title")
	resumed_scene.menu = false
	resumed_scene.model.start_battle(1)
	resumed_scene.refresh(false)
	check(resumed_scene.coach_open, "Resumed pre-battle first journey still teaches the first action")
	check(resumed_scene.model.actions_remaining() == 3, "Resumed coach preserves all three actions")
	resumed_scene.queue_free()
	await process_frame
	scene.model.persist_meta = false
	# Visible language button and L key are present; finisher still consumes combat input.
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_L; event.pressed = true
	var old_language: String = L.get_language()
	scene._unhandled_key_input(event)
	check(L.get_language() != old_language, "L hotkey toggles language")
	check(scene.get_window().title == scene.display_text("ASHEN OATH — The Hollow Crown"), "Main language hotkey updates Window.title")
	scene.queue_free()
	await process_frame
	await test_studio()
	print("LOCALIZED UI SELFTEST: %d checks; %d contexts; %d failures (headless layout/input/font coverage, not native visual QA)" % [checks,contexts,failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_studio() -> void:
	for language: String in ["ko", "en"]:
		L.set_language(language); L.save_preferences(); L.clear_diagnostics()
		var studio = load("res://character_studio.tscn").instantiate()
		root.add_child(studio)
		studio.set_process(false)
		await process_frame
		await process_frame
		check(studio.get_window().title == L.t("ASHEN OATH — Character Studio"), language + " studio Window.title follows display language")
		check_display(studio, language + " studio")
		studio.select_state("attack")
		studio._on_animation_event("attack","hit")
		studio._update_status()
		check_display(studio, language + " studio animation event")
		studio.set_checker(false); studio.set_anchors(false)
		var position: Vector2 = studio.hero.position
		var state: String = studio.hero.state
		studio.toggle_language()
		await process_frame
		check(studio.get_window().title == L.t("ASHEN OATH — Character Studio"), "Studio language toggle updates Window.title")
		check(studio.hero.position == position and studio.hero.state == state, "Studio language switch preserves animation state and position")
		check(not studio.ui.get_node("Checker").button_pressed and not studio.ui.get_node("Anchors").button_pressed, "Studio language switch preserves display toggles")
		check_display(studio, language + " studio after language switch")
		studio.queue_free()
		await process_frame

func test_save_notices(scene) -> void:
	for language: String in ["ko", "en"]:
		L.set_language(language); scene.apply_language_theme(); fixture(scene)
		scene.model._recovery("recovered", "A damaged or interrupted save was recovered from a complete checkpoint. Some recent actions may need to be repeated.")
		await draw_case(scene, language + " recovery notice")
		check(scene.recovery_notice_open, "Recovery is shown until explicit dismissal")
		var snapshot: Dictionary = scene.model.describe()
		scene.toggle_language()
		check(scene.recovery_notice_open and scene.model.describe() == snapshot, "Language change preserves recovery notice and journey")
		scene.dismiss_recovery_notice()
		check(scene.model.recovery_status == "none" and not scene.recovery_notice_open, "Explicit dismissal calls clear_recovery_notice")
		L.set_language(language); scene.apply_language_theme()
		scene.model.meta_path = "user://missing-ui-test-folder/meta.json"
		scene.model._resume_path = "user://ui_retry_%s.save" % language
		check(not scene.model.save_meta(), "Actual unwritable path reports save failure")
		await draw_case(scene, language + " save error")
		check(scene.save_error_open, "Save failure is explicit")
		scene.retry_save()
		check(scene.save_error_open and scene.model.save_status == "error", "Failed retry does not dismiss warning")
		scene.dismiss_save_error()
		await draw_case(scene, language + " dismissed save error banner")
		check(not scene.save_error_open and not scene.save_notice.is_empty(), "Dismissed save failure retains visible review indicator")
		scene.open_save_error()
		check(scene.save_error_open, "Save warning can be reopened")
		scene.model.meta_path = "user://ui_retry_%s_meta.json" % language
		scene.retry_save()
		check(scene.model.save_status == "saved" and not scene.save_error_open and scene.save_notice.is_empty(), "Retry repairs paired saves and clears failure UI")
		check(FileAccess.file_exists(scene.model.meta_path) and FileAccess.file_exists(scene.model._resume_path), "Successful retry writes both vault and journey")
		# A second model creates a genuinely newer checkpoint, then the stale UI
		# must ask before reloading and discard only its unsaved in-memory action.
		var newer = Model.new(); newer.persist_meta = false
		newer.meta_path = scene.model.meta_path; newer._resume_path = scene.model._resume_path
		check(newer.load_meta() and newer.load_resume(newer._resume_path), "Second window opens matching checkpoint")
		newer.run.gold += 1
		check(newer.retry_save(), "Second window writes a newer valid checkpoint")
		scene.model.run.gold += 7
		check(not scene.model.retry_save(), "Stale window cannot overwrite newer checkpoint")
		await draw_case(scene, language + " stale-window conflict")
		scene.request_reload_save()
		await draw_case(scene, language + " explicit reload confirmation")
		check(scene.confirmation == "reload_save", "Reload requires explicit confirmation")
		check(scene.model.run.gold == newer.run.gold+6, "Showing confirmation does not discard unsaved actions")
		scene.confirm_action()
		check(scene.model.run.gold == newer.run.gold, "Confirmed reload discards stale actions and restores newest checkpoint")
		check(not scene.recovery_notice_open and not scene.save_error_open, "Successful explicit reload clears obsolete warning UI")
		# Equal-revision corruption cannot be bypassed through the UI's reload.
		var latest_path: String = newer._resume_path
		var contradictory: Dictionary = newer._read_record(latest_path).duplicate(true)
		contradictory.erase("digest")
		contradictory.journey.run.gold += 10
		var payload: PackedByteArray = var_to_bytes(contradictory)
		var envelope: Dictionary = {"version": 2, "payload": Marshalls.raw_to_base64(payload), "sha256": newer._digest(payload)}
		var altered: FileAccess = FileAccess.open(newer.meta_path, FileAccess.WRITE)
		altered.store_string(JSON.stringify(envelope)); altered.close()
		var vault_hash: String = FileAccess.get_sha256(newer.meta_path)
		var journey_hash: String = FileAccess.get_sha256(latest_path)
		scene.model._resume_path = latest_path
		check(not scene.model.load_meta(), "Equal-revision split refuses profile load")
		await draw_case(scene, language + " equal-revision conflict")
		var conflicted_memory: Dictionary = scene.model.describe()
		scene.request_reload_save()
		scene.confirm_action()
		check(scene.model.describe() == conflicted_memory, "Unresolved profile conflict cannot partially replace the live journey")
		check(scene.recovery_notice_open and scene.model.recovery_status == "conflict", "Confirmed reload cannot dismiss an unresolved equal-revision split")
		check(FileAccess.get_sha256(newer.meta_path) == vault_hash and FileAccess.get_sha256(latest_path) == journey_hash, "Conflicting files remain byte-identical after UI reload attempt")
