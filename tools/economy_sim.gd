extends Node
## Plays thousands of imaginary runs against the real catalog, bean formula and daily missions to
## show when every flavour, reward and shop item unlocks. Tune prices and goals in catalog.tres or
## the profiles below, then run:
##   Godot --headless --path . res://tools/economy_sim.tscn
##   Godot --headless --path . res://tools/economy_sim.tscn -- perfect   (one profile, full log)
## The summary is also written to docs/economy-results.txt.

## score: Kinu piled on run 1, `grow` more each run, up to `cap`. `wobble` is random spread (0-1).
## tumbles: Kinu lost per run (0-3). A perfect player never tumbles, so never sees a Heart Kinu.
## daily: runs played per day (a new set of missions each day). spin: box turns per Kinu.
const PROFILES := {
	"perfect": {"score": 30, "grow": 10.0, "cap": 160, "wobble": 0.0, "tumbles": 0, "daily": 5, "catch_lucky": 1.0, "spin": .3},
	"skilled": {"score": 12, "grow": 1.5, "cap": 80, "wobble": .25, "tumbles": 3, "daily": 5, "catch_lucky": .8, "spin": .25},
	"casual": {"score": 6, "grow": .4, "cap": 35, "wobble": .35, "tumbles": 3, "daily": 3, "catch_lucky": .6, "spin": .2},
}
const RUNS := 400
const SECONDS_PER_KINU := 5.0
const CM_PER_KINU := 11.0
const SEED := 7
const SQUIRTS_START_SIM := NestRun.SQUIRTS_START
## Share of squirts that land on a Kinu rather than missing.
const GLAZE_HIT := .75

var catalog: KinuCatalog
var rng := RandomNumberGenerator.new()
var log_lines: PackedStringArray = []

func _ready() -> void:
	catalog = load("res://resources/kinu/catalog.tres")
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if PROFILES.has(arg):
			only = arg
	var report: PackedStringArray = []
	report.append(_catalog_totals())
	for name in PROFILES:
		if only != "" and name != only:
			continue
		report.append(_simulate(name, PROFILES[name], only != ""))
	var text := "\n".join(report)
	print(text)
	if only == "":
		var file := FileAccess.open("res://docs/economy-results.txt", FileAccess.WRITE)
		if file:
			file.store_string(text+"\n")
	get_tree().quit()

func _shop_items() -> Array:
	var items := []
	for kind in ["outfit", "box", "room"]:
		var list: Array = catalog.outfits if kind == "outfit" else catalog.decor_of(kind)
		for item in list:
			items.append({"kind": kind, "item": item})
	return items

func _catalog_totals() -> String:
	var spend := 0
	var bought := 0
	var earned := 0
	for entry in _shop_items():
		if entry.item.goal != "":
			earned += 1
		elif entry.item.price > 0:
			bought += 1
			spend += entry.item.price
	return "CATALOG  %d flavours (last at %d Kinu) · %d earned rewards · %d shop items costing %d beans in total\n" % [catalog.flavours.size(), catalog.flavours.back().unlock_kinu, earned, bought, spend]

func _simulate(name: String, profile: Dictionary, verbose: bool) -> String:
	rng.seed = SEED
	var best := 0
	var best_cm := 0
	var beans := 0
	var stats := {"runs": 0, "total": 0, "clean": 0, "lucky": 0, "missions": 0, "days": 0, "glazed": 0}
	var discovered := {}
	var owned := {}
	var equipped_something := false
	var seconds := 0.0
	var beans_from := {"runs": 0, "lucky": 0, "missions": 0}
	var events: Array[Dictionary] = []
	var missions: Array = []
	var yesterday: Array = []
	var shop := _shop_items().filter(func(e: Dictionary) -> bool: return e.item.goal == "" and e.item.price > 0)
	shop.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.item.price < b.item.price)
	var earnable := _shop_items().filter(func(e: Dictionary) -> bool: return e.item.goal != "")
	var done_run := {"flavours": -1, "rewards": -1, "shop": -1}
	var done_minutes := {}
	for run in RUNS:
		var day := run/int(profile.daily)
		if run % int(profile.daily) == 0:
			missions = _roll_missions(best, discovered, yesterday)
			yesterday = missions.map(func(m: Dictionary) -> String: return m.type)
		# ---- the run itself
		var earned_before := _earned(earnable, best, best_cm, stats, discovered)
		var target := minf(profile.cap, profile.score+profile.grow*run)
		var score := clampi(roundi(target*(1.0+rng.randf_range(-profile.wobble, profile.wobble))), 1, int(profile.cap))
		var tumbles := int(profile.tumbles)
		var placed := score+tumbles
		var pool := catalog.flavours.filter(func(f: KinuFlavour) -> bool: return best >= f.unlock_kinu)
		var flavour_counts := {}
		var shape_counts := {}
		var new_flavours := 0
		var lucky := 0
		var lucky_spawned := false
		for i in placed:
			var flavour: KinuFlavour = _pick(pool)
			flavour_counts[flavour.id] = int(flavour_counts.get(flavour.id, 0))+1
			var shape: KinuShape = _pick(catalog.shapes)
			shape_counts[shape.id] = int(shape_counts.get(shape.id, 0))+1
			if not discovered.has(flavour.id):
				discovered[flavour.id] = true
				new_flavours += 1
				events.append({"run": run, "text": "found %s" % flavour.id})
			# Hearts only roll after a tumble, so the roll goes straight to Lucky for a clean run.
			if i >= 3 and not lucky_spawned and rng.randf() > 1.0-NestRun.LUCKY_CHANCE:
				lucky_spawned = true
				if rng.randf() < profile.catch_lucky:
					lucky += 1
		var hearts := 0
		if tumbles > 0:
			for i in maxi(0, placed-3):
				if rng.randf() < NestRun.HEART_CHANCE*.3:
					hearts += 1
		var cm := roundi(score*CM_PER_KINU)
		seconds += placed*SECONDS_PER_KINU
		var event_start := events.size()
		# ---- results screen
		var record := score > best
		var old_best := best
		best = maxi(best, score)
		best_cm = maxi(best_cm, cm)
		stats.runs += 1
		stats.total += placed
		stats.lucky += lucky
		# Profiles play every day, so the day streak is simply the day number.
		stats.days = day+1
		# Shoyu: one squirt to start and one per 20 Kinu, landing on a Kinu most of the time.
		for squirt in SQUIRTS_START_SIM+score/NestRun.SQUIRT_EVERY:
			if rng.randf() < GLAZE_HIT:
				stats.glazed += 1
		if tumbles == 0:
			stats.clean = maxi(stats.clean, score)
		var run_beans := NestRun.beans_for(score, record)
		beans += run_beans+lucky*NestRun.LUCKY_BEANS
		beans_from.runs += run_beans
		beans_from.lucky += lucky*NestRun.LUCKY_BEANS
		for flavour in catalog.flavours:
			if flavour.unlock_kinu > old_best and flavour.unlock_kinu <= best:
				events.append({"run": run, "text": "unlocked flavour %s (pile %d)" % [flavour.id, flavour.unlock_kinu]})
		var summary := {"score": score, "placed": placed, "tumbles": tumbles, "lucky": lucky, "hearts": hearts, "cm": cm, "flavours": flavour_counts, "shapes": shape_counts, "streak": score if tumbles == 0 else score/(tumbles+1), "turns": int(placed*profile.spin), "new_flavours": new_flavours, "dressed": equipped_something}
		for mission in missions:
			if mission.progress >= mission.amount:
				continue
			_progress(mission, summary)
			if mission.progress >= mission.amount:
				stats.missions += 1
				beans += mission.reward
				beans_from.missions += mission.reward
		for key in _earned(earnable, best, best_cm, stats, discovered):
			if not earned_before.has(key):
				owned[key] = true
				events.append({"run": run, "text": "earned %s" % key})
		# ---- spend: cheapest thing first, like a player browsing the shop
		for entry in shop:
			var key: String = entry.kind+":"+entry.item.id
			if not owned.has(key) and beans >= entry.item.price:
				beans -= entry.item.price
				owned[key] = true
				equipped_something = true
				events.append({"run": run, "text": "bought %s for %d" % [key, entry.item.price]})
		for i in range(event_start, events.size()):
			events[i].minutes = seconds/60.0
		if done_run.flavours < 0 and discovered.size() == catalog.flavours.size():
			done_run.flavours = run
			done_minutes.flavours = seconds/60.0
		if done_run.rewards < 0 and earnable.all(func(e: Dictionary) -> bool: return owned.has(e.kind+":"+e.item.id)):
			done_run.rewards = run
			done_minutes.rewards = seconds/60.0
		if done_run.shop < 0 and shop.all(func(e: Dictionary) -> bool: return owned.has(e.kind+":"+e.item.id)):
			done_run.shop = run
			done_minutes.shop = seconds/60.0
		if verbose:
			log_lines.append("run %3d day %3d  pile %3d  +%3d beans  bank %5d  flavours %2d/%d" % [run+1, day+1, score, run_beans+lucky*NestRun.LUCKY_BEANS, beans, discovered.size(), catalog.flavours.size()])
	return _report(name, profile, events, done_run, done_minutes, seconds, stats, beans_from, verbose)

func _report(name: String, profile: Dictionary, events: Array[Dictionary], done_run: Dictionary, done_minutes: Dictionary, seconds: float, stats: Dictionary, beans_from: Dictionary, verbose: bool) -> String:
	var out: PackedStringArray = []
	out.append("==== %s  (pile %d on run 1, +%s a run, max %d, %d tumbles, %d runs a day)" % [name.to_upper(), profile.score, str(profile.grow), profile.cap, profile.tumbles, profile.daily])
	if verbose:
		out.append_array(log_lines)
		log_lines.clear()
	var minutes_per_run := seconds/RUNS/60.0
	for event in events:
		if event.text.begins_with("found") and not verbose:
			continue
		out.append("  run %3d · day %3d · %4.0f min   %s" % [event.run+1, event.run/int(profile.daily)+1, event.minutes, event.text])
	for goal in ["flavours", "rewards", "shop"]:
		var label: String = {"flavours": "every flavour found", "rewards": "every earned reward", "shop": "whole shop bought"}[goal]
		var run: int = done_run[goal]
		out.append("  %-22s %s" % [label, "never (in %d runs)" % RUNS if run < 0 else "run %d · day %d · %.1f hours" % [run+1, run/int(profile.daily)+1, done_minutes.get(goal, 0.0)/60.0]])
	var total: int = beans_from.runs+beans_from.lucky+beans_from.missions
	out.append("  beans over %d runs: %d (runs %d%% · lucky %d%% · missions %d%%), %.0f a run, %.1f min a run" % [RUNS, total, 100*beans_from.runs/maxi(total, 1), 100*beans_from.lucky/maxi(total, 1), 100*beans_from.missions/maxi(total, 1), total/float(RUNS), minutes_per_run])
	out.append("")
	return "\n".join(out)

func _pick(items: Array) -> Variant:
	var total := 0.0
	for item in items:
		total += item.spawn_weight
	var choice := rng.randf()*total
	for item in items:
		choice -= item.spawn_weight
		if choice <= 0:
			return item
	return items.back()

func _earned(earnable: Array, best: int, best_cm: int, stats: Dictionary, discovered: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for entry in earnable:
		var item: Resource = entry.item
		var value := 0
		match item.goal:
			"best":
				value = best
			"height":
				value = best_cm
			"flavours":
				value = discovered.size()
			_:
				value = int(stats.get(item.goal, 0))
		if value >= item.goal_amount:
			keys.append(entry.kind+":"+item.id)
	return keys

## Mirrors KinuProgress._roll: three different mission types a day, never yesterday's.
func _roll_missions(best: int, discovered: Dictionary, yesterday: Array) -> Array:
	var pool := []
	var undiscovered := catalog.flavours.any(func(f: KinuFlavour) -> bool: return best >= f.unlock_kinu and not discovered.has(f.id))
	for template in KinuProgress.MISSIONS:
		if yesterday.has(template.type) or (template.type == "discover" and not undiscovered):
			continue
		pool.append(template)
	var picked := []
	for i in 3:
		var template: Dictionary = pool.pop_at(rng.randi() % pool.size())
		var tier: int = rng.randi() % template.amounts.size()
		var mission := {"type": template.type, "amount": template.amounts[tier], "reward": template.rewards[tier], "progress": 0}
		if template.type == "flavour":
			var unlocked := catalog.flavours.filter(func(f: KinuFlavour) -> bool: return best >= f.unlock_kinu)
			mission.flavour = unlocked[rng.randi() % unlocked.size()].id
		elif template.type == "shape":
			mission.shape = catalog.shapes[rng.randi() % catalog.shapes.size()].id
		picked.append(mission)
	return picked

## Mirrors KinuProgress.record_run.
func _progress(mission: Dictionary, s: Dictionary) -> void:
	match str(mission.type):
		"pile":
			mission.progress = maxi(mission.progress, s.score)
		"runs":
			mission.progress += 1
		"land":
			mission.progress += s.placed
		"clean":
			if s.tumbles == 0:
				mission.progress = maxi(mission.progress, s.score)
		"lucky":
			mission.progress += s.lucky
		"heart":
			mission.progress += s.hearts
		"height":
			mission.progress = maxi(mission.progress, s.cm)
		"flavour":
			mission.progress += int(s.flavours.get(mission.flavour, 0))
		"shape":
			mission.progress += int(s.shapes.get(mission.shape, 0))
		"streak":
			mission.progress = maxi(mission.progress, s.streak)
		"spin":
			mission.progress += s.turns
		"pile_times":
			if s.score >= KinuProgress.PILE_TIMES_TARGET:
				mission.progress += 1
		"discover":
			mission.progress += s.new_flavours
		"dressed", "decorated":
			if s.dressed:
				mission.progress += 1
