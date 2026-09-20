class_name TumbleMeter
extends Control
## Two compact rows of tofu blocks for the tumbles a run can survive; one is crossed out per loss.

var total: int = NestRun.MAX_TUMBLES
var used: int = 0:
	set(value):
		used = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _get_minimum_size() -> Vector2:
	# Report this before the VBox lays out the score card, so the second row cannot be clipped.
	return Vector2(96, 50)

func _draw() -> void:
	# This is intentionally an explicit 3 × 2 grid. Do not collapse it into a single row.
	var start := Vector2((size.x-84.0)*.5, (size.y-44.0)*.5)
	for i in total:
		var column := i % 3
		var y := 1.0 if i < 3 else 24.0
		var rect := Rect2(start+Vector2(column*28+2, y), Vector2(24, 19))
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
