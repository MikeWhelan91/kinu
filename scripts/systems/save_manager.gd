extends Node
signal changed
const PATH := "user://nest_save.json"
var data: Dictionary = {}
var save_path: String = PATH

## How many past piles the Records chart remembers.
const RECENT_RUNS := 10

func _ready() -> void:
	load_data()

func defaults() -> Dictionary:
	return {"version": 3, "best": 0, "best_height": 0.0, "discovered": [], "music": 0.55, "sfx": 0.8, "haptics": true, "tutorial": false, "runs": 0, "outfit": "", "controls": "classic", "claw_hand": "right", "beans": 0, "owned": [], "box": "hinoki", "room": "shop", "excluded_flavours": [], "debug_unlocked": false, "seen_specials": [], "fresh": [], "language": "", "stats": {"total": 0, "clean": 0, "lucky": 0, "missions": 0, "piled": 0, "tumbles": 0, "hearts": 0, "streak": 0, "spins": 0, "beans_earned": 0, "bonus_beans": 0, "beans_spent": 0, "time": 0, "longest_time": 0, "squirts": 0, "glazed": 0, "day_streak": 0, "best_day_streak": 0}, "daily": {}, "first_played": "", "last_played": "", "flavour_counts": {}, "shape_counts": {}, "outfit_best": {}, "room_best": {}, "recent": []}

func load_data() -> void:
	data = defaults()
	var loaded: Variant = _read(save_path)
	if not loaded is Dictionary:
		loaded = _read(save_path + ".bak")
	if loaded is Dictionary:
		for key in data:
			if key == "version":
				continue
			if not loaded.has(key):
				continue
			var value: Variant = loaded[key]
			match key:
				"best", "runs", "beans":
					if (value is float or value is int) and is_finite(float(value)):
						data[key] = clampi(int(value), 0, 2147483647)
				"best_height":
					if (value is float or value is int) and is_finite(float(value)):
						data[key] = clampf(float(value), 0, 10000)
				"music", "sfx":
					if (value is float or value is int) and is_finite(float(value)):
						data[key] = clampf(float(value), 0, 1)
				"haptics", "tutorial", "debug_unlocked":
					if value is bool:
						data[key] = value
				"language":
					if value in ["", "en", "ja", "ko", "zh_TW"]:
						data[key] = value
				"outfit":
					if value is String:
						data[key] = value
				"controls":
					if value in ["classic", "grab", "claw"]:
						data[key] = value
				"claw_hand":
					if value in ["right", "left"]:
						data[key] = value
				"owned":
					if value is Array:
						for item in value:
							if item is String and not data.owned.has(item):
								data.owned.append(item)
				"box", "room":
					if value is String and value != "":
						data[key] = value
				"seen_specials", "fresh":
					if value is Array:
						for item in value:
							if item is String and not data[key].has(item):
								data[key].append(item)
				"excluded_flavours":
					if value is Array:
						for item in value:
							if item is String and not data.excluded_flavours.has(item):
								data.excluded_flavours.append(item)
				"stats":
					if value is Dictionary:
						for stat in data.stats:
							var number: Variant = value.get(stat, 0)
							if (number is float or number is int) and is_finite(float(number)):
								data.stats[stat] = clampi(int(number), 0, 2147483647)
				"first_played", "last_played":
					if value is String:
						data[key] = value
				"flavour_counts", "shape_counts", "outfit_best", "room_best":
					if value is Dictionary:
						for id in value:
							var count: Variant = value[id]
							if id is String and (count is float or count is int) and is_finite(float(count)):
								data[key][id] = clampi(int(count), 0, 2147483647)
				"recent":
					if value is Array:
						for score in value.slice(-RECENT_RUNS):
							if (score is float or score is int) and is_finite(float(score)):
								data.recent.append(clampi(int(score), 0, 2147483647))
				"daily":
					if value is Dictionary and value.get("day") is String and value.get("missions") is Array:
						data.daily = value
				"discovered":
					if value is Array:
						for item in value:
							if item is String and not data.discovered.has(item):
								data.discovered.append(item)
		# Early shop builds stored outfits separately.
		if loaded.get("owned_outfits") is Array:
			for item in loaded.owned_outfits:
				if item is String and not data.owned.has("outfit:"+item):
					data.owned.append("outfit:"+item)
		# Version 2 recorded the best as a tower height in cm; from version 3 it is Kinu on the pile.
		# Flavour goals moved from cm to a tenth as many Kinu, so the same flavours stay unlocked.
		if int(loaded.get("version", 1)) == 2:
			data.best = int(data.best)/10
		# Store IDs stay strings: JSON numbers cannot safely preserve every Apple transaction ID.
		if loaded.get("purchases") is Dictionary:
			data["purchases"] = loaded.purchases.duplicate(true)
		data["ads_removed"] = loaded.get("ads_removed", false) == true
		data["ads_entitlement_date"] = float(loaded.get("ads_entitlement_date", 0.0))

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

func persist() -> bool:
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	# Never replace the last valid backup with a corrupted main file.
	if _read(save_path) is Dictionary:
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	var error := DirAccess.rename_absolute(temp, save_path)
	if error == OK:
		changed.emit()
	return error == OK

## Atomically save both the balance and delivery receipt before acknowledging Apple.
## Returns -1 on save failure, 0 for a replay, and 1 for a newly applied transaction.
func apply_store_transaction(id: String, product: String, beans: int, revoked: bool, date: float, remove_ads: bool) -> int:
	if id.is_empty() or product.is_empty():
		return -1
	var before := data.duplicate(true)
	var receipts: Dictionary = data.get("purchases", {}).duplicate(true)
	var previous: Dictionary = receipts.get(id, {})
	if not previous.is_empty() and (bool(previous.get("revoked", false)) or not revoked):
		return 0
	if revoked:
		if not previous.is_empty():
			data.beans = maxi(0, int(data.beans)-int(previous.get("beans", 0)))
	else:
		data.beans = int(data.beans)+beans
	receipts[id] = {"product": product, "beans": beans, "revoked": revoked}
	data["purchases"] = receipts
	if remove_ads and date >= float(data.get("ads_entitlement_date", 0.0)):
		data["ads_removed"] = not revoked
		data["ads_entitlement_date"] = date
	if not persist():
		data = before
		return -1
	# Keep the recovery copy current with paid deliveries, not the pre-purchase balance.
	DirAccess.copy_absolute(save_path, save_path+".bak")
	return 1

func discover(id: String) -> bool:
	if data.discovered.has(id):
		return false
	data.discovered.append(id)
	if not debug_unlocked():
		mark_fresh("flavour:"+id)
	persist()
	return true

## Unlocks the player hasn't looked at yet, by "kind:id" ("flavour:yuzu", "outfit:scarf"...).
## They show as red counts on the Kinu Book until the item is tapped.
func mark_fresh(key: String) -> void:
	if not data.fresh.has(key):
		data.fresh.append(key)

func is_fresh(key: String) -> bool:
	return data.fresh.has(key)

## How many unseen unlocks start with `prefix` ("" for all of them, "flavour:" for flavours).
func fresh_count(prefix: String = "") -> int:
	# Older saves may contain flavour keys recorded when a spawn threshold was reached, before the
	# player actually found that flavour. A hidden ??? card is not something the player has seen.
	return data.fresh.filter(func(key: String) -> bool:
		return key.begins_with(prefix) and (not key.begins_with("flavour:") or data.discovered.has(key.trim_prefix("flavour:")))
	).size()

func clear_fresh(key: String) -> void:
	if data.fresh.has(key):
		data.fresh.erase(key)
		persist()

## Leaving the Kinu Book marks its complete contents as read in one save operation.
func clear_all_fresh() -> void:
	if data.fresh.is_empty():
		return
	data.fresh.clear()
	persist()

func setting(key: String, value: Variant) -> void:
	if key in ["music", "sfx", "haptics", "tutorial", "controls", "claw_hand", "outfit", "box", "room", "debug_unlocked", "language"]:
		data[key] = value
		persist()

func add_beans(amount: int) -> void:
	data.beans = maxi(0, int(data.beans)+amount)
	persist()

## Beans won by playing (runs and daily missions), counted for the Records page. Purchases aren't.
func add_earned_beans(amount: int) -> void:
	data.stats.beans_earned = int(data.stats.beans_earned)+maxi(0, amount)
	add_beans(amount)

## kind is "outfit", "box" or "room". Free items (price 0 or no outfit) are always owned.
func owns(kind: String, id: String, price: int = 1) -> bool:
	if debug_unlocked() or id == "":
		return true
	if KinuProgress.is_earned_item(kind, id):
		return KinuProgress.met(KinuProgress.goals[kind+":"+id])
	return price <= 0 or data.owned.has(kind+":"+id)

## Test switch for development builds only: everything counts as unlocked, found and owned.
## Beans and best pile are untouched, so switching it off restores normal progress.
func debug_unlocked() -> bool:
	return OS.is_debug_build() and bool(data.get("debug_unlocked", false))

func flavour_unlocked(flavour: KinuFlavour) -> bool:
	return debug_unlocked() or int(data.best) >= flavour.unlock_kinu

func flavour_found(flavour: KinuFlavour) -> bool:
	return flavour_unlocked(flavour) and (debug_unlocked() or data.discovered.has(flavour.id))

func flavour_in_mix(id: String) -> bool:
	return not data.excluded_flavours.has(id)

func set_flavour_in_mix(id: String, included: bool) -> void:
	if included:
		data.excluded_flavours.erase(id)
	elif not data.excluded_flavours.has(id):
		data.excluded_flavours.append(id)
	persist()

## Spends soybeans on a shop item and equips it where that makes sense. False if unaffordable.
func buy(kind: String, id: String, price: int) -> bool:
	if KinuProgress.is_earned_item(kind, id) and not owns(kind, id, price):
		return false
	if not owns(kind, id, price):
		if int(data.beans) < price:
			return false
		data.beans = int(data.beans)-price
		data.stats.beans_spent = int(data.stats.beans_spent)+price
		data.owned.append(kind+":"+id)
	if kind in ["outfit", "box", "room"]:
		data[kind] = id
		if kind == "room":
			Sound.play_room_music(id)
	persist()
	return true

## Records a finished run: best pile and height, lifetime stats and daily mission progress.
func finish_run(summary: Dictionary) -> bool:
	var score := int(summary.get("score", 0))
	var earned_before := KinuProgress.earned_keys()
	var record := score > int(data.best)
	data.best = maxi(score, int(data.best))
	data.best_height = maxf(float(summary.get("height", 0.0)), float(data.best_height))
	data.runs = int(data.runs) + 1
	data.stats.total = int(data.stats.total)+int(summary.get("placed", 0))
	data.stats.lucky = int(data.stats.lucky)+int(summary.get("lucky", 0))
	data.stats.piled = int(data.stats.piled)+score
	data.stats.tumbles = int(data.stats.tumbles)+int(summary.get("tumbles", 0))
	data.stats.hearts = int(data.stats.hearts)+int(summary.get("hearts", 0))
	data.stats.spins = int(data.stats.spins)+int(summary.get("turns", 0))
	data.stats.streak = maxi(int(data.stats.streak), int(summary.get("streak", 0)))
	data.stats.bonus_beans = int(data.stats.bonus_beans)+int(summary.get("bonus", 0))
	data.stats.squirts = int(data.stats.squirts)+int(summary.get("squirts", 0))
	data.stats.glazed = int(data.stats.glazed)+int(summary.get("glazed", 0))
	var seconds := int(summary.get("time", 0.0))
	data.stats.time = int(data.stats.time)+seconds
	data.stats.longest_time = maxi(int(data.stats.longest_time), seconds)
	_add_counts(data.flavour_counts, summary.get("flavours", {}))
	_add_counts(data.shape_counts, summary.get("shapes", {}))
	data.outfit_best[str(data.outfit)] = maxi(int(data.outfit_best.get(str(data.outfit), 0)), score)
	data.room_best[str(data.room)] = maxi(int(data.room_best.get(str(data.room), 0)), score)
	data.recent.append(score)
	data.recent = data.recent.slice(-RECENT_RUNS)
	_record_day()
	if int(summary.get("tumbles", 0)) == 0:
		data.stats.clean = maxi(int(data.stats.clean), score)
	KinuProgress.record_run(summary)
	if not debug_unlocked():
		for key in KinuProgress.earned_keys():
			if not earned_before.has(key):
				mark_fresh(key)
	persist()
	return record

static func _add_counts(into: Dictionary, counts: Variant) -> void:
	if counts is Dictionary:
		for id in counts:
			into[id] = int(into.get(id, 0))+int(counts[id])

## Days in a row with at least one finished run, by the device's local calendar.
func _record_day() -> void:
	var today := Time.get_date_string_from_system()
	if data.first_played == "":
		data.first_played = today
	if data.last_played == today:
		return
	var yesterday := Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(today)-86400)
	data.stats.day_streak = int(data.stats.day_streak)+1 if data.last_played == yesterday else 1
	data.stats.best_day_streak = maxi(int(data.stats.best_day_streak), int(data.stats.day_streak))
	data.last_played = today

## The current streak, or 0 once a whole day has passed without a run.
func day_streak() -> int:
	var today := Time.get_date_string_from_system()
	var yesterday := Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(today)-86400)
	return int(data.stats.day_streak) if data.last_played in [today, yesterday] else 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		persist()
