extends Node
signal changed
const PATH := "user://nest_save.json"
var data: Dictionary = {}
var save_path: String = PATH
var _last_cloud_content := ""

## How many past piles the Records chart remembers.
const RECENT_RUNS := 10

func _ready() -> void:
	load_data()

## Beans were restated in a larger unit at version 4: prices, prizes and rewards all moved by
## this factor together, so the change is one of units only and buys exactly what it did before.
const BEAN_REDENOMINATION := 5
## Goal rewards earned before the wardrobe pacing update remain owned after their targets rise.
const OLD_OUTFIT_GOALS := {
	"leaf": ["runs", 1], "astronaut": ["height", 350], "ghost": ["flavours", 10],
	"hatchling": ["total", 100], "parcel": ["best", 25], "builder": ["best", 10],
	"acrobat": ["clean", 8], "chef": ["glazed", 10], "yukata": ["streak", 8],
	"climber": ["height", 500], "daruma": ["clean", 31], "dragon": ["best", 62],
}

func defaults() -> Dictionary:
	return {"version": 6, "cloud_revision": 0, "cloud_updated_at": 0.0, "cloud_last_downloaded": "", "cloud_last_uploaded": "", "best": 0, "best_height": 0.0, "discovered": [], "music": 0.55, "sfx": 0.8, "haptics": true, "tutorial": false, "home_tour": false, "runs": 0, "outfit": "", "controls": "classic", "claw_hand": "right", "beans": 0, "tickets": 0, "owned": [], "box": "hinoki", "room": "shop", "excluded_flavours": [], "debug_unlocked": false, "seen_specials": [], "fresh": [], "language": "", "backend_session": {}, "stats": {"total": 0, "clean": 0, "lucky": 0, "missions": 0, "piled": 0, "tumbles": 0, "hearts": 0, "streak": 0, "spins": 0, "beans_earned": 0, "bonus_beans": 0, "beans_spent": 0, "time": 0, "longest_time": 0, "squirts": 0, "glazed": 0, "day_streak": 0, "best_day_streak": 0, "crane_plays": 0, "crane_items": 0, "crane_jackpots": 0, "crane_beans_won": 0, "crane_tickets_won": 0, "crane_spent": 0, "crane_tickets_spent": 0, "boxes_shipped": 0}, "crane": {"since_item": 0, "free_day": "", "free_used": 0, "history": []}, "daily_calendar": {"last_day": "", "streak": 0}, "mode": "classic", "mode_best": {}, "daily": {}, "weekly": {}, "showcase": {"weeks": {}, "announced": "", "earned": [], "reveal": []}, "grand_opening": {"runs": 0, "missions": 0, "days": [], "earned": [], "reveal": [], "announced": false}, "first_played": "", "last_played": "", "flavour_counts": {}, "shape_counts": {}, "outfit_best": {}, "room_best": {}, "recent": [], "look": "outfit", "my_kinu": MyKinu.defaults()}

func load_data(source: Variant = null) -> void:
	data = defaults()
	var loaded: Variant = source if source is Dictionary else _read(save_path)
	if not loaded is Dictionary and source == null:
		loaded = _read(save_path + ".bak")
	if loaded is Dictionary:
		for key in data:
			if key == "version":
				continue
			if not loaded.has(key):
				continue
			var value: Variant = loaded[key]
			match key:
				"cloud_revision":
					if (value is float or value is int) and is_finite(float(value)):
						data[key] = clampi(int(value), 0, 2147483647)
				"cloud_updated_at":
					if (value is float or value is int) and is_finite(float(value)):
						data[key] = maxf(float(value), 0.0)
				"cloud_last_downloaded", "cloud_last_uploaded":
					if value is String and value.length() <= 32:
						data[key] = value
				"best", "runs", "beans", "tickets":
					if (value is float or value is int) and is_finite(float(value)):
						data[key] = clampi(int(value), 0, 2147483647)
				"best_height":
					if (value is float or value is int) and is_finite(float(value)):
						data[key] = clampf(float(value), 0, 10000)
				"music", "sfx":
					if (value is float or value is int) and is_finite(float(value)):
						data[key] = clampf(float(value), 0, 1)
				"haptics", "tutorial", "home_tour", "debug_unlocked":
					if value is bool:
						data[key] = value
				"language":
					if value in ["", "en", "ja", "ko", "zh_TW"]:
						data[key] = value
				"backend_session":
					if value is Dictionary and value.get("access_token", "") is String and value.get("refresh_token", "") is String:
						data[key] = value
				"outfit":
					if value is String:
						data[key] = value
				"look":
					if value in ["outfit", "my_kinu"]:
						data[key] = value
				"my_kinu":
					if value is Dictionary:
						var xp: Variant = value.get("xp", 0)
						if (xp is float or xp is int) and is_finite(float(xp)):
							data.my_kinu.xp = clampi(int(xp), 0, 2147483647)
						var seen: Variant = value.get("seen_level", 1)
						if (seen is float or seen is int) and is_finite(float(seen)):
							data.my_kinu.seen_level = clampi(int(seen), 1, 100000)
						for text in ["flavour", "last_run"]:
							if value.get(text) is String and str(value[text]).length() <= 64:
								data.my_kinu[text] = value[text]
						data.my_kinu.intro_seen = value.get("intro_seen") == true
						# Unknown part ids are kept: a newer catalogue on another device may know them,
						# and anything unwearable is simply skipped when the look is drawn.
						if value.get("equipped") is Dictionary:
							for slot in MyKinu.SLOTS:
								var id: Variant = value.equipped.get(slot, "")
								if id is String and str(id).length() <= 64:
									data.my_kinu.equipped[slot] = id
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
				"weekly":
					if value is Dictionary and value.get("week") is String and value.get("mission") is Dictionary:
						data.weekly = value
				"showcase":
					if value is Dictionary:
						if value.get("announced") is String:
							data.showcase.announced = value.announced
						if value.get("weeks") is Dictionary:
							for month in value.weeks:
								if month is String and value.weeks[month] is Array:
									data.showcase.weeks[month] = []
									for week in value.weeks[month]:
										if (week is float or week is int) and not data.showcase.weeks[month].has(int(week)):
											data.showcase.weeks[month].append(int(week))
						for list in ["earned", "reveal"]:
							if value.get(list) is Array:
								for entry in value[list]:
									if entry is String and not data.showcase[list].has(entry):
										data.showcase[list].append(entry)
				"grand_opening":
					if value is Dictionary:
						for counter in ["runs", "missions"]:
							var number: Variant = value.get(counter, 0)
							if (number is float or number is int) and is_finite(float(number)):
								data.grand_opening[counter] = clampi(int(number), 0, 100000)
						data.grand_opening.announced = value.get("announced") == true
						for list in ["days", "earned", "reveal"]:
							if value.get(list) is Array:
								for entry in value[list]:
									if entry is String and not data.grand_opening[list].has(entry):
										data.grand_opening[list].append(entry)
				"daily_calendar":
					if value is Dictionary and value.get("last_day", "") is String:
						data.daily_calendar.last_day = value.last_day
						var streak: Variant = value.get("streak", 0)
						if streak is float or streak is int:
							data.daily_calendar.streak = clampi(int(streak), 0, 7)
				"mode":
					if value in NestRun.MODES:
						data[key] = value
				"mode_best":
					if value is Dictionary:
						for mode in value:
							var best: Variant = value[mode]
							if mode in NestRun.MODES and (best is float or best is int) and is_finite(float(best)):
								data.mode_best[mode] = clampi(int(best), 0, 2147483647)
				"crane":
					if value is Dictionary:
						for counter in ["since_item"]:
							var number: Variant = value.get(counter, 0)
							if (number is float or number is int) and is_finite(float(number)):
								data.crane[counter] = clampi(int(number), 0, 1000)
						if value.get("free_day") is String:
							data.crane.free_day = value.free_day
						var used: Variant = value.get("free_used", 1 if value.get("free_day", "") != "" else 0)
						if used is int or used is float:
							data.crane.free_used = clampi(int(used), 0, KinuCatcher.FREE_DAILY_TICKETS)
						if value.get("history") is Array:
							for entry in value.history.slice(-KinuCatcher.HISTORY):
								if entry is Dictionary and entry.get("kind") is String:
									data.crane.history.append(entry)
				"discovered":
					if value is Array:
						for item in value:
							if item is String and not data.discovered.has(item):
								data.discovered.append(item)
		# The home tour arrived after launch. Anyone who'd already played a couple of runs knows the
		# home screen, so it's only for players still on their first return to it.
		if not loaded.has("home_tour") and int(data.runs) >= 2:
			data.home_tour = true
		# Early shop builds stored outfits separately.
		if loaded.get("owned_outfits") is Array:
			for item in loaded.owned_outfits:
				if item is String and not data.owned.has("outfit:"+item):
					data.owned.append("outfit:"+item)
		# Version 2 recorded the best as a tower height in cm; from version 3 it is Kinu on the pile.
		# Flavour goals moved from cm to a tenth as many Kinu, so the same flavours stay unlocked.
		if int(loaded.get("version", 1)) == 2:
			data.best = int(data.best)/10
		# Version 4 restated beans in a larger unit: every price, prize and reward was multiplied
		# by five at once, so an older balance has to move with them or it quietly buys a fifth of
		# what it used to. Lifetime bean totals are restated too, so the records screen stays honest.
		if int(loaded.get("version", 1)) < 4:
			data.beans = int(data.beans)*BEAN_REDENOMINATION
			for key in ["beans_earned", "bonus_beans", "beans_spent", "crane_beans_won"]:
				data.stats[key] = int(data.stats.get(key, 0))*BEAN_REDENOMINATION
		if int(loaded.get("version", 1)) < 5:
			for id in OLD_OUTFIT_GOALS:
				var goal: Array = OLD_OUTFIT_GOALS[id]
				var key: String = "outfit:"+str(id)
				if (KinuProgress.stat(str(goal[0])) >= int(goal[1]) or str(data.outfit) == id) and not data.owned.has(key):
					data.owned.append(key)
		# Version 6 added My Kinu. Players who were already playing are credited one XP per Kinu
		# they have landed, up to the arms slot, with each opened slot's starter part put on.
		# Their outfit, ownership and selected look are left exactly as they were.
		if int(loaded.get("version", 1)) < 6 and not loaded.has("my_kinu"):
			data.my_kinu.xp = mini(int(data.stats.total), MyKinu.RETRO_XP_CAP)
			var level := MyKinu.level_for(int(data.my_kinu.xp))
			data.my_kinu.seen_level = level
			for slot in MyKinu.SLOTS:
				if MyKinu.slot_level(slot) <= level:
					MyKinu.equip_starter(slot, data.my_kinu)
		# Store IDs stay strings: JSON numbers cannot safely preserve every Apple transaction ID.
		if loaded.get("purchases") is Dictionary:
			data["purchases"] = loaded.purchases.duplicate(true)
		data["ads_removed"] = loaded.get("ads_removed", false) == true
		data["ads_entitlement_date"] = float(loaded.get("ads_entitlement_date", 0.0))
	_last_cloud_content = _cloud_content_json()

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

func persist() -> bool:
	var old_revision := int(data.cloud_revision)
	var old_updated_at := float(data.cloud_updated_at)
	var content := _cloud_content_json()
	if content != _last_cloud_content:
		data.cloud_revision = old_revision + 1
		data.cloud_updated_at = maxf(Time.get_unix_time_from_system(), old_updated_at)
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		data.cloud_revision = old_revision
		data.cloud_updated_at = old_updated_at
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		data.cloud_revision = old_revision
		data.cloud_updated_at = old_updated_at
		return false
	# Never replace the last valid backup with a corrupted main file.
	if _read(save_path) is Dictionary:
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	var error := DirAccess.rename_absolute(temp, save_path)
	if error == OK:
		_last_cloud_content = content
		changed.emit()
	else:
		data.cloud_revision = old_revision
		data.cloud_updated_at = old_updated_at
	return error == OK

## The cloud copy includes the purchase ledger so restored consumable balances cannot be
## delivered twice. Anonymous Supabase tokens and development switches never leave the device.
func cloud_snapshot() -> Dictionary:
	return {"format": 1, "save": _cloud_data()}

func _cloud_data() -> Dictionary:
	var copy := data.duplicate(true)
	copy.erase("backend_session")
	copy.erase("debug_unlocked")
	copy.erase("cloud_last_downloaded")
	copy.erase("cloud_last_uploaded")
	return copy

func _cloud_content_json() -> String:
	var copy := _cloud_data()
	copy.erase("cloud_revision")
	copy.erase("cloud_updated_at")
	return JSON.stringify(copy)

func cloud_snapshot_valid(snapshot: Variant) -> bool:
	if not snapshot is Dictionary or snapshot.get("format") != 1:
		return false
	var saved: Variant = snapshot.get("save")
	if not saved is Dictionary:
		return false
	if not (saved.get("version") is int or saved.get("version") is float) or int(saved.version) > int(defaults().version):
		return false
	if not saved.get("owned") is Array or not saved.get("discovered") is Array or not saved.get("stats") is Dictionary:
		return false
	if not saved.get("purchases", {}) is Dictionary:
		return false
	return (saved.get("cloud_revision", 0) is int or saved.get("cloud_revision", 0) is float) and (saved.get("cloud_updated_at", 0.0) is int or saved.get("cloud_updated_at", 0.0) is float)

func cloud_has_progress(saved: Dictionary) -> bool:
	return int(saved.get("runs", 0)) > 0 or int(saved.get("best", 0)) > 0 or int(saved.get("beans", 0)) > 0 or int(saved.get("tickets", 0)) > 0 or not (saved.get("owned", []) as Array).is_empty() or not (saved.get("discovered", []) as Array).is_empty()

func local_has_new_purchases(saved: Dictionary) -> bool:
	var local_receipts: Dictionary = data.get("purchases", {})
	var cloud_receipts: Dictionary = saved.get("purchases", {})
	for id in local_receipts:
		if not cloud_receipts.has(id):
			return true
	return false

func cloud_has_new_purchases(saved: Dictionary) -> bool:
	var local_receipts: Dictionary = data.get("purchases", {})
	var cloud_receipts: Dictionary = saved.get("purchases", {})
	for id in cloud_receipts:
		if not local_receipts.has(id):
			return true
	return false

func restore_cloud_snapshot(snapshot: Dictionary) -> bool:
	if not cloud_snapshot_valid(snapshot):
		return false
	var before := data.duplicate(true)
	var before_content := _last_cloud_content
	var session: Dictionary = data.get("backend_session", {}).duplicate(true)
	var local_ads := bool(data.get("ads_removed", false))
	var last_downloaded := str(data.get("cloud_last_downloaded", ""))
	var last_uploaded := str(data.get("cloud_last_uploaded", ""))
	load_data(snapshot.save)
	data.backend_session = session
	data["ads_removed"] = local_ads or bool(data.get("ads_removed", false))
	data.cloud_last_downloaded = last_downloaded
	data.cloud_last_uploaded = last_uploaded
	if persist():
		return true
	data = before
	_last_cloud_content = before_content
	return false

## Atomically save currency balances and the delivery receipt before acknowledging Apple.
## Returns -1 on save failure, 0 for a replay, and 1 for a newly applied transaction.
func apply_store_transaction(id: String, product: String, beans: int, tickets: int, revoked: bool, date: float, remove_ads: bool) -> int:
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
			data.tickets = maxi(0, int(data.tickets)-int(previous.get("tickets", 0)))
	else:
		data.beans = int(data.beans)+beans
		data.tickets = int(data.tickets)+tickets
	receipts[id] = {"product": product, "beans": beans, "tickets": tickets, "revoked": revoked}
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
	if key in ["music", "sfx", "haptics", "tutorial", "controls", "claw_hand", "outfit", "box", "room", "debug_unlocked", "language", "mode", "look"]:
		data[key] = value
		persist()

func add_beans(amount: int) -> void:
	data.beans = maxi(0, int(data.beans)+amount)
	persist()

## Beans won by playing (runs and daily missions), counted for the Records page. Purchases aren't.
func add_earned_beans(amount: int) -> void:
	data.stats.beans_earned = int(data.stats.beans_earned)+maxi(0, amount)
	add_beans(amount)

func add_tickets(amount: int) -> void:
	data.tickets = maxi(0, int(data.tickets)+amount)
	persist()

## kind is "outfit", "box" or "room". Free items (price 0 or no outfit) are always owned.
func owns(kind: String, id: String, price: int = 1) -> bool:
	if debug_unlocked() or id == "":
		return true
	# My Kinu level rewards are free but only owned once that level is reached.
	if kind == "part":
		var part := KinuParts.find(id)
		if part and part.level > 0:
			return data.owned.has(kind+":"+id)
	if KinuProgress.is_earned_item(kind, id):
		return data.owned.has(kind+":"+id) or KinuProgress.met(KinuProgress.goals[kind+":"+id])
	if KinuProgress.is_crane_only(kind, id) or KinuProgress.is_showcase(kind, id) or KinuProgress.is_event(kind, id):
		return data.owned.has(kind+":"+id)
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
	if (KinuProgress.is_earned_item(kind, id) or KinuProgress.is_crane_only(kind, id) or KinuProgress.is_showcase(kind, id) or KinuProgress.is_event(kind, id)) and not owns(kind, id, price):
		return false
	if not owns(kind, id, price):
		if int(data.beans) < price:
			return false
		data.beans = int(data.beans)-price
		data.stats.beans_spent = int(data.stats.beans_spent)+price
		data.owned.append(kind+":"+id)
	if kind in ["outfit", "box", "room"]:
		data[kind] = id
		if kind == "outfit":
			data.look = "outfit"
		if kind == "room":
			Sound.play_room_music(id)
	persist()
	return true

## Records a finished run: best pile and height, lifetime stats and daily mission progress.
func finish_run(summary: Dictionary) -> bool:
	var score := int(summary.get("score", 0))
	var mode := str(summary.get("mode", "classic"))
	# Kinu on the pile at the end, which is the score itself in Classic.
	var pile := int(summary.get("pile", score))
	var earned_before := KinuProgress.earned_keys()
	var record := score > int(data.best)
	if mode == "classic":
		data.best = maxi(score, int(data.best))
	else:
		record = score > int(data.mode_best.get(mode, 0))
		data.mode_best[mode] = maxi(score, int(data.mode_best.get(mode, 0)))
		data.stats.boxes_shipped = int(data.stats.boxes_shipped)+int(summary.get("boxes", 0))
	data.best_height = maxf(float(summary.get("height", 0.0)), float(data.best_height))
	data.runs = int(data.runs) + 1
	data.stats.total = int(data.stats.total)+int(summary.get("placed", 0))
	data.stats.lucky = int(data.stats.lucky)+int(summary.get("lucky", 0))
	data.stats.piled = int(data.stats.piled)+pile
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
	if mode == "classic":
		var look := MyKinu.record_key()
		data.outfit_best[look] = maxi(int(data.outfit_best.get(look, 0)), score)
		data.room_best[str(data.room)] = maxi(int(data.room_best.get(str(data.room), 0)), score)
		data.recent.append(score)
		data.recent = data.recent.slice(-RECENT_RUNS)
	_record_day()
	if int(summary.get("tumbles", 0)) == 0:
		data.stats.clean = maxi(int(data.stats.clean), pile)
	GrandOpening.record_run()
	KinuProgress.record_run(summary)
	_grant_run_xp(summary, record)
	if not debug_unlocked():
		for key in KinuProgress.earned_keys():
			if not earned_before.has(key):
				mark_fresh(key)
	persist()
	return record

## My Kinu XP is earned only here, by a run that reached its results, whatever look it wore.
## Restarting or leaving from the pause menu never calls finish_run, so it earns nothing. A run's
## id is remembered so the same run can never pay out twice. The outcome is written back into
## the summary for the results screen as summary.my_kinu.
func _grant_run_xp(summary: Dictionary, record: bool) -> void:
	var run_id := str(summary.get("run_id", ""))
	if run_id != "" and run_id == str(data.my_kinu.last_run):
		summary["my_kinu"] = {"xp": 0, "level_before": MyKinu.level(), "level_after": MyKinu.level(), "rewards": {"beans": 0, "tickets": 0, "parts": [], "slots": []}}
		return
	data.my_kinu.last_run = run_id
	var before := MyKinu.level()
	var gained := MyKinu.run_xp(summary, record)
	data.my_kinu.xp = mini(int(data.my_kinu.xp)+gained, 2147483647)
	var after := MyKinu.level()
	var rewards := MyKinu.grant_levels(before, after)
	if MyKinu.active() and KinuProgress.catalog:
		MyKinu.sync_discovered(KinuProgress.catalog)
	summary["my_kinu"] = {"xp": gained, "level_before": before, "level_after": after, "rewards": rewards}

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
