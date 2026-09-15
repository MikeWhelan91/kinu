class_name DecorPreview
extends SubViewportContainer
## Shop thumbnail for a box skin (a small 3D render) or a room theme (an illustrated swatch).

func setup_box(decor: KinuDecor, pixels: Vector2i) -> void:
	custom_minimum_size = Vector2(pixels)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	var viewport := SubViewport.new()
	viewport.size = pixels
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var environment := WorldEnvironment.new()
	var env := TofuShop.make_environment()
	env.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment = env
	viewport.add_child(environment)
	var sun := TofuShop.make_sun()
	sun.shadow_enabled = false
	viewport.add_child(sun)
	var box := TofuBox.new()
	box.decor = decor
	box.with_collision = false
	box.rotation.y = .5
	viewport.add_child(box)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 5.6
	camera.position = Vector3(0, 4.2, 5.2)
	camera.rotation.x = -atan2(3.7, 5.2)
	viewport.add_child(camera)

func setup_room(decor: KinuDecor, pixels: Vector2i) -> void:
	custom_minimum_size = Vector2(pixels)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := RoomSwatch.new()
	swatch.decor = decor
	swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(swatch)

class RoomSwatch extends Control:
	var decor: KinuDecor

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _c(key: String, fallback: Color) -> Color:
		return decor.palette.get(key, fallback)

	func _draw() -> void:
		var area := Rect2(Vector2(8, 4), size-Vector2(16, 8))
		var frame := StyleBoxFlat.new()
		frame.bg_color = _c("plaster", TofuShop.PLASTER)
		frame.set_corner_radius_all(14)
		draw_style_box(frame, area)
		var floor_top := area.position.y+area.size.y*.72
		draw_rect(Rect2(Vector2(area.position.x, floor_top), Vector2(area.size.x, area.end.y-floor_top-6)), _c("floor", Color("9c6a42")))
		var post := _c("post", TofuShop.POST)
		for i in 3:
			var x := area.position.x+area.size.x*(.18+i*.32)
			draw_rect(Rect2(Vector2(x-4, area.position.y+4), Vector2(8, floor_top-area.position.y-4)), post)
		var shoji := Rect2(Vector2(area.position.x+area.size.x*.05, area.position.y+area.size.y*.18), Vector2(area.size.x*.26, area.size.y*.44))
		draw_rect(shoji, _c("paper", TofuShop.PAPER))
		for i in 3:
			draw_line(Vector2(shoji.position.x+shoji.size.x*(i+1)/4.0, shoji.position.y), Vector2(shoji.position.x+shoji.size.x*(i+1)/4.0, shoji.end.y), post, 2)
			draw_line(Vector2(shoji.position.x, shoji.position.y+shoji.size.y*(i+1)/4.0), Vector2(shoji.end.x, shoji.position.y+shoji.size.y*(i+1)/4.0), post, 2)
		for i in 3:
			var strip := Rect2(Vector2(area.position.x+area.size.x*(.52+i*.13), area.position.y+area.size.y*.1), Vector2(area.size.x*.11, area.size.y*.34))
			draw_rect(strip, _c("noren", TofuShop.INDIGO))
			draw_circle(strip.get_center()+Vector2(0, strip.size.y*.2), 6, _c("paper", TofuShop.PAPER))
		var lantern := Vector2(area.position.x+area.size.x*.4, area.position.y+area.size.y*.3)
		draw_line(Vector2(lantern.x, area.position.y+2), lantern, NestTheme.INK, 2)
		draw_circle(lantern, 13, _c("lantern", TofuShop.LANTERN))
		var dots := {"snow": Color.WHITE, "petals": Color("ffb3c8"), "fireflies": Color("ffe27a")}
		if dots.has(decor.effect):
			for i in 14:
				draw_circle(area.position+Vector2(fmod(i*37.0, area.size.x), fmod(i*23.0+9, area.size.y*.7)), 3, dots[decor.effect])
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = NestTheme.INK
		outline.set_border_width_all(3)
		outline.set_corner_radius_all(14)
		draw_style_box(outline, area)
