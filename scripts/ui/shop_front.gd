class_name ShopFront
extends Control
## Home screen title: a noren curtain hanging across the top with a wooden shop sign in front.
## Set `parting` to play the exit: the curtain strips swing apart and the sign lifts away.

const STRIPS := 4
## The wooden sign's height. Its light inset holds "Kinu" and "Tumble"; the tagline sits on the dark
## band along the bottom.
const SIGN_HEIGHT := 164.0
## Shortest the strips may hang below the rail, so labels clear the sign's bottom edge.
const MIN_DROP := 256.0
const EMBLEM_RADIUS := 32.0
const WOOD := Color("c9894c")
const WOOD_LIGHT := Color("dda56a")
const WOOD_GRAIN := Color("a86d3a")

var top_margin: float = 20.0
## The equipped room, so the curtain matches the scene behind it.
var decor: KinuDecor
var parting: bool = false
var progress: float = 0.0
var font: Font = NestTheme.font
var _frame_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	# Sample once so painted emblems and interactive icons share exactly the same pose.
	_frame_time = Time.get_ticks_usec()*.000001
	if parting:
		progress = minf(1.0, progress+delta*2.2)
		if progress >= 1.0:
			queue_free()
	_layout_navigation()
	queue_redraw()

## Keeps interactive curtain emblems attached to the same swaying/parting panel geometry.
func _layout_navigation() -> void:
	for child in get_children():
		if not child.has_meta("curtain_panel"):
			continue
		var index := int(child.get_meta("curtain_panel"))
		var pose := _panel_pose(index,_frame_time)
		child.position = pose.emblem
		var polygon := _panel_hit_polygon(pose,index)
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		for item in child.get_children():
			if not item.has_meta("curtain_target"):
				continue
			item.position = bounds.position-pose.emblem
			item.size = bounds.size
			var local_polygon := PackedVector2Array()
			for point in polygon:
				local_polygon.append(point-bounds.position)
			item.hit_polygon = local_polygon

func _panel_pose(index: int, time: float) -> Dictionary:
	var ease := progress*progress*(3.0-2.0*progress)
	var rail_y := top_margin+18
	# The strips hang a fifth of the screen, but never so short that a strip's label (about 80px up
	# from the hem) rides up behind the sign. On 16:9 screens like the iPhone SE a fifth is too short.
	var curtain_bottom := rail_y+maxf(size.y*.2, MIN_DROP)+18
	var strip_width := size.x/STRIPS
	var side := -1.0 if index < STRIPS/2 else 1.0
	var outward := ease*size.x*.55*side*(1.0+absf(index-(STRIPS-1)*.5)*.3)
	var sway := sin(time*1.3+index*1.7)*5.0*(1.0-ease)
	var left := index*strip_width+4+outward
	var right := left+strip_width-8
	var hem := curtain_bottom+sway-ease*80
	return {"left": left, "right": right, "rail_y": rail_y, "hem": hem, "sway": sway, "outward": outward,
		"emblem": Vector2((left+right)*.5+sway+outward*.12,hem-39)}

## Shared geometry keeps drawing and touch targets aligned throughout the animation.
func _panel_polygon(pose: Dictionary) -> PackedVector2Array:
	var shift: float = pose.sway+pose.outward*.15
	return PackedVector2Array([Vector2(pose.left,-10),Vector2(pose.right,-10),
		Vector2(pose.right+shift,pose.hem),Vector2(pose.left+shift,pose.hem)])

## The cloth remains full-height, but the top of the outer strips is not part of
## their button. This leaves Daily Missions and the bean wallet unambiguously
## tappable without changing the noren artwork.
func _panel_hit_polygon(pose: Dictionary, index: int) -> PackedVector2Array:
	var polygon := _panel_polygon(pose)
	if index == 0 or index == STRIPS-1:
		var hit_top: float = pose.rail_y+14+SIGN_HEIGHT*.5
		polygon[0].y = hit_top
		polygon[1].y = hit_top
	return polygon

func _c(key: String, fallback: Color) -> Color:
	return decor.palette.get(key, fallback) if decor else fallback

func _draw() -> void:
	var noren := _c("noren", TofuShop.INDIGO)
	var paper := _c("paper", TofuShop.PAPER)
	var ease := progress*progress*(3.0-2.0*progress)
	var rail_y := top_margin+18
	# Curtain strips, gently swaying; when parting they swing out to the sides.
	for i in STRIPS:
		var pose := _panel_pose(i,_frame_time)
		var polygon := _panel_polygon(pose)
		draw_colored_polygon(polygon, noren)
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, NestTheme.INK, 4, true)
		var emblem: Vector2 = pose.emblem
		draw_circle(emblem, EMBLEM_RADIUS, paper)
		draw_arc(emblem, EMBLEM_RADIUS, 0, TAU, 40, NestTheme.INK, 4, true)
	draw_rect(Rect2(Vector2(-10, rail_y-12-ease*140), Vector2(size.x+20, 22)), _c("post", TofuShop.POST))
	draw_rect(Rect2(Vector2(-10, rail_y-12-ease*140), Vector2(size.x+20, 22)), NestTheme.INK, false, 4)
	_draw_sign(Vector2(size.x*.5, rail_y+14+SIGN_HEIGHT*.5-ease*size.y*.4), rail_y-ease*140)

func _draw_sign(center: Vector2, rail_y: float) -> void:
	var sign_size := Vector2(minf(size.x-120, 330), SIGN_HEIGHT)
	var rect := Rect2(center-sign_size*.5, sign_size)
	var tilt := sin(_frame_time*1.1)*1.5*(1.0-progress)
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
	_text("Kinu", Vector2(center.x, rect.position.y+62), 50, NestTheme.CREAM, 12)
	_text("Tumble", Vector2(center.x, rect.position.y+104), 36, NestTheme.BERRY, 10)
	var tag := Rect2(Vector2(center.x-120, rect.end.y-32), Vector2(240, 26))
	var paper := StyleBoxFlat.new()
	paper.bg_color = TofuShop.PAPER
	paper.border_color = NestTheme.INK
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(10)
	draw_style_box(paper, tag)
	_text("Pile in as many Kinu as you can!", tag.get_center()+Vector2(0, 5), 13, NestTheme.INK, 0)

func _text(text: String, baseline_center: Vector2, font_size: int, color: Color, outline: int) -> void:
	text = tr(text)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := baseline_center-Vector2(width*.5, 0)
	if outline > 0:
		draw_string_outline(font, at+Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, NestTheme.INK)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, NestTheme.INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
