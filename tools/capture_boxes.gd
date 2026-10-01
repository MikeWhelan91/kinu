extends Node
## Boots Kinu Toss and screenshots the box at a spread of box_index values directly, without
## having to actually clear each one first - much faster than playing through a real run.
var options := {"out": "user://"}
var app: Node

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	get_window().size = Vector2i(393, 852)
	Save.save_path = "user://capture_boxes.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	Save.data.best = 30
	Save.data.mode = "toss"
	Save.data.room = "shop"
	print("[capture] loading app")
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	print("[capture] app added, waiting 1s")
	await get_tree().create_timer(1.0).timeout
	print("[capture] starting run")
	app._start()
	var run: NestRun = app.run
	print("[capture] waiting for aim state, run=", run)
	await _until(func() -> bool: return is_instance_valid(run) and run.state == "aim")
	print("[capture] state=", run.state if is_instance_valid(run) else "run invalid", " toss=", run.toss if is_instance_valid(run) else null)
	var toss: TossPlay = run.toss
	var indices := [3, 6, 7]
	for i in indices:
		toss.rng.seed = 7
		if is_instance_valid(toss.box):
			toss.box.queue_free()
		toss.box_index = i
		toss._new_box()
		toss.focus = toss._wanted_focus()
		toss._place_camera(1.0)
		for f in 4:
			await get_tree().process_frame
		await get_tree().create_timer(.5).timeout
		for f in 4:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(str(options.out).path_join("toss-box-%02d.png" % i))
		print("captured box_index=", i, " quota=", toss.box_quota, " lidded=", toss.box.lidded, " holes=", toss.box.holes.size())
	# Hunt for a gauntlet box (16% chance at d>=9) by trying seeds until one turns up.
	toss.box_index = 10
	for seed_try in 60:
		if is_instance_valid(toss.box):
			toss.box.queue_free()
		toss.rng.seed = seed_try
		toss._new_box()
		if toss.box_quota == TossPlay.GAUNTLET_HOLES:
			toss.focus = toss._wanted_focus()
			toss._place_camera(1.0)
			for f in 4:
				await get_tree().process_frame
			await get_tree().create_timer(.5).timeout
			for f in 4:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.save_png(str(options.out).path_join("toss-box-gauntlet.png"))
			print("captured gauntlet at seed=", seed_try, " quota=", toss.box_quota, " holes=", toss.box.holes.size())
			break
	get_tree().quit()

func _until(done: Callable) -> void:
	for tick in 900:
		if done.call():
			return
		await get_tree().physics_frame
