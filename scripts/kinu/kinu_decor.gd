class_name KinuDecor
extends Resource
## A box skin or a room theme. Visual only: every box has identical dimensions and walls.

@export var id: String = ""
@export var display_name: String = ""
## "box" or "room".
@export var kind: String = "box"
@export var price: int = 0
@export var palette: Dictionary = {}
## Boxes: "" or "shiny"/"petals". Rooms: ambient effect "steam", "snow", "petals" or "fireflies".
@export var effect: String = ""
