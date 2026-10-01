extends Node
## Plays Kinu Toss on a throwaway save and screenshots it, into out= (a folder). room= picks the
## room to play in; shots=home,aim,flight,landed picks which to take; throws= how many to make.
var options := {"out": "user://", "room": "shop", "box": "", "throws": "6", "shots": "home,aim,flight,landed"}
var app: Node

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	get_window().size = Vector2i(393, 852)
	Save.save_path = "user://capture_toss.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	Save.data.best = 30
	Save.data.mode = "toss"
	Save.data.room = options.room
	if str(options.box) != "":
		Save.data.box = options.box
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(1.2).timeout
	var shots: PackedStringArray = str(options.shots).split(",")
	if "home" in shots:
		await shot("toss-home-"+options.room)
	app._start()
	var run: NestRun = app.run
	await _until(func() -> bool: return run.state == "aim")
	await get_tree().create_timer(.6).timeout
	if "aim" in shots:
		await shot("toss-aim-"+options.room)
	var seen_box := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for turn in int(options.throws):
		await _until(func() -> bool: return run.state == "aim" or run.state == "over")
		if run.state == "over":
			break
		var toss := run.toss
		# Aim at the box: an angle and power found by trying, plus a little human error.
		var target := _target(toss)
		var solved := _aim_and_power(toss, target)
		var aim_t: float = clampf(solved.aim_t+rng.randf_range(-.03, .03), -1, 1)
		var loft_t: float = clampf(solved.loft_t+rng.randf_range(-.03, .03), -1, 1)
		var power: float = clampf(solved.power+rng.randf_range(-.12, .12), 0, 1)
		toss.set_aim(aim_t, loft_t)
		toss.throw(power)
		if "flight" in shots and turn == 0:
			await get_tree().create_timer(.45).timeout
			await shot("toss-flight-"+options.room)
		var flier: KinuBody = toss.flying
		for tick in 400:
			if run.state != "settle":
				break
			if tick % 6 == 0 and is_instance_valid(flier) and options.get("trace", "") != "":
				print("  t=%.2f pos=%s vel=%s" % [tick/60.0, flier.position, flier.linear_velocity])
			await get_tree().physics_frame
		print("  power=%.2f box=%s end=%s" % [power, toss.box.position, flier.position if is_instance_valid(flier) else "freed"])
		if "boxes" in shots and toss.box_index != seen_box:
			seen_box = toss.box_index
			await get_tree().create_timer(.4).timeout
			await shot("toss-box%d-%s" % [seen_box, options.room])
		print("throw ", turn, " box ", toss.box_index, " score ", run.score, " misses ", run.tumbles, " dist ", toss.distance_cm())
	if "results" in shots:
		for tick in 900:
			if app.page == "results":
				break
			await get_tree().physics_frame
		await get_tree().create_timer(1.8).timeout
		await shot("toss-results-"+options.room)
	if "landed" in shots:
		await get_tree().create_timer(.3).timeout
		await shot("toss-landed-"+options.room)
	get_tree().quit()

## The flick speed that lands about on the middle of the box, from the launch ballistics.
## Where the bot aims: the biggest hole in the lid, or the middle of an open box.
func _target(toss: TossPlay) -> Vector3:
	var box := toss.box
	if not box.lidded or box.holes.is_empty():
		return box.lid_center()
	var best: Dictionary = box.holes[0]
	for hole in box.holes:
		if float(hole.half) > float(best.half):
			best = hole
	var c: Vector2 = best.center
	return box.board.to_global(Vector3(c.x, box.lid_top(), c.y))

## The aim box's own -1..1 x/y that points straight at `target`: since the real game now maps the
## stick directly onto the box's own local space for anything inside the box (only past its lip
## does the easing kick in), aiming the bot at a real in-box target is just the plain inverse of
## that mapping.
func _aim_and_power(toss: TossPlay, target: Vector3) -> Dictionary:
	var box := toss.box
	var local: Vector3 = box.local(target)
	var aim_t := clampf(local.x/maxf(box.half_x-TossPlay.AIM_MARGIN, .01), -1, 1)
	var depth := maxf(box.half_z-TossPlay.AIM_MARGIN, .01)/TossPlay.AIM_DEPTH_FRACTION
	var loft_t := clampf(-local.z/depth, -1, 1)
	return {"aim_t": aim_t, "loft_t": loft_t, "power": 1.0}

func _until(done: Callable) -> void:
	for tick in 900:
		if done.call():
			return
		await get_tree().physics_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(options.out).path_join(name+".png"))
