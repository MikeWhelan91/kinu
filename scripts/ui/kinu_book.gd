class_name KinuBookScreen
extends RefCounted
## The Kinu Book: every flavour found while stacking, a checklist of every outfit,
## box and room with how to get it, and the player's lifetime records.

static func show(app: Node) -> void:
	app._new_screen("collection", true)
	var layout = app._header("Kinu Book")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	for tab in [["flavours", "Flavours", "flavour:"], ["collection", "Collection", ""], ["records", "Records", "-"]]:
		var button := NestTheme.tab(tab[1], app.book_tab == tab[0], func() -> void:
			app.book_tab = tab[0]
			show(app)
		, "book")
		tabs.add_child(button)
		if tab[2] == "-":
			continue
		var fresh: int = Save.fresh_count(tab[2]) if tab[2] != "" else Save.fresh_count()-Save.fresh_count("flavour:")
		_badge(button, fresh)
	if app.book_tab == "collection":
		_collection(app, layout)
	elif app.book_tab == "records":
		KinuRecords.show(app, layout)
	else:
		_flavours(app, layout)

static func _flavours(app: Node, layout: VBoxContainer) -> void:
	var flavours: Array[KinuFlavour] = app.run.catalog.flavours
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	layout.add_child(filter_row)
	for filter in ["All", "Found", "Missing"]:
		var button := NestTheme.tab(filter, app.flavour_filter == filter, func() -> void:
			app.flavour_filter = filter
			app._collection()
		, "book")
		button.custom_minimum_size.y = 52
		button.add_theme_font_size_override("font_size", 15)
		filter_row.add_child(button)
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var list: VBoxContainer = app._vbox(scroll, 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var count := NestTheme.pill(NestTheme.t("%d / %d flavours found")%[found(flavours), flavours.size()], 18)
	var count_row := CenterContainer.new()
	count_row.add_child(count)
	list.add_child(count_row)
	var grid := CardGrid.grid(list)
	var block: KinuShape = app.run.catalog.shapes[0]
	for i in flavours.size():
		var flavour := flavours[i]
		var locked: bool = not Save.flavour_unlocked(flavour)
		var known: bool = Save.flavour_found(flavour)
		var in_mix: bool = Save.flavour_in_mix(flavour.id)
		if (app.flavour_filter == "Found" and not known) or (app.flavour_filter == "Missing" and known):
			continue
		var preview := KinuPreview.new()
		preview.setup(block, flavour, known, Vector2i(170, 124), "calm" if known else "worried")
		if known and not in_mix:
			preview.modulate.a = .4
		var fresh_key := "flavour:"+flavour.id
		var card := CardGrid.card(grid, preview, flavour.display_name if known else "???", CardGrid.tint(i), func() -> void:
			if Save.is_fresh(fresh_key):
				Save.clear_fresh(fresh_key)
				show(app)
			app._flavour_detail(flavour, known)
		, 210, "book")
		if known and Save.is_fresh(fresh_key):
			_badge(card.button, 1, true)
		if not known:
			NestTheme.style_card(card.button, "locked")
		var status := NestTheme.t("Pile %d Kinu")%flavour.unlock_kinu if locked else ("Not found yet" if not known else (flavour.rarity() if in_mix else "Not in the mix"))
		card.status.add_child(NestTheme.pill(status, 14, NestTheme.MUTED if not known else NestTheme.INK))
	if grid.get_child_count() == 0:
		app._center_label(list, "Every flavour found. Amazing!", 18)

const RARITY_ORDER := {"": 0, "common": 1, "rare": 2, "epic": 3, "legendary": 4}

static func _collection(app: Node, layout: VBoxContainer) -> void:
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	layout.add_child(filter_row)
	for filter in ["All", "Owned", "Unowned"]:
		var button := NestTheme.tab(filter, app.collection_filter == filter, func() -> void:
			app.collection_filter = filter
			show(app)
		, "book")
		button.custom_minimum_size.y = 52
		button.add_theme_font_size_override("font_size", 15)
		filter_row.add_child(button)
	# Give the tap a frame to paint the new header before building the grid. Thumbnails are
	# pre-baked image files (tools/bake_collection_thumbs.gd), not a live render, so nothing here
	# needs to wait on rendering the way it used to.
	var target_screen: Control = app.screen
	var loading_row := CenterContainer.new()
	loading_row.name = "CollectionLoading"
	loading_row.add_child(NestTheme.pill("Opening collection…", 18))
	layout.add_child(loading_row)
	await app.get_tree().process_frame
	if not _still_showing_collection(app, layout, target_screen):
		return
	loading_row.queue_free()
	var catalog: KinuCatalog = app.run.catalog
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var list: VBoxContainer = app._vbox(scroll, 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var owned := 0
	var total := 0
	for entry in KinuShopScreen.TABS:
		for item in KinuShopScreen.items(catalog, entry[2]):
			total += 1
			if Save.owns(entry[2], item.id, item.price):
				owned += 1
	var count_row := CenterContainer.new()
	count_row.add_child(NestTheme.pill(NestTheme.t("%d / %d collected")%[owned, total], 18))
	list.add_child(count_row)
	for entry in KinuShopScreen.TABS:
		var kind: String = entry[2]
		var entries: Array = KinuShopScreen.items(catalog, kind).duplicate()
		entries.sort_custom(func(a: Resource, b: Resource) -> bool:
			var ra: int = RARITY_ORDER.get(a.rarity, 0)
			var rb: int = RARITY_ORDER.get(b.rarity, 0)
			if ra != rb:
				return ra < rb
			var oa := Save.owns(kind, a.id, a.price)
			var ob := Save.owns(kind, b.id, b.price)
			return oa and not ob
		)
		entries = entries.filter(func(item: Resource) -> bool:
			var have := Save.owns(kind, item.id, item.price)
			return app.collection_filter == "All" or (app.collection_filter == "Owned" and have) or (app.collection_filter == "Unowned" and not have)
		)
		if entries.is_empty():
			continue
		CardGrid.heading(list, entry[1])
		var grid := CardGrid.grid(list, 3)
		for item in entries:
			var have := Save.owns(kind, item.id, item.price)
			var preview := _thumb(catalog, kind, item)
			if not have:
				preview.modulate = Color(.62, .56, .52)
			var fresh_key: String = kind+":"+item.id
			var card := CardGrid.card(grid, preview, item.display_name, _tier_tint(item.rarity, grid.get_child_count()), func() -> void:
				Save.clear_fresh(fresh_key)
				_item_detail(app, kind, item)
			, 196, "book", 150, 15, kind == "room")
			_collection_status(card, kind, item)
			if have and Save.is_fresh(fresh_key):
				_badge(card.button, 1, true)
	app._center_label(layout, "Tap a card for a closer look.", 15, NestTheme.MUTED)

## A small thumbnail for the collection grid: a pre-baked image for outfits and boxes, or a fresh
## room swatch, which draws as flat Control and needs no image at all.
static func _thumb(catalog: KinuCatalog, kind: String, item: Resource) -> Control:
	if kind == "room":
		# Inset on the card's tinted stage, so a row of rooms matches the outfits and decor
		# beside them instead of covering its tile edge to edge.
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(126, 118)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(DecorPreview.room_swatch(item, Vector2i(112, 100)))
		return holder
	var texture: Texture2D = CollectionThumb.outfit(item) if kind == "outfit" else CollectionThumb.box(item)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(126, 118)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func _still_showing_collection(app: Node, layout, target_screen) -> bool:
	return is_instance_valid(layout) and is_instance_valid(target_screen) and app.screen == target_screen and app.page == "collection" and app.book_tab == "collection"

## A card's backdrop colour: a pastel tint of its own rarity colour, so common/rare/epic/legendary
## read at a glance across the whole grid, the same colours as each tier's pill. Earned rewards
## have no rarity, so they keep cycling through the plain Shop palette instead.
static func _tier_tint(rarity: String, index: int) -> Color:
	if rarity == "legendary":
		return Color("f2c14e")
	if KinuCatcher.TIER_COLORS.has(rarity):
		return KinuCatcher.TIER_COLORS[rarity].lightened(.6)
	return CardGrid.tint(index)

static func _collection_status(card: Dictionary, kind: String, item: Resource) -> void:
	# Pills stack instead of sitting side by side: a 3-column card is too narrow for two pills
	# in a row, and a stack never forces the card wider than its thumbnail.
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	# A CenterContainer shrinks its child to that child's own minimum size, and an autowrapped
	# Label with nothing forcing a width reports almost none — a fixed width here is what stops
	# the goal text collapsing into a single letter per line.
	box.custom_minimum_size.x = 126
	card.status.add_child(box)
	var tier := KinuCatcher.tier_pill(item.rarity, 16)
	if tier:
		var tier_row := CenterContainer.new()
		tier_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tier_row.add_child(tier)
		box.add_child(tier_row)
	if Save.owns(kind, item.id, item.price):
		NestTheme.style_card(card.button, "plain")
		CardGrid.corner_badge(card.stage, NestTheme.pill("Owned", 13))
		return
	NestTheme.style_card(card.button, "locked")
	# No "Catcher"/price pill here — the tier pill above is enough at a glance, and the full
	# story (Claw Machine only, or its bean price) is one tap away in the info panel.
	if item.crane_only or item.goal == "":
		return
	# The goal text itself (e.g. "Glaze 50 Kinu with shoyu") is dropped here — a 3-column card is
	# too narrow for a full sentence. The bar alone is enough of a hint; the full text is one tap
	# away in the info panel.
	box.add_child(NestTheme.progress(KinuProgress.stat(item.goal), item.goal_amount))

## A cosy info panel for a Collection card: a larger view, its descriptor, and how it's obtained.
## Never navigates away to the Shop or Wardrobe; tapping only ever opens this same panel.
static func _item_detail(app: Node, kind: String, item: Resource) -> void:
	Save.clear_fresh(kind+":"+item.id)
	var have := Save.owns(kind, item.id, item.price)
	var stack = app._modal(NestTheme.t(item.display_name))
	_apply_rarity_board(stack, item.rarity)
	var stage := NestTheme.stage(NestTheme.STAGES[2])
	stack.add_child(stage)
	var preview := _big_preview(app.run.catalog, kind, item, have)
	if kind == "room":
		# Rooms are complete artwork, not a small object to centre. Fill the whole framed area so
		# no stage colour appears as empty bands at either side of the scene.
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(preview)
	else:
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(holder)
		holder.add_child(preview)
	if have:
		CardGrid.corner_badge(stage, NestTheme.pill("Owned", 14))
	if kind != "room":
		var spin_hint := NestTheme.label("Drag to spin", 14, NestTheme.MUTED)
		spin_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(spin_hint)
	if item.description != "":
		app._paper_text(stack, item.description, 19)
	var status_row := CenterContainer.new()
	var pills := HBoxContainer.new()
	pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pills.add_theme_constant_override("separation", 6)
	status_row.add_child(pills)
	if KinuCatcher.tier_pill(item.rarity, 17):
		pills.add_child(KinuCatcher.tier_pill(item.rarity, 17))
	elif item.crane_only:
		pills.add_child(NestTheme.pill("Only in the Kinu Claw", 13, NestTheme.PURPLE))
	elif item.goal == "":
		pills.add_child(NestTheme.bean_pill(str(int(item.price)), 15))
	stack.add_child(status_row)
	# Every tile says how it is come by, so tapping one always answers "how do I get this?".
	if item.crane_only:
		app._paper_text(stack, NestTheme.t("Only won in the Kinu Claw."), 16)
	elif item.goal != "":
		app._paper_text(stack, NestTheme.t("%s to earn this.")%KinuProgress.goal_text(item), 16)
	elif float(item.price) > 0:
		app._paper_text(stack, NestTheme.t("Sold in the Shop for %d beans.")%int(item.price), 16)
	if not have and item.goal != "":
		var progress_row := VBoxContainer.new()
		progress_row.add_theme_constant_override("separation", 4)
		var amount := "%s / %s"%[app._number(mini(KinuProgress.stat(item.goal), item.goal_amount)), app._number(item.goal_amount)]
		if item.goal == "height":
			amount = "%s / %s"%[KinuFlavour.height_text(KinuProgress.stat(item.goal)), KinuFlavour.height_text(item.goal_amount)]
		var label := NestTheme.headline(amount, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_row.add_child(label)
		progress_row.add_child(NestTheme.progress(KinuProgress.stat(item.goal), item.goal_amount))
		stack.add_child(progress_row)
	stack.add_child(NestTheme.button("Lovely" if have else "Okay", app._close_modal, true, "book"))

static func _apply_rarity_board(stack: VBoxContainer, rarity: String) -> void:
	if not KinuCatcher.TIER_COLORS.has(rarity):
		return
	var board: SignBoard = stack.get_parent() as SignBoard
	if board:
		board.set_tint(KinuCatcher.TIER_COLORS[rarity])

## The info panel is a real showcase, not a magnified 220px grid thumbnail. Live previews fit
## their whole silhouette in the roomy stage and can be spun to inspect every side.
static func _big_preview(catalog: KinuCatalog, kind: String, item: Resource, have: bool) -> Control:
	var pixels := Vector2i(300, 170) if kind == "room" else Vector2i(280, 190)
	var preview := KinuShopScreen.preview(catalog, kind, item, pixels, kind != "room")
	if not have:
		preview.modulate = Color(.62, .56, .52)
	return preview

## Red count in the top-right corner of a tab or card, for unlocks not looked at yet.
## Cards sit inside a scroll area that clips, so their badge tucks inside the corner (`inset`).
static func _badge(target: Control, count: int, inset: bool = false) -> void:
	if count <= 0:
		return
	var badge := NestTheme.count_badge(count)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_top = 2 if inset else -10
	badge.offset_right = -2 if inset else 8
	target.add_child(badge)

static func found(flavours: Array[KinuFlavour]) -> int:
	var count := 0
	for flavour in flavours:
		if Save.flavour_found(flavour):
			count += 1
	return count

static func flavour_detail(app: Node, flavour: KinuFlavour, known: bool) -> void:
	var stack = app._modal(NestTheme.t("%s Kinu")%NestTheme.t(flavour.display_name) if known else NestTheme.t("A Flavour To Find"))
	var stage := NestTheme.stage(NestTheme.STAGES[2])
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := KinuPreview.new()
	preview.setup(app.run.catalog.shapes[0], flavour, known, Vector2i(260, 180), "happy" if known else "worried")
	preview.enable_spin()
	preview.fit_model(1.12)
	holder.add_child(preview)
	stage.add_child(holder)
	stack.add_child(stage)
	var spin_hint := NestTheme.label("Drag to spin", 14, NestTheme.MUTED)
	spin_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(spin_hint)
	var waiting := NestTheme.t("Pile %d Kinu in one run to unlock this flavour.")%flavour.unlock_kinu if not Save.flavour_unlocked(flavour) else "Keep piling. This flavour turns up now and then."
	app._paper_text(stack, flavour.description if known else waiting, 19)
	if not known:
		stack.add_child(NestTheme.button("Okay", app._close_modal, true, "book"))
		return
	var rarity_row := CenterContainer.new()
	rarity_row.add_child(NestTheme.pill(flavour.rarity(), 16, NestTheme.SKY.darkened(.2)))
	stack.add_child(rarity_row)
	var in_mix: bool = Save.flavour_in_mix(flavour.id)
	var others_on: bool = app.run.flavour_mix().size() > 1 or not in_mix
	var toggle := NestTheme.button(NestTheme.t("In The Mix: %s")%NestTheme.t("On" if in_mix else "Off"), func() -> void:
		if in_mix and not others_on:
			return
		Sound.play("plop")
		Save.set_flavour_in_mix(flavour.id, not in_mix)
		app._collection()
		app._flavour_detail(flavour, known)
	, false, "book")
	stack.add_child(toggle)
	var note := NestTheme.label("Switched off flavours won't appear while you stack." if others_on else "Keep at least one flavour in the mix.", 14, NestTheme.CREAM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_outline_color", NestTheme.INK)
	note.add_theme_constant_override("outline_size", 5)
	stack.add_child(note)
	stack.add_child(NestTheme.button("Lovely", func() -> void:
		Sound.play("plop")
		app._close_modal.call()
	, true, "book"))
