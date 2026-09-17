class_name SignBoard
extends PanelContainer
## A wooden shop sign hanging on ropes, matching the home screen's shop front.

const WOOD := Color("c9894c")
const GRAIN := Color("a86d3a")
var rope_length: float = 400.0
var mounted: bool = false
## Menu boards sit on the page instead of hanging from ropes.
var ropes: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board := StyleBoxFlat.new()
	board.bg_color = WOOD
	board.border_color = NestTheme.INK
	board.set_border_width_all(5)
	board.border_width_bottom = 12
	board.set_corner_radius_all(24)
	board.content_margin_left = 22
	board.content_margin_right = 22
	board.content_margin_top = 12
	board.content_margin_bottom = 22
	add_theme_stylebox_override("panel", board)
	resized.connect(queue_redraw)

func _draw() -> void:
	for i in 4:
		var y := 24.0+i*(size.y-40)/3.0
		draw_line(Vector2(26, y), Vector2(size.x-26, y+sin(i*1.9)*6), GRAIN, 3, true)
	if mounted:
		var rail := NestTheme.box(WOOD.darkened(.12),8,NestTheme.INK,5)
		draw_style_box(rail,Rect2(34,-44,size.x-68,18))
		for x in [46.0,size.x-46]:
			var screw := Vector2(x,-35)
			draw_circle(screw,4,NestTheme.INK)
			draw_line(screw-Vector2(2,0),screw+Vector2(2,0),NestTheme.CREAM,1,true)
	if not ropes:
		return
	for side in [-1.0, 1.0]:
		var knot := Vector2(size.x*.5+side*size.x*.32, 8)
		var anchor := knot+Vector2(-side*24, -rope_length)
		if mounted:
			anchor = Vector2(knot.x-side*12,-33)
			draw_circle(anchor,6,NestTheme.INK)
		draw_line(anchor, knot, NestTheme.INK, 5, true)
		if mounted:
			draw_line(anchor, knot, Color("e8bc7c"), 2, true)
		draw_circle(knot, 7, NestTheme.INK)

## Cream paper panel for text sitting on the wood.
static func paper(radius: int = 16) -> StyleBoxFlat:
	var style := NestTheme.box(TofuShop.PAPER, radius, NestTheme.INK, 6)
	style.content_margin_top = 6
	style.content_margin_bottom = 10
	return style
