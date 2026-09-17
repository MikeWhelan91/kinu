extends Node2D
## Renders the app icon (1024px) and boot splash (192px):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/render_icon.tscn
## A night-market moment: a big cream Kinu peeks over the rim of the hinoki crate with a bunny Kinu
## squeezed in beside it, under a paper lantern on a sunny day. The Kinu and the crate are the
## game's own 3D models on a transparent viewport, laid over flat 2D artwork drawn with the same ink
## outline, so every face and edge is real geometry rather than painted.
##
## `-- <out.png>` renders somewhere else for comparison without touching the real icon.

const SIDE := 1024.0
const INK := Color("2e1c16")
## Where the Kinu should land on the icon, as a screen rect the camera is fitted to. The crate is left
## to run off the bottom and sides, which is what makes it read as a close-up.
const KINU_FRAME := Rect2(130, 175, 780, 660)
const KINU_SCALE := 1.9

var world: SubViewport
var kinu: Array[Node3D] = []
var out_path := "res://assets/icons/app_icon.png"

func _ready() -> void:
	get_window().size = Vector2i(1024, 1024)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	add_child(DaySky.new())
	world = SubViewport.new()
	world.size = Vector2i(1024, 1024)
	world.transparent_bg = true
	world.msaa_3d = Viewport.MSAA_4X
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)
	_build_world()
	for pass_index in 3:
		await RenderingServer.frame_post_draw
		await _fit()
	var layer := Sprite2D.new()
	layer.centered = false
	layer.texture = world.get_texture()
	add_child(layer)
	add_child(Petals.new())
	await get_tree().create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(out_path)
	if out_path.ends_with("app_icon.png"):
		image.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		image.save_png("res://assets/icons/splash.png")
	get_tree().quit()

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CANVAS
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff3e0")
	env.environment.ambient_light_energy = .45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(env)
	# Warm sunlit key, with a cool sky-blue rim from the right.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -40, 0)
	key.light_color = Color("fff0dc")
	key.light_energy = 1.0
	key.shadow_enabled = false
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_color = Color("c9d4ff")
	rim.light_energy = .45
	rim.shadow_enabled = false
	world.add_child(rim)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	camera.position = Vector3(0, 3.2, 6.0)
	camera.rotation.x = -.2
	world.add_child(camera)
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var box := TofuBox.new()
	box.decor = catalog.find_decor("box", "hinoki")
	# Turned so a front corner points at the camera, like the crate in the game's own previews.
	box.rotation.y = .62
	world.add_child(box)
	var floor_y := TofuBox.FLOOR_TOP
	# Both Kinu are lifted clear of the floor so they peek over the front wall instead of hiding
	# behind it; the floor itself is out of sight, so nothing reads as floating.
	# The big Kinu tips toward the lantern.
	var big_h: float = _find(catalog.shapes, "block").size.y*KINU_SCALE
	kinu.append(_kinu(catalog, "block", "silken", Vector3(-.45, floor_y+big_h*.5+.6, -.35),
		Vector3(-.05, .3, .14), "happy", KINU_SCALE))
	# The bunny squeezes into the front right corner, a size smaller.
	var bunny_h: float = _find(catalog.shapes, "block").size.y*1.2
	kinu.append(_kinu(catalog, "block", "sakura", Vector3(1.15, floor_y+bunny_h*.5+.85, .85),
		Vector3(0, -.25, -.12), "calm", 1.2, "bunny"))

## Zooms and centres the camera so the two Kinu fill KINU_FRAME.
func _fit() -> void:
	var camera := world.get_camera_3d()
	var bounds := _screen_bounds(camera)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	camera.size *= maxf(bounds.size.x/KINU_FRAME.size.x, bounds.size.y/KINU_FRAME.size.y)
	await RenderingServer.frame_post_draw
	bounds = _screen_bounds(camera)
	var offset := (bounds.get_center()-KINU_FRAME.get_center())/SIDE*camera.size
	camera.position += camera.global_transform.basis.x*offset.x-camera.global_transform.basis.y*offset.y

func _screen_bounds(camera: Camera3D) -> Rect2:
	var bounds := Rect2()
	var started := false
	for body in kinu:
		for mesh in _meshes(body):
			var box := mesh.global_transform*mesh.get_aabb()
			for corner in 8:
				var point := camera.unproject_position(box.get_endpoint(corner))
				if started:
					bounds = bounds.expand(point)
				else:
					bounds = Rect2(point, Vector2.ZERO)
					started = true
	return bounds

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found

func _kinu(catalog: KinuCatalog, shape_id: String, flavour_id: String, at: Vector3, turn: Vector3, mood: String, scale_to: float = 1.0, outfit: String = "") -> Node3D:
	var flavour: KinuFlavour = catalog.finish(flavour_id)
	if flavour == null:
		flavour = _find(catalog.flavours, flavour_id)
	var body := KinuModel.build(_find(catalog.shapes, shape_id), flavour, catalog.outfit(outfit), mood)
	body.position = at
	body.rotation = turn
	body.scale = Vector3.ONE*scale_to
	world.add_child(body)
	return body

func _find(items: Array, id: String) -> Resource:
	for item in items:
		if item.id == id:
			return item
	return items[0]

## A sakura petal: a rounded teardrop with the little notch at its tip.
class Petal:
	static func points(at: Vector2, angle: float, length: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		var width := length*.62
		for i in 25:
			var t := float(i)/24.0
			var along := lerpf(-.5, .5, t)*length
			var bulge := sin(t*PI)*pow(1.0-t, .35)*width*.62
			points.append(Vector2(along, -bulge))
		for i in range(24, -1, -1):
			var t := float(i)/24.0
			var along := lerpf(-.5, .5, t)*length
			var bulge := sin(t*PI)*pow(1.0-t, .35)*width*.62
			points.append(Vector2(along, bulge))
		# Pull the middle of the wide end inwards for the notch.
		points[0] = Vector2(-.5*length+length*.12, 0)
		var turn := Transform2D(angle, at)
		return turn*points

## Everything behind the Kinu, drawn flat with the game's ink outline.
class DaySky extends Node2D:
	const SIDE := 1024.0
	const INK := Color("2e1c16")
	const SKY_TOP := Color("3aa8ee")
	const SKY_LOW := Color("a8dcfa")
	const SUN := Color("ffe45c")
	const CLOUD := Color("ffffff")
	const LANTERN := Color("f0553a")
	const LANTERN_DARK := Color("c23a2a")
	const LANTERN_LIGHT := Color("ff8a5c")

	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(SIDE, 0), Vector2(SIDE, SIDE), Vector2(0, SIDE)]),
			PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
		_hills()
		_counter()
		_sun(Vector2(850, 170), 78.0)
		_cloud(Vector2(580, 150), 1.0)
		_cloud(Vector2(930, 440), .85)
		_cloud(Vector2(90, 560), .7)
		_lantern(Vector2(165, 205))

	## Rolling green hills along the horizon.
	func _hills() -> void:
		for hill in [[Vector2(110, 720), Vector2(260, 160), Color("7cc76a")], [Vector2(930, 700), Vector2(300, 150), Color("8fd27a")],
				[Vector2(520, 780), Vector2(420, 130), Color("6bb85c")]]:
			var points := _ellipse(hill[0], hill[1], 64)
			draw_colored_polygon(points, hill[2])
			points.append(points[0])
			draw_polyline(points, INK, 5.0, true)

	## The stall counter the crate sits on, so the corners under it are wood rather than grass.
	func _counter() -> void:
		var top := 845.0
		draw_rect(Rect2(0, top, SIDE, SIDE-top), Color("b9794a"))
		draw_rect(Rect2(0, top, SIDE, 26), Color("d6955e"))
		for y in [top+70.0, top+130.0]:
			draw_line(Vector2(0, y), Vector2(SIDE, y), Color("9a603a"), 4.0)
		draw_line(Vector2(0, top), Vector2(SIDE, top), INK, 7.0)

	## A round sun with rounded, evenly spaced rays.
	func _sun(at: Vector2, radius: float) -> void:
		for i in 10:
			var dir := Vector2.from_angle(TAU*i/10.0-PI*.5)
			var from := at+dir*(radius+26)
			var to := at+dir*(radius+62)
			draw_line(from, to, INK, 22.0)
			draw_circle(from, 11.0, INK)
			draw_circle(to, 11.0, INK)
			draw_line(from, to, SUN, 12.0)
			draw_circle(from, 6.0, SUN)
			draw_circle(to, 6.0, SUN)
		draw_circle(at, radius+4, INK)
		draw_circle(at, radius-3, SUN)
		draw_circle(at+Vector2(-radius*.25, -radius*.25), radius*.45, Color("fff29c"))

	## A puffy cloud: overlapping circles on a flat base, outlined as one shape.
	func _cloud(at: Vector2, scale_by: float) -> void:
		var puffs := [[Vector2(-70, 0), 42.0], [Vector2(-18, -32), 58.0], [Vector2(48, -16), 48.0], [Vector2(92, 6), 34.0]]
		var base := Rect2(at+Vector2(-70, -4)*scale_by, Vector2(162, 46)*scale_by)
		for puff in puffs:
			draw_circle(at+puff[0]*scale_by, (puff[1]+6)*scale_by, INK)
		draw_rect(base.grow(6*scale_by), INK)
		for puff in puffs:
			draw_circle(at+puff[0]*scale_by, puff[1]*scale_by, CLOUD)
		draw_rect(base, CLOUD)

	## A round chōchin with ribs, caps and a painted blossom, glowing into the sky.
	func _lantern(at: Vector2) -> void:
		var size := Vector2(165, 150)
		draw_line(at+Vector2(0, -size.y-60), at+Vector2(0, -size.y), INK, 6.0)
		var body := _ellipse(at, size, 64)
		draw_colored_polygon(body, LANTERN)
		draw_colored_polygon(_ellipse(at+Vector2(-size.x*.2, -size.y*.15), size*Vector2(.55, .7), 48), LANTERN_LIGHT)
		# Ribs follow the ellipse so the paper reads round.
		for i in range(-4, 5):
			var y := at.y+i*size.y/5.0
			var half := size.x*sqrt(maxf(1.0-pow((y-at.y)/size.y, 2), 0))
			draw_line(Vector2(at.x-half+4, y), Vector2(at.x+half-4, y), LANTERN_DARK, 3.0, true)
		_blossom(at+Vector2(-10, 5), 50.0)
		body.append(body[0])
		draw_polyline(body, INK, 7.0, true)
		for cap in [[at.y-size.y+8, 1.0], [at.y+size.y-8, -1.0]]:
			var rect := Rect2(at.x-78, cap[0]-(22 if cap[1] > 0 else 0), 156, 22)
			draw_rect(rect, Color("3a2a2a"))
			draw_rect(rect, INK, false, 6.0)
		draw_line(at+Vector2(0, size.y+14), at+Vector2(0, size.y+60), Color("ffd76a"), 8.0)

	func _blossom(at: Vector2, radius: float) -> void:
		for i in 5:
			var angle := -PI*.5+TAU*i/5.0
			var petal := Petal.points(at+Vector2.from_angle(angle)*radius*.52, angle+PI, radius*.95)
			draw_colored_polygon(petal, Color("ffe6c2"))
		draw_circle(at, radius*.13, Color("f0a33a"))

	func _ellipse(at: Vector2, radius: Vector2, steps: int) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in steps:
			points.append(at+Vector2.from_angle(TAU*i/steps)*radius)
		return points

## Petals drifting in front of and behind the scene.
class Petals extends Node2D:
	const INK := Color("2e1c16")
	func _draw() -> void:
		for drift in [[Vector2(420, 85), .5, 62.0], [Vector2(885, 470), -.7, 70.0], [Vector2(55, 560), 1.1, 58.0],
				[Vector2(90, 900), -.3, 84.0], [Vector2(935, 930), .9, 72.0]]:
			var points := Petal.points(drift[0], drift[1], drift[2])
			draw_colored_polygon(points, Color("ffc3d6"))
			draw_colored_polygon(Petal.points(drift[0]+Vector2(3, -3), drift[1], drift[2]*.55), Color("ffe1ea"))
			points.append(points[0])
			draw_polyline(points, INK, 5.0, true)
