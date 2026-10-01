extends Node
## My Kinu: levels and XP, save migration and cloud copies, part ownership and equipping, the run
## appearance, and the guarantee that parts never change a Kinu's physics.

var failures: Array[String] = []
var checks := 0
var catalog: KinuCatalog

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)
		print("FAIL: ", reason)

func _ready() -> void:
	Save.save_path = "user://my_kinu_test.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(Save.save_path+suffix)
	catalog = load("res://resources/kinu/catalog.tres")
	KinuProgress.register(catalog)
	_levels()
	_parts_catalogue()
	_fresh_save()
	_migration()
	_run_xp()
	_home_progress()
	_ownership()
	_appearance()
	_physics()
	_rendering()
	_catcher()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(Save.save_path+suffix)
	print("MY KINU CHECKS=%d FAILURES=%d" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _levels() -> void:
	check(MyKinu.level_for(0) == 1 and MyKinu.level_for(59) == 1 and MyKinu.level_for(60) == 2, "level 2 takes 60 XP")
	check(MyKinu.level_for(240) == 4 and MyKinu.level_for(239) == 3, "arms (level 4) takes 240 XP")
	check(MyKinu.level_for(500) == 6, "glasses (level 6) takes 500 XP")
	check(MyKinu.level_for(1260) == 10 and MyKinu.level_for(4560) == 20, "levels 10 and 20 follow the curve")
	check(MyKinu.level_for(10000000) > 100, "there is no level cap")
	var progress := MyKinu.progress_for(70)
	check(progress[0] == 10 and progress[1] == 80, "progress is measured within the current level")
	check(MyKinu.run_xp({"placed": 3}, false) == 3, "a short run earns only its landed Kinu")
	check(MyKinu.run_xp({"placed": 5}, false) == 15, "a real attempt earns the finish bonus")
	check(MyKinu.run_xp({"placed": 20}, true) == 40, "a new best earns the record bonus")
	check(MyKinu.run_xp({}, true) == 10 and MyKinu.run_xp({"placed": -4}, false) == 0, "missing or bad counts never go negative")
	check(MyKinu.slot_level("body") == 1 and MyKinu.slot_level("hat") == 2 and MyKinu.slot_level("arms") == 4 and MyKinu.slot_level("glasses") == 6, "slots open at levels 1, 2, 4 and 6")
	check(MyKinu.level_beans(1) == 110 and MyKinu.level_beans(100) == 400, "level beans grow and cap at 400")
	check(MyKinu.badge(9) == "" and MyKinu.badge(10) == "bronze" and MyKinu.badge(55) == "rainbow", "badge frames climb every ten levels")

func _parts_catalogue() -> void:
	var ids := {}
	var shop := {"common": 0, "rare": 0, "epic": 0}
	var crane := 0
	var goals := 0
	var slots := {"body": 0, "hat": 0, "arms": 0, "glasses": 0}
	for part in catalog.parts:
		check(not ids.has(part.id), "part id %s is unique" % part.id)
		ids[part.id] = true
		check(part.slot in MyKinu.SLOTS, "%s has a real slot" % part.id)
		check(not catalog.outfit(part.id), "%s does not share an outfit id" % part.id)
		check(RegEx.create_from_string("^[a-z0-9_]+$").search(part.id) != null, "%s fits the Supabase item key pattern" % part.id)
		check(part.description != "" and not part.description.contains("every Kinu you drop") and not part.description.contains("My Kinu's flavour"), "%s has an item description" % part.id)
		slots[part.slot] += 1
		if part.goal != "":
			goals += 1
			check(KinuProgress.GOAL_TEXT.has(part.goal), "%s has a supported goal" % part.id)
		if part.price > 0:
			shop[part.rarity] += 1
			var band: Array = KinuParts.PRICES[part.rarity]
			check(part.price >= int(band[0]) and part.price <= int(band[2]), "%s is priced in its rarity band" % part.id)
		if part.crane_only:
			crane += 1
	for slot in MyKinu.SLOTS:
		check(MyKinu.starter(slot) != null, "%s has a free starter part" % slot)
		check(slots[slot] >= 30, "%s has at least 30 parts" % slot)
	check(goals >= 30, "at least 30 parts can be earned through goals")
	check(shop.common == 24 and shop.rare == 19 and shop.epic == 10, "53 shop parts: 24 common, 19 rare, 10 epic")
	check(crane == 18, "18 Catcher-only parts")
	for level in range(5, 55, 5):
		check(MyKinu.level_part(level) != null, "level %d has an exclusive part" % level)

func _fresh_save() -> void:
	Save.load_data()
	check(int(Save.data.version) == 6, "saves are version 6")
	check(Save.data.look == "outfit" and str(Save.data.outfit) == "", "new players start in No Outfit")
	check(int(Save.data.my_kinu.xp) == 0 and MyKinu.level() == 1, "new players start at level 1")
	check(Save.data.my_kinu.equipped.body == "comfy_tee", "My Kinu starts in its starter tee")
	check(not MyKinu.active(), "My Kinu is not worn until chosen")

func _migration() -> void:
	var old := {"version": 5, "best": 40, "runs": 30, "outfit": "frog", "owned": ["outfit:frog", "outfit:ghost", "box:ice"], "outfit_best": {"frog": 33, "": 12}, "discovered": ["silken", "matcha"], "stats": {"total": 900}}
	Save.load_data(old)
	check(Save.data.outfit == "frog" and Save.data.look == "outfit", "an existing player keeps wearing their outfit")
	check(Save.data.owned.has("outfit:frog") and Save.data.owned.has("outfit:ghost") and Save.data.owned.has("box:ice") and Save.data.owned.size() == 3, "existing ownership is untouched")
	check(Save.data.outfit_best == {"frog": 33, "": 12}, "outfit records are untouched")
	check(int(Save.data.my_kinu.xp) == MyKinu.RETRO_XP_CAP and MyKinu.level() == 4, "veterans are credited up to the arms slot")
	check(Save.data.my_kinu.equipped.hat == "little_beanie" and Save.data.my_kinu.equipped.arms == "little_arms" and Save.data.my_kinu.equipped.glasses == "", "opened slots wear their starters; glasses are still to earn")
	check(int(Save.data.my_kinu.seen_level) == 4, "back-dated levels are not announced as new")
	Save.load_data({"version": 5, "stats": {"total": 30}})
	check(int(Save.data.my_kinu.xp) == 30 and MyKinu.level() == 1 and Save.data.my_kinu.equipped.hat == "", "a newer player is credited only what they landed")
	# A v6 save round-trips, and survives an iCloud copy.
	Save.load_data(old)
	Save.data.look = "my_kinu"
	Save.data.my_kinu.flavour = "matcha"
	Save.data.my_kinu.equipped.hat = "top_hat"
	check(Save.persist(), "a v6 save writes")
	var snapshot := Save.cloud_snapshot()
	var encoded: Variant = JSON.parse_string(JSON.stringify(snapshot))
	check(Save.cloud_snapshot_valid(encoded), "a v6 cloud snapshot validates")
	Save.load_data({})
	check(Save.restore_cloud_snapshot(encoded), "a v6 cloud snapshot restores")
	check(Save.data.look == "my_kinu" and Save.data.my_kinu.flavour == "matcha" and Save.data.my_kinu.equipped.hat == "top_hat" and int(Save.data.my_kinu.xp) == MyKinu.RETRO_XP_CAP, "My Kinu survives the cloud copy")
	check(Save.data.outfit == "frog", "the remembered outfit survives the cloud copy")
	Save.load_data()
	check(Save.data.look == "my_kinu" and Save.data.my_kinu.equipped.hat == "top_hat", "My Kinu survives a reload")
	var future := Save.cloud_snapshot()
	future.save.version = 7
	check(not Save.cloud_snapshot_valid(future), "a snapshot from a newer save version is refused")
	# Bad data is cleaned on load without losing the rest.
	Save.load_data({"version": 6, "look": "hat", "my_kinu": {"xp": -50, "flavour": 7, "equipped": {"hat": 9, "body": "sky_tee", "cape": "x"}}})
	check(Save.data.look == "outfit" and int(Save.data.my_kinu.xp) == 0 and Save.data.my_kinu.flavour == "silken", "invalid My Kinu fields fall back to defaults")
	check(Save.data.my_kinu.equipped.body == "sky_tee" and Save.data.my_kinu.equipped.hat == "" and not Save.data.my_kinu.equipped.has("cape"), "only known slots with text ids are kept")

func _run_xp() -> void:
	Save.load_data({})
	var summary := {"mode": "classic", "score": 12, "pile": 12, "placed": 14, "run_id": "run-a"}
	Save.finish_run(summary)
	check(int(Save.data.my_kinu.xp) == 24+MyKinu.RECORD_BONUS, "a finished run grants its XP (first run is a new best)")
	check(summary.my_kinu.xp == 24+MyKinu.RECORD_BONUS and summary.my_kinu.level_before == 1, "the results screen gets what was granted")
	check(summary.my_kinu.xp_before == 0 and summary.my_kinu.xp_after == int(Save.data.my_kinu.xp), "results can replay XP from the saved before and after values")
	var xp := int(Save.data.my_kinu.xp)
	Save.finish_run(summary.duplicate(true))
	check(int(Save.data.my_kinu.xp) == xp, "the same run can never pay out twice")
	Save.finish_run({"mode": "classic", "score": 3, "pile": 3, "placed": 3, "run_id": "run-b"})
	check(int(Save.data.my_kinu.xp) == xp+3, "a different run pays out")
	# Reaching levels pays them out.
	var beans := int(Save.data.beans)
	Save.data.my_kinu.xp = MyKinu.RETRO_XP_CAP-1
	Save.finish_run({"mode": "classic", "score": 1, "pile": 1, "placed": 1, "run_id": "run-c"})
	check(MyKinu.level() == 4 and int(Save.data.beans)-beans == MyKinu.level_beans(4), "levelling up pays its beans")
	check(Save.data.my_kinu.equipped.arms == "little_arms", "a slot that opens puts its starter on")
	var tickets := int(Save.data.tickets)
	Save.data.my_kinu.xp = 360
	var rewards := MyKinu.grant_levels(4, 5)
	check(rewards.parts.size() == 1 and Save.owns("part", "bunny_band", 0), "level 5 grants its exclusive part")
	rewards = MyKinu.grant_levels(54, 55)
	check(rewards.tickets == MyKinu.SPARE_TICKETS and int(Save.data.tickets) == tickets+MyKinu.SPARE_TICKETS, "levels past the exclusive parts grant tickets")

func _home_progress() -> void:
	Save.load_data({})
	Save.finish_run({"mode": "classic", "score": 10, "pile": 10, "placed": 10, "run_id": "home-a"})
	Save.finish_run({"mode": "classic", "score": 8, "pile": 8, "placed": 8, "run_id": "home-b"})
	var earned := MyKinu.xp()
	check(earned == 48 and int(Save.data.my_kinu.home_seen_xp) == 0, "Play Again runs accumulate XP for one home celebration")
	var saved: Dictionary = Save.data.duplicate(true)
	Save.load_data(saved)
	check(MyKinu.xp() == earned and int(Save.data.my_kinu.home_seen_xp) == 0, "unseen home XP survives a save reload")
	Save.acknowledge_kinu_progress()
	check(int(Save.data.my_kinu.home_seen_xp) == earned and Save.data.my_kinu.intro_seen, "closing the home celebration marks only that XP as seen")
	Save.finish_run({"mode": "classic", "score": 12, "pile": 12, "placed": 12, "run_id": "home-c"})
	var recap := NestMenuScreen._kinu_rewards_between(MyKinu.level_for(earned),MyKinu.level())
	check(MyKinu.xp() == 80 and int(Save.data.my_kinu.home_seen_xp) == earned, "the next run starts a fresh pending home celebration")
	check(recap.slots == ["hat"] and int(recap.beans) == MyKinu.level_beans(2), "home recap shows the rewards already granted by the new level")
	var old_v6: Dictionary = Save.data.duplicate(true)
	old_v6.my_kinu.erase("home_seen_xp")
	Save.load_data(old_v6)
	check(int(Save.data.my_kinu.home_seen_xp) == MyKinu.xp(), "older v6 saves do not replay previously shown XP")

func _ownership() -> void:
	Save.load_data({})
	check(Save.owns("part", "comfy_tee", 0), "the body starter is owned at level 1")
	check(not Save.owns("part", "little_beanie", 0) and not Save.owns("part", "little_arms", 0) and not Save.owns("part", "round_specs", 0), "locked slot starters are not owned yet")
	check(not Save.owns("part", "golden_specs", 0), "a level part is not owned before its level")
	check(not Save.owns("part", "top_hat", 1300), "a shop part is not owned before it is bought")
	check(not Save.owns("part", "royal_crown", 0), "a Catcher part is not owned before it is won")
	check(not Save.owns("part", "club_jersey", 0), "a goal part is not owned before its goal")
	Save.data.runs = 10
	check(Save.owns("part", "club_jersey", 0), "a goal part is owned once its goal is met")
	Save.data.owned.append("part:planner_glasses")
	check(not Save.owns("part", "planner_glasses", 0), "a goal glass stays locked before its slot opens")
	check(not MyKinu.can_equip(catalog, "hat", "little_beanie"), "a locked slot cannot be worn")
	Save.data.beans = 5000
	check(not Save.buy("part", "cool_shades", 1300) and not Save.owns("part", "cool_shades", 1300), "glasses cannot be bought before level 6")
	check(int(Save.data.beans) == 5000, "a blocked purchase spends no beans")
	check(Save.data.outfit == "" and Save.data.look == "outfit", "buying a part never changes the outfit")
	Save.data.owned.append("part:round_specs")
	check(not Save.owns("part", "round_specs", 0), "a previously recorded glass stays locked before level 6")
	Save.data.my_kinu.xp = 500
	check(Save.owns("part", "little_beanie", 0) and Save.owns("part", "little_arms", 0) and Save.owns("part", "round_specs", 0), "starter parts become owned when their slots open")
	check(Save.owns("part", "planner_glasses", 0), "an earlier goal glass becomes owned at level 6")
	check(Save.buy("part", "cool_shades", 1300) and Save.owns("part", "cool_shades", 1300), "glasses can be bought once the slot opens")
	check(int(Save.data.beans) == 5000-1300, "buying an open slot part spends its price")
	check(MyKinu.equip(catalog, "glasses", "cool_shades"), "a bought part is worn once its slot opens")
	Save.data.owned.append("part:golden_specs")
	check(not Save.owns("part", "golden_specs", 0), "a level 10 reward stays locked at level 6")
	Save.data.my_kinu.xp = 1260
	check(Save.owns("part", "golden_specs", 0), "a level reward becomes owned at its level")
	check(not MyKinu.equip(catalog, "hat", "top_hat"), "an unowned part cannot be worn")
	check(not MyKinu.equip(catalog, "hat", "cool_shades"), "a part only fits its own slot")
	check(MyKinu.equip(catalog, "hat", ""), "a slot can be emptied")
	check(not MyKinu.choose_flavour(catalog, "hanabi"), "a locked flavour cannot be My Kinu's base")
	check(MyKinu.choose_flavour(catalog, "matcha") and MyKinu.base(catalog).id == "matcha", "an unlocked flavour can be My Kinu's base")
	Save.data.my_kinu.flavour = "hanabi"
	check(MyKinu.base(catalog).id == catalog.flavours[0].id, "an unusable base falls back to the first flavour")

func _appearance() -> void:
	Save.load_data({})
	Save.data.owned.append("outfit:frog")
	Save.buy("outfit", "frog", 0)
	check(MyKinu.worn_outfit(catalog).id == "frog" and MyKinu.worn_parts(catalog).is_empty(), "an outfit is worn with no parts")
	check(MyKinu.record_key() == "frog" and MyKinu.dressed(catalog), "outfit runs are filed under the outfit")
	Save.data.best = 20
	Save.data.my_kinu.xp = 500
	Save.data.my_kinu.flavour = "kinako"
	Save.data.my_kinu.equipped = {"body": "comfy_tee", "hat": "little_beanie", "arms": "little_arms", "glasses": "round_specs"}
	MyKinu.wear(catalog, true)
	check(MyKinu.active() and MyKinu.worn_outfit(catalog) == null and MyKinu.worn_parts(catalog).size() == 4, "My Kinu is worn with its parts and no outfit")
	check(Save.data.outfit == "frog", "the outfit is remembered while My Kinu is worn")
	check(MyKinu.record_key() == MyKinu.RECORD_KEY, "My Kinu runs are filed under My Kinu")
	check(Save.data.discovered.has("kinako") and Save.data.discovered.has("yuzu"), "every unlocked flavour counts as found in My Kinu")
	check(not Save.data.discovered.has("blueberry"), "locked flavours stay unfound")
	Save.data.my_kinu.equipped = {"body": "", "hat": "", "arms": "", "glasses": ""}
	check(not MyKinu.dressed(catalog), "an empty My Kinu is not dressed up")
	Save.buy("outfit", "frog", 0)
	check(not MyKinu.active(), "wearing an outfit takes My Kinu off")
	# A run in My Kinu drops only the base flavour, wearing the parts.
	Save.data.my_kinu.equipped = {"body": "sky_tee", "hat": "top_hat", "arms": "", "glasses": ""}
	Save.data.owned.append("part:top_hat")
	Save.data.owned.append("part:sky_tee")
	MyKinu.wear(catalog, true)
	var run := NestRun.new()
	run.catalog = catalog
	var seen := {}
	for i in 40:
		seen[run._choose_flavour().id] = true
	check(seen.keys() == ["kinako"], "every Kinu in a My Kinu run is the base flavour")
	var body := run.make_body(catalog.shapes[0], MyKinu.base(catalog))
	check(body.outfit == null and body.parts.size() == 2 and body.visual.has_node("Parts"), "run Kinu wear My Kinu's parts")
	var lucky := run.make_body(catalog.shapes[0], MyKinu.base(catalog), "lucky")
	check(lucky.look.id == "gold" and lucky.parts.size() == 2, "Lucky Kinu turn gold and keep their parts")
	Save.buy("outfit", "frog", 0)
	var dressed := run.make_body(catalog.shapes[0], catalog.flavours[0])
	check(dressed.outfit.id == "frog" and dressed.parts.is_empty() and not dressed.visual.has_node("Parts"), "outfit runs never show parts")
	run.free()

func _physics() -> void:
	# Every part on its own, plus a full four-slot look.
	var loadouts: Array = []
	var everything: Array[KinuPart] = []
	for part in catalog.parts:
		var single: Array[KinuPart] = [part]
		loadouts.append(single)
	for slot in MyKinu.SLOTS:
		everything.append(catalog.parts_for(slot)[3])
	loadouts.append(everything)
	for shape in catalog.shapes:
		var plain := KinuBody.new()
		plain.setup(shape, catalog.flavours[0])
		var plain_points := _collider(plain).shape.points as PackedVector3Array
		var same := true
		for loadout in loadouts:
			for flavour in [catalog.flavours[0], catalog.flavours[catalog.flavours.size()-1]]:
				var worn := KinuBody.new()
				worn.setup(shape, flavour, null, null, 1.0, loadout)
				same = same and worn.parts.size() == loadout.size() and worn.visual.has_node("Parts")
				same = same and _collider(worn).shape.points == plain_points and worn.mass == plain.mass and worn.center_of_mass == plain.center_of_mass
				same = same and worn.physics_material_override.friction == plain.physics_material_override.friction and worn.physics_material_override.bounce == plain.physics_material_override.bounce
				worn.free()
		check(same, "parts never change the %s hitbox, mass, friction, bounce or balance" % shape.id)
		plain.free()

func _collider(body: KinuBody) -> CollisionShape3D:
	for child in body.get_children():
		if child is CollisionShape3D:
			return child
	return null

func _rendering() -> void:
	var built := 0
	for shape in catalog.shapes:
		var plain := KinuModel.build(shape, catalog.flavours[0])
		var face: Mesh = plain.get_node("Face").mesh
		for part in catalog.parts:
			var model := KinuModel.build(shape, catalog.flavours[0], null, "calm", [part])
			var mesh: Mesh = model.get_node("Parts").mesh
			var ok: bool = mesh.get_surface_count() > 0 and mesh.surface_get_array_len(0) > 0
			# Bounds: parts stay close to the Kinu they are drawn on.
			var bounds := mesh.get_aabb()
			var limit := AABB(-shape.size*.5-Vector3(.55, .4, .4), shape.size+Vector3(1.1, 1.3, .8))
			ok = ok and limit.encloses(bounds)
			for mood in KinuModel.MOODS:
				KinuModel.set_mood(model, shape, mood)
				ok = ok and model.get_node("Parts").mesh == mesh
			KinuModel.set_mood(model, shape, "calm")
			ok = ok and model.get_node("Face").mesh == face
			check(ok, "%s draws on %s within its bounds and through every mood" % [part.id, shape.id])
			model.free()
			built += 1
		plain.free()
	# Arms take the Kinu's own colour, so the cache keeps flavours apart.
	var arms := catalog.part("little_arms")
	var a := KinuModel.build(catalog.shapes[0], catalog.flavours[0], null, "calm", [arms])
	var b := KinuModel.build(catalog.shapes[0], catalog.flavours[3], null, "calm", [arms])
	check(a.get_node("Parts").mesh != b.get_node("Parts").mesh, "arms are coloured per flavour")
	var hat := catalog.part("top_hat")
	var c := KinuModel.build(catalog.shapes[0], catalog.flavours[0], null, "calm", [hat])
	var d := KinuModel.build(catalog.shapes[0], catalog.flavours[3], null, "calm", [hat])
	check(c.get_node("Parts").mesh == d.get_node("Parts").mesh, "hats share one mesh across flavours")
	var outfit := catalog.outfit("frog")
	var e := KinuModel.build(catalog.shapes[0], catalog.flavours[0], outfit, "calm", [hat])
	check(not e.has_node("Parts"), "a complete outfit never mixes with parts")
	for node in [a, b, c, d, e]:
		node.free()
	check(built == catalog.parts.size()*catalog.shapes.size(), "every part was built on every shape")

func _catcher() -> void:
	Save.load_data({})
	check(KinuCatcher.COSMETIC_ODDS == 15.0 and KinuCatcher.LUCKY_EVERY == 15, "the Catcher gives items 15% of the time with a guarantee every 15 plays")
	var parts_in := 0
	for entry in KinuCatcher.table(catalog):
		if entry.kind == "part":
			parts_in += 1
			var part := catalog.part(str(entry.id))
			check(part != null and part.level == 0 and part.goal == "" and not part.starter, "%s belongs in the Catcher" % entry.id)
	check(parts_in == 71, "every shop and Catcher-only part is in the Catcher")
	var total := 0.0
	for entry in KinuCatcher.table(catalog):
		total += float(entry.odds)
	check(absf(total-100.0) < .001, "Catcher odds still add up to 100")
	for entry in KinuCatcher.pool(catalog, true):
		if entry.kind == "part":
			check(catalog.part(str(entry.id)).slot == "body", "level 1 Catcher only offers body parts")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	Save.data.tickets = 400
	var won := 0
	for i in 400:
		var prize: Dictionary = KinuCatcher.play(catalog, rng)
		if prize.get("kind", "") == "part":
			won += 1
			check(Save.owns("part", str(prize.id), 1), "a part won in the Catcher is owned")
	check(won > 0, "parts can be won in the Catcher")
	Save.data.my_kinu.xp = 500
	check(KinuCatcher.pool(catalog, true).any(func(entry: Dictionary) -> bool: return entry.kind == "part" and catalog.part(str(entry.id)).slot == "glasses"), "glasses join the Catcher at level 6")
