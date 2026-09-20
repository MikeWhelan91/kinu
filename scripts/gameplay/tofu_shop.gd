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

## The equipped room theme. Null uses the default tofu-shop palette.
var decor: KinuDecor
var steam: Array[MeshInstance3D] = []
var particles: Array[Dictionary] = []

func _c(key: String, fallback: Color) -> Color:
	return decor.palette.get(key, fallback) if decor else fallback

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
	environment.environment.background_color = _c("background", Color("f4d9ad"))
	environment.environment.ambient_light_color = _c("ambient", Color("fff1dc"))
	add_child(environment)
	var sun := make_sun()
	sun.light_color = _c("sun", Color("fff4e2"))
	if decor:
		sun.light_energy = float(decor.palette.get("sun_energy", sun.light_energy))
		environment.environment.ambient_light_energy = float(decor.palette.get("ambient_energy", .1))
	add_child(sun)
	add_child(_counter())
	var layout := decor.layout if decor else ""
	add_child(_room() if layout == "" else RoomScenery.build(self, layout))
	_counter_collision()
	if layout == "":
		_build_steam()
	_build_particles(decor.effect if decor else "")

func _counter() -> Node3D:
	var kit := MeshKit.new()
	var span := COUNTER_HALF*2
	kit.add_rounded_box(Vector3(0, -.225, 0), Vector3(span, .45, span), _c("wood", WOOD), Vector3.ZERO, true, 10.0)
	# Plank seams on the counter top.
	for i in 6:
		var x := -COUNTER_HALF+span*(i+1)/7.0
		kit.add_rounded_box(Vector3(x, .01, 0), Vector3(.05, .03, span-.2), _c("wood_deep", WOOD_DEEP), Vector3.ZERO, false, 10.0)
	kit.add_rounded_box(Vector3(0, -.45-(COUNTER_HEIGHT-.45)*.5, 0), Vector3(span-.4, COUNTER_HEIGHT-.45, span-.4), _c("wood_deep", WOOD_DEEP), Vector3.ZERO, true, 10.0)
	for side in 4:
		var basis := Basis(Vector3.UP, side*PI*.5)
		for i in 7:
			var x := -COUNTER_HALF+.6+i*(span-1.2)/6.0
			kit.add_rounded_box(basis*Vector3(x, -1.8, COUNTER_HALF-.18), Vector3(.12, COUNTER_HEIGHT-.9, .06), _c("post", POST), Vector3(0, side*PI*.5, 0), false, 10.0)
	# Tenugui cloth under the tofu box: white border, indigo middle.
	kit.add_rounded_box(Vector3(0, .02, 0), Vector3(5.6, .04, 5.6), _c("paper", PAPER), Vector3.ZERO, false, 10.0)
	kit.add_rounded_box(Vector3(0, .04, 0), Vector3(5.1, .06, 5.1), _c("noren", INDIGO), Vector3.ZERO, false, 10.0)
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
	kit.add_rounded_box(Vector3(0, floor_y-.2, 0), Vector3(ROOM_HALF*2, .4, ROOM_HALF*2), _c("floor", Color("9c6a42")), Vector3.ZERO, false, 10.0)
	for i in 12:
		kit.add_rounded_box(Vector3(-ROOM_HALF+(i+.5)*2.5, floor_y+.01, 0), Vector3(.06, .03, ROOM_HALF*2), _c("floor_line", Color("7f5433")), Vector3.ZERO, false, 10.0)
	for side in 4:
		var angle := side*PI*.5
		var basis := Basis(Vector3.UP, angle)
		var rotation := Vector3(0, angle, 0)
		var at := func(x: float, y: float, inset: float) -> Vector3:
			return basis*Vector3(x, floor_y+y, -ROOM_HALF+inset)
		kit.add_rounded_box(at.call(0.0, WALL_HEIGHT*.5, -.2), Vector3(ROOM_HALF*2, WALL_HEIGHT, .4), _c("plaster", PLASTER), rotation, false, 10.0)
		kit.add_rounded_box(at.call(0.0, 1.6, .06), Vector3(ROOM_HALF*2, 3.2, .3), _c("wood_deep", WOOD_DEEP), rotation, true, 10.0)
		for p in 6:
			kit.add_rounded_box(at.call(-ROOM_HALF+p*6.0, WALL_HEIGHT*.5, .25), Vector3(.5, WALL_HEIGHT, .5), _c("post", POST), rotation, true, 10.0)
		kit.add_rounded_box(at.call(0.0, 9.6, .25), Vector3(ROOM_HALF*2, .45, .45), _c("post", POST), rotation, true, 10.0)
		for panel in 5:
			var x := -ROOM_HALF+3.0+panel*6.0
			if side == 0 and panel == 2:
				_noren(kit, at, rotation, x)
				continue
			if side % 2 == 1 and panel % 2 == 0:
				_shelves(kit, at, rotation, basis, x)
				continue
			_shoji(kit, at, rotation, x)
	var lanterns := MeshKit.new()
	for i in 8:
		var a := TAU*i/8.0+.2
		_lantern(lanterns, Vector3(sin(a)*9.5, 5.5+(i % 3)*.9, cos(a)*9.5))
	var lantern_node := lanterns.build(.06, false)
	if decor and (decor.effect == "fireflies" or decor.palette.get("lantern_glow", false)):
		var glow := ShaderMaterial.new()
		glow.shader = MeshKit.TOON
		glow.set_shader_parameter("glow", .55)
		(lantern_node.get_node("Fill") as MeshInstance3D).material_override = glow
	add_child(lantern_node)
	_stove(kit, Vector3(-9.5, floor_y, -9.5))
	return kit.build(.06, false)

func _shoji(kit: MeshKit, at: Callable, rotation: Vector3, x: float) -> void:
	kit.add_rounded_box(at.call(x, 6.2, .2), Vector3(5.2, 5.6, .1), _c("paper", PAPER), rotation, true, 10.0)
	for c in 3:
		kit.add_rounded_box(at.call(x-1.3+c*1.3, 6.2, .27), Vector3(.08, 5.6, .06), _c("post", POST), rotation, false, 10.0)
	for r in 4:
		kit.add_rounded_box(at.call(x, 3.9+r*1.5, .27), Vector3(5.2, .08, .06), _c("post", POST), rotation, false, 10.0)

## Split indigo curtain over the doorway, each strip with a white tofu emblem.
func _noren(kit: MeshKit, at: Callable, rotation: Vector3, x: float) -> void:
	kit.add_rounded_box(at.call(x, 6.3, .12), Vector3(5.2, 5.8, .1), Color("6b4a33"), rotation, false, 10.0)
	kit.add_rounded_box(at.call(x, 9.1, .45), Vector3(5.6, .16, .16), _c("post", POST), rotation, true, 10.0)
	for s in 4:
		var sx := x-1.95+s*1.3
		kit.add_rounded_box(at.call(sx, 7.4, .5), Vector3(1.22, 3.2, .06), _c("noren", INDIGO), rotation, true, 10.0)
		kit.add("cylinder", at.call(sx, 7.6, .57), Vector3(.8, .04, .8), _c("paper", PAPER), rotation+Vector3(PI*.5, 0, 0), false)
		kit.add_rounded_box(at.call(sx, 7.6, .62), Vector3(.36, .36, .04), _c("noren", INDIGO), rotation, false, 8.0)

func _shelves(kit: MeshKit, at: Callable, rotation: Vector3, basis: Basis, x: float) -> void:
	var tofu := [Color("fff5dc"), Color("e3f3c9"), Color("ffe3ec"), Color("fbdfae")]
	for level in 3:
		var y := 4.0+level*1.8
		kit.add_rounded_box(at.call(x, y, .8), Vector3(5.2, .16, 1.1), _c("wood", WOOD), rotation, true, 10.0)
		for item in 5:
			var ix := x-2.0+item
			if (item+level) % 3 == 0:
				kit.add("cylinder", at.call(ix, y+.26, .8), Vector3(.62, .36, .62), Color("f2efe6"))
				kit.add("torus", at.call(ix, y+.44, .8), Vector3(.64, .12, .64), _c("noren", INDIGO), Vector3.ZERO, false)
			else:
				kit.add_rounded_box(at.call(ix, y+.3, .8), Vector3(.52, .44, .5), tofu[(item+level) % 4], rotation, true, 7.0)

func _lantern(kit: MeshKit, center: Vector3) -> void:
	# The room is open above so a tall tower never pushes the camera into the ceiling.
	kit.add("cylinder", center+Vector3(0, (WALL_HEIGHT-center.y)*.5+.8, 0), Vector3(.05, WALL_HEIGHT-center.y-1.6, .05), INK, Vector3.ZERO, false)
	kit.add("sphere", center, Vector3(1.3, 1.65, 1.3), _c("lantern", LANTERN))
	for ring in [-.45, 0.0, .45]:
		kit.add("torus", center+Vector3(0, ring, 0), Vector3(1.28-absf(ring)*.35, .05, 1.28-absf(ring)*.35), _c("lantern", LANTERN).darkened(.2), Vector3.ZERO, false)
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

const PARTICLE_COLORS := {
	"snow": [Color(1, 1, 1, .95)],
	"petals": [Color("ffb3c8")],
	"fireflies": [Color(1, .9, .45, .9)],
	"leaves": [Color("e8552f"), Color("f28b2c"), Color("f6c343")],
	"rain": [Color(.75, .85, 1.0, .55)],
	"mist": [Color(1, 1, 1, .14)],
	"sparks": [Color(1, .8, .35, .95), Color(1, .5, .45, .95)],
	"stars": [Color(1, .97, .8, .95)],
	"bubbles": [Color(.85, .97, 1.0, .5)],
	"fireworks": [Color("ffd166"), Color("ff7aa2"), Color("8ce0ff"), Color("b5ff8c")],
	"confetti": [Color("ff8fb1"), Color("7fd4e8"), Color("ffd84d"), Color("9ccc5a"), Color("b99cf2")],
}
const PARTICLE_COUNTS := {"snow": 70, "petals": 45, "fireflies": 30, "leaves": 40, "rain": 120, "mist": 16, "sparks": 45, "stars": 60, "bubbles": 50, "fireworks": 96, "confetti": 60}
const PARTICLE_SCALES := {"snow": Vector3.ONE*.12, "petals": Vector3(.2, .04, .14), "fireflies": Vector3.ONE*.1, "leaves": Vector3(.28, .04, .22), "rain": Vector3(.03, .55, .03), "mist": Vector3(3.2, 1.6, 3.2), "sparks": Vector3.ONE*.09, "stars": Vector3.ONE*.14, "bubbles": Vector3.ONE*.16, "fireworks": Vector3.ONE*.35, "confetti": Vector3(.18, .02, .12)}
## Fireworks go off in bursts of this many sparks.
const BURST := 16

## Ambient particles for the room theme. A palette "particles" array recolours them.
func _build_particles(effect: String) -> void:
	if not PARTICLE_COUNTS.has(effect):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24 if effect == "mist" else 8
	mesh.rings = 12 if effect == "mist" else 4
	var materials: Array[StandardMaterial3D] = []
	for color in decor.palette.get("particles", PARTICLE_COLORS[effect]):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		materials.append(material)
	for i in PARTICLE_COUNTS[effect]:
		var dot := MeshInstance3D.new()
		dot.mesh = mesh
		dot.material_override = materials[i % materials.size()]
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.scale = PARTICLE_SCALES[effect]
		add_child(dot)
		var radius := rng.randf_range(3.5, 12.5) if effect != "mist" else rng.randf_range(5.5, 11.0)
		var item := {"node": dot, "effect": effect, "angle": rng.randf()*TAU, "radius": radius, "phase": rng.randf(), "speed": rng.randf_range(.7, 1.3)}
		if effect == "fireworks":
			# Sparks share their burst's centre and timing, and fly out along their own direction.
			var burst: int = int(i)/BURST
			var burst_rng := RandomNumberGenerator.new()
			burst_rng.seed = burst*31+5
			var around := burst_rng.randf_range(-1.1, 1.1)+RoomScenery.MENU_FACING
			item.center = Vector3(sin(around)*30.0, burst_rng.randf_range(14.0, 24.0), cos(around)*30.0)
			item.phase = burst*.37
			item.speed = 1.0
			var a: float = TAU*(int(i) % BURST)/BURST
			item.direction = Vector3(cos(a), sin(a), sin(a*2.0)*.4).normalized()
			dot.material_override = materials[burst % materials.size()]
		particles.append(item)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()*.001
	for item in particles:
		var node: MeshInstance3D = item.node
		var t: float = now*float(item.speed)+float(item.phase)*20.0
		var angle: float = item.angle+sin(t*.3)*.2
		var height: float
		match item.effect:
			"snow":
				height = 16.0-fmod(t*1.1, 19.0)
			"petals":
				height = 16.0-fmod(t*.7, 19.0)
				node.rotation = Vector3(t*1.7, t, t*1.3)
			"fireflies":
				height = 1.5+sin(t*.8)*2.0+float(item.phase)*5.0
				angle += t*.05
			"leaves":
				height = 16.0-fmod(t*.8, 19.0)
				node.rotation = Vector3(t*1.3, t*.9, sin(t)*1.2)
				angle += sin(t*.6)*.15
			"rain":
				height = 16.0-fmod(t*9.0, 19.0)
			"mist":
				height = -COUNTER_HEIGHT+.9+sin(t*.25)*.4
				angle += t*.02
			"sparks":
				height = -COUNTER_HEIGHT+fmod(t*1.4, 20.0)
				angle += sin(t*2.0)*.05
			"stars":
				height = 11.0+float(item.phase)*14.0
				node.scale = Vector3.ONE*(.08+.08*absf(sin(t*1.5)))
			"bubbles":
				height = -COUNTER_HEIGHT+fmod(t*1.6, 22.0)
				angle += sin(t*1.8)*.03
			"confetti":
				height = 16.0-fmod(t*1.2, 19.0)
				node.rotation = Vector3(t*3.1, t*2.3, t*1.7)
			"fireworks":
				# Each burst blooms, drifts down and fades, then waits its turn to go off again.
				var cycle := fmod(now*.45+float(item.phase), 3.0)
				var bloom := clampf(cycle/1.4, 0, 1)
				node.visible = cycle < 1.8
				node.position = item.center+item.direction*(1.0-pow(1.0-bloom, 3.0))*5.5-Vector3.UP*cycle*cycle*.6
				node.scale = PARTICLE_SCALES.fireworks*(1.0-clampf((cycle-1.0)/.8, 0, 1))
				continue
		node.position = Vector3(sin(angle), 0, cos(angle))*float(item.radius)+Vector3(sin(t)*.4, height, cos(t*.9)*.4)
	var clock := Time.get_ticks_msec()*.00025
	for puff in steam:
		var t := fmod(clock+float(puff.get_meta("phase")), 1.0)
		puff.position = Vector3(-9.5+sin(t*6.0+float(puff.get_meta("phase"))*9.0)*.4, -COUNTER_HEIGHT+4.3+t*5.0, -9.5)
		puff.scale = Vector3.ONE*lerpf(.5, 1.6, t)
		(puff.material_override as StandardMaterial3D).albedo_color.a = .7*(1.0-t)
