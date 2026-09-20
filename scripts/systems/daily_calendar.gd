class_name DailyCalendar
extends RefCounted
## A seven-day attendance calendar. Missing a day resets progress to Day 1; completing Day 7
## awards one new Catcher-only cosmetic, keeping the bean shop a useful targeted destination.

const REWARDS := [
	{"kind": "beans", "amount": 30},
	{"kind": "beans", "amount": 40},
	{"kind": "tickets", "amount": 1},
	{"kind": "beans", "amount": 50},
	{"kind": "beans", "amount": 60},
	{"kind": "tickets", "amount": 2},
	{"kind": "item", "amount": 1},
]

static func _today() -> String:
	return Time.get_date_string_from_system()

## Local midnight-to-midnight, so "yesterday" is the previous *local* calendar day.
static func _yesterday() -> String:
	return Time.get_date_string_from_unix_time(_local_unix()-86400.0)

## The system clock as a unix stamp that, read back as UTC, spells out the local wall-clock date.
static func _local_unix() -> float:
	return Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())

## Days since the epoch for a stored "YYYY-MM-DD" stamp. A missing or malformed stamp reads as
## the distant past so every comparison against it counts as a missed day.
static func _day_number(date: String) -> int:
	var parts := date.split("-")
	if parts.size() != 3:
		return -0x40000000
	return int(floor(Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12, "minute": 0, "second": 0})/86400.0))

## Whole local days between the stored stamp and today. Both sides are derived from the local
## clock: the old code compared a local date string against a UTC one, so for every timezone
## behind UTC "yesterday" resolved to today's date and the streak restarted at Day 1 forever.
static func _days_since(date: String) -> int:
	return _day_number(_today())-_day_number(date)

static func _state() -> Dictionary:
	if not Save.data.get("daily_calendar") is Dictionary:
		Save.data.daily_calendar = {"last_day": "", "streak": 0}
	return Save.data.daily_calendar

## Once Supabase is configured, this short-lived local cache is display-only. The function is
## still the authority for whether a claim may be granted.
static func _remote() -> Dictionary:
	var state := _state()
	if not state.get("remote") is Dictionary:
		state.remote = {"known": false, "ready": false, "streak": 0, "seconds_remaining": 0}
	return state.remote

static func apply_server_status(status: Dictionary) -> void:
	if status.is_empty():
		return
	var remote := _remote()
	remote.known = true
	remote.ready = bool(status.get("ready", false))
	remote.streak = clampi(int(status.get("streak", 0)), 0, 7)
	remote.seconds_remaining = maxi(0, int(status.get("seconds_remaining", 0)))

static func refresh_server_status() -> Dictionary:
	if not Rewards.configured():
		return {}
	var status: Dictionary = await Rewards.daily_status()
	apply_server_status(status)
	return status

## The 0-based calendar square that can be claimed today, or -1 once today's prize is claimed.
static func current_index() -> int:
	var state := _state()
	var remote := _remote()
	if Rewards.configured() and bool(remote.get("known", false)):
		return int(remote.get("streak", 0)) % REWARDS.size() if bool(remote.get("ready", false)) else -1
	var elapsed := _days_since(str(state.get("last_day", "")))
	if elapsed == 0:
		return -1
	if elapsed == 1:
		return int(state.get("streak", 0)) % REWARDS.size()
	return 0

static func ready() -> bool:
	return current_index() >= 0

## Number of checked cells to show in the current seven-day strip.
static func claimed_count() -> int:
	var state := _state()
	var remote := _remote()
	if Rewards.configured() and bool(remote.get("known", false)):
		return int(remote.get("streak", 0)) % REWARDS.size() if bool(remote.get("ready", false)) else int(remote.get("streak", 0))
	var elapsed := _days_since(str(state.get("last_day", "")))
	if elapsed == 0:
		return int(state.get("streak", 0))
	if elapsed == 1:
		return int(state.get("streak", 0)) % REWARDS.size()
	return 0

static func countdown_text() -> String:
	if ready():
		return "Today's treat is ready!"
	var remote := _remote()
	if Rewards.configured() and bool(remote.get("known", false)):
		var remaining := maxi(0, int(remote.get("seconds_remaining", 0)))
		return "Next treat in %02d:%02d:%02d" % [remaining/3600, (remaining % 3600)/60, remaining % 60]
	var now := Time.get_datetime_dict_from_system()
	var seconds := 86400-(int(now.hour)*3600+int(now.minute)*60+int(now.second))
	seconds = clampi(seconds, 0, 86400)
	return "Next treat in %02d:%02d:%02d" % [seconds/3600, (seconds % 3600)/60, seconds % 60]

## Claims today's prize first, then returns a Catcher-shaped prize dictionary for CapsuleReveal.
static func claim(catalog: KinuCatalog, rng: RandomNumberGenerator, approved_index: int = -1) -> Dictionary:
	var index := approved_index if approved_index >= 0 else current_index()
	if index < 0:
		return {}
	var reward: Dictionary = REWARDS[index]
	var prize: Dictionary = {"kind": str(reward.kind), "id": "", "amount": int(reward.amount), "lucky": false, "free": true}
	if prize.kind == "beans":
		Save.add_earned_beans(prize.amount)
	elif prize.kind == "tickets":
		Save.add_tickets(prize.amount)
	else:
		prize = _item_prize(catalog, rng)
		if prize.is_empty():
			# The finite claw collection has been completed. Tickets remain useful and never waste a Day 7.
			prize = {"kind": "tickets", "id": "", "amount": 3, "lucky": false, "free": true}
			Save.add_tickets(3)
	var state := _state()
	state.last_day = _today()
	state.streak = index+1
	Save.persist()
	return prize

## Day 7 draws only from unowned claw-only cosmetics using the normal Catcher rarity weights.
static func _item_prize(catalog: KinuCatalog, rng: RandomNumberGenerator) -> Dictionary:
	var entries: Array = []
	for item in catalog.outfits:
		if item.crane_only and not Save.owns("outfit", item.id, int(item.price)):
			entries.append({"kind": "outfit", "id": item.id, "rarity": item.rarity})
	for item in catalog.decor:
		if item.crane_only and not Save.owns(item.kind, item.id, int(item.price)):
			entries.append({"kind": item.kind, "id": item.id, "rarity": item.rarity})
	if entries.is_empty():
		return {}
	var tiers := {}
	for entry in entries:
		tiers[entry.rarity] = int(tiers.get(entry.rarity, 0))+1
	var active_weight := 0.0
	for tier in KinuCatcher.TIERS:
		if int(tiers.get(tier, 0)) > 0:
			active_weight += float(KinuCatcher.TIER_WEIGHTS[tier])
	var roll := rng.randf()*active_weight
	var selected_tier := ""
	for tier in KinuCatcher.TIERS:
		if int(tiers.get(tier, 0)) <= 0:
			continue
		roll -= float(KinuCatcher.TIER_WEIGHTS[tier])
		if roll <= 0.0:
			selected_tier = tier
			break
	var choices: Array = entries.filter(func(entry: Dictionary) -> bool: return entry.rarity == selected_tier)
	var entry: Dictionary = choices[rng.randi_range(0, choices.size()-1)]
	var item := KinuCatcher.item_of(catalog, entry)
	Save.data.owned.append(str(entry.kind)+":"+str(entry.id))
	Save.mark_fresh(str(entry.kind)+":"+str(entry.id))
	return {"kind": str(entry.kind), "id": str(entry.id), "amount": 0, "item": item, "crane_only": true, "lucky": false, "free": true}

static func prompt(app: Node) -> void:
	if not ready():
		return
	app.get_tree().create_timer(.25).timeout.connect(func() -> void:
		if is_instance_valid(app) and app.page == "home" and not is_instance_valid(app.modal) and ready():
			show(app))

static func show(app: Node) -> void:
	DailyTreats.open(app)

static func _claim_and_reveal(app: Node) -> void:
	if Rewards.configured():
		DailyTreats.set_claim_pending(app, true)
		var approved: Dictionary = await Rewards.claim_daily()
		DailyTreats.set_claim_pending(app, false)
		if approved.is_empty():
			DailyTreats.set_claim_error(app, "Couldn't check your daily treat. Please try again while online.")
			return
		apply_server_status(approved)
		if not bool(approved.get("claimed", false)):
			show(app)
			return
		var remote_rng := RandomNumberGenerator.new()
		remote_rng.randomize()
		var remote_prize := claim(app.run.catalog, remote_rng, int(approved.get("reward_index", -1)))
		if not remote_prize.is_empty():
			Sound.play("cashregister")
			Haptics.pulse(30, .55)
			app._close_modal()
			var remote_reveal := CapsuleReveal.open(app, remote_prize)
			remote_reveal.closed.connect(func(_action: String) -> void:
				if is_instance_valid(app) and app.page == "home":
					show(app))
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var prize := claim(app.run.catalog, rng)
	if prize.is_empty():
		return
	Sound.play("cashregister")
	Haptics.pulse(30, .55)
	app._close_modal()
	var reveal := CapsuleReveal.open(app, prize)
	reveal.closed.connect(func(_action: String) -> void:
		if is_instance_valid(app) and app.page == "home":
			show(app))
