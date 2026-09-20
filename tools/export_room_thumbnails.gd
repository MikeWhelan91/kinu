extends Node

const SIZE := Vector2i(320, 180)
const OUTPUT_DIR := "res://resources/kinu/thumbs"

func _ready() -> void:
	await get_tree().process_frame
	var catalog := load("res://resources/kinu/catalog.tres") as KinuCatalog
	for room in catalog.decor_of("room"):
		var viewport := SubViewport.new()
		viewport.size = SIZE
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_tree().root.add_child(viewport)
		var swatch := DecorPreview.room_swatch(room, SIZE)
		viewport.add_child(swatch)
		await get_tree().process_frame
		await get_tree().process_frame
		var image := viewport.get_texture().get_image()
		var error := image.save_png("%s/room_%s.png" % [OUTPUT_DIR, room.id])
		if error != OK:
			push_error("Could not save thumbnail for %s" % room.id)
		viewport.queue_free()
	get_tree().quit()
