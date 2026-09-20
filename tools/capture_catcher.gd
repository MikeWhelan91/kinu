extends Node
## Screenshots the Kinu Catcher at each stage, into out= (a folder):
##   godot --path . res://tools/capture_catcher.tscn -- out=/tmp/catcher prize=outfit:kitsune
## The player's save is left untouched: the tool plays on a throwaway save file.
var options := {"out": "user://", "prize": "outfit:kitsune", "size": "393x852", "lang": "en"}
var app: Node

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var parts: PackedStringArray = options.size.split("x")
	get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	Save.save_path = "user://capture_catcher.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	Save.data.beans = 5000
	Save.data.best = 40
	Save.data.language = options.lang
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(1.0).timeout
	await shot("home")
	KinuCatcherScreen.show(app)
	await get_tree().create_timer(2.5).timeout
	await shot("catcher-idle")
	KinuCatcherScreen.machine.yaw_goal = 1.05
	KinuCatcherScreen.machine.pitch_goal = .22
	await get_tree().create_timer(.8).timeout
	await shot("catcher-turned")
	KinuCatcherScreen.machine.yaw_goal = -1.05
	KinuCatcherScreen.machine.pitch_goal = -.12
	await get_tree().create_timer(.8).timeout
	await shot("catcher-behind")
	Save.data.controls = "claw"
	KinuCatcherScreen.show(app)
	await get_tree().create_timer(2.0).timeout
	await shot("catcher-claw-controls")
	KinuCatcherScreen.refresh(app)
	var prize := KinuCatcher.play(app.run.catalog, KinuCatcherScreen.machine.rng)
	# Swap the drawn prize for the one being photographed.
	var wanted: PackedStringArray = options.prize.split(":")
	if wanted[0] == "beans":
		prize = {"kind": "beans", "id": "", "amount": int(wanted[1]), "chance": 0.5, "lucky": false, "free": false}
	else:
		for entry in KinuCatcher.table(app.run.catalog):
			if entry.kind == wanted[0] and entry.get("id", "") == wanted[1]:
				var item := KinuCatcher.item_of(app.run.catalog, entry)
				prize = {"kind": wanted[0], "id": wanted[1], "amount": 0, "chance": .3, "lucky": false, "free": false, "item": item, "crane_only": item.crane_only}
	KinuCatcherScreen.machine.begin_aim()
	for i in 30:
		KinuCatcherScreen.machine.target += Vector2(.03, .02)
		await get_tree().process_frame
	await shot("catcher-aim")
	KinuCatcherScreen.machine.drop()
	await get_tree().create_timer(1.35).timeout
	await shot("catcher-grab")
	await get_tree().create_timer(1.3).timeout
	await shot("catcher-lift")
	await KinuCatcherScreen.machine.delivered
	var reveal := CapsuleReveal.open(app, prize)
	await get_tree().create_timer(.8).timeout
	await shot("reveal-capsule")
	for i in 3:
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		reveal._gui_input(tap)
		await get_tree().create_timer(.25).timeout
	await get_tree().create_timer(1.2).timeout
	await shot("reveal-prize-"+options.prize.replace(":", "-"))
	reveal._close("continue")
	KinuCatcherScreen.odds_page(app)
	await get_tree().create_timer(.6).timeout
	await shot("odds")
	app._close_modal()
	get_tree().quit()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(options.out).path_join(name+".png"))
