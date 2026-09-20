class_name KinuProgress
extends RefCounted
## Lifetime goals that earn cosmetics in the Kinu Book, and the three daily missions.

const GOAL_TEXT := {
	"best": "Pile %d Kinu in one run",
	"total": "Land %d Kinu in total",
	"runs": "Play %d runs",
	"flavours": "Find %d flavours",
	"clean": "Pile %d Kinu without a tumble",
	"streak": "Land %d Kinu in a row",
	"lucky": "Catch %d Lucky Kinu",
	"height": "Build a tower %s tall",
	"missions": "Finish %d daily missions",
	"days": "Play %d days in a row",
	"glazed": "Glaze %d Kinu with shoyu",
}

## Daily mission templates. Each day draws three different types (never yesterday's), then a
## tier, and a flavour or shape where the mission needs one.
const MISSIONS := [
	{"type": "pile", "amounts": [30, 50, 65], "rewards": [25, 35, 50]},
	{"type": "runs", "amounts": [2, 3, 5], "rewards": [20, 25, 35]},
	{"type": "land", "amounts": [40, 60, 90], "rewards": [25, 35, 45]},
	{"type": "clean", "amounts": [10, 19, 25], "rewards": [35, 50, 65]},
	{"type": "lucky", "amounts": [1, 2], "rewards": [40, 60]},
	{"type": "heart", "amounts": [1, 2], "rewards": [35, 50]},
	{"type": "height", "amounts": [150, 250, 350], "rewards": [30, 45, 60]},
	{"type": "flavour", "amounts": [5, 8, 12], "rewards": [30, 40, 55]},
	{"type": "shape", "amounts": [6, 10, 15], "rewards": [30, 40, 55]},
	{"type": "streak", "amounts": [16, 28, 40], "rewards": [30, 45, 60]},
	{"type": "spin", "amounts": [5, 10, 20], "rewards": [20, 25, 35]},
	{"type": "pile_times", "amounts": [2, 3], "rewards": [35, 50]},
	{"type": "discover", "amounts": [1], "rewards": [40]},
	{"type": "dressed", "amounts": [1, 3], "rewards": [20, 30]},
	{"type": "decorated", "amounts": [1, 3], "rewards": [20, 30]},
]
## Pile size a "pile_times" mission counts towards.
const PILE_TIMES_TARGET := 40

## One substantial, repeatable challenge rotates each week. These deliberately use enduring
## play stats rather than collection objectives, so the pool never dries up for veterans.
const WEEKLY_MISSIONS := [
	{"id": "land_250", "type": "land", "amount": 250},
	{"id": "land_400", "type": "land", "amount": 400},
	{"id": "land_600", "type": "land", "amount": 600},
	{"id": "runs_14", "type": "runs", "amount": 14},
	{"id": "runs_20", "type": "runs", "amount": 20},
	{"id": "runs_28", "type": "runs", "amount": 28},
	{"id": "clean_8", "type": "clean_runs", "amount": 8},
	{"id": "clean_12", "type": "clean_runs", "amount": 12},
	{"id": "clean_18", "type": "clean_runs", "amount": 18},
	{"id": "glaze_20", "type": "glazed", "amount": 20},
	{"id": "glaze_35", "type": "glazed", "amount": 35},
	{"id": "glaze_55", "type": "glazed", "amount": 55},
	{"id": "play_15", "type": "time", "amount": 900},
	{"id": "play_25", "type": "time", "amount": 1500},
	{"id": "spin_50", "type": "spin", "amount": 50},
	{"id": "spin_100", "type": "spin", "amount": 100},
	{"id": "pile_45", "type": "pile", "amount": 45},
	{"id": "pile_65", "type": "pile", "amount": 65},
	{"id": "streak_30", "type": "streak", "amount": 30},
	{"id": "streak_45", "type": "streak", "amount": 45},
]
const WEEKLY_BEANS := 150
const WEEKLY_TICKETS := 1

## Earnable items by "kind:id" (outfit, box or room).
static var goals: Dictionary = {}
## Kinu Catcher exclusives by "kind:id".
static var crane_only: Dictionary = {}
static var catalog: KinuCatalog

static func register(from: KinuCatalog) -> void:
	catalog = from
	goals.clear()
	crane_only.clear()
	for item in from.outfits:
		if item.goal != "":
			goals["outfit:"+item.id] = item
		if item.crane_only:
			crane_only["outfit:"+item.id] = item
	for item in from.decor:
		if item.goal != "":
			goals[item.kind+":"+item.id] = item
		if item.crane_only:
			crane_only[item.kind+":"+item.id] = item

static func is_earned_item(kind: String, id: String) -> bool:
	return goals.has(kind+":"+id)

static func is_crane_only(kind: String, id: String) -> bool:
	return crane_only.has(kind+":"+id)

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

static var server_day := ""

static func apply_time_status(status: Dictionary) -> void:
	var key := str(status.get("daily_key", ""))
	if key.length() == 10 and key[4] == "-" and key[7] == "-":
		server_day = key

static func today() -> Array:
	var day := server_day if not server_day.is_empty() else Time.get_date_string_from_system()
	var daily: Dictionary = Save.data.daily
	# With Supabase enabled, never let a changed device clock create a new mission set before the
	# server has supplied today's key. The Daily screen will populate immediately after startup.
	if Rewards.configured() and server_day.is_empty():
		return daily.get("missions", []) if daily.get("missions") is Array else []
	var changed := false
	if daily.get("day", "") != day or not daily.get("missions") is Array:
		Save.data.daily = {"day": day, "missions": _roll(day)}
		changed = true
	var missions: Array = Save.data.daily.missions
	if _clear_ticket_flags(missions):
		changed = true
	if changed:
		Save.persist()
	return missions

## Old saves may contain a marked ticket mission. Daily missions now award beans only, so clear
## that legacy flag as soon as their saved set is opened.
static func _clear_ticket_flags(missions: Array) -> bool:
	var changed := false
	for mission in missions:
		if bool(mission.get("ticket", false)):
			mission.ticket = false
			changed = true
	return changed

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
		var mission := {"type": template.type, "amount": template.amounts[tier], "reward": template.rewards[tier], "progress": 0, "claimed": false, "flavour": "", "shape": "", "ticket": false}
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

# ---------- Weekly challenge ----------

## A week is a stable seven-day calendar block. Keeping this independent of a launch means the
## same challenge survives restarts and device time within the week.
static func _week_key() -> String:
	var day := Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system())
	return str(floori(day / 604800.0))

static func weekly() -> Dictionary:
	var key := _week_key()
	var saved: Dictionary = Save.data.weekly
	if saved.get("week", "") == key and saved.get("mission") is Dictionary:
		return saved.mission
	var previous_id := str(saved.get("mission", {}).get("id", ""))
	var index := posmod(hash("kinu-week-"+key), WEEKLY_MISSIONS.size())
	if WEEKLY_MISSIONS.size() > 1 and str(WEEKLY_MISSIONS[index].id) == previous_id:
		index = (index+1) % WEEKLY_MISSIONS.size()
	var mission: Dictionary = WEEKLY_MISSIONS[index].duplicate()
	mission.progress = 0
	mission.claimed = false
	Save.data.weekly = {"week": key, "mission": mission}
	Save.persist()
	return mission

static func weekly_text(mission: Dictionary) -> String:
	var amount := int(mission.amount)
	match str(mission.type):
		"land": return _t("Land %d Kinu this week")%amount
		"runs": return _t("Play %d runs this week")%amount
		"clean_runs": return _t("Finish %d clean runs this week")%amount
		"glazed": return _t("Glaze %d Kinu with shoyu this week")%amount
		"time": return _t("Play for %d minutes this week")%roundi(amount / 60.0)
		"spin": return _t("Spin the box %d full turns this week")%amount
		"pile": return _t("Pile %d Kinu in one run")%amount
		"streak": return _t("Land %d Kinu in a row without a tumble")%amount
	return ""

static func weekly_claimable() -> bool:
	var mission := weekly()
	return complete(mission) and not bool(mission.claimed)

static func claim_weekly() -> bool:
	var mission := weekly()
	if not complete(mission) or bool(mission.claimed):
		return false
	mission.claimed = true
	Save.data.stats.missions = int(Save.data.stats.get("missions", 0))+1
	Save.data.stats.beans_earned = int(Save.data.stats.get("beans_earned", 0))+WEEKLY_BEANS
	Save.data.beans = int(Save.data.beans)+WEEKLY_BEANS
	Save.data.tickets = int(Save.data.tickets)+WEEKLY_TICKETS
	Save.persist()
	return true

static func _record_weekly(summary: Dictionary) -> bool:
	var mission := weekly()
	if complete(mission):
		return false
	var score := int(summary.get("pile", summary.get("score", 0)))
	match str(mission.type):
		"land": mission.progress = int(mission.progress)+int(summary.get("placed", 0))
		"runs": mission.progress = int(mission.progress)+1
		"clean_runs":
			if int(summary.get("tumbles", 0)) == 0:
				mission.progress = int(mission.progress)+1
		"glazed": mission.progress = int(mission.progress)+int(summary.get("glazed", 0))
		"time": mission.progress = int(mission.progress)+int(summary.get("time", 0.0))
		"spin": mission.progress = int(mission.progress)+int(summary.get("turns", 0))
		"pile": mission.progress = maxi(int(mission.progress), score)
		"streak": mission.progress = maxi(int(mission.progress), int(summary.get("streak", 0)))
	return complete(mission)

## Applies a finished run to today's missions; returns how many became complete.
static func record_run(summary: Dictionary) -> int:
	var finished := 0
	for mission in today():
		if complete(mission):
			continue
		# Pile missions count Kinu on the pile, whichever mode was played.
		var score := int(summary.get("pile", summary.get("score", 0)))
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
	_record_weekly(summary)
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
