class_name BeanIcon
extends Control
## A little soybean, the game's currency.

func _init(diameter: float = 24.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size*.5
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU*i/24.0
		points.append(center+Vector2(cos(a)*size.x*.46, sin(a)*size.y*.38).rotated(-.5))
	draw_colored_polygon(points, Color("f2cf7c"))
	points.append(points[0])
	draw_polyline(points, NestTheme.INK, 2.5, true)
	draw_arc(center+Vector2(size.x*.08, -size.y*.02), size.x*.14, .4, 2.4, 8, Color("a8743a"), 2.0, true)
	draw_circle(center+Vector2(-size.x*.16, -size.y*.12), size.x*.07, Color(1, 1, 1, .8))
