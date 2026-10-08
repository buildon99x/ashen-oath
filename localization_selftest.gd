extends SceneTree
## Isolated headless coverage for the Korean display boundary. Never starts main.tscn.
## Run with fresh XDG_DATA_HOME / XDG_CONFIG_HOME / XDG_CACHE_HOME directories.
const L = preload("res://localization.gd")
const Model = preload("res://model.gd")
var checks: int = 0
var failures: Array[String] = []
var reviewed: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _init() -> void:
	_test_language_and_preferences()
	_test_catalog_and_templates()
	_test_save_recovery_messages()
	_test_source_literals()
	_test_live_model()
	_test_old_save_and_logic()
	_test_font()
	L.set_language("ko")
	print("LOCALIZATION SELFTEST: %d checks, %d display strings reviewed, %d failures" % [checks, reviewed, failures.size()])
	for failure: String in failures:
		print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func _test_language_and_preferences() -> void:
	check(L.get_language() == "ko", "Korean is the first-launch default")
	check(L.t("Mara") == "마라", "Display-only hero localization")
	check(not L.set_language("fr"), "Unsupported language rejected")
	check(L.get_language() == "ko", "Unsupported language preserves current display")
	check(L.set_language("en-US"), "English locale normalization")
	for source: String in ["Mara", "The oath is sworn. Nine crossings stand between you and the last sun.", "Mara -9 HP / -1 focus", "Already 한국어 7", "Unknown future sentence."]:
		check(L.t(source) == source, "English returns exact canonical source: " + source)
	var path: String = "user://localization_test_language.cfg"
	check(L.save_preferences(path), "Language preference saves independently")
	L.set_language("ko")
	check(L.load_preferences(path) and L.get_language() == "en", "Separate language preference reloads")
	check(not L.load_preferences("user://nonexistent_localization_pref.cfg") and L.get_language() == "ko", "Missing preference defaults to Korean")
	var invalid: ConfigFile = ConfigFile.new()
	invalid.set_value("display", "language", "invalid")
	invalid.save(path)
	check(not L.load_preferences(path) and L.get_language() == "ko", "Invalid preference defaults to Korean")
	check(not L.save_preferences("user://ashen_oath_meta.json"), "Preference writer refuses legacy save filename")
	check(not L.save_preferences("user://ashen_oath_journey.save"), "Preference writer refuses journey save filename")
	L.clear_diagnostics()
	check(L.t("Unknown future sentence.") == "Unknown future sentence.", "Unknown source falls back intact")
	check("Unknown future sentence." in L.missing_sources(), "Unknown source is diagnosable")
	L.clear_diagnostics()

func review(source: String, context: String = "") -> void:
	if source.is_empty(): return
	reviewed += 1
	L.clear_diagnostics()
	var translated: String = L.t(source)
	check(not translated.is_empty(), "Nonempty translation: " + context)
	check(L.missing_sources().is_empty(), "Untranslated text in " + context + ": " + str(L.missing_sources()) + " / " + source)
	L.set_language("en")
	check(L.t(source) == source, "English round trip: " + context)
	L.set_language("ko")

func _test_catalog_and_templates() -> void:
	for source: String in L.CATALOG:
		review(source, "exact catalog")
		check(L.t(source) == L.CATALOG[source], "Exact catalog value: " + source)
		review(source.to_upper(), "uppercase UI names")
	var placeholder: RegEx = RegEx.create_from_string("%[+0-9.]*[dsf]")
	for entry: Array in L.TEMPLATES:
		var source: String = entry[0]
		var arguments: Array = []
		for spec: RegExMatch in placeholder.search_all(source):
			arguments.append("Mara" if spec.get_string().ends_with("s") else 7)
		review(source % arguments, "formatted template " + source)
	for source: String in [
		"Mara uses Oathblade on Offering Arm: 5 damage · WEAKNESS.",
		"Mara uses Oathblade on Offering Arm: 0 damage.",
		"Gravewake strikes Sable for 9 (guarded).",
		"SEVERED: Rooted Legs. Gravewake is silenced forever. 21 rupture damage.",
		"LOW · Rooted Legs\nSHIELD 3  |  HP 33/33\nWeak: blunt",
		"1  Mara  /  Ironbound\nHP 78/78   MP 6/6  READY",
		"Q  Oathblade\nSLASH · 0 MP\n7 DMG / -1 SHIELD",
		"MARA / OATHBLADE / FINAL STRIKE",
		"OMEN / SPLIT VERDICT",
		"Red Thread, Hollow Bell, Glass Tooth",
		"Mara: Defend cancels this rite. Break Crowned Head to halve; sever it to cancel.",
		"Crowned Head / STAGGERED",
		"CYCLE 13  /  ASH 124  /  GOLD 67  /  KARMA -2",
		"Sable -9 HP / -1 focus / guarded",
		"SPACE / END ROUND\nRESOLVE OMEN",
		"Blood Lantern restores 7 HP to every living ally.\nRound 12 · The Pale Sun prepares Fading Light / Choir of Ash.",
		"Animation event: HIT  /  frame 05  /  foot position unchanged",
		"ATTACK  /  DOWN  /  05 OF 06",
		"8 FPS  ·  ONE SHOT",
		"Speed  0.5×",
		"14 slash damage. Exploit SLASH weakness to remove 2 shields.\nForecast: 25 titan HP, including any sever rupture. Part damage is shown on the button."
	]: review(source, "composed screen fixture")
	check(L.t("Mara uses Oathblade on Offering Arm: 5 damage · WEAKNESS.") == "마라 → 제물의 팔: 맹세의 칼날, 피해 5 · 약점.", "Attack grammar preserves hero, target, skill, damage and weakness")

func _test_save_recovery_messages() -> void:
	var suffix: String = " Changes are still in memory; saving must succeed before closing."
	for prefix: String in ["The save data failed validation.", "The checkpoint could not be written.", "The previous checkpoint could not be protected.", "The checkpoint could not be committed."]:
		var complete: String = prefix + suffix
		review(complete, "complete save-failure warning")
		check(L.CATALOG.has(complete), "Full concatenated save-failure warning has exact mapping")
		check(L.t(complete).contains("게임을 닫기 전에 저장을 완료해야 합니다."), "Save-failure warning retains required action")

func _test_source_literals() -> void:
	# Check prose actually present at the integration boundary. Identifiers/paths
	# are deliberately excluded because these must stay canonical in the model.
	var literal: RegEx = RegEx.create_from_string('"(?:[^"\\\\]|\\\\.)*"')
	var prose: RegEx = RegEx.create_from_string("[A-Za-z].* [A-Za-z]")
	for path: String in ["res://main.gd", "res://model.gd", "res://legacy/legacy_content.gd", "res://character_studio.gd"]:
		var content: String = FileAccess.get_file_as_string(path)
		for matched: RegExMatch in literal.search_all(content):
			var decoded: Variant = JSON.parse_string(matched.get_string())
			if not decoded is String: continue
			var source: String = decoded
			if source.begins_with("res://") or source.begins_with("user://") or source.begins_with("#"):
				continue
			if prose.search(source) == null:
				continue
			# These are fragments assembled into complete intent templates, not
			# independently rendered strings. Real generated intents are tested below.
			if source in [" and drains 1 focus from unguarded heroes", " and drains 1 focus", " / -%d focus", " / -%d MP", " Second source: %s from %s. %s"]:
				continue
			if source.contains("%"):
				var placeholder: RegEx = RegEx.create_from_string("%[+0-9.]*[dsf]")
				var arguments: Array = []
				for spec: RegExMatch in placeholder.search_all(source):
					arguments.append("Mara" if spec.get_string().ends_with("s") else 7)
				if arguments.is_empty(): continue
				match source:
					"%s -%d HP%s%s": arguments = ["Mara", 7, " / -1 focus", " / guarded"]
					"%s strikes %s for %d%s.": arguments = ["Gravewake", "Mara", 7, " (guarded)"]
					"%s for %d damage. Break to halve it; sever to cancel it.": arguments = ["Hits every living hero", 7]
					"Targets %s for %d damage%s. %s can Defend to cancel this rite. Break %s to halve it; sever to cancel it.": arguments = ["Mara", 7, " and drains 1 focus", "Mara", "Crowned Head"]
				source = source % arguments
			review(source, "source literal " + path)

func inspect_display(value: Variant, context: String = "model") -> void:
	if value is Array:
		for child: Variant in value: inspect_display(child, context)
	elif value is Dictionary:
		for key: String in value:
			var child: Variant = value[key]
			if child is String and key in ["name", "title", "role", "description", "level", "move", "summary", "source", "counterplay", "next", "last_error"]:
				review(child, context + "/" + key)
			elif child is Dictionary or child is Array:
				if key == "log":
					for line: String in child: review(line, "combat log")
				else: inspect_display(child, context + "/" + key)

func fresh(seed_value: int = 73):
	var model = Model.new()
	model.persist_meta = false
	model.meta = {"essence": 0, "upgrades": {"vitality": 0, "force": 0, "focus": 0}, "runs": 0, "wins": 0}
	model.new_run(seed_value)
	return model

func _test_live_model() -> void:
	var model = fresh()
	inspect_display(model.describe(), "new journey")
	for kind: String in ["camp", "relic", "event"]:
		model._open_event(kind)
		inspect_display(model.describe(), kind)
		for option in model.event.options: review(str(option.name) + ".", "event log")
	model.run.relics = Model.RELICS.duplicate(true)
	for kind: String in ["relic", "event"]:
		model._open_event(kind)
		inspect_display(model.describe(), "full relic inventory")
	model.phase = "map"
	model.start_battle(1)
	model._win_battle()
	inspect_display(model.describe(), "relic duplicate reward")
	for tier: int in [1, 2, 3]:
		for milestone: bool in [false, true]:
			model = fresh(101 + tier)
			model._milestone = milestone
			model.start_battle(tier)
			for round_value: int in [1, 2, 3, 4, 9, 12]:
				model.round_number = round_value
				model._prepare_intent()
				inspect_display(model.describe(), "live battle")
				inspect_display(model.preview_intent(), "incoming omen")
				for h: int in range(3):
					for skill: int in range(4):
						for part: int in range(3): inspect_display(model.preview_action(h, skill, part), "action forecast")
				for part in model.parts: part.broken = true
				inspect_display(model.preview_intent(), "staggered omen")
				for hero in model.heroes: hero.guard = true
				inspect_display(model.preview_intent(), "warded omen")
				for hero in model.heroes: hero.hp = 0
				inspect_display(model.preview_intent(), "fallen fixed targets")
				for part in model.parts: part.severed = true
				inspect_display(model.preview_intent(), "cancelled omen")
				for hero in model.heroes: hero.hp = hero.max_hp; hero.guard = false
				for part in model.parts: part.severed = false; part.broken = false
				# Only one source left changes each sovereign's rhythm prose.
				model.parts[1].severed = true; model.parts[2].severed = true
				model._prepare_intent()
				inspect_display(model.intent, "single surviving source")
				model.parts[1].severed = false; model.parts[2].severed = false
	# Execute real seeded journeys with all event/reward branches and combat logs.
	for seed_value: int in range(1, 10):
		model = fresh(seed_value)
		model.meta.upgrades.force = 5
		model.meta.upgrades.vitality = 5
		var steps: int = 0
		while model.phase not in ["victory", "defeat"] and steps < 500:
			steps += 1
			match model.phase:
				"map": model.travel(seed_value % model.choices.size())
				"camp", "relic", "event":
					var choice: int = seed_value % model.event.options.size()
					if not model.choose_event(choice):
						review(model.last_error, "cost rejection")
						model.choose_event(1 if model.phase == "event" else 0)
				"reward": model.choose_reward(seed_value % 3)
				"battle":
					for h: int in range(3):
						if model.phase != "battle": break
						if model.heroes[h].hp <= 0 or model.heroes[h].acted: continue
						var target: int = model._intact_parts()[0]
						var skill: int = 2 if model.parts[target].broken and model.heroes[h].mp >= 3 else 0
						model.act(h, skill, target)
					if model.phase == "battle": model.end_round()
			inspect_display(model.describe(), "seeded journey %d" % seed_value)
		check(model.phase in ["victory", "defeat"], "Seeded journey reaches terminal outcome")

func _test_old_save_and_logic() -> void:
	var model = fresh(721)
	model._milestone = true
	model.start_battle(3)
	model.round_number = 2
	model._prepare_intent()
	model.log.append("Mara defends: incoming damage halved; +2 focus, +3 HP.")
	model.heroes[0].skills[3].description = "Halve incoming damage this round. Restore 2 focus and 3 HP."
	model.log.append("Mara uses Sundering Arc on Crowned Head: 45 damage.")
	var snapshot: Dictionary = model.describe()
	var path: String = "user://localization_legacy_journey.save"
	check(model.save_resume(path), "Canonical English journey saved")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	L.set_language("ko")
	inspect_display(model.describe(), "old English save in Korean")
	check(model.describe() == snapshot, "Translation leaves every model field unchanged")
	check(model.heroes[0].skills[2].name == "Sundering Arc", "Combat skill comparison key remains English")
	check(model.heroes[1].skills[2].name == "Blood Lantern", "Heal skill comparison key remains English")
	check(L.save_preferences("user://localization_isolated_language.cfg"), "Preference saved beside existing journey")
	check(FileAccess.get_file_as_bytes(path) == bytes, "Language preference leaves journey bytes unchanged")
	L.set_language("en")
	check(model.describe() == snapshot, "English switch also leaves model unchanged")
	var resumed = Model.new(); resumed.persist_meta = false
	check(resumed.load_resume(path), "Existing canonical save reloads")
	L.set_language("ko")
	inspect_display(resumed.describe(), "resumed old English logs")
	check(resumed.log.back() == "Mara uses Sundering Arc on Crowned Head: 45 damage.", "Stored old log retained verbatim")
	check(L.t(resumed.log.back()).contains("분쇄의 참격"), "Old English log localizes after reload")
	var before_hp: int = resumed.heroes[0].hp
	resumed.heroes[0].hp -= 15
	var wounded_hp: int = resumed.heroes[0].hp
	check(resumed.act(1, 2, 0), "Canonical Blood Lantern accepted after language switch")
	check(resumed.heroes[0].hp == mini(before_hp, wounded_hp + 7), "Canonical heal behavior survives localization")

func _test_font() -> void:
	var font: FontFile = FontFile.new()
	check(font.load_dynamic_font(L.FONT_PATH) == OK, "Bundled Korean OTF loads without system fonts")
	check(font.get_font_name() == "Ashen Korean", "Font is the renamed Korean face")
	var server: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var absent: Array[int] = []
	for codepoint: int in range(0xAC00, 0xD7A4):
		if not font.has_char(codepoint) or server.font_get_glyph_index(rid, 22, codepoint, 0) == 0:
			absent.append(codepoint)
	check(absent.is_empty(), "All 11,172 modern Hangul syllables have non-tofu glyphs")
	for codepoint: int in [0x1100, 0x1161, 0x11A8, 0x3131, 0x314F, 0x2191, 0x2193, 0x2022, 0x00B7, 0x2013, 0x00D7]:
		check(font.has_char(codepoint), "Required Jamo/punctuation glyph U+%04X" % codepoint)
	var glyphs: Dictionary = {}
	for translated: String in L.CATALOG.values():
		for index: int in range(translated.length()): glyphs[translated.unicode_at(index)] = true
	for template: Array in L.TEMPLATES:
		var translated: String = template[1]
		for index: int in range(translated.length()): glyphs[translated.unicode_at(index)] = true
	for codepoint: int in glyphs:
		if codepoint in [9, 10, 13]: continue
		check(font.has_char(codepoint), "Catalog glyph exists U+%04X" % codepoint)
	var shaped: RID = server.create_shaped_text()
	check(server.shaped_text_add_string(shaped, "재의 맹세 · 마라 · 방어막 붕괴 · 유물 · 집중력 7 · ↑/↓", font.get_rids(), 22), "Representative Korean text accepted for shaping")
	check(server.shaped_text_shape(shaped), "Korean text shapes headlessly")
	var missing: int = 0
	for glyph: Dictionary in server.shaped_text_get_glyphs(shaped):
		if int(glyph.get("index", 0)) == 0: missing += 1
	check(missing == 0, "Shaped Korean UI has no missing/tofu glyph indexes")
	check(server.shaped_text_get_size(shaped).x > 200, "Korean text has measurable nonzero layout")
	server.free_rid(shaped)
