extends Node3D
## Review sheets for the Kinu Catcher items, saved into the scratch folder given by out=.
##   godot --path . tools/catcher_sheet.tscn -- sheet=outfits out=/tmp/x
##   sheet=boxes, or sheet=room room=arcade for one room from the home and play cameras.
var options := {"sheet": "outfits", "out": "res://docs", "room": "arcade", "look": "", "group": "premium", "page": "0"}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var canvas := SubViewport.new()
	canvas.size = Vector2i(2000, 1300) if options.sheet != "room" else Vector2i(900, 1600)
	canvas.own_world_3d = true
	canvas.msaa_3d = Viewport.MSAA_4X
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	var camera := Camera3D.new()
	match options.sheet:
		"outfits", "boxes":
			var env := WorldEnvironment.new()
			env.environment = TofuShop.make_environment()
			env.environment.background_color = Color("eee2cf")
			canvas.add_child(env)
			var sun := TofuShop.make_sun()
			sun.shadow_enabled = false
			canvas.add_child(sun)
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.keep_aspect = Camera3D.KEEP_WIDTH
			if options.sheet == "outfits":
				var wanted: Array = KinuModel.PREMIUM_STYLES
				if options.group == "common":
					wanted = KinuModel.CUTE_STYLES.slice(0, 30)
				elif options.group == "rare":
					wanted = KinuModel.CUTE_STYLES.slice(30)
				var styles := catalog.outfits.filter(func(o: KinuOutfit) -> bool: return o.style in wanted)
				var page := int(options.page)
				styles = styles.slice(page*10, mini((page+1)*10, styles.size()))
				var look := catalog.flavours[0]
				for flavour in catalog.flavours+catalog.finishes:
					if flavour.id == options.look:
						look = flavour
				var shape: KinuShape = catalog.shapes[int(options.get("shape", "0"))]
				for i in styles.size():
					for view in 2:
						var model := KinuModel.build(shape, look, styles[i], ["calm", "happy"][view])
						model.position = Vector3((i % 5-2)*3.2, (1.5-floori(i/5.0)*2-view)*3.0, 0)
						model.rotation_degrees.y = -28 if view == 0 else 145
						canvas.add_child(model)
				camera.size = 17.0
				camera.position = Vector3(0, 2.0, 20)
				camera.rotation.x = -.1
			else:
				var boxes := catalog.decor_of("box").slice(12)
				for i in boxes.size():
					var box := TofuBox.new()
					box.decor = boxes[i]
					box.with_collision = false
					box.rotation.y = .6
					box.position = Vector3((i % 5-2)*6.2, (5.2 if floori(i/5.0) == 0 else 0.0)-2.2, 0)
					canvas.add_child(box)
					var label := Label3D.new()
					label.text = boxes[i].display_name
					label.font = NestTheme.font
					label.font_size = 48
					label.modulate = Color("493c43")
					label.pixel_size = .01
					label.position = box.position+Vector3(0, -1.2, 3)
					canvas.add_child(label)
				camera.size = 33.0
				camera.position = Vector3(0, 9, 20)
				camera.rotation.x = -.45
		"room":
			var shop := TofuShop.new()
			shop.decor = catalog.find_decor("room", options.room)
			canvas.add_child(shop)
			var box := TofuBox.new()
			box.decor = catalog.find_decor("box", options.get("box", "hinoki"))
			canvas.add_child(box)
			camera.fov = 52
			camera.keep_aspect = Camera3D.KEEP_WIDTH
			camera.far = 120
			var angle := float(options.get("angle", ".35"))
			var elevation := float(options.get("elevation", ".34"))
			camera.position = Vector3(sin(angle), 0, cos(angle))*8.0*cos(elevation)+Vector3.UP*(1.2+8.0*sin(elevation))
	canvas.add_child(camera)
	if options.sheet == "room":
		camera.look_at(Vector3(0, 1.12, 0))
	await get_tree().create_timer(1.2).timeout
	for i in 3:
		await get_tree().process_frame
	var name: String = options.sheet+"-"+str(options.group)+"-"+str(options.page)+str(options.get("shape", "")) if options.sheet != "room" else "room-"+options.room+"-"+str(options.get("angle", ".35"))
	canvas.get_texture().get_image().save_png(options.out.path_join(name+".png"))
	get_tree().quit()
