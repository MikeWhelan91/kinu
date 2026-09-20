extends Node

func _ready() -> void:
	Save.save_path = "user://daily_visual_check.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	get_window().size = Vector2i(393, 852)
	var app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(2).timeout
	DailyCalendar.show(app)
	await get_tree().create_timer(.7).timeout
	await shot("daily-ready")
	var sheet = app.modal.find_child("RewardSheet", true, false)
	assert(sheet.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x)
	var rng := RandomNumberGenerator.new()
	DailyCalendar.claim(app.run.catalog, rng)
	DailyCalendar.show(app)
	await get_tree().create_timer(.7).timeout
	await shot("daily-claimed")
	Save.data.daily_calendar = {"last_day": DailyCalendar._yesterday(), "streak": 6}
	get_window().size = Vector2i(320, 568)
	await get_tree().process_frame
	DailyCalendar.show(app)
	await get_tree().create_timer(.5).timeout
	await shot("daily-day7-small")
	sheet = app.modal.find_child("RewardSheet", true, false)
	assert(sheet.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x)
	app._close_modal()
	app.run.begin()
	await get_tree().create_timer(1).timeout
	app.run.toggle_bottle()
	await get_tree().process_frame
	assert(app.run.marker.get_child_count() == 1)
	assert(app.run.marker.get_child(0).name == "SauceShadow")
	await shot("sauce-shadow")
	app.run.toggle_bottle()
	await get_tree().process_frame
	assert(app.run.marker.get_child(0).name == "KinuGhost")
	app.run.toggle_bottle()
	app.run.drop()
	await get_tree().physics_frame
	assert(not app.run.marker.visible)
	print("DAILY AND SAUCE CHECKS PASSED")
	get_tree().quit()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/"+label+".png")
