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
		var button := NestTheme.tab(filter, app.collection_filter == filter, func() -> void:
			app.collection_filter = filter
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
		if (app.collection_filter == "Found" and not known) or (app.collection_filter == "Missing" and known):
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
		, 246, "book")
		if known and Save.is_fresh(fresh_key):
			_badge(card.button, 1, true)
		if not known:
			NestTheme.style_card(card.button, "locked")
		var status := NestTheme.t("Pile %d Kinu")%flavour.unlock_kinu if locked else ("Not found yet" if not known else (flavour.rarity() if in_mix else "Not in the mix"))
		card.status.add_child(NestTheme.pill(status, 14, NestTheme.MUTED if not known else NestTheme.INK))
	if grid.get_child_count() == 0:
		app._center_label(list, "Every flavour found. Amazing!", 18)

static func _collection(app: Node, layout: VBoxContainer) -> void:
	# Give the tap a frame to paint the new header before constructing dozens of 3D previews. The
	# cards then arrive in small batches, avoiding the long frozen-looking transition on phones.
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
	var previews_built := 0
	for entry in KinuShopScreen.TABS:
		var kind: String = entry[2]
		CardGrid.heading(list, entry[1])
		var grid := CardGrid.grid(list)
		var entries: Array = KinuShopScreen.items(catalog, kind).duplicate()
		entries.sort_custom(func(a: Resource, b: Resource) -> bool: return Save.owns(kind, a.id, a.price) and not Save.owns(kind, b.id, b.price))
		for item in entries:
			var have := Save.owns(kind, item.id, item.price)
			var preview := KinuShopScreen.preview(catalog, kind, item)
			if not have:
				preview.modulate = Color(.62, .56, .52)
			var fresh_key: String = kind+":"+item.id
			var card := CardGrid.card(grid, preview, item.display_name, CardGrid.tint(grid.get_child_count()), func() -> void:
				Save.clear_fresh(fresh_key)
				_collection_tapped(app, kind, item)
			, 272 if item.goal != "" else 246, "book")
			_collection_status(card, kind, item)
			if have and Save.is_fresh(fresh_key):
				_badge(card.button, 1, true)
			previews_built += 1
			if previews_built % 2 == 0:
				await app.get_tree().process_frame
				if not _still_showing_collection(app, layout, target_screen):
					return
	app._center_label(layout, "Earn rewards by playing, or buy them in the Shop.", 15, NestTheme.MUTED)

static func _still_showing_collection(app: Node, layout, target_screen) -> bool:
	return is_instance_valid(layout) and is_instance_valid(target_screen) and app.screen == target_screen and app.page == "collection" and app.book_tab == "collection"

static func _collection_status(card: Dictionary, kind: String, item: Resource) -> void:
	if Save.owns(kind, item.id, item.price):
		NestTheme.style_card(card.button, "plain")
		card.status.add_child(NestTheme.pill("Owned", 15))
		return
	NestTheme.style_card(card.button, "locked")
	if item.goal == "":
		card.status.add_child(NestTheme.bean_pill(NestTheme.t("Shop · %s")%str(int(item.price)), 15))
		return
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size.x = 170
	var goal := NestTheme.label(KinuProgress.goal_text(item), 13, NestTheme.CREAM)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.add_theme_color_override("font_outline_color", NestTheme.INK)
	goal.add_theme_constant_override("outline_size", 5)
	box.add_child(goal)
	box.add_child(NestTheme.progress(KinuProgress.stat(item.goal), item.goal_amount))
	card.status.add_child(box)

static func _collection_tapped(app: Node, kind: String, item: Resource) -> void:
	if Save.owns(kind, item.id, item.price):
		app._wardrobe_from_book(kind, item)
		return
	if item.goal == "":
		app._shop_from_book(kind, item)
		return
	var stack = app._modal(NestTheme.t(item.display_name))
	app._paper_text(stack, NestTheme.t("%s to earn this.")%KinuProgress.goal_text(item), 20)
	var progress_row := VBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 4)
	var amount := "%s / %s"%[app._number(mini(KinuProgress.stat(item.goal), item.goal_amount)), app._number(item.goal_amount)]
	if item.goal == "height":
		amount = "%s / %s"%[KinuFlavour.height_text(KinuProgress.stat(item.goal)), KinuFlavour.height_text(item.goal_amount)]
	var label := NestTheme.headline(amount, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_row.add_child(label)
	progress_row.add_child(NestTheme.progress(KinuProgress.stat(item.goal), item.goal_amount))
	stack.add_child(progress_row)
	stack.add_child(NestTheme.button("Okay", app._close_modal, true, "book"))

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
	holder.add_child(preview)
	stage.add_child(holder)
	stack.add_child(stage)
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
