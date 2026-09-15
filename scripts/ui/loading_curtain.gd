class_name LoadingCurtain
extends Control
## A brief indigo curtain shown while the shop box or room is rebuilt, so the pause reads as a
## scene change instead of a freeze. Call finish() to fade it out.

var font: Font = NestTheme.font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), TofuShop.INDIGO)
	var strip := size.x/4.0
	for i in 4:
		draw_line(Vector2(strip*i, 0), Vector2(strip*i, size.y), NestTheme.INK, 4)
	var center := size*.5
	var hop := absf(sin(Time.get_ticks_msec()*.006))*18.0
	var tofu := Rect2(center+Vector2(-34, -70-hop), Vector2(68, 60))
	var body := StyleBoxFlat.new()
	body.bg_color = Color("fbf0da")
	body.border_color = NestTheme.INK
	body.set_border_width_all(4)
	body.set_corner_radius_all(14)
	draw_style_box(body, tofu)
	for side in [-1.0, 1.0]:
		draw_circle(tofu.get_center()+Vector2(side*13, 2), 4.5, NestTheme.INK)
		draw_circle(tofu.get_center()+Vector2(side*22, 12), 6, Color("ff9fb0"))
	var text := "Tidying the shop..."
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var at := center+Vector2(-width*.5, 30)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, NestTheme.INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, NestTheme.CREAM)

func finish() -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, .25)
	fade.tween_callback(queue_free)
