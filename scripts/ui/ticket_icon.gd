class_name TicketIcon
extends Control
## A tiny Kinu Claw play ticket: clean gold stock with the machine's claw stamped on it.

func _init(height: float = 24.0) -> void:
	custom_minimum_size = Vector2(height*1.48, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var rect := Rect2(Vector2(1, size.y*.10), Vector2(size.x-2, size.y*.80))
	var ticket := StyleBoxFlat.new()
	ticket.bg_color = Color("ffbd35")
	ticket.border_color = NestTheme.INK
	ticket.set_border_width_all(2)
	ticket.set_corner_radius_all(maxi(3, int(size.y*.12)))
	draw_style_box(ticket, rect)
	# A simple claw stamp stays clear in the small balance pill as well as prize reveals.
	var c := rect.get_center()+Vector2(0, size.y*.05)
	var ink_width := maxf(1.5, size.y*.075)
	draw_line(c+Vector2(0, -size.y*.24), c+Vector2(0, -size.y*.04), NestTheme.INK, ink_width, true)
	draw_arc(c+Vector2(0, -size.y*.02), size.y*.15, PI+.1, TAU-.1, 12, NestTheme.INK, ink_width, true)
	draw_line(c+Vector2(-size.y*.14, 0), c+Vector2(-size.y*.20, size.y*.17), NestTheme.INK, ink_width, true)
	draw_line(c+Vector2(size.y*.14, 0), c+Vector2(size.y*.20, size.y*.17), NestTheme.INK, ink_width, true)
	draw_line(c+Vector2(-size.y*.20, size.y*.17), c+Vector2(-size.y*.10, size.y*.23), NestTheme.INK, ink_width, true)
	draw_line(c+Vector2(size.y*.20, size.y*.17), c+Vector2(size.y*.10, size.y*.23), NestTheme.INK, ink_width, true)
