extends Node
## Sends a compact, idempotent ownership snapshot to Supabase. Only explicitly acquired
## cosmetics count; the debug unlock switch never adds entries to Save.data.owned.

var _timer: Timer
var _key_pattern := RegEx.new()
var _last_sent := ""
var _busy := false
var _queued := false
var _restored := false
var _remote_owned: Dictionary = {}

func _ready() -> void:
	if not Rewards.configured():
		return
	_key_pattern.compile("^(outfit|part|box|room):[a-z0-9_]+$")
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_flush)
	add_child(_timer)
	Save.changed.connect(_schedule)
	# Reconcile server-owned items before reporting the local collection. This lets the same
	# reward account recover cosmetics after reinstall without replacing other save fields.
	call_deferred("_restore_then_schedule")

func _schedule() -> void:
	if not _restored:
		return
	if _busy:
		_queued = true
	elif is_instance_valid(_timer):
		_timer.start(2.0)

func _owned_keys() -> Array[String]:
	var unique: Dictionary = {}
	for value in Save.data.owned:
		if value is String and _key_pattern.search(value) != null:
			unique[value] = true
	var keys: Array[String] = []
	for key in unique:
		keys.append(str(key))
	keys.sort()
	return keys

func _restore_then_schedule() -> void:
	if _busy or _restored:
		return
	_busy = true
	var response: Dictionary = await Rewards.owned_items()
	_busy = false
	if not response.has("items") or not response.items is Array:
		_timer.start(60.0)
		return
	var added := false
	for key in response.items:
		if key is String and _key_pattern.search(key) != null:
			_remote_owned[key] = true
			if not Save.data.owned.has(key):
				Save.data.owned.append(key)
				added = true
	if added:
		if not Save.persist():
			_timer.start(60.0)
			return
	_restored = true
	_schedule()

func _flush() -> void:
	if not _restored:
		_restore_then_schedule()
		return
	if _busy:
		_queued = true
		return
	# An iCloud save chosen later in this session may predate the Supabase collection.
	# Preserve this account's permanent items when that full save replaces Save.data.
	var added := false
	for key in _remote_owned:
		if not Save.data.owned.has(key):
			Save.data.owned.append(key)
			added = true
	if added and not Save.persist():
		_timer.start(60.0)
		return
	var keys := _owned_keys()
	var fingerprint := JSON.stringify(keys)
	if fingerprint == _last_sent:
		return
	_busy = true
	var synced: bool = await Rewards.sync_inventory(keys)
	_busy = false
	if synced:
		_last_sent = fingerprint
		for key in keys:
			_remote_owned[key] = true
	else:
		# A network failure must not affect the save. Try again later while the app is open.
		_timer.start(60.0)
	if _queued:
		_queued = false
		_schedule()
