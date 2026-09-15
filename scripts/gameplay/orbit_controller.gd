class_name OrbitController
extends RefCounted
## Camera rig. Spinning the nest is implemented as orbiting the camera, which keeps the
## pile's physics untouched. The drop point is stored relative to the view (right / toward
## camera), so spinning carries the nest underneath a piece that stays put on screen.

const PLACEMENT_RADIUS := 2.0
const ELEVATION := 0.5
const BASE_FOCUS := 1.2

var angle: float = 0.0
var target_angle: float = 0.0
var spin_velocity: float = 0.0
var spinning: bool = false
var lateral: float = 0.0
var depth: float = 0.0
var tower_top: float = 0.0
var focus_height: float = BASE_FOCUS
var camera: Camera3D
var shake: float = 0.0
var _last_spin_usec: int = 0

func update(delta: float, menu: bool = false) -> void:
	if not spinning:
		target_angle += spin_velocity*delta
		spin_velocity *= exp(-delta*2.8)
		if absf(spin_velocity) < .02:
			spin_velocity = 0.0
	angle = lerpf(angle, target_angle, 1.0-exp(-delta*18))
	var desired := BASE_FOCUS if menu else maxf(BASE_FOCUS, tower_top+.1)
	focus_height = lerpf(focus_height, desired, 1.0-exp(-delta*2.5))
	var rise := focus_height-BASE_FOCUS
	var tall := minf(rise, 6.0)
	# Taller towers: pull back a little and flatten the angle so the side of the tower reads.
	var distance := 7.5+tall*.28
	var elevation := ELEVATION-tall*.03
	var flat := Vector3(sin(angle), 0, cos(angle))
	camera.position = flat*distance*cos(elevation)+Vector3.UP*(focus_height+distance*sin(elevation))
	# The home screen looks a little higher so the tower sits below the shop-front curtain.
	camera.look_at(Vector3(0, focus_height-.3-tall*.22+(.3 if menu else 0.0), 0))
	if shake > 0.0:
		shake = maxf(0.0, shake-delta*1.8)
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0)*shake*.12

func right() -> Vector3:
	return Vector3(cos(angle), 0, -sin(angle))

func toward_camera() -> Vector3:
	return Vector3(sin(angle), 0, cos(angle))

func drop_position(height: float) -> Vector3:
	return right()*lateral+toward_camera()*depth+Vector3.UP*height

func orbit(pixels: float) -> void:
	var step := -pixels*.009
	target_angle += step
	var now := Time.get_ticks_usec()
	var dt := clampf((now-_last_spin_usec)/1000000.0, .004, .1)
	_last_spin_usec = now
	spin_velocity = lerpf(spin_velocity, clampf(step/dt, -14, 14), .5)
	spinning = true

## Lets go of the nest; recent swipe speed carries on as momentum.
func release_spin() -> void:
	spinning = false
	if (Time.get_ticks_usec()-_last_spin_usec) > 80000:
		spin_velocity = 0.0

func stop_spin() -> void:
	spinning = false
	spin_velocity = 0.0

## Moves the drop point by a screen-space drag. Vertical drags are boosted because depth is
## foreshortened by the camera's tilt.
func move_drop(relative: Vector2) -> void:
	var world_per_pixel := 2.0*camera.global_position.distance_to(Vector3(0, focus_height, 0))*tan(deg_to_rad(camera.fov*.5))/camera.get_viewport().get_visible_rect().size.x
	var local := Vector2(lateral+relative.x*world_per_pixel, depth+relative.y*world_per_pixel/sin(ELEVATION+.25))
	if local.length() > PLACEMENT_RADIUS:
		local = local.normalized()*PLACEMENT_RADIUS
	lateral = local.x
	depth = local.y
