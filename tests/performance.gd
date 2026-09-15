extends Node
func _ready() -> void:
	Save.save_path = "user://performance_test.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	var app: Node = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	app._start()
	var run: NestRun = app.run
	run._clear()
	# "over" skips fall detection while bodies keep simulating.
	run.state = "over"
	run.beam.hide()
	run.marker.hide()
	run.orbit.tower_top = 3
	for i in 60:
		var body := run.make_body(run.catalog.shapes[i%5],run.catalog.flavours[i%6])
		body.position = Vector3((i%4-1.5)*1.3,.9+floor(i/16.0)*1.4,(int(i/4)%4-1.5)*1.3)
	await get_tree().create_timer(1.0).timeout
	var samples: Array[float] = []
	var physics_samples: Array[float] = []
	var peak := 0
	var min_bodies := 1000
	var start := Time.get_ticks_usec()
	var last := start
	var draw_calls := 0
	while Time.get_ticks_usec()-start<8000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-last)/1000.0)
		last = now
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		peak = maxi(peak,run.bodies.size())
		min_bodies = mini(min_bodies,run.bodies.size())
		draw_calls = maxi(draw_calls,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/crowded.png")
	var mean := 0.0
	var physics_mean := 0.0
	for sample in samples:
		mean += sample
	for sample in physics_samples:
		physics_mean += sample
	mean /= samples.size()
	physics_mean /= physics_samples.size()
	samples.sort()
	var text := "Renderer: Compatibility / Apple M4 desktop (not an iPhone benchmark)\nInitial rigid bodies: 60\nBodies during measurement: %d–%d\nMeasured frames: %d\nMean frame time: %.2f ms\n95th percentile frame time: %.2f ms\nMean physics time: %.2f ms\nPeak draw calls: %d\n"%[min_bodies,peak,samples.size(),mean,samples[int(samples.size()*.95)],physics_mean,draw_calls]
	print(text)
	var file := FileAccess.open("res://docs/performance-results.txt",FileAccess.WRITE)
	file.store_string(text)
	file.close()
	Sound.shutdown()
	app.queue_free()
	await get_tree().create_timer(.2).timeout
	get_tree().quit()
