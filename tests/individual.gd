extends Node
func _ready() -> void:
	Save.save_path = "user://individual_test.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	var app: Node = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	for i in app.run.catalog.shapes.size():
		var shape: KinuShape = app.run.catalog.shapes[i]
		print("START ",shape.id)
		app._start()
		var run: NestRun = app.run
		run.next_shape = shape
		run.next_flavour = run.catalog.flavours[i]
		run.bodies.erase(run.active)
		run.active.queue_free()
		run.active = null
		run._spawn()
		run.orbit.lateral = 0
		run.orbit.depth = 0
		run.drop()
		for tick in 330:
			await get_tree().physics_frame
		print("END ", shape.id, " ", run.placed)
	for i in 4:
		print("NAV ",i)
		app._home()
		app._collection()
		await get_tree().process_frame
		app._flavour_detail(app.run.catalog.flavours[0],true)
		await get_tree().process_frame
		app._close_modal()
		app._settings()
		await get_tree().process_frame
		app._credits()
		await get_tree().process_frame
	Sound.shutdown()
	app.queue_free()
	await get_tree().process_frame
	OS.delay_msec(180)
	get_tree().quit()
