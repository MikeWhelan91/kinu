class_name WardrobeScreen
extends RefCounted
## Everything you own, in one place, ready to wear or use.

static var cards: Array[Dictionary] = []

const NONE_TITLES := {"outfit": "No Outfit"}

static func show(app: Node) -> void:
	app._new_screen("wardrobe", true)
	cards.clear()
	var back: Callable = app.wardrobe_back if app.wardrobe_back.is_valid() else app._home
	var layout: VBoxContainer = app._header("Wardrobe", back)
	layout.add_child(KinuShopScreen.tabs(app, app.wardrobe_tab, func(tab: String) -> void:
		app.wardrobe_tab = tab
		show(app)
	, "wardrobe"))
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var list: VBoxContainer = app._vbox(scroll, 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := CardGrid.grid(list)
	var catalog: KinuCatalog = app.run.catalog
	var kind := KinuShopScreen.kind_of(app.wardrobe_tab)
	if NONE_TITLES.has(kind):
		_card(app, grid, kind, "", NONE_TITLES[kind], KinuShopScreen.kinu_preview(catalog.flavours[0], null, true))
	for item in KinuShopScreen.items(catalog, kind):
		if Save.owns(kind, item.id, item.price):
			_card(app, grid, kind, item.id, item.display_name, KinuShopScreen.preview(catalog, kind, item))
	if grid.get_child_count() <= 1:
		app._center_label(list, "Nothing here yet.", 18)
	var more := NestTheme.button("Get More In The Shop", func() -> void:
		app.shop_tab = app.wardrobe_tab
		app._shop()
	, false, "wardrobe")
	more.custom_minimum_size = Vector2(0, 58)
	more.add_theme_font_size_override("font_size", 20)
	var more_row := CenterContainer.new()
	more_row.add_child(more)
	list.add_child(more_row)
	var note := "Each room plays its own music." if kind == "room" else "Earn even more by playing. See the Kinu Book."
	app._center_label(layout, note, 15, NestTheme.MUTED)

static func _card(app: Node, grid: GridContainer, kind: String, id: String, title: String, preview: Control) -> void:
	var built := CardGrid.card(grid, preview, title, CardGrid.tint(grid.get_child_count()), func() -> void:
		Save.buy(kind, id, 0)
		if kind == "room":
			Sound.play_room_music(id)
		for card in cards:
			_style(card)
	, 246, "wardrobe")
	var card := {"kind": kind, "id": id, "button": built.button, "status": built.status}
	cards.append(card)
	_style(card)

static func _style(card: Dictionary) -> void:
	for child in card.status.get_children():
		child.queue_free()
	var using: bool = str(Save.data[card.kind]) == card.id
	var wearable: bool = card.kind == "outfit"
	NestTheme.style_card(card.button, "active" if using else "plain")
	if using:
		card.status.add_child(NestTheme.pill("Wearing" if wearable else "In Use", 15))
	else:
		card.status.add_child(NestTheme.pill("Tap To Wear" if wearable else "Tap To Use", 15, NestTheme.MUTED))
