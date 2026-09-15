class_name KinuFlavour
extends Resource
## A look for Kinu. Flavours are found by playing (some unlock at a best height); finishes such as
## gold or crystal use the same data but are bought as costumes and restyle every Kinu.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var spawn_weight: float = 1.0
## Surface detail: "", "crisp", "speckled", "petal", "grain", "veins", "stars", "sparkle" or "facets".
@export var pattern: String = ""
## Surface finish: "" (matte), "shiny" (metal), "glass" (see-through), "jelly" or "glow".
@export var material: String = ""
## Soybeans for a finish in the Costumes shop. Unused for flavours.
@export var price: int = 0
## Best tower height (cm) that adds this flavour to the spawn mix; 0 means available from the start.
@export var unlock_cm: int = 0
## Pale features for dark flavours, so the face stays readable.
@export var light_face: bool = false

func rarity() -> String:
	if unlock_cm > 0:
		return "Unlocked at %s"%height_text(unlock_cm)
	if spawn_weight >= 3.0:
		return "Common"
	return "Uncommon" if spawn_weight >= 1.5 else "Rare"

static func height_text(cm: int) -> String:
	return "%d cm"%cm if cm < 100 else ("%s m"%str(snappedf(cm/100.0, .1)).trim_suffix(".0"))
