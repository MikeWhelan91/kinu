class_name TutorialCoach
extends Control
## First-run guide for each mode: a cheerful Kinu with a speech bubble and step dots, plus a
## cartoon finger that acts out each card's gesture over the real scene.

var app: Node
var title: Label
var text: Label
var button: Button
var dots: Control
var step: int = 0
var count: int = 5
var clock: float = 0.0
## What the hand acts out on each card ("slide", "drop", "spin", "press", "bottle", "toss_aim",
## "toss_fire" or "" for none), and the last card's button.
var gestures: Array = []
var finish_text := "Let’s Stack!"

func build(owner: Node, safe_bottom: float) -> void:
	app = owner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dock := HBoxContainer.new()
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_constant_override("separation", 4)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	var toss: bool = app.run.mode == "toss"
	var classic: bool = Save.data.controls == "classic" and not toss
	# Toss's aim box and Fire button fill the bottom of the screen just like the claw controls.
	var claw: bool = Save.data.controls == "claw" or toss
	# The claw sticks and Drop button fill the lower side of the screen. Keep the guide
	# above them so Skip Guide remains reachable during the first run.
	dock.grow_vertical = Control.GROW_DIRECTION_END if claw else Control.GROW_DIRECTION_BEGIN
	dock.anchor_top = .26 if claw else .78 if classic else 1.0
	dock.anchor_bottom = dock.anchor_top
	dock.offset_top = 0.0 if claw else -10.0 if classic else -safe_bottom-10.0
	dock.offset_bottom = dock.offset_top
	dock.offset_left = 18
	dock.offset_right = -18
	add_child(dock)
	var mascot_holder := VBoxContainer.new()
	mascot_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mascot_holder.alignment = BoxContainer.ALIGNMENT_END
	dock.add_child(mascot_holder)
	var catalog: KinuCatalog = app.run.catalog
	var mascot := KinuPreview.new()
	mascot.setup(catalog.shapes[0], MyKinu.mascot_flavour(catalog), true, Vector2i(118, 118), "happy", MyKinu.worn_outfit(catalog), false, false, MyKinu.worn_parts(catalog))
	mascot.fit_model(1.08, true)
	mascot_holder.add_child(mascot)
	var bubble := SpeechBubble.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paper := StyleBoxFlat.new()
	paper.bg_color = NestTheme.CREAM
	paper.border_color = NestTheme.INK
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(22)
	paper.set_content_margin_all(18)
	bubble.add_theme_stylebox_override("panel", paper)
	dock.add_child(bubble)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	bubble.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	title = NestTheme.label("", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	dots = StepDots.new()
	dots.coach = self
	dots.custom_minimum_size = Vector2(80, 26)

	text = NestTheme.label("", 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(dots)
	button = NestTheme.button("Skip Guide", app._finish_tutorial)
	button.custom_minimum_size.y = 44
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 16)
	footer.add_child(button)
	var hand := TutorialHand.new()
	hand.coach = self
	hand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hand)
	move_child(hand, 0)

func refresh(current: int, steps: Array) -> void:
	step = current
	count = steps.size()
	var entry: Array = steps[clampi(current, 0, count-1)]
	title.text = entry[0]
	text.text = entry[1]
	gestures.clear()
	for card in steps:
		gestures.append(card[2] if card.size() > 2 else "")
	dots.queue_redraw()
	if current == count-1:
		button.text = finish_text
		NestTheme.set_primary(button, true)

## A small open-seam tail points from the cream bubble toward the Kinu's face.
class SpeechBubble extends PanelContainer:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var y := size.y-64
		var tail := PackedVector2Array([Vector2(3,y-12),Vector2(-22,y+10),Vector2(3,y+8)])
		draw_colored_polygon(tail,NestTheme.CREAM)
		draw_polyline(PackedVector2Array([Vector2(0,y-12),tail[1],Vector2(0,y+8)]),NestTheme.INK,3,true)

class StepDots extends Control:
	var coach: TutorialCoach

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in coach.count:
			var at := Vector2(i*13+5, size.y*.5)
			draw_circle(at, 4.5, NestTheme.INK)
			draw_circle(at, 3, NestTheme.SUN if i <= coach.step else NestTheme.CREAM)

## A cartoon finger that demonstrates aiming, dropping and spinning.
class TutorialHand extends Control:
	var coach: TutorialCoach
	var fade: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		coach.clock += delta
		var run: NestRun = coach.app.run
		var wanted := 1.0 if gesture() != "" and run.gesture == "" and run.state == "aim" else 0.0
		fade = move_toward(fade, wanted, delta*3.0)
		queue_redraw()

	func gesture() -> String:
		return str(coach.gestures[coach.step]) if coach.step >= 0 and coach.step < coach.gestures.size() else ""

	func _draw() -> void:
		var run: NestRun = coach.app.run
		if fade <= 0.0 or not is_instance_valid(run.active):
			return
		var t := coach.clock
		var press := 0.0
		var alpha := fade
		# Toss's gestures happen on its own controls rather than over the held Kinu.
		if gesture().begins_with("toss_"):
			var target := coach.app.screen.find_child("TossAimBox" if gesture() == "toss_aim" else "TossFireButton", true, false) as Control
			if target == null:
				return
			var area := target.get_global_rect()
			var at := get_global_transform().affine_inverse()*area.get_center()
			if gesture() == "toss_aim":
				_draw_hand(at+Vector2(sin(t*2.0)*area.size.x*.3, cos(t*1.3)*area.size.y*.15-10), 0.0, alpha)
			else:
				# Press and hold, then let go.
				var phase := fmod(t, 2.0)/2.0
				press = clampf(phase/.15, 0.0, 1.0) if phase < .7 else 0.0
				if phase >= .7:
					alpha *= 1.0-(phase-.7)/.3
				_draw_hand(at+Vector2(-6, -18), press, alpha)
			return
		if not run.orbit.camera.is_inside_tree():
			return
		var held := run.orbit.camera.unproject_position(run.active.global_position)
		var tip := held+Vector2(0, 70)
		match gesture():
			"slide":
				tip.x += sin(t*2.2)*70
			"drop":
				var phase := fmod(t, 1.6)/1.6
				tip = held+Vector2(0, 40)
				if phase < .45:
					press = sin(phase/.45*PI)
				else:
					tip.y -= (phase-.45)*90
					alpha *= 1.0-(phase-.45)/.55
			"press":
				# The Sticky lesson is an ordinary drop; the badge on the Kinu does the explaining.
				var sticky_phase := fmod(t, 1.6)/1.6
				tip = held+Vector2(0, 50)
				if sticky_phase < .45:
					press = sin(sticky_phase/.45*PI)
				else:
					alpha *= 1.0-(sticky_phase-.45)/.55
			"bottle":
				var phase := fmod(t, 1.6)/1.6
				if run.aim_mode == "kinu" and is_instance_valid(coach.app.bottle_button):
					# Tap the bottle icon first...
					tip = coach.app.bottle_button.get_global_rect().get_center()+Vector2(-10, 14)
				else:
					# ...then let go over a crowded part of the pile.
					tip = held+Vector2(0, 50)
				if phase < .45:
					press = sin(phase/.45*PI)
				else:
					alpha *= 1.0-(phase-.45)/.55
			"spin":
				var phase := fmod(t, 1.4)/1.4
				if run.control_scheme() == "classic":
					var strip := run.spin_strip_rect()
					tip = Vector2(strip.get_center().x+lerpf(-130, 130, phase), strip.get_center().y-10)
				else:
					tip = Vector2(size.x*.5+lerpf(-130, 130, phase), size.y*.64)
				alpha *= minf(1.0, (1.0-phase)*4.0)
		_draw_hand(tip, press, alpha)

	func _draw_hand(tip: Vector2, press: float, alpha: float) -> void:
		var ink := Color(NestTheme.INK, alpha)
		var skin := Color(NestTheme.CREAM, alpha)
		if press > 0.0:
			draw_arc(tip, 14+press*22, 0, TAU, 32, Color(NestTheme.SUN, alpha*(1.0-press*.5)), 5, true)
		var squash := 1.0-press*.12
		var palm := StyleBoxFlat.new()
		palm.bg_color = skin
		palm.border_color = ink
		palm.set_border_width_all(4)
		palm.set_corner_radius_all(24)
		draw_style_box(palm, Rect2(tip+Vector2(-20, 34*squash), Vector2(56, 52)))
		var finger := StyleBoxFlat.new()
		finger.bg_color = skin
		finger.border_color = ink
		finger.set_border_width_all(4)
		finger.set_corner_radius_all(12)
		draw_style_box(finger, Rect2(tip+Vector2(-12, -2), Vector2(24, 60*squash)))
		for knuckle in 3:
			var x := tip.x+14+knuckle*9
			draw_line(Vector2(x, tip.y+40*squash), Vector2(x, tip.y+50*squash), ink, 3, true)
