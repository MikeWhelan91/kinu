extends SceneTree
## Exercise runtime expression changes, cache isolation and fabric materials for every shape/style.
func _initialize() -> void:
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var count := 0
	var combinations := 0
	for shape in catalog.shapes:
		var plain := KinuModel.build(shape, catalog.flavours[0])
		var plain_face: Mesh = plain.get_node("Face").mesh
		for outfit in catalog.outfits:
			var model := KinuModel.build(shape, catalog.flavours[0], outfit)
			assert(model.get_node("Costume").mesh.get_surface_count() > 0)
			var costume_mesh: Mesh = model.get_node("Costume").mesh
			if outfit.style == "ghost":
				check_underside(costume_mesh, shape)
			for mood in KinuModel.MOODS:
				KinuModel.set_mood(model, shape, mood, true)
				assert(model.get_node("Face").mesh.get_surface_count() > 0)
				assert(model.get_node("Costume").mesh == costume_mesh)
				assert(plain.get_node("Face").mesh == plain_face)
				var fresh := KinuModel.build(shape, catalog.flavours[0], outfit, mood)
				KinuModel.set_mood(fresh, shape, mood, true)
				assert(fresh.get_node("Face").mesh == model.get_node("Face").mesh)
				fresh.free()
				count += 1
			for finish in catalog.flavours + catalog.finishes:
				var special := KinuModel.build(shape, finish, outfit)
				assert(special.get_node("Costume").material_override == MeshKit.toon_material())
				assert(special.get_node("Costume").mesh == costume_mesh)
				assert(special.get_node("Fill").visible == (outfit.style in KinuModel.BARE_STYLES))
				var exposes_skin: bool = outfit.style not in KinuModel.BARE_STYLES and outfit.style not in ["ghost", "panda"]
				assert(special.has_node("ExposedFace") == exposes_skin)
				if exposes_skin:
					assert(special.get_node("ExposedFace").material_override == MeshKit.toon_material())
					var colors: PackedColorArray = special.get_node("ExposedFace").mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
					assert(absf(colors[0].r-finish.color.r) < .005)
					assert(absf(colors[0].g-finish.color.g) < .005)
					assert(absf(colors[0].b-finish.color.b) < .005)
					KinuModel.set_mood(special, shape, "calm", finish.light_face)
					var face_colors: PackedColorArray = special.get_node("Face").mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
					var ink := Color("fff6e2") if finish.light_face else KinuModel.INK
					assert(absf(face_colors[0].r-ink.r) < .005)
				combinations += 1
				special.free()
			model.free()
		plain.free()
	KinuModel.clear_cache()
	assert(KinuModel.costumes.is_empty() and KinuModel.exposed_faces.is_empty())
	print("PASS: %s shape/outfit/mood combinations; %s shape/outfit/flavour-or-finish combinations; colours, eye contrast, materials and cache isolation"%[count, combinations])
	quit()

## Rays from below must meet outward-facing fabric across the ghost's underside.
func check_underside(mesh: Mesh, shape: KinuShape) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for x in [-.7, 0.0, .7]:
		for z in [-.7, 0.0, .7]:
			var start := Vector3(x*shape.size.x*.5, -shape.size.y-1, z*shape.size.z*.5)
			var end := Vector3(start.x, 0, start.z)
			var covered := false
			for i in range(0, indices.size(), 3):
				var a := vertices[indices[i]]
				var b := vertices[indices[i+1]]
				var c := vertices[indices[i+2]]
				if (c-a).cross(b-a).normalized().dot(Vector3.DOWN) < .5:
					continue
				if Geometry3D.segment_intersects_triangle(start, end, a, b, c) != null:
					covered = true
					break
			assert(covered, "Ghost underside hole: %s at %s"%[shape.id, start])
