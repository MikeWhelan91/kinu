class_name CatcherMachine
extends SubViewportContainer
## The Kinu Catcher's glass case: a pile of identical capsules, a three-pronged claw on a gantry and
## the prize chute in the front-left corner. The prize is already decided when a play starts; the
## claw always catches a capsule and always delivers it. Drag the case to steer the claw.

signal delivered
signal state_changed

const HALF_X := 3.0
const HALF_Z := 2.1
const CEILING := 6.5
const CAPSULE_RADIUS := .46
const CAPSULE_COUNT := 26
## The chute's footprint on the floor (x from, z from, width, depth). Capsules drop through it.
const CHUTE := Rect2(-3.0, .45, 1.6, 1.65)
const HOME := Vector3(-2.2, 5.5, 1.28)
const SHELF_LOW := 2.55
const SHELF_HIGH := 4.0
## The shelves' front edge, and the height of the plinth built up underneath them.
const SHELF_FRONT := -1.0
const SHELF_BASE := 1.15
const STAND_TILT := .42
## How far the case turns each way from the front, and how far it tilts.
const YAW_LIMIT := 1.05
const PITCH_MIN := -.12
const PITCH_MAX := .22
const CAMERA_DISTANCE := 15.5
const LOOK_AT := Vector3(0, 2.9, 0)
const CLAW_SPEED := 3.2
## How far the claw may travel, in x and z. This covers the whole prize floor, less the claw's
## own width at the glass: capsules roll into the far corners, and anything the player can see
## in the case has to be something they can go and get.
const REACH_MIN := Vector2(-2.6, -.6)
const REACH_MAX := Vector2(2.6, 1.8)
## Kept clear around the chute opening, where there is nothing to pick up. The delivery ride
## carries the claw out over it on its own, so only player steering is held back.
const CHUTE_CLEAR := .35
## Finger angles: positive curls the hooks inward.
const CLOSED := .14
const OPEN := -.62
const GRIP := Vector3(0, -.66, 0)

const SOFT_GLASS := preload("res://resources/shaders/toon_glass_soft.gdshader")
const PINK := Color("b9a6f0")
const CHROME := Color("dfe4ee")
const CREAM := Color("fff4df")
const PRIZE_RED := Color("ff6f91")
const CAPSULE_COLOR := Color("ff8fb1")
const CAPSULE_BAND := Color("fff4df")

var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var capsules: Array[RigidBody3D] = []
var claw: Node3D
var cable: MeshInstance3D
var carriage: MeshInstance3D
var fingers: Array[Node3D] = []
var bulbs: Array[MeshInstance3D] = []
## While aiming: a soft shadow where the claw will land, and a faint line down to it.
var marker: MeshInstance3D
var beam: MeshInstance3D
## A soft glow around the capsule the claw would catch from where it is now.
var halo: MeshInstance3D
## "idle", "aim" (the player steers) or "busy" (the claw is working).
var state: String = "idle"
var target := Vector2(HOME.x, HOME.z)
var velocity := Vector3.ZERO
var sway: float = 0.0
var rng := RandomNumberGenerator.new()
var pointer: int = -99
## The view: yaw 0 looks at the front of the case, pitch 0 is level with its middle.
var yaw: float = 0.0
var pitch: float = .02
var yaw_goal: float = 0.0
var pitch_goal: float = .02
## Held joystick values, applied every frame.
var move_input := Vector2.ZERO
## Seconds the motor keeps running after a drag on the case, which arrives as one-off nudges
## rather than a held deflection like the sticks do.
var _drag_motor: float = 0.0
## True while the catch sequence is driving the claw itself, so the motor is heard on the way
## down, on the way up and on the ride back to the chute — but not during the pauses between.
var _motor_auto: bool = false
var view_input := Vector2.ZERO

static var capsule_meshes: Array = []

func _ready() -> void:
	rng.randomize()
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.transparent_bg = false
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var env := TofuShop.make_environment()
	env.background_color = Color("e9e0ff")
	env.ambient_light_color = Color("fbf6ff")
	env.ambient_light_energy = .22
	environment.environment = env
	world.add_child(environment)
	var sun := TofuShop.make_sun()
	sun.rotation_degrees = Vector3(-62, -20, 0)
	sun.light_energy = .85
	sun.directional_shadow_max_distance = 20
	world.add_child(sun)
	camera = Camera3D.new()
	# Level with the middle of the case and far back with a narrow lens, so the inside reads
	# straight-on like the flat cabinet frame around it.
	camera.fov = 27
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	world.add_child(camera)
	_place_camera()
	_build_case()
	_build_claw()
	for i in CAPSULE_COUNT:
		# Dropped onto the prize floor, clear of the chute so none falls straight down it and in
		# front of the shelf plinth so every one of them stays within the claw's reach.
		_spawn_capsule(Vector3(rng.randf_range(CHUTE.end.x+.3, HALF_X-.5), SHELF_BASE+.6+i*.34, rng.randf_range(REACH_MIN.y+.15, HALF_Z-.5)))

# ---------- Building ----------

func _build_case() -> void:
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	var mat := Color("ece4ff")
	# The floor mat, leaving a hole over the chute.
	kit.add_rounded_box(Vector3((CHUTE.end.x+HALF_X)*.5, -.1, 0), Vector3(HALF_X-CHUTE.end.x, .2, HALF_Z*2), mat, Vector3.ZERO, false, 10)
	kit.add_rounded_box(Vector3((CHUTE.position.x+CHUTE.end.x)*.5, -.1, (CHUTE.position.y-HALF_Z)*.5), Vector3(CHUTE.size.x, .2, CHUTE.position.y+HALF_Z), mat, Vector3.ZERO, false, 10)
	for i in 12:
		for j in 8:
			if (i+j) % 2 == 0:
				var spot := Vector3(-HALF_X+.25+i*.5, .005, -HALF_Z+.26+j*.53)
				if not CHUTE.grow(.05).has_point(Vector2(spot.x, spot.z)):
					kit.add("cylinder", spot, Vector3(.16, .02, .16), Color("d9ccff"), Vector3.ZERO, false)
	kit.add("cylinder", Vector3(CHUTE.get_center().x, -.25, CHUTE.get_center().y), Vector3(CHUTE.size.x*.95, .05, CHUTE.size.y*.95), Color("3a2530"), Vector3.ZERO, false)
	# The cabinet front below the glass, so the view never looks past the floor's edge.
	# The whole cabinet base under the floor, closed on every side.
	kit.add_rounded_box(Vector3(0, -1.6, .05), Vector3(HALF_X*2+.6, 3.2, HALF_Z*2+.7), Color("ff8fb1"), Vector3.ZERO, true, 10)
	kit.add_rounded_box(Vector3(0, -.02, HALF_Z+.42), Vector3(HALF_X*2+.6, .12, .12), KinuModel.GOLD, Vector3.ZERO, true, 10)
	var face_z := HALF_Z+.42
	# The prize flap under the chute, where capsules come out.
	var flap := Vector3(-2.3, -.95, face_z)
	kit.add_rounded_box(flap, Vector3(1.2, 1.2, .06), Color("3a2150"), Vector3.ZERO, true, 8)
	kit.add_rounded_box(flap+Vector3(0, .05, .04), Vector3(1.0, .9, .04), Color("5a3a78"), Vector3.ZERO, false, 8)
	kit.add_rounded_box(flap+Vector3(0, .4, .07), Vector3(.8, .08, .03), CHROME, Vector3.ZERO, false, 8)
	# A cream logo plate with a little Kinu face beside the game's name.
	var plate := Vector3(0, -.85, face_z)
	kit.add_rounded_box(plate, Vector3(3.0, 1.2, .06), Color("fffaf0"), Vector3.ZERO, true, 8)
	kit.add_rounded_box(plate+Vector3(-1.05, 0, .05), Vector3(.72, .64, .08), Color("fff4df"), Vector3.ZERO, true, 7)
	for side in [-1.0, 1.0]:
		kit.add("sphere", plate+Vector3(-1.05+side*.14, .06, .1), Vector3(.08, .11, .02), Color("2b1a17"), Vector3.ZERO, false)
		kit.add("sphere", plate+Vector3(-1.05+side*.24, -.08, .1), Vector3(.12, .06, .02), Color("ff9fb0"), Vector3.ZERO, false)
	kit.add("sphere", plate+Vector3(-1.05, -.1, .1), Vector3(.1, .05, .02), Color("2b1a17"), Vector3.ZERO, false)
	# The coin slot, tucked right.
	var slot := Vector3(2.3, -.85, face_z)
	kit.add_rounded_box(slot, Vector3(.42, .9, .06), Color("3a2150"), Vector3.ZERO, true, 8)
	kit.add_rounded_box(slot+Vector3(0, .15, .05), Vector3(.08, .34, .03), KinuModel.GOLD, Vector3.ZERO, false, 8)
	kit.add("sphere", slot+Vector3(0, -.28, .05), Vector3(.18, .18, .04), Color("ff6f91"), Vector3.ZERO, false)
	# The quilted back wall.
	var back := MeshKit.new()
	back.add_rounded_box(Vector3(0, CEILING*.5, -HALF_Z-.15), Vector3(HALF_X*2+.3, CEILING+.4, .3), PINK, Vector3.ZERO, true, 10)
	for row in 7:
		for column in 9:
			var at := Vector3(-HALF_X+.35+column*.7+(.35 if row % 2 else 0.0), .45+row*.62, -HALF_Z)
			if at.x < HALF_X-.1:
				back.add("sphere", at, Vector3(.1, .1, .05), PINK.darkened(.12), Vector3.ZERO, false)
	_add_wall(back, Vector3(0, 0, -1))
	# Tinted glass sides between pink corner posts, so the case is closed but still see-through.
	var glass := MeshKit.new()
	for side in [-1.0, 1.0]:
		glass.add_rounded_box(Vector3(side*(HALF_X+.12), CEILING*.5, 0), Vector3(.06, CEILING, HALF_Z*2+.2), Color("e6dcff"), Vector3.ZERO, false, 10)
		for z in [-1.0, 1.0]:
			kit.add_rounded_box(Vector3(side*(HALF_X+.15), CEILING*.5, z*(HALF_Z+.2)), Vector3(.3, CEILING+.4, .3), Color("ff8fb1"), Vector3.ZERO, true, 10)
	var panes := glass.build(.02, false)
	var pane_material := ShaderMaterial.new()
	pane_material.shader = SOFT_GLASS
	# The side glass is drawn before everything else see-through, so it never covers the capsules.
	pane_material.render_priority = -1
	pane_material.set_shader_parameter("opacity", .22)
	pane_material.set_shader_parameter("shine", .8)
	pane_material.set_shader_parameter("rim_strength", .2)
	(panes.get_node("Fill") as MeshInstance3D).material_override = pane_material
	world.add_child(panes)
	# The plinth the shelves stand on, closing off the space under them.
	kit.add_rounded_box(Vector3(0, SHELF_BASE*.5, (-HALF_Z+SHELF_FRONT)*.5), Vector3(HALF_X*2, SHELF_BASE, HALF_Z+SHELF_FRONT), Color("ff8fb1"), Vector3.ZERO, true, 10)
	kit.add_rounded_box(Vector3(0, SHELF_BASE, (-HALF_Z+SHELF_FRONT)*.5), Vector3(HALF_X*2, .1, HALF_Z+SHELF_FRONT), KinuModel.GOLD, Vector3.ZERO, false, 10)
	# Two prize shelves on the back wall, showing items still waiting in the machine.
	for y in [SHELF_LOW, SHELF_HIGH]:
		kit.add_rounded_box(Vector3(0, y-.06, -HALF_Z+.55), Vector3(HALF_X*2-.2, .12, 1.1), Color("fffaf2"), Vector3.ZERO, true, 10)
		kit.add_rounded_box(Vector3(0, y-.12, -HALF_Z+1.1), Vector3(HALF_X*2-.2, .12, .06), KinuModel.GOLD, Vector3.ZERO, false, 10)
	# The ceiling with a rail along the front and back, and a row of marquee bulbs.
	var ceiling := MeshKit.new()
	ceiling.add_rounded_box(Vector3(0, CEILING+.2, 0), Vector3(HALF_X*2+.6, .4, HALF_Z*2+.6), Color("ff8fb1"), Vector3.ZERO, true, 10)
	_add_wall(ceiling, Vector3.UP)
	for z in [-HALF_Z+.25, HALF_Z-.25]:
		kit.add("cylinder", Vector3(0, CEILING-.12, z), Vector3(.12, HALF_X*2, .12), CHROME, Vector3(0, 0, PI*.5))
	# The chute: clear walls with a gold rim and a prize sign.
	var chute_center := CHUTE.get_center()
	for wall in [[Vector3(CHUTE.position.x+.04, .9, chute_center.y), Vector3(.08, 1.8, CHUTE.size.y)], [Vector3(CHUTE.end.x, .9, chute_center.y), Vector3(.08, 1.8, CHUTE.size.y)], [Vector3(chute_center.x, .9, CHUTE.position.y), Vector3(CHUTE.size.x, 1.8, .08)], [Vector3(chute_center.x, .55, HALF_Z), Vector3(CHUTE.size.x, 1.1, .08)]]:
		kit.add_rounded_box(wall[0], wall[1], Color("dff6ff"), Vector3.ZERO, true, 8)
	# Complete the chute's gold top lip on both sides. Previously only the inner/right edge was
	# built, leaving the prize-door side as an unfinished white edge from the front camera.
	kit.add_rounded_box(Vector3(CHUTE.position.x+.04, 1.82, chute_center.y), Vector3(.14, .08, CHUTE.size.y+.1), KinuModel.GOLD, Vector3.ZERO, true, 8)
	kit.add_rounded_box(Vector3(CHUTE.end.x, 1.82, chute_center.y), Vector3(.14, .08, CHUTE.size.y+.1), KinuModel.GOLD, Vector3.ZERO, true, 8)
	kit.add_rounded_box(Vector3(chute_center.x, 1.82, CHUTE.position.y), Vector3(CHUTE.size.x+.1, .08, .14), KinuModel.GOLD, Vector3.ZERO, true, 8)
	kit.add_rounded_box(Vector3(chute_center.x, .6, HALF_Z+.06), Vector3(1.2, .5, .06), PRIZE_RED, Vector3.ZERO, true, 8)
	for i in 14:
		var at := Vector3(-HALF_X+.2+i*(HALF_X*2-.4)/13.0, CEILING-.05, HALF_Z+.28)
		glow.add("sphere", at, Vector3.ONE*.2, [Color("fff1a8"), Color("ffffff"), Color("ffb3cf")][i % 3], Vector3.ZERO, false)
	var model := kit.build(.03)
	var fill := model.get_node("Fill") as MeshInstance3D
	fill.material_override = MeshKit.toon_material()
	world.add_child(model)
	var lit := glow.build(.03, false)
	var glow_material := ShaderMaterial.new()
	glow_material.shader = MeshKit.TOON
	glow_material.set_shader_parameter("glow", .8)
	(lit.get_node("Fill") as MeshInstance3D).material_override = glow_material
	world.add_child(lit)
	var sign := Label3D.new()
	sign.text = tr("PRIZE")
	sign.font = NestTheme.font
	sign.font_size = 56
	sign.pixel_size = .006
	sign.outline_size = 10
	sign.outline_modulate = Color("3a2418")
	sign.modulate = Color("fffaf0")
	sign.position = Vector3(chute_center.x, .6, HALF_Z+.1)
	world.add_child(sign)
	for words in [["Kinu Claw", Vector3(.3, -.7, HALF_Z+.49), 50, Color("ff6f91")], ["Prize Machine", Vector3(.3, -1.1, HALF_Z+.49), 30, Color("8a6d5a")]]:
		var label := Label3D.new()
		label.text = tr(words[0])
		label.font = NestTheme.font
		label.font_size = words[2]
		label.pixel_size = .006
		label.outline_size = 10 if words[2] > 40 else 0
		label.outline_modulate = Color("3a2418")
		label.modulate = words[3]
		label.position = words[1]
		world.add_child(label)
	_build_showcase()
	_add_collision()

## Outfits on the top shelf; boxes and rooms below. The rarest items the player doesn't own yet go
## on show first, falling back to the Catcher exclusives once most things are won.
func _build_showcase() -> void:
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	var picks := {"outfit": [], "box": [], "room": []}
	var available := KinuCatcher.odds(catalog, true)
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.chance) < float(b.chance))
	var entries := available.map(func(row: Dictionary) -> Dictionary: return row.entry)
	# Only collectables go on the shelves; beans and ticket wins have nothing to display.
	for entry in entries+KinuCatcher.table(catalog).filter(func(e: Dictionary) -> bool: return KinuCatcher.is_item(e)):
		var list: Array = picks[entry.kind]
		var item := KinuCatcher.item_of(catalog, entry)
		if item and not list.has(item) and list.size() < 4:
			list.append(item)
	var shapes := ["block", "ball", "tall", "slab"]
	for i in picks.outfit.size():
		var shape: KinuShape = catalog.shapes[0]
		for candidate in catalog.shapes:
			if candidate.id == shapes[i % shapes.size()]:
				shape = candidate
		var outfit: KinuOutfit = picks.outfit[i]
		var kinu := KinuModel.build(shape, outfit.finish if outfit.finish else catalog.flavours[0], null if outfit.finish else outfit, "happy")
		kinu.scale = Vector3.ONE*.62
		kinu.position = Vector3(-2.1+i*1.4, SHELF_HIGH+shape.size.y*.31, -HALF_Z+.5)
		world.add_child(kinu)
	var low: Array = []
	for i in 2:
		if i < picks.box.size():
			low.append(picks.box[i])
		if i < picks.room.size():
			low.append(picks.room[i])
	for i in low.size():
		var x := -2.1+i*1.4
		var decor: KinuDecor = low[i]
		if decor.kind == "box":
			# A little tilted display stand, so the box shows its inside rather than a thin edge.
			var stand := MeshKit.new()
			stand.add_rounded_box(Vector3(0, .12, 0), Vector3(1.05, .08, .95), Color("fffaf2"), Vector3(STAND_TILT, 0, 0), true, 8)
			stand.add_rounded_box(Vector3(0, .06, -.34), Vector3(.9, .2, .12), KinuModel.GOLD, Vector3.ZERO, true, 8)
			var stand_node := stand.build(.025)
			stand_node.position = Vector3(x, SHELF_LOW, -HALF_Z+.62)
			world.add_child(stand_node)
			var box := TofuBox.new()
			box.decor = decor
			box.with_collision = false
			box.scale = Vector3.ONE*.19
			box.rotation = Vector3(STAND_TILT, .35, 0)
			box.position = Vector3(x, SHELF_LOW+.2, -HALF_Z+.62)
			world.add_child(box)
		else:
			_room_picture(decor, Vector3(x, SHELF_LOW+.42, -HALF_Z+.12))

## A room shown as a gold-framed picture: its shop swatch drawn into a texture on the back wall.
func _room_picture(decor: KinuDecor, at: Vector3) -> void:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(170, 124)
	# Opaque, so the picture never sorts behind the see-through side glass when the case is turned.
	canvas.transparent_bg = false
	canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
	var swatch := DecorPreview.RoomSwatch.new()
	swatch.decor = decor
	swatch.size = Vector2(170, 124)
	canvas.add_child(swatch)
	# Kept inside the 3D world: a SubViewport directly under this container would be drawn flat on top.
	world.add_child(canvas)
	var picture := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.15, .84)
	picture.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = canvas.get_texture()
	picture.material_override = material
	picture.position = at+Vector3(0, 0, .05)
	world.add_child(picture)
	var frame := MeshKit.new()
	frame.add_rounded_box(Vector3.ZERO, Vector3(1.25, .94, .06), KinuModel.GOLD, Vector3.ZERO, true, 8)
	var node := frame.build(.02)
	node.position = at
	world.add_child(node)

func _add_wall(kit: MeshKit, _outward: Vector3) -> void:
	world.add_child(kit.build(.03))

func _add_collision() -> void:
	var body := StaticBody3D.new()
	world.add_child(body)
	var boxes := [
		# Floor, around the chute hole.
		[Vector3((CHUTE.end.x+HALF_X)*.5, -.1, 0), Vector3(HALF_X-CHUTE.end.x, .2, HALF_Z*2)],
		[Vector3((CHUTE.position.x+CHUTE.end.x)*.5, -.1, (CHUTE.position.y-HALF_Z)*.5), Vector3(CHUTE.size.x, .2, CHUTE.position.y+HALF_Z)],
		# The plinth under the back shelves. The claw drops straight down, so any floor it can
		# hover over must be clear all the way up — this fills the space beneath the shelves so
		# no capsule can settle where the claw would have to come through a shelf to reach it.
		[Vector3(0, SHELF_BASE*.5, (-HALF_Z+SHELF_FRONT)*.5), Vector3(HALF_X*2, SHELF_BASE, HALF_Z+SHELF_FRONT)],
		# Walls and the chute's own walls, taller than the pile so nothing rolls in by itself.
		[Vector3(0, CEILING*.5, -HALF_Z-.15), Vector3(HALF_X*2, CEILING, .3)],
		[Vector3(0, CEILING*.5, HALF_Z+.15), Vector3(HALF_X*2, CEILING, .3)],
		[Vector3(-HALF_X-.15, CEILING*.5, 0), Vector3(.3, CEILING, HALF_Z*2)],
		[Vector3(HALF_X+.15, CEILING*.5, 0), Vector3(.3, CEILING, HALF_Z*2)],
		[Vector3(CHUTE.end.x, 1.6, CHUTE.get_center().y), Vector3(.12, 3.2, CHUTE.size.y)],
		[Vector3(CHUTE.get_center().x, 1.6, CHUTE.position.y), Vector3(CHUTE.size.x, 3.2, .12)],
	]
	for entry in boxes:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[1]
		shape.shape = box
		shape.position = entry[0]
		body.add_child(shape)

func _build_claw() -> void:
	claw = Node3D.new()
	claw.position = HOME
	world.add_child(claw)
	var kit := MeshKit.new()
	kit.add("cylinder", Vector3(0, .05, 0), Vector3(.62, .32, .62), CHROME)
	kit.add("cone", Vector3(0, .35, 0), Vector3(.5, .3, .5), CHROME.darkened(.08))
	kit.add("torus", Vector3(0, -.08, 0), Vector3(.7, .5, .7), KinuModel.GOLD, Vector3.ZERO, false)
	kit.add("sphere", Vector3(0, -.14, 0), Vector3(.26, .16, .26), CHROME.darkened(.18))
	claw.add_child(_shiny(kit.build(.025)))
	var light := MeshInstance3D.new()
	var bead := SphereMesh.new()
	bead.radius = .07
	bead.height = .14
	light.mesh = bead
	var lit := ShaderMaterial.new()
	lit.shader = MeshKit.TOON
	lit.set_shader_parameter("glow", .9)
	light.material_override = lit
	light.position = Vector3(0, .06, .32)
	claw.add_child(light)
	bulbs.append(light)
	for i in 3:
		var pivot := Node3D.new()
		pivot.rotation.y = TAU*i/3.0
		pivot.position = Basis(Vector3.UP, TAU*i/3.0)*Vector3(0, -.12, .2)
		claw.add_child(pivot)
		var finger := Node3D.new()
		finger.rotation.x = CLOSED
		pivot.add_child(finger)
		var arm := MeshKit.new()
		arm.add("sphere", Vector3.ZERO, Vector3.ONE*.12, KinuModel.GOLD)
		arm.add_rounded_box(Vector3(0, -.3, .02), Vector3(.08, .58, .1), CHROME, Vector3(.08, 0, 0), true, 6)
		arm.add("sphere", Vector3(0, -.6, .04), Vector3.ONE*.1, CHROME.darkened(.1))
		arm.add_rounded_box(Vector3(0, -.72, -.08), Vector3(.08, .3, .09), CHROME, Vector3(.85, 0, 0), true, 6)
		finger.add_child(_shiny(arm.build(.025)))
		fingers.append(finger)
	cable = MeshInstance3D.new()
	var rope := CylinderMesh.new()
	rope.top_radius = .025
	rope.bottom_radius = .025
	rope.height = 1.0
	cable.mesh = rope
	cable.material_override = MeshKit.toon_material()
	world.add_child(cable)
	marker = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = .62
	disc.bottom_radius = .62
	disc.height = .01
	disc.radial_segments = 32
	marker.mesh = disc
	var shade := StandardMaterial3D.new()
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.albedo_color = Color(.2, .08, .25, .55)
	shade.no_depth_test = true
	shade.render_priority = 2
	marker.material_override = shade
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	world.add_child(marker)
	beam = MeshInstance3D.new()
	var line := CylinderMesh.new()
	line.top_radius = .02
	line.bottom_radius = .02
	line.height = 1.0
	beam.mesh = line
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color = Color(1, 1, 1, .6)
	beam.material_override = beam_material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visible = false
	world.add_child(beam)
	halo = MeshInstance3D.new()
	var glow_ball := SphereMesh.new()
	glow_ball.radius = CAPSULE_RADIUS*1.3
	glow_ball.height = CAPSULE_RADIUS*2.6
	halo.mesh = glow_ball
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1, .88, .3, .45)
	glow.cull_mode = BaseMaterial3D.CULL_FRONT
	halo.material_override = glow
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.visible = false
	world.add_child(halo)
	carriage = MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(.3, .16, HALF_Z*2-.3)
	carriage.mesh = bar
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = CHROME.darkened(.1)
	carriage.material_override = chrome
	world.add_child(carriage)

func _shiny(node: Node3D) -> Node3D:
	var material := ShaderMaterial.new()
	material.shader = MeshKit.TOON
	material.set_shader_parameter("shine", .9)
	material.set_shader_parameter("rim_strength", .3)
	(node.get_node("Fill") as MeshInstance3D).material_override = material
	return node

## The shared capsule meshes: a clear dome over a cream cup with a red band, and a wrapped prize.
static func capsule_parts() -> Array:
	if capsule_meshes.is_empty():
		var r := CAPSULE_RADIUS
		var top := MeshKit.new()
		var dome := PackedVector2Array()
		for k in 9:
			var theta := PI*.5*k/8.0
			dome.append(Vector2(sin(theta)*r, cos(theta)*r+.01))
		top.lathe(dome, 24, func(_s: int, _i: int) -> Color: return Color("f4fbff"), false)
		var bottom := MeshKit.new()
		var cup := PackedVector2Array([Vector2(r*1.05, .06), Vector2(r*1.05, -.07)])
		for k in 9:
			var theta := PI*.5+PI*.5*k/8.0
			cup.append(Vector2(sin(theta)*r, cos(theta)*r-.01))
		bottom.lathe(cup, 24, func(_s: int, i: int) -> Color: return CAPSULE_BAND if i == 0 else CAPSULE_COLOR)
		var inner := MeshKit.new()
		inner.add("sphere", Vector3(0, .04, 0), Vector3(.5, .4, .5), Color("fff6d8"), Vector3.ZERO, false)
		inner.add("sphere", Vector3(0, .22, 0), Vector3(.2, .14, .2), Color("ffd84d"), Vector3.ZERO, false)
		var glass := ShaderMaterial.new()
		glass.shader = SOFT_GLASS
		glass.set_shader_parameter("opacity", .55)
		glass.set_shader_parameter("shine", 1.0)
		glass.set_shader_parameter("rim_strength", .55)
		capsule_meshes = [top.commit_fill(), top.commit_hull(), bottom.commit_fill(), bottom.commit_hull(), inner.commit_fill(), glass]
	return capsule_meshes

## A capsule as plain meshes, for the machine and the reveal. Children: Inner, Bottom, Top.
static func capsule_model() -> Node3D:
	var parts := capsule_parts()
	var root := Node3D.new()
	var inner := MeshInstance3D.new()
	inner.name = "Inner"
	inner.mesh = parts[4]
	inner.material_override = MeshKit.toon_material()
	root.add_child(inner)
	var bottom := Node3D.new()
	bottom.name = "Bottom"
	root.add_child(bottom)
	var top := Node3D.new()
	top.name = "Top"
	root.add_child(top)
	for pair in [[bottom, parts[2], parts[3], MeshKit.toon_material()], [top, parts[0], parts[1], parts[5]]]:
		var fill := MeshInstance3D.new()
		fill.mesh = pair[1]
		fill.material_override = pair[3]
		pair[0].add_child(fill)
		if pair[2] == null or (pair[2] as ArrayMesh).get_surface_count() == 0:
			continue
		var line := MeshInstance3D.new()
		line.mesh = pair[2]
		line.material_override = MeshKit.outline_material(.02)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pair[0].add_child(line)
	return root

func _spawn_capsule(at: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = .4
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = .7
	body.physics_material_override.bounce = .2
	body.angular_damp = 1.5
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = CAPSULE_RADIUS
	shape.shape = sphere
	body.add_child(shape)
	body.add_child(capsule_model())
	body.position = at
	body.rotation = Vector3(rng.randf_range(-.8, .8), rng.randf()*TAU, rng.randf_range(-.8, .8))
	world.add_child(body)
	capsules.append(body)
	return body

# ---------- Playing ----------

func begin_aim() -> void:
	state = "aim"
	target = Vector2(.8, .2)
	Sound.play("plop")
	state_changed.emit()

## Dragging the case moves the claw while aiming, and turns the case the rest of the time.
func _gui_input(event: InputEvent) -> void:
	var motion := Vector2.ZERO
	if event is InputEventScreenTouch:
		pointer = event.index if event.pressed else -99
	elif event is InputEventScreenDrag and event.index == pointer:
		motion = event.relative
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		motion = event.relative
	if motion == Vector2.ZERO:
		return
	accept_event()
	if state == "aim":
		steer_claw(Vector2(motion.x, motion.y*1.4)*HALF_X*2.4/maxf(size.x, 1.0))
	else:
		turn_view(motion)

## Moves the claw target by an on-screen offset: right is the camera's right, up is away from it.
func steer_claw(offset: Vector2) -> void:
	if state != "aim":
		return
	_drag_motor = .12
	var right := Vector2(cos(yaw), -sin(yaw))
	var away := Vector2(-sin(yaw), -cos(yaw))
	target += right*offset.x-away*offset.y
	target = _reachable(target)

## Holds a steering target on the prize floor and off the chute, pushing it to whichever edge of
## the opening it is nearest so the claw slides along the hole rather than stopping dead at it.
func _reachable(at: Vector2) -> Vector2:
	at = at.clamp(REACH_MIN, REACH_MAX)
	var hole := CHUTE.grow(CHUTE_CLEAR)
	if not hole.has_point(at):
		return at
	if absf(at.y-hole.position.y) <= absf(at.x-hole.end.x):
		at.y = hole.position.y
	else:
		at.x = hole.end.x
	return at

## Turns and tilts the case by a drag or swipe, in pixels.
func turn_view(motion: Vector2) -> void:
	yaw_goal = clampf(yaw_goal-motion.x*.008, -YAW_LIMIT, YAW_LIMIT)
	pitch_goal = clampf(pitch_goal+motion.y*.005, PITCH_MIN, PITCH_MAX)

func _place_camera() -> void:
	var flat := Vector3(sin(yaw), 0, cos(yaw))
	camera.position = LOOK_AT+flat*CAMERA_DISTANCE*cos(pitch)+Vector3.UP*CAMERA_DISTANCE*sin(pitch)
	camera.look_at(LOOK_AT)


func _exit_tree() -> void:
	_motor_auto = false
	Sound.claw_motor(false)

func _process(delta: float) -> void:
	if not is_instance_valid(claw):
		return
	yaw_goal = clampf(yaw_goal-view_input.x*2.2*delta, -YAW_LIMIT, YAW_LIMIT)
	pitch_goal = clampf(pitch_goal+view_input.y*1.2*delta, PITCH_MIN, PITCH_MAX)
	yaw = lerpf(yaw, yaw_goal, 1.0-exp(-delta*10.0))
	pitch = lerpf(pitch, pitch_goal, 1.0-exp(-delta*10.0))
	_place_camera()
	if move_input != Vector2.ZERO:
		steer_claw(move_input*CLAW_SPEED*delta)
	# The motor runs whenever the claw is being steered or the case turned, by stick or by drag.
	_drag_motor = maxf(0.0, _drag_motor-delta)
	var steering := state == "aim" and (_drag_motor > 0.0 or view_input.length() > .04)
	Sound.claw_motor(steering or _motor_auto)
	var before := claw.position
	if state == "aim":
		var goal := Vector3(target.x, HOME.y, target.y)
		claw.position = claw.position.lerp(goal, 1.0-exp(-delta*7.0))
	elif state == "idle":
		claw.position.y = HOME.y+sin(Time.get_ticks_msec()*.002)*.04
	velocity = velocity.lerp((claw.position-before)/maxf(delta, .001), 1.0-exp(-delta*10.0))
	sway = lerpf(sway, 0.0, 1.0-exp(-delta*3.0))
	var wobble := sin(Time.get_ticks_msec()*.012)*sway
	claw.rotation.z = lerpf(claw.rotation.z, clampf(-velocity.x*.06, -.25, .25)+wobble, 1.0-exp(-delta*8.0))
	claw.rotation.x = lerpf(claw.rotation.x, clampf(velocity.z*.06, -.25, .25), 1.0-exp(-delta*8.0))
	var top := CEILING-.12
	var bottom := claw.position.y+.45
	cable.scale = Vector3(1, maxf(top-bottom, .01), 1)
	cable.position = Vector3(claw.position.x, (top+bottom)*.5, claw.position.z)
	carriage.position = Vector3(claw.position.x, CEILING-.16, 0)
	var blink := int(Time.get_ticks_msec()*.004) % 2 == 0
	for bulb in bulbs:
		bulb.visible = state != "busy" or blink

## Runs the whole catch: open, lower onto the nearest capsule, grab, lift, carry it to the chute and
## drop it in. Emits `delivered` once the capsule has gone down the chute.
func drop() -> void:
	if state != "aim":
		return
	state = "busy"
	state_changed.emit()
	Haptics.pulse(15, .3)
	await _fingers(OPEN, .22)
	var capsule := _nearest_capsule()
	if capsule == null:
		capsule = _spawn_capsule(claw.position-Vector3(0, 2.0, 0))
	var reach := Vector3(lerpf(claw.position.x, capsule.position.x, .85), capsule.position.y-GRIP.y+.06, lerpf(claw.position.z, capsule.position.z, .85))
	var lower := create_tween()
	lower.tween_property(claw, "position", reach, .95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motor_auto = true
	await lower.finished
	_motor_auto = false
	capsule.freeze = true
	capsule.collision_layer = 0
	capsule.collision_mask = 0
	capsules.erase(capsule)
	var grab := create_tween().set_parallel(true)
	for finger in fingers:
		grab.tween_property(finger, "rotation:x", CLOSED+.08, .26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grab.tween_property(capsule, "global_position", claw.global_position+GRIP, .26).set_trans(Tween.TRANS_SINE)
	await grab.finished
	capsule.reparent(claw)
	Sound.play("plop", .9)
	Haptics.pulse(25, .45)
	await get_tree().create_timer(.22).timeout
	sway = .12
	var lift := create_tween()
	lift.tween_property(claw, "position:y", HOME.y, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motor_auto = true
	await lift.finished
	var carry := create_tween()
	carry.tween_property(claw, "position", HOME, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await carry.finished
	_motor_auto = false
	sway = .06
	await get_tree().create_timer(.25).timeout
	capsule.reparent(world)
	capsule.freeze = false
	capsule.collision_layer = 1
	capsule.collision_mask = 1
	capsule.linear_velocity = Vector3.DOWN*.5
	capsule.angular_velocity = Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	await _fingers(OPEN, .2)
	await get_tree().create_timer(.45).timeout
	Sound.play("drop")
	Haptics.pulse(30, .55)
	await get_tree().create_timer(.35).timeout
	if is_instance_valid(capsule):
		capsule.queue_free()
	await _fingers(CLOSED, .25)
	state = "idle"
	state_changed.emit()
	delivered.emit()
	# A fresh capsule tumbles in to keep the pile full.
	_spawn_capsule(Vector3(rng.randf_range(CHUTE.end.x+.3, HALF_X-.6), CEILING-1.0, rng.randf_range(REACH_MIN.y+.15, 1.2)))

## Casts straight down from the claw onto the pile or floor and shows where it will come down.
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(marker):
		return
	var aiming := state == "aim"
	marker.visible = aiming
	beam.visible = aiming
	halo.visible = false
	if not aiming:
		return
	var target_capsule := _nearest_capsule()
	if target_capsule:
		halo.visible = true
		halo.global_position = target_capsule.global_position
		halo.scale = Vector3.ONE*(1.0+.08*sin(Time.get_ticks_msec()*.008))
	var from := claw.global_position+GRIP
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from-Vector3.UP*10.0))
	var ground: Vector3 = hit.get("position", Vector3(from.x, 0, from.z))
	marker.global_position = ground+Vector3.UP*.02
	var length := maxf(.01, from.y-ground.y)
	beam.global_position = (from+ground)*.5
	beam.scale = Vector3(1, length, 1)

func _fingers(angle: float, seconds: float) -> void:
	var tween := create_tween().set_parallel(true)
	for finger in fingers:
		tween.tween_property(finger, "rotation:x", angle, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _nearest_capsule() -> RigidBody3D:
	var best: RigidBody3D = null
	var best_score := INF
	for capsule in capsules:
		if not is_instance_valid(capsule) or CHUTE.grow(.2).has_point(Vector2(capsule.position.x, capsule.position.z)):
			continue
		# Prefer capsules right under the claw, and those near the top of the pile.
		var score := Vector2(capsule.position.x-claw.position.x, capsule.position.z-claw.position.z).length()-capsule.position.y*.25
		if score < best_score:
			best_score = score
			best = capsule
	return best
