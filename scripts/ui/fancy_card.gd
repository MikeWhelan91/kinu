class_name FancyCard
extends PanelContainer
## The game's premium card, shared by the My Kinu celebration and the results screen: a sky
## gradient in a gold frame with diamond studs, slowly turning rays and twinkles. Children lay out
## inside it like any PanelContainer; everything here is drawn underneath them.

var top_color := Color("e6f5ff")
var bottom_color := Color("a9d4f0")
var radius := 30.0
var rays := true
## Where the rays fan out from, as a fraction of the card's size.
var ray_origin := Vector2(.5, .28)
var phase := 0.0

func _init() -> void:
	var margins := StyleBoxEmpty.new()
	margins.content_margin_left = 24
	margins.content_margin_right = 24
	margins.content_margin_top = 22
	margins.content_margin_bottom = 22
	add_theme_stylebox_override("panel", margins)

func _process(delta: float) -> void:
	phase += delta
	queue_redraw()

func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	draw_colored_polygon(MyKinuScreen.rounded_points(Rect2(Vector2(0, 9), size), radius), Color(.12, .05, .02, .35))
	var body := MyKinuScreen.rounded_points(outer, radius)
	var shades := PackedColorArray()
	for point in body:
		shades.append(top_color.lerp(bottom_color, clampf(point.y/maxf(size.y, 1), 0, 1)))
	draw_polygon(body, shades)
	if rays:
		var centre := size*ray_origin
		for i in 18:
			var angle := TAU*float(i)/18.0+phase*.05
			var direction := Vector2.RIGHT.rotated(angle)
			var side := direction.orthogonal()
			var reach := size.length()
			var ray := PackedVector2Array([centre+side*3, centre+direction*reach+side*reach*.09, centre+direction*reach-side*reach*.09, centre-side*3])
			var clipped := Geometry2D.intersect_polygons(ray, body)
			for piece in clipped:
				draw_colored_polygon(piece, Color(1, 1, 1, .2 if i % 2 == 0 else .08))
	var spots := [Vector2(.1, .12), Vector2(.9, .1), Vector2(.94, .45), Vector2(.07, .55), Vector2(.88, .82)]
	for i in spots.size():
		var twinkle := .5+.5*sin(phase*2.0+float(i)*1.4)
		var at := Vector2(size.x*spots[i].x, size.y*spots[i].y)
		var star := PackedVector2Array()
		for j in 8:
			star.append(at+Vector2.UP.rotated(TAU*j/8.0)*(6.0 if i % 2 == 0 else 4.0)*twinkle*(1.7 if j % 2 == 0 else .38))
		draw_colored_polygon(star, Color(1, 1, 1, .95*twinkle))
	var edge := body.duplicate()
	edge.append(body[0])
	draw_polyline(edge, NestTheme.INK, 5.0, true)
	var inner := MyKinuScreen.rounded_points(outer.grow(-9), radius-9)
	inner.append(inner[0])
	draw_polyline(inner, MyKinuScreen.GOLD, 2.5, true)
	for corner in [Vector2(9, 9), Vector2(size.x-9, 9), Vector2(9, size.y-9), Vector2(size.x-9, size.y-9)]:
		var at: Vector2 = corner+(size*.5-corner).normalized()*14
		var gem := PackedVector2Array([at+Vector2(0, -6), at+Vector2(6, 0), at+Vector2(0, 6), at+Vector2(-6, 0)])
		draw_colored_polygon(gem, MyKinuScreen.GOLD)
		var gem_line := gem.duplicate()
		gem_line.append(gem[0])
		draw_polyline(gem_line, NestTheme.INK, 1.5, true)

## A ribbon banner with a title, made to straddle a FancyCard's top edge.
class Banner extends Control:
	var text := ""
	var color := NestTheme.BERRY
	var font_size := 24
	## Extra room either side of the text and above/below it, and a floor on the width.
	var side_padding := 38.0
	var height_padding := 26.0
	var min_width := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var width := NestTheme.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x+side_padding*2
		custom_minimum_size = Vector2(maxf(width, min_width), font_size+height_padding)

	func _draw() -> void:
		var h := size.y
		var w := size.x
		var tail := 22.0
		# Folded tails behind each end.
		for side in [-1.0, 1.0]:
			var x0: float = 0.0 if side < 0 else w
			var tail_shape := PackedVector2Array([Vector2(x0, h*.28), Vector2(x0-side*tail*1.4, h*.28), Vector2(x0-side*tail*.8, h*.64), Vector2(x0-side*tail*1.4, h), Vector2(x0, h)])
			draw_colored_polygon(tail_shape, color.darkened(.3))
			var tail_line := tail_shape.duplicate()
			tail_line.append(tail_shape[0])
			draw_polyline(tail_line, NestTheme.INK, 3.0, true)
		var band := PackedVector2Array([Vector2(tail*.6, 0), Vector2(w-tail*.6, 0), Vector2(w-tail*.6, h*.8), Vector2(tail*.6, h*.8)])
		var shades := PackedColorArray([color.lightened(.15), color.lightened(.15), color, color])
		draw_polygon(band, shades)
		draw_line(Vector2(tail*.6+4, h*.14), Vector2(w-tail*.6-4, h*.14), Color(1, 1, 1, .45), 2.0, true)
		var band_line := band.duplicate()
		band_line.append(band[0])
		draw_polyline(band_line, NestTheme.INK, 3.5, true)
		var font := NestTheme.font
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at := Vector2((w-tw)*.5, h*.4+font_size*.36)
		draw_string_outline(font, at+Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, NestTheme.INK)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, NestTheme.INK)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, NestTheme.CREAM)

## A chunky gold meter with a gloss and a travelling shimmer. With `show_levels` it wears level
## badges at each end, for My Kinu's experience. It is a ProgressBar so tweens can drive `value`.
class XpMeter extends ProgressBar:
	var show_levels := true
	var level := 1
	var fill_top := Color("fff1a8")
	var fill_bottom := Color("f2a428")
	## The travelling shimmer. A finished bar has nothing left to fill, so it sits still.
	var shimmer := true
	var phase := 0.0

	func _ready() -> void:
		show_percentage = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for part in ["background", "fill"]:
			add_theme_stylebox_override(part, StyleBoxEmpty.new())
		custom_minimum_size.y = maxf(custom_minimum_size.y, 34.0 if show_levels else 20.0)

	func _process(delta: float) -> void:
		if not shimmer:
			return
		phase += delta
		queue_redraw()

	func _draw() -> void:
		var badge := size.y*.5 if show_levels else 0.0
		var track_h := size.y*(.56 if show_levels else 1.0)
		var track := Rect2(Vector2(badge*1.4, (size.y-track_h)*.5), Vector2(size.x-badge*2.8, track_h))
		var r := track_h*.5
		draw_colored_polygon(MyKinuScreen.rounded_points(track.grow(3), r+3), NestTheme.INK)
		draw_colored_polygon(MyKinuScreen.rounded_points(track, r), Color("fff8e8"))
		draw_line(track.position+Vector2(r, track_h*.72), Vector2(track.end.x-r, track.position.y+track_h*.72), Color(0, 0, 0, .06), track_h*.3)
		var amount := clampf(value/maxf(max_value, 1), 0, 1)
		if amount > 0:
			var fill := Rect2(track.position, Vector2(maxf(track_h, track.size.x*amount), track_h))
			var points := MyKinuScreen.rounded_points(fill, r)
			var colors := PackedColorArray()
			for point in points:
				colors.append(fill_top.lerp(fill_bottom, (point.y-fill.position.y)/track_h))
			draw_polygon(points, colors)
			draw_line(fill.position+Vector2(r*.8, track_h*.28), Vector2(fill.end.x-r*.8, fill.position.y+track_h*.28), Color(1, 1, 1, .7), maxf(2, track_h*.16), true)
			# A shimmer sliding along the filled part.
			var sweep := fmod(phase*.6, 1.6)
			if shimmer and sweep < 1.0:
				var x := fill.position.x+fill.size.x*sweep
				var streak := PackedVector2Array([Vector2(x-6, fill.end.y), Vector2(x+4, fill.end.y), Vector2(x+12, fill.position.y), Vector2(x+2, fill.position.y)])
				for piece in Geometry2D.intersect_polygons(streak, points):
					draw_colored_polygon(piece, Color(1, 1, 1, .5))
		if show_levels:
			_level_badge(Vector2(badge, size.y*.5), badge, level, Color("ffb62e"))
			_level_badge(Vector2(size.x-badge, size.y*.5), badge, level+1, Color("c9b7ff"))

	func _level_badge(at: Vector2, r: float, number: int, tone: Color) -> void:
		draw_circle(at, r, NestTheme.INK)
		draw_circle(at, r-3, tone)
		draw_arc(at, r*.55, PI*1.1, PI*1.6, 8, Color(1, 1, 1, .7), 2.0, true)
		var font := NestTheme.font
		var text := str(number)
		var fs := int(r*(.95 if text.length() < 3 else .72))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := at+Vector2(-w*.5, fs*.36)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, NestTheme.INK)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, NestTheme.CREAM)
