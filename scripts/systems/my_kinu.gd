class_name MyKinu
extends RefCounted
## The player's own Kinu: a favourite flavour as its base, levelled up by playing, with parts worn
## in equipment slots. When it is the chosen look, every Kinu dropped in a run is the base flavour
## wearing the equipped parts. Purely visual: shapes keep their own hitboxes and weights.

const SLOTS := ["body", "hat", "arms", "glasses"]
## The level each slot opens at. Each slot comes with a free starter part.
const SLOT_LEVELS := {"body": 1, "hat": 2, "arms": 4, "glasses": 6}
const SLOT_NAMES := {"body": "Body", "hat": "Hat", "arms": "Arms", "glasses": "Glasses"}
## outfit_best key for My Kinu runs; "@" can never begin an outfit id.
const RECORD_KEY := "@my_kinu"
## Existing players are credited 1 XP per Kinu they have landed, up to the arms slot (level 4).
const RETRO_XP_CAP := 240
## Only a real attempt earns the finish bonus, so dropping a Kinu off the edge earns next to nothing.
const FINISH_BONUS_MIN := 5
const FINISH_BONUS := 10
const RECORD_BONUS := 10
## Every LEVEL_PART_EVERY levels grants that level's exclusive part, or these tickets once a
## level has none.
const LEVEL_PART_EVERY := 5
const SPARE_TICKETS := 2
## Badge frames climb every ten levels.
const BADGES := [[50, "rainbow"], [40, "sakura"], [30, "gold"], [20, "silver"], [10, "bronze"]]

static func defaults() -> Dictionary:
	return {"xp": 0, "home_seen_xp": 0, "flavour": "silken", "equipped": {"body": "comfy_tee", "hat": "", "arms": "", "glasses": ""}, "last_run": "", "seen_level": 1, "intro_seen": false}

# ---------- Levels ----------

## XP needed to go from `level` to the next one.
static func xp_to_next(level: int) -> int:
	return 60+20*(maxi(level, 1)-1)

static func level_for(xp: int) -> int:
	var level := 1
	var left := maxi(xp, 0)
	while left >= xp_to_next(level):
		left -= xp_to_next(level)
		level += 1
	return level

## [XP into the current level, XP that level needs].
static func progress_for(xp: int) -> Array[int]:
	var level := 1
	var left := maxi(xp, 0)
	while left >= xp_to_next(level):
		left -= xp_to_next(level)
		level += 1
	return [left, xp_to_next(level)]

static func xp() -> int:
	return int(Save.data.my_kinu.xp)

static func level() -> int:
	return level_for(xp())

static func slot_level(slot: String) -> int:
	return int(SLOT_LEVELS.get(slot, 1))

static func slot_unlocked(slot: String, at_level: int = -1) -> bool:
	return (level() if at_level < 0 else at_level) >= slot_level(slot)

static func badge(at_level: int = -1) -> String:
	var lvl := level() if at_level < 0 else at_level
	for entry in BADGES:
		if lvl >= int(entry[0]):
			return str(entry[1])
	return ""

## XP for a finished run: one per Kinu landed, plus bonuses for a real attempt and a new best.
static func run_xp(summary: Dictionary, record: bool) -> int:
	var placed := maxi(int(summary.get("placed", 0)), 0)
	return placed+(FINISH_BONUS if placed >= FINISH_BONUS_MIN else 0)+(RECORD_BONUS if record else 0)

static func level_beans(at_level: int) -> int:
	return mini(100+10*at_level, 400)

static func level_part(at_level: int) -> KinuPart:
	for part in KinuParts.all():
		if part.level == at_level:
			return part
	return null

## Pays out every level passed between `from` and `to`, into Save.data (the caller persists).
## Returns {"beans", "tickets", "parts": [KinuPart], "slots": [slot]}.
static func grant_levels(from: int, to: int) -> Dictionary:
	var rewards := {"beans": 0, "tickets": 0, "parts": [], "slots": []}
	for reached in range(from+1, to+1):
		rewards.beans += level_beans(reached)
		for slot in SLOTS:
			if slot_level(slot) == reached:
				rewards.slots.append(slot)
				equip_starter(slot)
		if reached % LEVEL_PART_EVERY == 0:
			var part := level_part(reached)
			if part == null:
				rewards.tickets += SPARE_TICKETS
			elif not Save.data.owned.has("part:"+part.id):
				Save.data.owned.append("part:"+part.id)
				Save.mark_fresh("part:"+part.id)
				rewards.parts.append(part)
	Save.data.beans = int(Save.data.beans)+int(rewards.beans)
	Save.data.stats.beans_earned = int(Save.data.stats.beans_earned)+int(rewards.beans)
	Save.data.tickets = int(Save.data.tickets)+int(rewards.tickets)
	return rewards

static func starter(slot: String) -> KinuPart:
	for part in KinuParts.all():
		if part.slot == slot and part.starter:
			return part
	return null

## Puts a newly opened slot's starter part on, unless the player already chose something for it.
## `state` is a my_kinu save dictionary; the live save's by default.
static func equip_starter(slot: String, state: Dictionary = {}) -> void:
	var target: Dictionary = state if not state.is_empty() else Save.data.my_kinu
	var part := starter(slot)
	if part and str(target.equipped.get(slot, "")) == "":
		target.equipped[slot] = part.id

# ---------- What runs wear ----------

## True when My Kinu, rather than an outfit or No Outfit, is the chosen look.
static func active() -> bool:
	return str(Save.data.get("look", "outfit")) == "my_kinu"

## The chosen base flavour, falling back to the first flavour if it is unknown or still locked.
static func base(catalog: KinuCatalog) -> KinuFlavour:
	var id := str(Save.data.my_kinu.flavour)
	for flavour in catalog.flavours:
		if flavour.id == id and Save.flavour_unlocked(flavour):
			return flavour
	return catalog.flavours[0]

## Equipped parts that can actually be worn: owned, and in a slot that is open.
static func equipped(catalog: KinuCatalog) -> Array[KinuPart]:
	var worn: Array[KinuPart] = []
	var slots: Dictionary = Save.data.my_kinu.equipped
	for slot in SLOTS:
		var part := catalog.part(str(slots.get(slot, "")))
		if part and part.slot == slot and slot_unlocked(slot) and Save.owns("part", part.id, part.price):
			worn.append(part)
	return worn

## The complete outfit runs wear, or null for My Kinu and No Outfit.
static func worn_outfit(catalog: KinuCatalog) -> KinuOutfit:
	return null if active() else catalog.outfit(str(Save.data.outfit))

## Parts every run Kinu wears: My Kinu's equipped parts, or none.
static func worn_parts(catalog: KinuCatalog) -> Array[KinuPart]:
	return equipped(catalog) if active() else ([] as Array[KinuPart])

## A pattern outfit's look, or null for My Kinu, costumes and No Outfit.
static func worn_pattern(catalog: KinuCatalog) -> KinuFlavour:
	return null if active() else catalog.pattern(str(Save.data.outfit))

## The flavour a mascot or preview of the player's look shows: My Kinu's base, a pattern outfit's
## finish, or the first flavour.
static func mascot_flavour(catalog: KinuCatalog) -> KinuFlavour:
	if active():
		return base(catalog)
	var pattern := worn_pattern(catalog)
	return pattern if pattern else catalog.flavours[0]

## The key a run's best is filed under on the Records page.
static func record_key() -> String:
	return RECORD_KEY if active() else str(Save.data.outfit)

## Whether a run counts as dressed up for the daily "dressed" mission.
static func dressed(catalog: KinuCatalog) -> bool:
	return not equipped(catalog).is_empty() if active() else str(Save.data.outfit) != ""

## In My Kinu, an unlocked flavour is a found flavour: it is chosen rather than spotted mid-run.
## Marks every unlocked flavour as discovered (the caller persists) and returns the new ids.
static func sync_discovered(catalog: KinuCatalog) -> Array[String]:
	var found: Array[String] = []
	if catalog == null or not active():
		return found
	for flavour in catalog.flavours:
		if Save.flavour_unlocked(flavour) and not Save.data.discovered.has(flavour.id):
			Save.data.discovered.append(flavour.id)
			if not Save.debug_unlocked():
				Save.mark_fresh("flavour:"+flavour.id)
			found.append(flavour.id)
	return found

# ---------- Choosing ----------

static func can_equip(catalog: KinuCatalog, slot: String, id: String) -> bool:
	if id == "":
		return SLOTS.has(slot)
	var part := catalog.part(id)
	return part != null and part.slot == slot and slot_unlocked(slot) and Save.owns("part", id, part.price)

static func equip(catalog: KinuCatalog, slot: String, id: String) -> bool:
	if not can_equip(catalog, slot, id):
		return false
	Save.data.my_kinu.equipped[slot] = id
	Save.persist()
	return true

static func choose_flavour(catalog: KinuCatalog, id: String) -> bool:
	for flavour in catalog.flavours:
		if flavour.id == id and Save.flavour_unlocked(flavour):
			Save.data.my_kinu.flavour = id
			Save.persist()
			return true
	return false

## Makes My Kinu (true) or the saved outfit (false) the look runs wear.
static func wear(catalog: KinuCatalog, on: bool) -> void:
	Save.data.look = "my_kinu" if on else "outfit"
	if on:
		sync_discovered(catalog)
	Save.persist()
