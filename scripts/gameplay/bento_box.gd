class_name BentoBox
extends TofuBox
## Bento Flip's target. It shares the box collision footprint so every room and the existing
## Kinu physics can be reused, but looks like a low lacquer lunch box with food compartments.

static var bento_models: Dictionary = {}

func _ready() -> void:
	var key := decor.id if decor else "default"
	if not bento_models.has(key):
		bento_models[key] = _build_bento()
	add_child((bento_models[key] as Node3D).duplicate())
	if with_collision:
		_add_collision()

func _build_bento() -> Node3D:
	var kit := MeshKit.new()
	var outer := INNER_HALF+WALL
	var lacquer := _color("wood", Color("a83225")).darkened(.18)
	var edge := _color("wood_dark", Color("5a211d"))
	var rice := Color("fff2d1")
	# Low lacquer walls and a warm rice-coloured floor make the object read as lunch rather than
	# the regular tofu crate. The inherited collision keeps it forgiving for launched Kinu.
	kit.add_rounded_box(Vector3(0, FLOOR_TOP*.5, 0), Vector3(outer*2, FLOOR_TOP, outer*2), rice, Vector3.ZERO, true, 10.0)
	for side in 4:
		var angle := side*PI*.5
		var basis := Basis(Vector3.UP, angle)
		kit.add_rounded_box(basis*Vector3(0, RIM_HEIGHT*.5, INNER_HALF+WALL*.5), Vector3(outer*2, RIM_HEIGHT, WALL), lacquer, Vector3(0, angle, 0), true, 10.0)
		kit.add_rounded_box(basis*Vector3(0, RIM_HEIGHT-.05, INNER_HALF+WALL*.5), Vector3(outer*2+.06, .12, WALL+.08), edge, Vector3(0, angle, 0), true, 10.0)
	# Two dividers make five friendly-looking compartments without becoming collision hazards.
	kit.add_rounded_box(Vector3(0, FLOOR_TOP+.08, 0), Vector3(.09, .14, outer*2-.34), edge.lightened(.08), Vector3.ZERO, false, 5.0)
	kit.add_rounded_box(Vector3(-outer*.52, FLOOR_TOP+.08, 0), Vector3(.07, .11, outer*2-.34), edge.lightened(.12), Vector3.ZERO, false, 5.0)
	kit.add_rounded_box(Vector3(outer*.48, FLOOR_TOP+.08, 0), Vector3(.07, .11, outer*2-.34), edge.lightened(.12), Vector3.ZERO, false, 5.0)
	# A leaf, tamagoyaki and umeboshi are visual garnish; they never change collision or scoring.
	kit.add("sphere", Vector3(-outer*.72, FLOOR_TOP+.12, outer*.62), Vector3(.30, .07, .18), Color("5cae63"), Vector3(0, .4, 0), false)
	kit.add_rounded_box(Vector3(outer*.68, FLOOR_TOP+.12, outer*.62), Vector3(.36, .10, .23), Color("f5bc45"), Vector3(0, .1, 0), false, 5.0)
	kit.add("sphere", Vector3(outer*.70, FLOOR_TOP+.14, -outer*.62), Vector3(.13, .07, .13), Color("db5446"), Vector3.ZERO, false)
	return kit.build(.035)

static func packed_lid(skin: KinuDecor) -> Node3D:
	var lid := TofuBox.lid(skin)
	# A little nori band makes the packed lid unmistakably a bento when it slides away.
	var kit := MeshKit.new()
	kit.add_rounded_box(Vector3(0, .22, 0), Vector3(TofuBox.INNER_HALF*1.55, .055, .30), Color("29453a"), Vector3.ZERO, false, 5.0)
	lid.add_child(kit.build(.02))
	return lid
