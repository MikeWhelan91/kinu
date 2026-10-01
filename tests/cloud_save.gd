extends Node

var failures: Array[String] = []

func check(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		push_error(reason)

func _ready() -> void:
	Save.save_path = "user://cloud_save_test.json"
	Save.data = Save.defaults()
	Save.data.best = 42
	Save.data.runs = 12
	Save.data.beans = 125
	Save.data.owned = ["outfit:ghost"]
	Save.data.backend_session = {"access_token": "private", "refresh_token": "private"}
	Save.data["purchases"] = {"transaction-1": {"product": "beans.bag", "beans": 100}}
	check(Save.persist(), "local save writes")
	var original_revision := int(Save.data.cloud_revision)
	Save.data.backend_session.access_token = "refreshed-private"
	check(Save.persist() and int(Save.data.cloud_revision) == original_revision, "session refresh does not make cloud progress newer")
	var snapshot := Save.cloud_snapshot()
	var encoded := JSON.stringify(snapshot)
	check(not encoded.contains("private"), "backend tokens stay off iCloud")
	check(encoded.contains("transaction-1"), "purchase ledger remains with restored balance")
	check(Save.cloud_snapshot_valid(JSON.parse_string(encoded)), "JSON cloud save validates")
	check(Save.cloud_has_progress(snapshot.save), "progress detection finds a played save")
	check(not Save.local_has_new_purchases(snapshot.save), "matching receipts do not block restore")
	Save.data = Save.defaults()
	Save.data.backend_session = {"access_token": "new-device", "refresh_token": "new-device"}
	check(Save.restore_cloud_snapshot(snapshot), "cloud save restores locally")
	check(Save.data.best == 42 and Save.data.runs == 12 and Save.data.beans == 125, "progress and currency restore")
	check(Save.data.owned.has("outfit:ghost"), "owned content restores")
	check(Save.data.backend_session.access_token == "new-device", "device session is preserved")
	check(int(Save.data.cloud_revision) == int(snapshot.save.cloud_revision), "restored copy keeps its cloud revision")
	var broken := {"format": 1, "save": {"version": 5}}
	check(not Save.cloud_snapshot_valid(broken), "incomplete cloud saves are rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.save_path+".bak"))
	print("cloud save checks: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
