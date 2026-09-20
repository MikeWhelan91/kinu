class_name BentoChargeMeter
extends Control
## A live force meter for Bento Flip. It redraws itself instead of rebuilding the whole HUD while
## the player holds, so the next-Kinu card and other UI stay stable during a charge.

var run: NestRun

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(186, 28)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	var shell := NestTheme.box(Color("fff8e8"), 14, NestTheme.INK, 4)
	draw_style_box(shell, outer)
	var amount := clampf(run.bento_charge if run else 0.0, 0.0, 1.0)
	var inset := Rect2(Vector2(5, 5), Vector2(maxf(0, (size.x-10)*amount), size.y-10))
	if inset.size.x > 0:
		var fill := NestTheme.SUN.lerp(Color("f28b32"), amount)
		draw_style_box(NestTheme.box(fill, 9, Color.TRANSPARENT, 0), inset)
	var label := "HOLD TO FLIP"
	var font_size := 13
	var text_size := NestTheme.font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := Vector2((size.x-text_size.x)*.5, (size.y+text_size.y)*.5-2)
	draw_string_outline(NestTheme.font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, NestTheme.INK)
	draw_string(NestTheme.font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, NestTheme.CREAM)
