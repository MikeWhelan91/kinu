class_name TossPowerMeter
extends Control
## Kinu Toss's power gauge: a tall bar beside the Fire button that fills as it charges, so how
## hard the next throw is about to go is something you can see at a glance, not just feel through
## the button's own small ring.

## Set right after creating one. TossPlay isn't built until NestRun.begin() runs, which is after
## the HUD, so this holds the run rather than the toss game itself and looks it up each time.
var run: NestRun
const WIDTH := 30.0

func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, 176)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _toss() -> TossPlay:
	return run.toss if is_instance_valid(run) else null

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_style_box(NestTheme.box(NestTheme.WOOD.lightened(.1), 15, NestTheme.INK, 5), Rect2(Vector2.ZERO, size))
	var pad := 6.0
	var track := Rect2(Vector2(pad, pad), Vector2(size.x-pad*2, size.y-pad*2))
	var inner := StyleBoxFlat.new()
	inner.bg_color = NestTheme.CREAM
	inner.set_corner_radius_all(10)
	draw_style_box(inner, track)
	var toss := _toss()
	var charge := toss.charge if is_instance_valid(toss) and toss.charging else 0.0
	if charge > .003:
		var fill_height := track.size.y*charge
		var fill := Rect2(track.position+Vector2(0, track.size.y-fill_height), Vector2(track.size.x, fill_height))
		var bar := StyleBoxFlat.new()
		bar.bg_color = NestTheme.BERRY.lerp(NestTheme.SUN, charge)
		bar.set_corner_radius_all(10)
		draw_style_box(bar, fill)
	# A few rest notches, purely decorative, so the bar reads as a gauge rather than a blank slab.
	for i: float in [.25, .5, .75]:
		var y: float = track.position.y+track.size.y*(1.0-i)
		draw_line(Vector2(track.position.x, y), Vector2(track.position.x+track.size.x, y), Color(NestTheme.INK, .18), 2)
