class_name KinuOutfit
extends Resource
## A cosmetic costume or accessory. Visual only: it never changes a shape's hitbox.

@export var id: String = ""
@export var display_name: String = ""
## Cost in soybeans in the Kinu Shop.
@export var price: int = 100
@export var hood_color: Color = Color.WHITE
## A pattern outfit restyles Kinu with this look (gold, crystal...) instead of building a costume.
@export var finish: KinuFlavour
## Which costume design to build: "tanuki", "bunny", "bat", "fox", "frog", "leaf", "pirate",
## "ninja", "panda", "dino", "astronaut", "ghost", "shark", "strawberry", "tiger", "dragon", "bee",
## "kappa", "tako", "daruma", "onsen", "nigiri", "hatchling" or "parcel".
@export var style: String = ""
## Earned in the Kinu Book instead of bought: "best", "total", "runs", "flavours", "clean", "lucky",
## "height" (cm), "missions", "days" (days in a row) or "glazed". Empty means it is sold in the shop.
@export var goal: String = ""
@export var goal_amount: int = 0
