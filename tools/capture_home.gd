extends Node
## Home screen in both modes, plus the Modes sheet, on a throwaway save. -- out=<folder>
var options := {"out": "user://", "best": "30"}
var app: Node

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	get_window().size = Vector2i(393, 852)
	Save.save_path = "user://capture_home.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	Save.data.best = int(options.best)
	Save.data.tickets = 3
	Save.data.mode = "classic"
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await _settle(1.2)
	await shot("home-classic")
	var tower: Button = app.content.find_child("ModeTower", true, false)
	tower.emit_signal("pressed")
	await _settle(.35)
	await shot("home-panning")
	await _settle(1.6)
	await shot("home-tower")
	var about = app.content.find_child("AboutModes", true, false)
	if about is Button:
		about.emit_signal("pressed")
		await _settle(.8)
		await shot("home-modes-sheet")
	get_tree().quit()

func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(options.out).path_join(name+".png"))
