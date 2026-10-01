class_name TossAimBox
extends Control
## Kinu Toss's aim control: a pad near the bottom of the screen, dragged like a joystick. Left and
## right lean the throw; up and down open or flatten its arc. The mark is sticky - letting go
## leaves it exactly where it was, so aiming and firing never need two fingers down at once, which
## is the point: this is meant to be played one-thumbed and unhurried. The throw's own ghost ring,
## drawn by TossPlay out on the table, is what actually shows where this is pointed.

## Set right after creating one. TossPlay isn't built until NestRun.begin() runs, which is after
## the HUD, so this holds the run rather than the toss game itself and looks it up each time.
var run: NestRun
## Kept clear of the pad's own rounded corners, so the nub's full travel stays inside the track.
const MARGIN := 34.0
const NUB_RADIUS := 22.0
var _touch_index: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(0, 176)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _toss() -> TossPlay:
	return run.toss if is_instance_valid(run) else null

func _live() -> bool:
	var toss := _toss()
	return is_instance_valid(toss) and toss.run.state == "aim"

func _input(event: InputEvent) -> void:
	if not visible or not _live():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = event.index
				_update_from(event.position)
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_touch_index = -1
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_from(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = -2
				_update_from(event.position)
		elif _touch_index == -2:
			_touch_index = -1
			queue_redraw()
	elif event is InputEventMouseMotion and _touch_index == -2:
		_update_from(event.position)

func _update_from(global_point: Vector2) -> void:
	var local := global_point-get_global_rect().position
	var half := _half()
	var x := clampf((local.x-size.x*.5)/half.x, -1, 1)
	var y := clampf((local.y-size.y*.5)/half.y, -1, 1)
	var toss := _toss()
	if is_instance_valid(toss):
		# Screen y grows downward; dragging up should open the arc, not flatten it.
		toss.set_aim(x, -y)
	queue_redraw()

func _half() -> Vector2:
	return Vector2(maxf(size.x*.5-MARGIN, 1.0), maxf(size.y*.5-MARGIN, 1.0))

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_style_box(NestTheme.box(NestTheme.WOOD.lightened(.1), 26, NestTheme.INK, 6), Rect2(Vector2.ZERO, size))
	var center := size*.5
	var half := _half()
	var track := StyleBoxFlat.new()
	track.bg_color = NestTheme.CREAM
	track.set_corner_radius_all(20)
	draw_style_box(track, Rect2(center-half-Vector2(6, 6), half*2+Vector2(12, 12)))
	# A soft crosshair and cardinal hints, so the four directions this drags in read at a glance.
	var guide := Color(NestTheme.INK, .16)
	draw_dashed_line(Vector2(center.x, center.y-half.y), Vector2(center.x, center.y+half.y), guide, 2.5, 10, true)
	draw_dashed_line(Vector2(center.x-half.x, center.y), Vector2(center.x+half.x, center.y), guide, 2.5, 10, true)
	var chevron := Color(NestTheme.INK, .3)
	_chevron(center+Vector2(0, -half.y-2), Vector2(0, -1), chevron)
	_chevron(center+Vector2(0, half.y+2), Vector2(0, 1), chevron)
	_chevron(center+Vector2(-half.x-2, 0), Vector2(-1, 0), chevron)
	_chevron(center+Vector2(half.x+2, 0), Vector2(1, 0), chevron)
	var toss := _toss()
	var aim_t := toss.aim_t if is_instance_valid(toss) else 0.0
	var loft_t := toss.loft_t if is_instance_valid(toss) else 0.0
	var nub := center+Vector2(aim_t*half.x, -loft_t*half.y)
	draw_line(center, nub, Color(NestTheme.SUN.darkened(.15), .8), 7, true)
	draw_circle(center, 6, NestTheme.INK)
	var held := _touch_index != -1
	draw_circle(nub+Vector2(0, 4), NUB_RADIUS, Color(NestTheme.INK, .35))
	draw_circle(nub, NUB_RADIUS, NestTheme.INK)
	draw_circle(nub, NUB_RADIUS-5, NestTheme.SUN.darkened(.1) if held else NestTheme.SUN)

## A small filled triangle pointing outward from the track's edge, hinting the drag direction.
func _chevron(at: Vector2, dir: Vector2, color: Color) -> void:
	var side := Vector2(dir.y, -dir.x)*7.0
	var points := PackedVector2Array([at+dir*10.0, at-dir*4.0+side, at-dir*4.0-side])
	draw_colored_polygon(points, color)
