extends SceneTree
## Headless, isolated-files regression suite. No scene, UI, or player's save.
const Model = preload("res://model.gd")
const ROOT = "user://save_recovery_selftest/"
var checks: int = 0
var failures: int = 0
var profile_index: int = 0

class FaultModel:
	extends Model
	var fail_at: String = ""
	func _write_checked(path: String, bytes: PackedByteArray) -> bool:
		if fail_at == "write" and not path.ends_with(".bak.tmp"):
			return false
		if fail_at == "backup_write" and path.ends_with(".bak.tmp"):
			return false
		return super._write_checked(path, bytes)
	func _replace_file(source: String, destination: String) -> bool:
		if fail_at == "commit" and not source.ends_with(".bak.tmp"):
			return false
		if fail_at == "backup_commit" and source.ends_with(".bak.tmp"):
			return false
		return super._replace_file(source, destination)

func _initialize() -> void:
	if "--default-path-only" in OS.get_cmdline_user_args():
		_test_default_startup()
		print("DEFAULT-PATH RECOVERY: %d checks; %d failures" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	_test_settlement_gap()
	_test_purchase_gap()
	_test_abandonment_gap()
	_test_newer_journey()
	_test_profile_only()
	_test_legacy_migration()
	_test_corruption()
	_test_failed_writes()
	_test_validation()
	_test_exact_continuation()
	_test_all_phases()
	_test_minimum_seed()
	_test_revision_conflict()
	_test_unrestored_profile_save()
	_test_stale_writer()
	_test_repair_both_copies()
	print("SAVE RECOVERY: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func fresh(seed_value: int = 7821):
	profile_index += 1
	var prefix: String = ROOT + str(profile_index)
	# Repeated test invocations clean only their own numbered fixture files.
	for extension: String in [".json", ".save"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + extension + suffix))
	var m = FaultModel.new()
	m.persist_meta = false
	m.meta = {"essence": 0, "upgrades": {"vitality": 0, "force": 0, "focus": 0}, "runs": 0, "wins": 0}
	m.meta_path = prefix + ".json"
	m._resume_path = prefix + ".save"
	m.new_run(seed_value)
	return m

func reader(m):
	var n = Model.new()
	n.persist_meta = false
	n.meta_path = m.meta_path
	n._resume_path = m._resume_path
	return n

func reload_pair(m):
	var n = reader(m)
	n.load_meta()
	n.load_resume(m._resume_path)
	return n

func raw_write(path: String, bytes: PackedByteArray) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func legacy_vault(m, value: Dictionary) -> void:
	raw_write(m.meta_path, JSON.stringify({"version": 1, "meta": value}).to_utf8_buffer())

func legacy_journey(m, snapshot: Dictionary = {}) -> void:
	var file = FileAccess.open(m._resume_path, FileAccess.WRITE)
	file.store_var(snapshot if not snapshot.is_empty() else m._journey_snapshot(), false)
	file.close()

func prepare_pending(m) -> void:
	m.start_battle(2)
	m.run.essence = 18
	check(m.act(0, 1, 0), "Prepared partial-action battle")
	check(m.save_resume(m._resume_path), "Saved the older active journey")

func defeat(m) -> void:
	for hero in m.heroes:
		hero.hp = 1
		hero.guard = false
	m.intent = {"name": "Test final omen", "part": 0, "damage": 100, "targets": [0, 1, 2], "description": "Final omen"}
	m.parts[0].severed = false
	m.end_round()

func _test_settlement_gap() -> void:
	var m = fresh()
	prepare_pending(m)
	m.persist_meta = true
	defeat(m) # Deliberately never call save_resume/refresh after settlement.
	check(m.save_status == "saved" and m.phase == "defeat", "Settlement commits before UI refresh")
	var n = reload_pair(m)
	check(n.meta.essence == 18 and n.meta.runs == 1 and n.phase == "defeat", "Newer vault restores complete settled transaction instead of stale battle")
	check(n._settled and n.describe() == m.describe(), "Recovered settlement has exact ending state")
	n._settle_run(false)
	check(n.meta.essence == 18 and n.meta.runs == 1, "Reloaded settlement cannot bank twice")
	check(not n.end_round() and not n.choose_reward(0), "Settled ending rejects battle/reward replay")
	check(n.save_resume(n._resume_path), "Recovered state can be checkpointed")
	var again = reload_pair(n)
	check(again.meta.essence == 18 and again.meta.runs == 1 and again._settled, "Repeated restart preserves exactly one settlement")
	# Victory's final reward and dawn bonus are part of the same transaction.
	var win = fresh()
	win.start_battle(3)
	win.run.node = 8
	win.run.stage = 8
	win._win_battle()
	check(win.save_resume(win._resume_path), "Saved pending final reward")
	win.persist_meta = true
	check(win.choose_reward(1), "Claimed final tribute and victory")
	var won = reload_pair(win)
	check(won.phase == "victory" and won.meta == win.meta and won.meta.wins == 1, "Victory survives gap before reward-screen refresh")
	check(not won.choose_reward(1) and won.meta == win.meta, "Final tribute cannot be claimed again after recovery")

func _test_purchase_gap() -> void:
	var m = fresh()
	prepare_pending(m)
	m.persist_meta = true
	defeat(m)
	check(m.save_resume(m._resume_path), "Saved old ending before purchase")
	check(m.buy_upgrade("vitality"), "Purchased upgrade from settled balance")
	var n = reload_pair(m)
	check(n.meta.essence == 6 and n.meta.upgrades.vitality == 1, "Newer purchase preserves lower Ash balance, never max(Ash)")
	check(n.phase == "defeat" and n._settled, "Purchase does not reopen the settled journey")
	n.new_run(42)
	check(n.heroes[0].max_hp == 83 and n.meta.essence == 6, "Recovered upgrade applies exactly once on next cycle")

func _test_abandonment_gap() -> void:
	var m = fresh()
	prepare_pending(m)
	m.persist_meta = true
	m.new_run(777)
	var n = reload_pair(m)
	check(n.phase == "map" and n.run.seed == 777 and n.run.essence == 0, "Interrupted new-cycle flow resumes replacement journey")
	check(n.meta.runs == 1 and n.meta.essence == 0, "Abandonment forfeits Ash and counts once")
	check(n.describe() == m.describe() and n.rng.state == m.rng.state, "Replacement journey and RNG committed as one state")
	check(n.save_resume(n._resume_path), "Replacement can save again")
	var again = reload_pair(n)
	check(again.meta.runs == 1 and again.run.seed == 777, "Reload does not count abandonment twice or restore abandoned battle")

func _test_newer_journey() -> void:
	var m = fresh()
	check(m.save_meta(), "Saved older map bundle in vault")
	prepare_pending(m)
	var n = reload_pair(m)
	check(n.describe() == m.describe() and n.rng.state == m.rng.state, "Newer journey wins over older vault as a whole")
	m.persist_meta = false
	defeat(m)
	m.meta.essence = 34
	check(m.buy_upgrade("force"), "Spent Ash without automatic vault write")
	check(m.save_resume(m._resume_path), "Wrote newer journey containing upgrade purchase")
	n = reload_pair(m)
	check(n.meta.essence == 18 and n.meta.upgrades.force == 1 and n.phase == "defeat", "Newer journey restores lower post-purchase balance")

func _test_profile_only() -> void:
	var m = fresh()
	prepare_pending(m)
	m.persist_meta = true
	defeat(m)
	var n = reader(m)
	check(n.load_meta(), "load_meta reads full envelope")
	check(n.meta == m.meta and n.phase == "title" and n.run.is_empty() and n.heroes.is_empty(), "load_meta preserves profile-only public behavior")
	var envelope = JSON.parse_string(FileAccess.get_file_as_string(m.meta_path))
	check(envelope is Dictionary and envelope.version == 2 and envelope.payload is String, "Meta file remains genuine UTF-8 JSON")
	# A deliberately saved title retires an old on-disk journey too.
	m._clear_journey()
	check(m.save_meta(), "Can checkpoint a profile without a journey")
	n = reload_pair(m)
	check(n.phase == "title" and n.run.is_empty() and n.meta.essence == 18, "Newer empty journey prevents stale resume resurrection")

func _test_legacy_migration() -> void:
	var m = fresh()
	m.start_battle(2)
	m.act(0, 3)
	legacy_vault(m, m.meta)
	legacy_journey(m)
	var n = reload_pair(m)
	check(n.describe() == m.describe() and n.rng.state == m.rng.state, "Matching version-1 pair restores exact old partial action/RNG")
	m.end_round()
	n.end_round()
	check(n.describe() == m.describe() and n.rng.state == m.rng.state, "Legacy continuation remains deterministic")
	check(n.save_resume(n._resume_path), "Version-1 journey migrates on next successful save")
	check(n._read_record(n._resume_path).version == 2, "Migrated record is complete v2")
	# Reproduction: already-banked 18 Ash / 1 run vs old active 0 / 0.
	m = fresh()
	m.start_battle(1)
	m.run.essence = 18
	legacy_journey(m)
	defeat(m)
	legacy_vault(m, m.meta)
	n = reload_pair(m)
	check(n.meta.essence == 18 and n.meta.runs == 1, "Legacy interrupted settlement keeps 18 Ash / 1 run")
	check(n.phase == "title" and n.run.is_empty() and n.recovery_status == "legacy_reconciled", "Legacy stale unfinished journey is retired with notice")
	# Legacy interrupted upgrade purchase: same completed run, higher rank.
	m = fresh()
	m.start_battle(1)
	m.run.essence = 30
	defeat(m)
	legacy_journey(m)
	m.buy_upgrade("vitality")
	legacy_vault(m, m.meta)
	n = reload_pair(m)
	check(n.meta.essence == 18 and n.meta.upgrades.vitality == 1 and n.phase == "defeat", "Legacy newer upgrade retains spent Ash and ending")
	# Legacy abandonment wrote only its vault before replacing the old run.
	m = fresh()
	m.run.essence = 12
	legacy_journey(m)
	m.new_run(123)
	legacy_vault(m, m.meta)
	n = reload_pair(m)
	check(n.meta.essence == 0 and n.meta.runs == 1 and n.run.is_empty(), "Legacy abandoned journey cannot be revived or banked")
	# Newer journey than legacy vault (e.g. interrupted write order).
	m = fresh()
	legacy_vault(m, m.meta)
	m.start_battle(1)
	m.run.essence = 30
	defeat(m)
	m.buy_upgrade("vitality")
	legacy_journey(m)
	n = reload_pair(m)
	check(n.meta == m.meta and n.phase == "defeat", "Legacy newer journey brings its coherent profile forward")
	# Ambiguous currency-only or crossed-stat mismatches never use max Ash.
	m = fresh()
	legacy_journey(m)
	m.meta.essence = 7
	legacy_vault(m, m.meta)
	n = reload_pair(m)
	check(n.meta.essence == 7 and n.run.is_empty(), "Ambiguous legacy mismatch conservatively keeps standalone vault")

func _test_corruption() -> void:
	var m = fresh()
	check(m.save_meta(), "Saved earlier whole checkpoint")
	prepare_pending(m)
	var older: Dictionary = m.describe()
	m.persist_meta = true
	defeat(m)
	check(m.save_resume(m._resume_path), "Redundant ending checkpoint exists in both files")
	raw_write(m.meta_path, "{\"version\":2,\"payload\":".to_utf8_buffer())
	var n = reload_pair(m)
	check(n.meta.essence == 18 and n.phase == "defeat" and n._settled, "Corrupt vault recovers complete latest journey without losing settlement")
	check(n.recovery_status == "recovered", "Corrupt-file recovery is surfaced")
	raw_write(m._resume_path, PackedByteArray([0, 1, 2]))
	n = reload_pair(m)
	check(n.describe() == older and n.meta.runs == 0, "If both newest files are lost, fallback rolls back both journey and vault together")
	check(n.recovery_status == "recovered" and "repeated" in n.recovery_message, "Fallback warns that recent actions may be repeated")
	# Truncated/checksum-tampered primary with no usable other file.
	m = fresh()
	check(m.save_resume(m._resume_path), "Initial standalone snapshot")
	m.act(0, 3) # Rejected outside battle, state remains a valid map.
	check(m.save_resume(m._resume_path), "Created last-good backup")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(m._resume_path)
	raw_write(m._resume_path, bytes.slice(0, bytes.size() / 2))
	n = reload_pair(m)
	check(n.phase == "map" and n.recovery_status == "recovered", "Truncation recovers validated backup")
	var envelope = JSON.parse_string(bytes.get_string_from_utf8())
	envelope.sha256 = "0".repeat(64)
	raw_write(m._resume_path, JSON.stringify(envelope).to_utf8_buffer())
	n = reload_pair(m)
	check(n.phase == "map" and n.recovery_status == "recovered", "Checksum mismatch recovers backup")
	# Garbage without backup is rejected without changing live gameplay.
	m = fresh()
	var before: Dictionary = m.describe()
	raw_write(m._resume_path, PackedByteArray([1, 2, 3, 4, 5]))
	check(not m.load_resume(m._resume_path) and m.describe() == before, "Malformed binary is rejected without partial mutation")
	check(m.recovery_status == "corrupt", "Unrecoverable snapshot failure has a visible status")

func _test_failed_writes() -> void:
	for failure: String in ["write", "backup_write", "backup_commit", "commit"]:
		var m = fresh()
		check(m.save_meta(), "Baseline checkpoint before injected " + failure)
		prepare_pending(m)
		var previous: PackedByteArray = FileAccess.get_file_as_bytes(m.meta_path)
		m.fail_at = failure
		m.persist_meta = true
		defeat(m)
		check(m.save_status == "error" and "memory" in m.save_message, "Failed " + failure + " is not reported as saved")
		check(FileAccess.get_file_as_bytes(m.meta_path) == previous, "Failed " + failure + " leaves original committed file intact")
		var n = reload_pair(m)
		check(n.phase == "battle" and n.meta.essence == 0 and n.meta.runs == 0, "Uncommitted " + failure + " restores entire old checkpoint, ignoring tmp")
		m.fail_at = ""
		check(m.save_meta(), "Retry after " + failure + " commits in-memory settlement")
		n = reload_pair(m)
		check(n.phase == "defeat" and n.meta.essence == 18 and n.meta.runs == 1, "Retry after " + failure + " banks exactly once")
		check(m.save_status == "saved", "Successful retry clears saving-error status")
	# An actual unwritable target directory fails without a simulated hook.
	var m = fresh()
	m.meta_path = ROOT + "missing-parent/vault.json"
	check(not m.save_meta() and m.save_status == "error", "Actual file-open failure is reported")

func _test_validation() -> void:
	var m = fresh()
	m.start_battle(2)
	var valid: Dictionary = m._journey_snapshot()
	var invalid: Array[Dictionary] = []
	var s: Dictionary = valid.duplicate(true)
	s.heroes = [{}, {}, {}]
	invalid.append(s)
	s = valid.duplicate(true)
	s.heroes[0].skills = [{}, {}, {}, {}]
	invalid.append(s)
	s = valid.duplicate(true)
	s.intent.part = 99
	invalid.append(s)
	s = valid.duplicate(true)
	s.intent.targets = [99]
	invalid.append(s)
	s = valid.duplicate(true)
	s.run.node = 99
	invalid.append(s)
	s = valid.duplicate(true)
	s.campaign[0] = {}
	invalid.append(s)
	s = valid.duplicate(true)
	s.parts[0].erase("hp")
	invalid.append(s)
	s = valid.duplicate(true)
	s.rng_state = "broken"
	invalid.append(s)
	s = valid.duplicate(true)
	s.settled = true
	invalid.append(s)
	var before: Dictionary = m.describe()
	for snapshot: Dictionary in invalid:
		legacy_journey(m, snapshot)
		check(not m.load_resume(m._resume_path) and m.describe() == before, "Invalid nested legacy snapshot is rejected atomically")
	# Empty-key shape used to pass CP10's shallow validator.
	check(invalid.size() == 9, "Covers nine independently malformed nested fields")

func _test_exact_continuation() -> void:
	for tier: int in [1, 2, 3]:
		var m = fresh(9223372036854770000)
		m._milestone = true
		m.start_battle(tier)
		m.round_number = 2
		m._prepare_intent()
		m.act(0, 3)
		check(m.save_meta() and m.save_resume(m._resume_path), "Large-seed partial guard checkpoints at tier " + str(tier))
		var n = reload_pair(m)
		check(n.describe() == m.describe() and n.rng.seed == m.rng.seed and n.rng.state == m.rng.state, "Exact action, guard, prepared multi-source intent and 64-bit RNG at tier " + str(tier))
		check(n.preview_intent() == m.preview_intent(), "Recovered forecast is exact at tier " + str(tier))
		m.end_round()
		n.end_round()
		check(n.describe() == m.describe() and n.rng.state == m.rng.state, "Recovered next-round state/RNG is exact at tier " + str(tier))

func _test_minimum_seed() -> void:
	var m = fresh(-9223372036854775807 - 1)
	legacy_vault(m, m.meta)
	legacy_journey(m)
	var old = reload_pair(m)
	check(old.describe() == m.describe() and old.rng.seed == m.rng.seed, "Minimum signed-int64 seed remains a valid legacy journey")
	check(m.save_meta() and m.save_resume(m._resume_path), "Minimum signed-int64 seed saves without narrowing the API")
	var n = reload_pair(m)
	check(n.describe() == m.describe() and n.rng.seed == m.rng.seed, "Minimum signed-int64 seed resumes exactly")


func _test_all_phases() -> void:
	for current_phase: String in ["map", "camp", "event", "relic", "battle", "reward", "victory", "defeat"]:
		var m = fresh()
		if current_phase in ["camp", "event", "relic"]:
			m._open_event(current_phase)
		elif current_phase != "map":
			m.start_battle(2)
			m.act(0, 3)
			if current_phase in ["reward", "victory"]:
				m._win_battle()
			if current_phase == "victory":
				m.run.node = 8
				m.run.stage = 8
				m.choose_reward(0)
			elif current_phase == "defeat":
				defeat(m)
		legacy_vault(m, m.meta)
		legacy_journey(m)
		var old = reload_pair(m)
		check(old.describe() == m.describe() and old.rng.state == m.rng.state, "Version-1 compatibility at " + current_phase)
		check(m.save_meta() and m.save_resume(m._resume_path), "Complete transactions save at " + current_phase)
		var n = reload_pair(m)
		check(n.describe() == m.describe() and n.rng.state == m.rng.state, "Version-2 exact continuity at " + current_phase)

func _test_default_startup() -> void:
	# Run this mode only under a freshly created isolated XDG_DATA_HOME.
	# Refuse to touch an existing default save, even in a developer test run.
	for path: String in [Model.DEFAULT_META_PATH, Model.DEFAULT_RESUME_PATH]:
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			check(false, "Default-path test requires a fresh isolated XDG_DATA_HOME")
			return
	var m = Model.new()
	check(m.phase == "title" and m.run.is_empty(), "First launch starts cleanly")
	check(m.new_run(772), "First New Cycle commits complete state immediately")
	check(not FileAccess.file_exists(Model.DEFAULT_RESUME_PATH), "No UI refresh has created a journey file yet")
	var n = Model.new()
	check(n.phase == "title" and n.run.is_empty(), "Constructor restores profile only")
	check(n.load_resume() and n.describe() == m.describe(), "First cycle resumes from complete vault before first refresh")
	m.start_battle(1)
	m.run.essence = 30
	check(m.save_resume(), "Default path saves partial battle")
	defeat(m)
	n = Model.new()
	check(n.meta.essence == 30 and n.run.is_empty(), "Constructor sees newer settled profile without restoring gameplay")
	check(n.load_resume() and n.phase == "defeat" and n.meta.runs == 1, "Default startup recovers interrupted settlement")
	check(m.buy_upgrade("vitality"), "Default-path upgrade commits before refresh")
	n = Model.new()
	check(n.load_resume() and n.meta.essence == 18 and n.meta.upgrades.vitality == 1, "Default startup keeps purchased upgrade and spent Ash")
	m.new_run(123)
	n = Model.new()
	check(n.load_resume() and n.run.seed == 123 and n.heroes[0].max_hp == 83, "Default next-cycle startup uses complete replacement checkpoint")
	# Journey newer than vault must also update profile-only load_meta.
	m.persist_meta = false
	m.start_battle(1)
	m.run.essence = 9
	defeat(m)
	check(m.save_resume(), "Explicit journey-only save includes profile transaction")
	n = Model.new()
	check(n.meta.essence == 27 and n.meta.runs == 2 and n.run.is_empty(), "Profile-only default load selects newer journey's coherent vault")
	check(n.load_resume() and n.phase == "defeat" and n._settled, "Default resume then restores the same newer transaction")

func _test_revision_conflict() -> void:
	var m = fresh()
	check(m.save_meta(), "Saved source for equal-revision conflict")
	legacy_journey(m)
	var source: Dictionary = m._read_record(m.meta_path)
	var transaction: Dictionary = {"version": 2, "revision": source.revision, "meta": source.meta.duplicate(true), "journey": source.journey.duplicate(true)}
	transaction.meta.essence = 7
	transaction.journey.meta.essence = 7
	var bytes: PackedByteArray = var_to_bytes(transaction)
	var envelope: Dictionary = {"version": 2, "payload": Marshalls.raw_to_base64(bytes), "sha256": m._digest(bytes)}
	raw_write(m.meta_path + ".bak", JSON.stringify(envelope).to_utf8_buffer())
	var n = reader(m)
	var before: Dictionary = n.describe()
	check(not n.load_meta() and n.describe() == before and n.recovery_status == "conflict", "Profile-only load does not arbitrarily choose a conflicting revision")
	check(not n.load_resume(m._resume_path) and n.describe() == before, "Resume also rejects a conflicting revision without mutation")
	var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(m.meta_path)
	check(not m.save_meta() and m.save_status == "error" and m.recovery_status == "conflict", "Automatic saves cannot overwrite an unresolved split checkpoint")
	check(FileAccess.get_file_as_bytes(m.meta_path) == old_bytes, "Conflict leaves both original choices available for recovery")

func _test_unrestored_profile_save() -> void:
	for legacy: bool in [false, true]:
		var m = fresh()
		m.start_battle(2)
		m.act(0, 3)
		m.meta.essence = 30
		if legacy:
			legacy_vault(m, m.meta)
			legacy_journey(m)
		else:
			check(m.save_meta() and m.save_resume(m._resume_path), "Prepared v2 profile-only round trip")
		var n = reader(m)
		check(n.load_meta() and n.phase == "title" and n.run.is_empty(), "Profile-only load leaves journey unrestored")
		check(n.save_meta() and n.run.is_empty(), "Profile-only save preserves hidden checkpoint without restoring gameplay")
		check(n.load_resume(m._resume_path) and n.describe() == m.describe() and n.rng.state == m.rng.state, "load_meta/save_meta round trip cannot erase the saved journey or RNG")
		n = reader(m)
		n.load_meta()
		check(not n.buy_upgrade("vitality"), "Deferred resume is still an unfinished run, so between-run purchases are blocked")
		n.new_run(818)
		check(n.meta.runs == 1 and n.meta.essence == 30 and n.run.seed == 818, "New Cycle before explicit resume abandons cached unfinished journey exactly once")
	# A completed unrestored journey does permit between-run purchases.
	var m = fresh()
	m.start_battle(1)
	m.run.essence = 30
	defeat(m)
	check(m.save_meta() and m.save_resume(m._resume_path), "Prepared completed profile-only purchase")
	var n = reader(m)
	n.load_meta()
	n.persist_meta = true
	check(n.buy_upgrade("vitality") and n.run.is_empty(), "Profile-only purchase preserves deferred ending without restoring it")
	var loaded = reload_pair(n)
	check(loaded.phase == "defeat" and loaded.meta.essence == 18 and loaded.meta.upgrades.vitality == 1, "Profile-only upgrade commit keeps complete ending and spent balance")

func _test_stale_writer() -> void:
	var current = fresh()
	check(current.save_meta() and current.save_resume(current._resume_path), "Prepared shared complete profile")
	var stale = reload_pair(current)
	current.start_battle(1)
	current.act(0, 3)
	check(current.save_resume(current._resume_path), "Other instance advances the saved checkpoint")
	var vault_bytes: PackedByteArray = FileAccess.get_file_as_bytes(current.meta_path)
	var journey_bytes: PackedByteArray = FileAccess.get_file_as_bytes(current._resume_path)
	stale.run.gold += 999
	check(not stale.save_meta() and stale.recovery_status == "conflict", "Stale process cannot overwrite a newer valid revision")
	check(not stale.retry_save(), "Retry is not a force overwrite of another window")
	check(FileAccess.get_file_as_bytes(current.meta_path) == vault_bytes and FileAccess.get_file_as_bytes(current._resume_path) == journey_bytes, "Stale attempts preserve both saved copies byte-for-byte")
	check(stale.load_resume(stale._resume_path) and stale.describe() == current.describe(), "Explicit reload selects the newer complete state, not a currency merge")
	check(stale.retry_save(), "Reloaded instance can repair/checkpoint normally")
	check(reload_pair(stale).describe() == current.describe(), "No stale gold or earlier journey was resurrected")

func _test_repair_both_copies() -> void:
	for damaged_vault: bool in [true, false]:
		var m = fresh()
		check(m.save_meta() and m.save_resume(m._resume_path), "Prepared both copies for repair")
		raw_write(m.meta_path if damaged_vault else m._resume_path, "{damaged".to_utf8_buffer())
		var n = reload_pair(m)
		check(n.recovery_status == "recovered" and n.describe() == m.describe(), "One valid complete copy recovers the same gameplay")
		check(n.retry_save() and n.save_status == "saved", "Explicit retry repairs both paired primaries")
		check(not n._read_record(n.meta_path).is_empty() and not n._read_record(n._resume_path).is_empty(), "Both primaries are valid after retry")
		var again = reload_pair(n)
		check(again.recovery_status == "none" and again.describe() == n.describe(), "Following startup has no repeated damaged-copy warning")
