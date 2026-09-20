class_name BentoPan
extends Node3D
## A visual-only little frying pan. The held Kinu sits in its bowl until the player releases it.

func _ready() -> void:
	var kit := MeshKit.new()
	var iron := Color("a8b1b7")
	var inner := Color("465058")
	var rim := Color("ff8a4b")
	var wood := Color("b66b35")
	# Wide and deep enough that a full Kinu visibly begins *in* the pan, not balanced on top of it.
	# A recognisable skillet: silver outer bowl, dark non-stick cooking surface, red rim and a
	# warm wooden handle. The deliberate material contrast keeps it distinct from dark Kinu.
	# The head intentionally dwarfs the short handle: a face-up frying pan, never a spoon.
	kit.add("cylinder", Vector3.ZERO, Vector3(1.72, .22, 1.72), iron, Vector3.ZERO, true)
	kit.add("cylinder", Vector3(0, .17, 0), Vector3(1.48, .10, 1.48), inner, Vector3.ZERO, false)
	kit.add("torus", Vector3(0, .42, 0), Vector3(1.74, .28, 1.74), rim, Vector3.ZERO, true)
	kit.add_rounded_box(Vector3(0, .17, 1.95), Vector3(.52, .18, 1.25), wood.darkened(.22), Vector3.ZERO, true, 8.0)
	kit.add_rounded_box(Vector3(0, .25, 2.48), Vector3(.68, .32, .48), wood, Vector3.ZERO, true, 8.0)
	add_child(kit.build(.03))
