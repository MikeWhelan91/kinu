class_name KinuShowcase
extends RefCounted
## The Monthly Showcase: each calendar month features one exclusive cosmetic, earned by finishing
## the month's four showcase goals. The schedule lives on the catalogue items themselves
## (`showcase = "2026-10"`), so a month with no tagged item simply has no showcase.
##
## The goals are the Showcase's own: they run the whole month, can be finished in any order, and
## have nothing to do with the weekly challenge in Daily Missions. Everything resets on the 1st.

## The month's goals. Every one counts in Classic, Tower and Kinu Toss alike.
const GOALS := [
	{"id": "runs", "amount": 40},
	{"id": "land", "amount": 1000},
	{"id": "clean", "amount": 15},
	{"id": "missions", "amount": 20},
]
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const MONTHS_SHORT := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const KINDS := {"outfit": "Kinu outfit", "box": "Box", "room": "Room"}

static func _state() -> Dictionary:
	if not Save.data.get("showcase") is Dictionary:
		Save.data.showcase = {"weeks": {}, "goals": {}, "announced": "", "earned": [], "reveal": []}
	var state: Dictionary = Save.data.showcase
	for key in ["weeks", "goals"]:
		if not state.get(key) is Dictionary:
			state[key] = {}
	for key in ["earned", "reveal"]:
		if not state.get(key) is Array:
			state[key] = []
	return state

## This month's counters, one per goal, kept per month so each month starts clean without a reset
## step. Showcase progress used to come from weekly challenges: a month that already had finished
## weeks keeps that progress as the same number of finished goals.
static func _counts(month: String = current_month()) -> Dictionary:
	var state := _state()
	var goals: Dictionary = state.goals
	if not goals.get(month) is Dictionary:
		var counts := {}
		var legacy: Array = state.weeks.get(month, []) if state.weeks.get(month) is Array else []
		for i in GOALS.size():
			counts[GOALS[i].id] = int(GOALS[i].amount) if i < legacy.size() else 0
		goals[month] = counts
	return goals[month]

static func current_month() -> String:
	return showcase_day().substr(0, 7)

## Showcase dates follow the player's local calendar.
static func showcase_day() -> String:
	return Time.get_date_string_from_system()

## The catalogue item featured in `month` ("2026-10"), or null.
static func item_for(month: String) -> Resource:
	for key in KinuProgress.showcase:
		if KinuProgress.showcase[key].showcase == month:
			return KinuProgress.showcase[key]
	return null

static func kind_of(item: Resource) -> String:
	return "outfit" if item is KinuOutfit else str(item.kind)

## Every scheduled reward, oldest month first: [{month, kind, item}].
static func schedule() -> Array:
	var rows: Array = []
	for key in KinuProgress.showcase:
		var item: Resource = KinuProgress.showcase[key]
		rows.append({"month": str(item.showcase), "kind": kind_of(item), "item": item})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.month < b.month)
	return rows

static func active() -> bool:
	return item_for(current_month()) != null

## "upcoming", "active" or "expended" for a showcase month, against today.
static func status_of(month: String) -> String:
	var now := current_month()
	return "active" if month == now else ("upcoming" if month > now else "expended")

static func goal_text(goal: Dictionary) -> String:
	var amount := int(goal.amount)
	match str(goal.id):
		"runs": return NestTheme.t("Play %d runs")%amount
		"land": return NestTheme.t("Land %d Kinu")%amount
		"clean": return NestTheme.t("Finish %d runs without a tumble")%amount
		"missions": return NestTheme.t("Finish %d daily missions")%amount
	return ""

static func goal_progress(goal: Dictionary) -> int:
	return mini(int(_counts().get(goal.id, 0)), int(goal.amount))

static func goal_done(goal: Dictionary) -> bool:
	return goal_progress(goal) >= int(goal.amount)

## Goals finished this month.
static func progress() -> int:
	var count := 0
	for goal in GOALS:
		if goal_done(goal):
			count += 1
	return count

static func goal_count() -> int:
	return GOALS.size()

## Applies a finished run. `missions` is how many daily missions it completed.
static func record_run(summary: Dictionary, missions: int) -> void:
	var month := current_month()
	if item_for(month) == null or earned(month):
		return
	var counts := _counts(month)
	var add := {"runs": 1, "land": int(summary.get("placed", 0)), "clean": 1 if int(summary.get("tumbles", 0)) == 0 else 0, "missions": missions}
	for goal in GOALS:
		counts[goal.id] = mini(int(counts.get(goal.id, 0))+int(add.get(goal.id, 0)), int(goal.amount))
	# Months that have been and gone are only kept long enough to finish.
	var state := _state()
	for old in state.goals.keys():
		if old < month:
			state.goals.erase(old)
	if progress() >= GOALS.size():
		_grant(state, month)
	Save.persist()

static func earned(month: String = current_month()) -> bool:
	return _state().earned.has(month)

static func _grant(state: Dictionary, month: String) -> void:
	var item := item_for(month)
	if item == null or state.earned.has(month):
		return
	state.earned.append(month)
	var key: String = kind_of(item)+":"+item.id
	if not Save.data.owned.has(key):
		Save.data.owned.append(key)
	Save.mark_fresh(key)
	state.reveal.append(key)
	Analytics.track("showcase_earned", {"month": month, "item": key})

## An earned reward whose celebration hasn't been shown yet, as {kind, item, month}, or {}.
static func pending_reveal() -> Dictionary:
	var state := _state()
	for key in state.reveal:
		if KinuProgress.showcase.has(key):
			var item: Resource = KinuProgress.showcase[key]
			return {"kind": kind_of(item), "item": item, "month": str(item.showcase)}
	return {}

static func clear_reveal(item: Resource) -> void:
	_state().reveal.erase(kind_of(item)+":"+item.id)
	Save.persist()

## The flashy announcement shows once per showcase month.
static func should_announce() -> bool:
	return active() and str(_state().announced) != current_month()

static func mark_announced() -> void:
	_state().announced = current_month()
	Save.persist()

## "October" alone, translated.
static func month_only(month: String) -> String:
	var index := int(month.substr(5, 2))-1
	return NestTheme.t(MONTHS[index]) if index >= 0 and index < MONTHS.size() else month

## "October 2026". Templates keep word order translatable ("2026年10月").
static func month_name(month: String) -> String:
	return NestTheme.t("{month} {year}").format({"month": month_only(month), "year": month.substr(0, 4)})

## "22 Oct".
static func day_name(day: int, month: String = current_month()) -> String:
	return NestTheme.t("{day} {month}").format({"day": day, "month": _short(month)})

static func _short(month: String) -> String:
	return NestTheme.t(MONTHS_SHORT[int(month.substr(5, 2))-1])

static func _days_in(month: String) -> int:
	var year := int(month.substr(0, 4))
	var number := int(month.substr(5, 2))
	if number == 2:
		return 29 if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 else 28
	return 30 if number in [4, 6, 9, 11] else 31

## Whole days left in the month, counting today.
static func days_left() -> int:
	return _days_in(current_month())-int(showcase_day().substr(8, 2))+1

static func days_left_text(days: int) -> String:
	return NestTheme.t("Last day!") if days <= 1 else NestTheme.t("%d days left")%days

## One line for the Kinu Book about how a showcase item is (or was) earned.
static func acquisition_text(item: Resource) -> String:
	var month := str(item.showcase)
	match status_of(month):
		"upcoming":
			return NestTheme.t("Coming in the %s Monthly Showcase. Finish that month's showcase goals to earn it.")%month_name(month)
		"active":
			return NestTheme.t("This month's Showcase reward. Finish all four showcase goals in %s to earn it.")%month_name(month)
	return NestTheme.t("The %s Monthly Showcase reward. It isn't sold in the Shop or found in the Kinu Claw.")%month_name(month)

## Home: an unseen celebration first, then the month's announcement, then the daily treat.
static func prompt(app: Node) -> void:
	if pending_reveal().is_empty() and not should_announce():
		DailyCalendar.prompt(app)
		return
	app.get_tree().create_timer(.3).timeout.connect(func() -> void:
		if not is_instance_valid(app) or app.page != "home" or is_instance_valid(app.modal):
			return
		var reveal := pending_reveal()
		if not reveal.is_empty():
			ShowcaseSheet.celebrate(app, reveal)
		elif should_announce():
			ShowcaseSheet.open(app, true))
