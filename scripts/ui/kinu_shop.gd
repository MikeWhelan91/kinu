class_name KinuShopScreen
extends RefCounted
## Spend soybeans on costumes (finishes and onesies), box skins and room themes.

const TABS := [["costume", "Costumes"], ["box", "Boxes"], ["room", "Rooms"]]

## Cards on the current page, so choosing or buying restyles them in place instead of rebuilding
## every 3D preview.
static var cards: Array[Dictionary] = []
static var balance: PanelContainer

static func show(app: Node) -> void:
	app._new_screen("shop",true)
	cards.clear()
	var layout = app._header("Kinu Shop")
	var balance_row = CenterContainer.new()
	balance_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance = NestTheme.bean_pill("%s beans"%app._number(Save.data.beans),22)
	balance_row.add_child(balance)
	layout.add_child(balance_row)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation",8)
	layout.add_child(tabs)
	for tab in TABS:
		var button = NestTheme.button(tab[1],func() -> void:
			app.shop_tab = tab[0]
			show(app)
		,app.shop_tab == tab[0])
		button.add_theme_font_size_override("font_size",15)
		button.custom_minimum_size.y = 60
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	var scroll = DragScroll.new()
	layout.add_child(scroll)
	var list = app._vbox(scroll,12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var catalog: KinuCatalog = app.run.catalog
	var plain: KinuFlavour = catalog.flavours[0]
	match str(app.shop_tab):
		"costume":
			var finishes := _section(app,list,"Finishes")
			_card(app,finishes,"finish","","Plain tofu",0,_kinu_preview(plain,null,false))
			for finish in catalog.finishes:
				_card(app,finishes,"finish",finish.id,finish.display_name,finish.price,_kinu_preview(finish,null,false))
			var onesies := _section(app,list,"Onesies")
			_card(app,onesies,"outfit","","No onesie",0,_kinu_preview(plain,null,true))
			for outfit in catalog.outfits:
				_card(app,onesies,"outfit",outfit.id,outfit.display_name,outfit.price,_kinu_preview(plain,outfit,true))
		"box", "room":
			var grid := _section(app,list,"")
			for decor in catalog.decor_of(app.shop_tab):
				var preview := DecorPreview.new()
				if decor.kind == "box":
					preview.setup_box(decor,Vector2i(180,130))
				else:
					preview.setup_room(decor,Vector2i(180,130))
				_card(app,grid,decor.kind,decor.id,decor.display_name,decor.price,preview)
	var hints := {"costume": "Finishes and onesies dress every Kinu you stack.", "box": "Same size box, fresh new look.", "room": "Change where Kinu lives."}
	app._center_label(layout,hints[app.shop_tab],15,NestTheme.MUTED)

static func _section(app: Node, list: VBoxContainer, title: String) -> GridContainer:
	if title != "":
		var heading := NestTheme.headline(title,28,NestTheme.SUN)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	list.add_child(grid)
	return grid

static func _kinu_preview(look: KinuFlavour, outfit: KinuOutfit, wide: bool) -> KinuPreview:
	var preview := KinuPreview.new()
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	preview.setup(catalog.shapes[0],look,true,Vector2i(170,130),"calm",outfit,wide)
	return preview

static func equipped(kind: String, id: String) -> bool:
	return str(Save.data[kind]) == id

static func _card(app: Node, grid: GridContainer, kind: String, id: String, title: String, price: int, preview: Control) -> void:
	var button := NestTheme.button("",func() -> void: _choose(app,kind,id,title,price))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(210,232)
	grid.add_child(button)
	var stack: VBoxContainer = app._vbox(button,2)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_top = 8
	stack.offset_bottom = -12
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	stack.add_child(holder)
	app._center_label(stack,title,20)
	var status := CenterContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(status)
	var card := {"kind": kind, "id": id, "price": price, "button": button, "status": status, "state": ""}
	cards.append(card)
	_style_card(card)

## Restyles one card for its current state; skips work when nothing changed.
static func _style_card(card: Dictionary) -> void:
	var kind: String = card.kind
	var wearable := kind in ["outfit", "finish"]
	var state := "using" if equipped(kind,card.id) else ("owned" if Save.owns(kind,card.id,card.price) else "price")
	if state == card.state:
		return
	card.state = state
	NestTheme.set_primary(card.button,state == "using")
	var status: CenterContainer = card.status
	for child in status.get_children():
		child.queue_free()
	match state:
		"using":
			status.add_child(NestTheme.label("Wearing" if wearable else "In use",16,NestTheme.INK))
		"owned":
			status.add_child(NestTheme.label("Tap to wear" if wearable else "Tap to use",16,NestTheme.MUTED))
		_:
			status.add_child(NestTheme.bean_pill(str(card.price),16))

static func _refresh(app: Node) -> void:
	for card in cards:
		_style_card(card)
	var label: Label = balance.get_child(0).get_child(1)
	label.text = "%s beans"%app._number(Save.data.beans)

static func _choose(app: Node, kind: String, id: String, title: String, price: int) -> void:
	# Equipping only restyles cards; the box and room are rebuilt when leaving the shop.
	if Save.owns(kind,id,price):
		Save.buy(kind,id,price)
		_refresh(app)
		return
	var stack = app._modal(title)
	var short: int = price-int(Save.data.beans)
	if short > 0:
		var note = app._center_label(stack,"You need %d more beans.\nBuild taller towers to earn them!"%short,19)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(NestTheme.button("Okay",app._close_modal,true))
		return
	var price_row := CenterContainer.new()
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(NestTheme.bean_pill("%d beans"%price,20))
	stack.add_child(price_row)
	var action := "Buy & wear" if kind in ["outfit", "finish"] else "Buy & use"
	stack.add_child(NestTheme.button(action,func() -> void:
		if Save.buy(kind,id,price):
			Sound.play("record")
			Haptics.pulse(30,.5)
		app._close_modal()
		_refresh(app)
	,true))
	stack.add_child(NestTheme.button("Not yet",app._close_modal))
