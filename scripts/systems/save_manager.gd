extends Node
signal changed
const PATH := "user://nest_save.json"
var data: Dictionary = {}
var save_path: String = PATH

func _ready() -> void:
	load_data()

func defaults() -> Dictionary:
	return {"version": 2, "best": 0, "best_height": 0.0, "discovered": [], "music": 0.55, "sfx": 0.8, "haptics": true, "tutorial": false, "runs": 0, "outfit": "", "controls": "classic", "beans": 0, "owned": [], "box": "hinoki", "room": "shop"}

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
				"haptics", "tutorial":
					if value is bool:
						data[key] = value
				"outfit":
					if value is String:
						data[key] = value
				"controls":
					if value in ["classic", "grab"]:
						data[key] = value
				"owned":
					if value is Array:
						for item in value:
							if item is String and not data.owned.has(item):
								data.owned.append(item)
				"box", "room":
					if value is String and value != "":
						data[key] = value
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
		# Version 1 recorded the best as a piece count; from version 2 it is the tower height in cm.
		if int(loaded.get("version", 1)) < 2:
			data.best = NestRun.height_cm(float(data.best_height)) if float(data.best_height) > 0 else 0

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
	file.close()
	# Never replace the last valid backup with a corrupted main file.
	if _read(save_path) is Dictionary:
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	var error := DirAccess.rename_absolute(temp, save_path)
	changed.emit()
	return error == OK

func discover(id: String) -> bool:
	if data.discovered.has(id):
		return false
	data.discovered.append(id)
	persist()
	return true

func setting(key: String, value: Variant) -> void:
	if key in ["music", "sfx", "haptics", "tutorial", "controls", "outfit", "box", "room"]:
		data[key] = value
		persist()

func add_beans(amount: int) -> void:
	data.beans = maxi(0, int(data.beans)+amount)
	persist()

## kind is "flavour", "outfit", "box" or "room". Free items (price 0 or no outfit) are always owned.
func owns(kind: String, id: String, price: int = 1) -> bool:
	return id == "" or price <= 0 or data.owned.has(kind+":"+id)

## Spends soybeans on a shop item and equips it where that makes sense. False if unaffordable.
func buy(kind: String, id: String, price: int) -> bool:
	if not owns(kind, id, price):
		if int(data.beans) < price:
			return false
		data.beans = int(data.beans)-price
		data.owned.append(kind+":"+id)
	if kind in ["outfit", "box", "room"]:
		data[kind] = id
	persist()
	return true

func finish_run(score: int, height: float = 0.0) -> bool:
	var record := score > int(data.best)
	data.best = maxi(score, int(data.best))
	data.best_height = maxf(height, float(data.best_height))
	data.runs = int(data.runs) + 1
	persist()
	return record

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		persist()
