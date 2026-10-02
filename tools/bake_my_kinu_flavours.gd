extends Node
## Run with a renderer after changing a flavour's appearance:
##   Godot --path . res://tools/bake_my_kinu_flavours.tscn
const OUT_DIR := "res://resources/kinu/thumbs"
const SIZE := Vector2i(192, 152)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	for flavour in catalog.flavours:
		if not await _save_preview(catalog.shapes[0], flavour, true, "flavour_%s.png" % flavour.id):
			get_tree().quit(1)
			return
	if not await _save_preview(catalog.shapes[0], catalog.flavours[0], false, "flavour_locked.png"):
		get_tree().quit(1)
		return
	print("Baked %d My Kinu flavour thumbnails" % (catalog.flavours.size() + 1))
	get_tree().quit()

func _save_preview(shape: KinuShape, flavour: KinuFlavour, discovered: bool, filename: String) -> bool:
	var preview := KinuPreview.new()
	preview.setup(shape, flavour, discovered, SIZE, "calm")
	preview.fit_model(1.04)
	add_child(preview)
	var viewport := preview.get_child(0) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	var image := viewport.get_texture().get_image()
	var error := image.save_png(OUT_DIR.path_join(filename))
	preview.queue_free()
	if error != OK:
		push_error("Could not save %s" % filename)
	return error == OK
