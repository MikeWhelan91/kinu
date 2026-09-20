class_name RewardService
extends Node
## Minimal Supabase client for reward endpoints. The publishable key is intentionally public;
## the service-role key and database password remain only in Supabase's server environment.

const SESSION_KEY := "backend_session"
const AUTH_PATH := "/auth/v1/signup"
const REFRESH_PATH := "/auth/v1/token?grant_type=refresh_token"
const DAILY_PATH := "/functions/v1/daily-reward"

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
	var session: Dictionary = Save.data.get(SESSION_KEY, {})
	if not str(session.get("access_token", "")).is_empty() and float(session.get("expires_at", 0.0)) > Time.get_unix_time_from_system()+60.0:
		return true
	if not str(session.get("refresh_token", "")).is_empty() and await _refresh_session():
		return true
	var response := await _request(AUTH_PATH, HTTPClient.METHOD_POST, {"apikey": _key()}, {})
	if int(response.get("status", 0)) < 200 or int(response.get("status", 0)) >= 300:
		return false
	return _save_session(response.get("body", {}))

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
