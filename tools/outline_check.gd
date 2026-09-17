extends Node
## Renders the home-screen pile wearing one outfit, cropped to the box, to check that neighbouring
## Kinu keep the ink line between them:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/outline_check.tscn -- ghost out.png
## Not --headless: that has no rendering device and the capture comes back blank.
## Changes the outfit in memory only, and puts the player's save back before quitting.

const SIZE := Vector2i(540, 960)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var outfit := args[0] if args.size() > 0 else "ghost"
	var path := args[1] if args.size() > 1 else "outline-%s.png"%outfit
	get_window().size = Vector2i(SIZE.x, int(args[3])) if args.size() > 3 else SIZE
	var saved: Dictionary = Save.data.duplicate(true)
	Save.data.outfit = outfit
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if not (args.size() > 2 and args[2] == "full"):
		image = image.get_region(Rect2i(60, 300, 420, 300))
	image.save_png(path)
	print("[outline] ", outfit, " -> ", path)
	Save.data = saved
	Save.persist()
	get_tree().quit()
