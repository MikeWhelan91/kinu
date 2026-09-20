class_name KinuBody
extends RigidBody3D
signal landed(body: KinuBody, other: Node, force: float)

const GRIP_DELAY := 0.45
const GRIP_SPEED := 0.35
## How far the centre of mass may sit outside its contact points and still count as supported.
const SUPPORT_MARGIN := .06
const HAPPY_SECONDS := 1.4
const SQUISH_SECONDS := .4
## Jelly spring: stiffness and damping for the squash/lean wobble.
const JIGGLE_STIFFNESS := 150.0
const JIGGLE_DAMPING := 6.5

## In-play Kinu are drawn and simulated a little smaller than their shape's base size; previews
## in the shop and book use the full size. Smaller Kinu leave more room to fit in the box.
const SCALE := 0.8

static var hitboxes: Dictionary = {}
## Scale this Kinu plays at: SCALE, or smaller for a Tiny Kinu.
var body_scale: float = SCALE

var shape: KinuShape
var flavour: KinuFlavour
## What the Kinu looks like: its flavour, or the costume finish being worn over it.
var look: KinuFlavour
var outfit: KinuOutfit
## Extra transform on the visual: identity, or KinuModel.ghost_fit for a Kinu wearing the ghost.
var fit := Transform3D.IDENTITY
## "", "lucky" or "heart". A floating badge marks special Kinu until they settle.
var special: String = ""
var special_marker: Node3D
## Glazed by the shoyu bottle: sticky for the rest of the run.
var sticky: bool = false
## Glued to a neighbour by shoyu (its own glaze, or a sticky Kinu it touched). The direct glue
## joint is secure; Kinu built beyond that joint still have to balance normally.
var stuck: bool = false
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
## Whether the centre of mass is over the points this Kinu rests on, from the last physics step.
## A piece balanced on an edge starts to tip very slowly, so low speed alone isn't enough to grip.
var supported: bool = false
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

func setup(kinu_shape: KinuShape, kinu_flavour: KinuFlavour, kinu_outfit: KinuOutfit = null, finish: KinuFlavour = null, size_scale: float = 1.0) -> void:
	shape = kinu_shape
	body_scale = SCALE*size_scale
	flavour = kinu_flavour
	look = finish if finish else kinu_flavour
	outfit = kinu_outfit if kinu_outfit and not kinu_outfit.finish else null
	mass = shape.mass*size_scale
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
	visual = KinuModel.build(shape, look, outfit)
	if outfit and outfit.style == "ghost":
		fit = KinuModel.ghost_fit(shape)
	add_child(visual)
	breath_phase = randf()*TAU
	var collision := CollisionShape3D.new()
	collision.shape = hitbox(shape, body_scale)
	add_child(collision)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -size().y*.08, 0)
	body_entered.connect(_contact)

## Convex hull of the rounded box, slightly larger than the drawn body so neighbours rest
## outline-to-outline instead of sinking in and hiding the ink line between them.
static func hitbox(kinu_shape: KinuShape, scale: float = SCALE) -> ConvexPolygonShape3D:
	var key := "%s@%.3f"%[kinu_shape.id, scale]
	if not hitboxes.has(key):
		var half := (kinu_shape.size*.5+Vector3.ONE*KinuModel.OUTLINE_WIDTH)*scale
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
		hitboxes[key] = hull
	return hitboxes[key]

func mark_special(kind: String) -> void:
	special = kind
	if is_instance_valid(special_marker):
		special_marker.queue_free()
		special_marker = null
	if kind in SpecialBadge.MARKED:
		special_marker = SpecialBadge.marker(kind)
		special_marker.top_level = true
		add_child(special_marker)

## The Kinu's size in play.
func size() -> Vector3:
	return shape.size*body_scale

## Shoyu from the bottle: coats this Kinu and glues it in place; anything landing on it sticks.
## Lit while a sauce is aimed at this Kinu, so you can see what a squirt will catch before you
## spend it. A box aura rather than an outline: it reads through a crowded pile from any angle.
var sauce_aura: MeshInstance3D

func set_sauce_target(on: bool, tint: Color = Color("00f5ff")) -> void:
	if on == is_instance_valid(sauce_aura):
		return
	if not on:
		sauce_aura.queue_free()
		sauce_aura = null
		return
	sauce_aura = MeshInstance3D.new()
	var box := BoxMesh.new()
	# Leave enough room around the body that the targeting colour is still visible when Kinu are
	# packed tightly together.
	box.size = size()*1.24
	sauce_aura.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint.r, tint.g, tint.b, .72)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.5
	sauce_aura.material_override = material
	sauce_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sauce_aura)

## Sauces resize a Kinu that is already packed. Body, mass, hitbox and centre of mass all move
## together; the drawn size follows body_scale through _jiggle, so nothing else needs telling.
## Returns false when the Kinu is already at the limit, so the sauce can report a wasted squirt.
func rescale(factor: float, low: float, high: float) -> bool:
	var wanted := clampf(body_scale*factor, SCALE*low, SCALE*high)
	if is_equal_approx(wanted, body_scale):
		return false
	body_scale = wanted
	mass = shape.mass*(body_scale/SCALE)
	for child in get_children():
		if child is CollisionShape3D:
			child.shape = hitbox(shape, body_scale)
	center_of_mass = Vector3(0, -size().y*.08, 0)
	# Squash going in, stretch coming out, so the change is felt and not just measured.
	poke(2.2 if factor < 1.0 else -2.2)
	return true

func glaze() -> void:
	sticky = true
	stuck = true
	if not visual.has_node("Sauce"):
		visual.add_child(KinuModel.glaze(shape, outfit))
		visual.add_child(KinuModel.glaze(shape, outfit, true))
	grip()
	poke(2.5)

## Sticky Kinu are born syrup-coated. They lock only after they meet another Kinu, so the
## player can still aim and place them normally.
func make_sticky() -> void:
	sticky = true
	if not visual.has_node("StickyCoat"):
		visual.add_child(KinuModel.sticky_coat(shape, outfit))

func stick() -> void:
	stuck = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	grip.call_deferred()
	poke(2.0)

## Glue belongs on the horizontal faces. The generous threshold tolerates the squash of an impact,
## while keeping a side brush or a leaning collision as normal physics.
func has_vertical_glue_contact(other: KinuBody) -> bool:
	var vertical := absf(other.global_position.y-global_position.y)
	return vertical >= (size().y+other.size().y)*.35

func footprint() -> float:
	return maxf(size().x, size().z)*.5

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
	if not gripped or stuck:
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
	if is_instance_valid(special_marker):
		var bob := sin(Time.get_ticks_msec()*.004)*.08
		special_marker.global_position = global_position+Vector3.UP*(size().y*.5+.55+bob)
	happy_time = maxf(0, happy_time-delta)
	squish_time = maxf(0, squish_time-delta)
	var wanted := _wanted_mood()
	if wanted != mood:
		mood = wanted
		KinuModel.set_mood(visual, shape, mood, look.light_face)

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
	var h := size().y*.5
	# Lean shears the top while the base stays planted.
	var basis := Basis(Vector3(1+s*.6, 0, 0), Vector3(lean.x, 1-s, lean.y), Vector3(0, 0, 1+s*.6))
	var wobble := sway*sin(Time.get_ticks_msec()*.012+position.y*1.7)*.09
	visual.transform = Transform3D(Basis(Vector3.BACK, wobble)*basis*Basis.from_scale(Vector3.ONE*body_scale), Vector3(lean.x*h, -s*h, lean.y*h))*fit

func _physics_process(delta: float) -> void:
	if freeze:
		return
	age += delta
	impact_cooldown = maxf(0, impact_cooldown-delta)
	regrip_cooldown = maxf(0, regrip_cooldown-delta)
	previous_speed = linear_velocity.length()
	if scored and not fallen and not touched_ground and regrip_cooldown <= 0:
		if supported and previous_speed < GRIP_SPEED and angular_velocity.length() < GRIP_SPEED*1.5:
			grip_time += delta
			if grip_time >= GRIP_DELAY:
				grip()
		else:
			grip_time = 0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var com := state.transform.origin+state.center_of_mass
	var points := PackedVector2Array()
	for i in state.get_contact_count():
		# Contacts that push up or sideways hold it up (including a piece it leans against);
		# something resting on top pushes down and doesn't.
		if state.get_contact_local_normal(i).y > -.2:
			var point := state.get_contact_local_position(i)
			points.append(Vector2(point.x, point.z))
	supported = is_over_support(Vector2(com.x, com.z), points)

## True when `com` lies over the support region spanned by `points`, within SUPPORT_MARGIN.
static func is_over_support(com: Vector2, points: PackedVector2Array) -> bool:
	if points.is_empty():
		return false
	var hull := Geometry2D.convex_hull(points) if points.size() >= 3 else PackedVector2Array()
	if hull.size() >= 4 and Geometry2D.is_point_in_polygon(com, hull):
		return true
	# Along the hull edges (or the lone point / segment) the margin absorbs contact jitter.
	var outline := hull if hull.size() >= 4 else points
	for i in outline.size():
		var next := outline[(i+1) % outline.size()]
		if com.distance_to(Geometry2D.get_closest_point_to_segment(com, outline[i], next)) <= SUPPORT_MARGIN:
			return true
	return false

func _contact(other: Node) -> void:
	if other.is_in_group(TofuShop.GROUND_GROUP):
		touched_ground = true
	elif not freeze and not stuck and age > .05 and other is KinuBody and has_vertical_glue_contact(other) and (sticky or other.sticky):
		# Syrup binds top-to-bottom only. A Sticky Kinu can make a dependable ledge, but side
		# collisions remain real physics instead of creating accidental floating scaffolds.
		stick()
		other.stick()
	if impact_cooldown > 0 or age < .08 or previous_speed < 1.2:
		return
	impact_cooldown = .3
	poke(previous_speed*.6)
	squish_time = SQUISH_SECONDS
	if other is KinuBody:
		other.poke(previous_speed*.25)
	landed.emit(self, other, previous_speed)
