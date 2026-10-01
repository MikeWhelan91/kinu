class_name GachaButton
extends Button
## A prize-machine style home button: a candy gradient cabinet in a gold rim, a gloss cap, a shine
## that sweeps across every few seconds, twinkling sparkles, and a custom illustration that pops
## out over the top edge. Titles stay real Labels so they translate and can be found by tests.

const RIM := Color("ffd76a")
const RIM_DEEP := Color("c9871f")
const SWEEP_PERIOD := 3.4
const SWEEP_TIME := .6

## "my_kinu" or "claw": which illustration to draw.
var icon_kind := "my_kinu"
var top_color := Color("9b7bff")
var bottom_color := Color("6a45d8")
var edge_color := Color("3d2380")
## Colour of the player's Kinu in the My Kinu illustration.
var kinu_color := Color("cfe8a0")
var hat := true
var title_text := ""
var subtitle_text := ""
## 0..1 progress drawn as a small bar under the subtitle, or negative for none.
var progress := -1.0
## A red count in the corner, hidden at 0.
var badge := 0
## A ribbon across the top-right corner ("FREE"), or empty.
var ribbon := ""
var phase := 0.0
var _pressed_scale := 1.0

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = false
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art := GachaIcon.new()
	art.name = "GachaIcon"
	art.owner_button = self
	add_child(art)
	var text := VBoxContainer.new()
	text.name = "Text"
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 1)
	add_child(text)
	var title := NestTheme.label(title_text, 19, NestTheme.CREAM)
	title.name = "Title"
	title.add_theme_color_override("font_outline_color", edge_color)
	title.add_theme_constant_override("outline_size", 7)
	title.add_theme_color_override("font_shadow_color", Color(edge_color, .6))
	title.add_theme_constant_override("shadow_offset_y", 2)
	text.add_child(title)
	if subtitle_text != "":
		var subtitle := NestTheme.label(subtitle_text, 13, Color(1, 1, 1, .95))
		subtitle.name = "Subtitle"
		subtitle.add_theme_color_override("font_outline_color", Color(edge_color, .8))
		subtitle.add_theme_constant_override("outline_size", 4)
		text.add_child(subtitle)
	if progress >= 0:
		var bar := Control.new()
		bar.name = "Progress"
		bar.custom_minimum_size = Vector2(0, 8)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(func() -> void:
			var track := Rect2(Vector2.ZERO, Vector2(minf(bar.size.x, 92), bar.size.y))
			bar.draw_colored_polygon(MyKinuScreen.rounded_points(track, 4), Color(0, 0, 0, .3))
			if progress > 0:
				var fill := Rect2(Vector2.ZERO, Vector2(maxf(8, track.size.x*clampf(progress, 0, 1)), track.size.y))
				bar.draw_colored_polygon(MyKinuScreen.rounded_points(fill, 4), RIM)
				bar.draw_line(Vector2(4, 2.5), Vector2(fill.size.x-4, 2.5), Color(1, 1, 1, .7), 1.5, true)
		)
		text.add_child(bar)
	resized.connect(_layout)
	button_down.connect(func() -> void: _squash(.95))
	button_up.connect(func() -> void: _squash(1.0))
	_layout()

func _layout() -> void:
	pivot_offset = size*.5
	var art := get_node_or_null("GachaIcon") as Control
	var icon_size := size.y-10
	if art:
		art.size = Vector2(icon_size, icon_size)
		# Kept inside the rim: nothing pokes over the cabinet's edge.
		art.position = Vector2(6, 5)
	var text := get_node_or_null("Text") as Control
	if text:
		var left := icon_size+8
		text.position = Vector2(left, 6)
		text.size = Vector2(maxf(size.x-left-10, 10), size.y-14)
		var title := text.get_node_or_null("Title") as Label
		if title:
			# Shrink long or translated titles to fit rather than spilling past the rim.
			var font_size := 19
			while font_size > 13 and NestTheme.font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > text.size.x-4:
				font_size -= 1
			title.add_theme_font_size_override("font_size", font_size)

func _squash(target: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE*target, .08)

func _process(delta: float) -> void:
	phase += delta
	queue_redraw()
	var art := get_node_or_null("GachaIcon") as Control
	if art:
		art.queue_redraw()

func _draw() -> void:
	var body := Rect2(Vector2.ZERO, size)
	var radius := 20.0
	# Drop shadow and a deep lower lip, so the cabinet stands proud of the tray.
	draw_colored_polygon(MyKinuScreen.rounded_points(Rect2(Vector2(0, 5), size), radius), Color(0, 0, 0, .35))
	draw_colored_polygon(MyKinuScreen.rounded_points(Rect2(Vector2(0, 3), size), radius), edge_color)
	# Gold rim.
	var rim := MyKinuScreen.rounded_points(body, radius)
	var rim_colors := PackedColorArray()
	for point in rim:
		rim_colors.append(RIM.lerp(RIM_DEEP, point.y/maxf(size.y, 1)))
	draw_polygon(rim, rim_colors)
	# Candy gradient face inside the rim.
	var face_rect := body.grow(-4)
	var face := MyKinuScreen.rounded_points(face_rect, radius-4)
	var face_colors := PackedColorArray()
	for point in face:
		face_colors.append(top_color.lerp(bottom_color, clampf((point.y-face_rect.position.y)/face_rect.size.y, 0, 1)))
	draw_polygon(face, face_colors)
	# Diagonal candy stripes, very faint.
	for i in int(size.x/22)+4:
		var x := -size.y+i*22.0+fmod(phase*8.0, 22.0)
		var stripe := PackedVector2Array([Vector2(x, face_rect.end.y), Vector2(x+10, face_rect.end.y), Vector2(x+10+face_rect.size.y, face_rect.position.y), Vector2(x+face_rect.size.y, face_rect.position.y)])
		_clipped(stripe, face_rect, Color(1, 1, 1, .06))
	# Gloss cap across the top half.
	var cap := MyKinuScreen.rounded_points(Rect2(face_rect.position+Vector2(6, 2), Vector2(face_rect.size.x-12, face_rect.size.y*.42)), radius-8)
	draw_colored_polygon(cap, Color(1, 1, 1, .2))
	# Shine sweep.
	var sweep := fmod(phase, SWEEP_PERIOD)
	if sweep < SWEEP_TIME:
		var x := lerpf(-60, size.x+60, sweep/SWEEP_TIME)
		var streak := PackedVector2Array([Vector2(x, face_rect.end.y), Vector2(x+26, face_rect.end.y), Vector2(x+26+size.y*.5, face_rect.position.y), Vector2(x+size.y*.5, face_rect.position.y)])
		_clipped(streak, face_rect, Color(1, 1, 1, .35))
	# Twinkles.
	for i in 3:
		var at := Vector2(size.x*(.5+.17*i), size.y*(.25+.22*(i % 2)))
		var twinkle := maxf(0, sin(phase*2.4+i*2.1))
		if twinkle > .05:
			_star(at, 5.0*twinkle, Color(1, 1, 1, .9*twinkle))
	# Ink outline.
	var outline := rim.duplicate()
	outline.append(rim[0])
	draw_polyline(outline, Color("321b14"), 2.0, true)
	if ribbon != "":
		_ribbon()
	if badge > 0:
		_badge()

## Draws `shape` only where it overlaps `area`; good enough for the slanted stripes and streak.
func _clipped(shape: PackedVector2Array, area: Rect2, color: Color) -> void:
	var clipped := Geometry2D.intersect_polygons(shape, MyKinuScreen.rounded_points(area, 16))
	for piece in clipped:
		draw_colored_polygon(piece, color)

func _star(at: Vector2, extent: float, color: Color) -> void:
	var star := PackedVector2Array()
	for j in 8:
		star.append(at+Vector2.UP.rotated(TAU*j/8.0)*extent*(1.7 if j % 2 == 0 else .38))
	draw_colored_polygon(star, color)

func _ribbon() -> void:
	var font := NestTheme.font
	var width := font.get_string_size(ribbon, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x+16
	var at := Vector2(size.x-width-10, -9)
	var tag := Rect2(at, Vector2(width, 20))
	var bob := sin(phase*3.0)*1.5
	tag.position.y += bob
	draw_colored_polygon(MyKinuScreen.rounded_points(tag.grow(2), 10), Color("321b14"))
	draw_colored_polygon(MyKinuScreen.rounded_points(tag, 9), Color("ffe04a"))
	draw_string(font, tag.position+Vector2(8, 15), ribbon, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8d2a55"))

func _badge() -> void:
	var text := str(badge) if badge < 100 else "99+"
	var font := NestTheme.font
	var pop := 1.0+.08*maxf(0, sin(phase*4.0))
	var radius := 13.0*pop
	var at := Vector2(size.x-8, 4)
	draw_circle(at+Vector2(0, 2), radius+2, Color(0, 0, 0, .3))
	draw_circle(at, radius+2.5, NestTheme.CREAM)
	draw_circle(at, radius, Color("e5383b"))
	draw_arc(at, radius*.62, PI*1.1, PI*1.55, 8, Color(1, 1, 1, .6), 2.0, true)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, at+Vector2(-width*.5, 5.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, NestTheme.CREAM)

## The illustration that pops out of the cabinet: My Kinu in its hat, or a claw lifting a capsule.
class GachaIcon extends Control:
	var owner_button: GachaButton

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not is_instance_valid(owner_button):
			return
		var s := minf(size.x, size.y)
		var t := owner_button.phase
		# A glow disc behind the art.
		draw_circle(Vector2(s*.5, s*.56), s*.4, Color(1, 1, 1, .18))
		if owner_button.icon_kind == "claw":
			_claw(s, t)
		else:
			_kinu(s, t)

	func _outlined(points: PackedVector2Array, fill: Color, width: float = 2.5) -> void:
		draw_colored_polygon(points, fill)
		var line := points.duplicate()
		line.append(points[0])
		draw_polyline(line, NestTheme.INK, width, true)

	func _kinu(s: float, t: float) -> void:
		var bob := sin(t*2.2)*s*.02
		var tilt := sin(t*1.3)*.05
		var body := Rect2(Vector2(s*.2, s*.36+bob), Vector2(s*.6, s*.5))
		var centre := body.get_center()
		var corners := MyKinuScreen.rounded_points(body, s*.12)
		var turned := PackedVector2Array()
		for point in corners:
			turned.append(centre+(point-centre).rotated(tilt))
		var shadow := MyKinuScreen.ellipse_points(Vector2(s*.5, s*.9), Vector2(s*.27, s*.045))
		draw_colored_polygon(shadow, Color(0, 0, 0, .25))
		_outlined(turned, owner_button.kinu_color, 3.0)
		# Side shading and a gloss.
		var shade := PackedVector2Array()
		for point in MyKinuScreen.rounded_points(Rect2(body.position+Vector2(body.size.x*.72, 4), Vector2(body.size.x*.22, body.size.y-8)), s*.08):
			shade.append(centre+(point-centre).rotated(tilt))
		draw_colored_polygon(shade, Color(0, 0, 0, .08))
		draw_arc(centre+Vector2(-body.size.x*.24, -body.size.y*.22).rotated(tilt), s*.07, PI*1.05, PI*1.6, 8, Color(1, 1, 1, .8), 2.5, true)
		# Face: eyes with shines, blush and a smile; it blinks now and then.
		var blink := fmod(t, 3.8) < .12
		for side in [-1.0, 1.0]:
			var eye := centre+Vector2(side*body.size.x*.2, -body.size.y*.02).rotated(tilt)
			if blink:
				draw_line(eye+Vector2(-s*.03, 0), eye+Vector2(s*.03, 0), NestTheme.INK, 2.5, true)
			else:
				draw_circle(eye, s*.042, NestTheme.INK)
				draw_circle(eye+Vector2(-s*.012, -s*.014), s*.014, Color.WHITE)
			draw_circle(centre+Vector2(side*body.size.x*.32, body.size.y*.16).rotated(tilt), s*.04, Color("ff9fb0", .85))
		draw_arc(centre+Vector2(0, body.size.y*.08).rotated(tilt), s*.035, PI*.15, PI*.85, 8, NestTheme.INK, 2.5, true)
		# Top hat with a red band, cocked to one side.
		if owner_button.hat:
			var hat_base := centre+Vector2(body.size.x*.08, -body.size.y*.5).rotated(tilt)
			var hat_tilt := tilt+.12
			var brim := PackedVector2Array()
			for point in MyKinuScreen.ellipse_points(Vector2.ZERO, Vector2(s*.2, s*.05), 24):
				brim.append(hat_base+point.rotated(hat_tilt))
			var crown := PackedVector2Array([Vector2(-s*.12, 0), Vector2(s*.12, 0), Vector2(s*.11, -s*.22), Vector2(-s*.11, -s*.22)])
			var crown_turned := PackedVector2Array()
			for point in crown:
				crown_turned.append(hat_base+point.rotated(hat_tilt))
			_outlined(crown_turned, Color("2b2730"))
			var band := PackedVector2Array([Vector2(-s*.12, -s*.02), Vector2(s*.12, -s*.02), Vector2(s*.118, -s*.07), Vector2(-s*.118, -s*.07)])
			var band_turned := PackedVector2Array()
			for point in band:
				band_turned.append(hat_base+point.rotated(hat_tilt))
			draw_colored_polygon(band_turned, Color("d8434f"))
			_outlined(brim, Color("2b2730"))
		# A sparkle that orbits the Kinu.
		var orbit := Vector2(s*.5, s*.55)+Vector2(cos(t*1.5), sin(t*1.5)*.5)*s*.42
		_spark(orbit, s*.05)

	func _claw(s: float, t: float) -> void:
		var swing := sin(t*1.8)*.08
		var pivot := Vector2(s*.52, 0)
		var reach := s*.34+sin(t*1.1)*s*.03
		var head := pivot+Vector2(0, reach).rotated(swing)
		# Cable and the claw head.
		draw_line(pivot, head, Color("4a4f5a"), s*.035, true)
		draw_line(pivot, head, Color("9aa3b0"), s*.015, true)
		var cap := PackedVector2Array([head+Vector2(-s*.11, -s*.02), head+Vector2(s*.11, -s*.02), head+Vector2(s*.08, s*.07), head+Vector2(-s*.08, s*.07)])
		_outlined(cap, Color("c7ced8"))
		# Capsule held in the claw, gently swinging with it.
		var ball := head+Vector2(0, s*.27)
		var radius := s*.2
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		for i in 25:
			var angle := PI+PI*float(i)/24.0
			top.append(ball+Vector2(cos(angle), sin(angle))*radius)
			bottom.append(ball+Vector2(cos(angle-PI), sin(angle-PI))*radius)
		draw_colored_polygon(top, Color("ff5d8f"))
		draw_colored_polygon(bottom, Color("fff6ea"))
		draw_line(ball+Vector2(-radius, 0), ball+Vector2(radius, 0), NestTheme.INK, 2.5, true)
		draw_arc(ball, radius, 0, TAU, 40, NestTheme.INK, 3.0, true)
		draw_arc(ball+Vector2(-radius*.25, -radius*.3), radius*.45, PI*1.05, PI*1.55, 10, Color(1, 1, 1, .85), 3.0, true)
		draw_circle(ball+Vector2(radius*.45, radius*.4), radius*.08, Color("ffd76a"))
		# Prongs gripping the capsule.
		for side in [-1.0, 1.0]:
			var root := head+Vector2(side*s*.07, s*.06)
			var elbow := root+Vector2(side*s*.12, s*.12)
			var tip := ball+Vector2(side*radius*.8, -radius*.15)
			draw_polyline(PackedVector2Array([root, elbow, tip]), NestTheme.INK, s*.06, true)
			draw_polyline(PackedVector2Array([root, elbow, tip]), Color("c7ced8"), s*.035, true)
		for i in 2:
			var at := Vector2(s*(.18+.66*i), s*(.5+.18*i))
			var twinkle := maxf(0, sin(t*2.6+i*2.0))
			_spark(at, s*.045*twinkle)

	func _spark(at: Vector2, extent: float) -> void:
		if extent <= .5:
			return
		var star := PackedVector2Array()
		for j in 8:
			star.append(at+Vector2.UP.rotated(TAU*j/8.0)*extent*(1.7 if j % 2 == 0 else .4))
		draw_colored_polygon(star, Color("fff3b0"))
