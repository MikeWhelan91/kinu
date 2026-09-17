class_name KinuCatalog
extends Resource

@export var shapes: Array[KinuShape] = []
@export var flavours: Array[KinuFlavour] = []
@export var outfits: Array[KinuOutfit] = []
## Special looks (gold, crystal...) worn through pattern outfits; Lucky Kinu are always gold.
@export var finishes: Array[KinuFlavour] = []
@export var decor: Array[KinuDecor] = []

func finish(id: String) -> KinuFlavour:
	for item in finishes:
		if item.id == id:
			return item
	return null

func decor_of(kind: String) -> Array[KinuDecor]:
	var items: Array[KinuDecor] = []
	for item in decor:
		if item.kind == kind:
			items.append(item)
	return items

func find_decor(kind: String, id: String) -> KinuDecor:
	for item in decor_of(kind):
		if item.id == id:
			return item
	return decor_of(kind)[0]

func outfit(id: String) -> KinuOutfit:
	for item in outfits:
		if item.id == id:
			return item
	return null

## The look a pattern outfit gives some Kinu, or null for costumes and no outfit.
func pattern(outfit_id: String) -> KinuFlavour:
	var item := outfit(outfit_id)
	return item.finish if item else null
