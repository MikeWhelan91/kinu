class_name RewardService
extends Node
signal session_checked
## Minimal Supabase client for reward endpoints. The publishable key is intentionally public;
## the service-role key and database password remain only in Supabase's server environment.

const SESSION_KEY := "backend_session"
const AUTH_PATH := "/auth/v1/signup"
const REFRESH_PATH := "/auth/v1/token?grant_type=refresh_token"
const DAILY_PATH := "/functions/v1/daily-reward"
const INVENTORY_PATH := "/rest/v1/rpc/record_owned_items"
const INVENTORY_READ_PATH := "/rest/v1/rpc/get_owned_items"
const KEYCHAIN_INBOX := "user://reward_session_inbox.json"
const KEYCHAIN_CHECKED := "user://reward_session_checked"
var _session_busy := false
var _session_result := false

func configured() -> bool:
	return not str(ProjectSettings.get_setting("supabase/url", "")).strip_edges().is_empty() and not str(ProjectSettings.get_setting("supabase/publishable_key", "")).strip_edges().is_empty()

func daily_status() -> Dictionary:
	return await _daily_request("status")

func claim_daily() -> Dictionary:
	return await _daily_request("claim")

func time_status() -> Dictionary:
	return await _daily_request("time_status")

func claim_free_claw() -> Dictionary:
	return await _daily_request("claim_free_claw")

## One direct database RPC per changed collection (and once after launch). This does not spend
## an Edge Function invocation. The RPC uses auth.uid() and cannot write another player's rows.
func sync_inventory(item_keys: Array[String]) -> bool:
	if not configured() or not (await _ensure_session()):
		return false
	var response := await _inventory_request(item_keys)
	if int(response.get("status", 0)) == 401 and await _refresh_session():
		response = await _inventory_request(item_keys)
	return int(response.get("status", 0)) >= 200 and int(response.get("status", 0)) < 300

func _inventory_request(item_keys: Array[String]) -> Dictionary:
	var session: Dictionary = Save.data.get(SESSION_KEY, {})
	return await _request(INVENTORY_PATH, HTTPClient.METHOD_POST, {
		"apikey": _key(), "Authorization": "Bearer "+str(session.get("access_token", "")),
	}, {"p_items": item_keys})

## Returns only items recorded for this same anonymous reward account. An empty dictionary
## means the read failed; a successful account with no collection has an empty items array.
func owned_items() -> Dictionary:
	if not configured() or not (await _ensure_session()):
		return {}
	var response := await _owned_items_request()
	if int(response.get("status", 0)) == 401 and await _refresh_session():
		response = await _owned_items_request()
	return response.get("body", {}) if int(response.get("status", 0)) >= 200 and int(response.get("status", 0)) < 300 else {}

func _owned_items_request() -> Dictionary:
	var session: Dictionary = Save.data.get(SESSION_KEY, {})
	return await _request(INVENTORY_READ_PATH, HTTPClient.METHOD_POST, {
		"apikey": _key(), "Authorization": "Bearer "+str(session.get("access_token", "")),
	}, {})

func _daily_request(action: String) -> Dictionary:
	if not configured() or not (await _ensure_session()):
		return {}
	var session: Dictionary = Save.data.get(SESSION_KEY, {})
	var response := await _request(DAILY_PATH, HTTPClient.METHOD_POST, {
		"apikey": _key(), "Authorization": "Bearer "+str(session.get("access_token", "")),
	}, {"action": action})
	if int(response.get("status", 0)) == 401 and await _refresh_session():
		return await _daily_request(action)
	return response.get("body", {}) if int(response.get("status", 0)) >= 200 and int(response.get("status", 0)) < 300 else {}

func _ensure_session() -> bool:
	if _session_busy:
		await session_checked
		return _session_result
	_session_busy = true
	var result := await _ensure_session_once()
	_session_result = result
	_session_busy = false
	session_checked.emit()
	return result

func _ensure_session_once() -> bool:
	var session: Dictionary = Save.data.get(SESSION_KEY, {})
	if str(session.get("refresh_token", "")).is_empty() and OS.get_name() == "iOS":
		# The native Keychain bridge starts before Godot, but its first file write can
		# arrive after this node. Wait before creating a new anonymous reward account.
		for attempt in 40:
			var recovered := _read_keychain_session()
			if not recovered.is_empty():
				Save.data[SESSION_KEY] = recovered
				Save.persist()
				session = recovered
				break
			if FileAccess.file_exists(KEYCHAIN_CHECKED):
				break
			await get_tree().create_timer(0.25).timeout
	if not str(session.get("access_token", "")).is_empty() and float(session.get("expires_at", 0.0)) > Time.get_unix_time_from_system()+60.0:
		return true
	if not str(session.get("refresh_token", "")).is_empty():
		# A temporary refresh failure must never replace the player's account.
		return await _refresh_session()
	var response := await _request(AUTH_PATH, HTTPClient.METHOD_POST, {"apikey": _key()}, {})
	if int(response.get("status", 0)) < 200 or int(response.get("status", 0)) >= 300:
		return false
	return _save_session(response.get("body", {}))

func _read_keychain_session() -> Dictionary:
	if not FileAccess.file_exists(KEYCHAIN_INBOX):
		return {}
	var file := FileAccess.open(KEYCHAIN_INBOX, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("access_token", "") is String and parsed.get("refresh_token", "") is String and not str(parsed.access_token).is_empty() and not str(parsed.refresh_token).is_empty():
		return parsed
	return {}

func _refresh_session() -> bool:
	var session: Dictionary = Save.data.get(SESSION_KEY, {})
	var response := await _request(REFRESH_PATH, HTTPClient.METHOD_POST, {"apikey": _key()}, {"refresh_token": str(session.get("refresh_token", ""))})
	if int(response.get("status", 0)) < 200 or int(response.get("status", 0)) >= 300:
		return false
	return _save_session(response.get("body", {}))

func _save_session(body: Dictionary) -> bool:
	if str(body.get("access_token", "")).is_empty() or str(body.get("refresh_token", "")).is_empty():
		return false
	Save.data[SESSION_KEY] = {
		"access_token": str(body.access_token),
		"refresh_token": str(body.refresh_token),
		"expires_at": Time.get_unix_time_from_system()+float(body.get("expires_in", 3600)),
	}
	Save.persist()
	return true

func _request(path: String, method: HTTPClient.Method, headers: Dictionary, body: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)
	var list := PackedStringArray(["Content-Type: application/json"])
	for name in headers:
		list.append(str(name)+": "+str(headers[name]))
	var error := request.request(_url()+path, list, method, JSON.stringify(body))
	if error != OK:
		request.queue_free()
		return {}
	var completed: Array = await request.request_completed
	request.queue_free()
	if completed.size() < 4 or int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		return {}
	var parsed: Variant = JSON.parse_string(PackedByteArray(completed[3]).get_string_from_utf8())
	return {"status": int(completed[1]), "body": parsed if parsed is Dictionary else {}}

func _url() -> String:
	return str(ProjectSettings.get_setting("supabase/url", "")).strip_edges().trim_suffix("/")

func _key() -> String:
	return str(ProjectSettings.get_setting("supabase/publishable_key", "")).strip_edges()
