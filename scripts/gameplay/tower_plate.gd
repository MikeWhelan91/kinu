class_name TowerPlate
extends Node3D
## Tower mode's base: a lacquered serving board on little feet, narrower than the box so every
## tower has to climb. Touching the counter beside it is a tumble, as in the other modes.

const HALF := 1.55
const TOP := .3

var body: StaticBody3D

static func contains(point: Vector3, margin: float = 0.0) -> bool:
	return absf(point.x) <= HALF+margin and absf(point.z) <= HALF+margin

func _ready() -> void:
	var kit := MeshKit.new()
	var lacquer := Color("c9403a")
	var black := Color("2b1a17")
	kit.add_rounded_box(Vector3(0, TOP-.08, 0), Vector3(HALF*2, .16, HALF*2), lacquer, Vector3.ZERO, true, 10)
	kit.add_rounded_box(Vector3(0, TOP-.005, 0), Vector3(HALF*2-.24, .02, HALF*2-.24), lacquer.lightened(.12), Vector3.ZERO, false, 10)
	for side in 4:
		var basis := Basis(Vector3.UP, side*PI*.5)
		kit.add_rounded_box(basis*Vector3(0, TOP-.08, HALF), Vector3(HALF*2+.04, .18, .06), black, Vector3(0, side*PI*.5, 0), false, 10)
		kit.add("sphere", basis*Vector3(0, TOP-.08, HALF+.035), Vector3(.16, .1, .02), KinuModel.GOLD, Vector3(0, side*PI*.5, 0), false)
	for x in [-1.0, 1.0]:
		kit.add_rounded_box(Vector3(x*(HALF-.35), .07, 0), Vector3(.24, .14, HALF*2-.3), black, Vector3.ZERO, true, 8)
	add_child(kit.build(.035))
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

func set_active(active: bool) -> void:
	visible = active
	if is_instance_valid(body):
		body.collision_layer = 1 if active else 0
