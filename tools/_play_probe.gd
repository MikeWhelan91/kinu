extends Node
## Plays real Classic runs to a genuine game over and reports what happened, so design talk can
## rest on the curve the game actually produces rather than on a reading of the source.
##
##   godot --path . res://tools/_play_probe.tscn -- runs=3
##
## Three aiming strategies play the same seeds: dead centre every time (no skill), a spread that
## lays a base then fills gaps (skill), and uniform random (anti-skill). If the three score alike,
## placement carries no decision weight — which is the thing under discussion.

const SIZE := Vector2i(430, 932)
const SHOTS := "/tmp/play-probe/"
## Box inner half is 1.8; capture_play uses .92 of that and calls a wider spread rim-risky.
const REACH := .92
const SPREAD: Array = [
	Vector2(-.75, -.75), Vector2(.75, -.75), Vector2(.75, .75), Vector2(-.75, .75),
	Vector2(0, -.85), Vector2(.85, 0), Vector2(0, .85), Vector2(-.85, 0),
	Vector2(-.45, -.4), Vector2(.45, -.4), Vector2(.45, .4), Vector2(-.45, .4),
	Vector2(0, 0), Vector2(-.6, .1), Vector2(.6, -.1), Vector2(.1, .55),
]

var main: Node
var run: NestRun
var saved: Dictionary = {}
var log_lines: Array[String] = []

func _ready() -> void:
	# One game per process: restarting the scene between runs proved unreliable, and a fresh
	# process is a cleaner control anyway.
	var strategy := "spread"
	var seed_value := 1000
	var cap := 150
	var play_mode := "classic"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("strategy="):
			strategy = arg.trim_prefix("strategy=")
		elif arg.begins_with("seed="):
			seed_value = int(arg.trim_prefix("seed="))
		elif arg.begins_with("cap="):
			cap = int(arg.trim_prefix("cap="))
		elif arg.begins_with("mode="):
			play_mode = arg.trim_prefix("mode=")
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_window().size = SIZE
	saved = Save.data.duplicate(true)
	Save.data.tutorial = true
	Save.data.mode = play_mode
	# A fresh save only unlocks the common creams; the real game's variety needs the full mix.
	Save.data.best = 9999
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	run = main.run
	var summary := await _play(strategy, seed_value, cap, true)
	print("[probe] %-6s seed %d -> score %d, boxes %d, drops %d, tumbles %d, %.0fs, capped %s" % [
		strategy, seed_value, summary.pile, summary.boxes, summary.drops, summary.tumbles, summary.time, summary.capped])
	print("[probe] sauces poured %d, Kinu resized %d" % [run.squirts_used, run.glazed])
	var file := FileAccess.open("%slog-%s-%d.txt" % [SHOTS, strategy, seed_value], FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()

	Save.data = saved
	Save.persist()
	get_tree().quit()

## One run, played to a real game over. Tumbles are never reset — that is the whole point.
func _play(strategy: String, seed_value: int, cap: int, shoot: bool) -> Dictionary:
	main._start()
	run.rng.seed = seed_value
	run.begin()
	await get_tree().process_frame
	var drops := 0
	var aim_rng := RandomNumberGenerator.new()
	aim_rng.seed = seed_value
	log_lines.append("\n--- %s seed %d ---" % [strategy, seed_value])
	while drops < cap:
		if not await _aim_ready():
			break
		var spot := _aim(strategy, drops, aim_rng)
		run.orbit.lateral = spot.x
		run.orbit.depth = spot.y
		run.active.position = run.orbit.drop_position(run.drop_height)
		var shape := str(run.active.shape.id)
		var special := str(run.active_sauce) if run.active_sauce != "" else str(run.next_special)
		await get_tree().process_frame
		run.drop()
		await _settled()
		drops += 1
		log_lines.append("%3d  %-6s %-7s score %3d  in-box %2d  boxes %d  tumbles %d" % [
			drops, shape, special, run.score, run.packed_count(), run.boxes_shipped, run.tumbles])
		# Lid prototype: close the box the moment it is worth closing. A greedier player would
		# push past the target, so this is the floor on what the loop produces, not the ceiling.
		if run.can_ship():
			await _rest()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s%s-%d-box%d.png" % [SHOTS, strategy, seed_value, run.boxes_shipped+1])
			run.ship_box()
			log_lines.append("     >>> shipped box %d" % (run.boxes_shipped))
			await _settled()
		if shoot and drops in [12, 30, 60]:
			await _rest()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s%s-%d-drop%02d.png" % [SHOTS, strategy, seed_value, drops])
		if run.state == "over":
			break
	var summary := {"pile": run.score, "drops": drops, "tumbles": run.tumbles, "time": run.run_time, "boxes": run.boxes_shipped, "capped": drops >= cap and run.state != "over"}
	# The run ends on its own summary screen; clear it before the next one starts.
	await get_tree().create_timer(.2).timeout
	return summary

func _aim(strategy: String, index: int, aim_rng: RandomNumberGenerator) -> Vector2:
	match strategy:
		"centre":
			return Vector2.ZERO
		"random":
			return Vector2(aim_rng.randf_range(-1, 1), aim_rng.randf_range(-1, 1))*REACH
	return SPREAD[index%SPREAD.size()]*REACH

func _aim_ready() -> bool:
	for _frame in 900:
		if run.state == "over":
			return false
		if run.state == "aim" and run.active != null:
			return true
		await get_tree().process_frame
	return false

func _settled() -> void:
	for _frame in 900:
		if run.state in ["aim", "over"]:
			return
		await get_tree().process_frame

func _rest() -> void:
	for _frame in 300:
		var moving := false
		for body in run.bodies:
			if is_instance_valid(body) and not body.freeze and body.linear_velocity.length() > .05:
				moving = true
				break
		if not moving:
			return
		await get_tree().process_frame
