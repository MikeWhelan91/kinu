class_name ShopFront
extends Control
## Home screen title: a noren curtain hanging across the top with a wooden shop sign in front.
## Set `parting` to play the exit: the curtain strips swing apart and the sign lifts away.

const STRIPS := 4
const WOOD := Color("c9894c")
const WOOD_LIGHT := Color("dda56a")
const WOOD_GRAIN := Color("a86d3a")

var top_margin: float = 20.0
var parting: bool = false
var progress: float = 0.0
var font: Font = NestTheme.font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if parting:
		progress = minf(1.0, progress+delta*2.2)
		if progress >= 1.0:
			queue_free()
	queue_redraw()

func _draw() -> void:
	var ease := progress*progress*(3.0-2.0*progress)
	var time := Time.get_ticks_msec()*.001
	var rail_y := top_margin+18
	var curtain_bottom := rail_y+size.y*.2
	var strip_width := size.x/STRIPS
	# Curtain strips, gently swaying; when parting they swing out to the sides.
	for i in STRIPS:
		var side := -1.0 if i < STRIPS/2 else 1.0
		var outward := ease*size.x*.55*side*(1.0+absf(i-(STRIPS-1)*.5)*.3)
		var sway := sin(time*1.3+i*1.7)*5.0*(1.0-ease)
		var left := i*strip_width+4+outward
		var right := left+strip_width-8
		var hem := curtain_bottom+sway-ease*80
		var polygon := PackedVector2Array([Vector2(left, -10), Vector2(right, -10), Vector2(right+sway+outward*.15, hem), Vector2(left+sway+outward*.15, hem)])
		draw_colored_polygon(polygon, TofuShop.INDIGO)
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, NestTheme.INK, 4, true)
		var emblem := Vector2((left+right)*.5+sway+outward*.12, hem-30)
		draw_circle(emblem, 18, TofuShop.PAPER)
		draw_arc(emblem, 18, 0, TAU, 32, NestTheme.INK, 3, true)
		draw_rect(Rect2(emblem-Vector2(7, 7), Vector2(14, 14)), TofuShop.INDIGO)
	draw_rect(Rect2(Vector2(-10, rail_y-12-ease*140), Vector2(size.x+20, 22)), TofuShop.POST)
	draw_rect(Rect2(Vector2(-10, rail_y-12-ease*140), Vector2(size.x+20, 22)), NestTheme.INK, false, 4)
	_draw_sign(Vector2(size.x*.5, rail_y+84-ease*size.y*.4), rail_y-ease*140)

func _draw_sign(center: Vector2, rail_y: float) -> void:
	var sign_size := Vector2(minf(size.x-120, 330), 140)
	var rect := Rect2(center-sign_size*.5, sign_size)
	var tilt := sin(Time.get_ticks_msec()*.0011)*1.5*(1.0-progress)
	for side in [-1.0, 1.0]:
		var knot := Vector2(center.x+side*sign_size.x*.32, rect.position.y+10)
		draw_line(Vector2(knot.x-side*20, rail_y), knot+Vector2(tilt*side, 0), NestTheme.INK, 5, true)
	var board := StyleBoxFlat.new()
	board.bg_color = WOOD
	board.border_color = NestTheme.INK
	board.set_border_width_all(5)
	board.border_width_bottom = 12
	board.set_corner_radius_all(22)
	draw_style_box(board, rect)
	# Grain and a lighter inset panel, like a carved kanban.
	for i in 3:
		var y := rect.position.y+26+i*40
		draw_line(Vector2(rect.position.x+24, y), Vector2(rect.end.x-24, y+sin(i*1.9)*6), WOOD_GRAIN, 3, true)
	var inset := StyleBoxFlat.new()
	inset.bg_color = WOOD_LIGHT
	inset.border_color = WOOD_GRAIN
	inset.set_border_width_all(4)
	inset.set_corner_radius_all(14)
	draw_style_box(inset, rect.grow_individual(-12, -10, -12, -38))
	_text("Kinu", Vector2(center.x, rect.position.y+58), 50, NestTheme.CREAM, 12)
	_text("Tumble", Vector2(center.x, rect.position.y+96), 36, NestTheme.BERRY, 10)
	var tag := Rect2(Vector2(center.x-120, rect.end.y-32), Vector2(240, 26))
	var paper := StyleBoxFlat.new()
	paper.bg_color = TofuShop.PAPER
	paper.border_color = NestTheme.INK
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(10)
	draw_style_box(paper, tag)
	_text("Stack the tofu. Don't let it tumble!", tag.get_center()+Vector2(0, 5), 13, NestTheme.INK, 0)

func _text(text: String, baseline_center: Vector2, font_size: int, color: Color, outline: int) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := baseline_center-Vector2(width*.5, 0)
	if outline > 0:
		draw_string_outline(font, at+Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, NestTheme.INK)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, NestTheme.INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
