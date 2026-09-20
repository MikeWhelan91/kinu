extends Node
## Screenshots the mode picker, Tower and Lunch Rush on a throwaway save, into out= (a folder).
var options := {"out": "user://"}
var app: Node

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	get_window().size = Vector2i(393, 852)
	Save.save_path = "user://capture_modes.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	Save.data.best = 30
	Save.data.mode = "tower"
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(1.0).timeout
	await shot("modes-home")
	app._start()
	var run: NestRun = app.run
	for turn in 9:
		await _drop(run, Vector2(sin(turn)*.1, cos(turn)*.1))
	await shot("modes-tower")
	run.end()
	await get_tree().create_timer(1.0).timeout
	await shot("modes-tower-results")
	Save.data.mode = "rush"
	app._start()
	var spots := [Vector2(-.9, -.9), Vector2(.9, -.9), Vector2(.9, .9), Vector2(-.9, .9), Vector2(0, -.9), Vector2(.9, 0)]
	for turn in 6:
		await _drop(run, spots[turn])
	await shot("modes-rush")
	get_tree().quit()

func _drop(run: NestRun, spot: Vector2) -> void:
	for tick in 300:
		if run.state == "aim":
			break
		await get_tree().physics_frame
	run.orbit.lateral = spot.x
	run.orbit.depth = spot.y
	run.drop()
	for tick in 300:
		await get_tree().physics_frame
		if run.state != "settle":
			break

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(options.out).path_join(name+".png"))
