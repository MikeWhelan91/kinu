class_name KinuBody
extends RigidBody3D
signal landed(body: KinuBody, other: Node, force: float)

const GRIP_DELAY := 0.45
const GRIP_SPEED := 0.35
const HAPPY_SECONDS := 1.4
const SQUISH_SECONDS := .4
## Jelly spring: stiffness and damping for the squash/lean wobble.
const JIGGLE_STIFFNESS := 150.0
const JIGGLE_DAMPING := 6.5

static var hitboxes: Dictionary = {}

var shape: KinuShape
var flavour: KinuFlavour
var outfit: KinuOutfit
var visual: Node3D
var mood: String = "calm"
var scored: bool = false
var fallen: bool = false
var touched_ground: bool = false
## Set once the balance check has tipped this piece. From then on real physics decides whether it
## stays put, so a piece wedged against the box can't be tipped over and over.
var tipped: bool = false
## Settled pieces "grip" the pile: they freeze in place until the tower tips or they are knocked loose.
var gripped: bool = false
var age: float = 0.0
var stable_time: float = 0.0
var grip_time: float = 0.0
var regrip_cooldown: float = 0.0
var impact_cooldown: float = 0.0
var previous_speed: float = 0.0
var sway: float = 0.0
var happy_time: float = 0.0
var squish_time: float = 0.0
var squash: float = 0.0
var squash_speed: float = 0.0
var lean := Vector2.ZERO
var lean_speed := Vector2.ZERO
var last_position := Vector3.ZERO
var last_velocity := Vector3.ZERO
var breath_phase: float = 0.0

func setup(kinu_shape: KinuShape, kinu_flavour: KinuFlavour, kinu_outfit: KinuOutfit = null) -> void:
	shape = kinu_shape
	flavour = kinu_flavour
	outfit = kinu_outfit
	mass = shape.mass
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = shape.friction
	physics_material_override.bounce = shape.bounce
	linear_damp = .3
	angular_damp = 2.2
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	collision_layer = 2
	collision_mask = 3
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	visual = KinuModel.build(shape, flavour, outfit)
	add_child(visual)
	breath_phase = randf()*TAU
	var collision := CollisionShape3D.new()
	collision.shape = hitbox(shape)
	add_child(collision)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -shape.size.y*.08, 0)
	body_entered.connect(_contact)

## Convex hull of the rounded box, slightly larger than the drawn body so neighbours rest
## outline-to-outline instead of sinking in and hiding the ink line between them.
static func hitbox(kinu_shape: KinuShape) -> ConvexPolygonShape3D:
	if not hitboxes.has(kinu_shape.id):
		var half := kinu_shape.size*.5+Vector3.ONE*KinuModel.OUTLINE_WIDTH
		var power := kinu_shape.roundness
		var points := PackedVector3Array()
		for ring in 11:
			var polar := PI*ring/10.0
			for segment in 16:
				var azimuth := TAU*segment/16.0
				var u := Vector3(sin(polar)*cos(azimuth), cos(polar), sin(polar)*sin(azimuth))
				points.append(Vector3(signf(u.x)*pow(absf(u.x), 2.0/power), signf(u.y)*pow(absf(u.y), 2.0/power), signf(u.z)*pow(absf(u.z), 2.0/power))*half)
		var hull := ConvexPolygonShape3D.new()
		hull.points = points
		hitboxes[kinu_shape.id] = hull
	return hitboxes[kinu_shape.id]

func footprint() -> float:
	return maxf(shape.size.x, shape.size.z)*.5

func cheer() -> void:
	happy_time = HAPPY_SECONDS

## Kicks the jelly spring; positive values squash down.
func poke(amount: float) -> void:
	squash_speed += clampf(amount, -3.5, 3.5)

func grip() -> void:
	gripped = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func release(impulse: Vector3 = Vector3.ZERO) -> void:
	if not gripped:
		return
	gripped = false
	freeze = false
	sleeping = false
	grip_time = 0
	regrip_cooldown = 1.2
	if impulse != Vector3.ZERO:
		apply_central_impulse(impulse*mass)
		apply_torque_impulse(Vector3(impulse.z, 0, -impulse.x)*mass*.35)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_jiggle(delta)
	happy_time = maxf(0, happy_time-delta)
	squish_time = maxf(0, squish_time-delta)
	var wanted := _wanted_mood()
	if wanted != mood:
		mood = wanted
		KinuModel.set_mood(visual, shape, mood, flavour.light_face)

func _wanted_mood() -> String:
	if fallen:
		return "falling"
	if sway > .25:
		return "worried"
	if squish_time > 0:
		return "squish"
	if happy_time > 0:
		return "happy"
	if scored:
		return "content"
	if not freeze and linear_velocity.y < -1.5:
		return "falling"
	return "calm"

## Soft-body feel without soft-body physics: a damped spring drives squash and lean of the
## visual only. Movement (including being carried while aiming) and impacts excite it.
func _jiggle(delta: float) -> void:
	var velocity := (global_position-last_position)/delta
	var acceleration := (velocity-last_velocity)/delta
	if last_position != Vector3.ZERO and acceleration.length() < 400.0:
		var local := global_basis.inverse()*acceleration
		lean_speed -= Vector2(local.x, local.z)*.0028
	last_position = global_position
	last_velocity = velocity
	squash_speed += (-JIGGLE_STIFFNESS*squash-JIGGLE_DAMPING*squash_speed)*delta
	squash += squash_speed*delta
	lean_speed += (-JIGGLE_STIFFNESS*lean-JIGGLE_DAMPING*lean_speed)*delta
	lean += lean_speed*delta
	lean = lean.limit_length(.35)
	var breath := sin(Time.get_ticks_msec()*.0024+breath_phase)*.012
	var s := clampf(squash+breath, -.3, .3)
	var h := shape.size.y*.5
	# Lean shears the top while the base stays planted.
	var basis := Basis(Vector3(1+s*.6, 0, 0), Vector3(lean.x, 1-s, lean.y), Vector3(0, 0, 1+s*.6))
	var wobble := sway*sin(Time.get_ticks_msec()*.012+position.y*1.7)*.09
	visual.transform = Transform3D(Basis(Vector3.BACK, wobble)*basis, Vector3(lean.x*h, -s*h, lean.y*h))

func _physics_process(delta: float) -> void:
	if freeze:
		return
	age += delta
	impact_cooldown = maxf(0, impact_cooldown-delta)
	regrip_cooldown = maxf(0, regrip_cooldown-delta)
	previous_speed = linear_velocity.length()
	if scored and not fallen and not touched_ground and regrip_cooldown <= 0:
		if previous_speed < GRIP_SPEED and angular_velocity.length() < GRIP_SPEED*1.5:
			grip_time += delta
			if grip_time >= GRIP_DELAY:
				grip()
		else:
			grip_time = 0

func _contact(other: Node) -> void:
	if other.is_in_group(TofuShop.GROUND_GROUP):
		touched_ground = true
	if impact_cooldown > 0 or age < .08 or previous_speed < 1.2:
		return
	impact_cooldown = .3
	poke(previous_speed*.6)
	squish_time = SQUISH_SECONDS
	if other is KinuBody:
		other.poke(previous_speed*.25)
	landed.emit(self, other, previous_speed)
