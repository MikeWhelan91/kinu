extends Node3D
## Review the ghost upright, tilted and directly underneath on every body shape.
func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1100)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = TofuShop.make_environment()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("eee2cf")
	viewport.add_child(env)
	var sun := TofuShop.make_sun()
	sun.shadow_enabled = false
	viewport.add_child(sun)
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var ghost: KinuOutfit
	for outfit in catalog.outfits:
		if outfit.style == "ghost":
			ghost = outfit
	for row in 3:
		for col in 5:
			var shape: KinuShape = catalog.shapes[col]
			var model := KinuModel.build(shape, catalog.flavours[0], ghost)
			model.position = Vector3((col-2)*3.0, (1-row)*3.0, 0)
			model.rotation = Vector3([0.0, -.9, -PI*.5][row], -.25 if row < 2 else 0.0, 0)
			viewport.add_child(model)
			var label := Label3D.new()
			label.text = shape.display_name+" · "+["Upright", "Tilted", "Underside"][row]
			label.font = NestTheme.font
			label.font_size = 30
			label.outline_size = 0
			label.modulate = Color("493c43")
			label.pixel_size = .006
			label.position = model.position+Vector3(0, -1.25, .1)
			viewport.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 16.0
	camera.position = Vector3(0, 0, 20)
	viewport.add_child(camera)
	await get_tree().create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://docs/ghost-underside.png")
	get_tree().quit()
