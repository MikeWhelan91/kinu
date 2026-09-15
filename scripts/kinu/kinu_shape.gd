class_name KinuShape
extends Resource
## A way Kinu can be cut or rolled. Shapes are gameplay: each has its own hitbox and weight.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var size: Vector3 = Vector3.ONE
## Superellipsoid power: 2 is an ellipsoid, higher values give boxier corners.
@export var roundness: float = 7.0
@export var mass: float = 1.0
@export var friction: float = 0.9
@export var bounce: float = 0.05
@export var spawn_weight: float = 1.0
## Awkward shapes are rarer early in a run.
@export var tricky: bool = false
@export var sleepy: bool = false
