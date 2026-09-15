class_name KinuCatalog
extends Resource

@export var shapes: Array[KinuShape] = []
@export var flavours: Array[KinuFlavour] = []
@export var outfits: Array[KinuOutfit] = []

func outfit(id: String) -> KinuOutfit:
	for item in outfits:
		if item.id == id:
			return item
	return null
