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
var state: String = "menu"
## The score is the tallest settled tower this run, in centimetres: how high, not how many.
var score: int = 0
var next_milestone: int = 100
var placed: int = 0
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
var best_ring: Node3D
var best_label: Label3D
var best_material: StandardMaterial3D

const LEVEL_STEP := .75
const WOBBLE_WARN := .7
const TIP_HOLD := .45
const KNOCK_LOOSE_SPEED := 5.0
## Touches this close (viewport pixels) to the held Kinu, or to its drop line, grab it.
const GRAB_RADIUS := 120.0
const GRAB_LINE_RADIUS := 70.0
## New Kinu arrive off-centre and turned, so every drop needs aiming (and often a spin).
const SPAWN_MIN_OFFSET := .6
const SPAWN_MAX_OFFSET := 1.2
const SPAWN_MAX_TURN := .8

func _ready() -> void:
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
	_build_best_ring()
	show_menu()

func _build_best_ring() -> void:
	best_ring = Node3D.new()
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.55
	torus.outer_radius = 2.71
	torus.rings = 64
	torus.ring_segments = 6
	ring.mesh = torus
	best_material = _flat(Color(1, .8, .2, .95))
	ring.material_override = best_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	best_ring.add_child(ring)
	best_label = Label3D.new()
	best_label.text = "BEST"
	best_label.font = NestTheme.font
	best_label.font_size = 48
	best_label.outline_size = 20
	best_label.modulate = NestTheme.CREAM
	best_label.outline_modulate = NestTheme.INK
	best_label.pixel_size = .01
	best_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	best_label.no_depth_test = true
	best_ring.add_child(best_label)
	add_child(best_ring)
	best_ring.hide()

func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

func _clear() -> void:
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
	best_ring.hide()
	orbit.stop_spin()
	orbit.angle = .35
	orbit.target_angle = .35
	orbit.tower_top = 0
	# Pieces are dropped just above their resting spots and settle with real physics, so they
	# never overlap. They grip once still, like a finished tower.
	var pile := [
		["slab", "silken", Vector3(-.7, .5, .3), .2], ["block", "matcha", Vector3(.8, .72, .35), -.25],
		["long", "sesame", Vector3(0, .57, -.95), .05], ["block", "silken", Vector3(-.7, 1.32, .3), .15],
		["ball", "sakura", Vector3(.8, 1.76, .35), 0.0], ["tall", "fried", Vector3(-.7, 2.58, .3), -.1]]
	for entry in pile:
		var body := make_body(_shape(entry[0]), _flavour(entry[1]))
		body.position = entry[2]
		body.rotation.y = entry[3]
		body.scored = true

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
	next_milestone = 100
	placed = 0
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
	var best := float(Save.data.best_height)
	best_ring.visible = best > TofuBox.RIM_HEIGHT
	best_ring.position.y = best
	choose_next()
	state = "ready"
	_spawn()

func choose_next() -> void:
	var shape_weights: Array[float] = []
	for item in catalog.shapes:
		var weight := item.spawn_weight
		# Early turns favour forgiving shapes; awkward ones arrive as the tower grows.
		if item.tricky:
			weight *= lerpf(.3, 1.3, clampf(placed/15.0, 0, 1))
		if item.id == last_shape:
			weight *= .35
		shape_weights.append(weight)
	next_shape = catalog.shapes[_weighted(shape_weights)]
	last_shape = next_shape.id
	var pool := flavour_mix()
	var flavour_weights: Array[float] = []
	for item in pool:
		flavour_weights.append(item.spawn_weight)
	next_flavour = pool[_weighted(flavour_weights)]

## Flavours whose height goal has been reached; these are what can spawn.
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

func make_body(shape: KinuShape, flavour: KinuFlavour) -> KinuBody:
	var body := KinuBody.new()
	body.setup(shape, flavour, catalog.outfit(str(Save.data.outfit)), catalog.finish(str(Save.data.finish)))
	add_child(body)
	body.landed.connect(_landed)
	bodies.append(body)
	return body

func tower_top() -> float:
	var top := TofuBox.RIM_HEIGHT*.4
	for body in bodies:
		if body != active and not body.fallen and body.scored and body.linear_velocity.length() < 2.0:
			top = maxf(top, body.position.y+body.shape.size.y*.45)
	return top

func _spawn() -> void:
	if state in ["over", "falling"]:
		return
	active = make_body(next_shape, next_flavour)
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
	Sound.play("drop")
	Haptics.pulse()
	action_done.emit("drop")
	updated.emit()

func _physics_process(delta: float) -> void:
	orbit.update(delta, menu_mode)
	if state in ["menu", "over"]:
		return
	if best_ring.visible:
		# Label on the far side of the ring so it stays small and never fills the screen.
		best_label.position = -orbit.toward_camera()*2.63+orbit.right()*1.2+Vector3.UP*.3
		# Fade the ring out as it comes level with the camera, where it would sweep across the view.
		var gap := absf(orbit.camera.global_position.y-best_ring.position.y)
		var fade := clampf((gap-.8)/1.6, 0, 1)
		best_material.albedo_color.a = .95*fade
		best_label.modulate.a = fade
		best_label.outline_modulate.a = fade
	if active:
		hold_time += delta
		drop_height = lerpf(drop_height, maxf(3.0, orbit.tower_top+1.4), 1.0-exp(-delta*4))
		grab_lift = lerpf(grab_lift, .3 if gesture == "aim" else 0.0, 1.0-exp(-delta*14))
		active.position = orbit.drop_position(drop_height)+Vector3.UP*(sin(hold_time*3.4)*.05+grab_lift)
		active.rotation.y = orbit.angle+active_yaw
		_update_guide()
	if state == "falling":
		elapsed += delta
		if elapsed > 1.8:
			end()
		return
	for body in bodies:
		# Ground contact counts even for a gripped (frozen) piece resting against the nest.
		if not body.fallen and (body.touched_ground or (not body.freeze and is_fallen(body))):
			_fall(body)
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
		if body.scored and not body.fallen and body != active:
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
				if body.tipped:
					continue
				weight += body.mass
				com += Vector2(body.position.x, body.position.z)*body.mass
			elif body.position.y >= cut-LEVEL_STEP*1.2:
				support.append(body)
		if weight == 0.0:
			break
		com /= weight
		var center := Vector2.ZERO
		var radius := TofuBox.RIM_RADIUS+.1
		if cut > TofuBox.RIM_HEIGHT and not support.is_empty():
			for body in support:
				center += Vector2(body.position.x, body.position.z)
			center /= support.size()
			radius = 0.0
			for body in support:
				radius = maxf(radius, Vector2(body.position.x, body.position.z).distance_to(center)+body.footprint())
		var ratio := com.distance_to(center)/maxf(radius, .3)
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

func _tip() -> void:
	overbalanced_time = 0
	var loosened := 0
	for body in bodies:
		if body.gripped and not body.tipped and body.position.y >= wobble_cut-.2:
			body.tipped = true
			var lift := clampf((body.position.y-wobble_cut)*.25, 0, 1)
			body.release(wobble_direction*(.9+lift)+Vector3.UP*.3)
			loosened += 1
	if loosened > 0:
		orbit.shake = .35
		Sound.play("heavy", .7)
		Haptics.pulse(40, .6)
		message.emit("Timber!", Color("ff8a1f"))

func _update_guide() -> void:
	var from := active.position-Vector3.UP*active.shape.size.y*.5
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
	state = "falling"
	elapsed = 0
	if active:
		bodies.erase(active)
		active.queue_free()
		active = null
	beam.hide()
	marker.hide()
	gesture = ""
	orbit.shake = .5
	Sound.play("escape")
	Haptics.pulse(60, .8)
	message.emit("Oh no! Kinu tumbled off!", Color("e0463a"))
	updated.emit()

func _settle() -> void:
	if not pending or pending.fallen:
		return
	pending.scored = true
	placed += 1
	tower_height = maxf(tower_height, tower_top())
	score = height_cm(tower_height)
	pending.cheer()
	var discovered: bool = Save.discover(pending.flavour.id)
	var unlocked: Array[String] = []
	for item in catalog.flavours:
		if item.unlock_cm > int(Save.data.best) and item.unlock_cm <= score:
			unlocked.append(item.display_name)
	if score > int(Save.data.best):
		Save.data.best = score
		Save.data.best_height = tower_height
		Save.persist()
	var metres := int(score/100.0)
	var milestone := score >= next_milestone
	if milestone:
		next_milestone = (metres+1)*100
	if not unlocked.is_empty():
		message.emit("%s unlocked!"%" & ".join(unlocked), Color("7a4fd0"))
		Sound.play("record")
		Haptics.pulse(35, .55)
	elif milestone:
		message.emit("%s tall! Amazing!"%("1 metre" if metres == 1 else "%d metres"%metres), Color("ff8a1f"))
		Sound.play("combo")
		Haptics.pulse(35, .55)
	elif discovered:
		message.emit("New flavour: %s!"%pending.flavour.display_name, Color("3f8fe0"))
		Sound.play("combo", 1.2)
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
	finished.emit({"score": score, "placed": placed, "height": tower_height})

func _landed(body: KinuBody, other: Node, force: float) -> void:
	if menu_mode or state == "over":
		return
	# A heavy landing jolts the piece it hits free of the pile.
	if other is KinuBody and other.gripped and force*body.mass > KNOCK_LOOSE_SPEED:
		other.release((other.position-body.position)*Vector3(1, 0, 1)*.4)
	Sound.play("heavy" if body.mass > 1.5 and force > 3 else "land", clampf(1.3-body.mass*.15, .8, 1.25))
	if force > 4:
		Haptics.pulse(12, .25)

## Soybeans for a run: 1 per 20 cm, 3 per full metre, and 5 more for a new best.
static func beans_for(score: int, record: bool) -> int:
	return int(score/20.0)+int(score/100.0)*3+(5 if record else 0)

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
