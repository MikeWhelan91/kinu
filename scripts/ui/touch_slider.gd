class_name TouchSlider
extends HSlider
## An HSlider that also drags by touch. Touch-to-mouse emulation is off for gameplay, so the
## built-in HSlider (like DragScroll's ScrollContainer) never sees touch motion — only mouse.

var _tracking: bool = false
var _start_value: float = 0.0

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not editable:
		return
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			if get_global_rect().has_point(event.position):
				_tracking = true
				_start_value = value
				drag_started.emit()
				_apply_touch_x(event.position.x)
				get_viewport().set_input_as_handled()
		elif _tracking:
			_tracking = false
			drag_ended.emit(value != _start_value)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == 0 and _tracking:
		_apply_touch_x(event.position.x)
		get_viewport().set_input_as_handled()

func _apply_touch_x(x: float) -> void:
	var rect := get_global_rect()
	var ratio := clampf((x-rect.position.x)/rect.size.x, 0.0, 1.0)
	var new_value := min_value+ratio*(max_value-min_value)
	if step > 0:
		new_value = round(new_value/step)*step
	value = new_value
