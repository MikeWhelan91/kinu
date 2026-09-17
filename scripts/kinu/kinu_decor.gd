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
## Rooms: "" (the tofu shop interior), "grove", "onsen", "festival", "rooftop" or "veranda".
@export var layout: String = ""
## Earned in the Kinu Book instead of bought: "best", "total", "runs", "flavours", "clean", "lucky",
## "height" (cm) or "missions". Empty means it is sold in the shop.
@export var goal: String = ""
@export var goal_amount: int = 0
