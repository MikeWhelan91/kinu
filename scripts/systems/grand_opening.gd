class_name GrandOpening
extends RefCounted
## The launch celebration: three exclusives, each earned by a small first-days goal before the
## event closes. The rewards are catalogue items tagged `event = "grand_opening"`, which keeps them
## out of the shop, the Kinu Claw and the Day 7 draw. Anything earned is kept for good; anything
## missed never comes back, because that is what makes a launch exclusive worth having.
##
## Progress only counts from the day the event opens, and days come from the server once it has
## answered, so a changed device clock can't add days or stretch the deadline.

const EVENT := "grand_opening"
const START := "2026-09-29"
const END := "2026-10-31"
## In the order the sheet lists them: one quick win on day one, one for coming back over a couple
## of days, and the showpiece for sticking around most of the first week.
const REWARDS := [
	{"key": "outfit:opening_day", "goal": "runs", "amount": 1},
	{"key": "box:first_edition", "goal": "missions", "amount": 5},
	{"key": "room:grand_opening", "goal": "days", "amount": 5},
]

static func _state() -> Dictionary:
	if not Save.data.get("grand_opening") is Dictionary:
		Save.data.grand_opening = {}
	var state: Dictionary = Save.data.grand_opening
	for counter in ["runs", "missions"]:
		if not (state.get(counter) is int or state.get(counter) is float):
			state[counter] = 0
	for list in ["days", "earned", "reveal"]:
		if not state.get(list) is Array:
			state[list] = []
	if not state.get("announced") is bool:
		state.announced = false
	return state

static func today() -> String:
	return KinuProgress.calendar_day()

## Today, but only once it can be trusted: with the backend set up, the device's own date isn't
## used before the server has answered, the same rule the daily missions follow.
static func _trusted_day() -> String:
	if Rewards.configured() and KinuProgress.server_day.is_empty():
		return ""
	return today()

static func active() -> bool:
	var day := today()
	return day >= START and day <= END

static func ended() -> bool:
	return today() > END

## Whole days left, counting today.
static func days_left() -> int:
	var now := Time.get_unix_time_from_datetime_string(today())
	var last := Time.get_unix_time_from_datetime_string(END)
	return maxi(0, int(round((last-now)/86400.0))+1)

static func item_of(reward: Dictionary) -> Resource:
	return KinuProgress.event.get(str(reward.key))

static func kind_of(item: Resource) -> String:
	return "outfit" if item is KinuOutfit else str(item.kind)

## The rewards that exist in this build's catalogue, as {key, goal, amount, item, kind}.
static func rewards() -> Array:
	var rows: Array = []
	for reward in REWARDS:
		var item := item_of(reward)
		if item:
			var row: Dictionary = reward.duplicate()
			row.item = item
			row.kind = kind_of(item)
			rows.append(row)
	return rows

static func reward_for(item: Resource) -> Dictionary:
	for row in rewards():
		if row.item == item:
			return row
	return {}

static func progress(reward: Dictionary) -> int:
	var state := _state()
	match str(reward.goal):
		"runs":
			return int(state.runs)
		"missions":
			return int(state.missions)
		"days":
			return state.days.size()
	return 0

static func earned(key: String) -> bool:
	return _state().earned.has(key)

static func earned_count() -> int:
	var count := 0
	for row in rewards():
		if earned(row.key):
			count += 1
	return count

static func complete() -> bool:
	return earned_count() >= rewards().size()

static func goal_text(reward: Dictionary) -> String:
	var amount := int(reward.amount)
	match str(reward.goal):
		"runs":
			return NestTheme.t("Play a run") if amount == 1 else NestTheme.t("Play %d runs")%amount
		"missions":
			return NestTheme.t("Finish %d daily missions")%amount
		"days":
			return NestTheme.t("Play on %d different days")%amount
	return ""

# ---------- Progress ----------

## Called for every finished run, before its missions are counted.
static func record_run() -> void:
	if not active():
		return
	var state := _state()
	state.runs = int(state.runs)+1
	var day := _trusted_day()
	if day != "" and not state.days.has(day):
		state.days.append(day)
	_check()

## Daily missions completed by a run. They count as soon as they're done, collected or not.
static func record_missions(finished: int) -> void:
	if finished <= 0 or not active():
		return
	var state := _state()
	state.missions = int(state.missions)+finished
	_check()

static func _check() -> void:
	for row in rewards():
		if not earned(row.key) and progress(row) >= int(row.amount):
			_grant(row.key)

static func _grant(key: String) -> void:
	var state := _state()
	if state.earned.has(key):
		return
	state.earned.append(key)
	if not Save.data.owned.has(key):
		Save.data.owned.append(key)
	Save.mark_fresh(key)
	state.reveal.append(key)
	Analytics.track("grand_opening_earned", {"item": key, "day": today()})

# ---------- Presentation ----------

## An earned reward whose celebration hasn't been shown yet, as {kind, item, key}, or {}.
static func pending_reveal() -> Dictionary:
	for key in _state().reveal:
		if KinuProgress.event.has(key):
			var item: Resource = KinuProgress.event[key]
			return {"kind": kind_of(item), "item": item, "key": key}
	return {}

static func clear_reveal(item: Resource) -> void:
	_state().reveal.erase(kind_of(item)+":"+item.id)
	Save.persist()

## Not before a player's first run: a brand-new player meets the event on the home tour instead,
## once they're back from that run.
static func should_announce() -> bool:
	return active() and not bool(_state().announced) and int(Save.data.runs) > 0

static func mark_announced() -> void:
	_state().announced = true
	Save.persist()

## "Ends 31 Oct" / "Last day!", for the banner and the rail.
static func ends_text() -> String:
	var left := days_left()
	if left <= 1:
		return NestTheme.t("Last day!")
	return NestTheme.t("%d days left")%left

## One line for the Kinu Book about how a Grand Opening item is (or was) earned.
static func acquisition_text(item: Resource) -> String:
	var reward := reward_for(item)
	if ended() or reward.is_empty():
		return NestTheme.t("A Grand Opening exclusive from Kinu Tumble's launch. It will never be sold or given out again.")
	return NestTheme.t("A Grand Opening exclusive. %s by 31 October to keep it forever.")%goal_text(reward)

## Home: a new Grand Opening reward first, then the home tour for a new player, then the event's
## one-time announcement, then whatever the Monthly Showcase and daily treat want to show.
static func prompt(app: Node) -> void:
	if pending_reveal().is_empty() and HomeTour.should_show():
		HomeTour.prompt(app)
		return
	if pending_reveal().is_empty() and not should_announce():
		KinuShowcase.prompt(app)
		return
	app.get_tree().create_timer(.3).timeout.connect(func() -> void:
		if not is_instance_valid(app) or app.page != "home" or is_instance_valid(app.modal):
			return
		var reveal := pending_reveal()
		if not reveal.is_empty():
			GrandOpeningSheet.celebrate(app, reveal)
		elif should_announce():
			GrandOpeningSheet.open(app, true))
