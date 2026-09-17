class_name NestRun
extends Node3D
signal updated
signal message(text: String, color: Color)
signal finished(stats: Dictionary)
signal action_done(action: String)

var CONFIG: NestConfig = preload("res://resources/game_config/default.tres")
var catalog: KinuCatalog = preload("res://resources/kinu/catalog.tres")
var rng := RandomNumberGenerator.new()
var orbit := OrbitController.new()
var bodies: Array[KinuBody] = []
var active: KinuBody
var active_yaw: float = 0.0
var pending: KinuBody
var next_shape: KinuShape
var next_flavour: KinuFlavour
## "" for a normal Kinu, "lucky" (bonus beans) or "heart" (gives back a tumble).
var next_special: String = ""
var lucky_caught: int = 0
var squirts: int = SQUIRTS_START
## "kinu" while aiming a Kinu, "bottle" while aiming the shoyu bottle.
var aim_mode: String = "kinu"
var bottle: ShoyuBottle
## Only one Lucky Kinu may appear per run.
var lucky_spawned: bool = false
var hearts_caught: int = 0
var streak: int = 0
var best_streak: int = 0
## Seconds of play this run; pausing stops physics, so paused time isn't counted.
var run_time: float = 0.0
var squirts_used: int = 0
var glazed: int = 0
var new_flavours: int = 0
## Successful placements at the most recent discovery, used to keep discoveries feeling special.
var last_new_flavour_placed: int = -NEW_FLAVOUR_GAP
var shape_counts: Dictionary = {}
var bonus_beans: int = 0
var flavour_counts: Dictionary = {}
var state: String = "menu"
## The score is how many Kinu are on the pile right now: in the box or stacked on it, not on the counter.
var score: int = 0
var next_milestone: int = MILESTONE_STEP
var placed: int = 0
## Kinu that tumbled onto the counter this run; the run ends at MAX_TUMBLES.
var tumbles: int = 0
var tower_height: float = 0.0
var elapsed: float = 0.0
var hold_time: float = 0.0
var drop_height: float = 3.0
var beam: MeshInstance3D
var marker: MeshInstance3D
var marker_material: StandardMaterial3D
var last_shape: String = ""
var gesture: String = ""
var pointer_id: int = -99
var menu_mode: bool = true
var accepting_input: bool = true
var fallen_body: KinuBody
var grab_lift: float = 0.0
var room: TofuShop
var box: TofuBox
## Space kept clear at the bottom of the screen (home indicator, rounded corners), in viewport pixels.
var bottom_inset: float = 20.0
## 0 = rock solid, 1 = the part above `wobble_cut` is past its support and about to tip.
var wobble: float = 0.0
var wobble_cut: float = 0.0
var wobble_direction: Vector3 = Vector3.ZERO
var overbalanced_time: float = 0.0
var balance_timer: float = 0.0

const LEVEL_STEP := .75
const MAX_TUMBLES := 3
const MILESTONE_STEP := 10
const LUCKY_BEANS := 10
const LUCKY_CHANCE := .06
## Lucky/Gold Star Kinu are a mid-run surprise, never an opening drop.
const LUCKY_MIN_PLACED := 12
const HEART_CHANCE := .12
const TINY_CHANCE := .08
## Familiar Kinu establish each pile before an unseen flavour can join it. Once eligible, unseen
## flavours use their own small draw rather than competing at full weight with familiar ones.
const NEW_FLAVOUR_FIRST_DROP := 5
const NEW_FLAVOUR_CHANCE := .20
const NEW_FLAVOUR_GAP := 5
## Shoyu bottle: squirts at the start of a run, one more per pile milestone, up to a cap.
const SQUIRTS_START := 1
const SQUIRTS_MAX := 3
const SQUIRT_EVERY := 20
const TINY_SCALE := .62
## Fallen Kinu stay on the counter this long before they are cleared away.
const FALLEN_LINGER := 1.5
const WOBBLE_WARN := .7
## How long a section can sit overbalanced before it tips: more time to react before disaster.
const TIP_HOLD := .7
const KNOCK_LOOSE_SPEED := 5.0
## Touches this close (viewport pixels) to the held Kinu, or to its drop line, grab it.
const GRAB_RADIUS := 120.0
const GRAB_LINE_RADIUS := 70.0
## New Kinu arrive off-centre and turned, so every drop needs aiming (and often a spin).
const SPAWN_MIN_OFFSET := .6
const SPAWN_MAX_OFFSET := 1.2
const SPAWN_MAX_TURN := .5

func _ready() -> void:
	KinuProgress.register(catalog)
	rng.randomize()
	refresh_decor()
	orbit.camera = Camera3D.new()
	orbit.camera.fov = 52
	orbit.camera.keep_aspect = Camera3D.KEEP_WIDTH
	# A tight near/far range keeps depth precision high enough that nearby surfaces don't flicker.
	orbit.camera.near = .25
	orbit.camera.far = 120.0
	orbit.camera.current = true
	add_child(orbit.camera)
	beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = .035
	beam_mesh.bottom_radius = .035
	beam_mesh.height = 1.0
	beam.mesh = beam_mesh
	beam.material_override = _flat(Color(1, 1, 1, .55))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	marker = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = .42
	disc.bottom_radius = .42
	disc.height = .01
	marker.mesh = disc
	marker_material = _flat(Color(.15, .08, .2, .3))
	marker.material_override = marker_material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	show_menu()

func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

func _clear() -> void:
	if is_instance_valid(bottle):
		bottle.queue_free()
	bottle = null
	aim_mode = "kinu"
	active = null
	pending = null
	fallen_body = null
	wobble = 0
	overbalanced_time = 0
	for body in bodies:
		if is_instance_valid(body):
			remove_child(body)
			body.queue_free()
	bodies.clear()
	gesture = ""
	pointer_id = -99

func decor_outdated() -> bool:
	return box == null or room == null or box.decor != catalog.find_decor("box", str(Save.data.box)) or room.decor != catalog.find_decor("room", str(Save.data.room))

## Rebuilds the box and room if the equipped skins changed (e.g. after a shop visit).
func refresh_decor() -> void:
	var box_decor := catalog.find_decor("box", str(Save.data.box))
	if box == null or box.decor != box_decor:
		if box:
			box.free()
		box = TofuBox.new()
		box.decor = box_decor
		add_child(box)
	var room_decor := catalog.find_decor("room", str(Save.data.room))
	if room == null or room.decor != room_decor:
		if room:
			room.free()
		room = TofuShop.new()
		room.decor = room_decor
		add_child(room)

func show_menu() -> void:
	refresh_decor()
	_clear()
	state = "menu"
	menu_mode = true
	beam.hide()
	marker.hide()
	orbit.stop_spin()
	orbit.angle = .35
	orbit.target_angle = .35
	orbit.tower_top = 0
	# A run can leave the view tilted and raised for a tall tower. Snap both back so the home
	# camera is always framed the same, instead of starting low or gliding down after a run.
	orbit.tilt = 0.0
	orbit.focus_height = OrbitController.BASE_FOCUS
	orbit.shake = 0.0
	# A deliberately arranged, gripped tableau keeps the home screen full and every face readable;
	# gameplay still uses real falling and settling physics.
	var pile := [
		["slab", "silken", Vector3(-1.05, .46, .62), .18], ["long", "sesame", Vector3(0, .50, -.72), .04],
		["slab", "fried", Vector3(1.05, .46, .62), -.18], ["block", "matcha", Vector3(-1.02, 1.12, .55), .16],
		["block", "silken", Vector3(0, 1.08, -.62), -.08], ["block", "tamago", Vector3(1.02, 1.12, .55), -.18],
		["ball", "sakura", Vector3(-.58, 1.92, .18), .08], ["block", "fried", Vector3(.62, 1.90, .18), -.14],
		["tall", "silken", Vector3(0, 2.78, .12), .04]]
	for i in pile.size():
		var entry: Array = pile[i]
		# The home tableau previews the actual run: every Kinu wears the equipped outfit.
		var body := make_body(_shape(entry[0]), _flavour(entry[1]))
		body.position = entry[2]
		body.rotation.y = entry[3]
		body.scored = true
		body.grip()

func _shape(id: String) -> KinuShape:
	for item in catalog.shapes:
		if item.id == id:
			return item
	return catalog.shapes[0]

func _flavour(id: String) -> KinuFlavour:
	for item in catalog.flavours:
		if item.id == id:
			return item
	return catalog.flavours[0]

func begin() -> void:
	refresh_decor()
	_clear()
	menu_mode = false
	score = 0
	next_milestone = MILESTONE_STEP
	placed = 0
	tumbles = 0
	next_special = ""
	lucky_caught = 0
	lucky_spawned = false
	squirts = SQUIRTS_START
	aim_mode = "kinu"
	hearts_caught = 0
	streak = 0
	best_streak = 0
	run_time = 0.0
	squirts_used = 0
	glazed = 0
	new_flavours = 0
	last_new_flavour_placed = -NEW_FLAVOUR_GAP
	shape_counts = {}
	orbit.tilt = 0.0
	orbit.travelled = 0.0
	bonus_beans = 0
	flavour_counts = {}
	tower_height = 0
	elapsed = 0
	last_shape = ""
	orbit.lateral = 0
	orbit.depth = 0
	orbit.stop_spin()
	orbit.target_angle = 0
	orbit.angle = 0
	orbit.tower_top = 0
	orbit.focus_height = OrbitController.BASE_FOCUS
	choose_next()
	state = "ready"
	_spawn()

func choose_next() -> void:
	var shape_weights: Array[float] = []
	for item in catalog.shapes:
		var weight := item.spawn_weight
		# Early turns favour forgiving shapes; awkward ones arrive as the tower grows.
		if item.tricky:
			weight *= lerpf(.3, 1.3, clampf(placed/25.0, 0, 1))
		if item.id == last_shape:
			weight *= .35
		shape_weights.append(weight)
	next_shape = catalog.shapes[_weighted(shape_weights)]
	last_shape = next_shape.id
	next_flavour = _choose_flavour()
	next_special = ""
	if placed >= 3 and not menu_mode:
		var roll := rng.randf()
		if tumbles > 0 and roll < HEART_CHANCE:
			next_special = "heart"
		elif placed >= LUCKY_MIN_PLACED and roll > 1.0-LUCKY_CHANCE and not lucky_spawned:
			next_special = "lucky"
			lucky_spawned = true
		elif roll > 1.0-LUCKY_CHANCE-TINY_CHANCE and roll <= 1.0-LUCKY_CHANCE:
			next_special = "tiny"

## Pick familiar flavours normally, then occasionally draw from the unseen pool once the run has
## warmed up. The active check prevents two discoveries being queued back-to-back.
func _choose_flavour() -> KinuFlavour:
	var pool := flavour_mix()
	var known: Array[KinuFlavour] = []
	var unseen: Array[KinuFlavour] = []
	for item in pool:
		if Save.data.discovered.has(item.id):
			known.append(item)
		else:
			unseen.append(item)
	# Respecting the mix must not force an unseen flavour into an opening drop. If every familiar
	# flavour was switched off, temporarily use the familiar unlocked pool for the warm-up.
	if known.is_empty() and not Save.data.discovered.is_empty():
		for item in unlocked_flavours():
			if Save.data.discovered.has(item.id):
				known.append(item)
	# A fresh save has no familiar flavour yet, so Silken (the first catalogue entry) introduces
	# itself on the opening drop. Every later discovery follows the paced path below.
	if known.is_empty():
		return pool[0]
	var active_is_unseen: bool = is_instance_valid(active) and active.flavour != null and not Save.data.discovered.has(active.flavour.id)
	var drop_number := placed+2 if is_instance_valid(active) else placed+1
	var discovery_ready: bool = drop_number >= NEW_FLAVOUR_FIRST_DROP \
		and placed-last_new_flavour_placed >= NEW_FLAVOUR_GAP \
		and not active_is_unseen and not unseen.is_empty()
	var candidates := unseen if discovery_ready and rng.randf() < NEW_FLAVOUR_CHANCE else known
	var weights: Array[float] = []
	for item in candidates:
		weights.append(item.spawn_weight)
	return candidates[_weighted(weights)]

## Flavours whose pile goal has been reached; these are what can spawn.
func unlocked_flavours() -> Array[KinuFlavour]:
	var pool: Array[KinuFlavour] = []
	for item in catalog.flavours:
		if Save.flavour_unlocked(item):
			pool.append(item)
	return pool

## Unlocked flavours the player has left switched on in the Kinu Book. Never empty.
func flavour_mix() -> Array[KinuFlavour]:
	var unlocked := unlocked_flavours()
	var mix := unlocked.filter(func(item: KinuFlavour) -> bool: return Save.flavour_in_mix(item.id))
	return mix if not mix.is_empty() else unlocked

func _weighted(weights: Array[float]) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	var choice := rng.randf()*total
	for i in weights.size():
		choice -= weights[i]
		if choice <= 0:
			return i
	return 0

## The pattern a Kinu of this flavour wears, or null. A flavour not found yet always shows itself,
## so the "New flavour" moment matches what lands in the box.
func pattern_for(flavour: KinuFlavour) -> KinuFlavour:
	return catalog.pattern(str(Save.data.outfit)) if Save.flavour_found(flavour) else null

## Every Kinu wears the equipped outfit: a costume, or a pattern outfit's look over its flavour.
func make_body(shape: KinuShape, flavour: KinuFlavour, special: String = "", wear_outfit: bool = true) -> KinuBody:
	var body := KinuBody.new()
	var finish: KinuFlavour = pattern_for(flavour) if wear_outfit else null
	if special == "lucky":
		finish = catalog.finish("gold")
	body.setup(shape, flavour, catalog.outfit(str(Save.data.outfit)) if wear_outfit else null, finish, TINY_SCALE if special == "tiny" else 1.0)
	body.mark_special(special)
	add_child(body)
	body.landed.connect(_landed)
	bodies.append(body)
	return body

func tower_top() -> float:
	var top := TofuBox.RIM_HEIGHT*.4
	for body in bodies:
		if body != active and not body.fallen and body.scored and body.linear_velocity.length() < 2.0:
			top = maxf(top, body.position.y+body.size().y*.45)
	return top

func _spawn() -> void:
	if state in ["over", "falling"]:
		return
	active = make_body(next_shape, next_flavour, next_special)
	if placed >= 2 and squirts > 0 and not Save.data.seen_specials.has("bottle"):
		Save.data.seen_specials.append("bottle")
		Save.persist()
		message.emit(tr("Tap the shoyu bottle to glue Kinu together!"), Color("a8612c"))
	elif active.special != "" and not Save.data.seen_specials.has(active.special):
		Save.data.seen_specials.append(active.special)
		Save.persist()
		message.emit(tr(SpecialBadge.INTRO[active.special]), SpecialBadge.COLORS[active.special].darkened(.25))
	active.freeze = true
	active.collision_layer = 0
	active.collision_mask = 0
	# Roughly facing the player, but turned enough that edges rarely line up by themselves.
	active_yaw = rng.randf_range(-SPAWN_MAX_TURN, SPAWN_MAX_TURN)
	var spot := Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(SPAWN_MIN_OFFSET, SPAWN_MAX_OFFSET)
	orbit.lateral = spot.x
	orbit.depth = spot.y
	choose_next()
	var top := tower_top()
	orbit.tower_top = top
	if placed > 0:
		tower_height = maxf(tower_height, top)
	drop_height = maxf(3.0, top+1.4)
	hold_time = 0
	active.position = orbit.drop_position(drop_height)
	state = "aim"
	beam.show()
	marker.show()
	updated.emit()

func drop() -> void:
	if state != "aim" or active == null:
		return
	if aim_mode == "bottle":
		_squirt()
		return
	state = "settle"
	active.position = orbit.drop_position(drop_height)
	active.collision_layer = 2
	active.collision_mask = 3
	active.freeze = false
	active.sleeping = false
	active.linear_velocity = Vector3.DOWN*.5
	pending = active
	active = null
	elapsed = 0
	beam.hide()
	marker.hide()
	Haptics.pulse()
	action_done.emit("drop")
	updated.emit()

func _physics_process(delta: float) -> void:
	orbit.update(delta, menu_mode)
	if state in ["menu", "over"]:
		return
	run_time += delta
	if active:
		hold_time += delta
		drop_height = lerpf(drop_height, maxf(3.0, orbit.tower_top+1.4), 1.0-exp(-delta*4))
		grab_lift = lerpf(grab_lift, .3 if gesture == "aim" else 0.0, 1.0-exp(-delta*14))
		active.position = orbit.drop_position(drop_height)+Vector3.UP*(sin(hold_time*3.4)*.05+grab_lift)
		active.rotation.y = orbit.angle+active_yaw
		if is_instance_valid(bottle) and not bottle.tipping:
			bottle.position = active.position+Vector3.UP*.3
			bottle.rotation.y = orbit.angle
		_update_guide()
	if state == "falling":
		elapsed += delta
		if elapsed > 1.8:
			end()
		return
	for body in bodies:
		# Ground contact counts even for a gripped (frozen) piece resting against the nest.
		if not body.fallen and body != active and (body.touched_ground or (not body.freeze and is_fallen(body))):
			_fall(body)
			if state == "falling":
				return
	balance_timer -= delta
	if balance_timer <= 0:
		balance_timer = .1
		_measure_balance()
		orbit.tower_top = tower_top()
	if wobble >= 1.0:
		overbalanced_time += delta
		if overbalanced_time >= TIP_HOLD:
			_tip()
	else:
		overbalanced_time = maxf(0, overbalanced_time-delta*2)
	if state == "settle":
		elapsed += delta
		if not is_instance_valid(pending):
			_spawn()
			return
		if pending.sleeping or (pending.linear_velocity.length() < CONFIG.settle_linear_speed and pending.angular_velocity.length() < CONFIG.settle_angular_speed):
			pending.stable_time += delta
		else:
			pending.stable_time = 0
		if (pending.stable_time >= CONFIG.settle_hold_seconds and elapsed > .5) or elapsed >= CONFIG.settle_timeout:
			_settle()

## Slices the pile into levels. For each cut, everything above it must have its centre of
## mass over the footprint of the pieces just below (or over the nest, for the first level).
func _measure_balance() -> void:
	var pile: Array[KinuBody] = []
	for body in bodies:
		if is_instance_valid(body) and body.scored and not body.fallen and body != active:
			pile.append(body)
	var worst := 0.0
	var worst_cut := 0.0
	var worst_direction := Vector3.ZERO
	var cut := TofuBox.RIM_HEIGHT*.85
	while true:
		var weight := 0.0
		var com := Vector2.ZERO
		var support: Array[KinuBody] = []
		for body in pile:
			if body.position.y >= cut:
				if body.tipped or body.stuck:
					continue
				weight += body.mass
				com += Vector2(body.position.x, body.position.z)*body.mass
			elif body.position.y >= cut-LEVEL_STEP*1.2:
				support.append(body)
		if weight == 0.0:
			break
		com /= weight
		var center := Vector2.ZERO
		var ratio: float
		if cut <= TofuBox.RIM_HEIGHT or support.is_empty():
			# The box itself is the support: a square, so measure against its outer walls.
			ratio = maxf(absf(com.x), absf(com.y))/(TofuBox.INNER_HALF+TofuBox.WALL)
		else:
			for body in support:
				center += Vector2(body.position.x, body.position.z)
			center /= support.size()
			var radius := 0.0
			for body in support:
				radius = maxf(radius, Vector2(body.position.x, body.position.z).distance_to(center)+body.footprint())
			ratio = com.distance_to(center)/maxf(radius, .3)
		if ratio >= WOBBLE_WARN and _held_up(pile, cut, com, support):
			ratio = minf(ratio, WOBBLE_WARN*.8)
		if ratio > worst:
			worst = ratio
			worst_cut = cut
			var lean := (com-center).normalized()
			worst_direction = Vector3(lean.x, 0, lean.y)
		cut += LEVEL_STEP
	wobble = worst
	wobble_cut = worst_cut
	wobble_direction = worst_direction
	var sway := clampf((wobble-WOBBLE_WARN)/(1.0-WOBBLE_WARN), 0, 1)
	for body in pile:
		body.sway = sway if body.position.y >= wobble_cut and not body.tipped else 0.0

## A second opinion before warning or tipping: probe straight down around the footprint of every
## loose piece above `cut` to find where it actually rests (on any Kinu, glued ones included, or
## the box). The section is held up if its centre of mass lies within those resting points.
## The probes ring the footprint and never sample the centre: a probe under the centre of a lone
## piece lands at its own centre of mass, which would call any piece with something below it
## supported, however far it overhangs.
func _held_up(pile: Array[KinuBody], cut: float, com: Vector2, support: Array[KinuBody]) -> bool:
	var loose: Array[KinuBody] = []
	var excluded: Array[RID] = []
	for body in pile:
		if body.position.y >= cut and not body.tipped and not body.stuck:
			loose.append(body)
			excluded.append(body.get_rid())
	var space := get_world_3d().direct_space_state
	var resting := PackedVector2Array()
	for body in loose:
		var b := body.global_basis.orthonormalized()
		var reach := (absf(b.x.y)*body.size().x+absf(b.y.y)*body.size().y+absf(b.z.y)*body.size().z)*.5
		var bottom := body.position.y-reach
		var spread := body.footprint()*.7
		var corner := spread*.7
		for offset in [Vector2(spread, 0), Vector2(-spread, 0), Vector2(0, spread), Vector2(0, -spread),
				Vector2(corner, corner), Vector2(-corner, corner), Vector2(corner, -corner), Vector2(-corner, -corner)]:
			var from := Vector3(body.position.x+offset.x, bottom+.1, body.position.z+offset.y)
			var query := PhysicsRayQueryParameters3D.create(from, from-Vector3.UP*.4, 3, excluded)
			var hit := space.intersect_ray(query)
			if not hit.is_empty() and not (hit.collider as Node).is_in_group(TofuShop.GROUND_GROUP):
				resting.append(Vector2(from.x, from.z))
	if resting.size() >= 3:
		var hull := Geometry2D.convex_hull(resting)
		# convex_hull closes the ring, so three corners come back as four points.
		if hull.size() >= 4 and Geometry2D.is_point_in_polygon(com, hull):
			return true
	# Too few probes landed to form a footprint: the centre of mass has to sit right on them.
	if resting.size() == 1 and com.distance_to(resting[0]) < .12:
		return true
	if resting.size() == 2 and com.distance_to(Geometry2D.get_closest_point_to_segment(com, resting[0], resting[1])) < .12:
		return true
	# Fall back to the pieces carrying this level, for sections bridging between separate stacks.
	var points := PackedVector2Array()
	for body in support:
		points.append(Vector2(body.position.x, body.position.z))
	if points.size() >= 3:
		return Geometry2D.is_point_in_polygon(com, Geometry2D.convex_hull(points))
	return false

func _tip() -> void:
	overbalanced_time = 0
	var loosened := 0
	for body in bodies:
		if body.gripped and not body.tipped and not body.stuck and body.position.y >= wobble_cut-.2:
			body.tipped = true
			var lift := clampf((body.position.y-wobble_cut)*.25, 0, 1)
			body.release(wobble_direction*(.9+lift)+Vector3.UP*.3)
			loosened += 1
	if loosened > 0:
		orbit.shake = .35
		Sound.play("heavy", .7)
		Haptics.pulse(40, .6)
		message.emit(tr("Timber!"), Color("ff8a1f"))

## Swaps the held Kinu for the shoyu bottle, or puts the bottle away again.
func toggle_bottle() -> void:
	if state != "aim" or active == null:
		return
	if aim_mode == "bottle":
		aim_mode = "kinu"
		if is_instance_valid(bottle):
			bottle.queue_free()
		bottle = null
		active.visible = true
	elif squirts > 0:
		aim_mode = "bottle"
		bottle = ShoyuBottle.new()
		add_child(bottle)
		bottle.position = active.position+Vector3.UP*.3
		active.visible = false
		Sound.play("tap")
	updated.emit()

func _squirt() -> void:
	state = "squirting"
	squirts -= 1
	squirts_used += 1
	beam.hide()
	marker.hide()
	var from := bottle.position
	var query := PhysicsRayQueryParameters3D.create(from, from-Vector3.UP*30, 3)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: KinuBody = null
	var point := Vector3.INF
	if not hit.is_empty():
		point = hit.position
		if hit.collider is KinuBody and hit.collider.scored and not hit.collider.fallen:
			target = hit.collider
	bottle.squirted.connect(_squirted)
	bottle.squirt(target, point)
	Sound.play("sauce", .7)
	Haptics.pulse(20, .3)
	updated.emit()

func _squirted(target: KinuBody) -> void:
	bottle = null
	aim_mode = "kinu"
	if is_instance_valid(target) and not target.fallen:
		target.glaze()
		glazed += 1
		message.emit(tr("Glued! Drop a Kinu on it"), Color("a8612c"))
		Sound.play("land", .8)
	else:
		message.emit(tr("Splat! Missed"), Color("8a6d5a"))
	action_done.emit("squirt")
	if state != "squirting":
		return
	state = "aim"
	if is_instance_valid(active):
		active.visible = true
		beam.show()
		marker.show()
	updated.emit()

func _update_guide() -> void:
	var from := active.position-Vector3.UP*active.size().y*.5
	var query := PhysicsRayQueryParameters3D.create(from, from-Vector3.UP*30, 3)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var ground: Vector3 = hit.get("position", Vector3(from.x, 0, from.z))
	marker.position = ground+Vector3.UP*.02
	var unsafe := not TofuBox.contains(ground) and ground.y < .35
	marker_material.albedo_color = Color(.95, .2, .2, .45) if unsafe else Color(.15, .08, .2, .3)
	var length := maxf(.01, from.y-ground.y)
	beam.position = (from+ground)*.5
	beam.scale = Vector3(1, length, 1)

func is_fallen(body: KinuBody) -> bool:
	var p := body.position
	if not p.is_finite() or p.y < -.6:
		return true
	var radius := Vector2(p.x, p.z).length()
	return radius > TofuShop.COUNTER_HALF*1.5 or (not TofuBox.contains(p, .35) and p.y < TofuBox.RIM_HEIGHT*.75)

func _fall(body: KinuBody) -> void:
	body.fallen = true
	fallen_body = body
	tumbles += 1
	streak = 0
	if body == pending:
		pending = null
	score = pile_count()
	orbit.shake = .5
	Sound.play("mistake")
	Haptics.pulse(60, .8)
	_clear_fallen(body)
	if tumbles < MAX_TUMBLES:
		var left := MAX_TUMBLES-tumbles
		message.emit(tr("Kinu tumbled off! 1 tumble left") if left == 1 else tr("Kinu tumbled off! %d tumbles left")%left, Color("e0463a"))
		updated.emit()
		return
	state = "falling"
	elapsed = 0
	if active:
		bodies.erase(active)
		active.queue_free()
		active = null
	beam.hide()
	marker.hide()
	gesture = ""
	message.emit(tr("Oh no! That's three tumbles!"), Color("e0463a"))
	updated.emit()

## Fallen Kinu are cleared off the counter so they can't prop up or knock into the pile.
func _clear_fallen(body: KinuBody) -> void:
	await get_tree().create_timer(FALLEN_LINGER, false).timeout
	if not is_instance_valid(body) or state == "over":
		return
	bodies.erase(body)
	if fallen_body == body:
		fallen_body = null
	body.queue_free()

## Kinu counted on the pile: settled at least once and not fallen onto the counter.
func pile_count() -> int:
	var count := 0
	for body in bodies:
		if is_instance_valid(body) and body.scored and not body.fallen:
			count += 1
	return count

func _settle() -> void:
	if not pending or pending.fallen:
		return
	pending.scored = true
	placed += 1
	tower_height = maxf(tower_height, tower_top())
	score = pile_count()
	pending.cheer()
	flavour_counts[pending.flavour.id] = int(flavour_counts.get(pending.flavour.id, 0))+1
	shape_counts[pending.shape.id] = int(shape_counts.get(pending.shape.id, 0))+1
	streak += 1
	best_streak = maxi(best_streak, streak)
	var discovered: bool = Save.discover(pending.flavour.id)
	if discovered:
		new_flavours += 1
		last_new_flavour_placed = placed
	var milestone := score >= next_milestone
	var earned_squirt := false
	if milestone:
		next_milestone = (score/MILESTONE_STEP+1)*MILESTONE_STEP
		if squirts < SQUIRTS_MAX and score/MILESTONE_STEP*MILESTONE_STEP % SQUIRT_EVERY == 0:
			squirts += 1
			earned_squirt = true
	var special := pending.special
	pending.mark_special("")
	if special == "lucky":
		lucky_caught += 1
		bonus_beans += LUCKY_BEANS
		message.emit(tr("Lucky Kinu! +%d beans")%LUCKY_BEANS, Color("e0a81f"))
		Sound.play("special")
		Haptics.pulse(35, .55)
	elif special == "heart":
		hearts_caught += 1
		if tumbles > 0:
			tumbles -= 1
			message.emit(tr("Heart Kinu! A tumble came back"), Color("ff5d8f"))
		else:
			bonus_beans += 5
			message.emit(tr("Heart Kinu! +5 beans"), Color("ff5d8f"))
		Sound.play("special", 1.2)
		Haptics.pulse(35, .55)
	elif milestone:
		var reached := score/MILESTONE_STEP*MILESTONE_STEP
		message.emit(tr("%d Kinu! +1 shoyu squirt")%reached if earned_squirt else tr("%d Kinu! Amazing!")%reached, Color("ff8a1f"))
		Sound.play("special")
		Haptics.pulse(35, .55)
	elif discovered:
		message.emit(tr("New flavour: %s!")%tr(pending.flavour.display_name), Color("3f8fe0"))
		Sound.play("special", 1.2)
	pending = null
	action_done.emit("settle")
	_spawn()

func end() -> void:
	if state == "over":
		return
	state = "over"
	for body in bodies:
		body.freeze = true
		body.sway = 0
	beam.hide()
	marker.hide()
	if active:
		bodies.erase(active)
		active.queue_free()
		active = null
	finished.emit(summary())

## Everything the results screen, lifetime stats and daily missions need about this run.
func summary() -> Dictionary:
	return {"score": score, "placed": placed, "height": tower_height, "tumbles": tumbles, "lucky": lucky_caught, "hearts": hearts_caught, "bonus": bonus_beans, "flavours": flavour_counts.duplicate(), "shapes": shape_counts.duplicate(), "streak": best_streak, "time": run_time, "squirts": squirts_used, "glazed": glazed, "turns": int(orbit.travelled/TAU), "new_flavours": new_flavours, "dressed": str(Save.data.outfit) != "", "decorated": str(Save.data.room) != "shop" or str(Save.data.box) != "hinoki"}

func _landed(body: KinuBody, other: Node, force: float) -> void:
	if menu_mode or state == "over":
		return
	# A heavy landing jolts the piece it hits free of the pile.
	if other is KinuBody and other.gripped and force*body.mass > KNOCK_LOOSE_SPEED:
		other.release((other.position-body.position)*Vector3(1, 0, 1)*.4)
	Sound.play("drop", clampf(1.3-body.mass*.15, .8, 1.25))
	if force > 4:
		Haptics.pulse(12, .25)

## Soybeans for a run: 1 per Kinu on the pile, 2 more for every 10, and 5 more for a new best.
static func beans_for(score: int, record: bool) -> int:
	return score+score/10*2+(5 if record else 0)

## Names of flavours whose pile goal lies above the old best and at or below the new one.
static func unlocks_between(flavours: Array[KinuFlavour], old_best: int, new_best: int) -> Array[String]:
	var names: Array[String] = []
	for item in flavours:
		if item.unlock_kinu > old_best and item.unlock_kinu <= new_best:
			names.append(item.display_name)
	return names

static func height_cm(height: float) -> int:
	return int(round(maxf(0, height-TofuBox.FLOOR_TOP)*20))

func height_label(height: float = tower_height) -> String:
	return "%d cm"%height_cm(height)

## "classic": drag anywhere above the bottom strip to move, swipe the strip to spin.
## "grab": press on Kinu to move it, swipe anywhere else to spin.
func control_scheme() -> String:
	return str(Save.data.get("controls", "classic"))

func spin_zone_top() -> float:
	return get_viewport().get_visible_rect().size.y*.78

## The classic spin strip: only touches that start inside it spin the box.
func spin_strip_rect() -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var top := spin_zone_top()
	return Rect2(Vector2(14, top), Vector2(view.x-28, view.y-top-bottom_inset-8))

## True when a touch lands on the held Kinu or the drop line beneath it.
func grabs_active(point: Vector2) -> bool:
	if active == null or not active.is_inside_tree():
		return false
	var held := orbit.camera.unproject_position(active.global_position)
	if point.distance_to(held) <= GRAB_RADIUS:
		return true
	var landing := orbit.camera.unproject_position(marker.global_position)
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, held, landing)) <= GRAB_LINE_RADIUS

func _unhandled_input(event: InputEvent) -> void:
	if not accepting_input or state not in ["aim", "settle"]:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				if not event.echo:
					drop()
			KEY_LEFT, KEY_RIGHT, KEY_UP:
				var direction := {KEY_LEFT: Vector2(-24, 0), KEY_RIGHT: Vector2(24, 0), KEY_UP: Vector2(0, -24)}
				orbit.move_drop(direction[event.keycode])
				action_done.emit("aim")
			KEY_A, KEY_D:
				orbit.orbit(-40 if event.keycode == KEY_A else 40)
				orbit.release_spin()
				action_done.emit("spin")
		return
	# The claw scheme's two joysticks and its Drop button own touch entirely (each claims its own
	# finger the moment it lands); there's no free-drag fallback for a touch that lands elsewhere.
	if control_scheme() == "claw":
		return
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id == -99:
			pointer_id = event.index
			_begin_gesture(event.position)
		elif not event.pressed and event.index == pointer_id:
			pointer_id = -99
			_end_gesture()
	elif event is InputEventScreenDrag and event.index == pointer_id:
		_move_gesture(event.position, event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_gesture(event.position)
		else:
			_end_gesture()
	elif event is InputEventMouseMotion and gesture != "":
		_move_gesture(event.position, event.relative)

func _begin_gesture(point: Vector2) -> void:
	var classic := control_scheme() == "classic"
	if classic and point.y >= spin_zone_top() and not spin_strip_rect().has_point(point):
		gesture = ""
		return
	# A press in the move area while the last piece settles waits for the next Kinu instead of
	# spinning, so a slightly early touch still picks it up the moment it appears.
	if classic and state == "settle" and point.y < spin_zone_top():
		gesture = "waiting"
		return
	var aiming := point.y < spin_zone_top() if classic else grabs_active(point)
	if state == "aim" and active and aiming:
		gesture = "aim"
		active.poke(-1.8)
		Haptics.pulse(10, .2)
	else:
		gesture = "spin"
		orbit.stop_spin()

func _move_gesture(_point: Vector2, relative: Vector2) -> void:
	if gesture == "waiting" and state == "aim" and active:
		gesture = "aim"
	if gesture == "spin":
		orbit.orbit(relative.x)
		orbit.tilt_by(relative.y)
		if absf(relative.x) > 1:
			action_done.emit("spin")
	elif gesture == "aim" and active:
		orbit.move_drop(relative)
		if relative.length() > 1:
			action_done.emit("aim")

func _end_gesture() -> void:
	if gesture == "aim" and state == "aim":
		drop()
	elif gesture == "spin":
		orbit.release_spin()
	gesture = ""
