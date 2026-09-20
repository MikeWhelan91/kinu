extends Node
## Kinu Catcher odds, meters, ownership and saving, plus Tower and Lunch Rush played by a bot.
##   godot --headless --path . tests/catcher.tscn
var failures: Array[String] = []
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		print("FAIL: ", description)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ready() -> void:
	Save.save_path = "user://catcher_test.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(Save.save_path+suffix)
	Save.load_data()
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	KinuProgress.register(catalog)
	# ---------- The odds table ----------
	var total := 0.0
	var ids := {}
	var valid := true
	var cosmetic_total := 0.0
	var tier_totals := {}
	for entry in KinuCatcher.table(catalog):
		total += float(entry.odds)
		if KinuCatcher.is_item(entry):
			cosmetic_total += float(entry.odds)
			tier_totals[entry.rarity] = float(tier_totals.get(entry.rarity, 0.0))+float(entry.odds)
			check(entry.rarity in KinuCatcher.TIERS and float(entry.odds) > 0, "%s has a valid tier and positive chance"%entry.id)
			var item := KinuCatcher.item_of(catalog, entry)
			valid = valid and item != null and item.goal == "" and not ids.has(entry.kind+entry.id)
			ids[entry.kind+entry.id] = true
	check(absf(total-100.0) < .001, "prize odds add up to exactly 100%% (got %s)"%total)
	check(absf(cosmetic_total-KinuCatcher.COSMETIC_ODDS) < .001, "the growing catalogue keeps a fixed %s%% cosmetic hit rate"%KinuCatcher.COSMETIC_ODDS)
	for tier in KinuCatcher.TIERS:
		check(absf(float(tier_totals.get(tier, 0.0))-KinuCatcher.COSMETIC_ODDS*float(KinuCatcher.TIER_WEIGHTS[tier])/100.0) < .001, "%s receives its configured share of cosmetic wins"%tier)
	check(valid, "every prize is a real, non-earned catalogue item listed once")
	for item in catalog.outfits+catalog.decor:
		if item.crane_only:
			var kind: String = item.kind if item is KinuDecor else "outfit"
			check(ids.has(kind+item.id), "Catcher exclusive %s is in the machine"%item.id)
			check(not Save.owns(kind, item.id, item.price), "Catcher exclusive %s starts unowned"%item.id)
	var shop_exclusives := catalog.outfits.filter(func(o: KinuOutfit) -> bool: return o.crane_only and o.goal == "" and o.price > 0)
	check(shop_exclusives.is_empty(), "exclusives are never priced for the shop")
	var cute_commons := KinuModel.CUTE_STYLES.slice(0, 30)
	var cute_rares := KinuModel.CUTE_STYLES.slice(30)
	check(cute_commons.size() == 30 and cute_commons.all(func(id: String) -> bool:
		var outfit := catalog.outfit(id)
		return outfit != null and not outfit.crane_only and outfit.rarity == "common" and outfit.price == 440
	), "thirty common outfits are available in the bean shop")
	check(cute_rares.size() == 10 and cute_rares.all(func(id: String) -> bool:
		var outfit := catalog.outfit(id)
		return outfit != null and outfit.crane_only and outfit.rarity == "rare"
	), "ten new rare outfits are in the Catcher and Kinu Book")
	check(catalog.outfits.filter(func(o: KinuOutfit) -> bool: return o.style in KinuModel.PREMIUM_STYLES).size() == 10, "ten new outfits")
	check(catalog.decor_of("box").size() == 22 and catalog.decor_of("room").size() == 20, "ten new boxes and ten new rooms")
	# ---------- Earning tickets ----------
	var legacy_missions := [
		{"claimed": true}, {"claimed": false}, {"claimed": false},
	]
	check(KinuProgress._ensure_ticket_mission("2026-09-17", legacy_missions) and legacy_missions.filter(func(m: Dictionary) -> bool: return bool(m.get("ticket", false))).size() == 1 and legacy_missions.filter(func(m: Dictionary) -> bool: return bool(m.get("ticket", false)))[0].claimed == false, "an old daily save gains exactly one ticket mission without choosing a claimed mission")
	Save.data.daily = {"day": Time.get_date_string_from_system(), "missions": [
		{"type": "runs", "amount": 1, "reward": 10, "progress": 1, "claimed": false, "flavour": "", "shape": "", "ticket": false},
		{"type": "clean", "amount": 1, "reward": 20, "progress": 1, "claimed": false, "flavour": "", "shape": "", "ticket": true},
		{"type": "lucky", "amount": 1, "reward": 30, "progress": 0, "claimed": false, "flavour": "", "shape": "", "ticket": false},
	]}
	var mission_beans := int(Save.data.beans)
	check(KinuProgress.claim(0) == 10 and int(Save.data.beans) == mission_beans+10 and int(Save.data.tickets) == 0, "a bean-only daily mission does not grant a ticket")
	check(KinuProgress.claim(1) == 20 and int(Save.data.beans) == mission_beans+30 and int(Save.data.tickets) == 1, "the marked daily mission grants its beans and one ticket")
	check(KinuProgress.claim(1) == 0 and int(Save.data.tickets) == 1, "the ticket mission cannot grant its ticket twice")
	# ---------- Seven-day calendar ----------
	Save.data.daily_calendar = {"last_day": "", "streak": 0}
	check(DailyCalendar.ready() and DailyCalendar.current_index() == 0 and DailyCalendar.claimed_count() == 0, "a new calendar starts at claimable Day 1")
	var calendar_beans := int(Save.data.beans)
	var calendar_rng := RandomNumberGenerator.new()
	calendar_rng.seed = 7
	var calendar_prize := DailyCalendar.claim(catalog, calendar_rng)
	check(calendar_prize.kind == "beans" and calendar_prize.amount == 30 and int(Save.data.beans) == calendar_beans+30 and not DailyCalendar.ready() and DailyCalendar.claimed_count() == 1, "Day 1 grants beans and checks its calendar square once")
	# Built from the local calendar, not a raw UTC stamp: writing "yesterday" the way the old
	# rollover did made this pass everywhere east of UTC and fail silently everywhere west of it.
	Save.data.daily_calendar = {"last_day": DailyCalendar._yesterday(), "streak": 2}
	check(DailyCalendar.ready() and DailyCalendar.current_index() == 2 and DailyCalendar.claimed_count() == 2, "returning tomorrow advances the calendar")
	Save.data.daily_calendar = {"last_day": DailyCalendar._today(), "streak": 2}
	check(not DailyCalendar.ready() and DailyCalendar.claimed_count() == 2, "a treat already taken today stays taken")
	Save.data.daily_calendar = {"last_day": "2000-01-01", "streak": 6}
	check(DailyCalendar.ready() and DailyCalendar.current_index() == 0 and DailyCalendar.claimed_count() == 0, "missing a day resets the calendar to Day 1")
	# ---------- Playing ----------
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	Save.data.beans = 0
	Save.data.tickets = 0
	check(KinuCatcher.free_ready() and KinuCatcher.can_play(), "a fresh day has a free play")
	var first := KinuCatcher.play(catalog, rng)
	check(not first.is_empty() and first.free and int(Save.data.beans) == (first.amount if first.kind == "beans" else 0), "the free play costs nothing and pays out")
	check(not KinuCatcher.free_ready(), "only one free play a day")
	var plays := 1
	var second := KinuCatcher.play(catalog, rng)
	plays += 0 if second.is_empty() else 1
	check(second.is_empty() and int(Save.data.tickets) == 0, "no tickets and no free play means no play")
	Save.data.tickets = 1000000
	var items_won := 0
	var longest_dry := 0
	var dry := 0
	var repeats := false
	var won := {}
	for i in 600:
		var beans_before := int(Save.data.beans)
		var tickets_before := int(Save.data.tickets)
		var prize := KinuCatcher.play(catalog, rng)
		plays += 1
		check(int(Save.data.tickets) == tickets_before-KinuCatcher.TICKET_COST, "a paid play spends one ticket") if i < 3 else null
		if prize.kind == "beans":
			check(int(Save.data.beans) == beans_before+prize.amount, "bean prizes pay into the separate bean balance") if i < 3 else null
		else:
			check(int(Save.data.beans) == beans_before, "non-bean prizes do not change the bean balance") if i < 3 else null
		if KinuCatcher.is_item(prize):
			repeats = repeats or won.has(prize.kind+prize.id)
			won[prize.kind+prize.id] = true
			items_won += 1
			longest_dry = maxi(longest_dry, dry)
			dry = 0
		else:
			dry += 1
	check(not repeats, "an owned item is never won again")
	check(longest_dry <= KinuCatcher.LUCKY_EVERY-1, "the lucky meter never lets %d plays pass without an item (longest %d)"%[KinuCatcher.LUCKY_EVERY, longest_dry])
	check(int(Save.data.stats.crane_plays) == plays and Save.data.crane.history.size() == KinuCatcher.HISTORY, "plays and recent history are recorded")
	check(int(Save.data.stats.crane_tickets_spent) == plays-1, "only paid plays count as tickets spent")
	var odds := KinuCatcher.odds(catalog)
	var shown := 0.0
	for row in odds:
		shown += float(row.chance)
	check(absf(shown-100.0) < .01, "the odds page always shows chances that add to 100%")
	Save.persist()
	var owned_before: Array = Save.data.owned.duplicate()
	var crane_before: Dictionary = Save.data.crane.duplicate(true)
	Save.load_data()
	check(Save.data.owned == owned_before and int(Save.data.crane.since_item) == int(crane_before.since_item) and Save.data.crane.free_day == crane_before.free_day and int(Save.data.tickets) > 0, "catcher progress and tickets survive reload")
	for i in 3000:
		if KinuCatcher.items_left(catalog) == 0:
			break
		KinuCatcher.play(catalog, rng)
	check(KinuCatcher.items_left(catalog) == 0 and KinuCatcher.odds(catalog).all(func(row: Dictionary) -> bool: return row.entry.kind in ["beans", "tickets"]), "once everything is won the machine pays currencies only")
	var dud := KinuCatcher.play(catalog, rng)
	check(dud.kind in ["beans", "tickets"] and not dud.lucky, "the lucky meter can't force an item that doesn't exist")
	# ---------- Modes ----------
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(Save.save_path+suffix)
	Save.load_data()
	Save.data.tutorial = true
	Save.data.sfx = 0
	Save.data.music = 0
	Save.data.best = 10
	Save.data.mode = "tower"
	check(NestRun.chosen_mode() == "classic", "a locked mode falls back to Classic")
	Save.data.best = 30
	check(NestRun.chosen_mode() == "tower" and NestRun.mode_unlocked("rush"), "modes unlock with a Classic best")
	var app: Node = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await frames(5)
	var run: NestRun = app.run
	check(app.screen.find_child("ModeTower", true, false) != null and app.screen.find_child("Catcher", true, false) != null, "home has the mode picker and the Kinu Catcher")
	app._start()
	await frames(3)
	check(run.mode == "tower" and not run.box.visible and run.plate.visible and run.box.body.collision_layer == 0, "Tower swaps the box for the plate")
	for turn in 14:
		if run.state != "aim":
			break
		run.orbit.lateral = sin(turn)*.12
		run.orbit.depth = cos(turn)*.12
		run.drop()
		for tick in 400:
			await frames(1)
			if run.state != "settle":
				break
	check(run.state in ["aim", "over", "falling"] and run.placed > 3, "Tower stacks Kinu on the plate")
	check(run.score == NestRun.height_cm(run.tower_top(), TowerPlate.TOP) or run.state != "aim", "Tower scores the standing height in cm")
	run.end()
	await frames(2)
	check(app.page == "results" and int(Save.data.mode_best.get("tower", -1)) == run.score and int(Save.data.best) == 30, "Tower bests are kept apart from Classic")
	Save.data.mode = "rush"
	app._start()
	await frames(3)
	check(run.mode == "rush" and run.box.visible and not run.plate.visible and is_instance_valid(app.timer_pill), "Lunch Rush uses the box and shows a clock")
	var spots := [Vector2(-.9, -.9), Vector2(.9, -.9), Vector2(.9, .9), Vector2(-.9, .9), Vector2(0, -.9), Vector2(.9, 0), Vector2(0, .9), Vector2(-.9, 0), Vector2(0, 0), Vector2(-.45, .45), Vector2(.45, -.45), Vector2(.45, .45)]
	var turn := 0
	while run.boxes_shipped == 0 and turn < 40 and run.state != "over":
		if run.state == "aim":
			var spot: Vector2 = spots[turn % spots.size()]
			run.orbit.lateral = spot.x
			run.orbit.depth = spot.y
			run.time_left = 60.0
			run.drop()
			turn += 1
		await frames(1)
	check(run.boxes_shipped == 1 and run.shipped >= NestRun.RUSH_BOX_TARGET, "a full box ships")
	for tick in 200:
		await frames(1)
		if run.state == "aim":
			break
	check(run.state == "aim" and run.pile_count() == 0 and is_equal_approx(run.box.position.x, 0.0), "a fresh empty box slides in after shipping")
	run.time_left = .05
	await frames(10)
	check(run.state == "over" and app.page == "results" and int(Save.data.mode_best.get("rush", -1)) >= NestRun.RUSH_BOX_TARGET, "running out of time ends Lunch Rush with a score")
	check(app.screen.find_child("ResultsCatcher", true, false) != null, "results offer the Kinu Catcher")
	print("CHECKS=", checks, " FAILURES=", failures.size())
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(Save.save_path+suffix)
	get_tree().quit(0 if failures.is_empty() else 1)
