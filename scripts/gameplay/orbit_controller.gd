class_name OrbitController
extends RefCounted
## Camera rig. Spinning the nest is implemented as orbiting the camera, which keeps the
## pile's physics untouched. The drop point is stored relative to the view (right / toward
## camera), so spinning carries the nest underneath a piece that stays put on screen.

const PLACEMENT_RADIUS := 2.3
const ELEVATION := 0.5
## The home tableau is viewed more front-on so faces read instead of mostly showing top surfaces.
const MENU_ELEVATION := 0.34
const BASE_FOCUS := 1.2
## How far a vertical swipe can tilt the view below or above the default angle, in radians.
const TILT_MIN := -.22
const TILT_MAX := .38

var angle: float = 0.0
var target_angle: float = 0.0
var spin_velocity: float = 0.0
var spinning: bool = false
var lateral: float = 0.0
var depth: float = 0.0
var tower_top: float = 0.0
var focus_height: float = BASE_FOCUS
## Home screen only: how high the rig looks, so the taller tower set-up is framed whole rather
## than cropped by the shop sign. Gameplay tracks the real pile instead.
var menu_focus: float = BASE_FOCUS
var camera: Camera3D
var shake: float = 0.0
var tilt: float = 0.0
## Total spin this run, in radians, for "spin the box" missions.
var travelled: float = 0.0
var _last_spin_usec: int = 0

func update(delta: float, menu: bool = false) -> void:
	if not spinning:
		target_angle += spin_velocity*delta
		spin_velocity *= exp(-delta*2.8)
		if absf(spin_velocity) < .02:
			spin_velocity = 0.0
	var previous := angle
	angle = lerpf(angle, target_angle, 1.0-exp(-delta*18))
	if not menu:
		travelled += absf(angle-previous)
	var desired := menu_focus if menu else maxf(BASE_FOCUS, tower_top+.1)
	focus_height = lerpf(focus_height, desired, 1.0-exp(-delta*2.5))
	var rise := focus_height-BASE_FOCUS
	var tall := minf(rise, 6.0)
	# Taller towers: pull back a little and flatten the angle so the side of the tower reads.
	var distance := 8.0+tall*.28
	var elevation := (MENU_ELEVATION if menu else ELEVATION)-tall*.03+tilt
	var flat := Vector3(sin(angle), 0, cos(angle))
	camera.position = flat*distance*cos(elevation)+Vector3.UP*(focus_height+distance*sin(elevation))
	# Aim near the faces on the home tableau; gameplay retains its higher view of landing surfaces.
	camera.look_at(Vector3(0, focus_height-.3-tall*.22+(.22 if menu else 0.0), 0))
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

## Vertical swipes raise or lower the camera a little.
func tilt_by(pixels: float) -> void:
	tilt = clampf(tilt-pixels*.004, TILT_MIN, TILT_MAX)

## Lets go of the nest; recent swipe speed carries on as momentum.
func release_spin() -> void:
	spinning = false
	if (Time.get_ticks_usec()-_last_spin_usec) > 80000:
		spin_velocity = 0.0

func stop_spin() -> void:
	spinning = false
	spin_velocity = 0.0

## Claw scheme: driven every physics frame from a joystick's held deflection, instead of the
## flick-and-momentum gesture above. Motion tracks the stick directly and stops dead the instant
## it's let go, like a real claw machine's rate-controlled joystick rather than a coasting swipe.
const MOVE_HOLD_SPEED := 3.4
const SPIN_HOLD_SPEED := 2.6
## Radians per second of view tilt with the spin stick pushed fully up or down.
const TILT_HOLD_SPEED := .9

func move_hold(deflection: Vector2, delta: float) -> void:
	if deflection.length() < .04:
		return
	var local := Vector2(lateral, depth)+deflection*MOVE_HOLD_SPEED*delta
	if local.length() > PLACEMENT_RADIUS:
		local = local.normalized()*PLACEMENT_RADIUS
	lateral = local.x
	depth = local.y

## Across turns the box; up and down tilts the view, the same as a vertical swipe on the spin strip.
func spin_hold(deflection: Vector2, delta: float) -> void:
	if absf(deflection.y) >= .04:
		tilt = clampf(tilt-deflection.y*TILT_HOLD_SPEED*delta, TILT_MIN, TILT_MAX)
	if absf(deflection.x) < .04:
		stop_spin()
		return
	spinning = true
	target_angle += deflection.x*SPIN_HOLD_SPEED*delta
	# `travelled` still accumulates in update(), off the smoothed `angle` rather than target_angle.

## Moves the drop point by a screen-space drag. Vertical drags are boosted because depth is
## foreshortened by the camera's tilt.
func move_drop(relative: Vector2) -> void:
	var world_per_pixel := 2.0*camera.global_position.distance_to(Vector3(0, focus_height, 0))*tan(deg_to_rad(camera.fov*.5))/camera.get_viewport().get_visible_rect().size.x
	var local := Vector2(lateral+relative.x*world_per_pixel, depth+relative.y*world_per_pixel/sin(ELEVATION+tilt+.25))
	if local.length() > PLACEMENT_RADIUS:
		local = local.normalized()*PLACEMENT_RADIUS
	lateral = local.x
	depth = local.y
