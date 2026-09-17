extends Node
## Plays a run and screenshots it, for the App Store screenshot studio:
##   godot --path . res://tools/capture_play.tscn
##   godot --path . res://tools/capture_play.tscn -- room=sakura_street box=sakura mode=aim drops=6 out=play-sakura.png
##   … lang=ja (or ko, zh_TW) shoots the HUD in that language.
##
## mode=packed (default) fills the box and captures the pile with nothing else on
## screen. mode=aim drops a few, then captures mid-turn with the next Kinu hovering
## on its beam, which is the "drag, spin, drop" moment. mode=scene is a turned,
## uncluttered view of the room and a part-filled box, for the rooms collage.
## room and box take catalog ids.
## Not --headless: that has no rendering device and the capture comes back blank.
##
## The point is a box packed WIDE. Left to itself the drop point barely moves and
## the pile grows as a column, which reads as a stacking game — the wrong game.
## So each Kinu is aimed at a spread of spots across the box footprint, and the
## tumble counter is held at zero so the run reaches a full box.

const OUT := "/Users/mike/Dev/Apps/critternest/app-store-screenshots/public/screenshots/"
## Matches the 393 × 852 captures already in docs/, at 1.4× for a sharper frame
## inside the studio's device mockup.
const SIZE := Vector2i(550, 1192)
const DROPS := 22
## Box inner half is 1.8. Kept deliberately tight: a wider spread lands pieces on
## the rim, and one bounce onto the counter is the shot ruined.
const REACH := .92

## Aim spots, in the order they are dropped: corners and edges first so the base
## covers the floor, then inner spots to fill the gaps, then the middle.
const SPOTS: Array = [
	Vector2(-.75, -.75), Vector2(.75, -.75), Vector2(.75, .75), Vector2(-.75, .75),
	Vector2(0, -.85), Vector2(.85, 0), Vector2(0, .85), Vector2(-.85, 0),
	Vector2(-.45, -.4), Vector2(.45, -.4), Vector2(.45, .4), Vector2(-.45, .4),
	Vector2(0, 0), Vector2(-.6, .1), Vector2(.6, -.1), Vector2(.1, .55),
]

var main: Node
var run: NestRun
## The tool unlocks every flavour so the pile is not all the same cream, and
## settling discoveries writes to the save. The player's own save is snapshotted
## here and put back before the tool exits.
var saved: Dictionary = {}
var options := {"room": "shop", "box": "hinoki", "mode": "packed", "drops": str(DROPS), "out": "packed.png", "lang": "en"}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and options.has(pair[0]):
			options[pair[0]] = pair[1]
	var aim: bool = options.mode == "aim"
	var scene: bool = options.mode == "scene"
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = SIZE
	saved = Save.data.duplicate(true)
	# The game reads the language when the main scene starts, so it is set first.
	Save.data.language = options.lang
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# Every flavour in the mix: a fresh save only has the common creams unlocked,
	# and a box of fourteen identical blocks says nothing about the game.
	Save.data.best = 9999
	Save.data.room = options.room
	Save.data.box = options.box
	main._start()
	run = main.run
	# No toasts over the pile, and no tutorial card.
	run.message.disconnect(main._toast)
	await get_tree().process_frame

	for i in int(options.drops):
		if not await _aim_ready():
			break
		var spot: Vector2 = SPOTS[i%SPOTS.size()]*REACH
		run.orbit.lateral = spot.x
		run.orbit.depth = spot.y
		run.active.position = run.orbit.drop_position(run.drop_height)
		await get_tree().process_frame
		run.drop()
		await _settled()
		print("[play] dropped %d, pile %d" % [i+1, run.score])

	# Let the last one come to rest, then clear everything that belongs to the
	# next turn rather than to the pile: the aiming beam, the drop marker, the
	# Kinu hovering ready to drop, and anything that rolled onto the counter.
	await _rest()
	for body in run.bodies:
		if is_instance_valid(body) and body != run.active and (body.fallen or not body.scored):
			body.hide()
	if aim:
		# Mid-turn: the next Kinu hovers off-centre on its beam over the pile, and
		# the box is turned a little so the room reads from a fresh angle.
		await _aim_ready()
		run.orbit.target_angle = .55
		run.orbit.lateral = .55
		run.orbit.depth = -.25
		for _frame in 90:
			run.active.position = run.orbit.drop_position(run.drop_height)
			await get_tree().process_frame
	else:
		if scene:
			run.orbit.target_angle = .55
		run.beam.hide()
		run.marker.hide()
		if run.active:
			run.active.hide()
		for _frame in 90:
			await get_tree().process_frame
	run.tumbles = 0
	# The unlock-everything best would otherwise read "Best 9,999" in the HUD.
	Save.data.best = 38
	main._hud_update()
	await _rest()

	var path: String = OUT+str(options.out)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("[play] saved ", path, " pile ", run.score, " tumbles ", run.tumbles)
	Save.data = saved
	Save.persist()
	get_tree().quit()

## Waits for the run to be ready for the next drop. The run is never allowed to
## end: a tumble mid-shot would leave a half-empty box.
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

## Waits until nothing is moving much, so the pile is not caught mid-wobble.
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
