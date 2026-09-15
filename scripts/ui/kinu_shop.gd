class_name KinuShopScreen
extends RefCounted
## Spend soybeans on costumes (finishes and onesies), box skins and room themes.

const TABS := [["costume", "Costumes"], ["box", "Boxes"], ["room", "Rooms"]]

static func show(app: Node) -> void:
	app._new_screen("shop",true)
	var layout = app._header("Kinu Shop")
	var balance_row = CenterContainer.new()
	balance_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance_row.add_child(NestTheme.bean_pill("%s beans"%app._number(Save.data.beans),22))
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
	var owned: bool = Save.owns(kind,id,price)
	var using := equipped(kind,id)
	var button := NestTheme.button("",func() -> void: _choose(app,kind,id,title,price),using)
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
	if using:
		status.add_child(NestTheme.label("Wearing" if kind in ["outfit", "finish"] else "In use",16,NestTheme.INK))
	elif owned:
		status.add_child(NestTheme.label("Tap to wear" if kind in ["outfit", "finish"] else "Tap to use",16,NestTheme.MUTED))
	else:
		status.add_child(NestTheme.bean_pill(str(price),16))

static func _choose(app: Node, kind: String, id: String, title: String, price: int) -> void:
	if Save.owns(kind,id,price):
		Save.buy(kind,id,price)
		app.run.refresh_decor()
		show(app)
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
			app.run.refresh_decor()
		show(app)
	,true))
	stack.add_child(NestTheme.button("Not yet",app._close_modal))
