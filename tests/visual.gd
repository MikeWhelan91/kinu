extends Node
var app: Node
func _ready() -> void:
	Save.save_path = "user://visual_test.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(1).timeout
	var mode := "home"
	var suffix := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("aspect="):
			var parts := arg.trim_prefix("aspect=").split("x")
			get_window().size = Vector2i(int(parts[0]),int(parts[1]))
			suffix = "-"+arg.trim_prefix("aspect=")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("screen="):
			mode = arg.trim_prefix("screen=")
	match mode:
		"play": app._start()
		"toast":
			app._start()
			await get_tree().create_timer(.2).timeout
			app._toast("Oh no! Kinu tumbled off!", Color("e0463a"))
		"tall":
			Save.data.best_height = 7.5
			app._start()
			var run: NestRun = app.run
			var ids := [1,0,0,3,0,4,0,1,0,0,3,0]
			for i in ids.size():
				var body := run.make_body(run.catalog.shapes[ids[i]],run.catalog.flavours[i%6])
				body.position = Vector3(sin(i*1.9)*.15,.1+i*.78,cos(i*1.9)*.15) if i>2 else Vector3(sin(i*2.1)*.8,.62,cos(i*2.1)*.8)
				body.rotation.y = i*.8
				body.scored = true
				body.grip()
			run.placed = ids.size()
			run.score = ids.size()
			run.bodies.erase(run.active)
			run.active.queue_free()
			run.active = null
			run._spawn()
			run.orbit.lateral = .9
			await get_tree().create_timer(2.5).timeout
		"tower":
			app._start()
			var run: NestRun = app.run
			run.rng.seed = 12
			for turn in 14:
				run.orbit.target_angle = turn*2.39996
				await get_tree().create_timer(.4).timeout
				var total := Vector3.ZERO
				var weight := 0.0
				for body in run.bodies:
					if body.scored:
						total += body.position*body.mass
						weight += body.mass
				var highest := Vector3.ZERO
				for body in run.bodies:
					if body.scored and body.position.y > highest.y:
						highest = body.position
				var aim := highest*Vector3(.5,0,.5)+Vector3(sin(turn*1.3),0,cos(turn*1.7))*(.9 if turn<6 else .15)
				run.orbit.lateral = aim.dot(run.orbit.right())
				run.orbit.depth = aim.dot(run.orbit.toward_camera())
				run.drop()
				while run.state == "settle":
					await get_tree().physics_frame
				if run.state != "aim":
					break
			run.orbit.lateral = .6
			run.orbit.depth = 0.0
			await get_tree().create_timer(1.5).timeout
		"tutorial":
			Save.data.tutorial = false
			app._start()
		"collection":
			Save.data.discovered = ["silken","fried","sesame","matcha"]
			app._collection()
		"settings": app._settings()
		"results":
			app.initial_best = 0
			app._results({"score":124,"placed":23,"height":6.4})
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/"+mode+suffix+".png")
	print("CAPTURE ",mode," ",get_viewport().get_visible_rect())
	app.queue_free()
	await get_tree().process_frame
	KinuModel.clear_cache()
	Sound.shutdown()
	await get_tree().create_timer(.15).timeout
	get_tree().quit()
