class_name CloudKvsService
extends Node

signal status_changed
signal restored

const INBOX := "user://cloud_kvs_inbox.json"
const OUTBOX := "user://cloud_kvs_outbox.json"
const STATUS := "user://cloud_kvs_status.json"

var app: Node
var _last_inbox := ""
var _last_outbox := ""
var _last_status := ""
var _native_status: Dictionary = {}
var _candidate: Dictionary = {}
var _requires_choice := false

func _ready() -> void:
	if OS.get_name() != "iOS":
		return
	Save.changed.connect(_write_outbox)
	_write_outbox()
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()
	_poll()

func status() -> String:
	if OS.get_name() != "iOS":
		return TranslationServer.translate("iCloud sync is available in the iPhone app.")
	if _native_status.is_empty():
		return TranslationServer.translate("Checking iCloud sync…")
	if not bool(_native_status.get("available", false)):
		return TranslationServer.translate("iCloud sync is unavailable. Progress is saved on this iPhone.")
	if _requires_choice:
		var remote: Dictionary = _candidate.get("save", {})
		return TranslationServer.translate("Choose which progress to keep.\nThis iPhone: Best %d · %d runs\niCloud: Best %d · %d runs") % [int(Save.data.best), int(Save.data.runs), int(remote.get("best", 0)), int(remote.get("runs", 0))]
	if not _candidate.is_empty():
		return TranslationServer.translate("iCloud progress is ready. Return Home to restore it.")
	var sent := float(_native_status.get("last_sent_at", 0.0))
	if sent > 0.0:
		var minutes_ago := maxi(0, int((Time.get_unix_time_from_system() - sent) / 60.0))
		var when: String = TranslationServer.translate("just now") if minutes_ago == 0 else TranslationServer.translate("1 minute ago") if minutes_ago == 1 else TranslationServer.translate("%d minutes ago") % minutes_ago
		return TranslationServer.translate("Progress sent to iCloud sync %s.") % when
	if int(_native_status.get("remote_slots", 0)) > 0:
		return TranslationServer.translate("iCloud has a game save. New progress will sync automatically.")
	return TranslationServer.translate("Waiting for the first iCloud sync.")

func transfer_history() -> String:
	var downloaded := str(Save.data.get("cloud_last_downloaded", ""))
	return TranslationServer.translate("Last restored from iCloud: %s") % (downloaded if downloaded != "" else TranslationServer.translate("Never"))

func has_conflict() -> bool:
	return _requires_choice

func choose_icloud_save() -> void:
	if not _requires_choice:
		return
	_requires_choice = false
	_try_restore(true)

func choose_device_save() -> void:
	if not _requires_choice:
		return
	var remote: Dictionary = _candidate.get("save", {})
	Save.data.cloud_revision = maxi(int(Save.data.cloud_revision), int(remote.get("cloud_revision", 0))) + 1
	Save.data.cloud_updated_at = Time.get_unix_time_from_system()
	Save.persist()
	_candidate = {}
	_requires_choice = false
	_write_outbox()
	status_changed.emit()

func sync_now() -> void:
	_write_outbox()
	_poll()

func _write_outbox() -> void:
	if not Save.cloud_has_progress(Save.data):
		return
	var body := JSON.stringify(Save.cloud_snapshot())
	if body == _last_outbox:
		return
	var file := FileAccess.open(OUTBOX, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(body)
	file.close()
	_last_outbox = body

func _poll() -> void:
	var status_text := FileAccess.get_file_as_string(STATUS) if FileAccess.file_exists(STATUS) else ""
	if status_text != _last_status:
		_last_status = status_text
		var parsed_status: Variant = JSON.parse_string(status_text)
		_native_status = parsed_status if parsed_status is Dictionary else {}
		status_changed.emit()
	var inbox_text := FileAccess.get_file_as_string(INBOX) if FileAccess.file_exists(INBOX) else ""
	if inbox_text != _last_inbox:
		_last_inbox = inbox_text
		var parsed: Variant = JSON.parse_string(inbox_text)
		if parsed is Dictionary and parsed.get("slots") is Array:
			var best: Dictionary = {}
			for raw in parsed.slots:
				if not raw is String:
					continue
				var snapshot: Variant = JSON.parse_string(raw)
				if not Save.cloud_snapshot_valid(snapshot):
					continue
				if best.is_empty() or _newer(snapshot.save, best.save):
					best = snapshot
			_candidate = best
			status_changed.emit()
	_try_restore()

func _newer(left: Dictionary, right: Dictionary) -> bool:
	var left_revision := int(left.get("cloud_revision", 0))
	var right_revision := int(right.get("cloud_revision", 0))
	return left_revision > right_revision or (left_revision == right_revision and float(left.get("cloud_updated_at", 0.0)) > float(right.get("cloud_updated_at", 0.0)))

func _same_progress(left: Dictionary, right: Dictionary) -> bool:
	var left_content := left.duplicate(true)
	var right_content := right.duplicate(true)
	for content in [left_content, right_content]:
		content.erase("cloud_revision")
		content.erase("cloud_updated_at")
	return JSON.stringify(left_content) == JSON.stringify(right_content)

func _try_restore(force := false) -> void:
	if _candidate.is_empty() or _requires_choice:
		return
	var remote: Dictionary = _candidate.save
	if not force:
		if _same_progress(remote, Save.cloud_snapshot().save):
			_candidate = {}
			status_changed.emit()
			return
		if not _newer(remote, Save.data):
			_candidate = {}
			status_changed.emit()
			return
		if Save.cloud_has_progress(Save.data) and (Save.local_has_new_purchases(remote) or Save.cloud_has_new_purchases(remote)):
			_requires_choice = true
			status_changed.emit()
			return
	if is_instance_valid(app) and app.get("page") not in ["", "home"]:
		return
	if not Save.restore_cloud_snapshot(_candidate):
		return
	Save.data.cloud_last_downloaded = Time.get_datetime_string_from_system().replace("T", " ")
	Save.persist()
	_candidate = {}
	_requires_choice = false
	_write_outbox()
	restored.emit()
	status_changed.emit()
