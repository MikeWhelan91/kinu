class_name DailyTreats
extends Control
## The daily login sheet, built like a prize machine's front panel: a spotlit treat of the day
## over a seven day strip, with Day 7's claw prize sold on its own card. Width-bounded, and short
## displays scroll instead of pushing the modal off screen.

const PANEL := Color("3a1f55")
const DEEP := Color("1d0f2e")
const LOCKED := Color("3d2758")
const GOLD := Color("ffc65c")
const GOLD_BRIGHT := Color("fff0b8")
const BEAN_TINT := Color("f7b733")
const TICKET_TINT := Color("a86ef0")
const GRAND_TINT := Color("ff6fa5")
const DONE_FILL := Color("2e4a43")
const DONE_INK := Color("9fc2b5")
const CLAIM_LABEL := "CLAIM MY TREAT!"

static func open(app: Node) -> void:
	app._close_modal()
	var sheet := DailyTreats.new()
	app.modal = sheet
	sheet.add_to_group("modal_input_lock")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.screen.add_child(sheet)
	sheet.build(app)
	if Rewards.configured():
		sheet.call_deferred("refresh_from_server", app)

func refresh_from_server(app: Node) -> void:
	var previous_index := DailyCalendar.current_index()
	var previous_count := DailyCalendar.claimed_count()
	var status := await DailyCalendar.refresh_server_status()
	if not status.is_empty() and is_instance_valid(app) and app.modal == self and (DailyCalendar.current_index() != previous_index or DailyCalendar.claimed_count() != previous_count):
		DailyCalendar.show(app)

static func set_claim_pending(app: Node, pending: bool) -> void:
	if not is_instance_valid(app.modal):
		return
	var claim := app.modal.find_child("ClaimTreat", true, false) as Button
	if is_instance_valid(claim):
		claim.disabled = pending
		claim.text = "CHECKING…" if pending else CLAIM_LABEL

static func set_claim_error(app: Node, message: String) -> void:
	if not is_instance_valid(app.modal):
		return
	var label := app.modal.find_child("ClaimError", true, false) as Label
	if not is_instance_valid(label):
		label = NestTheme.label("", 14, Color("ffb5ad"))
		label.name = "ClaimError"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		app.modal.find_child("ClaimTreat", true, false).get_parent().add_child(label)
	label.text = message

## The prize family a square belongs to, which drives its card trim and icon.
static func tint(index: int) -> Color:
	var kind := str(DailyCalendar.REWARDS[index].kind)
	if kind == "beans":
		return BEAN_TINT
	return TICKET_TINT if kind == "tickets" else GRAND_TINT

## The short amount shown on a strip square, where there is no room for a noun.
static func amount_text(index: int) -> String:
	var reward: Dictionary = DailyCalendar.REWARDS[index]
	if str(reward.kind) == "beans":
		return "+%d" % int(reward.amount)
	if str(reward.kind) == "tickets":
		return "×%d" % int(reward.amount)
	return "???"

## The spotlight's headline, which does have room to name what the prize is.
static func headline_text(index: int) -> String:
	var reward: Dictionary = DailyCalendar.REWARDS[index]
	if str(reward.kind) == "beans":
		return "+%d BEANS" % int(reward.amount)
	if str(reward.kind) == "tickets":
		return "%d CLAW TICKET%s" % [int(reward.amount), "" if int(reward.amount) == 1 else "S"]
	return "CLAW TREASURE"

static func icon_for(index: int, reach: float) -> Control:
	var kind := str(DailyCalendar.REWARDS[index].kind)
	if kind == "beans":
		return BeanIcon.new(reach)
	return TicketIcon.new(reach) if kind == "tickets" else MysteryGift.new(reach)

func caption(parent: Node, text: String, points: int, color: Color) -> Label:
	var label := NestTheme.label(text, points, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func build(app: Node) -> void:
	var current := DailyCalendar.current_index()
	var checked := DailyCalendar.claimed_count()
	var shade := ColorRect.new()
	shade.color = Color(.06, .02, .12, .86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var rays := CapsuleReveal.Rays.new()
	rays.color = NestTheme.SUN
	rays.modulate.a = .20
	rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rays)
	var sparkles := Sparkles.new()
	sparkles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sparkles)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 20
	scroll.offset_right = -20
	scroll.offset_top = 24
	scroll.offset_bottom = -24
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "RewardSheet"
	panel.custom_minimum_size.x = minf(440, get_viewport_rect().size.x-40)
	var style := NestTheme.box(PANEL, 30, GOLD, 9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	panel.add_child(stack)
	_banner(stack)
	_streak(stack, current, checked)
	_spotlight(app, stack, current, checked)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	stack.add_child(grid)
	for index in 6:
		_day_card(grid, index, current, checked)
	_grand_card(app, stack, current, checked)
	if current >= 0:
		var claim := NestTheme.button(CLAIM_LABEL, func() -> void: DailyCalendar._claim_and_reveal(app), true, "plop")
		claim.name = "ClaimTreat"
		claim.custom_minimum_size.y = 76
		claim.add_theme_font_size_override("font_size", 26)
		stack.add_child(claim)
		claim.add_child(ButtonGloss.new())
		claim.add_child(Throb.new())
	else:
		_countdown(app, stack)
	var close := NestTheme.button("See you tomorrow!" if current < 0 else "Maybe later", app._close_modal, false, "plop")
	close.custom_minimum_size.y = 44
	close.add_theme_font_size_override("font_size", 18)
	stack.add_child(close)
	caption(stack, "Miss a day and the calendar restarts at Day 1.", 12, Color("b79fd0"))
	panel.modulate.a = 0
	var entrance := create_tween()
	entrance.tween_property(panel, "modulate:a", 1.0, .25)

## The header ribbon. Loud on purpose: this is the first thing the player sees each session.
func _banner(stack: Node) -> void:
	var banner := PanelContainer.new()
	var banner_style := NestTheme.box(Color("c7307f"), 18, GOLD_BRIGHT, 6)
	banner_style.content_margin_top = 6
	banner_style.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", banner_style)
	stack.add_child(banner)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	banner.add_child(body)
	var title := NestTheme.headline("DAILY TREATS", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	caption(body, "★  7 DAYS · 7 PRIZES  ★", 13, Color("ffdcee"))

## Seven notches under the banner, so the run of days reads at a glance before any text does.
func _streak(stack: Node, current: int, checked: int) -> void:
	var row := CenterContainer.new()
	stack.add_child(row)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	row.add_child(pips)
	for index in 7:
		var pip := Pip.new()
		pip.lit = index < checked
		pip.live = index == current
		pips.add_child(pip)
	caption(stack, "DAY %d OF 7" % mini(7, (checked+1) if current >= 0 else maxi(1, checked)), 15, GOLD)

## Today's prize, lit from behind and never quite still.
func _spotlight(app: Node, stack: Node, current: int, checked: int) -> void:
	var featured := current if current >= 0 else maxi(0, checked-1)
	var spotlight := PanelContainer.new()
	var spot_style := NestTheme.box(DEEP, 24, GOLD, 5)
	spot_style.content_margin_top = 8
	spot_style.content_margin_bottom = 12
	spotlight.add_theme_stylebox_override("panel", spot_style)
	spotlight.clip_contents = true
	stack.add_child(spotlight)
	var burst := CapsuleReveal.Rays.new()
	burst.color = tint(featured)
	burst.rotation_speed = .22
	burst.modulate.a = .32
	spotlight.add_child(burst)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	spotlight.add_child(body)
	caption(body, "TODAY'S TREAT" if current >= 0 else "COLLECTED TODAY", 13, Color("d9c2ef"))
	var hero := CenterContainer.new()
	hero.custom_minimum_size.y = 108
	body.add_child(hero)
	var bob := Bob.new()
	hero.add_child(bob)
	var kind := str(DailyCalendar.REWARDS[featured].kind)
	if kind == "beans":
		var bean := DailyBean.new()
		bean.custom_minimum_size = Vector2(100, 82)
		bob.add_child(bean)
	elif kind == "tickets":
		bob.add_child(TicketIcon.new(70))
	else:
		# The same grey mystery model used by undiscovered flavours in the Kinu Book.
		var mystery := KinuPreview.new()
		mystery.setup(app.run.catalog.shapes[0], app.run.catalog.flavours.back(), false, Vector2i(144, 108), "worried")
		bob.add_child(mystery)
	var prize := NestTheme.headline(headline_text(featured), 30, GOLD_BRIGHT if current >= 0 else Color("cbb6e0"))
	prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(prize)

## One square on the strip: locked, live or collected.
func _day_card(parent: Node, index: int, current: int, checked: int) -> void:
	var live := index == current
	var done := index < checked
	var accent := tint(index)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := Color("ffdc81") if live else (DONE_FILL if done else LOCKED)
	var edge := GOLD_BRIGHT if live else (Color("4a6f63") if done else accent.darkened(.4))
	var card_style := NestTheme.box(fill, 14, edge, 4)
	card_style.content_margin_left = 3
	card_style.content_margin_right = 3
	card_style.content_margin_top = 5
	card_style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)
	if live:
		card.add_child(Halo.new())
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 1)
	card.add_child(body)
	var ink := NestTheme.INK if live else (DONE_INK if done else Color("e4d2f5"))
	caption(body, "DAY %d" % (index+1), 12, ink)
	var icon_row := CenterContainer.new()
	icon_row.custom_minimum_size.y = 28
	body.add_child(icon_row)
	icon_row.add_child(icon_for(index, 26.0))
	caption(body, amount_text(index), 16, NestTheme.INK if live else (DONE_INK if done else accent))
	if done:
		body.modulate.a = .72
		card.add_child(Stamp.new())
	if live:
		card.add_child(Throb.new())

## Day 7 gets a card to itself: the whole strip exists to sell this one prize.
func _grand_card(app: Node, stack: Node, current: int, checked: int) -> void:
	var live := current == 6
	var done := checked >= 7
	var card := PanelContainer.new()
	var grand_style := NestTheme.box(DONE_FILL if done else Color("5d2a7d"), 18, GOLD_BRIGHT if live else GOLD, 6)
	grand_style.content_margin_top = 8
	grand_style.content_margin_bottom = 10
	grand_style.content_margin_left = 10
	grand_style.content_margin_right = 12
	card.add_theme_stylebox_override("panel", grand_style)
	card.clip_contents = true
	stack.add_child(card)
	var burst := CapsuleReveal.Rays.new()
	burst.color = GRAND_TINT
	burst.rotation_speed = .16
	burst.modulate.a = .12 if done else .30
	card.add_child(burst)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var art := CenterContainer.new()
	art.custom_minimum_size = Vector2(78, 64)
	row.add_child(art)
	var mystery := KinuPreview.new()
	mystery.setup(app.run.catalog.shapes[0], app.run.catalog.flavours.back(), false, Vector2i(78, 64), "happy" if done else "worried")
	art.add_child(mystery)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	text.add_child(NestTheme.label("★  TODAY · GRAND PRIZE  ★" if live else "★  DAY 7 · GRAND PRIZE  ★", 13, GOLD_BRIGHT if live else GOLD))
	var name_label := NestTheme.headline("Kinu Claw Treasure", 22, NestTheme.CREAM)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(name_label)
	text.add_child(NestTheme.label("Collected — back to Day 1 tomorrow!" if done else "A cosmetic only the claw can drop.", 12, Color("e6d2f5")))
	if done:
		row.modulate.a = .72
		var seal := Stamp.new()
		seal.reach = 16.0
		card.add_child(seal)
	if live:
		card.add_child(Throb.new())

## The wait between treats, framed like a machine's countdown rather than a line of body text.
func _countdown(app: Node, stack: Node) -> void:
	var card := PanelContainer.new()
	var card_style := NestTheme.box(DEEP, 16, GOLD, 4)
	card_style.content_margin_top = 6
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)
	stack.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	card.add_child(body)
	caption(body, "NEXT TREAT IN", 12, Color("d9c2ef"))
	var clock := caption(body, DailyCalendar.countdown_text().replace("Next treat in ", ""), 30, GOLD_BRIGHT)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(func() -> void:
		if DailyCalendar.ready():
			DailyCalendar.show(app)
		else:
			clock.text = DailyCalendar.countdown_text().replace("Next treat in ", ""))
	add_child(timer)
	timer.start()

class DailyBean extends Control:
	## A larger, seam-only soybean: no face or circular coin silhouette.
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size*.5
		var outline := PackedVector2Array()
		for i in 32:
			var a := TAU*i/32.0
			var bulge := 1.0+.13*cos(a*2.0)
			outline.append(c+Vector2(cos(a)*size.x*.37*bulge, sin(a)*size.y*.38*bulge))
		draw_colored_polygon(outline, Color("f2cf7c"))
		outline.append(outline[0])
		draw_polyline(outline, NestTheme.INK, 3.0, true)
		draw_arc(c+Vector2(size.x*.05, 0), size.y*.19, -.9, 1.5, 16, Color("a8743a"), 3.0, true)
		draw_circle(c+Vector2(-size.x*.17, -size.y*.14), size.y*.075, Color(1, 1, 1, .8))

class MysteryGift extends Control:
	## The Day 7 stand-in on the strip: a wrapped box, since the real prize is a surprise.
	func _init(reach: float = 24.0) -> void:
		custom_minimum_size = Vector2(reach, reach)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var body := Rect2(Vector2(size.x*.12, size.y*.36), Vector2(size.x*.76, size.y*.54))
		var box := StyleBoxFlat.new()
		box.bg_color = Color("ff6fa5")
		box.border_color = NestTheme.INK
		box.set_border_width_all(2)
		box.set_corner_radius_all(maxi(2, int(size.y*.10)))
		box.anti_aliasing = true
		draw_style_box(box, body)
		draw_rect(Rect2(Vector2(size.x*.43, body.position.y), Vector2(size.x*.14, body.size.y)), Color("ffe08a"))
		for side in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(size.x*.5, size.y*.37),
				Vector2(size.x*(.5+side*.3), size.y*.14),
				Vector2(size.x*(.5+side*.32), size.y*.36)]), Color("ffe08a"))
		draw_circle(Vector2(size.x*.5, size.y*.34), maxf(2.0, size.y*.09), Color("fff4df"))

class Pip extends Control:
	## One notch of the streak bar; the live notch keeps blinking until the treat is taken.
	var lit := false
	var live := false
	var _time := 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(22, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _ready() -> void:
		set_process(live)
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		var tone := Color("59d19a") if lit else Color("53386f")
		if live:
			tone = Color("ffc65c").lerp(Color("fff6d8"), .5+.5*sin(_time*4.0))
		var style := StyleBoxFlat.new()
		style.bg_color = tone
		style.set_corner_radius_all(5)
		style.border_color = NestTheme.INK
		style.set_border_width_all(2)
		style.anti_aliasing = true
		draw_style_box(style, Rect2(Vector2.ZERO, size))

class Stamp extends Control:
	## The collected seal. It sits in the corner at a slight angle, like a real stamp pressed on a
	## card, so the prize underneath can still be read back.
	var reach := 13.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_set_transform(size-Vector2.ONE*(reach+1.0), -.22, Vector2.ONE)
		draw_circle(Vector2.ZERO, reach, Color("2f8f66"))
		draw_arc(Vector2.ZERO, reach, 0, TAU, 28, Color("effcf5"), 2.5, true)
		draw_polyline(PackedVector2Array([
			Vector2(-reach*.44, 0), Vector2(-reach*.10, reach*.36), Vector2(reach*.50, -reach*.40)]),
			Color("effcf5"), maxf(3.0, reach*.24), true)

class Halo extends Control:
	## A breathing glow around today's square. Drawn behind its parent so the card stays crisp.
	var color := Color("ffdc81")
	var _time := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		var pulse := .55+.45*sin(_time*3.0)
		for ring in 3:
			var grow := 3.0+ring*5.0+pulse*3.0
			var tone := color
			tone.a = (.20-ring*.055)*pulse
			var style := StyleBoxFlat.new()
			style.bg_color = tone
			style.set_corner_radius_all(14+int(grow))
			style.anti_aliasing = true
			draw_style_box(style, Rect2(-Vector2.ONE*grow, size+Vector2.ONE*grow*2.0))

class Throb extends Control:
	## Rides inside a control and keeps it breathing. Only the host's scale changes, so it still
	## occupies its natural size in the layout.
	var amount := .025
	var speed := 3.2
	var _time := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		var host := get_parent() as Control
		if not is_instance_valid(host):
			return
		_time += delta
		host.pivot_offset = host.size*.5
		host.scale = Vector2.ONE*(1.0+amount*sin(_time*speed))

class Bob extends CenterContainer:
	## A gentle tilt and swell on the spotlit prize. Containers reset a child's position and size
	## every layout pass but leave rotation and scale alone, so the drift rides on those.
	var _time := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_time += delta
		pivot_offset = size*.5
		rotation = sin(_time*1.4)*.08
		scale = Vector2.ONE*(1.0+.045*sin(_time*2.3))

class Sparkles extends Control:
	## Slow drifting glints over the whole sheet, the way a prize cabinet catches the light.
	const COUNT := 24
	var _time := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		for i in COUNT:
			var spread := absf(fmod(sin(i*12.9898)*43758.5453, 1.0))
			var drop := absf(fmod(sin(i*78.233)*43758.5453, 1.0))
			var at := Vector2(spread*size.x, fmod(drop*size.y+_time*11.0*(.4+spread*.6), size.y))
			var reach := 3.0+spread*5.0
			var tone := GOLD_BRIGHT
			tone.a = .08+(.5+.5*sin(_time*2.4+i))*.34
			draw_colored_polygon(PackedVector2Array([
				at+Vector2(0, -reach), at+Vector2(reach*.28, 0), at+Vector2(0, reach), at+Vector2(-reach*.28, 0)]), tone)
			draw_colored_polygon(PackedVector2Array([
				at+Vector2(-reach, 0), at+Vector2(0, -reach*.28), at+Vector2(reach, 0), at+Vector2(0, reach*.28)]), tone)
