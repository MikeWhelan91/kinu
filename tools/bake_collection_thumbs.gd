extends Node
## Bakes every outfit and box in the catalogue to an individual PNG under resources/kinu/thumbs/.
## Run after any catalogue change that adds, removes or reskins an item:
##   godot --path . tools/bake_collection_thumbs.tscn
## (not --headless: headless uses a null renderer here and produces empty images.)
## The Kinu Book loads these directly at runtime instead of building a live 3D preview per card.

const OUT_DIR := "res://resources/kinu/thumbs"
const SIZE := Vector2i(220, 220)
## Outfits share this one padding so every costume renders at the same scale, the way a trading
## card game keeps every card's art at a consistent size — a bulky costume and a plain one both
## get cropped from the same camera distance. Below 1.0 the widest costumes (wings, tall hats)
## clip at the edges, which reads better at thumbnail size than a small character with spare margin.
const OUTFIT_PADDING := 0.8

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := WorldEnvironment.new()
	var env := TofuShop.make_environment()
	env.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment = env
	viewport.add_child(environment)
	var sun := TofuShop.make_sun()
	sun.shadow_enabled = false
	viewport.add_child(sun)

	# Pass 1: measure every outfit's on-screen extent to find the one shared camera size that
	# fits all of them, instead of each one cropping to its own bounds independently.
	var bounds := {}
	var shared_extent := 0.0
	for item in catalog.outfits:
		var before := viewport.get_children()
		var model := _build_outfit(catalog, item)
		viewport.add_child(model)
		var camera := _base_outfit_camera(catalog)
		viewport.add_child(camera)
		var b := _bounds(camera, model)
		bounds[item.id] = b
		shared_extent = maxf(shared_extent, maxf(b.extent.x, b.extent.y*float(SIZE.x)/SIZE.y))
		for child in viewport.get_children():
			if child not in before:
				viewport.remove_child(child)
				child.queue_free()
	var shared_size := shared_extent*OUTFIT_PADDING

	var count := 0
	for item in catalog.outfits:
		var before := viewport.get_children()
		var model := _build_outfit(catalog, item)
		viewport.add_child(model)
		var camera := _base_outfit_camera(catalog)
		camera.size = shared_size
		var b: Dictionary = bounds[item.id]
		camera.position += camera.basis*Vector3(b.center.x, b.center.y, 0)
		viewport.add_child(camera)
		await get_tree().process_frame
		await get_tree().process_frame
		save(viewport, "outfit_%s.png"%item.id, before)
		count += 1
		print("baked ", count, " ", item.id)
	for item in catalog.decor_of("box"):
		var before := viewport.get_children()
		_capture_box(viewport, item)
		await get_tree().process_frame
		await get_tree().process_frame
		save(viewport, "box_%s.png"%item.id, before)
		count += 1
		print("baked ", count, " ", item.id)
	print("Baked ", count, " collection thumbnails to ", OUT_DIR)
	get_tree().quit()

## Mirrors KinuShopScreen.preview's outfit case: a finish (pattern) outfit shows the plain shape in
## that flavour, not a costume, exactly as the Shop and Wardrobe already render it.
func _build_outfit(catalog: KinuCatalog, item: KinuOutfit) -> Node3D:
	var look: KinuFlavour = item.finish if item.finish else catalog.flavours[0]
	var outfit: KinuOutfit = null if item.finish else item
	var model := KinuModel.build(catalog.shapes[0], look, outfit, "calm")
	model.rotation_degrees.y = -22
	return model

func _base_outfit_camera(catalog: KinuCatalog) -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = maxf(catalog.shapes[0].size.x*1.9, catalog.shapes[0].size.y*2.5)*1.45
	camera.position = Vector3(0, 1.5, 4)
	camera.rotation.x = -atan2(1.2, 4.0)
	return camera

## The on-screen bounding box of a model's visible meshes, in the given camera's view space.
func _bounds(camera: Camera3D, model: Node3D) -> Dictionary:
	var lower := Vector2(INF, INF)
	var upper := Vector2(-INF, -INF)
	for child in model.get_children():
		if not child is MeshInstance3D or not child.visible or child.mesh == null:
			continue
		var to_camera: Transform3D = camera.transform.affine_inverse()*model.transform*child.transform
		for surface in child.mesh.get_surface_count():
			var vertices: PackedVector3Array = child.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point: Vector3 = to_camera*vertex
				lower = lower.min(Vector2(point.x, point.y))
				upper = upper.max(Vector2(point.x, point.y))
	if lower.x == INF:
		return {"center": Vector2.ZERO, "extent": Vector2.ZERO}
	return {"center": (lower+upper)*.5, "extent": upper-lower}

func _capture_box(viewport: SubViewport, item: KinuDecor) -> void:
	var node := TofuBox.new()
	node.decor = item
	node.with_collision = false
	node.rotation.y = .5
	viewport.add_child(node)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	# Boxes are broad (including bows, corner posts and special trims). The old close camera
	# cut their corners off in the Collection, which made every skin look like a crop rather
	# than a usable box. Match the roomy live-preview framing.
	camera.size = 7.0
	camera.position = Vector3(0, 4.2, 5.2)
	camera.rotation.x = -atan2(3.7, 5.2)
	viewport.add_child(camera)

func save(viewport: SubViewport, filename: String, before: Array) -> void:
	viewport.get_texture().get_image().save_png(OUT_DIR.path_join(filename))
	for child in viewport.get_children():
		if child not in before:
			viewport.remove_child(child)
			child.queue_free()
