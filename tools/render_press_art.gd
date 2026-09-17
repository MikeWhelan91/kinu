extends Node2D
## Renders the cast as transparent PNGs for the App Store screenshot studio:
##   godot --path . res://tools/render_press_art.tscn
## Each Kinu is drawn from the game's own models, so the store art matches the app exactly.

const OUT := "/Users/mike/Dev/Apps/critternest/app-store-screenshots/public/kinutumble/"
const SIDE := 640
## Share of the frame the Kinu fills; the rest is transparent margin.
const FILL := .9

## name, shape, flavour (or finish), outfit, mood, yaw
const CAST := [
	["kinu-silken", "block", "silken", "", "happy", -.42],
	["kinu-sakura", "block", "sakura", "", "happy", .38],
	["kinu-matcha", "block", "matcha", "", "calm", -.3],
	["kinu-sesame", "block", "sesame", "", "content", .34],
	["kinu-gold", "block", "gold", "", "happy", -.36],
	["kinu-falling", "block", "silken", "", "falling", .5],
	["kinu-worried", "tall", "silken", "", "worried", -.28],
	["kinu-slab", "slab", "fried", "", "calm", -.24],
	["kinu-tall-tamago", "tall", "tamago", "", "happy", .3],
	["kinu-ball", "ball", "silken", "", "squish", .2],
	["kinu-bunny", "tall", "silken", "bunny", "happy", -.3],
	["kinu-fox", "block", "silken", "fox", "happy", .32],
	["kinu-panda", "block", "silken", "panda", "calm", -.34],
	["kinu-tanuki", "tall", "silken", "tanuki", "happy", .26],
	## The flavours screen needs pieces that read apart from each other at
	## thumbnail size, so this half of the cast is picked for colour spread
	## rather than for being the common ones.
	["kinu-galaxy", "block", "galaxy", "", "happy", .34],
	["kinu-ube", "block", "ube", "", "calm", -.32],
	["kinu-blueberry", "block", "blueberry", "", "happy", .28],
	["kinu-kabocha", "slab", "kabocha", "", "content", -.26],
	["kinu-mint", "ball", "mint", "", "happy", .22],
	["kinu-chocolate", "block", "chocolate", "", "calm", .36],
	["kinu-jelly", "tall", "jelly", "", "happy", -.3],
	["kinu-ramune", "block", "ramune", "", "content", -.38],
]

var world: SubViewport
var catalog: KinuCatalog

func _ready() -> void:
	get_window().size = Vector2i(SIDE, SIDE)
	DirAccess.make_dir_recursive_absolute(OUT)
	catalog = load("res://resources/kinu/catalog.tres")
	world = SubViewport.new()
	world.size = Vector2i(SIDE, SIDE)
	world.transparent_bg = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)
	_lights()
	for entry in CAST:
		await _render(entry)
	get_tree().quit()

## Flat, bright and frontal: these sit on coloured store panels, not in the game's world.
func _lights() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CANVAS
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff3e0")
	env.environment.ambient_light_energy = .5
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -26, 0)
	key.light_energy = 1.0
	key.shadow_enabled = false
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-6, 152, 0)
	rim.light_color = Color("ffd6f2")
	rim.light_energy = .45
	rim.shadow_enabled = false
	world.add_child(rim)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.position = Vector3(0, 0, 4)
	camera.rotation.x = -.16
	world.add_child(camera)

func _render(entry: Array) -> void:
	var kinu := KinuModel.build(_find(catalog.shapes, entry[1]), _look(entry[2]), catalog.outfit(entry[3]), entry[4])
	kinu.rotation = Vector3(0, entry[5], 0)
	world.add_child(kinu)
	var camera := world.get_camera_3d()
	camera.size = 2.6
	camera.position = Vector3(0, 0, 4)
	for pass_index in 3:
		await RenderingServer.frame_post_draw
		_fit(camera, kinu)
	await RenderingServer.frame_post_draw
	var image := world.get_texture().get_image()
	image.save_png(OUT+str(entry[0])+".png")
	print("[art] ", entry[0])
	kinu.queue_free()
	await get_tree().process_frame

## Zooms and centres on the Kinu so every piece of art is framed the same, whatever its shape.
func _fit(camera: Camera3D, kinu: Node3D) -> void:
	var frame := Vector2(world.size)
	var bounds := Rect2()
	var started := false
	for mesh in _meshes(kinu):
		var box := mesh.global_transform*mesh.get_aabb()
		for corner in 8:
			var point := camera.unproject_position(box.get_endpoint(corner))
			if started:
				bounds = bounds.expand(point)
			else:
				bounds = Rect2(point, Vector2.ZERO)
				started = true
	if not started or bounds.size.x <= 0:
		return
	camera.size *= (maxf(bounds.size.x, bounds.size.y)/frame.x)/FILL
	var offset := (bounds.get_center()-frame*.5)/frame.x*camera.size
	camera.position.x += offset.x
	camera.position.y -= offset.y

func _look(id: String) -> KinuFlavour:
	var finish: KinuFlavour = catalog.finish(id)
	return finish if finish else _find(catalog.flavours, id)

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
