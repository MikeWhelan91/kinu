extends Node
## Kinu Catcher odds, meters, ownership and saving, plus Tower and Kinu Toss played by a bot.
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
	# This suite exercises local save rules; server-gated free plays have their own tests.
	ProjectSettings.set_setting("supabase/url", "")
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
		if item.showcase != "":
			var showcase_kind: String = item.kind if item is KinuDecor else "outfit"
			check(not ids.has(showcase_kind+item.id) and int(item.price) == 0 and not item.crane_only, "Monthly Showcase reward %s is never in the machine or shop"%item.id)
		if item.event != "":
			var event_kind: String = item.kind if item is KinuDecor else "outfit"
			check(not ids.has(event_kind+item.id) and int(item.price) == 0 and not item.crane_only, "Grand Opening reward %s is never in the machine or shop"%item.id)
			check(not Save.owns(event_kind, item.id, item.price), "Grand Opening reward %s starts unowned"%item.id)
	var shop_exclusives := catalog.outfits.filter(func(o: KinuOutfit) -> bool: return o.crane_only and o.goal == "" and o.price > 0)
	check(shop_exclusives.is_empty(), "exclusives are never priced for the shop")
	var cute_commons := KinuModel.CUTE_STYLES.slice(0, 30)
	var cute_rares := KinuModel.CUTE_STYLES.slice(30)
	check(cute_commons.size() == 30 and cute_commons.all(func(id: String) -> bool:
		var outfit := catalog.outfit(id)
		return outfit != null and not outfit.crane_only and outfit.rarity == "common" and outfit.price > 0
	), "the original common outfits are available in the bean shop")
	check(cute_rares.slice(0, 10).all(func(id: String) -> bool:
		var outfit := catalog.outfit(id)
		return outfit != null and outfit.crane_only and outfit.rarity == "rare"
	), "the original rare outfits are in the Catcher and Kinu Book")
	check(KinuModel.CUTE_STYLES.all(func(id: String) -> bool: return catalog.outfit(id) != null), "every cute outfit style has a catalog entry")
	check(catalog.outfits.filter(func(o: KinuOutfit) -> bool: return o.style in KinuModel.PREMIUM_STYLES).size() == 10, "ten new outfits")
	check(catalog.decor_of("box").size() >= 22 and catalog.decor_of("room").size() >= 20, "the expanded box and room collections remain available")
	# ---------- Daily missions and legacy ticket flags ----------
	var legacy_missions := [
		{"claimed": true, "ticket": false}, {"claimed": false, "ticket": true}, {"claimed": false, "ticket": false},
	]
	check(KinuProgress._clear_ticket_flags(legacy_missions) and legacy_missions.all(func(m: Dictionary) -> bool: return not bool(m.get("ticket", false))) and not KinuProgress._clear_ticket_flags(legacy_missions), "old daily missions lose ticket flags exactly once")
	Save.data.daily = {"day": Time.get_date_string_from_system(), "missions": [
		{"type": "runs", "amount": 1, "reward": 10, "progress": 1, "claimed": false, "flavour": "", "shape": "", "ticket": false},
		{"type": "clean", "amount": 1, "reward": 20, "progress": 1, "claimed": false, "flavour": "", "shape": "", "ticket": true},
		{"type": "lucky", "amount": 1, "reward": 30, "progress": 0, "claimed": false, "flavour": "", "shape": "", "ticket": false},
	]}
	var mission_beans := int(Save.data.beans)
	check(KinuProgress.claim(0) == 10 and int(Save.data.beans) == mission_beans+10 and int(Save.data.tickets) == 0, "a bean-only daily mission does not grant a ticket")
	check(KinuProgress.claim(1) == 20 and int(Save.data.beans) == mission_beans+30 and int(Save.data.tickets) == 0, "a legacy marked daily mission grants beans without a ticket")
	check(KinuProgress.claim(1) == 0 and int(Save.data.tickets) == 0, "a claimed daily mission cannot pay twice")
	# ---------- Seven-day calendar ----------
	Save.data.daily_calendar = {"last_day": "", "streak": 0}
	check(DailyCalendar.ready() and DailyCalendar.current_index() == 0 and DailyCalendar.claimed_count() == 0, "a new calendar starts at claimable Day 1")
	var calendar_beans := int(Save.data.beans)
	var calendar_rng := RandomNumberGenerator.new()
	calendar_rng.seed = 7
	var calendar_prize := DailyCalendar.claim(catalog, calendar_rng)
	check(calendar_prize.kind == "beans" and calendar_prize.amount == int(DailyCalendar.REWARDS[0].amount) and int(Save.data.beans) == calendar_beans+int(DailyCalendar.REWARDS[0].amount) and not DailyCalendar.ready() and DailyCalendar.claimed_count() == 1, "Day 1 grants beans and checks its calendar square once")
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
	check(KinuCatcher.free_remaining() == 2 and KinuCatcher.total_tickets() == 2 and KinuCatcher.can_play(), "a fresh day has two visible free tickets")
	var first := KinuCatcher.play(catalog, rng)
	check(not first.is_empty() and first.free and int(Save.data.beans) == (first.amount if first.kind == "beans" else 0), "the free play costs nothing and pays out")
	check(KinuCatcher.free_remaining() == 1 and KinuCatcher.total_tickets() == int(Save.data.tickets)+1, "the first free play leaves one visible non-bankable ticket")
	var second := KinuCatcher.play(catalog, rng)
	check(not second.is_empty() and second.free and KinuCatcher.free_remaining() == 0, "the second free play uses the last free ticket")
	var plays := 2
	Save.data.tickets = 0
	var third := KinuCatcher.play(catalog, rng)
	check(third.is_empty() and int(Save.data.tickets) == 0, "no tickets and no free play means no play")
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
	check(int(Save.data.stats.crane_tickets_spent) == plays-2, "only paid plays count as tickets spent")
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
	check(NestRun.chosen_mode() == "tower" and NestRun.mode_unlocked("toss"), "modes unlock with a Classic best")
	var app: Node = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await frames(5)
	var run: NestRun = app.run
	check(app.screen.find_child("ModeTower", true, false) != null and app.screen.find_child("Catcher", true, false) != null, "home has the mode picker and the Kinu Catcher")
	app._start()
	await frames(3)
	check(run.mode == "tower" and not run.box.visible and run.plate.visible and run.box.body.collision_layer == 0, "Tower swaps the box for the plate")
	check(run.sauce_id() == "shoyu" and int(NestRun.SAUCES[run.sauce_id()].targets) == 1, "Tower equips a single-target Shoyu bottle")
	var sauce_probe := run.make_body(run.catalog.shapes[0], run.catalog.flavours[0])
	sauce_probe.scored = true
	var before_sauce := sauce_probe.body_scale
	var sauce_targets: Array[KinuBody] = [sauce_probe]
	check(run._apply_sauce(sauce_targets, NestRun.SAUCES[run.sauce_id()]) == 1 and sauce_probe.sticky and is_equal_approx(sauce_probe.body_scale, before_sauce), "Tower Shoyu glues a Kinu without shrinking it")
	run.bodies.erase(sauce_probe)
	sauce_probe.free()
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
	Save.data.mode = "toss"
	app._start()
	await frames(3)
	var toss: TossPlay = run.toss
	check(run.mode == "toss" and is_instance_valid(toss) and not run.box.visible and not run.plate.visible, "Kinu Toss puts the Classic box and the plate away")
	check(TossPlay.MAX_MISSES == 6 and app.tumble_meter.total == 6, "Toss grants six misses and shows six lives")
	check(is_instance_valid(toss.box) and not toss.box.lidded and toss.box.position.z < -3.0, "Toss opens on an open box down the table")
	check(run.room.lane, "the room is built with a lane cut for the throw")
	# Thrown at the box hard enough to reach it, and again too softly to.
	var landed := 0
	var thrown := 0
	while thrown < 8 and run.state != "over":
		if run.state == "aim":
			var before := run.score
			toss.throw(.84 if thrown % 3 != 2 else .06)
			for tick in 500:
				await frames(1)
				if run.state != "settle":
					break
			if run.score > before:
				landed += 1
			thrown += 1
		await frames(1)
	check(landed > 0, "a firm flick lands Kinu in the box and scores")
	check(run.tumbles > 0, "a limp flick falls short and costs a miss")
	check(run.state == "over" or run.tumbles < TossPlay.MAX_MISSES, "the run ends on the sixth miss")
	run.end()
	await frames(2)
	check(app.page == "results" and int(Save.data.mode_best.get("toss", -1)) == run.score, "Toss keeps its own best")
	check(app.screen.find_child("ResultsCatcher", true, false) != null, "results offer the Kinu Catcher")
	print("CHECKS=", checks, " FAILURES=", failures.size())
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(Save.save_path+suffix)
	get_tree().quit(0 if failures.is_empty() else 1)
