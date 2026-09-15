class_name KinuBookScreen
extends RefCounted
## The collection: every flavour of Kinu you've stacked, plus a guide to the shapes.

static func show(app: Node) -> void:
	app._new_screen("collection",true)
	var layout = app._header("Kinu Book")
	var flavours: Array[KinuFlavour] = app.run.unlocked_flavours()
	app._center_label(layout,"%d / %d flavours found"%[found(flavours),flavours.size()],18,NestTheme.MUTED)
	var filter_row = HBoxContainer.new()
	layout.add_child(filter_row)
	for filter in ["All","Found","Missing"]:
		var button = NestTheme.button(filter,func() -> void:
			app.collection_filter = filter
			app._collection()
		,app.collection_filter==filter)
		button.add_theme_font_size_override("font_size",16)
		button.custom_minimum_size.y = 66
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filter_row.add_child(button)
	var scroll = DragScroll.new()
	layout.add_child(scroll)
	var list = app._vbox(scroll,16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid = _grid(list)
	var block: KinuShape = app.run.catalog.shapes[0]
	for flavour in flavours:
		var known: bool = Save.data.discovered.has(flavour.id)
		if (app.collection_filter=="Found" and not known) or (app.collection_filter=="Missing" and known):
			continue
		var card = _card(app,grid,func() -> void: app._flavour_detail(flavour,known))
		var preview = KinuPreview.new()
		preview.setup(block,flavour,known,Vector2i(170,130),"calm" if known else "worried")
		card.add_child(preview)
		app._center_label(card,flavour.display_name if known else "???",22)
		app._center_label(card,flavour.rarity() if known else "Not found yet",14,NestTheme.MUTED)
	if grid.get_child_count() == 0:
		app._center_label(grid,"Every flavour found. Amazing!",17)
	var heading = NestTheme.headline("Shapes",30,NestTheme.SUN)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(heading)
	var silken: KinuFlavour = flavours[0]
	for shape in app.run.catalog.shapes:
		var row = PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(row)
		var line = HBoxContainer.new()
		row.add_child(line)
		var preview = KinuPreview.new()
		preview.setup(shape,silken,true,Vector2i(120,90))
		line.add_child(preview)
		var text = app._vbox(line,0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_child(NestTheme.label(shape.display_name,22))
		var description = NestTheme.label(shape.description,15,NestTheme.MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(description)
	app._center_label(layout,"Stack a new flavour safely to add it to your book.",15,NestTheme.MUTED)

static func found(flavours: Array[KinuFlavour]) -> int:
	var count := 0
	for flavour in flavours:
		if Save.data.discovered.has(flavour.id):
			count += 1
	return count

static func _grid(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	parent.add_child(grid)
	return grid

static func _card(app: Node, grid: GridContainer, callback: Callable) -> VBoxContainer:
	var button := NestTheme.button("",callback)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(210,210)
	grid.add_child(button)
	var stack: VBoxContainer = app._vbox(button,1)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_top = 10
	stack.offset_bottom = -10
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return stack

static func flavour_detail(app: Node, flavour: KinuFlavour, known: bool) -> void:
	var stack = app._modal(flavour.display_name+" Kinu" if known else "A flavour to find")
	var preview = KinuPreview.new()
	preview.setup(app.run.catalog.shapes[0],flavour,known,Vector2i(280,200),"happy" if known else "worried")
	stack.add_child(preview)
	var description = app._center_label(stack,flavour.description if known else "Keep stacking. This flavour turns up now and then.",20)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if known:
		app._center_label(stack,flavour.rarity(),18,NestTheme.SKY)
	stack.add_child(NestTheme.button("Lovely",app._close_modal,true))
