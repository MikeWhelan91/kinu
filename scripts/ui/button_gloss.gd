class_name ButtonGloss
extends Control
## Arcade glass over a button: a soft cap of light along the top, and a shine that sweeps across
## every few seconds. Nothing moves or resizes, so the control still sits still in the layout —
## it just keeps catching the eye, the way a prize machine's cabinet does.
##
## Add it as the first child of a button so the label and icon stay crisp on top of it.

## Seconds between sweeps, and how long one takes to cross.
const SWEEP_PERIOD := 3.6
const SWEEP_TIME := .55
## How far the streak leans over, as a fraction of the button's height.
const SWEEP_LEAN := .55
const SWEEP_WIDTH := 30.0

## Matched to the button's own corner radius so the cap's top corners follow its outline.
var radius: int = 18
## Inset from the button's edge, normally its border width, so the gloss stays inside the frame.
var inset: float = 3.0
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The streak is drawn across the whole button and cut off at its edges.
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = inset
	offset_top = inset
	offset_right = -inset
	offset_bottom = -inset

func _process(delta: float) -> void:
	_time = fmod(_time+delta, SWEEP_PERIOD)
	# Only the sweep animates, so there is nothing to redraw between passes.
	if _time <= SWEEP_TIME:
		queue_redraw()
	elif _time-delta <= SWEEP_TIME:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	# The cap: brightest along the top edge, following the button's top corners and easing off
	# into a soft lozenge rather than ending on a hard line.
	var cap := StyleBoxFlat.new()
	cap.bg_color = Color(1, 1, 1, .17)
	cap.corner_radius_top_left = radius
	cap.corner_radius_top_right = radius
	cap.corner_radius_bottom_left = int(size.y*.5)
	cap.corner_radius_bottom_right = int(size.y*.5)
	cap.anti_aliasing = true
	draw_style_box(cap, Rect2(Vector2.ZERO, Vector2(size.x, size.y*.52)))
	if _time > SWEEP_TIME:
		return
	# The sweep: a leaning streak crossing left to right, brightest in the middle of its pass.
	var progress := _time/SWEEP_TIME
	var alpha := sin(progress*PI)*.32
	if alpha <= 0.0:
		return
	var lean := size.y*SWEEP_LEAN
	var x := lerpf(-SWEEP_WIDTH-lean, size.x+SWEEP_WIDTH, progress)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x+lean, -1), Vector2(x+lean+SWEEP_WIDTH, -1),
		Vector2(x+SWEEP_WIDTH, size.y+1), Vector2(x, size.y+1)]), Color(1, 1, 1, alpha))
