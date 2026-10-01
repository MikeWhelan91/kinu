class_name MyKinuScreen
extends RefCounted
## Dress up My Kinu: pick a favourite flavour as its base, then a part for each open slot. A live
## preview turns through every shape, because every Kinu dropped in a run wears this look.

const TABS := ["flavour", "body", "hat", "arms", "glasses"]
static var tab := "flavour"
static var shape_index := 0
static var back: Callable

## A quiet animated backdrop for the large dressing preview. The rays move behind Kinu while
## the actual model remains under the player's drag control.
class PortraitStage extends Control:
	var phase := 0.0
	var preview_model: Node3D

	func _process(delta: float) -> void:
		phase += delta
		if is_instance_valid(preview_model):
			preview_model.position.y = sin(phase*1.7)*.035
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(size.x*.5,size.y*.48)
		var radius := minf(size.x,size.y)*.43
		var canvas := PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
		var colors := PackedColorArray([Color("ffcfbd"),Color("ffe9c5"),Color("ffe2bd"),Color("ffc4c4")])
		draw_polygon(canvas,colors)
		for i in 12:
			var angle := TAU*float(i)/12.0+phase*.11
			var direction := Vector2.RIGHT.rotated(angle)
			var side := direction.orthogonal()
			var tip := center+direction*radius*1.35
			var ray := PackedVector2Array([center+side*8,tip,center-side*8])
			draw_colored_polygon(ray,Color("ffffff48") if i%2 == 0 else Color("ffad5640"))
		draw_circle(center,radius*.87,Color("fff7d1"))
		draw_arc(center,radius*.89,0,TAU,64,Color("ffffffd0"),3,true)
		var shadow := PackedVector2Array()
		for j in 32:
			var angle := TAU*float(j)/32.0
			shadow.append(Vector2(center.x+cos(angle)*radius*.53,size.y*.84+sin(angle)*12))
		draw_colored_polygon(shadow,Color("8b492f48"))
		var stars := [Vector2(.16,.25),Vector2(.79,.18),Vector2(.88,.52),Vector2(.14,.67),Vector2(.75,.76)]
		for i in stars.size():
			var point := Vector2(size.x*stars[i].x,size.y*stars[i].y)
			var twinkle := .72+.28*sin(phase*1.8+float(i)*1.4)
			var extent := (6.0 if i%2 == 0 else 4.0)*twinkle
			var star := PackedVector2Array([point+Vector2(0,-extent*1.65),point+Vector2(extent*.36,-extent*.36),point+Vector2(extent*1.65,0),point+Vector2(extent*.36,extent*.36),point+Vector2(0,extent*1.65),point+Vector2(-extent*.36,extent*.36),point+Vector2(-extent*1.65,0),point+Vector2(-extent*.36,-extent*.36)])
			draw_colored_polygon(star,Color("ffffff"))

static func show(app: Node, back_to: Callable = Callable()) -> void:
	if back_to.is_valid():
		back = back_to
	if not back.is_valid():
		back = app._show_wardrobe
	var catalog: KinuCatalog = app.run.catalog
	app._new_screen("my_kinu", true)
	var layout: VBoxContainer = app._header("My Kinu", back)
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var list: VBoxContainer = app._vbox(scroll, 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hero := _hero(app, catalog)
	list.add_child(hero)
	scroll.drag_exclusion = hero.find_child("MyKinuPreview",true,false) as Control
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
	list.add_child(tabs)
	var grid := CardGrid.grid(list, 3)
	if tab == "flavour":
		_flavours(app, catalog, grid)
	else:
		_parts(app, catalog, grid, tab)
		if not MyKinu.slot_unlocked(tab):
			app._center_label(list, NestTheme.t("This slot opens at level %d. Its parts become available then.")%MyKinu.slot_level(tab), 15, NestTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var paper := PanelContainer.new()
	paper.name = "MyKinuHero"
	var hero_style := NestTheme.box(Color("ffe0c4"),28,NestTheme.INK,5)
	hero_style.content_margin_top = 7
	hero_style.content_margin_bottom = 12
	hero_style.shadow_color = Color("713723",.25)
	hero_style.shadow_size = 8
	paper.add_theme_stylebox_override("panel",hero_style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(column)
	var shape: KinuShape = catalog.shapes[shape_index % catalog.shapes.size()]
	var preview := KinuPreview.new()
	preview.name = "MyKinuPreview"
	var screen_size: Vector2 = app.get_viewport().get_visible_rect().size
	var portrait_width := mini(308,int(screen_size.x)-74)
	var portrait_height := clampi(int(screen_size.y*.36),232,318)
	preview.setup(shape, MyKinu.base(catalog), true, Vector2i(portrait_width,portrait_height), "happy", null, true, false, MyKinu.equipped(catalog))
	preview.enable_spin()
	preview.fit_model(1.08)
	var stage := PortraitStage.new()
	stage.preview_model = preview.model
	stage.custom_minimum_size.y = portrait_height+8
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = true
	column.add_child(stage)
	var portrait_center := CenterContainer.new()
	portrait_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(portrait_center)
	portrait_center.add_child(preview)
	var shapes := HBoxContainer.new()
	shapes.alignment = BoxContainer.ALIGNMENT_CENTER
	shapes.add_theme_constant_override("separation", 12)
	var previous := NestTheme.button("‹", func() -> void:
		shape_index = (shape_index+catalog.shapes.size()-1) % catalog.shapes.size()
		show(app)
	, false, "tap")
	var next := NestTheme.button("›", func() -> void:
		shape_index = (shape_index+1) % catalog.shapes.size()
		show(app)
	, false, "tap")
	for button in [previous, next]:
		button.custom_minimum_size = Vector2(44, 44)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	previous.name = "PreviousShape"
	next.name = "NextShape"
	shapes.add_child(previous)
	var title := NestTheme.label(NestTheme.t("%s Kinu")%NestTheme.t(shape.display_name)+"  ·  "+NestTheme.t("Level %d")%MyKinu.level(), 18)
	title.name = "MyKinuLevel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = mini(200,int(screen_size.x)-166)
	shapes.add_child(title)
	shapes.add_child(next)
	column.add_child(shapes)
	var level := MyKinu.level()
	var progress := MyKinu.progress_for(MyKinu.xp())
	var bar := NestTheme.progress(progress[0], progress[1])
	bar.custom_minimum_size.y = 16
	column.add_child(bar)
	var next_line := NestTheme.label(NestTheme.t("%d / %d XP · Next: %s")%[progress[0], progress[1], next_reward(level+1)], 14, NestTheme.MUTED)
	next_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(next_line)
	if not MyKinu.active():
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
