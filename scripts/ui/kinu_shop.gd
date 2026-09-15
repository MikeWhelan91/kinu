class_name KinuShopScreen
extends RefCounted
## Spend soybeans on onesies for Kinu, and choose which one to wear.

static func show(app: Node) -> void:
	app._new_screen("shop",true)
	var layout = app._header("Kinu Shop")
	var balance_row = CenterContainer.new()
	balance_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance_row.add_child(NestTheme.bean_pill("%s beans"%app._number(Save.data.beans),22))
	layout.add_child(balance_row)
	var scroll = DragScroll.new()
	layout.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	scroll.add_child(grid)
	var catalog: KinuCatalog = app.run.catalog
	_card(app,grid,null)
	for outfit in catalog.outfits:
		_card(app,grid,outfit)
	app._center_label(layout,"Earn soybeans by building taller towers.",15,NestTheme.MUTED)

static func _card(app: Node, grid: GridContainer, outfit: KinuOutfit) -> void:
	var id := outfit.id if outfit else ""
	var owned: bool = Save.owns_outfit(id)
	var wearing: bool = str(Save.data.outfit) == id
	var button := NestTheme.button("",func() -> void: _choose(app,outfit),wearing)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(210,230)
	grid.add_child(button)
	var stack: VBoxContainer = app._vbox(button,2)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_top = 8
	stack.offset_bottom = -12
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var catalog: KinuCatalog = app.run.catalog
	var preview := KinuPreview.new()
	preview.setup(catalog.shapes[0],catalog.flavours[0],true,Vector2i(170,130),"happy" if wearing else "calm",outfit,true)
	stack.add_child(preview)
	app._center_label(stack,outfit.display_name if outfit else "Plain Kinu",21)
	var status := CenterContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(status)
	if wearing:
		status.add_child(NestTheme.label("Wearing",16,NestTheme.INK))
	elif owned:
		status.add_child(NestTheme.label("Tap to wear",16,NestTheme.MUTED))
	else:
		status.add_child(NestTheme.bean_pill(str(outfit.price),16))

static func _choose(app: Node, outfit: KinuOutfit) -> void:
	var id := outfit.id if outfit else ""
	if Save.owns_outfit(id):
		Save.setting("outfit",id)
		show(app)
		return
	var stack = app._modal(outfit.display_name)
	var preview := KinuPreview.new()
	preview.setup(app.run.catalog.shapes[0],app.run.catalog.flavours[0],true,Vector2i(280,210),"happy",outfit)
	stack.add_child(preview)
	var short: int = outfit.price-int(Save.data.beans)
	if short > 0:
		var note = app._center_label(stack,"You need %d more beans.\nBuild taller towers to earn them!"%short,19)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(NestTheme.button("Okay",app._close_modal,true))
		return
	var price_row := CenterContainer.new()
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(NestTheme.bean_pill("%d beans"%outfit.price,20))
	stack.add_child(price_row)
	stack.add_child(NestTheme.button("Buy & wear",func() -> void:
		if Save.buy_outfit(outfit.id,outfit.price):
			Sound.play("record")
			Haptics.pulse(30,.5)
		show(app)
	,true))
	stack.add_child(NestTheme.button("Not yet",app._close_modal))
