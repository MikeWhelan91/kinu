class_name MyKinuScreen
extends RefCounted
## Dress up My Kinu: pick a favourite flavour as its base, then a part for each open slot. A live
## preview turns through every shape, because every Kinu dropped in a run wears this look.

const TABS := ["flavour", "body", "hat", "arms", "glasses"]
static var tab := "flavour"
static var shape_index := 0
static var back: Callable

static func show(app: Node, back_to: Callable = Callable()) -> void:
	if back_to.is_valid():
		back = back_to
	if not back.is_valid():
		back = app._show_wardrobe
	var catalog: KinuCatalog = app.run.catalog
	app._new_screen("my_kinu", true)
	var layout: VBoxContainer = app._header("My Kinu", back)
	layout.add_child(_hero(app, catalog))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	for id in TABS:
		var title := "Flavour" if id == "flavour" else str(MyKinu.SLOT_NAMES[id])
		var button := NestTheme.tab(title, tab == id, func() -> void:
			tab = id
			show(app)
		, "wardrobe")
		button.name = "Tab_"+id
		button.add_theme_font_size_override("font_size", 14)
		if id != "flavour" and not MyKinu.slot_unlocked(id):
			button.text = NestTheme.t("%s\nLv %d")%[NestTheme.t(title), MyKinu.slot_level(id)]
			button.add_theme_font_size_override("font_size", 12)
		tabs.add_child(button)
	layout.add_child(tabs)
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	KinuShopScreen.remember_scroll(scroll, "my_kinu:"+tab)
	var list: VBoxContainer = app._vbox(scroll, 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := CardGrid.grid(list, 3)
	if tab == "flavour":
		_flavours(app, catalog, grid)
	else:
		_parts(app, catalog, grid, tab)
		if not MyKinu.slot_unlocked(tab):
			app._center_label(list, NestTheme.t("This slot opens at level %d. Parts you own now are ready to wear then.")%MyKinu.slot_level(tab), 15, NestTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var more := NestTheme.button("Get More In The Shop", func() -> void:
			app.shop_tab = "part"
			KinuShopScreen.part_slot = tab
			app.shop_back = func() -> void: show(app)
			app._show_shop()
		, false, "wardrobe")
		more.name = "GetMoreParts"
		more.custom_minimum_size = Vector2(0, 58)
		more.add_theme_font_size_override("font_size", 20)
		var row := CenterContainer.new()
		row.add_child(more)
		list.add_child(row)
	Save.data.my_kinu.seen_level = maxi(int(Save.data.my_kinu.seen_level), MyKinu.level())

## The live preview, level and XP bar, and the button that puts My Kinu on.
static func _hero(app: Node, catalog: KinuCatalog) -> Control:
	var paper := NestTheme.paper()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(column)
	var shape: KinuShape = catalog.shapes[shape_index % catalog.shapes.size()]
	var preview := KinuPreview.new()
	preview.name = "MyKinuPreview"
	preview.setup(shape, MyKinu.base(catalog), true, Vector2i(220, 150), "happy", null, true, false, MyKinu.equipped(catalog))
	preview.enable_spin()
	preview.fit_model(1.12)
	var holder := CenterContainer.new()
	holder.add_child(preview)
	column.add_child(holder)
	var shapes := HBoxContainer.new()
	shapes.alignment = BoxContainer.ALIGNMENT_CENTER
	shapes.add_theme_constant_override("separation", 10)
	var previous := NestTheme.button("‹", func() -> void:
		shape_index = (shape_index+catalog.shapes.size()-1) % catalog.shapes.size()
		show(app)
	, false, "tap")
	var next := NestTheme.button("›", func() -> void:
		shape_index = (shape_index+1) % catalog.shapes.size()
		show(app)
	, false, "tap")
	for button in [previous, next]:
		button.custom_minimum_size = Vector2(52, 44)
	previous.name = "PreviousShape"
	next.name = "NextShape"
	shapes.add_child(previous)
	var shape_name := NestTheme.label(NestTheme.t("%s Kinu")%NestTheme.t(shape.display_name), 17, NestTheme.MUTED)
	shape_name.custom_minimum_size.x = 120
	shape_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shapes.add_child(shape_name)
	shapes.add_child(next)
	column.add_child(shapes)
	var level := MyKinu.level()
	var progress := MyKinu.progress_for(MyKinu.xp())
	var title := NestTheme.label(NestTheme.t("Level %d")%level, 22)
	title.name = "MyKinuLevel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(NestTheme.progress(progress[0], progress[1]))
	var next_line := NestTheme.label(NestTheme.t("%d / %d XP · Next: %s")%[progress[0], progress[1], next_reward(level+1)], 14, NestTheme.MUTED)
	next_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(next_line)
	if MyKinu.active():
		var wearing := CenterContainer.new()
		wearing.add_child(NestTheme.pill("Every Kinu in your runs looks like this", 15))
		column.add_child(wearing)
	else:
		var wear := NestTheme.button("Wear My Kinu", func() -> void:
			MyKinu.wear(catalog, true)
			Analytics.track("my_kinu_worn", {"level": MyKinu.level()})
			show(app)
		, true, "wardrobe")
		wear.name = "WearMyKinu"
		wear.custom_minimum_size.y = 58
		column.add_child(wear)
	return paper

## What reaching `at_level` gives, in a few words.
static func next_reward(at_level: int) -> String:
	for slot in MyKinu.SLOTS:
		if MyKinu.slot_level(slot) == at_level:
			return NestTheme.t("%s slot")%NestTheme.t(MyKinu.SLOT_NAMES[slot])
	if at_level % MyKinu.LEVEL_PART_EVERY == 0:
		var part := MyKinu.level_part(at_level)
		return NestTheme.t(part.display_name) if part else NestTheme.t("%d tickets")%MyKinu.SPARE_TICKETS
	return NestTheme.t("%d beans")%MyKinu.level_beans(at_level)

static func _flavours(app: Node, catalog: KinuCatalog, grid: GridContainer) -> void:
	var shape: KinuShape = catalog.shapes[0]
	var chosen := MyKinu.base(catalog)
	for flavour in catalog.flavours:
		var open := Save.flavour_unlocked(flavour)
		var preview := KinuPreview.new()
		preview.setup(shape, flavour, open, Vector2i(96, 72), "calm")
		preview.fit_model(1.02)
		var title := flavour.display_name if open else "???"
		var built := CardGrid.card(grid, preview, title, CardGrid.tint(grid.get_child_count()), func() -> void:
			if open and MyKinu.choose_flavour(catalog, flavour.id):
				show(app)
		, 150, "wardrobe", 104, 15)
		built.button.name = "Flavour_"+flavour.id
		if flavour == chosen:
			built.status.add_child(NestTheme.pill("Wearing", 13))
		elif not open:
			built.status.add_child(NestTheme.pill(NestTheme.t("Pile %d Kinu")%flavour.unlock_kinu, 13, NestTheme.MUTED))

static func _parts(app: Node, catalog: KinuCatalog, grid: GridContainer, slot: String) -> void:
	var worn := str(Save.data.my_kinu.equipped.get(slot, ""))
	var open := MyKinu.slot_unlocked(slot)
	var options: Array = [null]
	for part in catalog.parts_for(slot):
		if Save.owns("part", part.id, part.price):
			options.append(part)
	for part in options:
		var id: String = part.id if part else ""
		var preview := part_preview(catalog, part, Vector2i(96, 72))
		var built := CardGrid.card(grid, preview, part.display_name if part else "Nothing", CardGrid.tint(grid.get_child_count()), func() -> void:
			if MyKinu.equip(catalog, slot, id):
				Analytics.track("my_kinu_equipped", {"slot": slot, "part": id})
				show(app)
		, 150, "wardrobe", 104, 15)
		built.button.name = "Part_"+(id if id != "" else "none_"+slot)
		if part:
			Save.clear_fresh("part:"+id)
		if not open:
			built.status.add_child(NestTheme.pill(NestTheme.t("Lv %d")%MyKinu.slot_level(slot), 13, NestTheme.MUTED))
		elif worn == id:
			built.status.add_child(NestTheme.pill("Wearing", 13))

## A My Kinu preview wearing only `part` (or nothing), on the player's chosen flavour.
static func part_preview(catalog: KinuCatalog, part: KinuPart, pixels: Vector2i, interactive: bool = false) -> KinuPreview:
	var node := KinuPreview.new()
	var parts: Array = [part] if part else []
	node.setup(catalog.shapes[0], MyKinu.base(catalog), true, pixels, "calm", null, true, false, parts)
	if interactive:
		node.enable_spin()
		node.fit_model(1.12)
	else:
		node.fit_model(1.02)
	return node
