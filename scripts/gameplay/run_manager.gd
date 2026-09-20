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
## "" for a normal Kinu; Sticky Kinu bond their contact cluster so it cannot slip.
var next_special: String = ""
var next_sticky_drop: int = 7
var lucky_caught: int = 0
## The tutorial asks for a particular next item so its lessons arrive in order instead of waiting
## on a dice roll. Each is cleared the moment it is honoured.
var forced_special: String = ""
## Where the last squirt landed, so a sauce that falls down a crevice still finds the pile.
var sauce_point: Vector3 = Vector3.INF
## The Kinu lit up under the aimed bottle. The squirt applies to exactly this list, so the
## preview cannot drift out of step with what actually changes.
var sauce_targets: Array[KinuBody] = []
## Squirts left this run, and how many of the unlock thresholds have been passed.
var squirts: int = SQUIRTS_START
var squirt_unlocks: int = 0
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
## The mode being played: one of MODES.
var mode: String = "classic"
## Tower: the serving plate the tower is built on, in place of the box.
var plate: TowerPlate
## Home screen: the nodes making up each mode's set-up, so the one being played can be shown and
## the other put away. Empty during a run, when only one set-up is ever built.
var menu_groups: Dictionary = {}
## Lunch Rush: seconds left, boxes shipped and the Kinu packed into them.
var time_left: float = 0.0
var boxes_shipped: int = 0
var shipped: int = 0
## The score is how many Kinu are on the pile right now: in the box or stacked on it, not on the counter.
var score: int = 0
var next_milestone: int = MILESTONE_STEP
var placed: int = 0
## Kinu that tumbled onto the counter this run; the run ends at MAX_TUMBLES.
var tumbles: int = 0
var tower_height: float = 0.0
var elapsed: float = 0.0
var hold_time: float = 0.0
## Bento Flip's spring charge, from 0 to 1. It controls the pan's launch height and distance.
var bento_charge: float = 0.0
var bento_assisted: bool = false
var drop_height: float = 3.0
var beam: MeshInstance3D
## A translucent copy of the held Kinu at its predicted first contact. It deliberately shows
## contact rather than a guaranteed final resting place: the whole point of the pile is that it
## can still roll or shift after release.
var marker: Node3D
var marker_fill_material: StandardMaterial3D
var marker_outline_material: StandardMaterial3D
## Tower: a ring hanging at the height of your best tower, to climb towards and then pass.
var best_ring: MeshInstance3D
var best_ring_material: StandardMaterial3D
## The height the ring sits at, in world units, and whether this run has climbed past it.
var best_ring_height: float = 0.0
var best_ring_passed: bool = false
var last_shape: String = ""
var gesture: String = ""
var pointer_id: int = -99
var menu_mode: bool = true
var accepting_input: bool = true
var fallen_body: KinuBody
var grab_lift: float = 0.0
var room: TofuShop
var box: TofuBox
## Bento Flip's pan sits at the front of the current room and launches toward the bento.
var pan: BentoPan
## Space kept clear at the bottom of the screen (home indicator, rounded corners), in viewport pixels.
var bottom_inset: float = 20.0
## 0 = rock solid, 1 = the part above `wobble_cut` is past its support and about to tip.
var wobble: float = 0.0
var wobble_cut: float = 0.0
var wobble_direction: Vector3 = Vector3.ZERO
var overbalanced_time: float = 0.0
var balance_timer: float = 0.0

## "classic" fills the box, "tower" builds as tall as possible, "rush" is Bento Flip.
const MODES := ["classic", "tower", "rush"]
## Shapes a mode leaves out of its pool. Tower has no box walls to trap a rolling Kinu, so the
## round one would turn a careful stack into a coin flip; it sits that mode out.
const MODE_OMITTED_SHAPES := {"tower": ["ball"]}
## Best pile in Classic needed to play each mode.
const MODE_UNLOCK := {"classic": 0, "tower": 15, "rush": 25}
## Every room is composed around a single viewpoint: the camera on the shop's cloth, looking at
## the counter's centre. So both home-screen set-ups stand on that same spot and choosing a mode
## swaps one for the other, rather than moving the camera somewhere no room was built for.
## Tower is taller than a boxful, so the camera rises to frame it whole; that is the only move.
const MENU_TOWER_FOCUS := 2.55
## Bento Flip is deliberate rather than timed: each run starts with a small lunch-service stack
## of tosses, and packing a bento earns two more.
const RUSH_START := 12.0
const RUSH_BONUS := 2.0
const RUSH_BOX_TARGET := 5
const LEVEL_STEP := .75
const MAX_TUMBLES := 6
## Rush is a packing mode: fill the box, close the lid, take the next one. Set false to get Bento
## Flip — the frying pan and the timer — back instead. Classic is untouched either way.
const PACKING_RUSH := false
## Each box wants more Kinu under a lower lid, so a run climbs instead of settling into a rhythm.
const PACK_TARGET_START := 8
const PACK_TARGET_STEP := 2
const PACK_LID_START := 1.60
const PACK_LID_STEP := .10
const PACK_LID_MIN := .95
## Slack at the line, so a Kinu a hair over does not feel cheated.
const LID_MARGIN := .10
## Pale while there is room left, red once the mound is at the line.
const LID_CLEAR := Color(.72, .93, .78, .34)
const LID_FULL := Color(1, .42, .36, .5)
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
## The bottle is a charge you spend, not a queue slot: you start with one and earn more as the
## pile grows, so a squirt is something you save for the moment it is worth most.
## Shoyu's glue is gone — Sticky Kinu cover that job — and the bottle now holds Nigari.
const SQUIRTS_START := 1
## Pile sizes that hand you another squirt. The gaps widen, so later ones have to be earned.
const SQUIRT_UNLOCKS := [20, 35, 50]
## The sauce the bottle carries. Kept as a table so a second one can be slotted in later.
const BOTTLE_SAUCE := "nigari"
## Both names are real parts of making tofu: nigari is the coagulant that firms it, koji the
## culture that makes it swell.
## Koji, which made a Kinu bigger instead of smaller, is parked rather than deleted: most sauces
## handed to you should improve your situation, and a coin flip between help and harm read as the
## game being mean. Put its row back to bring it in.
##	"koji": {"label": "Koji", "hint": "Koji! Swells a Kinu bigger", "factor": 1.32, "targets": 1, "low": 1.0, "high": 1.45, "tint": "f5c14e"},
const SAUCES := {
	"nigari": {"label": "Nigari", "hint": "Nigari! Makes crowded Kinu smaller", "factor": .74, "targets": 3, "low": .55, "high": 1.0, "tint": "8fd3ff"},
}
## How far from the splash a Kinu can be and still catch the sauce.
const SAUCE_REACH := 1.35
const TINY_SCALE := .62
## Classic is intentionally the tighter, more immediately tactical mode. Scale only the box's
## footprint: its rim stays the familiar height, while a 10% smaller floor asks players to plan
## their base sooner. Tower and Rush retain the standard dimensions.
const CLASSIC_BOX_SCALE := .90
const BENTO_BOX_SCALE := .78
const BENTO_TARGET_DEPTH := 0.0
## The pan starts close to the counter edge, outside the regular pile area. Do not judge a toss
## as fallen until it has had time to leave the pan and cross the bento.
const BENTO_LAUNCH_GRACE := 1.8
## The best-height ring: pale while it is still above you, gold once you are over it.
const RING_WAITING := Color(1, .98, .92, .5)
const RING_PASSED := Color(1, .78, .23, .72)
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
	# A thin hoop a little wider than the plate, so it frames the tower without touching it.
	best_ring = MeshInstance3D.new()
	var hoop := TorusMesh.new()
	hoop.inner_radius = TowerPlate.HALF+.12
	hoop.outer_radius = TowerPlate.HALF+.22
	hoop.rings = 40
	hoop.ring_segments = 8
	best_ring.mesh = hoop
	best_ring_material = _flat(RING_WAITING)
	best_ring.material_override = best_ring_material
	best_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	best_ring.hide()
	add_child(best_ring)
	marker = Node3D.new()
	marker.name = "LandingGhost"
	marker_fill_material = _ghost_material(Color(.35, .82, 1.0, .20))
	marker_outline_material = _ghost_material(Color(.18, .48, .82, .68))
	add_child(marker)
	show_menu()

func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

## A single pair of unlit materials keeps the preview readable over every room and costume.
## The source meshes are still the current Kinu's meshes, so its silhouette and dimensions stay
## exact even for Tiny Kinu and outfits.
func _ghost_material(color: Color) -> StandardMaterial3D:
	var material := _flat(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _clear() -> void:
	if is_instance_valid(bottle):
		bottle.queue_free()
	bottle = null
	if is_instance_valid(pan):
		pan.queue_free()
	pan = null
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
	if box == null or box.decor != box_decor or box is BentoBox:
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

func _ensure_bento_box() -> void:
	var decor := catalog.find_decor("box", str(Save.data.box))
	if box is BentoBox and box.decor == decor:
		return
	if is_instance_valid(box):
		box.queue_free()
	box = BentoBox.new()
	box.decor = decor
	add_child(box)

func show_menu() -> void:
	refresh_decor()
	_clear()
	mode = "classic"
	_set_stage(true)
	state = "menu"
	menu_mode = true
	beam.hide()
	marker.hide()
	if best_ring:
		best_ring.hide()
	orbit.stop_spin()
	orbit.angle = .35
	orbit.target_angle = .35
	orbit.tower_top = 0
	# A run can leave the view tilted and raised for a tall tower. Snap both back so the home
	# camera is always framed the same, instead of starting low or gliding down after a run.
	orbit.tilt = 0.0
	orbit.menu_focus = OrbitController.BASE_FOCUS
	orbit.focus_height = OrbitController.BASE_FOCUS
	orbit.shake = 0.0
	# Deliberately arranged, gripped tableaux keep the home screen full and every face readable;
	# gameplay still uses real falling and settling physics.
	menu_groups = {"classic": [box] as Array[Node3D], "tower": [plate] as Array[Node3D]}
	# The box, filled the way a good Classic run ends.
	_tableau("classic", Vector3.ZERO, [
		["slab", "silken", Vector3(-1.05, .46, .62), .18], ["long", "sesame", Vector3(0, .50, -.72), .04],
		["slab", "fried", Vector3(1.05, .46, .62), -.18], ["block", "matcha", Vector3(-1.02, 1.12, .55), .16],
		["block", "silken", Vector3(0, 1.08, -.62), -.08], ["block", "tamago", Vector3(1.02, 1.12, .55), -.18],
		["ball", "sakura", Vector3(-.58, 1.92, .18), .08], ["block", "fried", Vector3(.62, 1.90, .18), -.14],
		["tall", "silken", Vector3(0, 2.78, .12), .04]])
	# The plate, with a tower that leans just enough to look like it is about to be someone's problem.
	_tableau("tower", Vector3.ZERO, [
		["slab", "fried", Vector3(0, TowerPlate.TOP+.26, 0), .06],
		["block", "silken", Vector3(-.04, TowerPlate.TOP+.92, .05), -.12],
		["block", "matcha", Vector3(.08, TowerPlate.TOP+1.58, -.03), .18],
		["long", "sesame", Vector3(-.02, TowerPlate.TOP+2.16, .02), .52],
		["block", "tamago", Vector3(.12, TowerPlate.TOP+2.80, .06), -.24],
		["slab", "sakura", Vector3(.05, TowerPlate.TOP+3.30, -.02), .1],
		["tall", "silken", Vector3(.18, TowerPlate.TOP+4.10, .04), .3]])
	focus_mode(chosen_mode(), true)

## Builds one gripped home-screen arrangement at `origin`, from [shape, flavour, offset, yaw] rows.
func _tableau(group: String, origin: Vector3, pile: Array) -> void:
	for entry in pile:
		# The home tableau previews the actual run: every Kinu wears the equipped outfit.
		var body := make_body(_shape(entry[0]), _flavour(entry[1]))
		body.position = origin+(entry[2] as Vector3)
		body.rotation.y = entry[3]
		body.scored = true
		body.grip()
		menu_groups[group].append(body)

## Home screen: puts the chosen mode's set-up on the counter and takes the other one away, and
## lifts the camera for Tower, which stands taller than a boxful.
## `snap` skips the camera's glide, for the first frame of the menu.
func focus_mode(id: String, snap: bool = false) -> void:
	if not menu_mode:
		return
	var tower := id == "tower"
	orbit.menu_focus = MENU_TOWER_FOCUS if tower else OrbitController.BASE_FOCUS
	if snap:
		orbit.focus_height = orbit.menu_focus
	if plate:
		plate.set_active(tower)
	if box:
		box.set_active(not tower)
	for group in menu_groups:
		for node in menu_groups[group]:
			if is_instance_valid(node) and node != box and node != plate:
				node.visible = group == id

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

static func mode_unlocked(id: String) -> bool:
	return Save.debug_unlocked() or int(Save.data.best) >= int(MODE_UNLOCK.get(id, 0))

## The mode the next run will play: the player's choice, if it's unlocked.
static func chosen_mode() -> String:
	var id := str(Save.data.mode)
	return id if id in MODES and mode_unlocked(id) else "classic"

static func best_for(id: String) -> int:
	return int(Save.data.best) if id == "classic" else int(Save.data.mode_best.get(id, 0))

func begin() -> void:
	refresh_decor()
	_clear()
	mode = chosen_mode()
	if bento_flip():
		_ensure_bento_box()
	_set_stage()
	time_left = RUSH_START
	boxes_shipped = 0
	shipped = 0
	menu_mode = false
	score = 0
	next_milestone = MILESTONE_STEP
	placed = 0
	tumbles = 0
	next_special = ""
	lucky_caught = 0
	lucky_spawned = false
	aim_mode = "kinu"
	hearts_caught = 0
	streak = 0
	best_streak = 0
	run_time = 0.0
	squirts = SQUIRTS_START
	squirt_unlocks = 0
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
	next_sticky_drop = 7+rng.randi_range(0, 1)
	orbit.lateral = 0
	orbit.depth = 0
	orbit.stop_spin()
	orbit.menu_focus = OrbitController.BASE_FOCUS
	orbit.target_angle = 0
	orbit.angle = 0
	orbit.tower_top = 0
	orbit.focus_height = OrbitController.BASE_FOCUS
	_place_best_ring()
	if bento_flip():
		pan = BentoPan.new()
		add_child(pan)
	choose_next()
	state = "ready"
	_spawn()

func choose_next() -> void:
	var shape_weights: Array[float] = []
	var omitted: Array = MODE_OMITTED_SHAPES.get(mode, [])
	for item in catalog.shapes:
		if item.id in omitted:
			shape_weights.append(0.0)
			continue
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
	if forced_special != "":
		next_special = forced_special
		forced_special = ""
		return
	var drop_number := placed+2 if is_instance_valid(active) else placed+1
	if mode == "classic" and not menu_mode and drop_number >= next_sticky_drop:
		next_special = "sticky"
		next_sticky_drop += 7+rng.randi_range(0, 1)
	elif placed >= 3 and not menu_mode:
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
		# A zero weight is a deliberate exclusion, so it must never be picked by a boundary roll.
		if weights[i] <= 0.0:
			continue
		choice -= weights[i]
		if choice <= 0:
			return i
	for i in weights.size():
		if weights[i] > 0.0:
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
	if special == "sticky":
		body.make_sticky()
	body.mark_special(special)
	add_child(body)
	body.landed.connect(_landed)
	bodies.append(body)
	return body

func tower_top() -> float:
	var top := TowerPlate.TOP if mode == "tower" else TofuBox.RIM_HEIGHT*.4
	for body in bodies:
		if body != active and not body.fallen and body.scored and body.linear_velocity.length() < 2.0:
			top = maxf(top, body.position.y+body.size().y*.45)
	return top

func _bento_pan_position() -> Vector3:
	# The pan stays at the near edge of the current view, so every room can reuse the same target
	# layout while still feeling like the Kinu is being served out of the machine.
	return orbit.toward_camera()*4.0+orbit.right()*orbit.lateral+Vector3.UP*.40

func _spawn() -> void:
	if state in ["over", "falling"]:
		return
	active = make_body(next_shape, next_flavour, next_special)
	if placed >= 2 and squirts > 0 and not Save.data.seen_specials.has("bottle"):
		Save.data.seen_specials.append("bottle")
		Save.persist()
		message.emit(tr("Tap the bottle to shrink crowded Kinu!"), Color("5a8fb5"))
	elif active.special != "" and not Save.data.seen_specials.has(active.special):
		Save.data.seen_specials.append(active.special)
		Save.persist()
		message.emit(tr(SpecialBadge.INTRO[active.special]), SpecialBadge.COLORS[active.special].darkened(.25))
	active.freeze = true
	active.collision_layer = 0
	active.collision_mask = 0
	# Roughly facing the player, but turned enough that edges rarely line up by themselves.
	active_yaw = rng.randf_range(-SPAWN_MAX_TURN, SPAWN_MAX_TURN)
	if bento_flip():
		orbit.lateral = 0.0
		orbit.depth = 0.0
	else:
		var reach := .5 if mode == "tower" else 1.0
		var spot := Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(SPAWN_MIN_OFFSET, SPAWN_MAX_OFFSET)*reach
		orbit.lateral = spot.x
		orbit.depth = spot.y
	choose_next()
	var top := tower_top()
	orbit.tower_top = top
	if placed > 0:
		tower_height = maxf(tower_height, top)
	drop_height = maxf(3.0, top+1.4)
	hold_time = 0
	bento_charge = 0.0
	bento_assisted = false
	if is_instance_valid(pan):
		pan.position = _bento_pan_position()
		pan.rotation.y = orbit.angle
	active.position = _bento_pan_position()+Vector3.UP*.20 if bento_flip() else orbit.drop_position(drop_height)
	state = "aim"
	_rebuild_landing_ghost()
	beam.show()
	marker.show()
	updated.emit()
	if is_instance_valid(active) and active.special == "sticky":
		action_done.emit("sticky_ready")

func drop() -> void:
	if state != "aim" or active == null:
		return
	if aim_mode == "bottle":
		_squirt()
		return
	state = "settle"
	active.position = _bento_pan_position()+Vector3.UP*.20 if bento_flip() else orbit.drop_position(drop_height)
	active.collision_layer = 2
	active.collision_mask = 3
	active.freeze = false
	active.sleeping = false
	if bento_flip():
		# A short, friendly lob: dragging the pan sideways changes the diagonal into the bento.
		var target := box.position+Vector3.UP*(TofuBox.RIM_HEIGHT*.68)
		var direction := (target-active.position)*Vector3(1, 0, 1)
		# A held pan reaches the high, long arc needed to clear the bento wall; a quick release is
		# a deliberately short flop. This makes force an understandable player-controlled skill.
		# Full charge is intentionally a slow, high serving lob: it has to clear the near rim and
		# descend into the bento before reaching the far wall. The old fast, shallow throw could
		# only collide with the outside face of the box.
		active.linear_velocity = direction.normalized()*lerpf(3.8, 5.0, bento_charge)+Vector3.UP*lerpf(2.8, 12.0, bento_charge)
		time_left = maxf(0.0, time_left-1.0)
		bento_charge = 0.0
		Sound.play("tap", 1.12)
	else:
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
	_update_best_ring()
	if state in ["menu", "over", "shipping"]:
		return
	run_time += delta
	if active:
		hold_time += delta
		if bento_flip() and gesture == "charge":
			bento_charge = minf(1.0, bento_charge+delta/1.15)
		drop_height = lerpf(drop_height, maxf(3.0, orbit.tower_top+1.4), 1.0-exp(-delta*4))
		grab_lift = lerpf(grab_lift, .3 if gesture == "aim" else 0.0, 1.0-exp(-delta*14))
		active.position = (_bento_pan_position()+Vector3.UP*.20 if bento_flip() else orbit.drop_position(drop_height))+Vector3.UP*(sin(hold_time*3.4)*.05+grab_lift)
		active.rotation.y = orbit.angle+active_yaw
		if is_instance_valid(pan):
			pan.position = _bento_pan_position()
			pan.rotation.y = orbit.angle
		if is_instance_valid(bottle) and not bottle.tipping:
			bottle.position = active.position+Vector3.UP*.3
			bottle.rotation.y = orbit.angle
		_update_guide()
	if bento_flip():
		_guide_bento_lob()
	if state == "falling":
		elapsed += delta
		if elapsed > 1.8:
			end()
		return
	for body in bodies:
		# Ground contact counts even for a gripped (frozen) piece resting against the nest.
		var launched := bento_flip() and body == pending and elapsed < BENTO_LAUNCH_GRACE
		if not launched and not body.fallen and body != active and (body.touched_ground or (not body.freeze and is_fallen(body))):
			_fall(body)
			if state == "falling":
				return
	balance_timer -= delta
	if not bento_flip() and balance_timer <= 0:
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
	var base_top := TowerPlate.TOP if mode == "tower" else TofuBox.RIM_HEIGHT
	var base_half := TowerPlate.HALF if mode == "tower" else box_half()
	var cut := TowerPlate.TOP+.6 if mode == "tower" else TofuBox.RIM_HEIGHT*.85
	while true:
		var weight := 0.0
		var com := Vector2.ZERO
		var support: Array[KinuBody] = []
		for body in pile:
			if body.position.y >= cut:
				# Glued Kinu are permanent structural anchors. They are not an unsupported
				# load for the balance system to wobble or tip.
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
		if cut <= base_top+(LEVEL_STEP if mode == "tower" else 0.0) or support.is_empty():
			# The box (or plate) itself is the support: a square, so measure against its edges.
			ratio = maxf(absf(com.x), absf(com.y))/base_half
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

## Swaps the held Kinu for the bottle, or puts the bottle away again. The Kinu is only hidden,
## so a squirt spends a charge rather than a turn.
func toggle_bottle() -> void:
	if state != "aim" or active == null:
		return
	if aim_mode == "bottle":
		aim_mode = "kinu"
		_clear_sauce_targets()
		if is_instance_valid(bottle):
			bottle.queue_free()
		bottle = null
		active.visible = true
	elif squirts > 0:
		aim_mode = "bottle"
		bottle = ShoyuBottle.new()
		bottle.tint = Color(str(SAUCES[BOTTLE_SAUCE].tint)).darkened(.25)
		add_child(bottle)
		bottle.position = active.position+Vector3.UP*.3
		active.visible = false
		Sound.play("tap")
	_rebuild_landing_ghost()
	_update_guide()
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
	sauce_point = point
	bottle.squirted.connect(_squirted)
	bottle.squirt(target, point)
	Sound.play("sauce", .7)
	Haptics.pulse(20, .3)
	updated.emit()

func _squirted(target: KinuBody) -> void:
	bottle = null
	aim_mode = "kinu"
	var recipe: Dictionary = SAUCES.get(BOTTLE_SAUCE, {})
	var touched := 0
	# Whatever was lit under the bottle is what gets sauced, so the preview is the promise.
	var chosen := sauce_targets.duplicate()
	_clear_sauce_targets()
	if not recipe.is_empty() and chosen.is_empty() and is_instance_valid(target):
		chosen = sauce_reach(target, int(recipe.targets))
	if not recipe.is_empty():
		touched = _apply_sauce(chosen, recipe)
	if touched > 0:
		glazed += touched
		message.emit(tr("%s! %d Kinu")%[str(recipe.label), touched], Color(str(recipe.tint)).darkened(.3))
		Sound.play("land", 1.1 if float(recipe.factor) < 1.0 else .7)
		Haptics.pulse(28, .5)
	else:
		message.emit(tr("Splat! Missed"), Color("8a6d5a"))
	action_done.emit("squirt")
	if state != "squirting":
		return
	# The charge is gone but the turn is not: the Kinu that was waiting comes back out.
	state = "aim"
	if is_instance_valid(active):
		active.visible = true
		_rebuild_landing_ghost()
		beam.show()
		marker.show()
	updated.emit()

## The packed Kinu closest to a point, within the sauce's reach.
func _nearest_to(point: Vector3) -> KinuBody:
	if not point.is_finite():
		return null
	var best: KinuBody = null
	var closest := SAUCE_REACH
	for body in bodies:
		if not is_instance_valid(body) or not body.scored or body.fallen or body == active:
			continue
		var gap := body.position.distance_to(point)
		if gap <= closest:
			closest = gap
			best = body
	return best

## The Kinu a squirt centred on `target` would catch, nearest first. The aiming preview and the
## squirt itself both read this, so what you see lit is what changes.
func sauce_reach(target: KinuBody, limit: int) -> Array[KinuBody]:
	var reachable: Array[KinuBody] = []
	if not is_instance_valid(target):
		return reachable
	for body in bodies:
		if is_instance_valid(body) and body.scored and not body.fallen and body != active:
			if body == target or body.position.distance_to(target.position) <= SAUCE_REACH:
				reachable.append(body)
	reachable.sort_custom(func(a: KinuBody, b: KinuBody) -> bool:
		return a.position.distance_to(target.position) < b.position.distance_to(target.position))
	return reachable.slice(0, limit)

## The Kinu directly under the bottle, or the nearest one to where the sauce would land if the
## ray slipped between two of them.
func sauce_aim(hit: Dictionary) -> KinuBody:
	if hit.is_empty():
		return null
	if hit.collider is KinuBody and hit.collider.scored and not hit.collider.fallen:
		return hit.collider
	return _nearest_to(hit.position)

## Lights the Kinu a squirt would catch, and puts out any that have fallen out of reach.
func _show_sauce_targets(aimed: KinuBody) -> void:
	var recipe: Dictionary = SAUCES.get(BOTTLE_SAUCE, {})
	var wanted: Array[KinuBody] = [] if recipe.is_empty() else sauce_reach(aimed, int(recipe.targets))
	for body in sauce_targets:
		if is_instance_valid(body) and not wanted.has(body):
			body.set_sauce_target(false)
	for body in wanted:
		if is_instance_valid(body):
			body.set_sauce_target(true, Color(str(recipe.tint)))
	sauce_targets = wanted

func _clear_sauce_targets() -> void:
	for body in sauce_targets:
		if is_instance_valid(body):
			body.set_sauce_target(false)
	sauce_targets.clear()

## Resizes exactly the Kinu that were lit, then lets the pile settle into the room it made.
func _apply_sauce(chosen: Array[KinuBody], recipe: Dictionary) -> int:
	var touched := 0
	for body in chosen:
		if is_instance_valid(body) and body.rescale(float(recipe.factor), float(recipe.low), float(recipe.high)):
			touched += 1
	if touched > 0:
		for body in bodies:
			if is_instance_valid(body) and not body.fallen:
				body.release()
	return touched

func _update_guide() -> void:
	if active == null:
		return
	if state != "aim":
		marker.hide()
		beam.hide()
		return
	if bento_flip():
		# Bento Flip's launch is ballistic, so the vertical Classic drop guide would be misleading.
		marker.hide()
		beam.hide()
		return
	if aim_mode == "bottle" and is_instance_valid(bottle):
		# Match the sauce ray, not the hidden Kinu's collision volume.
		var query := PhysicsRayQueryParameters3D.create(bottle.position, bottle.position-Vector3.UP*30, 3)
		query.exclude = [active.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		_show_sauce_targets(sauce_aim(hit))
		marker.visible = not hit.is_empty()
		if not hit.is_empty():
			var normal: Vector3 = hit.normal
			var tangent := normal.cross(Vector3.FORWARD).normalized()
			if tangent.length_squared() < .01:
				tangent = normal.cross(Vector3.RIGHT).normalized()
			marker.transform = Transform3D(Basis(tangent, normal, tangent.cross(normal)), hit.position+normal*.025)
			# The white guide makes the bottle's landing shadow feel connected to the sauce.
			var line_from: Vector3 = bottle.position-Vector3.UP*.14
			var line_to: Vector3 = hit.position+normal*.04
			var line_length := maxf(.01, line_from.distance_to(line_to))
			beam.position = (line_from+line_to)*.5
			beam.scale = Vector3(1, line_length, 1)
			beam.show()
		else:
			beam.hide()
		return
	marker.show()
	beam.show()
	marker.rotation = Vector3.ZERO
	# A shape cast, rather than a ray from the centre, accounts for this Kinu's actual width,
	# height and Tiny scale. The safe fraction puts the ghost at its first collision position.
	var from := active.position
	var motion := Vector3.DOWN*30.0
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = KinuBody.hitbox(active.shape, active.body_scale)
	shape_query.transform = Transform3D(Basis(Vector3.UP, active.rotation.y), from)
	shape_query.motion = motion
	shape_query.collision_mask = 3
	shape_query.exclude = [active.get_rid()]
	var cast := get_world_3d().direct_space_state.cast_motion(shape_query)
	var fraction := float(cast[0]) if not cast.is_empty() else 1.0
	var contact := from+motion*fraction
	marker.position = contact
	marker.rotation.y = active.rotation.y

	# This ray is only for the guide line and the red outside-the-container warning. The ghost
	# itself comes from the shape cast above, so it never shrinks to the old generic disc.
	var ray_from := active.position-Vector3.UP*active.size().y*.5
	var ray_query := PhysicsRayQueryParameters3D.create(ray_from, ray_from-Vector3.UP*30, 3)
	ray_query.exclude = [active.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray_query)
	var ground: Vector3 = hit.get("position", Vector3(ray_from.x, 0, ray_from.z))
	var unsafe := not on_base(contact) and ground.y < (TowerPlate.TOP+.1 if mode == "tower" else .35)
	_set_ghost_danger(unsafe)
	var length := maxf(.01, ray_from.y-ground.y)
	beam.position = (ray_from+ground)*.5
	beam.scale = Vector3(1, length, 1)

## Rebuild only when a new held Kinu appears. The preview uses the same generated model as the
## live piece, including its outfit/pattern and its exact in-play scale, but has no collider.
func _rebuild_landing_ghost() -> void:
	for child in marker.get_children():
		marker.remove_child(child)
		child.queue_free()
	if active == null:
		return
	if aim_mode == "bottle":
		var shadow := MeshInstance3D.new()
		shadow.name = "SauceShadow"
		var plane := PlaneMesh.new()
		plane.size = Vector2(.95, .95)
		shadow.mesh = plane
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded, blend_mix, depth_draw_never, cull_disabled; void fragment() { float r = length(UV - vec2(0.5)) * 2.0; ALBEDO = vec3(0.12, 0.065, 0.035); ALPHA = (1.0 - smoothstep(0.25, 1.0, r)) * 0.48; }"
		var material := ShaderMaterial.new()
		material.shader = shader
		shadow.material_override = material
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.add_child(shadow)
		return
	var ghost := KinuModel.build(active.shape, active.look, active.outfit)
	ghost.name = "KinuGhost"
	ghost.transform = Transform3D(Basis.from_scale(Vector3.ONE*active.body_scale), Vector3.ZERO)*active.fit
	marker.add_child(ghost)
	_apply_ghost_materials(ghost)

func _apply_ghost_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.material_override = marker_outline_material if mesh.name.contains("Outline") else marker_fill_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_ghost_materials(child)

func _set_ghost_danger(unsafe: bool) -> void:
	marker_fill_material.albedo_color = Color(.98, .25, .32, .24) if unsafe else Color(.35, .82, 1.0, .20)
	marker_outline_material.albedo_color = Color(.82, .12, .18, .72) if unsafe else Color(.18, .48, .82, .68)

## True when a point lies over the box, or over the plate in Tower.
func on_base(point: Vector3, margin: float = 0.0) -> bool:
	if mode == "tower":
		return TowerPlate.contains(point, margin)
	return box_contains(point, margin)

## Classic narrows the real collision box and every gameplay query with it, so the visible rim,
## landing guide and tumble boundary always agree.
func box_half() -> float:
	var scale := BENTO_BOX_SCALE if bento_flip() else CLASSIC_BOX_SCALE if mode != "tower" else 1.0
	return (TofuBox.INNER_HALF+TofuBox.WALL)*scale

func box_contains(point: Vector3, margin: float = 0.0) -> bool:
	var reach := box_half()+margin
	var local := point-box.position
	return absf(local.x) <= reach and absf(local.z) <= reach

func is_fallen(body: KinuBody) -> bool:
	var p := body.position
	if not p.is_finite() or p.y < -.6:
		return true
	var radius := Vector2(p.x, p.z).length()
	if mode == "tower":
		return radius > TofuShop.COUNTER_HALF*1.5 or (not TowerPlate.contains(p, .35) and p.y < TowerPlate.TOP+.25)
	return radius > TofuShop.COUNTER_HALF*1.5 or (not box_contains(p, .35) and p.y < TofuBox.RIM_HEIGHT*.75)

func _fall(body: KinuBody, reason: String = "tumble") -> void:
	body.fallen = true
	fallen_body = body
	tumbles += 1
	streak = 0
	if body == pending:
		pending = null
	score = shipped+pile_count() if lid_mode() else pile_count()
	orbit.shake = .5
	Sound.play("mistake")
	Haptics.pulse(60, .8)
	_clear_fallen(body)
	if mode == "tower":
		score = standing_height()
	elif bento_flip():
		score = boxes_shipped
		message.emit(tr("Missed the bento!"), Color("e0463a"))
		updated.emit()
		if time_left <= 0.0:
			end()
		else:
			_spawn()
		return
	if tumbles < MAX_TUMBLES:
		var left := MAX_TUMBLES-tumbles
		if reason == "lid":
			message.emit(tr("Too tall! The lid won't close") if left > 1 else tr("Too tall! 1 tumble left"), Color("e0463a"))
		else:
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
	message.emit(tr("Oh no! That's %d tumbles!")%MAX_TUMBLES, Color("e0463a"))
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
## True while Rush is packing boxes under a lid.
func lid_mode() -> bool:
	return mode == "rush" and PACKING_RUSH

## True while Rush is still the old pan-and-timer Bento Flip.
func bento_flip() -> bool:
	return mode == "rush" and not PACKING_RUSH

## How many Kinu this box wants before the lid is worth closing.
func pack_target() -> int:
	return PACK_TARGET_START+boxes_shipped*PACK_TARGET_STEP

## The highest point of a settled Kinu, projected onto world Y so a Kinu resting on its side or
## stood on end is measured by how much room it actually takes up, not by its upright height.
func _lid_reach(body: KinuBody) -> float:
	var half := body.size()*.5
	var turn := body.global_transform.basis
	return body.position.y+absf(turn.x.y*half.x)+absf(turn.y.y*half.y)+absf(turn.z.y*half.z)

## The height the lid closes at. It comes down box by box, which keeps the box shallow enough to
## see into while steadily squeezing the room left to pack in.
func lid_height() -> float:
	return TofuBox.RIM_HEIGHT+maxf(PACK_LID_MIN, PACK_LID_START-boxes_shipped*PACK_LID_STEP)

func _too_proud(body: KinuBody) -> bool:
	return _lid_reach(body) > lid_height()+LID_MARGIN

## How many Kinu are packed in the box right now, against the number needed to close the lid.
func packed_count() -> int:
	return pile_count()

func can_ship() -> bool:
	return lid_mode() and state == "aim" and packed_count() >= pack_target()

func ship_box() -> void:
	if not can_ship():
		return
	if is_instance_valid(active):
		bodies.erase(active)
		active.queue_free()
		active = null
	_ship()

func pile_count() -> int:
	var count := 0
	for body in bodies:
		if is_instance_valid(body) and body.scored and not body.fallen:
			count += 1
	return count

func _settle() -> void:
	if not pending or pending.fallen:
		return
	# The bento's lacquer rim and the Kinu's rounded body make a centre-point-only check feel
	# unfair. A piece settled anywhere visibly inside the box is a successful serve.
	if (bento_flip() or lid_mode()) and not box_contains(pending.position, .55):
		_fall(pending)
		return
	# The lid rule: anything standing above the rim would stop the box closing, so it cannot be
	# part of this box. This is what stops Classic turning into a free-standing tower.
	if lid_mode() and _too_proud(pending):
		_fall(pending, "lid")
		return
	pending.scored = true
	placed += 1
	tower_height = maxf(tower_height, tower_top())
	score = pile_count()
	if mode == "tower":
		score = standing_height()
	elif lid_mode():
		score = shipped+pile_count()
	elif bento_flip():
		score = boxes_shipped
	pending.cheer()
	flavour_counts[pending.flavour.id] = int(flavour_counts.get(pending.flavour.id, 0))+1
	shape_counts[pending.shape.id] = int(shape_counts.get(pending.shape.id, 0))+1
	streak += 1
	best_streak = maxi(best_streak, streak)
	var discovered: bool = Save.discover(pending.flavour.id)
	if discovered:
		new_flavours += 1
		last_new_flavour_placed = placed
	var milestone := score >= next_milestone and mode == "classic"
	if milestone:
		next_milestone = (score/MILESTONE_STEP+1)*MILESTONE_STEP
	# Squirts are earned at set pile sizes with widening gaps, so each one costs more than the last.
	var earned_squirt := false
	while mode == "classic" and squirt_unlocks < SQUIRT_UNLOCKS.size() and score >= int(SQUIRT_UNLOCKS[squirt_unlocks]):
		squirt_unlocks += 1
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
		if bento_flip():
			time_left += 3.0
			message.emit(tr("Heart Kinu! +3s"), Color("ff5d8f"))
		elif tumbles > 0:
			tumbles -= 1
			message.emit(tr("Heart Kinu! A tumble came back"), Color("ff5d8f"))
		else:
			bonus_beans += 5
			message.emit(tr("Heart Kinu! +5 beans"), Color("ff5d8f"))
		Sound.play("special", 1.2)
		Haptics.pulse(35, .55)
	elif earned_squirt:
		# 35 is not a round number, so an earned squirt announces itself rather than riding on a
		# milestone it would otherwise miss.
		message.emit(tr("%d Kinu! +1 Nigari squirt")%score, Color("5a8fb5"))
		Sound.play("special")
		Haptics.pulse(35, .55)
	elif milestone:
		var reached := score/MILESTONE_STEP*MILESTONE_STEP
		message.emit(tr("%d Kinu! Amazing!")%reached, Color("ff8a1f"))
		Sound.play("special")
		Haptics.pulse(35, .55)
	elif discovered:
		message.emit(tr("New flavour: %s!")%tr(pending.flavour.display_name), Color("3f8fe0"))
		Sound.play("special", 1.2)
	pending = null
	action_done.emit("settle")
	if bento_flip() and pile_count() >= RUSH_BOX_TARGET:
		_ship()
		return
	if bento_flip() and time_left <= 0.0:
		end()
		return
	_spawn()

## A full pan flip is intentionally generous once it has cleanly cleared the rim. This keeps the
## challenge in choosing aim and charge, rather than demanding pinball-perfect collision luck.
func _guide_bento_lob() -> void:
	if bento_assisted or not is_instance_valid(pending) or pending.fallen:
		return
	if pending.linear_velocity.y >= 0.0 or pending.position.y < TofuBox.RIM_HEIGHT+.45:
		return
	var local := pending.position-box.position
	var catch_half := box_half()+.45
	if absf(local.x) > catch_half or absf(local.z) > catch_half:
		return
	bento_assisted = true
	# Preserve a soft fall, but pull the horizontal drift toward the rice bed so the Kinu visibly
	# drops into the lunch rather than catching the far lip after a successful high arc.
	pending.linear_velocity = Vector3(-local.x*2.4, -2.2, -local.z*2.4)

func end() -> void:
	if state == "over":
		return
	state = "over"
	if mode == "tower":
		score = standing_height()
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
	return {"mode": mode, "pile": pile_count() if mode != "rush" else score, "boxes": boxes_shipped, "score": score, "placed": placed, "height": tower_height, "tumbles": tumbles, "lucky": lucky_caught, "hearts": hearts_caught, "bonus": bonus_beans, "flavours": flavour_counts.duplicate(), "shapes": shape_counts.duplicate(), "streak": best_streak, "time": run_time, "squirts": squirts_used, "glazed": glazed, "turns": int(orbit.travelled/TAU), "new_flavours": new_flavours, "dressed": str(Save.data.outfit) != "", "decorated": str(Save.data.room) != "shop" or str(Save.data.box) != "hinoki"}

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

## Soybeans for any mode: Tower pays a bean per 10 cm, Rush pays like Classic plus 5 a box.
static func beans_for_run(stats: Dictionary, record: bool) -> int:
	var score := int(stats.get("score", 0))
	match str(stats.get("mode", "classic")):
		"tower":
			return score/10+score/100*2+(5 if record else 0)
		"rush":
			return beans_for(score, record)+int(stats.get("boxes", 0))*5
	return beans_for(score, record)

## Height of what's standing on the plate right now, in cm.
func standing_height() -> int:
	return height_cm(tower_top(), TowerPlate.TOP)

## Names of flavours whose pile goal lies above the old best and at or below the new one.
static func unlocks_between(flavours: Array[KinuFlavour], old_best: int, new_best: int) -> Array[String]:
	var names: Array[String] = []
	for item in flavours:
		if item.unlock_kinu > old_best and item.unlock_kinu <= new_best:
			names.append(item.display_name)
	return names

static func height_cm(height: float, base: float = TofuBox.FLOOR_TOP) -> int:
	return int(round(maxf(0, height-base)*20))

func height_label(height: float = tower_height) -> String:
	return "%d cm"%height_cm(height)

## Tower only: hangs the ring at your best tower so far, as something to climb towards. A first
## run has nothing to beat, so it shows nothing rather than a ring on the plate.
func _place_best_ring() -> void:
	best_ring_passed = false
	if best_ring == null:
		return
	if lid_mode():
		best_ring_height = lid_height()
		best_ring.position = Vector3(0, best_ring_height, 0)
		# Sized to sit just outside the box walls, so it frames the mound rather than floating free.
		best_ring.scale = Vector3.ONE*((TofuBox.INNER_HALF*CLASSIC_BOX_SCALE+.10)/(TowerPlate.HALF+.22))
		best_ring_material.albedo_color = LID_CLEAR
		best_ring.show()
		return
	best_ring.scale = Vector3.ONE
	var best := best_for("tower")
	if mode != "tower" or best <= 0:
		best_ring.hide()
		return
	# Scores are centimetres measured from the plate, the same conversion height_cm does.
	best_ring_height = TowerPlate.TOP+best/20.0
	best_ring.position = Vector3(0, best_ring_height, 0)
	best_ring_material.albedo_color = RING_WAITING
	best_ring.show()

## Keeps the ring breathing gently so it reads as a target rather than scenery, and turns it gold
## the moment the tower climbs past it.
func _update_best_ring() -> void:
	if best_ring == null or not best_ring.visible:
		return
	if lid_mode():
		# Reads as headroom: pale with room to spare, reddening as the mound reaches the lid.
		var fill := clampf((tower_top()-TofuBox.RIM_HEIGHT*.5)/maxf(.01, best_ring_height-TofuBox.RIM_HEIGHT*.5), 0, 1)
		var tone := LID_CLEAR.lerp(LID_FULL, fill)
		var breath := .5+.5*sin(Time.get_ticks_msec()*.0035)
		best_ring_material.albedo_color = Color(tone.r, tone.g, tone.b, tone.a*(.7+.3*breath*fill))
		best_ring.rotation.y += .002
		return
	var beat := tower_top() > best_ring_height
	if beat and not best_ring_passed:
		best_ring_passed = true
		best_ring_material.albedo_color = RING_PASSED
		message.emit(tr("New best height!"), Color("ffb62e"))
		Sound.play("special")
		Haptics.pulse(30, .6)
	var pulse := .5+.5*sin(Time.get_ticks_msec()*.0035)
	var tone := RING_PASSED if best_ring_passed else RING_WAITING
	best_ring_material.albedo_color = Color(tone.r, tone.g, tone.b, tone.a*(.72+.28*pulse))
	best_ring.rotation.y += .004

## Shows the box or the tower plate for the current mode.
func _set_stage(menu: bool = false) -> void:
	var tower := mode == "tower"
	# The home screen builds both set-ups so either can be swapped in without a rebuild.
	if (tower or menu) and plate == null:
		plate = TowerPlate.new()
		add_child(plate)
	if plate:
		plate.position = Vector3.ZERO
		plate.set_active(tower)
	if box:
		box.position = Vector3(0, 0, BENTO_TARGET_DEPTH) if bento_flip() else Vector3.ZERO
		var scale := BENTO_BOX_SCALE if bento_flip() else CLASSIC_BOX_SCALE if mode != "tower" else 1.0
		box.scale = Vector3(scale, 1.0, scale)
		box.set_active(not tower)

## The lid seats flush on the rim, so anything standing proud of the box is pressed down into it.
## Tofu squashes, which is both the right fiction and the reason a mound is packable at all rather
## than an instant loss — the lid line is how big a mound the lid can still flatten.
func _press_lid(lid: Node3D, mound: float, seconds: float) -> void:
	var floor_y := TofuBox.FLOOR_TOP
	var rim := TofuBox.RIM_HEIGHT
	var squash := clampf((rim-floor_y)/maxf(.01, mound-floor_y), .25, 1.0)
	var packed: Array[KinuBody] = []
	var starts: Array[float] = []
	for body in bodies:
		if is_instance_valid(body) and not body.fallen:
			packed.append(body)
			starts.append(body.position.y)
	# Everything gives at once, so the mound settles as one pressed block rather than in layers.
	for body in packed:
		body.poke(2.4*(1.0-squash))
	Sound.play("land", .7)
	Haptics.pulse(25, .45)
	# The whole stack is scaled toward the floor together, so nothing is left poking through the
	# lid and the pressed block keeps the arrangement the player actually built.
	var step := func(t: float) -> void:
		if not is_instance_valid(lid):
			return
		lid.position.y = lerpf(mound+.05, rim+.02, t)
		var give := lerpf(1.0, squash, t)
		for i in packed.size():
			if is_instance_valid(packed[i]):
				packed[i].position.y = floor_y+(starts[i]-floor_y)*give
	var press := create_tween()
	press.tween_method(step, 0.0, 1.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await press.finished

## Bento Flip: five served Kinu close the bento, then a fresh lunchbox slides in.
func _ship() -> void:
	state = "shipping"
	beam.hide()
	marker.hide()
	var packed := pile_count()
	boxes_shipped += 1
	shipped += RUSH_BOX_TARGET if bento_flip() else packed
	if bento_flip():
		time_left += RUSH_BONUS
	score = boxes_shipped if bento_flip() else shipped
	for body in bodies:
		body.freeze = true
		body.sway = 0
	message.emit(tr("Bento packed! +%d tosses")%int(RUSH_BONUS) if bento_flip() else tr("Box packed! %d Kinu · next box wants %d")%[packed, pack_target()], Color("3f8fe0"))
	Sound.play("cashregister")
	Haptics.pulse(40, .6)
	updated.emit()
	var lid := BentoBox.packed_lid(box.decor)
	lid.position = box.position+Vector3.UP*6.0
	add_child(lid)
	var mound := maxf(tower_top(), TofuBox.RIM_HEIGHT)
	var packing := create_tween()
	packing.tween_property(lid, "position:y", mound+.05, .35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await packing.finished
	if lid_mode():
		await _press_lid(lid, mound, .5)
	var riders: Array[Node3D] = [box, lid]
	for body in bodies:
		if is_instance_valid(body) and not body.fallen:
			riders.append(body)
	var away := create_tween().set_parallel(true)
	for node in riders:
		away.tween_property(node, "position:x", node.position.x+14.0, .55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await away.finished
	if state == "over":
		return
	lid.queue_free()
	for body in bodies:
		if is_instance_valid(body):
			body.queue_free()
	bodies.clear()
	box.position.x = -14.0
	var back := create_tween()
	back.tween_property(box, "position:x", 0.0, .45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await back.finished
	Sound.play("drop")
	if state != "shipping":
		return
	state = "ready"
	_place_best_ring()
	_spawn()

## "classic": drag anywhere above the bottom strip to move, swipe the strip to spin.
## "grab": press on Kinu to move it, swipe anywhere else to spin.
func control_scheme() -> String:
	if bento_flip():
		return "bento"
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
	if bento_flip() and state == "aim" and active:
		if spin_strip_rect().has_point(point):
			gesture = "spin"
			orbit.stop_spin()
			return
		gesture = "charge"
		bento_charge = 0.0
		_set_bento_aim(point)
		active.poke(-1.8)
		Haptics.pulse(10, .2)
		return
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

func _move_gesture(point: Vector2, relative: Vector2) -> void:
	if gesture == "charge":
		_set_bento_aim(point)
		return
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
	if gesture in ["aim", "charge"] and state == "aim":
		drop()
	elif gesture == "spin":
		orbit.release_spin()
	gesture = ""

func _set_bento_aim(point: Vector2) -> void:
	var width := maxf(1.0, get_viewport().get_visible_rect().size.x)
	# Aim is chosen by where the finger sits horizontally; the player can slide while holding.
	orbit.lateral = clampf((point.x/width-.5)*2.0, -1.0, 1.0)*1.45
