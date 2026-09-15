class_name TofuBox
extends Node3D
## A wooden masu tofu box, about three to four Kinu wide: roomy enough to plan a base,
## small enough that the pile soon has to grow upward. Square, so spinning reads clearly.

const INNER_HALF := 1.55
const WALL := .24
const FLOOR_TOP := .18
const RIM_HEIGHT := 1.1
## Radius used by circular checks (balance support, placement): the inner wall distance.
const RIM_RADIUS := INNER_HALF

const WOOD := Color("f6dfb4")
const WOOD_DARK := Color("d9ad74")
const WOOD_LIGHT := Color("fbe9c8")
const HANKO := Color("e0463a")

static func contains(point: Vector3, margin: float = 0.0) -> bool:
	var reach := INNER_HALF+WALL+margin
	return absf(point.x) <= reach and absf(point.z) <= reach

func _ready() -> void:
	var kit := MeshKit.new()
	var outer := INNER_HALF+WALL
	# Floor boards.
	for i in 5:
		var x := -INNER_HALF+INNER_HALF*.4*(i+.5)
		kit.add_rounded_box(Vector3(x, FLOOR_TOP*.5, 0), Vector3(INNER_HALF*.4-.02, FLOOR_TOP, INNER_HALF*2), WOOD_LIGHT if i % 2 else WOOD, Vector3.ZERO, true, 10.0)
	# Two stacked planks per wall, with a darker rim trim.
	for side in 4:
		var angle := side*PI*.5
		var basis := Basis(Vector3.UP, angle)
		for plank in 2:
			var height := (RIM_HEIGHT-.08)*.5
			var center := basis*Vector3(0, height*(plank+.5), INNER_HALF+WALL*.5)
			kit.add_rounded_box(center, Vector3(outer*2-.02, height-.02, WALL), WOOD if plank == 0 else WOOD_LIGHT, Vector3(0, angle, 0), true, 10.0)
		kit.add_rounded_box(basis*Vector3(0, RIM_HEIGHT-.04, INNER_HALF+WALL*.5), Vector3(outer*2+.04, .1, WALL+.06), WOOD_DARK, Vector3(0, angle, 0), true, 10.0)
		# Hanko stamp: a red seal with a little white tofu square, on every side.
		var face := basis*Vector3(0, RIM_HEIGHT*.45, outer+.012)
		kit.add("cylinder", face, Vector3(.46, .02, .46), HANKO, Vector3(PI*.5, angle, 0), false)
		kit.add_rounded_box(face+basis*Vector3(0, 0, .02), Vector3(.2, .2, .02), Color("fff6e2"), Vector3(0, angle, 0), false, 8.0)
	# Corner posts.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			kit.add_rounded_box(Vector3(x*(outer-.04), RIM_HEIGHT*.5, z*(outer-.04)), Vector3(.2, RIM_HEIGHT+.06, .2), WOOD_DARK, Vector3.ZERO, true, 10.0)
	add_child(kit.build(.035))

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

func _box(body: StaticBody3D, center: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	return shape
