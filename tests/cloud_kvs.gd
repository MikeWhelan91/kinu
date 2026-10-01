extends Node

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	Save.save_path = "user://cloud_kvs_test_save.json"
	Save.load_data(Save.defaults())
	var service := CloudKvsService.new()
	add_child(service)
	var remote := Save.defaults()
	remote.best = 38
	remote.runs = 4
	remote.cloud_revision = 46
	remote.cloud_updated_at = 100.0
	var snapshot := {"format": 1, "save": remote}
	var inbox := FileAccess.open(CloudKvsService.INBOX, FileAccess.WRITE)
	inbox.store_string(JSON.stringify({"slots": [JSON.stringify(snapshot)]}))
	inbox.close()
	service._poll()
	check(int(Save.data.best) == 38 and int(Save.data.runs) == 4, "fresh install restores iCloud key-value snapshot")
	check(str(Save.data.cloud_last_downloaded) != "", "restore records the download time")
	service._write_outbox()
	var outbox: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CloudKvsService.OUTBOX))
	check(int(outbox.save.best) == 38, "cloud outbox contains restored progress")
	check(not outbox.save.has("backend_session") and not outbox.save.has("debug_unlocked"), "outbox omits private local fields")
	var restored_at := str(Save.data.cloud_last_downloaded)
	var echoed := Save.cloud_snapshot()
	echoed.save.cloud_revision = int(Save.data.cloud_revision) + 3
	var echoed_inbox := FileAccess.open(CloudKvsService.INBOX, FileAccess.WRITE)
	echoed_inbox.store_string(JSON.stringify({"slots": [JSON.stringify(echoed)]}))
	echoed_inbox.close()
	service._poll()
	check(service._candidate.is_empty() and str(Save.data.cloud_last_downloaded) == restored_at, "same progress echoed by iCloud is not restored again")
	Save.data.best = 45
	Save.data.runs = 5
	Save.persist()
	service._poll()
	check(int(Save.data.best) == 45, "older cloud snapshot does not replace newer local progress")
	for path in [CloudKvsService.INBOX, CloudKvsService.OUTBOX, CloudKvsService.STATUS, Save.save_path, Save.save_path + ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("iCloud key-value checks: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
