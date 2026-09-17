class_name Joystick
extends Control
## One half of the claw control scheme: a self-contained virtual stick that tracks its own touch
## by index, independent of any other stick on screen. Two of these held down at once (one per
## thumb) is what makes the claw scheme genuinely two-handed rather than a sequential mode switch -
## each stick claims its own finger the moment it lands and never looks at anyone else's.
##
## Deliberately built on raw InputEventScreenTouch/Drag rather than Control's own _gui_input:
## the project turns off touch-to-mouse emulation (see project.godot), and a joystick needs to
## keep tracking a finger that drags outside its own rect, which a Control's built-in hit-testing
## isn't guaranteed to do for touch the way it does for a captured mouse button.

## "move" nudges the drop point; "spin" turns the box. Set right after creating one.
var kind: String = "move"
var run: NestRun
## Small caption drawn under the ring, e.g. "Move".
var label: String = ""
var base_radius: float = 54.0
var nub_radius: float = 28.0
## Current stick position, -1..1 per axis, magnitude clamped to 1. Read every physics frame.
var deflection: Vector2 = Vector2.ZERO
## -1 idle, an InputEventScreenTouch index while held, or -2 for a held desktop-testing mouse.
var _touch_index: int = -1

const LABEL_HEIGHT := 24.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(base_radius*2+24, base_radius*2+24+LABEL_HEIGHT)

## The ring's centre in local space; the caption sits below it.
func _ring_center() -> Vector2:
	return Vector2(size.x*.5, (size.y-LABEL_HEIGHT)*.5)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(run) or run.state != "aim":
		return
	if kind == "spin":
		run.orbit.spin_hold(deflection, delta)
	else:
		run.orbit.move_hold(deflection, delta)

func _input(event: InputEvent) -> void:
	if not visible or run == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and run.state == "aim" and get_global_rect().has_point(event.position):
				_touch_index = event.index
				_update_from(event.position)
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_from(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Desktop testing only: a mouse has no index, so it stands in for a single touch.
		if event.pressed:
			if _touch_index == -1 and run.state == "aim" and get_global_rect().has_point(event.position):
				_touch_index = -2
				_update_from(event.position)
		elif _touch_index == -2:
			_release()
	elif event is InputEventMouseMotion and _touch_index == -2:
		_update_from(event.position)

func _release() -> void:
	_touch_index = -1
	deflection = Vector2.ZERO
	queue_redraw()

func _update_from(global_point: Vector2) -> void:
	var local := global_point-(get_global_rect().position+_ring_center())
	if local.length() > base_radius:
		local = local.normalized()*base_radius
	deflection = local/base_radius
	queue_redraw()
	if deflection.length() > .1:
		run.action_done.emit("spin" if kind == "spin" else "aim")

func _draw() -> void:
	var center := _ring_center()
	var held := _touch_index != -1
	draw_circle(center, base_radius, Color(1, 1, 1, .3 if held else .18))
	draw_arc(center, base_radius, 0, TAU, 48, NestTheme.INK, 4, true)
	var nub_at := center+deflection*base_radius
	draw_circle(nub_at+Vector2(0, 4), nub_radius, NestTheme.INK)
	draw_circle(nub_at, nub_radius, NestTheme.CREAM)
	draw_arc(nub_at, nub_radius, 0, TAU, 32, NestTheme.INK, 4, true)
	if label != "":
		var font := NestTheme.font
		var text := tr(label)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var baseline := Vector2(size.x*.5-width*.5, size.y-5)
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, NestTheme.INK)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NestTheme.CREAM)
