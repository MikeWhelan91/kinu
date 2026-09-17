class_name KinuPreview
extends SubViewportContainer
var model: Node3D
var camera: Camera3D
static var silhouette: ShaderMaterial

func setup(shape: KinuShape, flavour: KinuFlavour, discovered: bool = true, pixels: Vector2i = Vector2i(180,150), mood: String = "calm", outfit: KinuOutfit = null, outfit_framing: bool = false) -> void:
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
	var light := TofuShop.make_sun()
	light.shadow_enabled = false
	viewport.add_child(light)
	model = KinuModel.build(shape, flavour, outfit, mood)
	if not discovered:
		if silhouette == null:
			silhouette = ShaderMaterial.new()
			silhouette.shader = MeshKit.TOON
			silhouette.set_shader_parameter("flat_color", true)
			silhouette.set_shader_parameter("override_color", Color("a8998a"))
		(model.get_node("Fill") as MeshInstance3D).material_override = silhouette
		if model.has_node("Costume"):
			(model.get_node("Costume") as MeshInstance3D).material_override = silhouette
		if model.has_node("ExposedFace"):
			(model.get_node("ExposedFace") as MeshInstance3D).material_override = silhouette
		model.get_node("Face").hide()
	viewport.add_child(model)
	model.rotation_degrees.y = -22
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	# Costumes add ears, wings and tails, so frame a little wider and higher (optionally for plain Kinu too,
	# so a row of previews all match).
	var wide := outfit != null or outfit_framing
	camera.size = maxf(shape.size.x*1.9, shape.size.y*2.5)*(1.45 if wide else 1.0)
	camera.position = Vector3(0, 1.2+(.3 if wide else 0.0), 4)
	# Set the angle directly: look_at needs the node inside the tree, and setup runs before that.
	camera.rotation.x = -atan2(1.2, 4.0)
	viewport.add_child(camera)

## Frame the visible costume tightly for a featured portrait, including ears and tails.
func fit_model(padding: float = 1.18, align_bottom: bool = false) -> void:
	var lower := Vector2(INF, INF)
	var upper := Vector2(-INF, -INF)
	for child in model.get_children():
		if not child is MeshInstance3D or not child.visible or child.mesh == null:
			continue
		var to_camera: Transform3D = camera.transform.affine_inverse()*model.transform*child.transform
		# Project the actual silhouette, not the empty corners of a box around fins/tails.
		for surface in child.mesh.get_surface_count():
			var vertices: PackedVector3Array = child.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point: Vector3 = to_camera*vertex
				lower = lower.min(Vector2(point.x, point.y))
				upper = upper.max(Vector2(point.x, point.y))
	var center := (lower+upper)*.5
	var extent := upper-lower
	var viewport: SubViewport = get_child(0)
	camera.size = maxf(extent.x, extent.y*float(viewport.size.x)/viewport.size.y)*padding
	if align_bottom:
		var view_height := camera.size*float(viewport.size.y)/viewport.size.x
		center.y = lower.y+view_height*.5-view_height*4.0/viewport.size.y
	camera.position += camera.basis*Vector3(center.x, center.y, 0)
