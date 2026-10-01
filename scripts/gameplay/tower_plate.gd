class_name TowerPlate
extends Node3D
## Tower mode's base: a lacquered serving board on little feet, narrower than the box so every
## tower has to climb. Touching the counter beside it is a tumble, as in the other modes.
## It wears the equipped box skin, so Tower and Classic read as one matching set.

const HALF := 1.55
const TOP := .3

## The equipped box skin, shared with TofuBox. Null uses the default hinoki palette.
var decor: KinuDecor

var body: StaticBody3D
var model: Node3D

## Built plate models by skin id; every plate duplicates one (sharing meshes).
static var models: Dictionary = {}

static func contains(point: Vector3, margin: float = 0.0) -> bool:
	return absf(point.x) <= HALF+margin and absf(point.z) <= HALF+margin

func _ready() -> void:
	_rebuild()
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 1.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF*2, TOP, HALF*2)
	shape.shape = box
	shape.position.y = TOP*.5
	body.add_child(shape)
	add_child(body)

## Swaps the plate over to another box skin, rebuilding only when it actually changed.
func apply_decor(value: KinuDecor) -> void:
	if decor == value:
		return
	decor = value
	if is_node_ready():
		_rebuild()

func _color(key: String, fallback: Color) -> Color:
	return decor.palette.get(key, fallback) if decor else fallback

func _rebuild() -> void:
	if is_instance_valid(model):
		model.free()
	var key := decor.id if decor else "default"
	model = MeshKit.cached_model(models, key, _build_model).duplicate()
	add_child(model)
	move_child(model, 0)

func _build_model() -> Node3D:
	var kit := MeshKit.new()
	var effect := decor.effect if decor else ""
	# Neon trim is built separately so only the rails and seals glow, as on the box.
	var trim := MeshKit.new() if effect == "glow" else kit
	var wood := _color("wood", TofuBox.WOOD)
	var wood_dark := _color("wood_dark", TofuBox.WOOD_DARK)
	var wood_light := _color("wood_light", TofuBox.WOOD_LIGHT)
	kit.add_rounded_box(Vector3(0, TOP-.08, 0), Vector3(HALF*2, .16, HALF*2), wood, Vector3.ZERO, true, 10)
	kit.add_rounded_box(Vector3(0, TOP-.005, 0), Vector3(HALF*2-.24, .02, HALF*2-.24), wood_light, Vector3.ZERO, false, 10)
	for side in 4:
		var angle := side*PI*.5
		var basis := Basis(Vector3.UP, angle)
		trim.add_rounded_box(basis*Vector3(0, TOP-.08, HALF), Vector3(HALF*2+.04, .18, .06), wood_dark, Vector3(0, angle, 0), false, 10)
		# The box's hanko seal, shrunk to fit the rail.
		var face := basis*Vector3(0, TOP-.08, HALF+.035)
		trim.add("cylinder", face, Vector3(.17, .02, .17), _color("stamp", TofuBox.HANKO), Vector3(PI*.5, angle, 0), false)
		trim.add_rounded_box(face+basis*Vector3(0, 0, .015), Vector3(.075, .075, .02), _color("stamp_mark", Color("fff6e2")), Vector3(0, angle, 0), false, 8)
		if effect == "first_edition":
			# The box's "No. 1" medal and gold studs, kept flat on the rail's face so nothing
			# stands up where a Kinu rests on the edge.
			for i in 10:
				var a := TAU*i/10.0
				kit.add("bead", face+basis*Vector3(sin(a)*.12, cos(a)*.07, -.008), Vector3(.07, .07, .03), TofuBox.GOLD_TRIM, Vector3.ZERO, false)
			for i in 12:
				var x := -HALF+.22+i*(HALF*2-.44)/11.0
				if absf(x) < .22:
					continue
				kit.add("bead", basis*Vector3(x, TOP-.08, HALF+.035), Vector3(.05, .05, .03), TofuBox.GOLD_TRIM, Vector3.ZERO, false)
	# Corner caps, standing in for the box's corner posts. They sit barely proud of the rail so a
	# Kinu resting out on the edge can never clip one.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var cap := Vector3(x*(HALF-.02), TOP-.08, z*(HALF-.02))
			trim.add_rounded_box(cap, Vector3(.22, .2, .22), wood_dark, Vector3.ZERO, false, 8)
	for x in [-1.0, 1.0]:
		kit.add_rounded_box(Vector3(x*(HALF-.35), .07, 0), Vector3(.24, .14, HALF*2-.3), wood_dark, Vector3.ZERO, true, 8)
	var built := kit.build(.035)
	var fill := built.get_node("Fill") as MeshInstance3D
	match effect:
		"shiny", "kintsugi", "raden", "taiko", "gachapon", "first_edition":
			fill.material_override = TofuBox.shiny_material()
		"glass", "koi_pond":
			fill.material_override = TofuBox.glass_material()
		"glow":
			var glowing := trim.build(.035)
			(glowing.get_node("Fill") as MeshInstance3D).material_override = TofuBox.glow_material()
			built.add_child(glowing)
	return built

## Put away for the other modes: hidden, and nothing can land on it. The mask goes with the layer,
## or a Kinu whose own mask matches would still hit the invisible plate.
func set_active(active: bool) -> void:
	visible = active
	if is_instance_valid(body):
		body.collision_layer = 1 if active else 0
		body.collision_mask = 2 if active else 0
