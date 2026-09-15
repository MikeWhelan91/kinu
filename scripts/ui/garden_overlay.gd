class_name GardenOverlay
extends Control
## Full-screen backdrop for menu pages that hide the 3D scene: warm paper with confetti dots.
var paper: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if not paper:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("ffe9a8"))
	var colors := [Color("ffd35c"), Color("ffc4d8"), Color("b7e6ff"), Color("c9f0a4")]
	var spacing := 64.0
	for row in int(size.y/spacing)+2:
		for column in int(size.x/spacing)+2:
			var offset := spacing*.5 if row % 2 else 0.0
			draw_circle(Vector2(column*spacing+offset, row*spacing), 9, colors[(row+column) % 4])
