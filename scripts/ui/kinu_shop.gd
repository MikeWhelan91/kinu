class_name KinuShopScreen
extends RefCounted
## The bean shop: outfits, boxes and rooms for sale. Wearing things happens in the
## Wardrobe; rewards earned by playing live in the Kinu Book.

## Tabs as [tab id, title, save kind].
const TABS := [["outfit", "Outfits", "outfit"], ["box", "Boxes", "box"], ["room", "Rooms", "room"]]
const HINTS := {"outfit": "Outfits dress every Kinu you stack.", "box": "Same size box, fresh new look.", "room": "Change where Kinu lives, with its own music."}

static var cards: Array[Dictionary] = []
static var balance: PanelContainer

static func kind_of(tab: String) -> String:
	for entry in TABS:
		if entry[0] == tab:
			return entry[2]
	return "outfit"

static func tab_of(kind: String) -> String:
	for entry in TABS:
		if entry[2] == kind:
			return entry[0]
	return "outfit"

static func show(app: Node) -> void:
	app._new_screen("shop", true)
	cards.clear()
	var back: Callable = app.shop_back if app.shop_back.is_valid() else app._home
	var layout: VBoxContainer = app._header("Kinu Shop", back)
	var balance_row := CenterContainer.new()
	balance_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance = NestTheme.bean_pill(NestTheme.t("%s beans")%app._number(Save.data.beans), 22)
	balance_row.add_child(balance)
	layout.add_child(balance_row)
	var get_beans := NestTheme.button("Get Beans & Extras  +", app._bean_shop, true)
	get_beans.name = "GetBeans"
	get_beans.custom_minimum_size.y = 54
	get_beans.add_theme_font_size_override("font_size", 20)
	layout.add_child(get_beans)
	layout.add_child(tabs(app, app.shop_tab, func(tab: String) -> void:
		app.shop_tab = tab
		show(app)
	))
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var list: VBoxContainer = app._vbox(scroll, 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := CardGrid.grid(list)
	var kind := kind_of(app.shop_tab)
	# Cheapest first, so each shelf climbs from common to epic.
	var stock := items(app.run.catalog, kind).filter(func(item: Resource) -> bool: return item.goal == "" and int(item.price) > 0)
	stock.sort_custom(func(a: Resource, b: Resource) -> bool: return int(a.price) < int(b.price))
	for item in stock:
		var built := CardGrid.card(grid, preview(app.run.catalog, kind, item), item.display_name, CardGrid.tint(grid.get_child_count()), func() -> void: _choose(app, kind, item), 210, "tap", 200, 19, kind == "room")
		var card := {"kind": kind, "item": item, "button": built.button, "status": built.status}
		cards.append(card)
		_style_card(card)
	app._center_label(layout, HINTS[app.shop_tab], 15, NestTheme.MUTED)

## The four category tabs shared by the Shop and Wardrobe.
static func tabs(app: Node, current: String, pick: Callable, sound: String = "tap") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for entry in TABS:
		var button := NestTheme.tab(entry[1], current == entry[0], func() -> void: pick.call(entry[0]), sound)
		button.add_theme_font_size_override("font_size", 15)
		row.add_child(button)
	return row

static func items(catalog: KinuCatalog, kind: String) -> Array:
	match kind:
		"outfit":
			return catalog.outfits
	return catalog.decor_of(kind)

static func preview(catalog: KinuCatalog, kind: String, item: Resource, pixels: Vector2i = Vector2i(170, 124), interactive: bool = false) -> Control:
	match kind:
		"outfit":
			if item and item.finish:
				return kinu_preview(item.finish, null, false, pixels, interactive)
			return kinu_preview(catalog.flavours[0], item, true, pixels, interactive)
		"box":
			var box := DecorPreview.new()
			box.setup_box(item, pixels)
			if interactive:
				box.enable_spin()
			return box
	return DecorPreview.room_swatch(item, pixels)

static func kinu_preview(look: KinuFlavour, outfit: KinuOutfit, wide: bool, pixels: Vector2i = Vector2i(170, 124), interactive: bool = false) -> KinuPreview:
	var node := KinuPreview.new()
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	node.setup(catalog.shapes[0], look, true, pixels, "calm", outfit, wide)
	if interactive:
		node.enable_spin()
		node.fit_model(1.12)
	return node

## A full inspection panel shared by the Shop and Wardrobe. It uses a live model rather than the
## grid thumbnail, so hats, tails, wings and box sides remain intact at this larger scale.
static func showcase(app: Node, kind: String, item: Resource, action: Callable, action_label: String) -> void:
	var stack = app._modal(NestTheme.t(item.display_name))
	if KinuCatcher.TIER_COLORS.has(item.rarity):
		var board: SignBoard = stack.get_parent() as SignBoard
		if board:
			board.set_tint(KinuCatcher.TIER_COLORS[item.rarity])
	var stage := NestTheme.stage(NestTheme.STAGES[2])
	stack.add_child(stage)
	var pixels := Vector2i(300, 170) if kind == "room" else Vector2i(280, 190)
	var featured := preview(app.run.catalog, kind, item, pixels, kind != "room")
	if kind == "room":
		featured.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(featured)
	else:
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(holder)
		holder.add_child(featured)
	if kind != "room":
		var hint := NestTheme.label("Drag to spin", 14, NestTheme.MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(hint)
	if item.description != "":
		app._paper_text(stack, item.description, 18)
	stack.add_child(NestTheme.button(action_label, action, true, "book"))
	stack.add_child(NestTheme.button("Not Yet", app._close_modal, false, "book"))

static func _style_card(card: Dictionary) -> void:
	var item: Resource = card.item
	for child in card.status.get_children():
		child.queue_free()
	NestTheme.style_card(card.button, "plain")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	card.status.add_child(row)
	var tier := KinuCatcher.tier_pill(item.rarity)
	if tier:
		row.add_child(tier)
	if Save.owns(card.kind, item.id, item.price):
		row.add_child(NestTheme.pill("Owned", 15, NestTheme.MUTED))
	else:
		row.add_child(NestTheme.bean_pill(str(item.price), 16))

static func _refresh(app: Node) -> void:
	for card in cards:
		_style_card(card)
	var label: Label = balance.get_child(0).get_child(1)
	label.text = NestTheme.t("%s beans")%app._number(Save.data.beans)

static func _choose(app: Node, kind: String, item: Resource) -> void:
	if Save.owns(kind, item.id, item.price):
		showcase(app, kind, item, func() -> void:
			app.wardrobe_tab = tab_of(kind)
			app._wardrobe()
		, "Open Wardrobe")
		return
	showcase(app, kind, item, func() -> void:
		purchase(app, kind, item, func() -> void: _refresh(app))
	, "Buy for %s beans"%app._number(item.price))

## The buy popup, also opened from the Kinu Book's collection.
static func purchase(app: Node, kind: String, item: Resource, done: Callable) -> void:
	var stack = app._modal(NestTheme.t(item.display_name))
	var short: int = int(item.price)-int(Save.data.beans)
	if short > 0:
		app._paper_text(stack, NestTheme.t("You need %d more beans.\nPile more Kinu and finish daily missions to earn them!")%short, 19)
		stack.add_child(NestTheme.button("Get Beans", app._bean_shop, true))
		stack.add_child(NestTheme.button("Okay", app._close_modal, true))
		return
	var price_row := CenterContainer.new()
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(NestTheme.bean_pill(NestTheme.t("%d beans")%int(item.price), 20))
	stack.add_child(price_row)
	stack.add_child(NestTheme.button("Buy & Wear" if kind == "outfit" else "Buy & Use", func() -> void:
		if Save.buy(kind, item.id, item.price):
			Sound.play("cashregister")
			Haptics.pulse(30, .5)
		app._close_modal()
		done.call()
	, true))
	stack.add_child(NestTheme.button("Not Yet", app._close_modal))
