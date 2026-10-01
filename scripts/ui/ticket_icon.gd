class_name TicketIcon
extends Control
## A golden Kinu Claw ticket: a gilded stub with notched sides, a perforated tear line, a stamped
## star, a gloss and a twinkle. Used everywhere tickets are counted or won.

const GOLD_TOP := Color("ffe57f")
const GOLD_BOTTOM := Color("f0a01c")
const GOLD_EDGE := Color("b8690a")
const CREAM := Color("fff6cc")

func _init(height: float = 24.0) -> void:
	custom_minimum_size = Vector2(height*1.6, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var h := size.y
	var line := maxf(1.5, h*.075)
	var body := Rect2(Vector2(line*.5, h*.06), Vector2(size.x-line, h*.84))
	var shape := _ticket(body, h)
	# Soft drop shadow, then the gilded stock with a top-to-bottom sheen.
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point+Vector2(0, h*.07))
	draw_colored_polygon(shadow, Color(0, 0, 0, .22))
	var colors := PackedColorArray()
	for point in shape:
		colors.append(GOLD_TOP.lerp(GOLD_BOTTOM, clampf((point.y-body.position.y)/body.size.y, 0, 1)))
	draw_polygon(shape, colors)
	# A diagonal gloss across the upper left.
	var gloss := PackedVector2Array([body.position, body.position+Vector2(body.size.x*.55, 0), body.position+Vector2(body.size.x*.3, body.size.y*.55), body.position+Vector2(0, body.size.y*.55)])
	for piece in Geometry2D.intersect_polygons(gloss, shape):
		draw_colored_polygon(piece, Color(1, 1, 1, .28))
	# Inner gilt rule.
	var inner := _ticket(body.grow(-h*.11), h*.78)
	inner.append(inner[0])
	draw_polyline(inner, Color(CREAM, .85), maxf(1.0, h*.035), true)
	# Perforated tear line between the stub and the ticket.
	var tear_x := body.position.x+body.size.x*.3
	var dots := 5
	for i in dots:
		var y := lerpf(body.position.y+h*.16, body.end.y-h*.16, float(i)/(dots-1))
		draw_circle(Vector2(tear_x, y), maxf(.8, h*.035), Color(GOLD_EDGE, .8))
	# Stamped stars: a big one on the ticket, a small one on the stub.
	_star(Vector2(body.position.x+body.size.x*.65, body.get_center().y), h*.25, CREAM)
	_star(Vector2(body.position.x+body.size.x*.15, body.get_center().y), h*.12, CREAM)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, NestTheme.INK, line, true)
	# A twinkle on the top-right corner.
	var glint := Vector2(body.end.x-h*.16, body.position.y+h*.14)
	var arm := h*.13
	draw_line(glint-Vector2(arm, 0), glint+Vector2(arm, 0), Color(1, 1, 1, .95), maxf(1.0, h*.045), true)
	draw_line(glint-Vector2(0, arm), glint+Vector2(0, arm), Color(1, 1, 1, .95), maxf(1.0, h*.045), true)

## A rounded ticket with a half-circle notch bitten from the middle of each short side.
func _ticket(rect: Rect2, h: float) -> PackedVector2Array:
	var corner := minf(h*.14, rect.size.y*.3)
	var points := MyKinuScreen.rounded_points(rect, corner, 4)
	var notch := minf(h*.16, rect.size.y*.25)
	for x in [rect.position.x, rect.end.x]:
		var bite := MyKinuScreen.ellipse_points(Vector2(x, rect.get_center().y), Vector2(notch, notch), 16)
		var clipped := Geometry2D.clip_polygons(points, bite)
		if not clipped.is_empty():
			points = clipped[0]
	return points

func _star(at: Vector2, radius: float, fill: Color) -> void:
	var star := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius*.45
		star.append(at+Vector2.UP.rotated(TAU*i/10.0)*r)
	draw_colored_polygon(star, fill)
	star.append(star[0])
	draw_polyline(star, GOLD_EDGE, maxf(1.0, radius*.14), true)
