extends Node3D
## Reproducible outfit review: all styles, shapes, expressions and special finishes.
func _ready() -> void:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(2100, 1400)
	canvas.own_world_3d = true
	canvas.msaa_3d = Viewport.MSAA_4X
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var page := 0
	var mixed := OS.get_cmdline_user_args().has("--flavours")
	var flavour_sheet := OS.get_cmdline_user_args().has("--flavour-sheet")
	var glazed := OS.get_cmdline_user_args().has("--glaze")
	var look_suffix := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--look="):
			look_suffix = "-"+arg.trim_prefix("--look=")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--page="):
			page = int(arg.trim_prefix("--page="))
	var env := WorldEnvironment.new()
	env.environment = TofuShop.make_environment()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("eee2cf")
	canvas.add_child(env)
	var sun := TofuShop.make_sun()
	sun.shadow_enabled = false
	canvas.add_child(sun)
	var count := catalog.flavours.size() if flavour_sheet else catalog.outfits.size()
	for i in count:
		var outfit: KinuOutfit = null if flavour_sheet else catalog.outfits[i]
		var shape: KinuShape = catalog.shapes[page % catalog.shapes.size()]
		var mood: String = KinuModel.MOODS[(i+page) % 6] if page > 0 else "calm"
		var look: KinuFlavour = catalog.flavours[i] if flavour_sheet else catalog.flavours[0]
		if mixed and not flavour_sheet:
			var looks: Array = catalog.flavours + catalog.finishes
			var ids := ["sesame", "matcha", "sakura", "chocolate", "wood", "galaxy", "blueberry", "matcha", "galaxy", "galaxy", "jelly", "mango", "crystal", "ube", "gold", "galaxy", "kinako", "onigiri", "hanabi", "ramune", "azuki", "kabocha", "wasabi", "gold"]
			for candidate in looks:
				if candidate.id == ids[i % ids.size()]:
					look = candidate
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--look="):
				look = catalog.finish(arg.trim_prefix("--look=")) if catalog.finish(arg.trim_prefix("--look=")) else look
		var model := KinuModel.build(shape, look, outfit, mood)
		if glazed:
			model.add_child(KinuModel.glaze(shape, outfit))
			model.add_child(KinuModel.glaze(shape, outfit, true))
		model.position = Vector3((i % 6-2.5)*3.6, (1.5-floori(i/6.0))*3.0, 0)
		model.rotation_degrees.y = -22
		canvas.add_child(model)
		var label := Label3D.new()
		label.text = look.display_name if flavour_sheet else outfit.display_name+(" + "+look.display_name if mixed else "")
		label.font = NestTheme.font
		label.font_size = 32 if mixed else 42
		label.outline_size = 0
		label.modulate = Color("493c43")
		label.pixel_size = .006
		label.position = model.position+Vector3(0, -1.28, .1)
		canvas.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 22.0
	camera.position = Vector3(0, 3.6, 20)
	camera.rotation.x = -.17
	canvas.add_child(camera)
	await get_tree().create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png("res://docs/costumes-%s%s%s.png"%[catalog.shapes[page % 5].id, look_suffix, "-glaze" if glazed else "-flavour-sheet" if flavour_sheet else ("-flavours" if mixed else "")])
	get_tree().quit()
