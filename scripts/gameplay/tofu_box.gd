class_name TofuBox
extends Node3D
## A wooden masu tofu box, about three to four Kinu wide: roomy enough to plan a base,
## small enough that the pile soon has to grow upward. Square, so spinning reads clearly.

## Scaled up 10% from the original 1.8/.24/.18/1.1 to leave more room for the Kinu inside.
const INNER_HALF := 1.98
const WALL := .264
const FLOOR_TOP := .198
const RIM_HEIGHT := 1.21
## Radius used by circular checks (balance support, placement): the inner wall distance.
const RIM_RADIUS := INNER_HALF

const WOOD := Color("f6dfb4")
const WOOD_DARK := Color("d9ad74")
const WOOD_LIGHT := Color("fbe9c8")
const HANKO := Color("e0463a")

## The equipped box skin (colours and finish). Null uses the default hinoki palette.
var decor: KinuDecor
## Previews skip physics.
var with_collision: bool = true

func _color(key: String, fallback: Color) -> Color:
	return decor.palette.get(key, fallback) if decor else fallback

static func contains(point: Vector3, margin: float = 0.0) -> bool:
	var reach := INNER_HALF+WALL+margin
	return absf(point.x) <= reach and absf(point.z) <= reach

## Built box models by skin id; new boxes and shop previews duplicate these (sharing meshes).
static var models: Dictionary = {}

func _ready() -> void:
	var key := decor.id if decor else "default"
	if not models.has(key):
		models[key] = _build_model()
	add_child((models[key] as Node3D).duplicate())
	if with_collision:
		_add_collision()

func _build_model() -> Node3D:
	var kit := MeshKit.new()
	var effect := decor.effect if decor else ""
	# Neon trim is built separately so only the rim, posts and stamps glow.
	var trim := MeshKit.new() if effect == "glow" else kit
	var outer := INNER_HALF+WALL
	var wood := _color("wood", WOOD)
	var wood_dark := _color("wood_dark", WOOD_DARK)
	var wood_light := _color("wood_light", WOOD_LIGHT)
	# Floor boards.
	for i in 5:
		var x := -INNER_HALF+INNER_HALF*.4*(i+.5)
		kit.add_rounded_box(Vector3(x, FLOOR_TOP*.5, 0), Vector3(INNER_HALF*.4-.02, FLOOR_TOP, INNER_HALF*2), wood_light if i % 2 else wood, Vector3.ZERO, true, 10.0)
	# Two stacked planks per wall, with a darker rim trim.
	for side in 4:
		var angle := side*PI*.5
		var basis := Basis(Vector3.UP, angle)
		for plank in 2:
			var height := (RIM_HEIGHT-.08)*.5
			var center := basis*Vector3(0, height*(plank+.5), INNER_HALF+WALL*.5)
			kit.add_rounded_box(center, Vector3(outer*2-.02, height-.02, WALL), wood if plank == 0 else wood_light, Vector3(0, angle, 0), true, 10.0)
		trim.add_rounded_box(basis*Vector3(0, RIM_HEIGHT-.04, INNER_HALF+WALL*.5), Vector3(outer*2+.04, .1, WALL+.06), wood_dark, Vector3(0, angle, 0), true, 10.0)
		_wall_pattern(kit, effect, basis, angle, outer)
		# Hanko stamp: a red seal with a little white tofu square, on every side.
		var face := basis*Vector3(0, RIM_HEIGHT*.45, outer+.022)
		trim.add("cylinder", face, Vector3(.46, .02, .46), _color("stamp", HANKO), Vector3(PI*.5, angle, 0), false)
		trim.add_rounded_box(face+basis*Vector3(0, 0, .02), Vector3(.2, .2, .02), _color("stamp_mark", Color("fff6e2")), Vector3(0, angle, 0), false, 8.0)
	# Corner posts.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			trim.add_rounded_box(Vector3(x*(outer-.04), RIM_HEIGHT*.5, z*(outer-.04)), Vector3(.2, RIM_HEIGHT+.06, .2), wood_dark, Vector3.ZERO, true, 10.0)
			if effect == "petals":
				_blossom(kit, Vector3(x*(outer-.04), RIM_HEIGHT+.08, z*(outer-.04)))
	if effect == "ribbon":
		_bow(kit, Vector3(outer-.04, RIM_HEIGHT+.12, outer-.04), _color("ribbon", Color("ff6f91")))
	var model := kit.build(.035)
	var fill := model.get_node("Fill") as MeshInstance3D
	match effect:
		"shiny":
			fill.material_override = shiny_material()
		"glass":
			fill.material_override = glass_material()
		"glow":
			var glowing := trim.build(.035)
			(glowing.get_node("Fill") as MeshInstance3D).material_override = glow_material()
			model.add_child(glowing)
	return model

## Surface detail on each outer wall: candy stripes, a gift ribbon or a woven wicker lattice.
func _wall_pattern(kit: MeshKit, effect: String, basis: Basis, angle: float, outer: float) -> void:
	var turn := Vector3(0, angle, 0)
	var body := (RIM_HEIGHT-.08)*.5
	match effect:
		"stripes":
			for i in 8:
				var x := -outer+.3+i*(outer*2-.6)/7.0
				if absf(x) < .36:
					continue
				kit.add_rounded_box(basis*Vector3(x, body, outer+.008), Vector3(.2, RIM_HEIGHT-.16, .02), _color("stripe", Color.WHITE), turn, false, 8.0)
		"ribbon":
			var ribbon := _color("ribbon", Color("ff6f91"))
			kit.add_rounded_box(basis*Vector3(0, body, outer+.01), Vector3(.36, RIM_HEIGHT-.08, .02), ribbon, turn, false, 8.0)
			kit.add_rounded_box(basis*Vector3(0, RIM_HEIGHT+.02, INNER_HALF+WALL*.5), Vector3(.36, .04, WALL+.1), ribbon, turn, false, 8.0)
		"weave":
			for row in 4:
				for i in 9:
					var x := -outer+.2+i*(outer*2-.4)/8.0
					var raised := (i+row) % 2 == 0
					if absf(x) < .4 and row in [1, 2]:
						continue
					kit.add_rounded_box(basis*Vector3(x, .14+row*.23, outer+(.02 if raised else .006)), Vector3(.36, .19, .03), _color("wood_light", WOOD_LIGHT) if raised else _color("wood_dark", WOOD_DARK), turn, false, 6.0)

## A looped ribbon bow perched on one corner post.
func _bow(kit: MeshKit, center: Vector3, color: Color) -> void:
	var across := Vector3(1, 0, -1).normalized()
	for side in [-1.0, 1.0]:
		kit.add("torus", center+across*side*.3+Vector3(0, .12, 0), Vector3(.5, .9, .5), color, Vector3(PI*.5, PI*.25, side*.6))
		kit.add_rounded_box(center+across*side*.14+Vector3(0, -.28, 0), Vector3(.14, .5, .04), color, Vector3(0, PI*.25, side*.35), true, 4.0)
	kit.add("sphere", center+Vector3(0, .06, 0), Vector3(.28, .24, .28), color.darkened(.12))

func _add_collision() -> void:
	var outer := INNER_HALF+WALL

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 1.0
	add_child(body)
	_box(body, Vector3(0, FLOOR_TOP*.5, 0), Vector3(outer*2, FLOOR_TOP, outer*2))
	for side in 4:
		var basis := Basis(Vector3.UP, side*PI*.5)
		var shape := _box(body, basis*Vector3(0, RIM_HEIGHT*.5, INNER_HALF+WALL*.5), Vector3(outer*2, RIM_HEIGHT, WALL))
		shape.basis = basis

static var _shiny: ShaderMaterial

static func shiny_material() -> ShaderMaterial:
	if _shiny == null:
		_shiny = ShaderMaterial.new()
		_shiny.shader = MeshKit.TOON
		_shiny.set_shader_parameter("shine", .8)
		_shiny.set_shader_parameter("rim_strength", .18)
	return _shiny

static var _glass: ShaderMaterial
static var _glow: ShaderMaterial

## See-through ice: the pile inside stays visible through the walls.
static func glass_material() -> ShaderMaterial:
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.shader = KinuModel.GLASS
		_glass.set_shader_parameter("opacity", .55)
		_glass.set_shader_parameter("shine", 1.0)
		_glass.set_shader_parameter("rim_strength", .5)
	return _glass

static func glow_material() -> ShaderMaterial:
	if _glow == null:
		_glow = ShaderMaterial.new()
		_glow.shader = MeshKit.TOON
		_glow.set_shader_parameter("glow", .7)
		_glow.set_shader_parameter("rim_strength", .3)
	return _glow

func _blossom(kit: MeshKit, center: Vector3) -> void:
	for i in 5:
		var a := TAU*i/5.0
		kit.add("sphere", center+Vector3(sin(a)*.09, 0, cos(a)*.09), Vector3(.13, .05, .13), Color("ffb3c8"))
	kit.add("bead", center+Vector3(0, .03, 0), Vector3(.07, .05, .07), Color("ffd85c"), Vector3.ZERO, false)

func _box(body: StaticBody3D, center: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	return shape
