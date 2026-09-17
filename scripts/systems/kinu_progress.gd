class_name KinuProgress
extends RefCounted
## Lifetime goals that earn cosmetics in the Kinu Book, and the three daily missions.

const GOAL_TEXT := {
	"best": "Pile %d Kinu in one run",
	"total": "Land %d Kinu in total",
	"runs": "Play %d runs",
	"flavours": "Find %d flavours",
	"clean": "Pile %d Kinu without a tumble",
	"lucky": "Catch %d Lucky Kinu",
	"height": "Build a tower %s tall",
	"missions": "Finish %d daily missions",
	"days": "Play %d days in a row",
	"glazed": "Glaze %d Kinu with shoyu",
}

## Daily mission templates. Each day draws three different types (never yesterday's), then a
## tier, and a flavour or shape where the mission needs one.
const MISSIONS := [
	{"type": "pile", "amounts": [30, 50, 65], "rewards": [15, 25, 40]},
	{"type": "runs", "amounts": [2, 3, 5], "rewards": [10, 15, 25]},
	{"type": "land", "amounts": [40, 60, 90], "rewards": [15, 25, 35]},
	{"type": "clean", "amounts": [10, 19, 25], "rewards": [25, 40, 55]},
	{"type": "lucky", "amounts": [1, 2], "rewards": [30, 50]},
	{"type": "heart", "amounts": [1, 2], "rewards": [25, 40]},
	{"type": "height", "amounts": [150, 250, 350], "rewards": [20, 35, 50]},
	{"type": "flavour", "amounts": [5, 8, 12], "rewards": [20, 30, 45]},
	{"type": "shape", "amounts": [6, 10, 15], "rewards": [20, 30, 45]},
	{"type": "streak", "amounts": [16, 28, 40], "rewards": [20, 35, 50]},
	{"type": "spin", "amounts": [5, 10, 20], "rewards": [10, 15, 25]},
	{"type": "pile_times", "amounts": [2, 3], "rewards": [25, 40]},
	{"type": "discover", "amounts": [1], "rewards": [30]},
	{"type": "dressed", "amounts": [1, 3], "rewards": [10, 20]},
	{"type": "decorated", "amounts": [1, 3], "rewards": [10, 20]},
]
## Pile size a "pile_times" mission counts towards.
const PILE_TIMES_TARGET := 40

## Earnable items by "kind:id" (outfit, box or room).
static var goals: Dictionary = {}
static var catalog: KinuCatalog

static func register(from: KinuCatalog) -> void:
	catalog = from
	goals.clear()
	for item in from.outfits:
		if item.goal != "":
			goals["outfit:"+item.id] = item
	for item in from.decor:
		if item.goal != "":
			goals[item.kind+":"+item.id] = item

static func is_earned_item(kind: String, id: String) -> bool:
	return goals.has(kind+":"+id)

static func stat(goal: String) -> int:
	match goal:
		"best":
			return int(Save.data.best)
		"runs":
			return int(Save.data.runs)
		"height":
			return NestRun.height_cm(float(Save.data.best_height))
		"flavours":
			return Save.data.discovered.size()
		"days":
			return int(Save.data.stats.best_day_streak)
	return int(Save.data.stats.get(goal, 0))

static func met(item: Resource) -> bool:
	return stat(item.goal) >= int(item.goal_amount)

static func goal_text(item: Resource) -> String:
	if item.goal == "height":
		return _t(GOAL_TEXT.height)%KinuFlavour.height_text(item.goal_amount)
	return _t(GOAL_TEXT[item.goal])%item.goal_amount

static func _t(text: String) -> String:
	return TranslationServer.translate(text)

static func earned_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in goals:
		if met(goals[key]):
			keys.append(key)
	return keys

static func newly_earned(before: Array[String]) -> Array[String]:
	var names: Array[String] = []
	for key in earned_keys():
		if not before.has(key):
			names.append(goals[key].display_name)
	return names

# ---------- Daily missions ----------

static func today() -> Array:
	var day := Time.get_date_string_from_system()
	var daily: Dictionary = Save.data.daily
	if daily.get("day", "") != day or not daily.get("missions") is Array:
		Save.data.daily = {"day": day, "missions": _roll(day)}
		Save.persist()
	return Save.data.daily.missions

static func _roll(day: String, avoid_yesterday: bool = true) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day)
	var pool: Array = []
	var yesterday: Array = []
	if avoid_yesterday:
		var date := Time.get_unix_time_from_datetime_string(day)
		for mission in _roll(Time.get_date_string_from_unix_time(date-86400), false):
			yesterday.append(mission.type)
	for template in MISSIONS:
		if _available(template.type) and not yesterday.has(template.type):
			pool.append(template)
	var picked := []
	for i in 3:
		var template: Dictionary = pool.pop_at(rng.randi() % pool.size())
		var tier: int = rng.randi() % template.amounts.size()
		var mission := {"type": template.type, "amount": template.amounts[tier], "reward": template.rewards[tier], "progress": 0, "claimed": false, "flavour": "", "shape": ""}
		if template.type == "flavour":
			var unlocked: Array = []
			for flavour in catalog.flavours:
				if Save.flavour_unlocked(flavour):
					unlocked.append(flavour.id)
			mission.flavour = unlocked[rng.randi() % unlocked.size()]
		elif template.type == "shape":
			mission.shape = catalog.shapes[rng.randi() % catalog.shapes.size()].id
		picked.append(mission)
	return picked

## Missions that can't be done yet (no flavours left to find) are left out of the draw.
static func _available(type: String) -> bool:
	if catalog == null:
		return type not in ["flavour", "shape", "discover"]
	if type == "discover":
		for flavour in catalog.flavours:
			if Save.flavour_unlocked(flavour) and not Save.data.discovered.has(flavour.id):
				return true
		return false
	if type == "decorated":
		# Needs a box or room besides the starting ones.
		for kind in ["box", "room"]:
			for item in catalog.decor_of(kind):
				if item.id != {"box": "hinoki", "room": "shop"}[kind] and Save.owns(kind, item.id, item.price):
					return true
		return false
	return true

static func mission_text(mission: Dictionary) -> String:
	var amount := int(mission.amount)
	match str(mission.type):
		"pile":
			return _t("Pile %d Kinu in one run")%amount
		"runs":
			return _t("Play %d runs")%amount
		"land":
			return _t("Land %d Kinu")%amount
		"clean":
			return _t("Pile %d Kinu without a tumble")%amount
		"lucky":
			return _t("Catch a Lucky Kinu") if amount == 1 else _t("Catch %d Lucky Kinu")%amount
		"heart":
			return _t("Catch a Heart Kinu") if amount == 1 else _t("Catch %d Heart Kinu")%amount
		"height":
			return _t("Build a tower %s tall")%KinuFlavour.height_text(amount)
		"flavour":
			return _t("Land %d %s Kinu")%[amount, _flavour_name(str(mission.flavour))]
		"shape":
			return _t("Land %d %s Kinu")%[amount, _shape_name(str(mission.get("shape", "")))]
		"streak":
			return _t("Land %d Kinu in a row without a tumble")%amount
		"spin":
			return _t("Spin the box %d full turns")%amount
		"pile_times":
			return _t("Pile %d Kinu in %d different runs")%[PILE_TIMES_TARGET, amount]
		"discover":
			return _t("Find a new flavour")
		"dressed":
			return _t("Play a run in an outfit") if amount == 1 else _t("Play %d runs in an outfit")%amount
		"decorated":
			return _t("Play a run with a new box or room") if amount == 1 else _t("Play %d runs with a new box or room")%amount
	return ""

static func _flavour_name(id: String) -> String:
	if catalog:
		for flavour in catalog.flavours:
			if flavour.id == id:
				return _t(flavour.display_name)
	return id.capitalize()

static func _shape_name(id: String) -> String:
	if catalog:
		for shape in catalog.shapes:
			if shape.id == id:
				return _t(shape.display_name)
	return id.capitalize()

static func complete(mission: Dictionary) -> bool:
	return int(mission.progress) >= int(mission.amount)

## Applies a finished run to today's missions; returns how many became complete.
static func record_run(summary: Dictionary) -> int:
	var finished := 0
	for mission in today():
		if complete(mission):
			continue
		var score := int(summary.get("score", 0))
		match str(mission.type):
			"pile":
				mission.progress = maxi(int(mission.progress), score)
			"runs":
				mission.progress = int(mission.progress)+1
			"land":
				mission.progress = int(mission.progress)+int(summary.get("placed", 0))
			"clean":
				if int(summary.get("tumbles", 0)) == 0:
					mission.progress = maxi(int(mission.progress), score)
			"lucky":
				mission.progress = int(mission.progress)+int(summary.get("lucky", 0))
			"heart":
				mission.progress = int(mission.progress)+int(summary.get("hearts", 0))
			"height":
				mission.progress = maxi(int(mission.progress), NestRun.height_cm(float(summary.get("height", 0.0))))
			"flavour":
				mission.progress = int(mission.progress)+int(summary.get("flavours", {}).get(mission.flavour, 0))
			"shape":
				mission.progress = int(mission.progress)+int(summary.get("shapes", {}).get(mission.get("shape", ""), 0))
			"streak":
				mission.progress = maxi(int(mission.progress), int(summary.get("streak", 0)))
			"spin":
				mission.progress = int(mission.progress)+int(summary.get("turns", 0))
			"pile_times":
				if score >= PILE_TIMES_TARGET:
					mission.progress = int(mission.progress)+1
			"discover":
				mission.progress = int(mission.progress)+int(summary.get("new_flavours", 0))
			"dressed":
				if summary.get("dressed", false):
					mission.progress = int(mission.progress)+1
			"decorated":
				if summary.get("decorated", false):
					mission.progress = int(mission.progress)+1
		if complete(mission):
			finished += 1
	return finished

static func claimable() -> int:
	var count := 0
	for mission in today():
		if complete(mission) and not mission.claimed:
			count += 1
	return count

static func claim(index: int) -> int:
	var mission: Dictionary = today()[index]
	if not complete(mission) or mission.claimed:
		return 0
	mission.claimed = true
	Save.data.stats.missions = int(Save.data.stats.get("missions", 0))+1
	Save.add_earned_beans(int(mission.reward))
	return int(mission.reward)
