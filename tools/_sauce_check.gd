extends Node
## Forces each sauce onto a built-up pile and shoots before/after, so shrink and swell can be
## judged by eye rather than by reading the constants.

const SHOTS := "/tmp/sauce-check/"
const SPREAD: Array = [
	Vector2(-.75, -.75), Vector2(.75, -.75), Vector2(.75, .75), Vector2(-.75, .75),
	Vector2(0, -.85), Vector2(.85, 0), Vector2(0, .85), Vector2(-.85, 0),
	Vector2(-.45, -.4), Vector2(.45, -.4), Vector2(.45, .4), Vector2(-.45, .4),
]
var main: Node
var run: NestRun
var saved: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_window().size = Vector2i(430, 932)
	saved = Save.data.duplicate(true)
	Save.data.tutorial = true
	Save.data.mode = "classic"
	Save.data.best = 9999
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	run = main.run
	main._start()
	run.rng.seed = 4242
	run.begin()
	await get_tree().process_frame
	for i in 12:
		if not await _aim(): break
		var spot: Vector2 = SPREAD[i%SPREAD.size()]*.92
		run.orbit.lateral = spot.x
		run.orbit.depth = spot.y
		run.active.position = run.orbit.drop_position(run.drop_height)
		await get_tree().process_frame
		run.drop()
		await _settled()
	await _rest()
	await _shot("00-before")
	for sauce in ["nigari"]:
		if not await _aim(): break
		var sizes_before := _sizes()
		# Force the sauce into this turn rather than waiting on a 16% roll.
		run.next_sauce = sauce
		run.bodies.erase(run.active)
		run.active.queue_free()
		run.active = null
		run.state = "ready"
		run._spawn()
		await get_tree().process_frame
		assert(run.aim_mode == "bottle", "%s did not put the bottle in hand" % sauce)
		await _shot("%s-1-aimed" % sauce)
		run.orbit.lateral = 0.0
		run.orbit.depth = 0.0
		if is_instance_valid(run.bottle):
			run.bottle.position = run.orbit.drop_position(run.drop_height)+Vector3.UP*.3
		await get_tree().process_frame
		run.drop()
		await _settled()
		await _rest()
		var sizes_after := _sizes()
		var changed := 0
		for id in sizes_before:
			if sizes_after.has(id) and not is_equal_approx(sizes_before[id], sizes_after[id]):
				changed += 1
		print("[sauce] %-7s changed %d Kinu (pile %d, tumbles %d)" % [sauce, changed, run.score, run.tumbles])
		await _shot("%s-2-after" % sauce)
	print("SAUCE CHECK DONE")
	Save.data = saved
	Save.persist()
	get_tree().quit()

func _sizes() -> Dictionary:
	var out := {}
	for body in run.bodies:
		if is_instance_valid(body) and body.scored and not body.fallen:
			out[body.get_instance_id()] = body.body_scale
	return out

func _aim() -> bool:
	for _frame in 900:
		if run.state == "over": return false
		if run.state == "aim" and run.active != null: return true
		await get_tree().process_frame
	return false

func _settled() -> void:
	for _frame in 900:
		if run.state in ["aim", "over"]: return
		await get_tree().process_frame

func _rest() -> void:
	for _frame in 240:
		var moving := false
		for body in run.bodies:
			if is_instance_valid(body) and not body.freeze and body.linear_velocity.length() > .05:
				moving = true
				break
		if not moving: return
		await get_tree().process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOTS+label+".png")
