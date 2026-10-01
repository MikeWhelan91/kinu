class_name GameCenterService
extends RefCounted
signal cloud_restored
signal cloud_status_changed
# Thin wrapper around the GodotApplePlugins GameCenter extension
# (addons/GodotApplePluginsGameCenter, addons/GodotApplePluginsRuntime).
# Every native class is resolved by name through ClassDB rather than a static
# GDScript type, so this file parses fine on every platform - the editor, the
# headless test suite - even where the extension isn't bundled at all.
# `available` is the only thing callers need to check.
const LEADERBOARD_IDS := {
	"classic": "kinu.leaderboard",
	"tower": "tower",
	"toss": "kinu.toss",
}
# GKLeaderboard.PlayerScope.GLOBAL / TimeScope.ALL_TIME, mirrored here so this
# file never needs the GKLeaderboard type to read its constants.
const SCOPE_GLOBAL := 0
const TIME_SCOPE_ALL_TIME := 2

var available := false
var authenticated := false
var manager: Object
var app: Node
const CLOUD_NAME := "kinu-progress-v1"
const CLOUD_DIAGNOSTIC_READ_ONLY := false
var _cloud_ready := false
var _fetching := false
var _uploading := false
var _upload_queued := false
var _cloud_candidate: Dictionary = {}
var _saved_games: Array = []
var _found_cloud_file := false
var _best_snapshot: Dictionary = {}
var _best_rank: Vector2 = Vector2.ZERO
var _debounce_id := 0
var _last_queued_revision := -1
var _conflicting_games: Array = []
var _listener_registered := false
var _cloud_error := ""
var _fetch_start_revision := 0
var _requires_choice := false
var _creating_first_backup := false
var _cloud_file_missing := false
var _cloud_probe_names: Array[String] = []
var _cloud_probe_candidates: Array[Dictionary] = []

func _init() -> void:
	Save.changed.connect(_on_local_save)
	# The extension also ships macOS binaries so it can load in-editor without
	# erroring, but Game Center itself is only wired up for real iOS builds.
	available = OS.get_name() == "iOS" and ClassDB.class_exists("GameCenterManager")
	if not available: return
	manager = ClassDB.instantiate("GameCenterManager")
	manager.connect("authentication_result", _on_authentication_result)
	manager.connect("authentication_error", _on_authentication_error)

func authenticate() -> void:
	if not available: return
	manager.call("authenticate")

func _on_authentication_result(status: bool) -> void:
	authenticated = status
	cloud_status_changed.emit()
	if status:
		var player: Object = manager.get("local_player")
		if player != null and not _listener_registered and player.has_signal("conflicting_saved_games"):
			player.connect("conflicting_saved_games", _on_conflicting_saved_games)
			player.call("register_listener")
			_listener_registered = true
		fetch_cloud_save()
	else:
		_cloud_ready = false
		cloud_status_changed.emit()

func _on_authentication_error(message: String) -> void:
	push_warning("Game Center authentication error: " + message)
	_cloud_error = TranslationServer.translate("Sign in to Game Center to use iCloud saves.")
	cloud_status_changed.emit()

func cloud_status() -> String:
	if not available:
		return TranslationServer.translate("iCloud saves are available in the iPhone app.")
	if not authenticated:
		return TranslationServer.translate("Sign in to Game Center and turn on iCloud Drive to back up progress.")
	if _fetching:
		return TranslationServer.translate("Checking iCloud for your save…")
	if _requires_choice:
		var remote: Dictionary = _cloud_candidate.get("save", {})
		return TranslationServer.translate("Choose which progress to keep.\nThis iPhone: Best %d · %d runs\niCloud: Best %d · %d runs") % [int(Save.data.best), int(Save.data.runs), int(remote.get("best", 0)), int(remote.get("runs", 0))]
	if not _cloud_candidate.is_empty():
		return TranslationServer.translate("iCloud progress is ready. Return Home to restore it.")
	if not _cloud_error.is_empty():
		return _cloud_error
	if _cloud_file_missing:
		return TranslationServer.translate("No Game Center iCloud save was found. Progress is only on this iPhone. Back Up Now will create a new cloud save.")
	if _uploading:
		return TranslationServer.translate("Backing up to iCloud…")
	if _upload_queued:
		return TranslationServer.translate("Waiting to back up recent progress…")
	if str(Save.data.get("cloud_last_uploaded", "")) != "":
		return TranslationServer.translate("Backup sent to Game Center iCloud.")
	return TranslationServer.translate("Waiting for the first iCloud backup…")

func cloud_transfer_history() -> String:
	var downloaded := str(Save.data.get("cloud_last_downloaded", ""))
	var uploaded := str(Save.data.get("cloud_last_uploaded", ""))
	return TranslationServer.translate("Last downloaded: %s\nLast backed up: %s") % [downloaded if downloaded != "" else TranslationServer.translate("Never"), uploaded if uploaded != "" else TranslationServer.translate("Never")]

## Transfer history stays on this iPhone; it must not make a new cloud revision or be
## copied into the cloud save itself.
func _record_transfer(key: String) -> void:
	var previous := str(Save.data.get(key, ""))
	Save.data[key] = Time.get_datetime_string_from_system().replace("T", " ")
	if not Save.persist():
		Save.data[key] = previous

func _write_cloud_probe(details: Dictionary) -> void:
	var file := FileAccess.open("user://cloud_probe.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(details))
		file.close()

func back_up_now() -> void:
	if not authenticated:
		return
	if _cloud_file_missing:
		if not Save.cloud_has_progress(Save.data):
			_cloud_error = TranslationServer.translate("There is no progress to back up yet. If you expected an older save, do not create a new one.")
			cloud_status_changed.emit()
			return
		_creating_first_backup = true
		fetch_cloud_save()
		return
	if not _cloud_ready:
		fetch_cloud_save()
		return
	_upload_queued = true
	_last_queued_revision = int(Save.data.cloud_revision)
	_upload_cloud_save()

func has_cloud_conflict() -> bool:
	return _requires_choice

func choose_icloud_save() -> void:
	if not _requires_choice or _cloud_candidate.is_empty():
		return
	_requires_choice = false
	_fetch_start_revision = int(Save.data.cloud_revision)
	if is_instance_valid(app):
		app.call("_home")
	maybe_restore_cloud_save()

func choose_device_save() -> void:
	if not _requires_choice:
		return
	_requires_choice = false
	_cloud_candidate = {}
	_cloud_ready = true
	_cloud_error = ""
	cloud_status_changed.emit()
	_resolve_cloud_conflicts()
	_queue_cloud_upload()

## Game Center's saved-game API stores this file in the player's iCloud account. A local save
## remains authoritative until the first fetch succeeds, so a fresh install cannot upload its
## defaults over a cloud save that is still downloading.
func fetch_cloud_save() -> void:
	if not available or not authenticated or _fetching or _uploading or _requires_choice:
		return
	var player: Object = manager.get("local_player")
	if player == null or not player.has_method("fetch_saved_games"):
		return
	_fetching = true
	_cloud_ready = false
	_cloud_file_missing = false
	_fetch_start_revision = int(Save.data.cloud_revision)
	_cloud_error = ""
	cloud_status_changed.emit()
	player.call("fetch_saved_games", func(games: Variant, error: Variant) -> void:
		if error != null or not games is Array:
			_write_cloud_probe({"stage": "fetch_error", "error": str(error)})
			_fetching = false
			_creating_first_backup = false
			_cloud_error = TranslationServer.translate("iCloud is unavailable. Your progress is still saved on this iPhone.")
			cloud_status_changed.emit()
			push_warning("iCloud save fetch failed: %s" % str(error))
			return
		_saved_games.clear()
		_found_cloud_file = false
		_best_snapshot.clear()
		_best_rank = Vector2.ZERO
		var game_names: Array[String] = []
		for game in games:
			if game != null:
				game_names.append(str(game.get("name")))
			if game != null and str(game.get("name")) == CLOUD_NAME:
				_found_cloud_file = true
				_saved_games.append(game)
		_cloud_probe_names = game_names
		_cloud_probe_candidates.clear()
		_write_cloud_probe({"stage": "fetched", "game_names": game_names, "matching_count": _saved_games.size(), "local_best": int(Save.data.best), "local_runs": int(Save.data.runs)})
		_load_next_cloud_game()
	)

func _load_next_cloud_game() -> void:
	if _saved_games.is_empty():
		_fetching = false
		_write_cloud_probe({"stage": "loaded", "game_names": _cloud_probe_names, "candidates": _cloud_probe_candidates, "conflicting_count": _conflicting_games.size(), "valid_snapshot": not _best_snapshot.is_empty(), "remote_best": int(_best_snapshot.get("save", {}).get("best", 0)), "remote_runs": int(_best_snapshot.get("save", {}).get("runs", 0))})
		_choose_cloud_save()
		return
	var game: Object = _saved_games.pop_front()
	var modification := float(game.get("modification_date"))
	game.call("load_data", func(bytes: PackedByteArray, error: Variant) -> void:
		if error == null:
			var snapshot: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if Save.cloud_snapshot_valid(snapshot):
				var saved: Dictionary = snapshot.save
				_cloud_probe_candidates.append({"valid": true, "best": int(saved.get("best", 0)), "runs": int(saved.get("runs", 0)), "revision": int(saved.get("cloud_revision", 0)), "modified": modification})
				var rank := Vector2(int(saved.get("cloud_revision", 0)), maxf(float(saved.get("cloud_updated_at", 0.0)), modification))
				if _best_snapshot.is_empty() or rank.x > _best_rank.x or (rank.x == _best_rank.x and rank.y > _best_rank.y):
					_best_snapshot = snapshot
					_best_rank = rank
			else:
				_cloud_probe_candidates.append({"valid": false, "modified": modification})
		else:
			_cloud_probe_candidates.append({"valid": false, "load_error": str(error), "modified": modification})
		_load_next_cloud_game()
	)

func _choose_cloud_save() -> void:
	if _best_snapshot.is_empty():
		if _found_cloud_file:
			_creating_first_backup = false
			_cloud_error = TranslationServer.translate("Your iCloud save could not be read. This iPhone's save is safe.")
			cloud_status_changed.emit()
			push_warning("iCloud save exists but could not be read; cloud upload is paused")
			return
		_cloud_file_missing = true
		if _creating_first_backup and Save.cloud_has_progress(Save.data):
			_creating_first_backup = false
			_cloud_file_missing = false
			_cloud_ready = true
			cloud_status_changed.emit()
			_queue_cloud_upload()
			return
		_creating_first_backup = false
		cloud_status_changed.emit()
		return
	_creating_first_backup = false
	_record_transfer("cloud_last_downloaded")
	var remote: Dictionary = _best_snapshot.save
	var local_has_progress := Save.cloud_has_progress(Save.data)
	var remote_has_progress := Save.cloud_has_progress(remote)
	var local_revision := int(Save.data.get("cloud_revision", 0))
	var remote_revision := int(remote.get("cloud_revision", 0))
	var remote_newer := remote_revision > local_revision or (remote_revision == local_revision and float(remote.get("cloud_updated_at", 0.0)) > float(Save.data.get("cloud_updated_at", 0.0)))
	var purchase_conflict := local_has_progress and remote_has_progress and (Save.local_has_new_purchases(remote) or Save.cloud_has_new_purchases(remote))
	if purchase_conflict or (local_has_progress and remote_has_progress and remote_newer and local_revision > _fetch_start_revision):
		_cloud_candidate = _best_snapshot
		_requires_choice = true
		cloud_status_changed.emit()
		return
	if remote_has_progress and (not local_has_progress or (remote_newer and not Save.local_has_new_purchases(remote))):
		_cloud_candidate = _best_snapshot
		maybe_restore_cloud_save()
	else:
		_cloud_ready = true
		cloud_status_changed.emit()
		_resolve_cloud_conflicts()
		_queue_cloud_upload()

## A run already under way is allowed to finish before cloud progress changes the local save.
func maybe_restore_cloud_save() -> void:
	if _cloud_candidate.is_empty() or _requires_choice:
		return
	if Save.cloud_has_progress(Save.data) and int(Save.data.cloud_revision) > _fetch_start_revision:
		_requires_choice = true
		cloud_status_changed.emit()
		return
	if is_instance_valid(app) and app.get("page") not in ["", "home"]:
		return
	var snapshot := _cloud_candidate
	_cloud_candidate = {}
	if Save.restore_cloud_snapshot(snapshot):
		_cloud_ready = true
		cloud_restored.emit()
		cloud_status_changed.emit()
		_resolve_cloud_conflicts()
		_queue_cloud_upload()
	else:
		_cloud_error = TranslationServer.translate("Your iCloud save could not be restored. This iPhone's save is safe.")
		cloud_status_changed.emit()
		push_warning("iCloud save could not be written locally; keeping the cloud copy untouched")

func _on_conflicting_saved_games(_player: Variant, games: Array) -> void:
	_conflicting_games = games
	if not _fetching and not _uploading:
		fetch_cloud_save()

func _resolve_cloud_conflicts() -> void:
	if CLOUD_DIAGNOSTIC_READ_ONLY:
		return
	if _conflicting_games.is_empty() or not _cloud_ready:
		return
	var player: Object = manager.get("local_player")
	if player == null or not player.has_method("resolve_conflicting_saved_games"):
		return
	var conflicts := _conflicting_games
	_conflicting_games = []
	player.call("resolve_conflicting_saved_games", conflicts, JSON.stringify(Save.cloud_snapshot()).to_utf8_buffer(), func(_games: Variant, error: Variant) -> void:
		if error != null:
			_conflicting_games = conflicts
			push_warning("iCloud save conflict resolution failed: %s" % str(error))
	)

func _on_local_save() -> void:
	if _cloud_ready and int(Save.data.cloud_revision) != _last_queued_revision:
		_queue_cloud_upload()

func _queue_cloud_upload() -> void:
	if CLOUD_DIAGNOSTIC_READ_ONLY:
		return
	if not _cloud_ready or not authenticated:
		return
	_last_queued_revision = int(Save.data.cloud_revision)
	_upload_queued = true
	cloud_status_changed.emit()
	_debounce_id += 1
	var this_id := _debounce_id
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.create_timer(2.0).timeout.connect(func() -> void:
		if this_id == _debounce_id:
			_upload_cloud_save()
	)

func _upload_cloud_save() -> void:
	if not _cloud_ready or not authenticated or _uploading or not _upload_queued:
		return
	var player: Object = manager.get("local_player")
	if player == null or not player.has_method("save_game_data"):
		return
	_upload_queued = false
	_uploading = true
	cloud_status_changed.emit()
	var revision := int(Save.data.cloud_revision)
	var payload := JSON.stringify(Save.cloud_snapshot()).to_utf8_buffer()
	player.call("save_game_data", payload, CLOUD_NAME, func(game: Variant, error: Variant) -> void:
		if error != null or game == null or not game.has_method("load_data"):
			_uploading = false
			_cloud_error = TranslationServer.translate("iCloud backup failed. Your progress is still saved on this iPhone.")
			cloud_status_changed.emit()
			push_warning("iCloud save upload failed or returned no saved game: %s" % str(error))
			if not _conflicting_games.is_empty():
				fetch_cloud_save()
			return
		game.call("load_data", func(read_bytes: PackedByteArray, read_error: Variant) -> void:
			_uploading = false
			if read_error != null or read_bytes != payload:
				_cloud_error = TranslationServer.translate("iCloud backup could not be verified. Your progress is still saved on this iPhone.")
				cloud_status_changed.emit()
				push_warning("iCloud save read-back failed: %s" % str(read_error))
				return
			_cloud_error = ""
			_record_transfer("cloud_last_uploaded")
			cloud_status_changed.emit()
			if int(Save.data.cloud_revision) != revision or _upload_queued:
				_queue_cloud_upload()
		)
	)

# Resolves the leaderboard for a released mode. Falling back to Classic keeps an old or
# malformed save from opening a non-existent Game Center board.
static func leaderboard_id(mode: String) -> String:
	return str(LEADERBOARD_IDS.get(mode, LEADERBOARD_IDS.classic))

# Posts a score to the selected mode's leaderboard. Silently does nothing if the
# player was never signed in - there is no offline queue, since a missed post
# here and there does not warrant one for a personal-best board.
func submit_score(mode: String, value: int) -> void:
	if not available or not authenticated: return
	var local_player: Object = manager.get("local_player")
	if local_player == null: return
	var board_id := leaderboard_id(mode)
	ClassDB.class_call_static("GKLeaderboard", "load_leaderboards", PackedStringArray([board_id]),
		func(leaderboards, error):
			if error or leaderboards.is_empty(): return
			leaderboards[0].call("submit_score", value, 0, local_player,
				func(submit_error):
					if submit_error: push_warning("Game Center score submit failed for %s: %s" % [board_id, submit_error]))
	)

# Presents Apple's native sheet for the mode selected on the home screen.
func show_leaderboard(mode: String) -> void:
	if not available: return
	ClassDB.class_call_static("GKGameCenterViewController", "show_leaderboard_time_period", leaderboard_id(mode), SCOPE_GLOBAL, TIME_SCOPE_ALL_TIME)
