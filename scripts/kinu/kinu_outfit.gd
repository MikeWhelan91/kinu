class_name KinuOutfit
extends Resource
## A cosmetic costume or accessory. Visual only: it never changes a shape's hitbox.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Cost in soybeans in the Kinu Shop.
@export var price: int = 100
@export var hood_color: Color = Color.WHITE
## A pattern outfit restyles Kinu with this look (gold, crystal...) instead of building a costume.
@export var finish: KinuFlavour
## Which procedural costume design KinuModel builds. Styles are grouped there into classic,
## premium and expanded cute Catcher collections.
@export var style: String = ""
## Earned in the Kinu Book instead of bought: "best", "total", "runs", "flavours", "clean", "lucky",
## "height" (cm), "missions", "days" (days in a row) or "glazed". Empty means it is sold in the shop.
@export var goal: String = ""
@export var goal_amount: int = 0
## Only ever won in the Kinu Catcher: never sold in the shop or earned by a goal.
@export var crane_only: bool = false
## "common", "rare", "epic" or "legendary" for shop and Kinu Catcher items; empty for earned rewards.
@export var rarity: String = ""
