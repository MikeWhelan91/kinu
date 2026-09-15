extends Node3D
## Renders the app icon (1024px) and boot splash (192px) from the real Kinu model.

func _ready() -> void:
	get_window().size = Vector2i(1024, 1024)
	var env := WorldEnvironment.new()
	env.environment = TofuShop.make_environment()
	env.environment.background_color = TofuShop.INDIGO
	add_child(env)
	var sun := TofuShop.make_sun()
	sun.shadow_enabled = false
	add_child(sun)
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var kinu := KinuModel.build(catalog.shapes[0], catalog.flavours[0], null, "happy")
	kinu.rotation.y = -.42
	add_child(kinu)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.85
	camera.position = Vector3(0, .95, 3.2)
	camera.rotation.x = -.3
	add_child(camera)
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png("res://assets/icons/app_icon.png")
	image.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	image.save_png("res://assets/icons/splash.png")
	get_tree().quit()
