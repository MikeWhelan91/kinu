extends Node2D
## Renders the full-screen Kinu Tumble boot splash from the game's own models:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/render_splash.tscn
##
## The layout deliberately follows the quiet title-over-mascot rhythm of Critter Scale's splash,
## while every shape, colour and character comes from Kinu Tumble itself.

const WIDTH := 1290
const HEIGHT := 2796
## Lift the mascot tableau clear of the iPhone home-indicator area and narrow device crops.
const ART_TOP := 930
const ART_HEIGHT := 1530
const FILL := .89
const BOX_SCALE := .72
const OUT := "res://assets/icons/splash_fullscreen.png"

var canvas: SubViewport
var world: SubViewport


func _ready() -> void:
	canvas = SubViewport.new()
	canvas.size = Vector2i(WIDTH, HEIGHT)
	canvas.transparent_bg = false
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	canvas.add_child(SplashBackground.new())
	_add_title()

	world = SubViewport.new()
	world.size = Vector2i(WIDTH, ART_HEIGHT)
	world.transparent_bg = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)
	_build_world()
	for pass_index in 4:
		await RenderingServer.frame_post_draw
		await _fit_world()

	var art := Sprite2D.new()
	art.centered = false
	art.position = Vector2(0, ART_TOP)
	art.texture = world.get_texture()
	canvas.add_child(art)
	canvas.add_child(SplashForeground.new())

	await get_tree().create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(OUT)
	print("[art] full-screen splash -> ", OUT)
	get_tree().quit()


func _add_title() -> void:
	var kinu := NestTheme.headline("Kinu", 250, NestTheme.CREAM)
	kinu.add_theme_font_override("font", NestTheme.font)
	kinu.add_theme_color_override("font_shadow_color", Color("7a2f58"))
	kinu.add_theme_constant_override("shadow_offset_y", 24)
	kinu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kinu.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kinu.position = Vector2(0, 360)
	kinu.size = Vector2(WIDTH, 330)
	canvas.add_child(kinu)

	var tumble := NestTheme.headline("Tumble", 218, NestTheme.BERRY)
	tumble.add_theme_font_override("font", NestTheme.font)
	tumble.add_theme_color_override("font_shadow_color", Color("7a2f58"))
	tumble.add_theme_constant_override("shadow_offset_y", 22)
	tumble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tumble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tumble.position = Vector2(0, 625)
	tumble.size = Vector2(WIDTH, 300)
	canvas.add_child(tumble)


## The exact crate and Kinu used by the game, lit flat and bright like the in-game previews.
func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CANVAS
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff3e0")
	env.environment.ambient_light_energy = .48
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -28, 0)
	key.light_energy = 1.02
	key.shadow_enabled = false
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8, 154, 0)
	rim.light_color = Color("ffd0ee")
	rim.light_energy = .48
	rim.shadow_enabled = false
	world.add_child(rim)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.8
	camera.position = Vector3(.1, 2.3, 4.6)
	camera.rotation.x = -.20
	world.add_child(camera)

	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var box := TofuBox.new()
	box.decor = catalog.find_decor("box", "hinoki")
	box.rotation.y = .58
	box.scale = Vector3.ONE*BOX_SCALE
	world.add_child(box)

	var tilt := .055
	var lean := Vector3(0, 0, tilt)
	var up := (Basis(Vector3.BACK, tilt)*Vector3.UP).normalized()
	var slab_h: float = _find(catalog.shapes, "slab").size.y
	var block_h: float = _find(catalog.shapes, "block").size.y
	var tall_h: float = _find(catalog.shapes, "tall").size.y
	var at := Vector3(-.14, TofuBox.FLOOR_TOP*BOX_SCALE, 0)+up*slab_h*.5
	_kinu(catalog, "slab", "silken", at, lean+Vector3(0, -.20, 0), "calm")
	at += up*(slab_h+block_h)*.5
	_kinu(catalog, "block", "matcha", at, lean+Vector3(0, .30, 0), "happy")
	at += up*block_h
	_kinu(catalog, "block", "gold", at, lean+Vector3(0, -.35, 0), "happy")
	at += up*(block_h+tall_h)*.5
	_kinu(catalog, "tall", "silken", at, lean+Vector3(0, .22, 0), "worried", 1.0, "bunny")

	# A fifth Kinu drops toward the tower, keeping the image about play rather than a posed cast.
	_kinu(catalog, "block", "sakura", at+Vector3(1.18, 1.22, .08),
		Vector3(.10, .55, -.72), "falling", .9)


func _fit_world() -> void:
	var camera := world.get_camera_3d()
	var frame := Vector2(world.size)
	var bounds := _screen_bounds(camera)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	var scale_needed := maxf(bounds.size.x/(frame.x*FILL), bounds.size.y/(frame.y*FILL))
	camera.size *= scale_needed
	await RenderingServer.frame_post_draw
	bounds = _screen_bounds(camera)
	var offset := (bounds.get_center()-frame*.5)/frame.y*camera.size
	camera.position.x += offset.x
	camera.position.y -= offset.y


func _screen_bounds(camera: Camera3D) -> Rect2:
	var bounds := Rect2()
	var started := false
	for mesh in _meshes(world):
		var box := mesh.global_transform*mesh.get_aabb()
		for corner in 8:
			var point := camera.unproject_position(box.get_endpoint(corner))
			if started:
				bounds = bounds.expand(point)
			else:
				bounds = Rect2(point, Vector2.ZERO)
				started = true
	return bounds


func _kinu(catalog: KinuCatalog, shape_id: String, flavour_id: String, at: Vector3,
		turn: Vector3, mood: String, scale_to: float = 1.0, outfit: String = "") -> Node3D:
	var look: KinuFlavour = catalog.finish(flavour_id)
	if look == null:
		look = _find(catalog.flavours, flavour_id)
	var kinu := KinuModel.build(_find(catalog.shapes, shape_id), look, catalog.outfit(outfit), mood)
	kinu.position = at
	kinu.rotation = turn
	kinu.scale = Vector3.ONE*scale_to
	world.add_child(kinu)
	return kinu


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found


func _find(items: Array, id: String) -> Resource:
	for item in items:
		if item.id == id:
			return item
	return items[0]


## A sunny day behind the tableau, matching the app icon: sky, sun, puffy clouds and green hills.
class SplashBackground extends Node2D:
	const INK := Color("2e1c16")
	const SKY_TOP := Color("3aa8ee")
	const SKY_LOW := Color("b4e2fb")
	const SUN := Color("ffe45c")

	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(WIDTH, 0), Vector2(WIDTH, HEIGHT), Vector2(0, HEIGHT)]),
			PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
		_sun(Vector2(1050, 250), 105.0)
		_cloud(Vector2(250, 250), 1.1)
		_cloud(Vector2(1110, 1180), .9)
		_cloud(Vector2(170, 1330), .75)
		# Hills on the horizon behind the crate, then a meadow down to the bottom edge.
		for hill in [[Vector2(160, 2080), Vector2(430, 230), Color("8fd27a")], [Vector2(1130, 2040), Vector2(460, 250), Color("7cc76a")],
				[Vector2(640, 2170), Vector2(640, 200), Color("6bb85c")]]:
			var points := _ellipse(hill[0], hill[1], 72)
			draw_colored_polygon(points, hill[2])
			points.append(points[0])
			draw_polyline(points, INK, 7.0, true)
		draw_rect(Rect2(0, 2200, WIDTH, HEIGHT-2200), Color("6bb85c"))
		draw_line(Vector2(0, 2200), Vector2(WIDTH, 2200), INK, 7.0)

	func _sun(at: Vector2, radius: float) -> void:
		for i in 10:
			var dir := Vector2.from_angle(TAU*i/10.0-PI*.5)
			var from := at+dir*(radius+34)
			var to := at+dir*(radius+80)
			draw_line(from, to, INK, 28.0)
			draw_circle(from, 14.0, INK)
			draw_circle(to, 14.0, INK)
			draw_line(from, to, SUN, 15.0)
			draw_circle(from, 7.5, SUN)
			draw_circle(to, 7.5, SUN)
		draw_circle(at, radius+5, INK)
		draw_circle(at, radius-4, SUN)
		draw_circle(at+Vector2(-radius*.25, -radius*.25), radius*.45, Color("fff29c"))

	func _cloud(at: Vector2, scale_by: float) -> void:
		var puffs := [[Vector2(-70, 0), 42.0], [Vector2(-18, -32), 58.0], [Vector2(48, -16), 48.0], [Vector2(92, 6), 34.0]]
		var base := Rect2(at+Vector2(-70, -4)*scale_by, Vector2(162, 46)*scale_by)
		for puff in puffs:
			draw_circle(at+puff[0]*scale_by, (puff[1]+6)*scale_by, INK)
		draw_rect(base.grow(6*scale_by), INK)
		for puff in puffs:
			draw_circle(at+puff[0]*scale_by, puff[1]*scale_by, Color.WHITE)
		draw_rect(base, Color.WHITE)

	func _ellipse(at: Vector2, radius: Vector2, steps: int) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in steps:
			points.append(at+Vector2.from_angle(TAU*i/steps)*radius)
		return points


## A few crisp petals in front of the render add motion without changing the native 3D look.
class SplashForeground extends Node2D:
	func _draw() -> void:
		_petal(Vector2(155, 1510), -0.5, 38)
		_petal(Vector2(1105, 1640), .35, 44)
		_petal(Vector2(180, 2320), .8, 30)
		_petal(Vector2(1080, 2440), -.7, 36)

	func _petal(at: Vector2, rotation: float, size: float) -> void:
		var along := Vector2(cos(rotation), sin(rotation))
		var across := Vector2(-along.y, along.x)
		draw_colored_polygon(PackedVector2Array([at-along*size, at-across*size*.48,
			at+along*size, at+across*size*.48]), Color("ffb3cb"))
		draw_polyline(PackedVector2Array([at-along*size, at-across*size*.48,
			at+along*size, at+across*size*.48, at-along*size]), Color("3a2418"), 5.0, true)
