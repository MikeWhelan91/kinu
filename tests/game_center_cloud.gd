extends Node

class FakeSavedGame extends RefCounted:
	var name := GameCenterService.CLOUD_NAME
	var modification_date := 10.0
	var bytes: PackedByteArray

	func load_data(done: Callable) -> void:
		done.call(bytes, null)

class FakePlayer extends RefCounted:
	var games: Array = []
	var uploaded: PackedByteArray
	var fetch_error: Variant = null

	func fetch_saved_games(done: Callable) -> void:
		done.call(games, fetch_error)

	func save_game_data(bytes: PackedByteArray, _name: String, done: Callable) -> void:
		uploaded = bytes
		var game := FakeSavedGame.new()
		game.bytes = bytes
		done.call(game, null)

class FakeManager extends RefCounted:
	var local_player: FakePlayer

var failures: Array[String] = []

func check(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		push_error(reason)

func _ready() -> void:
	Save.save_path = "user://game_center_cloud_test.json"
	Save.load_data(Save.defaults())
	var cloud_data := Save.defaults()
	cloud_data.best = 31
	cloud_data.runs = 7
	cloud_data.cloud_revision = 8
	cloud_data.cloud_updated_at = 100.0
	var game := FakeSavedGame.new()
	game.bytes = JSON.stringify({"format": 1, "save": cloud_data}).to_utf8_buffer()
	var player := FakePlayer.new()
	player.games = [game]
	var manager := FakeManager.new()
	manager.local_player = player
	var service := GameCenterService.new()
	service.available = true
	service.manager = manager
	service._on_authentication_result(true)
	check(Save.data.best == 31 and Save.data.runs == 7, "fresh install restores before first upload")
	check(str(Save.data.cloud_last_downloaded) != "", "successful iCloud download records a local timestamp")
	check(player.uploaded.is_empty(), "default save did not overwrite cloud during fetch")
	await get_tree().create_timer(2.2).timeout
	check(not player.uploaded.is_empty(), "restored save uploads after local write")
	check(str(Save.data.cloud_last_uploaded) != "", "successful iCloud backup records a local timestamp")
	var local_copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.save_path))
	check(str(local_copy.get("cloud_last_downloaded", "")) != "" and str(local_copy.get("cloud_last_uploaded", "")) != "", "transfer timestamps survive relaunch")
	if not player.uploaded.is_empty():
		var uploaded: Dictionary = JSON.parse_string(player.uploaded.get_string_from_utf8())
		check(int(uploaded.save.best) == 31, "cloud upload contains restored progress")
		check(not uploaded.save.has("cloud_last_downloaded") and not uploaded.save.has("cloud_last_uploaded"), "local transfer history stays off iCloud")
	Save.data.best = 9
	Save.data["purchases"] = {"new-local-purchase": {"product": "beans.bag", "beans": 100}}
	Save.persist()
	var buyer := FakePlayer.new()
	buyer.games = [game]
	var buyer_manager := FakeManager.new()
	buyer_manager.local_player = buyer
	var buyer_service := GameCenterService.new()
	buyer_service.available = true
	buyer_service.manager = buyer_manager
	buyer_service._on_authentication_result(true)
	check(Save.data.best == 9, "a new local purchase prevents automatic replacement by older cloud receipts")
	check(buyer_service.has_cloud_conflict(), "purchase divergence asks the player to choose")
	buyer_service.choose_device_save()
	check(not buyer_service.has_cloud_conflict(), "choosing the iPhone resolves the conflict")
	var broken_game := FakeSavedGame.new()
	broken_game.bytes = "not-json".to_utf8_buffer()
	var broken_player := FakePlayer.new()
	broken_player.games = [broken_game]
	var broken_manager := FakeManager.new()
	broken_manager.local_player = broken_player
	var broken_service := GameCenterService.new()
	broken_service.available = true
	broken_service.manager = broken_manager
	broken_service._on_authentication_result(true)
	await get_tree().create_timer(2.2).timeout
	check(broken_player.uploaded.is_empty(), "unreadable cloud data is never replaced with local defaults")
	Save.load_data(Save.defaults())
	Save.data.best = 38
	Save.data.runs = 4
	Save.data.cloud_revision = 10
	Save.persist()
	var blank_cloud := Save.defaults()
	blank_cloud.cloud_revision = 100
	var blank_game := FakeSavedGame.new()
	blank_game.bytes = JSON.stringify({"format": 1, "save": blank_cloud}).to_utf8_buffer()
	var blank_player := FakePlayer.new()
	blank_player.games = [blank_game]
	var blank_manager := FakeManager.new()
	blank_manager.local_player = blank_player
	var blank_service := GameCenterService.new()
	blank_service.available = true
	blank_service.manager = blank_manager
	blank_service._on_authentication_result(true)
	check(int(Save.data.best) == 38 and int(Save.data.runs) == 4, "empty Game Center save never replaces local progress even with a higher revision")
	Save.load_data(Save.defaults())
	var empty_player := FakePlayer.new()
	var empty_manager := FakeManager.new()
	empty_manager.local_player = empty_player
	var empty_service := GameCenterService.new()
	empty_service.available = true
	empty_service.manager = empty_manager
	empty_service._on_authentication_result(true)
	await get_tree().create_timer(2.2).timeout
	check(empty_player.uploaded.is_empty(), "empty iCloud fetch never uploads a fresh install's defaults")
	check(not empty_service._cloud_ready, "empty iCloud fetch pauses automatic uploads")
	Save.data.best = 4
	Save.data.runs = 1
	Save.persist()
	await get_tree().create_timer(2.2).timeout
	check(empty_player.uploaded.is_empty(), "local progress does not overwrite a missing iCloud save automatically")
	empty_service.back_up_now()
	await get_tree().create_timer(2.2).timeout
	check(not empty_player.uploaded.is_empty(), "explicit Back Up Now creates the first cloud save after another fetch")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.save_path+".bak"))
	print("Game Center cloud checks: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
