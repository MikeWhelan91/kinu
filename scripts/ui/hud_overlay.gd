class_name HudOverlay
extends Control
## Draws play-screen helpers over the 3D scene: the classic spin strip, or curved "swipe to spin"
## arrows around the box while the hint shows in grab mode. Never takes input.
var run: NestRun
var app: Node
var hint: Control
var font: Font = NestTheme.font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if run == null:
		return
	match run.control_scheme():
		"classic", "bento":
			_draw_spin_strip()
		"claw":
			pass # The joysticks and drop button draw their own state; nothing to overlay here.
		_:
			if is_instance_valid(hint) and hint.visible and run.orbit.camera.is_inside_tree():
				_draw_spin_arrows(run.orbit.camera.unproject_position(Vector3(0, TofuBox.RIM_HEIGHT*.5, 0)))

func _draw_spin_strip() -> void:
	var strip := run.spin_strip_rect()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, .22 if run.gesture != "spin" else .38)
	style.border_color = Color(1, 1, 1, .7)
	style.set_border_width_all(3)
	style.set_corner_radius_all(30)
	draw_style_box(style, strip)
	var center := strip.get_center()
	var wobble := sin(Time.get_ticks_msec()*.004)*6.0
	for side in [-1.0, 1.0]:
		var tip := center+Vector2(side*(strip.size.x*.38+wobble), 0)
		draw_colored_polygon(PackedVector2Array([tip, tip+Vector2(-side*22, -18), tip+Vector2(-side*22, 18)]), NestTheme.INK)
		draw_colored_polygon(PackedVector2Array([tip+Vector2(-side*6, 0), tip+Vector2(-side*19, -10), tip+Vector2(-side*19, 10)]), NestTheme.CREAM)
	var text := tr("Swipe To Spin")
	var font_size := 24
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center+Vector2(-width*.5, font_size*.36)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, NestTheme.INK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, NestTheme.CREAM)

func _draw_spin_arrows(center: Vector2) -> void:
	var drift := sin(Time.get_ticks_msec()*.004)*.12
	var radius := size.x*.44
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for i in 13:
			var t: float = lerpf(-.35, .35, i/12.0)+drift*side
			var angle: float = (PI if side < 0 else 0.0)+t
			points.append(center+Vector2(cos(angle), sin(angle)*.42)*radius)
		draw_polyline(points, NestTheme.INK, 12, true)
		draw_polyline(points, NestTheme.CREAM, 6, true)
		var tip := points[points.size()-1 if side > 0 else 0]
		var before := points[points.size()-3 if side > 0 else 2]
		var forward := (tip-before).normalized()
		var normal := Vector2(-forward.y, forward.x)
		var head := PackedVector2Array([tip+forward*16, tip-forward*6+normal*14, tip-forward*6-normal*14])
		draw_colored_polygon(head, NestTheme.INK)
		var inner := PackedVector2Array([tip+forward*9, tip-forward*2+normal*7, tip-forward*2-normal*7])
		draw_colored_polygon(inner, NestTheme.CREAM)
