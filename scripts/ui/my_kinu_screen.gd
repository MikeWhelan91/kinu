class_name MyKinuScreen
extends RefCounted
## Dress up My Kinu: pick a favourite flavour as its base, then a part for each open slot. A
## showcase card presents the live model on a pedestal under a spotlight; equipment sockets beneath
## it double as the slot tabs, and the grid below lists everything that slot can wear.

const TABS := ["flavour", "body", "hat", "arms", "glasses"]
const VELVET_TOP := Color("dff2ff")
const VELVET_BOTTOM := Color("a9d4f0")
const GOLD := Color("f6c869")
const GOLD_DEEP := Color("c98a2e")
const GOLD_LIGHT := Color("fff1c4")
const BADGE_COLORS := {"": Color("ffb62e"), "bronze": Color("d58a4a"), "silver": Color("c9d3de"), "gold": Color("f6c869"), "sakura": Color("ff9fc0"), "rainbow": Color("b99cf2")}
const SECTION_TITLES := {"flavour": "Flavours", "body": "Body", "hat": "Hats", "arms": "Arms", "glasses": "Glasses"}
static var tab := "flavour"
static var shape_index := 0
static var back: Callable

## Fills `points` with a rounded rectangle outline, clockwise from the top-left corner.
static func rounded_points(rect: Rect2, radius: float, steps: int = 8) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y)*.5)
	var corners := [[rect.position+Vector2(r, r), PI], [Vector2(rect.end.x-r, rect.position.y+r), PI*1.5], [rect.end-Vector2(r, r), 0.0], [Vector2(rect.position.x+r, rect.end.y-r), PI*.5]]
	for corner in corners:
		for i in steps+1:
			var angle: float = corner[1]+PI*.5*float(i)/steps
			points.append(corner[0]+Vector2(cos(angle), sin(angle))*r)
	return points

static func ellipse_points(center: Vector2, radius: Vector2, steps: int = 48) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU*float(i)/steps
		points.append(center+Vector2(cos(angle)*radius.x, sin(angle)*radius.y))
	return points

## Text on the light sky backdrop.
const SKY_TEXT := Color("2f5878")
const NEXT_TEXT := Color("b0670f")

## The showcase: sky backdrop in a gold frame, a spotlight on a pedestal, drifting motes and the
## level medallion. The live model sits on the pedestal; buttons and labels are real children.
class ShowcaseCard extends Control:
	var phase := 0.0
	var preview: KinuPreview
	var glow := Color("ffd27a")
	var level := 1
	var badge := ""
	var stage_height := 300.0
	var pedestal_y := 0.0
	var motes: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 18:
			motes.append([rng.randf(), rng.randf(), rng.randf_range(.02, .06), rng.randf_range(1.2, 3.0), rng.randf()*TAU])
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		pedestal_y = stage_height-34
		if is_instance_valid(preview):
			preview.position = Vector2((size.x-preview.size.x)*.5, pedestal_y-preview.size.y+20)

	func _process(delta: float) -> void:
		phase += delta
		if is_instance_valid(preview) and is_instance_valid(preview.model):
			preview.model.position.y = .02+sin(phase*1.6)*.02
		queue_redraw()

	func _draw() -> void:
		var outer := Rect2(Vector2.ZERO, size)
		var radius := 30.0
		# Soft drop shadow, then the velvet body with a vertical gradient.
		draw_colored_polygon(MyKinuScreen.rounded_points(Rect2(Vector2(0, 8), size), radius), Color(.23, .1, .05, .28))
		var body := MyKinuScreen.rounded_points(outer, radius)
		var shades := PackedColorArray()
		for point in body:
			shades.append(MyKinuScreen.VELVET_TOP.lerp(MyKinuScreen.VELVET_BOTTOM, clampf(point.y/maxf(size.y, 1), 0, 1)))
		draw_polygon(body, shades)
		var center := Vector2(size.x*.5, pedestal_y-stage_height*.36)
		# Slowly turning gold rays and a glow tinted by My Kinu's own flavour.
		for i in 16:
			var angle := TAU*float(i)/16.0+phase*.06
			var direction := Vector2.RIGHT.rotated(angle)
			var side := direction.orthogonal()
			var ray := PackedVector2Array([center+side*4, center+direction*size.x*.9+side*34, center+direction*size.x*.9-side*34, center-side*4])
			draw_colored_polygon(ray, Color(MyKinuScreen.GOLD, .045 if i % 2 == 0 else .02))
		for i in 16:
			var t := float(i)/16.0
			draw_circle(center, stage_height*.5*(1.0-t*.85), Color(glow, .035+t*.02))
		# Spotlight falling onto the pedestal.
		var beam := PackedVector2Array([Vector2(size.x*.5-26, 0), Vector2(size.x*.5+26, 0), Vector2(size.x*.5+size.x*.36, pedestal_y), Vector2(size.x*.5-size.x*.36, pedestal_y)])
		draw_polygon(beam, PackedColorArray([Color(1, 1, 1, .2), Color(1, 1, 1, .2), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
		# Drifting motes.
		for mote in motes:
			var y: float = fposmod(float(mote[1])-phase*float(mote[2]), 1.0)
			var x: float = float(mote[0])+sin(phase*.7+float(mote[4]))*.015
			var fade := sin(y*PI)
			draw_circle(Vector2(x*size.x, 16+y*(stage_height-40)), float(mote[3]), Color(1, 1, 1, .8*fade))
		_pedestal()
		_sparkles()
		# Gold frame: a heavy ink edge, a gold inner rule and diamond corner studs.
		var closed := body.duplicate()
		closed.append(body[0])
		draw_polyline(closed, NestTheme.INK, 5.0, true)
		var inner := MyKinuScreen.rounded_points(outer.grow(-9), radius-9)
		inner.append(inner[0])
		draw_polyline(inner, Color(MyKinuScreen.GOLD, .9), 2.5, true)
		for corner in [Vector2(9, 9), Vector2(size.x-9, 9), Vector2(9, size.y-9), Vector2(size.x-9, size.y-9)]:
			var at: Vector2 = corner+(Vector2(size.x*.5, size.y*.5)-corner).normalized()*14
			_diamond(at, 6.0)
		# Divider between the stage and the nameplate.
		var rule_y := stage_height+6
		draw_line(Vector2(34, rule_y), Vector2(size.x*.5-16, rule_y), Color(MyKinuScreen.GOLD, .6), 2.0, true)
		draw_line(Vector2(size.x*.5+16, rule_y), Vector2(size.x-34, rule_y), Color(MyKinuScreen.GOLD, .6), 2.0, true)
		_diamond(Vector2(size.x*.5, rule_y), 5.0)
		_medallion(Vector2(46, 46))

	func _pedestal() -> void:
		var middle := Vector2(size.x*.5, pedestal_y)
		var width := minf(size.x*.34, 130.0)
		draw_colored_polygon(MyKinuScreen.ellipse_points(middle+Vector2(0, 22), Vector2(width*1.18, 16)), Color(0, 0, 0, .28))
		# Side band of the dais.
		var side := MyKinuScreen.ellipse_points(middle+Vector2(0, 12), Vector2(width, 22))
		draw_colored_polygon(side, MyKinuScreen.GOLD_DEEP)
		var band := PackedVector2Array()
		for i in 25:
			var angle := PI*float(i)/24.0
			band.append(middle+Vector2(cos(angle)*width, sin(angle)*22))
		for i in 25:
			var angle := PI-PI*float(i)/24.0
			band.append(middle+Vector2(cos(angle)*width, 12+sin(angle)*22))
		draw_colored_polygon(band, MyKinuScreen.GOLD_DEEP)
		var band_line := band.duplicate()
		band_line.append(band[0])
		draw_polyline(band_line, NestTheme.INK, 3.0, true)
		# Top face, lit from the spotlight.
		var top := MyKinuScreen.ellipse_points(middle, Vector2(width, 22))
		var lit := PackedColorArray()
		for point in top:
			lit.append(MyKinuScreen.GOLD_LIGHT.lerp(MyKinuScreen.GOLD, clampf((point.y-middle.y+22)/44.0, 0, 1)))
		draw_polygon(top, lit)
		var rim := top.duplicate()
		rim.append(top[0])
		draw_polyline(rim, NestTheme.INK, 3.0, true)
		draw_arc(middle, width*.8, PI*1.12, PI*1.5, 16, Color(1, 1, 1, .7), 2.5, true)

	func _sparkles() -> void:
		var spots := [Vector2(.16, .2), Vector2(.84, .16), Vector2(.9, .5), Vector2(.1, .58), Vector2(.76, .7)]
		for i in spots.size():
			var point := Vector2(size.x*spots[i].x, stage_height*spots[i].y)
			var twinkle := .55+.45*sin(phase*2.0+float(i)*1.3)
			_star(point, (7.0 if i % 2 == 0 else 4.5)*twinkle, Color(1, 1, 1, .9*twinkle))

	func _star(point: Vector2, extent: float, color: Color) -> void:
		var star := PackedVector2Array()
		for j in 8:
			var reach := extent*(1.7 if j % 2 == 0 else .38)
			star.append(point+Vector2.UP.rotated(TAU*j/8.0)*reach)
		draw_colored_polygon(star, color)

	func _diamond(at: Vector2, extent: float) -> void:
		var shape := PackedVector2Array([at+Vector2(0, -extent), at+Vector2(extent, 0), at+Vector2(0, extent), at+Vector2(-extent, 0)])
		draw_colored_polygon(shape, MyKinuScreen.GOLD)
		var line := shape.duplicate()
		line.append(shape[0])
		draw_polyline(line, NestTheme.INK, 1.5, true)

	func _medallion(at: Vector2) -> void:
		var tone: Color = MyKinuScreen.BADGE_COLORS.get(badge, MyKinuScreen.BADGE_COLORS[""])
		draw_circle(at+Vector2(0, 3), 31, Color(0, 0, 0, .3))
		draw_circle(at, 31, NestTheme.INK)
		draw_circle(at, 28, tone.darkened(.15))
		draw_circle(at, 23, tone)
		draw_arc(at, 25.5, 0, TAU, 40, Color(1, 1, 1, .55), 1.5, true)
		draw_arc(at, 19, PI*1.1, PI*1.6, 10, Color(1, 1, 1, .8), 3, true)
		var font := NestTheme.font
		var tag := "LV"
		var tag_width := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, at+Vector2(-tag_width*.5, -6), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, NestTheme.INK)
		var number := str(level)
		var number_size := 24 if number.length() < 3 else 18
		var number_width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
		draw_string_outline(font, at+Vector2(-number_width*.5, 15), number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, 5, NestTheme.INK)
		draw_string(font, at+Vector2(-number_width*.5, 15), number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, NestTheme.CREAM)

## A thin gold experience bar with a gloss highlight, drawn on the velvet.
class XpBar extends Control:
	var value := 0.0
	var maximum := 1.0

	func _draw() -> void:
		var track := Rect2(Vector2.ZERO, size)
		var radius := size.y*.5
		draw_colored_polygon(MyKinuScreen.rounded_points(track, radius), Color(1, 1, 1, .75))
		var amount := clampf(value/maxf(maximum, 1), 0, 1)
		if amount > 0:
			var fill := Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x*amount), size.y))
			var points := MyKinuScreen.rounded_points(fill, radius)
			var colors := PackedColorArray()
			for point in points:
				colors.append(MyKinuScreen.GOLD_LIGHT.lerp(MyKinuScreen.GOLD_DEEP, point.y/size.y))
			draw_polygon(points, colors)
			draw_line(Vector2(radius, size.y*.3), Vector2(fill.size.x-radius, size.y*.3), Color(1, 1, 1, .55), 2.0, true)
		var outline := MyKinuScreen.rounded_points(track, radius)
		outline.append(outline[0])
		draw_polyline(outline, NestTheme.INK, 2.0, true)

static func show(app: Node, back_to: Callable = Callable()) -> void:
	if back_to.is_valid():
		back = back_to
		# Opening the screen afresh goes straight to a slot with new parts waiting in it.
		for slot in MyKinu.SLOTS:
			if MyKinu.fresh_parts(slot) > 0:
				tab = slot
				break
	if not back.is_valid():
		back = app._show_wardrobe
	var catalog: KinuCatalog = app.run.catalog
	app._new_screen("my_kinu", true)
	var layout: VBoxContainer = app._header("My Kinu", back)
	layout.add_theme_constant_override("separation", 10)
	# The showcase and the slot sockets stay put; only the item list below them scrolls.
	var hero := _hero(app, catalog)
	layout.add_child(hero)
	if not MyKinu.active():
		var wear := NestTheme.button("Wear My Kinu In Runs", func() -> void:
			MyKinu.wear(catalog, true)
			Analytics.track("my_kinu_worn", {"level": MyKinu.level()})
			show(app)
		, true, "wardrobe")
		wear.name = "WearMyKinu"
		wear.custom_minimum_size.y = 56
		layout.add_child(wear)
	layout.add_child(_sockets(app, catalog))
	var scroll := DragScroll.new()
	scroll.name = "MyKinuItems"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	KinuShopScreen.remember_scroll(scroll, "my_kinu:"+tab)
	var list: VBoxContainer = app._vbox(scroll, 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(_section_title(catalog))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	list.add_child(grid)
	if tab == "flavour":
		_flavours(app, catalog, grid)
	else:
		_parts(app, catalog, grid, tab)
		if not MyKinu.slot_unlocked(tab):
			var locked := app._center_label(list, NestTheme.t("This slot opens at level %d. Its parts become available then.")%MyKinu.slot_level(tab), 15, NestTheme.MUTED) as Label
			locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var more := NestTheme.button("Get More In The Shop", func() -> void:
			app.shop_tab = "part"
			KinuShopScreen.part_slot = tab
			app.shop_back = func() -> void: show(app)
			app._show_shop()
		, false, "wardrobe")
		more.name = "GetMoreParts"
		more.custom_minimum_size = Vector2(0, 58)
		more.add_theme_font_size_override("font_size", 20)
		for state in ["normal", "hover", "pressed"]:
			var tone := NestTheme.BERRY.lightened(.08) if state == "hover" else NestTheme.BERRY.darkened(.1) if state == "pressed" else NestTheme.BERRY
			more.add_theme_stylebox_override(state, NestTheme.box(tone, 24, NestTheme.INK, 6 if state != "pressed" else 4))
		for colour in ["font_color", "font_hover_color", "font_pressed_color"]:
			more.add_theme_color_override(colour, NestTheme.CREAM)
		var row := CenterContainer.new()
		row.add_child(more)
		list.add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	list.add_child(spacer)
	Save.data.my_kinu.seen_level = maxi(int(Save.data.my_kinu.seen_level), MyKinu.level())

## The showcase card: live model on the pedestal, shape switcher, nameplate and level progress.
static func _hero(app: Node, catalog: KinuCatalog) -> Control:
	var screen_size: Vector2 = app.get_viewport().get_visible_rect().size
	var stage_height := float(clampi(int(screen_size.y*.23), 170, 240))
	var card := ShowcaseCard.new()
	card.name = "MyKinuHero"
	card.stage_height = stage_height
	card.level = MyKinu.level()
	card.badge = MyKinu.badge()
	card.glow = MyKinu.base(catalog).color.lightened(.25)
	card.custom_minimum_size = Vector2(0, stage_height+122)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = false
	var shape: KinuShape = catalog.shapes[shape_index % catalog.shapes.size()]
	var preview := KinuPreview.new()
	preview.name = "MyKinuPreview"
	var width := mini(300, int(screen_size.x)-120)
	var height := int(stage_height)-40
	preview.setup(shape, MyKinu.base(catalog), true, Vector2i(width, height), "happy", null, true, false, MyKinu.equipped(catalog))
	preview.enable_spin()
	# Framed on the body alone, so the Kinu keeps its size whatever it wears.
	preview.fit_model(1.5, true, true)
	preview.size = Vector2(width, height)
	card.preview = preview
	card.add_child(preview)
	# Glassy round arrows either side of the pedestal.
	for side in [-1, 1]:
		var arrow := Button.new()
		arrow.name = "PreviousShape" if side < 0 else "NextShape"
		arrow.text = "‹" if side < 0 else "›"
		arrow.add_theme_font_size_override("font_size", 30)
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, .7 if state == "normal" else .9 if state == "hover" else 1.0)
			style.set_corner_radius_all(24)
			style.border_color = NestTheme.INK
			style.set_border_width_all(3)
			style.anti_aliasing = true
			arrow.add_theme_stylebox_override(state, style)
		arrow.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for colour in ["font_color", "font_hover_color", "font_pressed_color"]:
			arrow.add_theme_color_override(colour, NestTheme.INK)
		arrow.custom_minimum_size = Vector2(46, 46)
		arrow.size = Vector2(46, 46)
		arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT if side < 0 else Control.PRESET_CENTER_RIGHT)
		arrow.anchor_top = 0
		arrow.anchor_bottom = 0
		arrow.position.y = stage_height*.5-23
		if side < 0:
			arrow.offset_left = 20
			arrow.offset_right = 66
		else:
			arrow.offset_left = -66
			arrow.offset_right = -20
		arrow.offset_top = stage_height*.5-23
		arrow.offset_bottom = stage_height*.5+23
		arrow.pressed.connect(func() -> void:
			Sound.play("tap")
			shape_index = (shape_index+catalog.shapes.size()+side) % catalog.shapes.size()
			show(app)
		)
		card.add_child(arrow)
	# Top-right: the current state of the look.
	var state_chip := _chip(NestTheme.t("Worn in runs") if MyKinu.active() else NestTheme.t("Not worn"), GOLD_DEEP if MyKinu.active() else NestTheme.MUTED)
	state_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	state_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	state_chip.offset_top = 26
	state_chip.offset_right = -24
	card.add_child(state_chip)
	# Nameplate and progress below the stage.
	var plate := VBoxContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_constant_override("separation", 4)
	plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	plate.offset_left = 30
	plate.offset_right = -30
	plate.offset_top = -112
	plate.offset_bottom = -22
	card.add_child(plate)
	var name := NestTheme.headline(NestTheme.t("My Kinu"), 24, NestTheme.CREAM)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(name)
	var subtitle := NestTheme.label(NestTheme.t("%s Kinu")%NestTheme.t(MyKinu.base(catalog).display_name)+"  ·  "+NestTheme.t(shape.display_name), 15, SKY_TEXT)
	subtitle.name = "MyKinuLevel"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(subtitle)
	var level := MyKinu.level()
	var progress := MyKinu.progress_for(MyKinu.xp())
	var numbers := HBoxContainer.new()
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_text := NestTheme.label(NestTheme.t("%d / %d XP")%[progress[0], progress[1]], 13, SKY_TEXT)
	xp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	numbers.add_child(xp_text)
	var next_text := NestTheme.label(NestTheme.t("Next: %s")%next_reward(level+1), 13, NEXT_TEXT)
	next_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	next_text.clip_text = true
	next_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	numbers.add_child(next_text)
	plate.add_child(numbers)
	var bar := XpBar.new()
	bar.value = progress[0]
	bar.maximum = progress[1]
	bar.custom_minimum_size.y = 12
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(bar)
	return card

## A small rounded tag on the velvet.
static func _chip(text: String, tone: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, .75)
	style.border_color = tone
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 3
	style.content_margin_bottom = 4
	style.anti_aliasing = true
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(NestTheme.label(text, 13, NestTheme.INK))
	return chip

## Five equipment sockets showing what is worn in each slot. They are also the slot tabs.
static func _sockets(app: Node, catalog: KinuCatalog) -> Control:
	var row := HBoxContainer.new()
	row.name = "MyKinuSockets"
	row.add_theme_constant_override("separation", 6)
	for id in TABS:
		var selected: bool = tab == id
		var open: bool = id == "flavour" or MyKinu.slot_unlocked(id)
		var button := Button.new()
		button.name = "Tab_"+id
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 86)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.pressed.connect(func() -> void:
			if NestTheme.scroll_dragging:
				return
			Sound.play("wardrobe")
			tab = id
			show(app)
		)
		row.add_child(button)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.add_theme_constant_override("separation", 4)
		button.add_child(column)
		var socket := PanelContainer.new()
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		socket.custom_minimum_size = Vector2(0, 58)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("fffaf0") if open else Color("e9dccb")
		style.set_corner_radius_all(20)
		style.border_color = GOLD_DEEP if selected else NestTheme.INK
		style.set_border_width_all(4 if selected else 3)
		style.border_width_bottom = 6 if selected else 5
		style.shadow_color = Color(GOLD, .55) if selected else Color(0, 0, 0, 0)
		style.shadow_size = 8 if selected else 0
		style.set_content_margin_all(2)
		style.anti_aliasing = true
		socket.add_theme_stylebox_override("panel", style)
		column.add_child(socket)
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		socket.add_child(holder)
		holder.add_child(_socket_art(catalog, id, open))
		var title := "Flavour" if id == "flavour" else str(MyKinu.SLOT_NAMES[id])
		var unseen := 0 if id == "flavour" else MyKinu.fresh_parts(id)
		if unseen > 0 and not selected:
			var dot := NestTheme.count_badge(unseen)
			dot.name = "NewParts"
			dot.position = Vector2(-4, -8)
			button.add_child(dot)
			dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			dot.offset_left = -22
			dot.offset_top = -8
		var caption := NestTheme.label(NestTheme.t(title) if open else NestTheme.t("Lv %d")%MyKinu.slot_level(id), 13, NestTheme.INK if selected else NestTheme.MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.clip_text = true
		column.add_child(caption)
	return row

## What a socket shows: the flavour's colour, the worn part, a "+" for an empty slot or a lock.
static func _socket_art(catalog: KinuCatalog, id: String, open: bool) -> Control:
	if not open:
		var lock := LockIcon.new()
		lock.custom_minimum_size = Vector2(30, 34)
		return lock
	if id == "flavour":
		var swatch := FlavourSwatch.new()
		swatch.color = MyKinu.base(catalog).color
		swatch.custom_minimum_size = Vector2(44, 44)
		return swatch
	var part := catalog.part(str(Save.data.my_kinu.equipped.get(id, "")))
	if part == null or not Save.owns("part", part.id, part.price):
		var empty := NestTheme.label("+", 28, Color(NestTheme.MUTED, .7))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return empty
	var mini := part_preview(catalog, part, Vector2i(56, 52))
	mini.fit_model(1.3, false, true, .14)
	return mini

## A small padlock for slots that have not opened yet.
class LockIcon extends Control:
	func _draw() -> void:
		var body := Rect2(Vector2(2, size.y*.42), Vector2(size.x-4, size.y*.56))
		draw_arc(Vector2(size.x*.5, size.y*.42), size.x*.3, PI, TAU, 16, NestTheme.MUTED, 4.0, true)
		draw_colored_polygon(MyKinuScreen.rounded_points(body, 5), NestTheme.MUTED)
		draw_circle(Vector2(size.x*.5, body.position.y+body.size.y*.45), 3.5, Color("e9dccb"))

## A glossy round swatch of a flavour colour.
class FlavourSwatch extends Control:
	var color := Color.WHITE
	func _draw() -> void:
		var center := size*.5
		var radius := minf(size.x, size.y)*.5-2
		draw_circle(center, radius+2, NestTheme.INK)
		draw_circle(center, radius, color)
		draw_arc(center, radius*.62, PI*1.1, PI*1.55, 10, Color(1, 1, 1, .75), 3.0, true)

## The heading above the grid: an ornamental rule with the slot's name and how many are owned.
static func _section_title(catalog: KinuCatalog) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var count := 0
	if tab == "flavour":
		for flavour in catalog.flavours:
			if Save.flavour_unlocked(flavour):
				count += 1
	else:
		for part in catalog.parts_for(tab):
			if Save.owns("part", part.id, part.price):
				count += 1
	var total := catalog.flavours.size() if tab == "flavour" else catalog.parts_for(tab).size()
	for side in [0, 1]:
		var rule := ColorRect.new()
		rule.color = Color(NestTheme.WOOD, .7)
		rule.custom_minimum_size = Vector2(0, 3)
		rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rule)
		if side == 0:
			var title := NestTheme.headline(NestTheme.t(SECTION_TITLES[tab]), 24)
			row.add_child(title)
			var tally := NestTheme.pill("%d / %d" % [count, total], 14, NestTheme.MUTED)
			tally.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tally)
	return row

## What reaching `at_level` gives, in a few words.
static func next_reward(at_level: int) -> String:
	for slot in MyKinu.SLOTS:
		if MyKinu.slot_level(slot) == at_level:
			return NestTheme.t("%s slot")%NestTheme.t(MyKinu.SLOT_NAMES[slot])
	if at_level % MyKinu.LEVEL_PART_EVERY == 0:
		var part := MyKinu.level_part(at_level)
		return NestTheme.t(part.display_name) if part else NestTheme.t("%d tickets")%MyKinu.SPARE_TICKETS
	return NestTheme.t("%d beans")%MyKinu.level_beans(at_level)

## One selectable item: a framed stage with its preview, a name and, when chosen, a gold ring.
static func _tile(grid: GridContainer, preview: Control, title: String, tint: Color, selected: bool, enabled: bool, callback: Callable) -> Dictionary:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 148)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(func() -> void:
		if NestTheme.scroll_dragging or not enabled:
			return
		Sound.play("wardrobe")
		callback.call()
	)
	grid.add_child(button)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 5)
	button.add_child(column)
	var stage := PanelContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = tint if enabled else tint.lerp(Color("d9cfc2"), .6)
	style.set_corner_radius_all(18)
	style.border_color = GOLD_DEEP if selected else NestTheme.INK
	style.set_border_width_all(4 if selected else 3)
	style.border_width_bottom = 6 if selected else 5
	style.shadow_color = Color(GOLD, .6) if selected else Color(.23, .1, .05, .12)
	style.shadow_size = 9 if selected else 3
	style.shadow_offset = Vector2(0, 0 if selected else 2)
	style.set_content_margin_all(3)
	style.anti_aliasing = true
	stage.add_theme_stylebox_override("panel", style)
	column.add_child(stage)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	stage.add_child(holder)
	if selected:
		var tag := _chip(NestTheme.t("Worn"), GOLD_DEEP)
		(tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = GOLD
		(tag.get_child(0) as Label).add_theme_color_override("font_color", NestTheme.INK)
		CardGrid.corner_badge(stage, tag)
	var name := NestTheme.label(title, 14, NestTheme.INK if enabled else NestTheme.MUTED)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name)
	return {"button": button, "stage": stage, "column": column}

static func _flavours(app: Node, catalog: KinuCatalog, grid: GridContainer) -> void:
	var shape: KinuShape = catalog.shapes[0]
	var chosen := MyKinu.base(catalog)
	for flavour in catalog.flavours:
		var open := Save.flavour_unlocked(flavour)
		var preview := KinuPreview.new()
		preview.setup(shape, flavour, open, Vector2i(96, 76), "calm")
		preview.fit_model(1.04)
		var built := _tile(grid, preview, flavour.display_name if open else "???", flavour.color.lightened(.6) if open else Color("eee4d6"), flavour == chosen, open, func() -> void:
			if MyKinu.choose_flavour(catalog, flavour.id):
				show(app)
		)
		built.button.name = "Flavour_"+flavour.id
		if not open:
			var hint := NestTheme.label(NestTheme.t("Pile %d Kinu")%flavour.unlock_kinu, 12, NestTheme.MUTED)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			built.column.add_child(hint)
			built.button.custom_minimum_size.y = 166

static func _parts(app: Node, catalog: KinuCatalog, grid: GridContainer, slot: String) -> void:
	var worn := str(Save.data.my_kinu.equipped.get(slot, ""))
	var open := MyKinu.slot_unlocked(slot)
	var options: Array = [null]
	for part in catalog.parts_for(slot):
		if Save.owns("part", part.id, part.price):
			options.append(part)
	for part in options:
		var id: String = part.id if part else ""
		var preview := part_preview(catalog, part, Vector2i(96, 76))
		var tint := Color("f3ece2")
		if part and KinuCatcher.TIER_COLORS.has(part.rarity):
			tint = (KinuCatcher.TIER_COLORS[part.rarity] as Color).lightened(.72)
		elif part:
			tint = Color("fff3d6")
		var built := _tile(grid, preview, part.display_name if part else "Nothing", tint, open and worn == id, open, func() -> void:
			if MyKinu.equip(catalog, slot, id):
				Analytics.track("my_kinu_equipped", {"slot": slot, "part": id})
				show(app)
		)
		built.button.name = "Part_"+(id if id != "" else "none_"+slot)
		if part and Save.is_fresh("part:"+id):
			var tag := _chip(NestTheme.t("New"), Color("e5383b"))
			(tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("e5383b")
			(tag.get_child(0) as Label).add_theme_color_override("font_color", NestTheme.CREAM)
			tag.set_anchors_preset(Control.PRESET_TOP_LEFT)
			tag.offset_left = 6
			tag.offset_top = 6
			built.stage.add_child(tag)
			Save.clear_fresh("part:"+id)

## A My Kinu preview wearing only `part` (or nothing), on the player's chosen flavour.
static func part_preview(catalog: KinuCatalog, part: KinuPart, pixels: Vector2i, interactive: bool = false) -> KinuPreview:
	var node := KinuPreview.new()
	var parts: Array = [part] if part else []
	node.setup(catalog.shapes[0], MyKinu.base(catalog), true, pixels, "calm", null, true, false, parts)
	if interactive:
		node.enable_spin()
		node.fit_model(1.45, false, true, .14)
	else:
		node.fit_model(1.32, false, true, .14)
	return node
