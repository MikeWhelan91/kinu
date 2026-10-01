class_name TossFireButton
extends Control
## Kinu Toss's fire control: hold to charge the throw, let go to send it. A ring fills around the
## button as it charges and stays full once charged, so there's no way to fumble a throw by
## holding a moment too long - only the choice of when to let go.

## Set right after creating one. TossPlay isn't built until NestRun.begin() runs, which is after
## the HUD, so this holds the run rather than the toss game itself and looks it up each time.
var run: NestRun
const RADIUS := 52.0
var _touch_index: int = -1
var _pressed: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS*2+8, RADIUS*2+8)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _toss() -> TossPlay:
	return run.toss if is_instance_valid(run) else null

func _live() -> bool:
	var toss := _toss()
	return is_instance_valid(toss) and toss.run.state == "aim" and is_instance_valid(toss.run.active)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _live() and get_global_rect().has_point(event.position):
				_touch_index = event.index
				_press()
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_touch_index = -1
			_release()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _touch_index == -1 and _live() and get_global_rect().has_point(event.position):
				_touch_index = -2
				_press()
		elif _touch_index == -2:
			_touch_index = -1
			_release()

func _press() -> void:
	_pressed = true
	var toss := _toss()
	if is_instance_valid(toss):
		toss.start_charge()

func _release() -> void:
	_pressed = false
	var toss := _toss()
	if is_instance_valid(toss):
		toss.release_charge()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x*.5, size.y*.5)
	var toss := _toss()
	var charge := toss.charge if is_instance_valid(toss) else 0.0
	draw_circle(center, RADIUS, NestTheme.SUN.darkened(.08) if _pressed else NestTheme.SUN)
	if charge > .001:
		draw_arc(center, RADIUS-8, -PI*.5, -PI*.5+TAU*charge, 32, NestTheme.INK, 8, true)
	draw_arc(center, RADIUS, 0, TAU, 48, NestTheme.INK, 4, true)
	var text := tr("Fire")
	var font := NestTheme.font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var baseline := center+Vector2(-width*.5, 7)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, NestTheme.INK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, NestTheme.CREAM)
