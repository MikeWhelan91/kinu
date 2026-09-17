class_name TumbleMeter
extends Control
## Little tofu blocks for the tumbles a run can survive; one is crossed out per Kinu lost.

var total: int = 3
var used: int = 0:
	set(value):
		used = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(total*30, 26)

func _draw() -> void:
	var start := (size.x-total*30+6)*.5
	for i in total:
		var rect := Rect2(start+i*30, 3, 24, 20)
		var lost := i >= total-used
		var style := NestTheme.box(Color(NestTheme.MUTED, .25) if lost else NestTheme.CREAM, 6, Color(NestTheme.INK, .45 if lost else 1.0), 3)
		draw_style_box(style, rect)
		if lost:
			var c := rect.get_center()
			draw_line(c+Vector2(-7, -7), c+Vector2(7, 7), NestTheme.BERRY, 4, true)
			draw_line(c+Vector2(7, -7), c+Vector2(-7, 7), NestTheme.BERRY, 4, true)
		else:
			draw_circle(rect.get_center()+Vector2(-4, 0), 1.6, NestTheme.INK)
			draw_circle(rect.get_center()+Vector2(4, 0), 1.6, NestTheme.INK)
