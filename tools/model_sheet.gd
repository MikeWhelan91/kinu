extends Node3D
## Renders Kinu's shapes, flavours, moods and outfits to docs/models.png for art iteration.

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = TofuShop.make_environment()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("cdeefd")
	add_child(env)
	var sun := TofuShop.make_sun()
	sun.shadow_enabled = false
	add_child(sun)
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var silken := catalog.flavours[0]
	var block := catalog.shapes[0]
	var rows := [
		["Shapes", catalog.shapes.map(func(s: KinuShape) -> Array: return [s, silken, null, "calm", s.display_name])],
		["Flavours", catalog.flavours.map(func(f: KinuFlavour) -> Array: return [block, f, null, "calm", f.display_name])],
		["Moods", KinuModel.MOODS.map(func(m: String) -> Array: return [block, silken, null, m, m.capitalize()])],
		["Outfits", catalog.outfits.map(func(o: KinuOutfit) -> Array: return [block, silken, o, "calm", o.display_name])],
	]
	for r in rows.size():
		var y := 4.2-r*2.75
		_label(rows[r][0], Vector3(-7.6, y+1.25, 0), 40, NestTheme.SKY, true)
		var items: Array = rows[r][1]
		for i in items.size():
			var item: Array = items[i]
			var model := KinuModel.build(item[0], item[1], item[2], item[3])
			var x := -5.6+i*2.45
			model.position = Vector3(x, y, 0)
			model.rotation.y = -.3
			add_child(model)
			_label(item[4], Vector3(x, y-1.1, 0), 30, NestTheme.INK)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 16.5
	camera.position = Vector3(.3, 3.4, 12)
	add_child(camera)
	camera.rotation.x = -.2
	get_window().size = Vector2i(1400, 1260)
	await get_tree().create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/models.png")
	get_tree().quit()

func _label(text: String, position: Vector3, size: int, color: Color, left: bool = false) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = NestTheme.font
	label.font_size = size
	label.outline_size = 12
	label.modulate = color
	label.outline_modulate = Color.WHITE
	label.pixel_size = .007
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_CENTER
	label.position = position
	add_child(label)
