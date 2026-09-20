class_name KinuRecords
extends RefCounted
## The Records tab of the Kinu Book: the player's favourite Kinu, recent piles and lifetime stats.
## Stats added after launch only count runs played since they were introduced.

static func show(app: Node, layout: VBoxContainer) -> void:
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var list: VBoxContainer = app._vbox(scroll, 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var catalog: KinuCatalog = app.run.catalog
	var stats: Dictionary = Save.data.stats
	var runs := int(Save.data.runs)
	_favourite(app, list, catalog)
	if not Save.data.recent.is_empty():
		var chart_board := NestSettingsScreen._board(list, "Recent Runs")
		var chart := RecentChart.new()
		chart.scores = Save.data.recent
		chart.best = int(Save.data.best)
		chart_board.add_child(NestTheme.paper(chart))
	var owned := 0
	var total := 0
	for entry in KinuShopScreen.TABS:
		for item in KinuShopScreen.items(catalog, entry[2]):
			total += 1
			if Save.owns(entry[2], item.id, item.price):
				owned += 1
	var favourite_shape := _top(Save.data.shape_counts)
	var shape := _shape(catalog, favourite_shape)
	var sections := [
		["Best Runs", [
			["Biggest pile", app._number(Save.data.best)],
			["Tallest tower", KinuFlavour.height_text(NestRun.height_cm(float(Save.data.best_height)))],
			["Biggest pile without a tumble", app._number(stats.clean)],
			["Longest landing streak", app._number(stats.streak)],
			["Longest run", duration(int(stats.longest_time))],
			["Most days in a row", app._number(stats.best_day_streak)],
		]],
		["All Time", [
			["Runs played", app._number(runs)],
			["Average pile", "%.1f"%(float(stats.piled)/runs) if runs > 0 else "–"],
			["Play time", duration(int(stats.time))],
			["Days in a row", app._number(Save.day_streak())],
			["Kinu landed", app._number(stats.total)],
			["Kinu tumbled", app._number(stats.tumbles)],
			["Box spins", app._number(stats.spins)],
			["Favourite shape", NestTheme.t(shape.display_name) if shape else "–"],
		]],
		["Shoyu", [
			["Squirts used", app._number(stats.squirts)],
			["Kinu glazed", app._number(stats.glazed)],
		]],
		["Treasures", [
			["Lucky Kinu caught", app._number(stats.lucky)],
			["Heart Kinu caught", app._number(stats.hearts)],
			["Flavours found", "%d / %d"%[KinuBookScreen.found(catalog.flavours), catalog.flavours.size()]],
			["Daily missions finished", app._number(stats.missions)],
			["Beans earned", app._number(stats.beans_earned)],
			["Bonus beans won", app._number(stats.bonus_beans)],
		]],
		["Modes", [
			["Tallest Tower", KinuFlavour.height_text(NestRun.best_for("tower"))],
			["Most bentos packed in Bento Flip", app._number(NestRun.best_for("rush"))],
			["Boxes shipped", app._number(stats.boxes_shipped)],
		]],
		["Kinu Claw", [
			["Plays", app._number(stats.crane_plays)],
			["Items won", app._number(stats.crane_items)],
			["Beans won", app._number(stats.crane_beans_won)],
			["Jackpots", app._number(stats.crane_jackpots)],
			["Tickets won", app._number(stats.get("crane_tickets_won", 0))],
			["Tickets spent", app._number(stats.crane_tickets_spent)],
		]],
		["Shop", [
			["Items collected", "%d / %d"%[owned, total]],
			["Beans spent", app._number(stats.beans_spent)],
		]],
	]
	for section in sections:
		var board := NestSettingsScreen._board(list, section[0])
		for row in section[1]:
			board.add_child(_row(row[0], row[1]))
	var by_room := []
	for id in Save.data.room_best:
		var room := catalog.find_decor("room", id)
		if room:
			by_room.append([room.display_name, int(Save.data.room_best[id])])
	_best_board(app, list, "Best Pile By Room", by_room)
	var by_outfit := []
	for id in Save.data.outfit_best:
		var outfit := catalog.outfit(id) if id != "" else null
		if outfit or id == "":
			by_outfit.append([outfit.display_name if outfit else "No Outfit", int(Save.data.outfit_best[id])])
	_best_board(app, list, "Best Pile By Outfit", by_outfit)

## A board featuring the most-landed flavour on the most-landed shape, and when stacking began.
static func _favourite(app: Node, list: VBoxContainer, catalog: KinuCatalog) -> void:
	var board := NestSettingsScreen._board(list, "Favourite Kinu")
	var flavour: KinuFlavour = null
	var favourite_id := _top(Save.data.flavour_counts)
	for item in catalog.flavours:
		if item.id == favourite_id:
			flavour = item
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if flavour:
		var shape := _shape(catalog, _top(Save.data.shape_counts))
		var preview := KinuPreview.new()
		preview.setup(shape if shape else catalog.shapes[0], flavour, true, Vector2i(150, 124), "happy")
		preview.custom_minimum_size = Vector2(150, 124)
		row.add_child(preview)
		text.add_child(NestTheme.label(NestTheme.t("%s Kinu")%NestTheme.t(flavour.display_name), 22))
		var landed := int(Save.data.flavour_counts[favourite_id])
		text.add_child(NestTheme.label(NestTheme.t("Landed 1 time") if landed == 1 else NestTheme.t("Landed %s times")%app._number(landed), 16, NestTheme.MUTED))
	else:
		var empty := NestTheme.label("Play a run to meet your favourite Kinu!", 18)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(empty)
	if Save.data.first_played != "":
		var since := NestTheme.label(NestTheme.t("Stacking since %s")%date_text(Save.data.first_played), 16, NestTheme.MUTED)
		since.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		since.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(since)
	row.add_child(text)
	board.add_child(NestTheme.paper(row))

static func _best_board(app: Node, list: VBoxContainer, title: String, entries: Array) -> void:
	if entries.is_empty():
		return
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var board := NestSettingsScreen._board(list, title)
	for entry in entries:
		board.add_child(_row(entry[0], app._number(entry[1])))

## A paper strip with the stat name on the left and its value on the right.
static func _row(title_text: String, value_text: String) -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var title := NestTheme.label(title_text, 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(title)
	var value := NestTheme.label(value_text, 22)
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	return NestTheme.paper(row)

## The key with the highest count, or "" when nothing has been counted.
static func _top(counts: Dictionary) -> String:
	var best := ""
	for id in counts:
		if best == "" or int(counts[id]) > int(counts[best]):
			best = id
	return best

static func _shape(catalog: KinuCatalog, id: String) -> KinuShape:
	for shape in catalog.shapes:
		if shape.id == id:
			return shape
	return null

## "3h 12m" for long totals, "4m 05s" for a single run.
static func duration(seconds: int) -> String:
	if seconds <= 0:
		return "–"
	if seconds >= 3600:
		return NestTheme.t("%dh %dm")%[seconds/3600, seconds/60%60]
	return NestTheme.t("%dm %ds")%[seconds/60, seconds%60]

## "12 Sep 2026" in English; CJK languages read year, month, day.
static func date_text(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3:
		return iso
	if TranslationServer.get_locale().substr(0, 2) in ["ja", "ko", "zh"]:
		return "%s/%s/%s"%[parts[0], parts[1], parts[2]]
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s %s"%[int(parts[2]), months[clampi(int(parts[1])-1, 0, 11)], parts[0]]

## Bars for the last few piles, oldest on the left; a pile matching the best is drawn in gold.
class RecentChart extends Control:
	var scores: Array = []
	var best := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 150)

	func _draw() -> void:
		var font := NestTheme.font
		var top := 1
		for score in scores:
			top = maxi(top, int(score))
		var slots := Save.RECENT_RUNS
		var gap := 8.0
		var width := (size.x-gap*(slots+1))/slots
		var base := size.y-8
		var tall := size.y-40
		draw_line(Vector2(4, base), Vector2(size.x-4, base), NestTheme.INK, 3, true)
		for i in scores.size():
			var score := int(scores[i])
			var height := maxf(6, tall*score/top)
			var rect := Rect2(gap+i*(width+gap), base-height, width, height)
			var fill := NestTheme.SUN if score >= best and best > 0 else NestTheme.WOOD_LIGHT
			var style := NestTheme.box(fill, 6, NestTheme.INK, 3)
			style.corner_radius_bottom_left = 0
			style.corner_radius_bottom_right = 0
			draw_style_box(style, rect)
			var text := str(score)
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
			draw_string(font, Vector2(rect.get_center().x-text_size.x*.5, rect.position.y-6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, NestTheme.INK)
