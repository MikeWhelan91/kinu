class_name KinuFlavour
extends Resource
## A variety of Kinu. Purely cosmetic: base flavours are found by playing, shop flavours are
## bought with soybeans and then join the spawn mix.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var spawn_weight: float = 1.0
## Surface detail: "", "crisp", "speckled", "petal", "grain", "veins", "stars", "sparkle" or "facets".
@export var pattern: String = ""
## Surface finish: "" (matte), "shiny" (metal), "glass" (see-through), "jelly" or "glow".
@export var material: String = ""
## Soybeans to unlock in the shop; 0 means it is found by playing instead.
@export var price: int = 0
## Pale features for dark flavours, so the face stays readable.
@export var light_face: bool = false

func rarity() -> String:
	if price > 0:
		return "Shop special"
	if spawn_weight >= 3.0:
		return "Common"
	return "Uncommon" if spawn_weight >= 1.5 else "Rare"
