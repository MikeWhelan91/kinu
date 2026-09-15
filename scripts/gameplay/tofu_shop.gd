class_name TofuShop
extends Node3D
## Kinu's home: a cosy Japanese tofu shop. The tofu box sits on the counter; the room wraps all
## the way round because the camera orbits.

const COUNTER_HALF := 4.2
const COUNTER_HEIGHT := 3.2
const ROOM_HALF := 15.0
const WALL_HEIGHT := 40.0
## Touching anything in this group means a Kinu has fallen out of the box.
const GROUND_GROUP := "ground"

const INK := Color("2b1a17")
const PLASTER := Color("f7e8cc")
const POST := Color("8a5532")
const WOOD := Color("b77c4b")
const WOOD_DEEP := Color("8f5a34")
const PAPER := Color("fff8e8")
const INDIGO := Color("3a5aa8")
const LANTERN := Color("ec4a3c")

var steam: Array[MeshInstance3D] = []

static func make_environment() -> Environment:
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("f4d9ad")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("fff1dc")
	settings.ambient_light_energy = .1
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	return settings

static func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("fff4e2")
	sun.light_energy = .9
	sun.shadow_enabled = true
	sun.shadow_bias = .04
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30
	return sun

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = make_environment()
	add_child(environment)
	add_child(make_sun())
	add_child(_counter())
	add_child(_room())
	_counter_collision()
	_build_steam()

func _counter() -> Node3D:
	var kit := MeshKit.new()
	var span := COUNTER_HALF*2
	kit.add_rounded_box(Vector3(0, -.225, 0), Vector3(span, .45, span), WOOD, Vector3.ZERO, true, 10.0)
	# Plank seams on the counter top.
	for i in 6:
		var x := -COUNTER_HALF+span*(i+1)/7.0
		kit.add_rounded_box(Vector3(x, .01, 0), Vector3(.05, .03, span-.2), WOOD_DEEP, Vector3.ZERO, false, 10.0)
	kit.add_rounded_box(Vector3(0, -.45-(COUNTER_HEIGHT-.45)*.5, 0), Vector3(span-.4, COUNTER_HEIGHT-.45, span-.4), WOOD_DEEP, Vector3.ZERO, true, 10.0)
	for side in 4:
		var basis := Basis(Vector3.UP, side*PI*.5)
		for i in 7:
			var x := -COUNTER_HALF+.6+i*(span-1.2)/6.0
			kit.add_rounded_box(basis*Vector3(x, -1.8, COUNTER_HALF-.18), Vector3(.12, COUNTER_HEIGHT-.9, .06), POST, Vector3(0, side*PI*.5, 0), false, 10.0)
	# Tenugui cloth under the tofu box: white border, indigo middle.
	kit.add_rounded_box(Vector3(0, .02, 0), Vector3(5.0, .04, 5.0), PAPER, Vector3.ZERO, false, 10.0)
	kit.add_rounded_box(Vector3(0, .04, 0), Vector3(4.5, .06, 4.5), INDIGO, Vector3.ZERO, false, 10.0)
	return kit.build(.045)

func _counter_collision() -> void:
	var table := StaticBody3D.new()
	table.add_to_group(GROUND_GROUP)
	table.collision_layer = 1
	table.collision_mask = 2
	var top := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(COUNTER_HALF*2, COUNTER_HEIGHT, COUNTER_HALF*2)
	top.shape = box
	top.position.y = -COUNTER_HEIGHT*.5
	table.add_child(top)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(ROOM_HALF*2, .4, ROOM_HALF*2)
	floor_shape.shape = floor_box
	floor_shape.position.y = -COUNTER_HEIGHT-.2
	table.add_child(floor_shape)
	add_child(table)

func _room() -> Node3D:
	var kit := MeshKit.new()
	var floor_y := -COUNTER_HEIGHT
	kit.add_rounded_box(Vector3(0, floor_y-.2, 0), Vector3(ROOM_HALF*2, .4, ROOM_HALF*2), Color("9c6a42"), Vector3.ZERO, false, 10.0)
	for i in 12:
		kit.add_rounded_box(Vector3(-ROOM_HALF+(i+.5)*2.5, floor_y+.01, 0), Vector3(.06, .03, ROOM_HALF*2), Color("7f5433"), Vector3.ZERO, false, 10.0)
	for side in 4:
		var angle := side*PI*.5
		var basis := Basis(Vector3.UP, angle)
		var rotation := Vector3(0, angle, 0)
		var at := func(x: float, y: float, inset: float) -> Vector3:
			return basis*Vector3(x, floor_y+y, -ROOM_HALF+inset)
		kit.add_rounded_box(at.call(0.0, WALL_HEIGHT*.5, -.2), Vector3(ROOM_HALF*2, WALL_HEIGHT, .4), PLASTER, rotation, false, 10.0)
		kit.add_rounded_box(at.call(0.0, 1.6, .06), Vector3(ROOM_HALF*2, 3.2, .3), WOOD_DEEP, rotation, true, 10.0)
		for p in 6:
			kit.add_rounded_box(at.call(-ROOM_HALF+p*6.0, WALL_HEIGHT*.5, .25), Vector3(.5, WALL_HEIGHT, .5), POST, rotation, true, 10.0)
		kit.add_rounded_box(at.call(0.0, 9.6, .25), Vector3(ROOM_HALF*2, .45, .45), POST, rotation, true, 10.0)
		for panel in 5:
			var x := -ROOM_HALF+3.0+panel*6.0
			if side == 0 and panel == 2:
				_noren(kit, at, rotation, x)
				continue
			if side % 2 == 1 and panel % 2 == 0:
				_shelves(kit, at, rotation, basis, x)
				continue
			_shoji(kit, at, rotation, x)
	for i in 8:
		var a := TAU*i/8.0+.2
		_lantern(kit, Vector3(sin(a)*9.5, 5.5+(i % 3)*.9, cos(a)*9.5))
	_stove(kit, Vector3(-9.5, floor_y, -9.5))
	return kit.build(.06, false)

func _shoji(kit: MeshKit, at: Callable, rotation: Vector3, x: float) -> void:
	kit.add_rounded_box(at.call(x, 6.2, .2), Vector3(5.2, 5.6, .1), PAPER, rotation, true, 10.0)
	for c in 3:
		kit.add_rounded_box(at.call(x-1.3+c*1.3, 6.2, .27), Vector3(.08, 5.6, .06), POST, rotation, false, 10.0)
	for r in 4:
		kit.add_rounded_box(at.call(x, 3.9+r*1.5, .27), Vector3(5.2, .08, .06), POST, rotation, false, 10.0)

## Split indigo curtain over the doorway, each strip with a white tofu emblem.
func _noren(kit: MeshKit, at: Callable, rotation: Vector3, x: float) -> void:
	kit.add_rounded_box(at.call(x, 6.3, .12), Vector3(5.2, 5.8, .1), Color("6b4a33"), rotation, false, 10.0)
	kit.add_rounded_box(at.call(x, 9.1, .45), Vector3(5.6, .16, .16), POST, rotation, true, 10.0)
	for s in 4:
		var sx := x-1.95+s*1.3
		kit.add_rounded_box(at.call(sx, 7.4, .5), Vector3(1.22, 3.2, .06), INDIGO, rotation, true, 10.0)
		kit.add("cylinder", at.call(sx, 7.6, .57), Vector3(.8, .04, .8), PAPER, rotation+Vector3(PI*.5, 0, 0), false)
		kit.add_rounded_box(at.call(sx, 7.6, .62), Vector3(.36, .36, .04), INDIGO, rotation, false, 8.0)

func _shelves(kit: MeshKit, at: Callable, rotation: Vector3, basis: Basis, x: float) -> void:
	var tofu := [Color("fff5dc"), Color("e3f3c9"), Color("ffe3ec"), Color("fbdfae")]
	for level in 3:
		var y := 4.0+level*1.8
		kit.add_rounded_box(at.call(x, y, .8), Vector3(5.2, .16, 1.1), WOOD, rotation, true, 10.0)
		for item in 5:
			var ix := x-2.0+item
			if (item+level) % 3 == 0:
				kit.add("cylinder", at.call(ix, y+.26, .8), Vector3(.62, .36, .62), Color("f2efe6"))
				kit.add("torus", at.call(ix, y+.44, .8), Vector3(.64, .12, .64), INDIGO, Vector3.ZERO, false)
			else:
				kit.add_rounded_box(at.call(ix, y+.3, .8), Vector3(.52, .44, .5), tofu[(item+level) % 4], rotation, true, 7.0)

func _lantern(kit: MeshKit, center: Vector3) -> void:
	# The room is open above so a tall tower never pushes the camera into the ceiling.
	kit.add("cylinder", center+Vector3(0, (WALL_HEIGHT-center.y)*.5+.8, 0), Vector3(.05, WALL_HEIGHT-center.y-1.6, .05), INK, Vector3.ZERO, false)
	kit.add("sphere", center, Vector3(1.3, 1.65, 1.3), LANTERN)
	for ring in [-.45, 0.0, .45]:
		kit.add("torus", center+Vector3(0, ring, 0), Vector3(1.28-absf(ring)*.35, .05, 1.28-absf(ring)*.35), LANTERN.darkened(.2), Vector3.ZERO, false)
	for cap in [-1.0, 1.0]:
		kit.add("cylinder", center+Vector3(0, cap*.8, 0), Vector3(.62, .16, .62), INK)
	kit.add("cylinder", center+Vector3(0, -1.05, 0), Vector3(.1, .4, .1), Color("ffcf4d"), Vector3.ZERO, false)

## A plastered kamado stove with a big pot of soy milk, where Kinu are made.
func _stove(kit: MeshKit, base: Vector3) -> void:
	kit.add_rounded_box(base+Vector3(0, 1.7, 0), Vector3(2.6, 3.4, 2.6), Color("f1e3cf"), Vector3.ZERO, true, 6.0)
	kit.add_rounded_box(base+Vector3(0, .9, 1.3), Vector3(1.0, .9, .06), INK, Vector3.ZERO, false, 6.0)
	kit.add("cylinder", base+Vector3(0, 3.75, 0), Vector3(2.0, .7, 2.0), Color("4a4650"))
	kit.add("torus", base+Vector3(0, 4.1, 0), Vector3(2.05, .2, 2.05), Color("35323a"))
	kit.add("cylinder", base+Vector3(0, 4.05, 0), Vector3(1.8, .02, 1.8), Color("fffaf0"), Vector3.ZERO, false)

func _build_steam() -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 1, 1, .7)
	for i in 8:
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.material_override = material.duplicate()
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.set_meta("phase", i/8.0)
		add_child(puff)
		steam.append(puff)

func _process(_delta: float) -> void:
	var clock := Time.get_ticks_msec()*.00025
	for puff in steam:
		var t := fmod(clock+float(puff.get_meta("phase")), 1.0)
		puff.position = Vector3(-9.5+sin(t*6.0+float(puff.get_meta("phase"))*9.0)*.4, -COUNTER_HEIGHT+4.3+t*5.0, -9.5)
		puff.scale = Vector3.ONE*lerpf(.5, 1.6, t)
		(puff.material_override as StandardMaterial3D).albedo_color.a = .7*(1.0-t)
