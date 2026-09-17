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
		if decor.layout != "":
			_draw_outdoor(area)
		else:
			_draw_shop(area, floor_top)
		if TofuShop.PARTICLE_COUNTS.has(decor.effect):
			var colors: Array = decor.palette.get("particles", TofuShop.PARTICLE_COLORS[decor.effect])
			for i in 14:
				var at := area.position+Vector2(fmod(i*37.0, area.size.x), fmod(i*23.0+9, area.size.y*.7))
				var tone: Color = colors[i % colors.size()]
				tone.a = maxf(tone.a, .8)
				if decor.effect == "rain":
					draw_line(at, at+Vector2(0, 9), tone, 2)
				elif decor.effect == "mist":
					draw_circle(Vector2(at.x, floor_top-4), 10, Color(1, 1, 1, .45))
				else:
					draw_circle(at, 3, tone)
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = NestTheme.INK
		outline.set_border_width_all(3)
		outline.set_corner_radius_all(14)
		draw_style_box(outline, area)

	## Sky, hills and ground, then a few shapes that say which outdoor setting this is.
	func _draw_outdoor(area: Rect2) -> void:
		var sky := StyleBoxFlat.new()
		sky.bg_color = _c("background", Color("cfe7f2"))
		sky.set_corner_radius_all(14)
		draw_style_box(sky, area)
		var horizon := area.position.y+area.size.y*.62
		var hills := PackedVector2Array([Vector2(area.position.x, horizon+2)])
		for i in 13:
			var t := i/12.0
			hills.append(Vector2(area.position.x+area.size.x*t, horizon-8-absf(sin(t*7.0))*14))
		hills.append(Vector2(area.end.x, horizon+2))
		draw_colored_polygon(hills, _c("hills", Color("7a9f63")))
		var ground := StyleBoxFlat.new()
		ground.bg_color = _c("floor", Color("8fb86a"))
		ground.corner_radius_bottom_left = 14
		ground.corner_radius_bottom_right = 14
		draw_style_box(ground, Rect2(Vector2(area.position.x, horizon), Vector2(area.size.x, area.end.y-horizon)))
		var at := func(fx: float, fy: float) -> Vector2:
			return area.position+Vector2(area.size.x*fx, area.size.y*fy)
		match decor.layout:
			"grove":
				var canopy: Array = decor.palette.get("canopy", [Color("e8552f")])
				for i in 5:
					var base: Vector2 = at.call(.1+i*.2, .66+(i % 2)*.04)
					match str(decor.palette.get("tree", "")):
						"bamboo":
							draw_line(base, base-Vector2(0, area.size.y*.6), _c("post", Color("8fbf5a")), 5)
							for n in 3:
								draw_line(base-Vector2(4, 16+n*16), base-Vector2(-4, 16+n*16), _c("post", Color("8fbf5a")).darkened(.3), 2)
						"pine":
							draw_colored_polygon(PackedVector2Array([base-Vector2(14, 0), base+Vector2(14, 0), base-Vector2(0, 46)]), _c("pine", Color("3f6b4f")))
							draw_colored_polygon(PackedVector2Array([base-Vector2(5, 30), base+Vector2(5, -30), base-Vector2(0, 46)]), Color("f7fbff"))
						_:
							draw_line(base, base-Vector2(0, 22), _c("post", Color("6b4a33")), 4)
							draw_circle(base-Vector2(0, 32), 16, canopy[i % canopy.size()])
				if decor.palette.get("torii", false):
					var gate: Vector2 = at.call(.5, .66)
					for side in [-1.0, 1.0]:
						draw_line(gate+Vector2(side*14, 0), gate+Vector2(side*14, -36), Color("d8432f"), 4)
					draw_line(gate+Vector2(-22, -36), gate+Vector2(22, -36), Color("2b1a17"), 5)
			"onsen":
				draw_rect(Rect2(at.call(.02, .66), Vector2(area.size.x*.96, area.size.y*.08)), _c("water", Color("7fcbd6")))
				for i in 9:
					draw_circle(at.call(.06+i*.11, .76), 7, TofuShop.PAPER.darkened(.35))
				for i in 22:
					var x: Vector2 = at.call(.03+i*.045, .62)
					draw_line(x, x-Vector2(0, area.size.y*.28), _c("post", Color("c4a864")), 4)
			"festival":
				var awning: Array = decor.palette.get("awning", [Color("e24a4a")])
				for i in 3:
					var left: Vector2 = at.call(.06+i*.32, .66)
					draw_rect(Rect2(left-Vector2(0, 26), Vector2(area.size.x*.26, 26)), _c("wood", Color("a9744a")))
					for s in 4:
						var x := left.x+s*area.size.x*.065
						draw_rect(Rect2(Vector2(x, left.y-40), Vector2(area.size.x*.065, 12)), awning[i % awning.size()] if s % 2 == 0 else Color("fff7ea"))
				for i in 9:
					draw_circle(at.call(.05+i*.11, .2+sin(i*1.1)*.04), 4, _c("lantern", Color("ff8a3d")))
			"rooftop":
				var windows: Array = decor.palette.get("windows", [Color("ffd46b")])
				for i in 6:
					var height := area.size.y*(.3+fmod(i*.37, .3))
					var rect := Rect2(Vector2(area.position.x+i*area.size.x/6.0+3, area.position.y+area.size.y*.62-height), Vector2(area.size.x/6.0-6, height))
					draw_rect(rect, _c("plaster", Color("2a2442")).lightened(.1))
					for w in 5:
						draw_rect(Rect2(rect.position+Vector2(5+fmod(w*7.0, rect.size.x-12), 6+w*9), Vector2(5, 5)), windows[(i+w) % windows.size()])
			"veranda":
				draw_circle(at.call(.78, .22), 16, _c("moon", Color("fff4c4")))
				draw_rect(Rect2(at.call(.04, .36), Vector2(area.size.x*.45, area.size.y*.28)), _c("paper", Color("ffe7a8")))
				for i in 3:
					var x: Vector2 = at.call(.04+i*.15, .36)
					draw_line(x, x+Vector2(0, area.size.y*.28), _c("post", Color("2a2230")), 2)
				for i in 6:
					var base: Vector2 = at.call(.55+i*.08, .9)
					draw_line(base, base+Vector2(sin(i)*6, -34), Color("8a9a5a"), 2)
					draw_circle(base+Vector2(sin(i)*6, -38), 5, Color("f1e3bf"))

	func _draw_shop(area: Rect2, floor_top: float) -> void:
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
