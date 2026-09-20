extends Node
## Plays a real, physics-driven run and records it as a video for social clips:
##   godot --path . res://tools/capture_clip.tscn --write-movie build/clip.avi -- room=shop box=hinoki
## Not --headless: movie mode still needs a rendering device.
## Unlike capture_play.gd, drops are loosely aimed (not gridded) and the box
## spins between them, so the pile grows the way a real player's would.

const SIZE := Vector2i(1080, 1920)
const DROPS := 16

## Roughly spread across the box, in drop order, with a little jitter added so
## it doesn't look choreographed. Corners and edges first, then the middle.
const SPOTS: Array = [
	Vector2(-.7, -.7), Vector2(.7, -.7), Vector2(.7, .7), Vector2(-.7, .7),
	Vector2(0, -.8), Vector2(.8, 0), Vector2(0, .8), Vector2(-.8, 0),
	Vector2(-.4, -.3), Vector2(.4, -.3), Vector2(.4, .3), Vector2(-.4, .3),
	Vector2(0, 0), Vector2(-.5, .15), Vector2(.5, -.15), Vector2(.15, .5),
]

var main: Node
var run: NestRun
var saved: Dictionary = {}
var options := {"room": "shop", "box": "hinoki", "out": "clip.png"}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 7
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and options.has(pair[0]):
			options[pair[0]] = pair[1]
	get_window().size = SIZE
	saved = Save.data.duplicate(true)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	Save.data.best = 9999
	Save.data.outfit = ""
	Save.data.room = options.room
	Save.data.box = options.box
	main._start()
	run = main.run
	run.message.disconnect(main._toast)
	# Flavour variety stays keyed off Save.data.best, so keep it high enough to spawn every
	# flavour (the catalog's last unlock is 70) without the HUD showing an absurd "Best 9,999".
	Save.data.best = 70
	main._hud_update()
	await get_tree().process_frame

	for i in DROPS:
		if not await _aim_ready():
			break
		# A gentle spin between drops so the box visibly turns, like a real hand would.
		run.orbit.orbit(rng.randf_range(-90, 90))
		for _frame in rng.randi_range(6, 14):
			await get_tree().process_frame
		if i == 9:
			run.next_special = "lucky"
		var spot: Vector2 = SPOTS[i%SPOTS.size()]+Vector2(rng.randf_range(-.08, .08), rng.randf_range(-.08, .08))
		run.orbit.lateral = spot.x
		run.orbit.depth = spot.y
		for _frame in 5:
			run.active.position = run.orbit.drop_position(run.drop_height)
			await get_tree().process_frame
		run.drop()
		await _settled()
		print("[clip] dropped %d, pile %d" % [i+1, run.score])

	# A slow turn over the finished pile to close the clip.
	await _rest()
	run.beam.hide()
	run.marker.hide()
	if run.active:
		run.active.hide()
	for _frame in 130:
		run.tumbles = 0
		run.orbit.orbit(9)
		await get_tree().process_frame
	Save.data = saved
	Save.persist()
	get_tree().quit()

func _aim_ready() -> bool:
	for _frame in 600:
		run.tumbles = 0
		if run.state == "over":
			return false
		if run.state == "aim" and run.active != null:
			return true
		await get_tree().process_frame
	return false

func _settled() -> void:
	for _frame in 600:
		run.tumbles = 0
		if run.state in ["aim", "over"]:
			return
		await get_tree().process_frame

func _rest() -> void:
	for _frame in 400:
		run.tumbles = 0
		var moving := false
		for body in run.bodies:
			if is_instance_valid(body) and not body.freeze and body.linear_velocity.length() > .05:
				moving = true
				break
		if not moving:
			return
		await get_tree().process_frame
