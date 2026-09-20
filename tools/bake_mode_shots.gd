extends Node
## Renders the home-screen set-up for each mode, with no interface over it, into the previews the
## Modes sheet shows. Run after changing the tableaux or the room:
##
##   godot --path . tools/bake_mode_shots.tscn
##
## Writes res://resources/modes/<mode>.png. `out=` overrides the folder.
var options := {"out": "res://resources/modes"}
var app: Node

## Portrait, matching the thumbnail the Modes sheet shows. The camera keeps a fixed horizontal
## FOV, so a wide crop would cut the top off the tower; a tall one fits the whole set-up in.
const SHOT_SIZE := Vector2i(480, 640)
const SAVE_SIZE := Vector2i(312, 416)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	DirAccess.make_dir_recursive_absolute(str(options.out))
	get_window().size = SHOT_SIZE
	# A throwaway save, so the previews never show one player's outfits or unlocks.
	Save.save_path = "user://bake_mode_shots.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	Save.data.best = 999
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(1.0).timeout
	app.canvas.visible = false
	for mode in ["classic", "tower"]:
		app.run.focus_mode(mode, true)
		# One settled frame after the snap, so no set-up is caught mid-lift.
		await get_tree().create_timer(.6).timeout
		await _shot(mode)
	get_tree().quit()

func _shot(mode: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(SAVE_SIZE.x, SAVE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(str(options.out).path_join(mode+".png"))
	print("baked ", mode)
