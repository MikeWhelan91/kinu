class_name TossTable
extends Node3D
## Kinu Toss throws down the length of the counter and on past it, so the counter is carried on by
## a matching table out to `END`. It is built from the room's own counter colours, which keeps it
## right in every room, including ones added later. Like the counter it counts as the ground: a
## Kinu that comes to rest on it has missed.

## How far along -z the playing surface reaches, from the centre of the counter, and half its width.
## It stops short of TofuShop.LANE's far end, which is what keeps the room clear around it.
const END := 13.4
const HALF := 3.5

var decor: KinuDecor

func _c(key: String, fallback: Color) -> Color:
	return decor.palette.get(key, fallback) if decor else fallback

func _ready() -> void:
	var start := TofuShop.COUNTER_HALF
	var length := END-start
	var width := HALF*2
	var mid := -(start+length*.5)
	var kit := MeshKit.new()
	var wood := _c("wood", TofuShop.WOOD)
	var deep := _c("wood_deep", TofuShop.WOOD_DEEP)
	# The top butts up flush against the counter so the join reads as one long table.
	kit.add_rounded_box(Vector3(0, -.225, mid), Vector3(width, .45, length+.02), wood, Vector3.ZERO, true, 10.0)
	for i in 4:
		var x := -HALF+width*(i+1)/5.0
		kit.add_rounded_box(Vector3(x, .01, mid), Vector3(.05, .03, length-.2), deep, Vector3.ZERO, false, 10.0)
	# A deep apron and four stout legs, so it looks built rather than floating.
	kit.add_rounded_box(Vector3(0, -.75, mid), Vector3(width-.4, .6, length-.3), deep, Vector3.ZERO, true, 10.0)
	for side in [-1.0, 1.0]:
		for z in [-END+.5, mid]:
			kit.add_rounded_box(Vector3(side*(HALF-.45), -TofuShop.COUNTER_HEIGHT*.5-.2, z), Vector3(.55, TofuShop.COUNTER_HEIGHT-.4, .55), _c("post", TofuShop.POST), Vector3.ZERO, true, 10.0)
	add_child(kit.build(.045))
	var table := StaticBody3D.new()
	table.add_to_group(TofuShop.GROUND_GROUP)
	table.collision_layer = 1
	table.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, .45, length)
	shape.shape = box
	shape.position = Vector3(0, -.225, mid)
	table.add_child(shape)
	add_child(table)
