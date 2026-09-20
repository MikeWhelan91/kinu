class_name CollectionThumb
extends RefCounted
## Loads a pre-baked image per outfit or box, instead of the Kinu Book building a live 3D preview
## (its own SubViewport, lit scene and model) for every card. Images live under
## resources/kinu/thumbs/ and are regenerated with tools/bake_collection_thumbs.gd whenever the
## catalogue changes; loading one is a plain file read, not a render, so opening the Collection is
## as fast as any other list screen. Rooms already draw as a flat Control and need no image at all.

const DIR := "res://resources/kinu/thumbs"
static var _cache: Dictionary = {}

static func outfit(item: KinuOutfit) -> Texture2D:
	return _load("outfit_%s.png"%item.id)

static func box(item: KinuDecor) -> Texture2D:
	return _load("box_%s.png"%item.id)

static func _load(filename: String) -> Texture2D:
	if _cache.has(filename):
		return _cache[filename]
	# The bake tool's PNGs are auto-imported like any other project asset, so the plain resource
	# loader returns their compressed texture directly — a raw file read (Image.load_from_file)
	# looks identical in the editor but silently returns nothing once the project is exported.
	var texture: Texture2D = load(DIR.path_join(filename))
	_cache[filename] = texture
	return texture
