class_name KinuDecor
extends Resource
## A box skin or a room theme. Visual only: every box has identical dimensions and walls.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
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
## Only ever won in the Kinu Catcher: never sold in the shop or earned by a goal.
@export var crane_only: bool = false
## "common", "rare", "epic" or "legendary" for shop and Kinu Catcher items; empty for earned rewards.
@export var rarity: String = ""
