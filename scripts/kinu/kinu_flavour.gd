class_name KinuFlavour
extends Resource
## A look for Kinu. Flavours are found by playing (some unlock once enough Kinu are piled in one run); finishes such as
## gold or crystal use the same data and are worn through a pattern outfit.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var spawn_weight: float = 1.0
## Surface detail: "", "crisp", "speckled", "petal", "grain", "veins", "stars", "sparkle", "facets",
## "dusted", "beans", "bubbles", "fireworks", "wrap" or "stem".
@export var pattern: String = ""
## Surface finish: "" (matte), "shiny" (metal), "glass" (see-through), "jelly" or "glow".
@export var material: String = ""
## Best pile (Kinu in one run) that adds this flavour to the spawn mix; 0 means available from the start.
@export var unlock_kinu: int = 0
## Pale features for dark flavours, so the face stays readable.
@export var light_face: bool = false

func rarity() -> String:
	if unlock_kinu > 0:
		return TranslationServer.translate("Unlocked at %d Kinu")%unlock_kinu
	if spawn_weight >= 3.0:
		return "Common"
	return "Uncommon" if spawn_weight >= 1.5 else "Rare"

static func height_text(cm: int) -> String:
	return "%d cm"%cm if cm < 100 else ("%s m"%str(snappedf(cm/100.0, .1)).trim_suffix(".0"))
