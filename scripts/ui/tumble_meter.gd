class_name TumbleMeter
extends Control
## Two compact rows of hearts for the tumbles (or Toss misses) a run can survive. Each loss empties
## a heart, which bursts out of its outline as it goes.

var total: int = NestRun.MAX_TUMBLES
var used: int = 0:
	set(value):
		var before := used
		used = value
		if value > before and is_inside_tree():
			_burst = 1.0
			var pop := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			pop.tween_property(self, "_burst", 0.0, .45).set_ease(Tween.EASE_OUT)
		queue_redraw()
## 1 → 0 as the most recently lost heart bursts away.
var _burst := 0.0:
	set(value):
		_burst = value
		queue_redraw()

const HEART_RED := Color("ff5a6e")
const HEART_DEEP := Color("d93a52")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _get_minimum_size() -> Vector2:
	# Report this before the VBox lays out the score card, so the second row cannot be clipped.
	return Vector2(96, 50) if total > 3 else Vector2(84, 24)

func _draw() -> void:
	# This is intentionally an explicit 3 × 2 grid. Do not collapse it into a single row.
	var start := Vector2((size.x-84.0)*.5, (size.y-(44.0 if total > 3 else 21.0))*.5)
	for i in total:
		var column := i % 3
		var y := 1.0 if i < 3 else 24.0
		var centre := start+Vector2(column*28+14, y+10)
		var lost := i >= total-used
		if lost:
			_heart(centre, 9.5, Color(NestTheme.MUTED, .22), Color(NestTheme.INK, .4))
			# The heart that just went bursts out of its outline and fades.
			if i == total-used and _burst > 0.0:
				_heart(centre, 9.5*(1.0+(1.0-_burst)*.7), Color(HEART_RED, _burst), Color(NestTheme.INK, _burst))
		else:
			_heart(centre, 9.5, HEART_RED, NestTheme.INK)
			_heart(centre+Vector2(0, 2.2), 6.2, HEART_DEEP, Color(0, 0, 0, 0), false)
			draw_circle(centre+Vector2(-3.6, -3.4), 1.9, Color(1, 1, 1, .85))

func _heart(centre: Vector2, radius: float, fill: Color, edge: Color, outline: bool = true) -> void:
	var points := PackedVector2Array()
	for step in 28:
		var a := TAU*step/28.0
		var x := 16.0*pow(sin(a), 3)
		var y := -(13.0*cos(a)-5.0*cos(2.0*a)-2.0*cos(3.0*a)-cos(4.0*a))
		points.append(centre+Vector2(x, y+1.5)*radius/16.0)
	if not outline:
		# A deeper lower lobe for a little roundness, kept inside the main heart.
		draw_colored_polygon(points, fill)
		return
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, edge, 2.5, true)
