class_name KinuCatcher
extends RefCounted
## The Kinu Catcher prize machine. Every play wins exactly one prize, drawn at random from the odds
## table below the moment the ticket is paid, and saved before any animation plays.
##
## The odds are percentages and add up to 100. Items you already own drop out of the draw, and the
## chances you see on the Odds page are the table re-scaled over what's left, so every item won is
## new. The lucky meter stops a long unlucky streak: LUCKY_EVERY plays in a row without an item and
## that play is drawn from items only.

const TICKET_COST := 1
const LUCKY_EVERY := 15
## One free play each calendar day.
const FREE_DAILY := true
const HISTORY := 20
## Bean prizes this size or bigger count as a jackpot.
const JACKPOT := 3000

static var _remote_free_known := false
static var _remote_free_ready := false

static func apply_time_status(status: Dictionary) -> void:
	if status.has("free_claw_ready"):
		_remote_free_known = true
		_remote_free_ready = bool(status.free_claw_ready)

static func refresh_free_status() -> Dictionary:
	if not Rewards.configured():
		return {}
	var status: Dictionary = await Rewards.time_status()
	apply_time_status(status)
	return status

## First roll a fixed cosmetic hit, then rarity, then an unowned item in that rarity. Keeping the
## hit rate separate means a growing catalogue never silently makes cosmetics more common.
const TIERS := ["common", "rare", "epic", "legendary"]
const COSMETIC_ODDS := 10.0
const TIER_WEIGHTS := {"common": 55.0, "rare": 25.0, "epic": 13.0, "legendary": 7.0}
## Beans take whatever is left once cosmetics, tickets and the jackpot have taken their cut. Each
## weight is a split of that remainder, so retuning any of the others moves beans and nothing else.
const BEANS := [
	{"amount": 10, "weight": 40},
	{"amount": 20, "weight": 30},
	{"amount": 40, "weight": 16},
	{"amount": 80, "weight": 8},
	{"amount": 200, "weight": 3},
]
const JACKPOT_ODDS := .03
## Tickets are the other thing a play can win: another go at the machine, which is a better
## prize than a small handful of beans. They take a fixed slice of the non-cosmetic remainder.
const TICKETS := [
	{"amount": 1, "weight": 62},
	{"amount": 2, "weight": 27},
	{"amount": 3, "weight": 11},
]
const TICKET_ODDS := 9.0
const TIER_NAMES := {"common": "Common", "rare": "Rare", "epic": "Epic", "legendary": "Legendary"}
const TIER_COLORS := {"common": Color("7f9a8c"), "rare": Color("3fa9f5"), "epic": Color("a66bff"), "legendary": Color("d89616")}

## A small pill naming an item's tier in its colour, or null for items without one.
static func tier_pill(rarity: String, font_size: int = 15) -> PanelContainer:
	if not TIER_NAMES.has(rarity):
		return null
	var text_color: Color = Color("4f3008") if rarity == "legendary" else TIER_COLORS[rarity].darkened(.25)
	var pill := NestTheme.pill(TIER_NAMES[rarity], font_size, text_color)
	var style := (pill.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	if rarity == "legendary":
		style.bg_color = Color("edb62e")
		style.border_color = Color("8c580b")
	else:
		style.border_color = TIER_COLORS[rarity].darkened(.35)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 5
	style.content_margin_bottom = 7
	pill.add_theme_stylebox_override("panel", style)
	return pill

## All paid or Catcher-only catalogue cosmetics enter automatically. Goal rewards and free starter
## decor stay out, so adding a new prize only requires adding it to the catalogue.
static func _item_entries(catalog: KinuCatalog, available_only: bool) -> Array:
	var entries: Array = []
	for item in catalog.outfits:
		if item.goal == "" and item.finish == null and (int(item.price) > 0 or item.crane_only):
			var entry := {"kind": "outfit", "id": item.id, "rarity": item.rarity}
			if not available_only or not owned(catalog, entry):
				entries.append(entry)
	for item in catalog.decor:
		if item.goal == "" and (int(item.price) > 0 or item.crane_only):
			var entry := {"kind": item.kind, "id": item.id, "rarity": item.rarity}
			if not available_only or not owned(catalog, entry):
				entries.append(entry)
	return entries

## Split `budget` across available tiers, then evenly across the items inside each tier.
static func _weighted_items(entries: Array, budget: float) -> Array:
	var counts := {}
	for entry in entries:
		counts[entry.rarity] = int(counts.get(entry.rarity, 0))+1
	var active_weight := 0.0
	for tier in TIERS:
		if int(counts.get(tier, 0)) > 0:
			active_weight += float(TIER_WEIGHTS[tier])
	var result: Array = []
	for entry in entries:
		var copy: Dictionary = entry.duplicate()
		copy.odds = budget*float(TIER_WEIGHTS.get(copy.rarity, 0.0))/active_weight/float(counts[copy.rarity]) if active_weight > 0 else 0.0
		result.append(copy)
	return result

static func _bean_entries(item_budget: float) -> Array:
	var entries: Array = []
	var weights := 0.0
	for bean in BEANS:
		weights += float(bean.weight)
	var left := 100.0-item_budget-JACKPOT_ODDS-TICKET_ODDS
	for bean in BEANS:
		entries.append({"kind": "beans", "amount": int(bean.amount), "odds": left*float(bean.weight)/weights})
	entries.append({"kind": "beans", "amount": JACKPOT, "odds": JACKPOT_ODDS})
	entries.append_array(_ticket_entries())
	return entries

## Ticket prizes, sharing TICKET_ODDS between them by weight.
static func _ticket_entries() -> Array:
	var entries: Array = []
	var weights := 0.0
	for ticket in TICKETS:
		weights += float(ticket.weight)
	for ticket in TICKETS:
		entries.append({"kind": "tickets", "amount": int(ticket.amount), "odds": TICKET_ODDS*float(ticket.weight)/weights})
	return entries

## The complete fresh-player table shown in tests and used for catalogue validation.
static func table(catalog: KinuCatalog) -> Array:
	var entries := _weighted_items(_item_entries(catalog, false), COSMETIC_ODDS)
	entries.append_array(_bean_entries(COSMETIC_ODDS if not entries.is_empty() else 0.0))
	return entries

## The catalogue item behind a prize entry, or null for beans.
static func item_of(catalog: KinuCatalog, entry: Dictionary) -> Resource:
	match str(entry.kind):
		"outfit":
			return catalog.outfit(str(entry.id))
		"box", "room":
			for item in catalog.decor_of(str(entry.kind)):
				if item.id == str(entry.id):
					return item
	return null

## Beans and tickets are amounts paid straight into the wallet; everything else is a collectable.
static func is_item(entry: Dictionary) -> bool:
	return str(entry.kind) not in ["beans", "tickets"]

static func owned(catalog: KinuCatalog, entry: Dictionary) -> bool:
	var item := item_of(catalog, entry)
	return item != null and Save.owns(str(entry.kind), item.id, int(item.price))

## Every prize still in the machine for this player: all beans, plus items not owned yet.
static func pool(catalog: KinuCatalog, items_only: bool = false) -> Array:
	var entries := _item_entries(catalog, true)
	if not items_only:
		entries.append_array(_bean_entries(COSMETIC_ODDS if not entries.is_empty() else 0.0))
	return entries

## Each prize left in the machine with its chance this play, in percent.
static func odds(catalog: KinuCatalog, items_only: bool = false) -> Array:
	var items := _item_entries(catalog, true)
	var entries := _weighted_items(items, 100.0 if items_only else COSMETIC_ODDS)
	if not items_only:
		entries.append_array(_bean_entries(COSMETIC_ODDS if not items.is_empty() else 0.0))
	var result: Array = []
	for entry in entries:
		result.append({"entry": entry, "chance": float(entry.odds)})
	return result

static func items_left(catalog: KinuCatalog) -> int:
	return pool(catalog, true).size()

static func free_ready() -> bool:
	if Rewards.configured():
		return FREE_DAILY and _remote_free_known and _remote_free_ready
	return FREE_DAILY and str(Save.data.crane.free_day) != Time.get_date_string_from_system()

static func can_play() -> bool:
	return free_ready() or int(Save.data.tickets) >= TICKET_COST

## Plays left before the lucky meter guarantees an item (1 means this play).
static func lucky_in() -> int:
	return maxi(1, LUCKY_EVERY-int(Save.data.crane.since_item))

## Pays for one play (the daily free play first) and draws its prize. The prize is granted and the
## save written before this returns, so closing the app mid-animation never loses or re-rolls it.
## Returns {} when the player can't afford a play.
static func play(catalog: KinuCatalog, rng: RandomNumberGenerator) -> Dictionary:
	var free := free_ready()
	if not free and int(Save.data.tickets) < TICKET_COST:
		return {}
	var crane: Dictionary = Save.data.crane
	var stats: Dictionary = Save.data.stats
	if free:
		crane.free_day = Time.get_date_string_from_system()
	else:
		Save.data.tickets = int(Save.data.tickets)-TICKET_COST
		stats.crane_tickets_spent = int(stats.crane_tickets_spent)+TICKET_COST
	var lucky := int(crane.since_item) >= LUCKY_EVERY-1 and items_left(catalog) > 0
	var table := odds(catalog, lucky)
	var weights: Array[float] = []
	for row in table:
		weights.append(float(row.chance))
	var row: Dictionary = table[_weighted(weights, rng)]
	var prize := _grant(catalog, row.entry)
	prize.chance = row.chance
	prize.lucky = lucky
	prize.free = free
	stats.crane_plays = int(stats.crane_plays)+1
	crane.since_item = 0 if is_item(row.entry) else int(crane.since_item)+1
	Save.persist()
	return prize

## The server grants the free play before any client-side prize animation starts. Paid ticket
## plays remain local because they have no time gate.
static func play_free(catalog: KinuCatalog, rng: RandomNumberGenerator) -> Dictionary:
	if not Rewards.configured():
		return play(catalog, rng)
	var status: Dictionary = await Rewards.claim_free_claw()
	apply_time_status(status)
	if not bool(status.get("claimed", false)):
		return {}
	var crane: Dictionary = Save.data.crane
	crane.free_day = "server"
	var stats: Dictionary = Save.data.stats
	var lucky := int(crane.since_item) >= LUCKY_EVERY-1 and items_left(catalog) > 0
	var table := odds(catalog, lucky)
	var weights: Array[float] = []
	for row in table:
		weights.append(float(row.chance))
	var row: Dictionary = table[_weighted(weights, rng)]
	var prize := _grant(catalog, row.entry)
	prize.chance = row.chance
	prize.lucky = lucky
	prize.free = true
	stats.crane_plays = int(stats.crane_plays)+1
	crane.since_item = 0 if is_item(row.entry) else int(crane.since_item)+1
	Save.persist()
	return prize

static func _grant(catalog: KinuCatalog, entry: Dictionary) -> Dictionary:
	var stats: Dictionary = Save.data.stats
	var prize := {"kind": str(entry.kind), "id": str(entry.get("id", "")), "amount": int(entry.get("amount", 0)), "chance": 0.0, "lucky": false, "free": false}
	if is_item(entry):
		var item := item_of(catalog, entry)
		prize.item = item
		prize.crane_only = bool(item.crane_only)
		Save.data.owned.append(str(entry.kind)+":"+item.id)
		Save.mark_fresh(str(entry.kind)+":"+item.id)
		stats.crane_items = int(stats.crane_items)+1
	elif str(entry.kind) == "tickets":
		Save.data.tickets = int(Save.data.tickets)+prize.amount
		stats.crane_tickets_won = int(stats.get("crane_tickets_won", 0))+prize.amount
	else:
		Save.data.beans = int(Save.data.beans)+prize.amount
		stats.crane_beans_won = int(stats.crane_beans_won)+prize.amount
		if prize.amount >= JACKPOT:
			stats.crane_jackpots = int(stats.crane_jackpots)+1
	var history: Array = Save.data.crane.history
	history.append({"kind": prize.kind, "id": prize.id, "amount": prize.amount})
	Save.data.crane.history = history.slice(-HISTORY)
	return prize

static func _weighted(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	var choice := rng.randf()*total
	for i in weights.size():
		choice -= weights[i]
		if choice <= 0:
			return i
	return weights.size()-1

## The prize's tier for the reveal: an item's own rarity, or for beans how big the win was.
static func grade(entry: Dictionary) -> String:
	if str(entry.get("kind", "")) == "tickets":
		# A free go is worth more than the small bean wins it sits among.
		return "epic" if int(entry.get("amount", 0)) >= 3 else "rare"
	if str(entry.get("kind", "")) == "beans":
		var amount := int(entry.get("amount", 0))
		return "legendary" if amount >= JACKPOT else "epic" if amount >= 200 else "rare" if amount >= 80 else "common"
	return str(entry.get("rarity", "common"))

static func entry_for(catalog: KinuCatalog, prize: Dictionary) -> Dictionary:
	for entry in table(catalog):
		if entry.kind == prize.kind and (is_item(entry) and entry.id == prize.id or not is_item(entry) and int(entry.amount) == int(prize.amount)):
			return entry
	return {}
