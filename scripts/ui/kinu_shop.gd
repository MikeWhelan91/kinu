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
	for item in items(app.run.catalog, kind):
		if item.goal == "" and int(item.price) > 0:
			var built := CardGrid.card(grid, preview(app.run.catalog, kind, item), item.display_name, CardGrid.tint(grid.get_child_count()), func() -> void: _choose(app, kind, item))
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

static func preview(catalog: KinuCatalog, kind: String, item: Resource) -> Control:
	match kind:
		"outfit":
			if item and item.finish:
				return kinu_preview(item.finish, null, false)
			return kinu_preview(catalog.flavours[0], item, true)
		"box":
			var box := DecorPreview.new()
			box.setup_box(item, Vector2i(170, 124))
			return box
	var room := DecorPreview.new()
	room.setup_room(item, Vector2i(170, 124))
	return room

static func kinu_preview(look: KinuFlavour, outfit: KinuOutfit, wide: bool) -> KinuPreview:
	var node := KinuPreview.new()
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	node.setup(catalog.shapes[0], look, true, Vector2i(170, 124), "calm", outfit, wide)
	return node

static func _style_card(card: Dictionary) -> void:
	var item: Resource = card.item
	for child in card.status.get_children():
		child.queue_free()
	NestTheme.style_card(card.button, "plain")
	if Save.owns(card.kind, item.id, item.price):
		card.status.add_child(NestTheme.pill("Owned", 15, NestTheme.MUTED))
	else:
		card.status.add_child(NestTheme.bean_pill(str(item.price), 16))

static func _refresh(app: Node) -> void:
	for card in cards:
		_style_card(card)
	var label: Label = balance.get_child(0).get_child(1)
	label.text = NestTheme.t("%s beans")%app._number(Save.data.beans)

static func _choose(app: Node, kind: String, item: Resource) -> void:
	if Save.owns(kind, item.id, item.price):
		app.wardrobe_tab = tab_of(kind)
		app._wardrobe()
		return
	purchase(app, kind, item, func() -> void: _refresh(app))

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
