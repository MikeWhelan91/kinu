extends Node
## Starts a run on the claw controls, drives both sticks with two simultaneous touches, taps Drop,
## and screenshots the play screen:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/claw_check.tscn -- right out.png
## Changes settings in memory only, and puts the player's save back before quitting.

const SIZE := Vector2i(540, 960)

var main: Node
var failures := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var hand := args[0] if args.size() > 0 else "right"
	var path := args[1] if args.size() > 1 else "claw-%s.png"%hand
	get_window().size = SIZE
	var saved: Dictionary = Save.data.duplicate(true)
	Save.data.controls = "claw"
	Save.data.claw_hand = hand
	Save.data.tutorial = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	main._start()
	var run: NestRun = main.run
	for i in 120:
		if run.state == "aim":
			break
		await get_tree().process_frame
	await _frames(5)
	var sticks: Array[Joystick] = []
	_find_sticks(main, sticks)
	_check(sticks.size() == 2, "two sticks built")
	var move: Joystick = sticks[0] if sticks[0].kind == "move" else sticks[1]
	var spin: Joystick = sticks[1] if move == sticks[0] else sticks[0]
	_check(move.get_global_rect().position.y < spin.get_global_rect().position.y, "move stick sits above spin stick")
	var on_right := move.get_global_rect().get_center().x > SIZE.x*.5
	_check(on_right == (hand == "right"), "column on the %s side"%hand)
	var lateral := run.orbit.lateral
	var angle := run.orbit.target_angle
	# Two fingers down at once, each pushed to the edge of its stick, held together.
	var move_at := move.get_global_rect().position+move._ring_center()
	var spin_at := spin.get_global_rect().position+spin._ring_center()
	_touch(0, move_at, true)
	_touch(1, spin_at, true)
	_drag(0, move_at+Vector2(80, 0))
	_drag(1, spin_at+Vector2(-80, 0))
	await _frames(20)
	_check(move._touch_index == 0 and spin._touch_index == 1, "each stick holds its own finger")
	_check(run.orbit.lateral > lateral+.3, "move stick moved the drop point (%.2f -> %.2f)"%[lateral, run.orbit.lateral])
	_check(run.orbit.target_angle < angle-.3, "spin stick turned the box while move was held (%.2f -> %.2f)"%[angle, run.orbit.target_angle])
	# Pushing the spin stick down tilts the view down, like a downward swipe on the classic strip.
	var tilt := run.orbit.tilt
	_drag(1, spin_at+Vector2(0, 80))
	await _frames(15)
	_check(run.orbit.tilt < tilt-.1, "spin stick tilts the view (%.2f -> %.2f)"%[tilt, run.orbit.tilt])
	_drag(1, spin_at+Vector2(-80, 0))
	await _frames(2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	# Lift the spin finger only: the move stick must keep its hold.
	_touch(1, spin_at, false)
	await _frames(2)
	_check(spin.deflection == Vector2.ZERO and move.deflection.length() > .9, "releasing one stick leaves the other held")
	_touch(0, move_at, false)
	await _frames(2)
	_check(run.state == "aim", "letting go of the sticks does not drop")
	var drop_at: Vector2 = main.drop_button.get_global_rect().get_center()
	_touch(2, drop_at, true)
	await _frames(1)
	_touch(2, drop_at, false)
	await _frames(3)
	_check(run.state != "aim", "tapping Drop drops the Kinu (state %s)"%run.state)
	# Leave the run tilted and raised, then go home: the home camera must come back to its framing.
	run.orbit.tilt = OrbitController.TILT_MIN
	run.orbit.focus_height = OrbitController.BASE_FOCUS+4.0
	main._home()
	await _frames(3)
	_check(run.orbit.tilt == 0.0 and run.orbit.focus_height == OrbitController.BASE_FOCUS, "home resets the camera tilt and height")
	print("[claw] %s: %s -> %s"%[hand, "PASS" if failures == 0 else "%d FAILED"%failures, path])
	Save.data = saved
	Save.persist()
	get_tree().quit()

func _find_sticks(node: Node, found: Array[Joystick]) -> void:
	if node is Joystick:
		found.append(node)
	for child in node.get_children():
		_find_sticks(child, found)

func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)

func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("  ", "ok   " if ok else "FAIL ", what)
