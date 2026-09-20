class_name DragScroll
extends ScrollContainer
## Vertical list that scrolls by dragging with a finger (or mouse), with momentum. Touch-to-mouse
## emulation is off for gameplay, so the built-in ScrollContainer never sees touch drags.

const START_DISTANCE := 12.0

var tracking: bool = false
var dragging: bool = false
var travelled: float = 0.0
var velocity: float = 0.0

func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# A detail sheet may be visually above this list, but _input receives pointer events globally.
	# Its preview and buttons remain interactive while the shop/book grid stays completely still.
	if get_tree().get_first_node_in_group("modal_input_lock") != null:
		return
	var pressed := false
	var released := false
	var point := Vector2.ZERO
	var motion := 0.0
	if event is InputEventScreenTouch and event.index == 0:
		pressed = event.pressed
		released = not event.pressed
		point = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		point = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		motion = event.relative.y
	elif event is InputEventMouseMotion and tracking:
		motion = event.relative.y
	if pressed and get_global_rect().has_point(point):
		tracking = true
		dragging = false
		travelled = 0.0
		velocity = 0.0
	elif motion != 0.0 and tracking:
		travelled += absf(motion)
		if travelled > START_DISTANCE and not dragging:
			dragging = true
			NestTheme.scroll_dragging = true
		if dragging:
			scroll_vertical -= int(motion)
			velocity = lerpf(velocity, -motion*60.0, .5)
	elif released and tracking:
		tracking = false
		if dragging:
			dragging = false
			# Cleared after this frame so the release doesn't also press the button under the finger.
			_clear_drag_flag.call_deferred()

func _clear_drag_flag() -> void:
	NestTheme.scroll_dragging = false

func _process(delta: float) -> void:
	if tracking or absf(velocity) < 5.0:
		return
	scroll_vertical += int(velocity*delta)
	velocity *= exp(-delta*4.0)
