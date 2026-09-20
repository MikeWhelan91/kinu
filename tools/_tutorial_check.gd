extends Node
## Walks the first-run guide end to end, doing what each step asks, and shoots every card. The
## last two lessons need a Sticky Kinu and a Nigari bottle to actually turn up, which is the part
## worth proving.

const SHOTS := "/tmp/tutorial-check/"
var main: Node
var run: NestRun
var saved: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_window().size = Vector2i(430, 932)
	saved = Save.data.duplicate(true)
	Save.data.tutorial = false
	Save.data.mode = "classic"
	Save.data.controls = "classic"
	Save.data.best = 9999
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	run = main.run
	main._start()
	run.rng.seed = 99
	await get_tree().process_frame
	assert(main.tutorial_step == 0, "the guide did not start")
	var guard := 0
	var seen: Array[int] = []
	var squirts_at_lesson := 0
	while main.tutorial_step >= 0 and main.tutorial_step < 6 and guard < 80:
		guard += 1
		var step: int = main.tutorial_step
		if not await _aim():
			break
		if not seen.has(step):
			seen.append(step)
			await _rest()
			await _shot("step%d" % step)
			var in_hand := "bottle" if run.aim_mode == "bottle" else (run.active.special if run.active.special != "" else "kinu")
			print("[tut] step %d — in hand: %-8s squirts %d  next: %s" % [step, in_hand, run.squirts, run.next_special if run.next_special != "" else "kinu"])
			# The whole point of the fix: a card about a thing only shows once you hold that thing.
			if step == 4:
				assert(run.active.special == "sticky", "the Sticky card showed while holding %s" % in_hand)
			if step == 5:
				assert(run.squirts > 0, "the Nigari card showed with no squirt to spend")
				squirts_at_lesson = run.squirts
		match step:
			5:
				# The lesson is the tap: pick the bottle up, aim it at the pile, let go.
				run.toggle_bottle()
				await get_tree().process_frame
				assert(run.aim_mode == "bottle", "tapping the bottle did not pick it up")
				run.orbit.lateral = 0.0
				run.orbit.depth = 0.0
				await get_tree().process_frame
				run.drop()
				await _settled()
				continue
			2:
				# The spin lesson wants the box turned, not another Kinu dropped.
				run.orbit.target_angle += 1.2
				run.action_done.emit("spin")
				await get_tree().process_frame
				continue
			_:
				run.orbit.lateral = sin(guard*1.7)*.7
				run.orbit.depth = cos(guard*1.3)*.7
				run.active.position = run.orbit.drop_position(run.drop_height)
				run.action_done.emit("aim")
				await get_tree().process_frame
				run.drop()
				await _settled()
	await _rest()
	await _shot("final")
	var reached: int = main.tutorial_step
	print("[tut] reached step %d after %d turns; steps seen %s" % [reached, guard, str(seen)])
	print("[tut] squirts at the lesson %d, after it %d" % [squirts_at_lesson, run.squirts])
	assert(run.squirts >= squirts_at_lesson, "the practice squirt cost a real charge")
	assert(seen.has(4), "the Sticky Kinu lesson never came up")
	assert(seen.has(5), "the Nigari lesson never came up")
	print("TUTORIAL CHECK DONE")
	Save.data = saved
	Save.persist()
	get_tree().quit()

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
	for _frame in 200:
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
