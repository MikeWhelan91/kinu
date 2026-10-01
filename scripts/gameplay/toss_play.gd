class_name TossPlay
extends Node3D
## Kinu Toss: flick Kinu off a mat at the front of the counter into a tilted box down the table.
## A Kinu has to go in and stay in. Smaller holes, longer throws and unbroken streaks score more;
## six misses end the run.
##
## Every box takes a few Kinu and is then carried off. The run opens on open boxes, then a lid with
## one hole that shrinks as the boxes move away, then lids with holes of several sizes, turned and
## off to the side. There are no levels, only an escalating run.
##
## NestRun still owns the shared parts of a run (the Kinu it makes, the queue, the score, stats and
## the end of the run); this node owns everything Toss does differently, including the camera.

const MAX_MISSES := 6
## A Kinu that scored has to stay in: out of the box this long and its points go back.
const KNOCKED_OUT_SECONDS := .35
## Clipped copies of Kinu materials, by original, for Kinu lying inside a box (box_clip.gdshaderinc).
static var clip_materials: Dictionary = {}
## Where the mat lies: across the front of the counter.
const MAT_Z := 3.4
const MAT_REACH := 2.3
## How small the waiting Kinu is drawn on the mat, so it clears the controls right below it.
const WAITING_SCALE := .68
## How many Kinu a box wants before it is carried away, by what it is: a wide open box asks for a
## proper haul, a lid with one shrinking hole for fewer, and a lid of little holes for a handful.
## A box also gives up after its quota plus SPARE_THROWS, so a hopeless board never stalls a run.
const OPEN_QUOTA := [10, 8]
const HOLE_QUOTA := [6, 5, 4, 4]
const LATE_QUOTA := 3
## A late-game gauntlet box: four walled-off compartments in a row, one Kinu needed in each. Kept
## to four, not more: a Kinu tumbles and lands however it lands, and much narrower than this most
## shapes simply can't fit through in any orientation.
const GAUNTLET_CHANCE := .16
const GAUNTLET_HOLES := 4
const SPARE_THROWS := 4
## How long holding the fire button takes to reach full power.
const CHARGE_SECONDS := 1.1
## Letting go always throws, however little it charged: this floor keeps a tap from being a dead
## drop rather than a proper (if feeble) toss.
const MIN_POWER := .12
## The loft a throw defaults to reaching for the aim point; steepened automatically for a target
## too close or too high for this to clear at any speed (see _solve_throw). Close to 45 degrees,
## where a throw's own arc reads as an arc rather than a near-straight line, without tipping past
## the angle that actually maximises range for a given speed.
const THROW_LOFT := .78
## However little the fire button is held, a throw still reaches this fraction of the way to the
## aim point - a floor under MIN_POWER so a bare tap is a feeble toss, not a dead drop.
const MIN_REACH_FRACTION := .12
## Full charge covers this much more ground than the aim point itself, rather than landing exactly
## on it - the solved speed alone gets you precisely there with nothing left over, which reads as
## gutless no matter how long the button was held. Range scales with speed squared, not speed
## itself, so the actual speed multiplier used is this value's square root - applying it directly
## turned a "little extra" into nearly tripling the distance.
const FULL_POWER_OVERSHOOT_RANGE := 1.35
## A resting Kinu is judged once it has been this still for this long, or at the timeout.
const REST_SPEED := .28
const REST_SECONDS := .3
const JUDGE_TIMEOUT := 3.5
## After a Kinu hits the table it gets this long to skip on into the box. Past that, a throw that
## is not in the box and not heading for it is called at once rather than watched to a standstill.
const SKIP_GRACE := .35
## World units to centimetres, the same scale Tower measures in.
const CM_PER_UNIT := 20.0
const STREAK_STEP := .5
const STREAK_CAP := 5.0
const LID_POINTS := 25
## Paid per Kinu the box asked for, so filling a ten-Kinu box is worth the work.
const BOX_BONUS := 60
const GOLD_BEANS := 15

var run: NestRun
var camera: Camera3D
var mat: Node3D
var box: TossBox
var table: TossTable
var rng := RandomNumberGenerator.new()

## Where the Kinu is lined up across the mat: where it sits when nothing is holding it, and where
## the camera leans to. Driven by aim_t, the aim box's own -1..1 left/right value.
var aim_x: float = 0.0
var aim_t: float = 0.0
## The aim box's own -1..1 up/down value: -1 flattest, 1 highest.
var loft_t: float = 0.0
## True while the fire button is held; charge climbs from 0 to 1 over CHARGE_SECONDS.
var charging: bool = false
var charge: float = 0.0
## The ghost Kinu itself, and the materials that make it translucent.
var _ghost: Node3D
var _ghost_fill_material: StandardMaterial3D
var _ghost_outline_material: StandardMaterial3D
## Which body the ghost's model currently mirrors, so it's only rebuilt when that changes.
var _ghost_for: KinuBody
var flying: KinuBody
var flight_time: float = 0.0
var still_time: float = 0.0
var launch_point := Vector3.ZERO
var last_local := Vector3.ZERO
## The hole the flying Kinu dropped through, and how far off its centre it was (0 = dead centre).
var crossed_hole: int = -1
var crossed_offset: float = 1.0
## True once the flying Kinu has touched the table: getting in after that is a Skip Shot.
var skipped: bool = false
## When in the flight the Kinu first hit the table, for the skip-on grace.
var ground_time: float = 0.0

var box_index: int = 0
var box_kinu: int = 0
var box_throws: int = 0
## How many this box wants, and how many throws it will take before it goes anyway.
var box_quota: int = 3
## Kinu in or on the current box. They ride away with it.
var riders: Array[KinuBody] = []
var boxes_filled: int = 0
var longest_cm: int = 0
var multiplier: float = 1.0

var focus := Vector3.ZERO

func _ready() -> void:
	rng.randomize()
	camera = run.orbit.camera
	table = TossTable.new()
	table.decor = run.room.decor
	add_child(table)
	mat = build_mat()
	mat.position = Vector3(0, 0, MAT_Z)
	add_child(mat)
	_build_ghost()
	_new_box()
	focus = _wanted_focus()
	_place_camera(1.0)

## The ghost Kinu: a translucent copy of the held piece, sat where the current aim and a steady
## reference power would land it - the same idea as Classic's own landing ghost, just following a
## throw's arc instead of a straight drop.
func _build_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.name = "TossGhost"
	_ghost.visible = false
	_ghost_fill_material = _ghost_material(Color(.35, .82, 1.0, .22))
	_ghost_outline_material = _ghost_material(Color(.18, .48, .82, .7))
	add_child(_ghost)

func _ghost_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material

## Rebuilt only when a new held Kinu appears: the ghost uses the same generated model as the live
## piece, including its outfit and exact in-play scale, but has no collider.
func _rebuild_ghost() -> void:
	for child in _ghost.get_children():
		_ghost.remove_child(child)
		child.queue_free()
	_ghost_for = run.active
	if not is_instance_valid(run.active):
		return
	var body := run.active
	var model := KinuModel.build(body.shape, body.look, body.outfit, "calm", body.parts)
	model.name = "KinuGhost"
	model.transform = Transform3D(Basis.from_scale(Vector3.ONE*body.body_scale), Vector3.ZERO)*body.fit
	_ghost.add_child(model)
	_apply_ghost_materials(model)

func _apply_ghost_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.material_override = _ghost_outline_material if mesh.name.contains("Outline") else _ghost_fill_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_ghost_materials(child)

func start() -> void:
	run.choose_next()
	run.state = "ready"
	_spawn()

# ---------- The box ----------

## The throwing mat: a red felt rug laid across the front of the counter, with a paler border.
static func build_mat() -> Node3D:
	var kit := MeshKit.new()
	kit.add_rounded_box(Vector3(0, .04, 0), Vector3(MAT_REACH*2+1.3, .08, 1.15), Color("e0685a"), Vector3.ZERO, true, 10.0)
	kit.add_rounded_box(Vector3(0, .07, 0), Vector3(MAT_REACH*2+.95, .04, .85), Color("b8322d"), Vector3.ZERO, false, 10.0)
	for side in [-1.0, 1.0]:
		kit.add_rounded_box(Vector3(0, .1, side*.34), Vector3(MAT_REACH*2+.7, .01, .03), Color("f3a08f"), Vector3.ZERO, false, 10.0)
	return kit.build(.035)

## Builds the next box from how far into the run this is. It opens on two open boxes, close in.
## Then a lid goes on with one hole that shrinks as the boxes move away, and from there the lids
## carry holes of several sizes, the box drifts to the side and some are turned.
func _new_box() -> void:
	var d := box_index
	var late := clampf((d-6)/8.0, 0, 1)
	# One curve runs the whole escalation: the box shrinks, stands up less and sits further away.
	var ease := clampf(d/12.0, 0, 1)
	var size := clampf(lerpf(1.25, .62, ease)+rng.randf_range(-.03, .03), .58, 1.3)
	var distance: float
	var sizes: Array = []
	var lidded := true
	var compartments := 0
	match d:
		0, 1:
			# Wide open and close to: a good haul to learn the flick on.
			lidded = false
			distance = 8.0+d*1.2
			box_quota = OPEN_QUOTA[d]
		2, 3, 4, 5:
			# The lid goes on with one hole, a little smaller and further away each box. Kept
			# roomier than the old progression: too tight and the wider shapes can't reliably fit.
			sizes = [[1.45, 1.2, 1.0, .88][d-2]]
			distance = 9.0+(d-2)*.6
			box_quota = HOLE_QUOTA[d-2]
		_:
			# Open, walled off into narrow compartments instead of a lid full of holes: the target
			# is squeezing a throw into one slot, and every slot is worth landing.
			lidded = false
			var gauntlet := d >= 9 and rng.randf() < GAUNTLET_CHANCE
			compartments = GAUNTLET_HOLES if gauntlet else [2, 2, 3][rng.randi() % 3]
			box_quota = compartments
			distance = lerpf(9.5, 12.5, late)+rng.randf_range(-1.0, 1.0)
			# Keep each pocket wide enough to remain a readable target as the run escalates.
			size = maxf(size, .90 if compartments >= 3 else .75)
			if gauntlet:
				# Held at full size so four compartments actually fit side by side.
				size = 1.3
	box = TossBox.new()
	box.decor = run.catalog.find_decor("box", str(Save.data.box))
	# Wider across than deep: seen from behind the mat, depth foreshortens away to nothing, so a
	# long narrow box reads as a slot. What the player aims at is the width.
	box.half_x = 1.95*size
	box.half_z = 1.5*size
	# Tipped well back, so from behind the mat you are looking into the box rather than at its lid.
	# The early ones lean the furthest; later boxes stand up and show less of themselves.
	box.tilt = lerpf(.46, .36, ease)+rng.randf_range(-.02, .02)
	box.lidded = lidded
	box.compartments = compartments
	box.holes = TossBox.place_compartment_holes(sizes, Vector2(box.half_x, box.half_z), rng)
	# An open box keeps low walls: tall ones on a tilt turn the mouth into a slot that throws Kinu
	# back at you. A lidded box is the other way round — the smaller its holes, the deeper it has
	# to be, or the first Kinu through sits up in the hole and blocks it for the rest.
	var tightest := float(TossBox.TIERS.big.half)
	for hole in box.holes:
		tightest = minf(tightest, float(hole.half))
	box.rise = clampf(size, .95, 1.12) if not lidded else clampf(1.0+(.82-tightest)*1.9, 1.0, 1.7)
	var reach := box.outer()
	var z := clampf(MAT_Z-distance, -TossTable.END+reach.y+.2, MAT_Z-2.6-reach.y)
	var sideways := lerpf(0.0, 1.9, clampf((d-3)/6.0, 0, 1))
	var x := clampf(rng.randf_range(-1, 1)*sideways, -TossTable.HALF+reach.x+.1, TossTable.HALF-reach.x-.1)
	box.position = Vector3(x, 0, z)
	box.rotation.y = rng.randf_range(-.4, .4) if d >= 8 and rng.randf() < .45 else 0.0
	add_child(box)
	box_kinu = 0
	box_throws = 0
	riders.clear()

## Carries the finished box off the side of the table with everything in it, and slides the next
## one in from the other side.
func _swap_box() -> void:
	run.state = "shipping"
	var full := box_kinu >= box_quota
	if full:
		boxes_filled += 1
		run.boxes_filled = boxes_filled
		var bonus := int(BOX_BONUS*box_quota*multiplier)
		run.score += bonus
		run.message.emit(tr("Box full! +%d")%bonus, Color("3f8fe0"))
		Sound.play("cashregister")
		Haptics.pulse(40, .6)
		run.updated.emit()
	await get_tree().create_timer(.25, false).timeout
	if run.state != "shipping":
		return
	var leaving: Array[Node3D] = [box]
	for body in riders:
		if is_instance_valid(body):
			body.freeze = true
			leaving.append(body)
	var away := create_tween().set_parallel(true)
	for node in leaving:
		away.tween_property(node, "position:x", node.position.x+16.0, .4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await away.finished
	if run.state != "shipping":
		return
	for body in riders:
		if is_instance_valid(body):
			run.bodies.erase(body)
			body.queue_free()
	box.queue_free()
	box_index += 1
	_new_box()
	var target := box.position.x
	box.position.x = target-16.0
	var back := create_tween()
	back.tween_property(box, "position:x", target, .38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await back.finished
	if run.state != "shipping":
		return
	Sound.play("drop")
	_spawn()

# ---------- Aiming and throwing ----------

func _spawn() -> void:
	if run.state in ["over", "falling"]:
		return
	# The aim carries over from the last throw: lining up on the same spot shouldn't cost a re-aim.
	var body := run.make_body(run.next_shape, run.next_flavour, run.next_special, true, _compartment_kinu_scale(run.next_shape))
	if body.special != "" and not Save.data.seen_specials.has(body.special):
		Save.data.seen_specials.append(body.special)
		Save.persist()
		run.message.emit(tr(SpecialBadge.INTRO[body.special]), SpecialBadge.COLORS[body.special].darkened(.25))
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	# Facing you, and not happy about what's coming: it trembles on the mat until it's thrown.
	body.rotation = Vector3.ZERO
	body.mood_override = "worried"
	body.sway = .3
	# Smaller while it waits, so it clears the controls right in front of it; back to full size
	# the moment it's actually thrown, in throw().
	body.scale = Vector3.ONE*WAITING_SCALE
	run.active = body
	run.choose_next()
	_seat(body)
	run.state = "aim"
	run.updated.emit()

## Make the widest horizontal side of the collision hull clear a pocket even when the Kinu
## lands sideways. The visual and hitbox share this scale, and Tiny Kinu keep their smaller size.
func _compartment_kinu_scale(shape: KinuShape) -> float:
	if box.compartments <= 1:
		return 1.0
	var pocket_width := box.half_x*2.0/float(box.compartments)-.22
	var widest := maxf(shape.size.x, shape.size.z)+KinuModel.OUTLINE_WIDTH*2.0
	return minf(1.0, pocket_width/(widest*KinuBody.SCALE))

## Where a Kinu rests when nothing is holding it: dead centre on the mat. It used to slide with
## the aim, but that put it in the way of the controls right below it and made it look like it was
## wandering rather than waiting.
func _seat(body: KinuBody) -> void:
	body.position = _rest_spot(body)

## Raised straight up off the mat, not just balanced on it: the controls sit low on screen now,
## so the waiting Kinu needs real height, not camera tricks or distance, to clear them.
const WAITING_LIFT := .6

func _rest_spot(body: KinuBody) -> Vector3:
	return Vector3(0.0, WAITING_LIFT+body.size().y*.5, MAT_Z)

func input(event: InputEvent) -> void:
	# Aiming and firing are both handled by their own on-screen controls (TossAimBox,
	# TossFireButton); this is left for desktop keyboard testing only.
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and run.state == "aim":
		if key.keycode == KEY_LEFT:
			set_aim(clampf(aim_t-.15, -1, 1), loft_t)
		elif key.keycode == KEY_RIGHT:
			set_aim(clampf(aim_t+.15, -1, 1), loft_t)
		elif key.keycode == KEY_UP:
			set_aim(aim_t, clampf(loft_t+.15, -1, 1))
		elif key.keycode == KEY_DOWN:
			set_aim(aim_t, clampf(loft_t-.15, -1, 1))
		elif key.keycode in [KEY_SPACE, KEY_ENTER] and not charging:
			start_charge()
	elif not key.pressed and key.keycode in [KEY_SPACE, KEY_ENTER] and charging:
		release_charge()

## Sets the aim from the aim box's own -1..1 values: x leans the throw left/right, y opens (+1) or
## flattens (-1) its arc. Both are sticky - the box only moves them while it's actually held.
func set_aim(x: float, y: float) -> void:
	aim_t = clampf(x, -1, 1)
	aim_x = aim_t*MAT_REACH
	loft_t = clampf(y, -1, 1)

## Leaving Toss mid-charge (quitting the run, say) mustn't leave the wind-up playing on.
func _exit_tree() -> void:
	Sound.toss_charge(false)

## Starts charging the held Kinu's throw; power climbs while the fire button stays down.
func start_charge() -> void:
	if run.state != "aim" or not is_instance_valid(run.active):
		return
	charging = true
	charge = 0.0
	run.active.sway = .6
	run.active.poke(-1.8)
	Haptics.pulse(10, .2)

func _charge_step(delta: float) -> void:
	if charging:
		charge = clampf(charge+delta/CHARGE_SECONDS, 0, 1)

## Letting go of the fire button always throws, at whatever power it reached.
func release_charge() -> void:
	if not charging:
		return
	charging = false
	var power := charge
	charge = 0.0
	if run.state == "aim" and is_instance_valid(run.active):
		throw(maxf(power, MIN_POWER))

## A free-aim point built off the box's own surface, x = left/right across its width. Up/down is
## more than just its depth, though: the box's near-to-far span only fills the lower part of the
## stick's own travel (see AIM_DEPTH_FRACTION), so the far lip sits comfortably inside the usable
## range instead of right at its very edge - and pushing further "up" past that doesn't stop at
## the lip, it keeps going, out past the box and up into the open sky, for a real high lob.
const AIM_MARGIN := .12
## How much of the stick's own upward travel it takes to reach the box's actual far lip - the
## rest keeps climbing on past it.
const AIM_DEPTH_FRACTION := .42
## Eases a -1..1 value towards the middle: a small drag turns into an even smaller move. Only used
## once the stick is past the box's own far lip, out in open sky - inside the box itself the stick
## tracks the finger directly, since that's the part that actually needs to be precise, and easing
## it only made it harder to place a throw exactly where intended.
const BEYOND_EASE := 3.0
static func _eased(t: float, exponent: float = BEYOND_EASE) -> float:
	return signf(t)*pow(absf(t), exponent)

func _aim_point(aim_x_t: float, aim_y_t: float) -> Vector3:
	if not is_instance_valid(box):
		return Vector3(0, 1.0, -6.0)
	var lx := clampf(aim_x_t, -1, 1)*maxf(box.half_x-AIM_MARGIN, 0.0)
	var raw_y := clampf(aim_y_t, -1, 1)
	var base_y := box.lid_top() if box.lidded else box.rim()
	var depth := maxf(box.half_z-AIM_MARGIN, 0.0)/AIM_DEPTH_FRACTION
	# The box's local -z is its raised far side (see TossBox._build_stand, whose support legs sit
	# at negative z under that raised back) - "up" on the stick has to point there, not +z.
	var lz: float
	var beyond: float
	if raw_y <= AIM_DEPTH_FRACTION:
		lz = -raw_y*depth
		beyond = 0.0
	else:
		var past := (raw_y-AIM_DEPTH_FRACTION)/(1.0-AIM_DEPTH_FRACTION)
		beyond = _eased(past)
		lz = -AIM_DEPTH_FRACTION*depth-beyond*(1.0-AIM_DEPTH_FRACTION)*depth
	var ly := base_y+beyond*depth*1.3
	return box.board.to_global(Vector3(lx, ly, lz))

## Solves the loft and speed a throw needs, at full strength, to land exactly on `target` from
## `start`: the aim point is free, but the throw that reaches it is still real ballistics, worked
## out backwards instead of guessed at with a fixed angle range. Steepens automatically when the
## target is too close or too high for the default loft to clear at any speed.
func _solve_throw(start: Vector3, target: Vector3) -> Dictionary:
	var reach := Vector2(target.x-start.x, target.z-start.z).length()
	var rise := target.y-start.y
	var g := _gravity()
	var loft := THROW_LOFT
	for attempt in 3:
		var denom := 2.0*cos(loft)*cos(loft)*(reach*tan(loft)-rise)
		if denom > .05:
			var speed := sqrt(g*reach*reach/denom)
			return {"loft": loft, "speed": speed}
		# This loft can't clear the target at any speed (too close, too high) - go steeper and
		# try again, right up to a near-vertical drop shot.
		loft = lerpf(loft, 1.45, .6)
	# Degenerate (on top of the target, or behind it): a soft vertical lob is always safe.
	return {"loft": 1.4, "speed": sqrt(maxf(rise, .5)*2.0*g)+1.0}

## Fires the held Kinu at the current aim. `power`, 0 to 1, sets how much of the solved throw it
## actually gets - full power lands it exactly on the aim point; less falls short along the same line.
func throw(power: float) -> void:
	var body := run.active
	if run.state != "aim" or not is_instance_valid(body):
		return
	var target := _aim_point(aim_t, loft_t)
	var solved := _solve_throw(body.position, target)
	var loft: float = solved.loft
	var speed: float = solved.speed*lerpf(MIN_REACH_FRACTION, sqrt(FULL_POWER_OVERSHOOT_RANGE), clampf(power, 0, 1))
	var aim := atan2(target.x-body.position.x, body.position.z-target.z)
	var forward := Vector3(sin(aim), 0, -cos(aim))
	body.scale = Vector3.ONE
	run.state = "settle"
	run.active = null
	run.pending = body
	flying = body
	body.collision_layer = 2
	body.collision_mask = 3
	body.freeze = false
	body.sleeping = false
	# Near-free flight, so power reads true; a Slab's broad face catches a little more air.
	# Replace rather than combine, or the room's own drag pulls every long throw short.
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = .12 if body.shape.id == "slab" else .02
	body.angular_damp = .5
	body.linear_velocity = forward*cos(loft)*speed+Vector3.UP*sin(loft)*speed
	# A forward cartwheel, the same every time: a random tumble made two identical throws land in
	# different places.
	body.angular_velocity = Basis(Vector3.UP, aim)*Vector3(-speed*.55, 0, 0)
	body.mood_override = "falling"
	body.sway = 0.0
	if not body.landed.is_connected(_struck):
		body.landed.connect(_struck)
	launch_point = body.position
	last_local = box.local(body.position)
	flight_time = 0.0
	still_time = 0.0
	crossed_hole = -1
	crossed_offset = 1.0
	skipped = false
	ground_time = 0.0
	body.poke(3.0)
	# The launch has its own shot plus a quieter, varied in-flight Kinu cry.
	Sound.play("shoot", 1.12)
	Sound.play("wee")
	Haptics.pulse(18, .35)
	run.action_done.emit("drop")
	run.updated.emit()

# ---------- Flight and judging ----------

func step(delta: float) -> void:
	Sound.toss_charge(charging and run.state == "aim")
	if run.state in ["menu", "over"]:
		_place_camera(delta)
		return
	run.run_time += delta
	_track_box(delta)
	_charge_step(delta)
	if is_instance_valid(run.active):
		run.active.position = run.active.position.lerp(_rest_spot(run.active), 1.0-exp(-delta*18))
	_update_ghost()
	if run.state == "falling":
		_place_camera(delta)
		return
	if is_instance_valid(flying):
		_follow_flight(delta)
	_place_camera(delta)

## Sits the ghost Kinu exactly where the aim box currently points - a real free-aim reticle, not
## a landing guess, so it moves exactly as far and as freely on screen as the stick does.
func _update_ghost() -> void:
	if run.state != "aim" or not is_instance_valid(run.active):
		_ghost.visible = false
		return
	if run.active != _ghost_for:
		_rebuild_ghost()
	_ghost.visible = true
	_ghost.position = _ghost_settle(_aim_point(aim_t, loft_t))

## World-space samples of the exact throw that would land at the current aim point. Kept here with
## the solver so the HUD guide can never drift away from the actual ballistics.
func preview_trajectory() -> PackedVector3Array:
	var points := PackedVector3Array()
	if run.state != "aim" or not is_instance_valid(run.active):
		return points
	var start := run.active.position
	var target := _aim_point(aim_t, loft_t)
	var solved := _solve_throw(start, target)
	var loft: float = solved.loft
	var speed: float = solved.speed
	var horizontal_speed := maxf(speed*cos(loft), .01)
	var reach := Vector2(target.x-start.x, target.z-start.z).length()
	var duration := reach/horizontal_speed
	var direction := Vector3(target.x-start.x, 0, target.z-start.z).normalized()
	for i in 21:
		var t := duration*float(i)/20.0
		points.append(start+direction*horizontal_speed*t+Vector3.UP*(speed*sin(loft)*t-.5*_gravity()*t*t))
	return points

## Keeps the ghost sitting on a real surface - the box's own floor or lid, inset a little from its
## walls - rather than floating in mid-air or clipping through the box's solid geometry, wherever
## the free-aim point itself happens to land.
const GHOST_INSET := .2
func _ghost_settle(point: Vector3) -> Vector3:
	if is_instance_valid(box):
		var local := box.local(point)
		var inside := Vector2(box.half_x, box.half_z)
		if absf(local.x) < inside.x+.05 and absf(local.z) < inside.y+.05:
			var floor_y: float = TofuBox.FLOOR_TOP*box.rise
			if box.lidded and box.hole_at(Vector2(local.x, local.z), .12) < 0:
				floor_y = box.lid_top()
			var cx := clampf(local.x, -inside.x+GHOST_INSET, inside.x-GHOST_INSET)
			var cz := clampf(local.z, -inside.y+GHOST_INSET, inside.y-GHOST_INSET)
			return box.board.to_global(Vector3(cx, floor_y, cz))
	return Vector3(point.x, maxf(point.y, .12), point.z)

func _follow_flight(delta: float) -> void:
	var body := flying
	flight_time += delta
	var local := box.local(body.position)
	var lid := box.lid_top()
	if box.lidded and last_local.y >= lid-.05 and local.y < lid-.05:
		var hole := box.hole_at(Vector2(local.x, local.z), .1)
		if hole >= 0:
			crossed_hole = hole
			var gap: Vector2 = (Vector2(local.x, local.z)-(box.holes[hole].center as Vector2)).abs()
			crossed_offset = maxf(gap.x, gap.y)/float(box.holes[hole].half)
	last_local = local
	if body.touched_ground:
		if not skipped:
			skipped = true
			ground_time = flight_time
		if _blown_it(body):
			_miss(body)
			return
	if _off_table(body.position):
		_miss(body, true)
		return
	if body.linear_velocity.length() < REST_SPEED and body.angular_velocity.length() < REST_SPEED*2.5:
		still_time += delta
	else:
		still_time = 0.0
	if (still_time >= REST_SECONDS and flight_time > .6) or flight_time >= JUDGE_TIMEOUT:
		_judge(body)

## Keeps the box clipping on whatever is really inside the box, and takes back the points of any
## Kinu a later throw has knocked out.
func _track_box(delta: float) -> void:
	if not is_instance_valid(box) or not is_instance_valid(box.board):
		return
	RenderingServer.global_shader_parameter_set("toss_box_inverse", Projection(box.board.global_transform.affine_inverse()))
	RenderingServer.global_shader_parameter_set("toss_box_inside", Vector4(box.half_x, box.half_z, TofuBox.FLOOR_TOP*box.rise, box.rim()))
	if is_instance_valid(flying):
		_set_clip(flying, _down_inside(flying))
	for body in riders.duplicate():
		if not is_instance_valid(body):
			continue
		_set_clip(body, body.scored and _down_inside(body))
		if body.scored and run.state in ["aim", "settle"]:
			var gone := _off_table(body.position)
			var out := gone or box.classify(body.global_position) == "out"
			var out_time := float(body.get_meta("out_time", 0.0))+delta if out else 0.0
			body.set_meta("out_time", out_time)
			if gone or out_time >= KNOCKED_OUT_SECONDS:
				_knocked_out(body, gone)

## In the box and below the rim. Only then is anything past the walls an outfit poking through;
## a Kinu still straddling the rim is partly outside for real.
func _down_inside(body: KinuBody) -> bool:
	return box.classify(body.global_position) == "in" and box.local(body.global_position).y < box.rim()

func _set_clip(body: KinuBody, on: bool) -> void:
	if bool(body.get_meta("box_clip", false)) == on or not is_instance_valid(body.visual):
		return
	body.set_meta("box_clip", on)
	for node in body.visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if on:
			mesh.set_meta("unclipped", mesh.material_override)
			mesh.material_override = _clip_material(mesh.material_override)
		elif mesh.has_meta("unclipped"):
			mesh.material_override = mesh.get_meta("unclipped")

static func _clip_material(material: Material) -> Material:
	if not material is ShaderMaterial:
		return material
	if not clip_materials.has(material):
		var copy := (material as ShaderMaterial).duplicate() as ShaderMaterial
		copy.set_shader_parameter("box_clip", true)
		clip_materials[material] = copy
	return clip_materials[material]

## A scored Kinu knocked back out of the box by a later throw: its points, its place in the box's
## quota and its count towards missions all go back. It isn't a miss; the throw that did it is
## judged on its own.
func _knocked_out(body: KinuBody, gone: bool) -> void:
	var lost := int(body.get_meta("toss_points", 0))
	riders.erase(body)
	body.scored = false
	_set_clip(body, false)
	run.score = maxi(0, run.score-lost)
	run.placed = maxi(0, run.placed-1)
	box_kinu = maxi(0, box_kinu-1)
	for pair in [[run.flavour_counts, body.flavour.id], [run.shape_counts, body.shape.id]]:
		var counts: Dictionary = pair[0]
		counts[pair[1]] = maxi(0, int(counts.get(pair[1], 0))-1)
	body.mood_override = "worried"
	_popup("-%d"%lost, Color("e0463a"))
	run.message.emit(tr("Knocked out! -%d")%lost, Color("e0463a"))
	Sound.play("land", .8)
	Haptics.pulse(30, .5)
	run.updated.emit()
	_sweep_away(body, 0.0 if gone else .6)

## The first real knock ends the look of terror and the free flight: the usual air drag comes
## back. Anything it clips counts, which is what makes a bank shot behave like a bank shot.
func _struck(body: KinuBody, _other: Node, _force: float) -> void:
	if body != flying:
		return
	body.mood_override = ""
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_COMBINE
	body.linear_damp = .3
	body.angular_damp = 2.2

## True when a Kinu on the table has no chance left: the grace for skipping on has run out and it
## is neither in the box nor still travelling towards it. Waiting for a dribbling Kinu to come to
## a complete stop is dead time, and the throw is already decided.
func _blown_it(body: KinuBody) -> bool:
	if flight_time-ground_time < SKIP_GRACE:
		return false
	if box.classify(body.global_position) != "out":
		return false
	# A Kinu still skipping hard towards the box gets a little longer, but never more than a second.
	var toward := body.linear_velocity.z < -1.0 and body.position.z > box.position.z
	return not toward or flight_time-ground_time > 1.0

## True once a Kinu is past the edge of the playing surface: there is nothing left to watch, so
## the throw is called there and then rather than after a long fall.
func _off_table(p: Vector3) -> bool:
	if not p.is_finite():
		return true
	if p.y < -.35:
		return true
	return absf(p.x) > TossTable.HALF+.4 or p.z > MAT_Z+1.8 or p.z < -TossTable.END-.4

func _gravity() -> float:
	return maxf(float(ProjectSettings.get_setting("physics/3d/default_gravity")), 1.0)

func _judge(body: KinuBody) -> void:
	match box.classify(body.global_position):
		"in":
			_scored(body)
		"lid":
			_on_lid(body)
		_:
			_miss(body)

func _finish_throw() -> void:
	flying = null
	run.pending = null
	box_throws += 1
	if run.state in ["over", "falling"]:
		return
	if box_kinu >= box_quota or box_throws >= box_quota+SPARE_THROWS:
		_swap_box()
	else:
		_spawn()

func _scored(body: KinuBody) -> void:
	var local := box.local(body.global_position)
	var hole := crossed_hole if crossed_hole >= 0 else box.nearest_hole(Vector2(local.x, local.z))
	var tier: String = box.holes[hole].tier if hole >= 0 and box.lidded else "big"
	var info: Dictionary = TossBox.TIERS[tier]
	var centre := box.lid_center()
	var distance_cm := int(round(Vector2(centre.x-launch_point.x, centre.z-launch_point.z).length()*CM_PER_UNIT))
	longest_cm = maxi(longest_cm, distance_cm)
	run.longest_cm = longest_cm
	var worth := TossBox.points_for(box.holes[hole]) if hole >= 0 and box.lidded else TossBox.OPEN_POINTS
	var points := worth+distance_cm
	var label: String = info.name if box.lidded else "In"
	var perfect := box.lidded and crossed_hole >= 0 and crossed_offset < .4
	var standing := body.shape.id == "tall" and body.global_basis.y.normalized().dot(Vector3.UP) > .9
	if skipped:
		points += 150
		label = "Skip Shot"
	if standing:
		points += 150
		label = "Standing Kinu"
	if perfect:
		points += worth/2
		label = "Perfect"
	if tier == "gold":
		label = "Lucky Box"
		run.bonus_beans += GOLD_BEANS
	run.streak += 1
	run.best_streak = maxi(run.best_streak, run.streak)
	multiplier = minf(1.0+(run.streak-1)*STREAK_STEP, STREAK_CAP)
	var total := int(round(points*multiplier))
	run.score += total
	run.placed += 1
	box_kinu += 1
	riders.append(body)
	body.scored = true
	body.set_meta("toss_points", total)
	body.touched_ground = false
	body.mood_override = ""
	body.cheer()
	run.flavour_counts[body.flavour.id] = int(run.flavour_counts.get(body.flavour.id, 0))+1
	run.shape_counts[body.shape.id] = int(run.shape_counts.get(body.shape.id, 0))+1
	var discovered: bool = Save.discover(body.flavour.id)
	if discovered:
		run.new_flavours += 1
		run.last_new_flavour_placed = run.placed
	_popup("+%d"%total, info.color)
	var line := tr(label)+"! +%d"%total
	if multiplier > 1.0:
		line += "  ×%s"%str(snappedf(multiplier, .1)).trim_suffix(".0")
	var special := body.special
	body.mark_special("")
	if tier == "gold":
		line += "  ·  "+tr("+%d beans")%GOLD_BEANS
		Sound.play("highscore")
	elif special == "lucky":
		run.lucky_caught += 1
		run.bonus_beans += NestRun.LUCKY_BEANS
		line = tr("Lucky Kinu! +%d beans")%NestRun.LUCKY_BEANS
		Sound.play("special")
	elif special == "heart":
		run.hearts_caught += 1
		if run.tumbles > 0:
			run.tumbles -= 1
			line = tr("Heart Kinu! A miss came back")
		else:
			run.bonus_beans += NestRun.HEART_BEANS
			line = tr("Heart Kinu! +%d beans")%NestRun.HEART_BEANS
		Sound.play("special", 1.2)
	elif discovered:
		line = tr("New flavour: %s!")%tr(body.flavour.display_name)
		Sound.play("special", 1.2)
	else:
		Sound.play("combo" if multiplier > 1.0 else "special", clampf(.9+run.streak*.05, .9, 1.4))
	run.message.emit(line, (info.color as Color).darkened(.35) if tier != "big" else Color("3f8fe0"))
	Haptics.pulse(35, .55)
	run.action_done.emit("settle")
	run.updated.emit()
	_finish_throw()

## Resting on the lid is neither in nor out: a few points, the streak is lost, and the Kinu stays
## where it is to be banked off or knocked in until the box goes.
func _on_lid(body: KinuBody) -> void:
	run.streak = 0
	multiplier = 1.0
	run.score += LID_POINTS
	riders.append(body)
	body.mood_override = "worried"
	body.touched_ground = false
	_popup("+%d"%LID_POINTS, NestTheme.CREAM)
	run.message.emit(tr("On the lid! +%d")%LID_POINTS, Color("8a6d5a"))
	Sound.play("land", .9)
	run.updated.emit()
	_finish_throw()

## `gone` means the Kinu has already left the table, so it is taken away at once instead of being
## left lying about; one that stopped on the table gets a moment to be seen before it is cleared.
func _miss(body: KinuBody, gone: bool = false) -> void:
	body.fallen = true
	body.mood_override = ""
	run.fallen_body = body
	run.tumbles += 1
	run.streak = 0
	multiplier = 1.0
	run.orbit.shake = .5
	Sound.play("mistake")
	Haptics.pulse(60, .8)
	_sweep_away(body, 0.0 if gone else .5)
	var left := MAX_MISSES-run.tumbles
	if left > 0:
		run.message.emit(tr("Missed! 1 miss left") if left == 1 else tr("Missed! %d misses left")%left, Color("e0463a"))
		run.updated.emit()
		_finish_throw()
		return
	run.state = "falling"
	run.message.emit(tr("Six misses! Great tossing though!"), Color("e0463a"))
	run.updated.emit()
	flying = null
	run.pending = null
	await get_tree().create_timer(1.6, false).timeout
	if run.state == "falling":
		run.end()

## Takes a missed Kinu off the table after `wait` seconds.
func _sweep_away(body: KinuBody, wait: float) -> void:
	if wait > 0.0:
		await get_tree().create_timer(wait, false).timeout
	if not is_instance_valid(body):
		return
	run.bodies.erase(body)
	if run.fallen_body == body:
		run.fallen_body = null
	body.queue_free()

## A score that floats up off the box and fades.
func _popup(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = NestTheme.font
	label.font_size = 96
	label.outline_size = 28
	label.modulate = color
	label.outline_modulate = NestTheme.INK
	label.pixel_size = .006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	add_child(label)
	label.position = box.lid_center()+Vector3.UP*.8
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y+1.4, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, .5).set_delay(.6)
	tween.chain().tween_callback(label.queue_free)

# ---------- Camera ----------

## Just behind the Kinu at its eye level, looking almost flat down the table: the Kinu fills the
## bottom of the screen and the box waits out ahead, the way you'd line up a throw.
const EYE := Vector3(0, 2.1, MAT_Z+2.8)

func _wanted_focus() -> Vector3:
	var target := box.position if is_instance_valid(box) else Vector3(0, 0, -6)
	# A slight upward tilt: WAITING_LIFT does the real work of clearing the waiting Kinu above the
	# controls now, this just keeps the box framed comfortably alongside it.
	return Vector3(target.x*.3, EYE.y+.2, EYE.z-10.0)

func _place_camera(delta: float) -> void:
	focus = focus.lerp(_wanted_focus(), 1.0-exp(-delta*2.5))
	var eye := EYE+Vector3(aim_x*.3+focus.x*.2, 0, 0)
	var shake := run.orbit.shake
	if shake > 0.0:
		run.orbit.shake = maxf(0.0, shake-delta*1.8)
		eye += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0)*shake*.12
	camera.position = eye
	camera.look_at(focus)

# ---------- Helpers ----------

func distance_cm() -> int:
	if not is_instance_valid(box):
		return 0
	var centre := box.lid_center()
	return int(round(Vector2(centre.x-aim_x, centre.z-MAT_Z).length()*CM_PER_UNIT))
