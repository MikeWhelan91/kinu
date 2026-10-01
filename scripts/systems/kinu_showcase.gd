class_name KinuShowcase
extends RefCounted
## The Monthly Showcase: each calendar month features one exclusive cosmetic, earned by finishing
## all four of that month's weekly challenges. The schedule lives on the catalogue items themselves
## (`showcase = "2026-10"`), so a month with no tagged item simply has no showcase.
##
## Weeks are the month-aligned blocks from KinuProgress.week_of(). A week counts the moment its
## weekly challenge is complete, whether or not its beans have been collected yet. Everything resets
## on the 1st.

const WEEKS := 4
## The showcase launched part way through its first month. Weeks that had already ended before
## the feature existed can't be asked of anyone, so that month only needs the weeks from here on.
const FIRST_WEEK := {"2026-09": 3}
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const MONTHS_SHORT := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const KINDS := {"outfit": "Kinu outfit", "box": "Box", "room": "Room"}

static func _state() -> Dictionary:
	if not Save.data.get("showcase") is Dictionary:
		Save.data.showcase = {"weeks": {}, "announced": "", "earned": [], "reveal": []}
	var state: Dictionary = Save.data.showcase
	if not state.get("weeks") is Dictionary:
		state.weeks = {}
	for key in ["earned", "reveal"]:
		if not state.get(key) is Array:
			state[key] = []
	return state

## Finished weeks, kept per month so each month starts clean without a reset step. That matters
## because the day comes from the server once it answers and the device before then; either side of
## midnight on the 1st they can disagree, and a reset would wipe a month the player is still in.
static func _weeks_of(month: String) -> Array:
	var weeks: Dictionary = _state().weeks
	if not weeks.get(month) is Array:
		weeks[month] = []
	return weeks[month]

static func current_month() -> String:
	return showcase_day().substr(0, 7)

## Showcase dates follow the player's local calendar. The weekly challenge still follows the
## server's reset, which can be up to a day apart near midnight in some time zones.
static func showcase_day() -> String:
	return Time.get_date_string_from_system()

static func challenge_ready() -> bool:
	return KinuProgress.calendar_day().substr(0, 7) == current_month()

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

static func first_week(month: String = current_month()) -> int:
	return int(FIRST_WEEK.get(month, 1))

## Weeks of this month that have to be finished for the reward.
static func required_weeks() -> Array[int]:
	var weeks: Array[int] = []
	for week in range(first_week(), WEEKS+1):
		weeks.append(week)
	return weeks

static func weeks_done() -> Array:
	return _weeks_of(current_month())

static func week_done(week: int) -> bool:
	return weeks_done().has(week)

static func progress() -> int:
	var count := 0
	for week in required_weeks():
		if week_done(week):
			count += 1
	return count

static func current_week() -> int:
	return KinuProgress.week_of(showcase_day())

## True once a required week has closed without its challenge, which means this month's reward
## can no longer be earned.
static func missed() -> bool:
	if not challenge_ready():
		return false
	for week in required_weeks():
		if week < current_week() and not week_done(week):
			return true
	return false

static func earned(month: String = current_month()) -> bool:
	return _state().earned.has(month)

## Called when a weekly challenge is finished. `week_key` is KinuProgress's "2026-09-w4".
static func record_week(week_key: String) -> void:
	var parts := week_key.split("-w")
	if parts.size() != 2:
		return
	var month := parts[0]
	var week := int(parts[1])
	var weeks := _weeks_of(month)
	if week < first_week(month) or weeks.has(week):
		return
	weeks.append(week)
	# Months that have been and gone are only kept long enough to finish.
	var state := _state()
	for old in state.weeks.keys():
		if old < month:
			state.weeks.erase(old)
	if weeks.size() >= WEEKS-first_week(month)+1:
		_grant(state, month)
	Save.persist()

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

## The flashy announcement shows once per showcase month, and never for a month the player can
## no longer win (a new player arriving after a required week has closed).
static func should_announce() -> bool:
	return active() and not missed() and str(_state().announced) != current_month()

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

## First and last day of a showcase week, e.g. [22, 30].
static func week_days(week: int, month: String = current_month()) -> Array:
	var start := (week-1)*7+1
	return [start, _days_in(month) if week == WEEKS else start+6]

## "22–30 Sep" style label for a week's card.
static func week_range(week: int, month: String = current_month()) -> String:
	var days := week_days(week, month)
	return NestTheme.t("{start}–{end} {month}").format({"start": days[0], "end": days[1], "month": _short(month)})

## Whole days left in the month, counting today.
static func days_left() -> int:
	return _days_in(current_month())-int(showcase_day().substr(8, 2))+1

## Whole days left in this showcase week, counting today.
static func week_days_left() -> int:
	return int(week_days(current_week())[1])-int(showcase_day().substr(8, 2))+1

static func days_left_text(days: int) -> String:
	return NestTheme.t("Last day!") if days <= 1 else NestTheme.t("%d days left")%days

## One line for the Kinu Book about how a showcase item is (or was) earned.
static func acquisition_text(item: Resource) -> String:
	var month := str(item.showcase)
	match status_of(month):
		"upcoming":
			return NestTheme.t("Coming in the %s Monthly Showcase. Finish that month's weekly challenges to earn it.")%month_name(month)
		"active":
			return NestTheme.t("This month's Showcase reward. Finish every weekly challenge in %s to earn it.")%month_name(month)
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
