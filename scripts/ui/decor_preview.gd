class_name DecorPreview
extends SubViewportContainer
## Shop thumbnail for a box skin (a small 3D render) or a room theme (an illustrated swatch).

var box_model: Node3D
var spin_enabled := false
var _pointer := -99
var _spin_velocity := 0.0

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
	box_model = TofuBox.new()
	box_model.decor = decor
	box_model.with_collision = false
	box_model.rotation.y = .5
	viewport.add_child(box_model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	# A box is roughly 4.5 units across once its rim and special trims are included. Leave a
	# generous frame around it in the feature view so no corner or ribbon disappears at the edge.
	camera.size = 7.0
	camera.position = Vector3(0, 4.2, 5.2)
	camera.rotation.x = -atan2(3.7, 5.2)
	viewport.add_child(camera)

## Boxes get the same inspection gesture as Kinu. Room swatches are illustrated rather than 3D,
## so they intentionally stay still.
func enable_spin() -> void:
	if box_model == null:
		return
	spin_enabled = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Drag to spin"
	var viewport: SubViewport = get_child(0)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _gui_input(event: InputEvent) -> void:
	if not spin_enabled:
		return
	var motion := Vector2.ZERO
	if event is InputEventScreenTouch:
		_pointer = event.index if event.pressed else -99
	elif event is InputEventScreenDrag and event.index == _pointer:
		motion = event.relative
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = -2 if event.pressed else -99
	elif event is InputEventMouseMotion and _pointer == -2 and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		motion = event.relative
	if motion == Vector2.ZERO:
		return
	_spin_velocity = -motion.x*.018
	box_model.rotate_y(_spin_velocity)
	accept_event()

func _process(delta: float) -> void:
	if not spin_enabled or absf(_spin_velocity) < .001:
		return
	box_model.rotate_y(_spin_velocity*delta*36.0)
	_spin_velocity = move_toward(_spin_velocity, 0.0, delta*.65)

func setup_room(decor: KinuDecor, pixels: Vector2i) -> void:
	custom_minimum_size = Vector2(pixels)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := room_swatch(decor, pixels)
	swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(swatch)

## A room is flat UI artwork, not a SubViewport. Returning the drawing control directly avoids
## SubViewportContainer's child sizing rules, which were narrowing room previews in wide stages.
static func room_swatch(decor: KinuDecor, pixels: Vector2i) -> RoomSwatch:
	var swatch := RoomSwatch.new()
	swatch.decor = decor
	swatch.custom_minimum_size = Vector2(pixels)
	return swatch

class RoomSwatch extends Control:
	const STONE_SWATCH := Color("b3ada2")
	var decor: KinuDecor

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Scenery is drawn to fill the swatch, and some of it reaches past — Sky Shrine's rainbow
		# arcs well above the horizon — so the swatch is clipped to its own frame.
		clip_contents = true

	func _c(key: String, fallback: Color) -> Color:
		return decor.palette.get(key, fallback)

	func _draw() -> void:
		# The complete artwork for a room, drawn to fill whatever size the swatch is given.
		var area := Rect2(Vector2.ZERO, size)
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
			"arcade":
				for i in 4:
					var left: Vector2 = at.call(.06+i*.235, .3)
					draw_rect(Rect2(left, Vector2(area.size.x*.18, area.size.y*.42)), [Color("e2445c"), Color("3a7bd5"), Color("ffb62e"), Color("7a4fd0")][i])
					draw_rect(Rect2(left+Vector2(4, 6), Vector2(area.size.x*.18-8, area.size.y*.14)), [Color("7fd4e8"), Color("ff8fb1"), Color("9ccc5a"), Color("ffd84d")][i])
				for i in 12:
					draw_circle(at.call(.05+i*.082, .14), 3, [Color("ff4fb0"), Color("37e0ff"), Color("ffe24f")][i % 3])
			"dragon_palace":
				var palace: Vector2 = at.call(.5, .64)
				for tier in 3:
					var width := area.size.x*(.44-tier*.1)
					var y := palace.y-tier*area.size.y*.17
					draw_rect(Rect2(Vector2(palace.x-width*.5, y-area.size.y*.12), Vector2(width, area.size.y*.12)), Color("fff4e0"))
					draw_colored_polygon(PackedVector2Array([Vector2(palace.x-width*.62, y-area.size.y*.1), Vector2(palace.x+width*.62, y-area.size.y*.1), Vector2(palace.x, y-area.size.y*.2)]), Color("2f9a8a"))
				for i in 5:
					var base: Vector2 = at.call(.08+i*.2, .72)
					draw_line(base, base-Vector2(sin(i)*6, 26), [Color("ff7a8a"), Color("ffb35c"), Color("c77dff")][i % 3], 5)
				for i in 8:
					draw_arc(at.call(fmod(i*.37, 1.0), .15+fmod(i*.29, .4)), 3.5, 0, TAU, 10, Color(1, 1, 1, .8), 1.5)
			"moon_base":
				draw_circle(at.call(.76, .22), 17, Color("3f86e0"))
				draw_circle(at.call(.72, .18), 6, Color("5fcf6a"))
				for i in 12:
					draw_circle(at.call(fmod(i*.41, .95)+.02, fmod(i*.23, .4)+.04), 1.5, Color("fff4d0"))
				for x in [.22, .5]:
					var dome: Vector2 = at.call(x, .64)
					draw_circle(dome, 16, Color("eef0f6"))
				draw_rect(Rect2(at.call(.86, .38), Vector2(8, area.size.y*.28)), Color("f4f5f9"))
				draw_colored_polygon(PackedVector2Array([at.call(.86, .38), at.call(.86, .38)+Vector2(8, 0), at.call(.86, .38)+Vector2(4, -10)]), Color("e8434f"))
			"sky_shrine":
				for band in 5:
					draw_arc(at.call(.5, .78), area.size.x*(.46-band*.04), PI, TAU, 24, KinuModel.RAINBOW[band], 4)
				for i in 6:
					draw_circle(at.call(.05+i*.18, .68+fmod(i*.3, .1)), 14, Color("fff6f4"))
				var gate: Vector2 = at.call(.5, .64)
				for side in [-1.0, 1.0]:
					draw_line(gate+Vector2(side*12, 0), gate+Vector2(side*12, -34), Color("e2553f"), 4)
				draw_line(gate+Vector2(-20, -34), gate+Vector2(20, -34), Color("2b1a17"), 5)
			"tea_fields":
				draw_colored_polygon(PackedVector2Array([at.call(.12, .62), at.call(.88, .62), at.call(.56, .1), at.call(.44, .1)]), _c("mountain", Color("8fa8d8")))
				draw_colored_polygon(PackedVector2Array([at.call(.38, .28), at.call(.62, .28), at.call(.56, .1), at.call(.44, .1)]), Color("f8fbff"))
				for row in 3:
					draw_rect(Rect2(at.call(.02, .68+row*.09), Vector2(area.size.x*.96, 6)), Color("3f8a43").lightened(row*.08))
			"sweets":
				var cake: Vector2 = at.call(.5, .64)
				for tier in 3:
					var width := area.size.x*(.36-tier*.09)
					draw_rect(Rect2(Vector2(cake.x-width*.5, cake.y-(tier+1)*area.size.y*.13), Vector2(width, area.size.y*.13)), Color("fff4e0"))
					draw_rect(Rect2(Vector2(cake.x-width*.5, cake.y-(tier+1)*area.size.y*.13+6), Vector2(width, 4)), Color("ff9fbf"))
				for x in [.14, .86]:
					var stick: Vector2 = at.call(x, .72)
					draw_line(stick, stick-Vector2(0, 42), Color("e8c48a"), 3)
					for i in 3:
						draw_circle(stick-Vector2(0, 14+i*10), 6, [Color("9ccc5a"), Color("fffaf2"), Color("ff9fbf")][i])
			"aurora":
				for i in 20:
					var x: Vector2 = at.call(.05+i*.047, .12+sin(i*.5)*.05)
					draw_line(x, x+Vector2(0, area.size.y*.22), [Color("5dffb0"), Color("3fe0d0"), Color("b58cff")][i % 3], 5)
				draw_circle(at.call(.3, .66), 15, Color("fbfdff"))
				for x in [.7, .85]:
					var base: Vector2 = at.call(x, .66)
					draw_colored_polygon(PackedVector2Array([base-Vector2(10, 0), base+Vector2(10, 0), base-Vector2(0, 34)]), Color("2f5a4f"))
			"beach":
				draw_rect(Rect2(at.call(0, .5), Vector2(area.size.x, area.size.y*.14)), _c("water", Color("4fc3e0")))
				var parasol: Vector2 = at.call(.32, .5)
				draw_line(parasol, parasol+Vector2(0, 30), Color("fbfbf6"), 2)
				draw_colored_polygon(PackedVector2Array([parasol-Vector2(20, -6), parasol+Vector2(20, 6), parasol-Vector2(0, 8)]), Color("e8434f"))
				var palm: Vector2 = at.call(.8, .72)
				draw_line(palm, palm+Vector2(6, -44), Color("a0764a"), 4)
				for i in 5:
					draw_line(palm+Vector2(6, -44), palm+Vector2(6, -44)+Vector2(cos(PI+i*.8)*16, sin(PI+i*.8)*8+4), Color("4fa04e"), 4)
			"lantern_river":
				draw_rect(Rect2(at.call(0, .66), Vector2(area.size.x, area.size.y*.14)), _c("water", Color("223a62")))
				for i in 7:
					draw_rect(Rect2(at.call(.05+i*.13, .68+fmod(i*.3, .06)), Vector2(6, 6)), Color("ffd98a"))
				for burst in 2:
					var center: Vector2 = at.call(.3+burst*.4, .22)
					for ray in 8:
						var a := TAU*ray/8.0
						draw_line(center+Vector2(cos(a), sin(a))*4, center+Vector2(cos(a), sin(a))*13, [Color("ffd166"), Color("ff7aa2")][burst], 2)
			"castle":
				var keep: Vector2 = at.call(.5, .64)
				draw_colored_polygon(PackedVector2Array([keep+Vector2(-30, 0), keep+Vector2(30, 0), keep+Vector2(22, -12), keep+Vector2(-22, -12)]), STONE_SWATCH)
				for tier in 3:
					var width := 34.0-tier*9.0
					var y := keep.y-12-tier*14
					draw_rect(Rect2(Vector2(keep.x-width*.5, y-10), Vector2(width, 10)), Color("fbf8f0"))
					draw_colored_polygon(PackedVector2Array([Vector2(keep.x-width*.5-6, y-8), Vector2(keep.x+width*.5+6, y-8), Vector2(keep.x, y-16)]), Color("56606e"))
				for x in [.14, .86]:
					draw_circle(at.call(x, .56), 13, Color("ffb3c8"))
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
