class_name KinuFlavour
extends Resource
## A colour variant of Kinu. Flavours are purely cosmetic and form the collection.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var spawn_weight: float = 1.0
## Surface detail: "", "crisp", "speckled" or "petal".
@export var pattern: String = ""

func rarity() -> String:
	if spawn_weight >= 3.0:
		return "Common"
	return "Uncommon" if spawn_weight >= 1.5 else "Rare"
