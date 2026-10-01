class_name HomeTour
extends Control
## A one-time walk round the home screen for a new player, shown the first time they come back from
## a run. The screen dims, a spotlight opens over one part of it, and the same Kinu guide as the
## first-run tutorial explains it from a speech bubble. Tap anywhere to move on; Skip ends it.
##
## Targets are looked up by name and re-measured every frame, because the curtains sway and the
## event rail settles into place a moment after the home screen appears.

const SHADE := Color(.05, .03, .1, .72)
const PAD := 10.0
const RADIUS := 20.0
## Enough height for the Kinu and a three-line bubble.
const DOCK_HEIGHT := 150.0

const HOLE_SHADER := """
shader_type canvas_item;
uniform vec4 hole;
uniform float radius;
uniform vec4 shade : source_color;
uniform vec2 extent;
void fragment() {
	vec2 p = UV*extent;
	vec2 half_size = hole.zw*.5;
	vec2 q = abs(p-(hole.xy+half_size))-half_size+radius;
	float d = length(max(q, 0.))+min(max(q.x, q.y), 0.)-radius;
	COLOR = vec4(shade.rgb, shade.a*smoothstep(-1.5, 1.5, d));
}
"""

var app: Node
var steps: Array = []
var step := 0
var hole := Rect2()
var shown_hole := Rect2()
var clock := 0.0
var shade_rect: ColorRect
var ring: Ring
var dock: HBoxContainer
var title: Label
var text: Label
var dots: Dots
var skip: Button
var next_button: Button
var later_button: Button
## Whether today's free Claw play is waiting, read as the last stop appears (the server's answer
## can land while the tour is open) so its text and its buttons always agree.
var free_play := false

## After the first finished run, whether or not the in-run guide was seen through to its last card
## (leaving a run partway through leaves that guide unfinished, and shouldn't cost the tour too).
static func should_show() -> bool:
	return int(Save.data.runs) >= 1 and not bool(Save.data.get("home_tour", false))

## Starts the tour once the home screen has settled, if nothing else has claimed it meanwhile.
static func prompt(app: Node) -> void:
	app.get_tree().create_timer(.45).timeout.connect(func() -> void:
		if not is_instance_valid(app) or app.page != "home" or is_instance_valid(app.modal) or not should_show():
			return
		start(app))

static func start(owner: Node) -> void:
	var tour := HomeTour.new()
	tour.app = owner
	owner.modal = tour
	tour.add_to_group("modal_input_lock")
	tour.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.screen.add_child(tour)
	tour._build()
	Analytics.track("home_tour", {"event": "start"})

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	steps = _steps()
	shade_rect = ColorRect.new()
	shade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = HOLE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("radius", RADIUS)
	material.set_shader_parameter("shade", SHADE)
	shade_rect.material = material
	add_child(shade_rect)
	ring = Ring.new()
	ring.tour = self
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ring)
	_build_dock()
	skip = NestTheme.button("Skip", func() -> void: _finish("skip"), false, "tap")
	skip.name = "HomeTourSkip"
	skip.custom_minimum_size = Vector2(88, 44)
	skip.add_theme_font_size_override("font_size", 16)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -16
	skip.offset_top = float(app.safe_top)+10
	add_child(skip)
	modulate.a = 0
	dock.visible = false
	# The first stop is placed once this layer has its real size.
	await get_tree().process_frame
	dock.visible = true
	create_tween().tween_property(self, "modulate:a", 1.0, .25)
	_show_step(0, true)

func _build_dock() -> void:
	dock = HBoxContainer.new()
	dock.name = "HomeTourDock"
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_constant_override("separation", 4)
	add_child(dock)
	var catalog: KinuCatalog = app.run.catalog
	var look: KinuFlavour = catalog.pattern(str(Save.data.outfit))
	var mascot := KinuPreview.new()
	mascot.setup(catalog.shapes[0], look if look else catalog.flavours[0], true, Vector2i(104, 104), "happy", catalog.outfit(str(Save.data.outfit)))
	mascot.fit_model(1.08, true)
	var mascot_holder := VBoxContainer.new()
	mascot_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mascot_holder.alignment = BoxContainer.ALIGNMENT_END
	mascot_holder.add_child(mascot)
	dock.add_child(mascot_holder)
	var bubble := TutorialCoach.SpeechBubble.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paper := StyleBoxFlat.new()
	paper.bg_color = NestTheme.CREAM
	paper.border_color = NestTheme.INK
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(22)
	paper.set_content_margin_all(14)
	bubble.add_theme_stylebox_override("panel", paper)
	dock.add_child(bubble)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	bubble.add_child(column)
	title = NestTheme.label("", 20)
	column.add_child(title)
	text = NestTheme.label("", 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	dots = Dots.new()
	dots.tour = self
	dots.custom_minimum_size = Vector2(80, 22)
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(dots)
	later_button = NestTheme.button("Later", func() -> void: _finish("done"), false, "tap")
	later_button.custom_minimum_size.y = 40
	later_button.add_theme_font_size_override("font_size", 15)
	footer.add_child(later_button)
	next_button = NestTheme.button("Next", _next, true, "plop")
	next_button.name = "HomeTourNext"
	next_button.custom_minimum_size.y = 40
	next_button.add_theme_font_size_override("font_size", 16)
	footer.add_child(next_button)

## [target node names (the spotlight covers all of them), title, text].
func _steps() -> Array:
	var rail_text := NestTheme.t("Your daily treat, the Grand Opening and the Monthly Showcase live here. A red dot means something is waiting for you.") if GrandOpening.active() else NestTheme.t("Your daily treat and the Monthly Showcase live here. A red dot means something is waiting for you.")
	var modes_text := NestTheme.t("Switch between Classic, Tower and Toss here.")
	if not NestRun.mode_unlocked("toss"):
		modes_text = NestTheme.t("Classic is all about filling the box. Pile %d Kinu in one run to unlock Tower, and %d for Toss.")%[NestRun.MODE_UNLOCK.tower, NestRun.MODE_UNLOCK.toss]
	var all := [
		[["Shop", "Wardrobe"], NestTheme.t("Shop & Wardrobe"), NestTheme.t("Spend beans on outfits, boxes and rooms in the Shop, then dress up your Kinu in the Wardrobe.")],
		[["Kinu Book"], NestTheme.t("Kinu Book"), NestTheme.t("Everything you can collect, and how to get it. New unlocks wait here with a badge.")],
		[["Daily"], NestTheme.t("Daily Missions"), NestTheme.t("Three new missions every day, plus a weekly challenge. Finish them for beans!")],
		[["EventRail"], NestTheme.t("Events"), rail_text],
		[["ModePicker"], NestTheme.t("Game Modes"), modes_text],
		[["Catcher"], NestTheme.t("Kinu Claw"), ""],
	]
	# A stop whose target isn't on this home screen is left out rather than pointing at nothing.
	return all.filter(func(entry: Array) -> bool: return _target_rect(entry[0]).has_area())

func _target_rect(names: Array) -> Rect2:
	var area := Rect2()
	for target_name in names:
		var node := app.screen.find_child(target_name, true, false) as Control
		if node == null or not node.is_visible_in_tree():
			continue
		var rect := node.get_global_rect()
		# A curtain's button covers its whole hanging cloth; the light goes on its emblem.
		if node.has_meta("curtain_target"):
			for sibling in node.get_parent().get_children():
				if sibling is MenuIcon:
					rect = (sibling as Control).get_global_rect().grow(8)
		# The rail's buttons carry status pills and a red dot outside their own box, so its whole
		# column is lit rather than just the button.
		area = rect if not area.has_area() else area.merge(rect)
	if not area.has_area():
		return area
	var local := get_global_transform().affine_inverse()*area
	return local.grow(PAD)

func _show_step(index: int, instant: bool = false) -> void:
	step = index
	var entry: Array = steps[step]
	var last := step == steps.size()-1
	free_play = KinuCatcher.free_ready()
	title.text = entry[1]
	text.text = entry[2]
	if entry[0] == ["Catcher"]:
		text.text = NestTheme.t("Win outfits, boxes and rooms. Two free claw tickets refill together!") if free_play else NestTheme.t("Win outfits, boxes and rooms with beans or claw tickets.")
	dots.queue_redraw()
	next_button.text = NestTheme.t("Try it!") if last and free_play else (NestTheme.t("Done") if last else NestTheme.t("Next"))
	later_button.visible = last and free_play
	skip.visible = not last
	hole = _target_rect(entry[0])
	if instant:
		shown_hole = hole
	Sound.play("tap")
	_place_dock()
	dock.modulate.a = 0
	create_tween().tween_property(dock, "modulate:a", 1.0, .2)

## The guide sits on whichever side of the screen the spotlight isn't, so it never covers it.
func _place_dock() -> void:
	var width := size.x-32
	var above := hole.get_center().y > size.y*.5
	var y: float
	if above:
		y = maxf(float(app.safe_top)+64, hole.position.y-DOCK_HEIGHT-24)
	else:
		y = minf(size.y-float(app.safe_bottom)-DOCK_HEIGHT-20, hole.end.y+24)
	# Wrapped text measures its height against its width, so it's given the bubble's width up front;
	# without it the first stop lays out one word per line and the bubble runs off the screen.
	text.custom_minimum_size.x = width-104-4-28
	dock.position = Vector2(16, y)
	dock.custom_minimum_size = Vector2(width, 0)
	dock.size = Vector2(width, 0)
	# A container keeps a size it has grown to, so it's shrunk back to fit once the new text has
	# measured itself.
	get_tree().process_frame.connect(func() -> void:
		if is_instance_valid(dock):
			dock.size = Vector2(width, 0), CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	clock += delta
	if steps.is_empty():
		return
	var live := _target_rect(steps[step][0])
	if live.has_area():
		hole = live
	var blend := 1.0-exp(-delta*12.0)
	shown_hole = Rect2(shown_hole.position.lerp(hole.position, blend), shown_hole.size.lerp(hole.size, blend))
	var material := shade_rect.material as ShaderMaterial
	material.set_shader_parameter("hole", Vector4(shown_hole.position.x, shown_hole.position.y, shown_hole.size.x, shown_hole.size.y))
	material.set_shader_parameter("extent", size)
	ring.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		accept_event()
		_next()

func _next() -> void:
	if step >= steps.size()-1:
		_finish("claw" if free_play else "done")
		return
	_show_step(step+1)

## Ends the tour for good. It covers the Grand Opening and Showcase, so their own announcements
## aren't repeated straight after; the daily treat still gets its turn.
func _finish(how: String) -> void:
	Save.data.home_tour = true
	if GrandOpening.active():
		GrandOpening.mark_announced()
	if KinuShowcase.active():
		KinuShowcase.mark_announced()
	Save.persist()
	Analytics.track("home_tour", {"event": how, "step": step})
	var owner := app
	owner._close_modal()
	if how == "claw":
		KinuCatcherScreen.show(owner)
	elif owner.page == "home":
		DailyCalendar.prompt(owner)

## A soft pulsing outline round the spotlight.
class Ring extends Control:
	var tour: HomeTour
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var area := tour.shown_hole
		if not area.has_area():
			return
		var pulse := .5+.5*sin(tour.clock*4.0)
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.set_corner_radius_all(int(RADIUS))
		style.set_border_width_all(4)
		style.border_color = Color(NestTheme.SUN, .65+.35*pulse)
		draw_style_box(style, area.grow(2+pulse*3))

class Dots extends Control:
	var tour: HomeTour
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in tour.steps.size():
			var at := Vector2(i*13+5, size.y*.5)
			draw_circle(at, 4.5, NestTheme.INK)
			draw_circle(at, 3, NestTheme.SUN if i <= tour.step else NestTheme.CREAM)
