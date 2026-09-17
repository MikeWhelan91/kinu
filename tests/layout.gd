extends Node
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		print("FAIL ",text)
func _ready() -> void:
	Save.save_path = "user://layout_test.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	var app: Node = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	for dimensions in [Vector2i(360,640),Vector2i(390,844),Vector2i(430,932)]:
		get_window().size = dimensions
		for i in 3:
			await get_tree().process_frame
		app._start()
		for i in 3:
			await get_tree().process_frame
		# Conservative simulated Dynamic Island and home-indicator insets.
		app.content.offset_top = 90
		app.content.offset_bottom = -48
		await get_tree().process_frame
		var rect := get_viewport().get_visible_rect()
		for label in [app.score_label,app.best_label,app.height_label]:
			check(rect.encloses(label.get_global_rect()),"HUD text visible "+str(dimensions))
		app.safe_top = 90
		app.safe_bottom = 48
		app._pause()
		for i in 3:
			await get_tree().process_frame
		for button in app.modal.find_children("*","Button",true,false):
			var bounds: Rect2 = button.get_global_rect()
			check(rect.encloses(bounds) and bounds.position.y >= 90 and bounds.end.y <= rect.size.y-48,"pause action inside safe area: "+button.text+" "+str(dimensions))
		app._close_modal()
		get_tree().paused = false
		var run: NestRun = app.run
		for height in [0.5,3.0,7.0]:
			run.orbit.tower_top = height
			run.orbit.focus_height = maxf(OrbitController.BASE_FOCUS,height+.1)
			var drop := maxf(3.0,height+1.4)
			for angle in [0.,PI/2,PI,PI*1.5]:
				run.orbit.angle = angle
				run.orbit.target_angle = angle
				run.orbit.spin_velocity = 0
				run.orbit.update(1)
				for offset in [Vector2(0,0),Vector2(OrbitController.PLACEMENT_RADIUS,0),Vector2(0,OrbitController.PLACEMENT_RADIUS),Vector2(0,-OrbitController.PLACEMENT_RADIUS)]:
					run.orbit.lateral = offset.x
					run.orbit.depth = offset.y
					var point := run.orbit.camera.unproject_position(run.orbit.drop_position(drop))
					check(rect.has_point(point),"held Kinu visible "+str(dimensions)+" h"+str(height))
					check(point.y>150 and point.y<rect.size.y-120,"held Kinu between HUD and hint "+str(dimensions)+" h"+str(height)+" "+str(offset))
				var rim := run.orbit.camera.unproject_position(run.orbit.right()*TofuBox.RIM_RADIUS+Vector3.UP*TofuBox.RIM_HEIGHT)
				check(rim.x>0 and rim.x<rect.size.x,"nest width remains visible")
	print("LAYOUT CHECKS=",checks," FAILURES=",failures.size())
	var file := FileAccess.open("res://docs/layout-results.txt",FileAccess.WRITE)
	file.store_string("360x640, 390x844, 430x932; simulated 90/48 logical-pixel safe insets; 4 compass bearings; 3 pile heights.\nChecks: %d\nFailures: %d\n"%[checks,failures.size()]+"\n".join(failures))
	file.close()
	Sound.shutdown()
	app.queue_free()
	await get_tree().process_frame
	OS.delay_msec(180)
	get_tree().quit(0 if failures.is_empty() else 1)
