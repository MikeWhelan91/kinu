class_name MenuIcon
extends Control
## Small inked icons for the home screen's round buttons.

var kind: String = "shop"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var ink := NestTheme.INK
	var s := minf(size.x, size.y)
	var o := (size-Vector2(s, s))*.5
	# Centre each drawing by its visible bounds, including the hanger hook.
	var centre_y: float = {"shop": .54, "wardrobe": .49, "book": .54}.get(kind, .5)
	o.y += (.5-float(centre_y))*s
	var stroke := s*.055
	var at := func(x: float, y: float) -> Vector2:
		return o+Vector2(x, y)*s
	match kind:
		"shop":
			# A shopping bag: the one shape everyone reads as "shop".
			draw_arc(at.call(.5, .34), s*.14, PI, TAU, 20, ink, stroke*1.4, true)
			_shape(PackedVector2Array([at.call(.2, .34), at.call(.8, .34), at.call(.84, .88), at.call(.16, .88)]), NestTheme.SUN)
			_kinu(Rect2(at.call(.35, .5), Vector2(.3, .26)*s))
		"wardrobe":
			# A T-shirt on a hanger hook.
			draw_arc(at.call(.5, .17), s*.065, PI*.95, TAU*1.12, 14, ink, stroke, true)
			_shape(PackedVector2Array([at.call(.36, .27), at.call(.44, .27), at.call(.5, .35), at.call(.56, .27),
				at.call(.64, .27), at.call(.92, .43), at.call(.82, .6), at.call(.72, .54), at.call(.72, .87),
				at.call(.28, .87), at.call(.28, .54), at.call(.18, .6), at.call(.08, .43)]), NestTheme.BERRY)
		"book":
			# A closed book with its page block showing, a ribbon and a Kinu on the cover.
			_box(Rect2(at.call(.27, .17), Vector2(.56, .66)*s), NestTheme.CREAM, 3)
			_shape(PackedVector2Array([at.call(.6, .78), at.call(.7, .78), at.call(.7, .95), at.call(.65, .89), at.call(.6, .95)]), NestTheme.BERRY)
			_box(Rect2(at.call(.17, .13), Vector2(.58, .68)*s), NestTheme.SKY, 4)
			_box(Rect2(at.call(.17, .13), Vector2(.12, .68)*s), NestTheme.SKY.darkened(.3), 3)
			_kinu(Rect2(at.call(.36, .33), Vector2(.3, .26)*s))
		"daily":
			_box(Rect2(at.call(.16, .24), Vector2(.68, .6)*s), NestTheme.CREAM, 7)
			_box(Rect2(at.call(.16, .24), Vector2(.68, .18)*s), NestTheme.BERRY, 7)
			for x in [.32, .68]:
				draw_line(at.call(x, .16), at.call(x, .3), ink, stroke, true)
			draw_polyline(PackedVector2Array([at.call(.34, .6), at.call(.46, .72), at.call(.68, .5)]), NestTheme.WOOD.darkened(.3), 6, true)
		"settings":
			var centre: Vector2 = at.call(.5, .5)
			var teeth := PackedVector2Array()
			for i in 16:
				var a := TAU*i/16.0
				teeth.append(centre+Vector2(cos(a), sin(a))*s*(.4 if i % 2 == 0 else .3))
			draw_colored_polygon(teeth, NestTheme.CREAM)
			teeth.append(teeth[0])
			draw_polyline(teeth, ink, stroke, true)
			draw_circle(centre, s*.12, NestTheme.WOOD)
			draw_arc(centre, s*.12, 0, TAU, 20, ink, stroke, true)

func _box(rect: Rect2, fill: Color, radius: int = 4) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = NestTheme.INK
	style.set_border_width_all(maxi(1,roundi(minf(size.x,size.y)*.055)))
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

## A filled polygon with the ink outline.
func _shape(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, NestTheme.INK, maxf(1.0, minf(size.x, size.y)*.055), true)

## A tiny cream Kinu with two dot eyes.
func _kinu(rect: Rect2) -> void:
	_box(rect, NestTheme.CREAM, 3)
	for side in [-1.0, 1.0]:
		draw_circle(rect.get_center()+Vector2(side*rect.size.x*.2, -rect.size.y*.02), maxf(1.0, rect.size.x*.08), NestTheme.INK)
