class_name NestTheme
extends RefCounted
const INK := Color("3a2418")
const CREAM := Color("fffaf0")
const MUTED := Color("8a6d5a")
const SUN := Color("ffb62e")
const SKY := Color("3fa9f5")
const BERRY := Color("ff5d8f")
const WOOD := Color("c9894c")
const WOOD_LIGHT := Color("e6b77c")
const PURPLE := Color("7a4fd0")
## Soft stage colours behind previews on cards, cycled so a grid never reads as one block.
const STAGES := [Color("ffe7a3"), Color("ffd3e2"), Color("cdeefc"), Color("d8f3bd")]
## Translates a phrase (or format template) for the player's language.
static func t(text: String) -> String:
	return TranslationServer.translate(text)

## Translates each name and joins them for "A & B" style lists.
static func t_join(names: Array) -> String:
	return t(" & ").join(names.map(func(name: String) -> String: return t(name)))

static var font: Font = preload("res://assets/fonts/nunito_bold.tres")
## True while a finger is scrolling a list, so lifting it doesn't press the button underneath.
static var scroll_dragging: bool = false

## Chunky cartoon panel: thick ink border with a deeper bottom edge for a pressable, 3D look.
static func box(color: Color = CREAM, radius: int = 26, border: Color = INK, depth: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(4)
	style.border_width_bottom = depth
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10+depth-4
	style.anti_aliasing = true
	return style

static func theme() -> Theme:
	var value := Theme.new()
	value.default_font = font
	value.default_font_size = 20
	value.set_color("font_color", "Label", INK)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		value.set_color(state, "Button", INK)
	value.set_color("font_disabled_color", "Button", Color("b3a293"))
	value.set_stylebox("normal", "Button", box())
	value.set_stylebox("hover", "Button", box(Color("ffffff")))
	var pressed := box(Color("f3e6cf"), 26, INK, 4)
	pressed.content_margin_top = 14
	value.set_stylebox("pressed", "Button", pressed)
	value.set_stylebox("disabled", "Button", box(Color("eee4d6"), 26, Color("b3a293")))
	value.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	value.set_stylebox("panel", "PanelContainer", box(CREAM, 26, INK, 6))
	value.set_constant("separation", "VBoxContainer", 12)
	value.set_constant("separation", "HBoxContainer", 12)
	value.set_stylebox("slider", "HSlider", box(Color("f0e2c8"), 10, INK, 4))
	value.set_stylebox("grabber_area", "HSlider", box(SUN, 10, INK, 4))
	value.set_stylebox("grabber_area_highlight", "HSlider", box(SUN.lightened(.1), 10, INK, 4))
	return value

static func label(text: String, size: int = 20, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

## Game-style headline text: bright fill with a thick ink outline.
static func headline(text: String, size: int, color: Color = CREAM) -> Label:
	var node := label(text, size, color)
	node.add_theme_color_override("font_outline_color", INK)
	node.add_theme_constant_override("outline_size", maxi(6, size/5))
	node.add_theme_color_override("font_shadow_color", INK)
	node.add_theme_constant_override("shadow_offset_y", maxi(3, size/14))
	node.add_theme_constant_override("shadow_offset_x", 0)
	return node

## Floating HUD text in a small cream pill, so it reads over any part of the scene.
static func pill(text: String, size: int, color: Color = INK) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := box(CREAM, 18, INK, 5)
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	panel.add_theme_stylebox_override("panel", style)
	var text_label := label(text, size, color)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(text_label)
	return panel

## A small red count bubble for things waiting to be looked at (unclaimed missions, new unlocks).
static func count_badge(count: int) -> PanelContainer:
	var badge := pill(str(count), 15, CREAM)
	var style := badge.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Color("e5383b")
	style.content_margin_left = 9
	style.content_margin_right = 9
	badge.name = "CountBadge"
	return badge

## A pill with a soybean icon before the text, for anything counted in beans.
static func bean_pill(text: String, size: int = 18) -> PanelContainer:
	var panel := pill("", size)
	var text_label: Label = panel.get_child(0)
	panel.remove_child(text_label)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(BeanIcon.new(size*1.3))
	text_label.text = text
	row.add_child(text_label)
	panel.add_child(row)
	return panel

## Gives a button the highlighted sun-yellow style, or returns it to the plain theme style.
static func set_primary(node: Button, primary: bool) -> void:
	if not primary:
		for state in ["normal", "hover", "pressed"]:
			node.remove_theme_stylebox_override(state)
		return
	node.add_theme_stylebox_override("normal", box(SUN))
	node.add_theme_stylebox_override("hover", box(SUN.lightened(.12)))
	var pressed := box(SUN.darkened(.08), 26, INK, 4)
	pressed.content_margin_top = 14
	node.add_theme_stylebox_override("pressed", pressed)

## Wooden tile style for tappable cards: "plain", "active" (sun yellow) or "locked" (faded wood).
static func style_card(node: Button, state: String) -> void:
	var base: Color = {"plain": WOOD, "active": SUN, "locked": Color("b39477")}[state]
	node.add_theme_stylebox_override("normal", box(base, 22, INK, 8))
	node.add_theme_stylebox_override("hover", box(base.lightened(.08), 22, INK, 8))
	var pressed := box(base.darkened(.06), 22, INK, 4)
	pressed.content_margin_top = 14
	node.add_theme_stylebox_override("pressed", pressed)

## Cream text with an ink outline on a button, for buttons that sit on wood.
static func carve(node: Button, size: int) -> void:
	node.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, CREAM)
	node.add_theme_color_override("font_outline_color", INK)
	node.add_theme_constant_override("outline_size", maxi(6, size/5))

## A tinted, inked frame that previews sit on inside a card.
static func stage(tint: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := box(tint, 16, INK, 4)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP]:
		style.set_content_margin(side, 2)
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	return panel

## A tab or segmented choice: sun yellow when selected, light wood otherwise.
static func tab(text: String, selected: bool, callback: Callable, sound: String = "tap") -> Button:
	var node := button(text, callback, selected, sound)
	if not selected:
		node.add_theme_stylebox_override("normal", box(WOOD_LIGHT, 22, INK, 8))
		node.add_theme_stylebox_override("hover", box(WOOD_LIGHT.lightened(.1), 22, INK, 8))
	node.add_theme_font_size_override("font_size", 17)
	node.custom_minimum_size.y = 60
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

## A cream paper strip for text or controls sitting on wood.
static func paper(child: Control = null) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := box(Color("fff8e8"), 16, INK, 5)
	style.content_margin_top = 8
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	if child:
		panel.add_child(child)
	return panel

## A thin inked progress bar.
static func progress(value: float, maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxf(1, maximum)
	bar.value = minf(value, maximum)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := box(Color("f0e2c8"), 9, INK, 3)
	back.set_content_margin_all(0)
	var fill := box(SUN, 9, INK, 3)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

static func button(text: String, callback: Callable, primary: bool = false, sound: String = "tap") -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, 70)
	node.add_theme_font_size_override("font_size", 24)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_primary(node, primary)
	node.pressed.connect(func() -> void:
		if scroll_dragging:
			return
		Sound.play(sound)
		callback.call()
	)
	return node
