class_name KinuCatcherScreen
extends RefCounted
## The Kinu Catcher page: a lit marquee over the machine, and a control deck with one round button
## that pays for a play, then drops the claw.

static var machine: CatcherMachine
static var action: Button
static var hint: Label
static var balance: PanelContainer
static var back: Callable

const BUTTON_SIZE := 118.0

static func show(app: Node, return_to: Callable = Callable()) -> void:
	back = return_to if return_to.is_valid() else app._home
	app._new_screen("catcher", true)
	Sound.play_room_music("catcher")
	var layout: VBoxContainer = app._header("Kinu Claw", func() -> void: back.call())
	layout.add_theme_constant_override("separation", 10)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	layout.add_child(top)
	balance = NestTheme.ticket_pill(NestTheme.t("%s tickets")%app._number(Save.data.tickets), 20)
	var balance_row := HBoxContainer.new()
	balance_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_row.add_child(balance)
	top.add_child(balance_row)
	var odds := NestTheme.button("Odds", func() -> void: odds_page(app), false, "book")
	odds.name = "Odds"
	odds.custom_minimum_size = Vector2(110, 50)
	odds.add_theme_font_size_override("font_size", 18)
	top.add_child(odds)
	# The cabinet breaks out of the page's side gutters and runs edge to edge, so the case has
	# the full width of the screen to be looked into rather than a narrow slot in the middle.
	var wide := MarginContainer.new()
	wide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var gutter := -int(app.content.offset_left)
	wide.add_theme_constant_override("margin_left", gutter)
	wide.add_theme_constant_override("margin_right", gutter)
	layout.add_child(wide)
	var cabinet := PanelContainer.new()
	cabinet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cabinet_style := NestTheme.box(Color("ff6f91"), 26, NestTheme.INK, 10)
	cabinet_style.set_content_margin_all(6)
	cabinet_style.content_margin_top = 10
	cabinet.add_theme_stylebox_override("panel", cabinet_style)
	wide.add_child(cabinet)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 8)
	cabinet.add_child(inside)
	inside.add_child(Marquee.new())
	var window := Control.new()
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.custom_minimum_size = Vector2(0, 260)
	inside.add_child(window)
	machine = CatcherMachine.new()
	machine.name = "Machine"
	machine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(machine)
	var glass := Glass.new()
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(glass)
	hint = NestTheme.label("", 16, NestTheme.CREAM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_outline_color", NestTheme.INK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 8
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(hint)
	# The control deck: the round Play/Drop button between two controls, which follow the player's
	# control scheme from Settings.
	var deck := HBoxContainer.new()
	deck.alignment = BoxContainer.ALIGNMENT_CENTER
	deck.add_theme_constant_override("separation", 10)
	deck.custom_minimum_size.y = BUTTON_SIZE+24
	layout.add_child(deck)
	var claw_scheme: bool = Save.data.controls == "claw"
	var steer := _control(claw_scheme, "move")
	var view := _control(claw_scheme, "view")
	var left_handed: bool = Save.data.claw_hand == "left"
	deck.add_child(view if left_handed and claw_scheme else steer)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	deck.add_child(holder)
	action = NestTheme.button("", func() -> void: _act(app), true, "plop")
	action.name = "CatcherAction"
	action.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	action.add_theme_font_size_override("font_size", 24)
	holder.add_child(action)
	deck.add_child(steer if left_handed and claw_scheme else view)
	app._resized()
	machine.state_changed.connect(func() -> void: refresh(app))
	refresh(app)
	if Rewards.configured():
		app.get_tree().create_timer(0.0).timeout.connect(func() -> void:
			await KinuCatcher.refresh_free_status()
			if is_instance_valid(app) and app.page == "catcher":
				refresh(app))

## One side of the deck: a joystick in the claw scheme, otherwise a pad to swipe.
static func _control(claw_scheme: bool, kind: String) -> Control:
	if claw_scheme:
		var stick := Joystick.new()
		stick.name = "MoveStick" if kind == "move" else "TurnStick"
		stick.kind = kind
		stick.label = "Move" if kind == "move" else "Turn"
		stick.base_radius = 48.0
		stick.nub_radius = 24.0
		stick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if kind == "move":
			stick.steer = func(value: Vector2) -> void: machine.move_input = value
			stick.accepting = func() -> bool: return machine.state == "aim"
		else:
			stick.steer = func(value: Vector2) -> void: machine.view_input = value
		return stick
	var pad := SwipePad.new()
	pad.name = "MovePad" if kind == "move" else "TurnPad"
	pad.kind = kind
	return pad

static func refresh(app: Node) -> void:
	if not is_instance_valid(action):
		return
	var label: Label = balance.get_child(0).get_child(1)
	label.text = NestTheme.t("%s tickets")%app._number(Save.data.tickets)
	var fill := NestTheme.SUN
	match machine.state:
		"aim":
			action.text = NestTheme.t("Drop!")
			action.disabled = false
			fill = NestTheme.BERRY
			hint.text = NestTheme.t("Move the claw, then Drop!")
		"busy":
			action.text = "…"
			action.disabled = true
			hint.text = ""
		_:
			action.disabled = false
			hint.text = ""
			if KinuCatcher.free_ready():
				action.text = NestTheme.t("Free\nPlay")
			elif int(Save.data.tickets) >= KinuCatcher.TICKET_COST:
				action.text = NestTheme.t("Play\n1 Ticket")
			else:
				action.text = NestTheme.t("Get\nTickets")
				fill = NestTheme.WOOD_LIGHT
	var radius := int(BUTTON_SIZE*.5)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tone: Color = {"normal": fill, "hover": fill.lightened(.12), "pressed": fill.darkened(.08), "disabled": Color("d9c7a8")}[state]
		var round := NestTheme.box(tone, radius, NestTheme.INK, 4 if state == "pressed" else 9)
		round.content_margin_left = 0
		round.content_margin_right = 0
		round.content_margin_top = 0
		action.add_theme_stylebox_override(state, round)
	if machine.state == "aim":
		NestTheme.carve(action, 26)
	else:
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			action.remove_theme_color_override(color)
		action.remove_theme_constant_override("outline_size")
		action.add_theme_font_size_override("font_size", 24)

static func _act(app: Node) -> void:
	match machine.state:
		"aim":
			machine.drop()
		"idle":
			if not KinuCatcher.can_play():
				app._bean_shop("tickets")
				return
			var prize := await KinuCatcher.play_free(app.run.catalog, machine.rng) if KinuCatcher.free_ready() else KinuCatcher.play(app.run.catalog, machine.rng)
			if prize.is_empty():
				return
			Sound.play("cashregister")
			Haptics.pulse(20, .4)
			machine.begin_aim()
			await machine.delivered
			_reveal(app, prize)

static func _reveal(app: Node, prize: Dictionary) -> void:
	if app.page != "catcher":
		return
	var reveal := CapsuleReveal.open(app, prize)
	reveal.closed.connect(func(_how: String) -> void:
		refresh(app)
		if prize.kind == "room" and _how == "wear":
			Sound.play_room_music("catcher")
	)
	refresh(app)

## The lucky meter, every prize still in the machine with its chance this play, and the rules.
static func odds_page(app: Node) -> void:
	var stack: VBoxContainer = app._modal("Odds")
	var catalog: KinuCatalog = app.run.catalog
	var scroll := DragScroll.new()
	scroll.custom_minimum_size = Vector2(0, minf(520, app.get_viewport().get_visible_rect().size.y-360))
	stack.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	if KinuCatcher.items_left(catalog) > 0:
		var meter := VBoxContainer.new()
		meter.add_theme_constant_override("separation", 4)
		var lucky_text := NestTheme.t("Lucky meter: an item within %d plays")%KinuCatcher.lucky_in() if KinuCatcher.lucky_in() > 1 else NestTheme.t("Lucky meter: the next play wins an item!")
		meter.add_child(NestTheme.label(lucky_text, 17))
		var bar := NestTheme.progress(int(Save.data.crane.since_item), KinuCatcher.LUCKY_EVERY-1)
		var bar_fill := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		bar_fill.bg_color = Color("ffb62e")
		bar.add_theme_stylebox_override("fill", bar_fill)
		meter.add_child(bar)
		list.add_child(NestTheme.paper(meter))
	var rules := [
		"Every play wins exactly one prize.",
		NestTheme.t("Base cosmetic chance: %s. Rarity is rolled only after an item win.")%_percent(KinuCatcher.COSMETIC_ODDS),
		"Items you already own leave the machine, so every item you win is new. The chances below are for you, right now.",
		NestTheme.t("Lucky meter: after %d plays in a row without an item, the next play is always an item.")%(KinuCatcher.LUCKY_EVERY-1),
		"One free play every day. Free plays don't stack.",
		NestTheme.t("Tickets are a prize too: %s of plays win another go at the machine.")%_percent(KinuCatcher.TICKET_ODDS),
	]
	for rule in rules:
		var text := NestTheme.label(rule, 15)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(NestTheme.paper(text))
	var table := KinuCatcher.odds(catalog)
	var groups := [["tickets", "Free Plays"], ["beans", "Beans"], ["outfit", "Outfits"], ["box", "Boxes"], ["room", "Rooms"]]
	for group in groups:
		var rows := table.filter(func(row: Dictionary) -> bool: return row.entry.kind == group[0])
		if rows.is_empty():
			continue
		var total := 0.0
		for row in rows:
			total += float(row.chance)
		var heading := HBoxContainer.new()
		var title := NestTheme.headline(group[1], 24)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(title)
		heading.add_child(NestTheme.headline(_percent(total), 22, NestTheme.SUN))
		list.add_child(heading)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		for row in rows:
			var line := HBoxContainer.new()
			var entry: Dictionary = row.entry
			var name := ""
			if entry.kind == "tickets":
				name = NestTheme.t("1 ticket") if int(entry.amount) == 1 else NestTheme.t("%d tickets")%int(entry.amount)
			elif entry.kind == "beans":
				name = NestTheme.t("%s beans")%app._number(entry.amount)
			else:
				name = NestTheme.t(KinuCatcher.item_of(catalog, entry).display_name)
			var name_label := NestTheme.label(name, 16)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(name_label)
			if KinuCatcher.is_item(entry):
				name_label.add_theme_color_override("font_color", KinuCatcher.TIER_COLORS.get(entry.rarity, NestTheme.INK).darkened(.3))
				line.add_child(NestTheme.label(NestTheme.t(KinuCatcher.TIER_NAMES.get(entry.rarity, "")), 13, KinuCatcher.TIER_COLORS.get(entry.rarity, NestTheme.MUTED).darkened(.3)))
			line.add_child(NestTheme.label(_percent(float(row.chance)), 16, NestTheme.MUTED))
			box.add_child(line)
		list.add_child(NestTheme.paper(box))
	stack.add_child(NestTheme.button("Close", app._close_modal, true, "book"))

static func _percent(value: float) -> String:
	return ("%.2f%%" if value < 10.0 else "%.1f%%")%value

## "KINU CLAW" in lights, with bulbs chasing round the sign.
class Marquee extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(0, 58)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2(6, 2), size-Vector2(12, 6))
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color("3a2150")
		plate.border_color = NestTheme.INK
		plate.set_border_width_all(4)
		plate.set_corner_radius_all(18)
		draw_style_box(plate, rect)
		var bulbs := int(rect.size.x/22.0)
		var chase := int(Time.get_ticks_msec()/140.0)
		for i in bulbs:
			var x := rect.position.x+14+i*(rect.size.x-28)/maxf(bulbs-1, 1)
			for y in [rect.position.y+8, rect.end.y-8]:
				var on := (i+(0 if y < rect.get_center().y else 2)+chase) % 3 == 0
				draw_circle(Vector2(x, y), 4.5, Color("fff1a8") if on else Color("8a6a7a"))
		var font := NestTheme.font
		var text := TranslationServer.translate("KINU CLAW")
		var font_size := 30
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at := Vector2(rect.get_center().x-width*.5, rect.get_center().y+font_size*.36)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 10, NestTheme.INK)
		var glow := Color("ff8fb1").lerp(Color("ffe36e"), .5+.5*sin(Time.get_ticks_msec()*.004))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, glow)

## A soft pad beside the round button. Swiping the Turn pad turns and tilts the case; swiping the
## Move pad steers the claw while aiming (dragging the case itself does the same).
class SwipePad extends Control:
	var kind := "view"
	var pointer := -99

	func _ready() -> void:
		custom_minimum_size = Vector2(110, 118)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var motion := Vector2.ZERO
		if event is InputEventScreenTouch:
			pointer = event.index if event.pressed else -99
		elif event is InputEventScreenDrag and event.index == pointer:
			motion = event.relative
		elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			motion = event.relative
		var machine := KinuCatcherScreen.machine
		if motion == Vector2.ZERO or not is_instance_valid(machine):
			return
		accept_event()
		if kind == "move":
			machine.steer_claw(Vector2(motion.x, motion.y*1.4)*.02)
		else:
			machine.turn_view(motion)

	func _draw() -> void:
		var rect := Rect2(Vector2(4, 10), size-Vector2(8, 20))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, .35)
		style.border_color = NestTheme.INK
		style.set_border_width_all(3)
		style.set_corner_radius_all(22)
		draw_style_box(style, rect)
		var center := rect.get_center()-Vector2(0, 8)
		if kind == "view":
			draw_arc(center, 20, PI*.2, PI*1.8, 24, NestTheme.INK, 4, true)
			var tip := center+Vector2(cos(PI*.2), sin(PI*.2))*20
			draw_colored_polygon(PackedVector2Array([tip+Vector2(-9, -2), tip+Vector2(8, -6), tip+Vector2(2, 10)]), NestTheme.INK)
		else:
			for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var tip: Vector2 = center+direction*24
				var side := Vector2(-direction.y, direction.x)*7
				draw_colored_polygon(PackedVector2Array([tip, tip-direction*10+side, tip-direction*10-side]), NestTheme.INK)
		var font := NestTheme.font
		var text := NestTheme.t("Turn" if kind == "view" else "Move")
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var baseline := Vector2(size.x*.5-width*.5, rect.end.y-10)
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, NestTheme.INK)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NestTheme.CREAM)

## Glass glare and an inked frame over the machine view.
class Glass extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		for stripe in [[.12, 34.0], [.24, 12.0]]:
			var x: float = size.x*float(stripe[0])
			var width: float = stripe[1]
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x+width, 0), Vector2(x+width-size.y*.35, size.y), Vector2(x-size.y*.35, size.y)]), Color(1, 1, 1, .12))
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.border_color = NestTheme.INK
		frame.set_border_width_all(4)
		frame.set_corner_radius_all(14)
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
