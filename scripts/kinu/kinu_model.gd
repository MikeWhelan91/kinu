class_name KinuModel
extends RefCounted
## Builds Kinu from cached body, opaque costume and outfit-aware expression meshes.
## Changing expression never rebuilds the body or costume.

const INK := Color("2b1a17")
const BLUSH := Color("ff9fb0")
const SWEAT := Color("8fd3ff")
const LEAF := Color("6cc94c")
const AZUKI := Color("7a2a3a")
const NORI := Color("24382d")
const OUTLINE_WIDTH := .02
## Pale sheets merge into each other when stacked, so the ghost is inked much heavier.
const GHOST_OUTLINE_WIDTH := .055
const MOODS := ["calm", "falling", "squish", "happy", "content", "worried"]
## Accessories worn over the bare Kinu, which keeps its own body and face.
const BARE_STYLES := ["leaf", "pirate", "onsen", "nigiri", "hatchling", "parcel"]
## Suits added with the Kinu Catcher, built by _premium_outfit.
const PREMIUM_STYLES := ["kitsune", "phoenix", "unicorn", "maneki", "samurai", "koi", "axolotl", "kimono", "oni", "capybara"]
## The expanded Catcher wardrobe, built by _cute_outfit.
const CUTE_STYLES := [
	"chick", "shiba", "calico", "bear_cub", "hamster", "penguin", "duckling", "seal", "otter", "red_panda",
	"mushroom", "peach", "lemon", "cupcake", "pudding", "boba", "melonpan", "donut", "marshmallow", "taiyaki",
	"cloud_outfit", "star_outfit", "moon_outfit", "sunflower", "daisy", "sailor", "raincoat", "overalls", "artist", "sleepy_cap",
	"magical_girl", "moon_princess", "candy_witch", "celestial_bunny", "sakura_deer", "royal_frog", "pastel_dragon", "snow_fox", "jellyfish", "fairy",
	"builder", "acrobat", "chef", "yukata", "climber", "lucky_charm",
	"jelly_cube", "rose_delight", "chocolate_square", "burger", "snack_box", "sea_sponge", "bread_loaf",
]
const GOLD := Color("f5c14e")
const RAINBOW := [Color("ff8fa3"), Color("ffb65c"), Color("ffe36e"), Color("8fdc8a"), Color("7fc4f5"), Color("b99cf2")]

const GLASS := preload("res://resources/shaders/toon_glass.gdshader")

static var bodies: Dictionary = {}
static var faces: Dictionary = {}
static var costumes: Dictionary = {}
static var exposed_faces: Dictionary = {}
static var materials: Dictionary = {}

## Matte flavours share the plain toon material; special finishes get their own tuned copy.
static func body_material(flavour: KinuFlavour) -> ShaderMaterial:
	if flavour.material == "":
		return MeshKit.toon_material()
	if not materials.has(flavour.material):
		var mat := ShaderMaterial.new()
		mat.shader = GLASS if flavour.material in ["glass", "jelly"] else MeshKit.TOON
		match flavour.material:
			"shiny":
				mat.set_shader_parameter("shine", .9)
				mat.set_shader_parameter("rim_strength", .2)
				mat.set_shader_parameter("shadow_tint", Color(.82, .68, .55))
			"glass":
				mat.set_shader_parameter("opacity", .72)
				mat.set_shader_parameter("shine", 1.0)
				mat.set_shader_parameter("rim_strength", .45)
			"jelly":
				mat.set_shader_parameter("opacity", .8)
				mat.set_shader_parameter("shine", .7)
				mat.set_shader_parameter("rim_strength", .3)
			"glow":
				mat.set_shader_parameter("glow", .28)
				mat.set_shader_parameter("rim_strength", .35)
		materials[flavour.material] = mat
	return materials[flavour.material]

static func build(shape: KinuShape, flavour: KinuFlavour, outfit: KinuOutfit = null, mood: String = "calm") -> Node3D:
	# Pattern outfits have no costume; callers pass their look as the flavour where it shows.
	if outfit and outfit.finish:
		outfit = null
	var root := Node3D.new()
	var key := "%s/%s"%[shape.id, flavour.id]
	if not bodies.has(key):
		var kit := MeshKit.new()
		_body(kit, shape, flavour)
		bodies[key] = [kit.commit_fill(), kit.commit_hull()]
	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	fill.mesh = bodies[key][0]
	fill.material_override = body_material(flavour)
	root.add_child(fill)
	var line := MeshInstance3D.new()
	line.name = "Outline"
	line.mesh = bodies[key][1]
	line.material_override = MeshKit.outline_material(OUTLINE_WIDTH)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(line)
	if outfit:
		var costume_key := "%s/%s"%[shape.id, outfit.id]
		if not costumes.has(costume_key):
			var cloth := MeshKit.new()
			_outfit(cloth, outfit, shape)
			costumes[costume_key] = [cloth.commit_fill(), cloth.commit_hull()]
		var costume := MeshInstance3D.new()
		costume.name = "Costume"
		costume.mesh = costumes[costume_key][0]
		costume.material_override = MeshKit.toon_material()
		root.add_child(costume)
		var seam := MeshInstance3D.new()
		seam.name = "CostumeOutline"
		seam.mesh = costumes[costume_key][1]
		seam.material_override = MeshKit.outline_material(GHOST_OUTLINE_WIDTH if outfit.style == "ghost" else OUTLINE_WIDTH)
		seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(seam)
	if outfit and outfit.style not in BARE_STYLES:
		fill.hide()
		line.hide()
	if outfit and outfit.style not in BARE_STYLES and outfit.style not in ["ghost", "panda"]:
		var skin_key := "%s/%s/%s"%[shape.id, flavour.id, outfit.style]
		if not exposed_faces.has(skin_key):
			var skin := MeshKit.new()
			_exposed_face(skin, shape, flavour, outfit.style)
			exposed_faces[skin_key] = skin.commit_fill()
		var skin := MeshInstance3D.new()
		skin.name = "ExposedFace"
		skin.mesh = exposed_faces[skin_key]
		# The face opening stays matte: shine and see-through finishes glare or ghost on a flat patch.
		skin.material_override = MeshKit.toon_material()
		skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(skin)
	root.set_meta("outfit_style", outfit.style if outfit else "")
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.material_override = MeshKit.toon_material()
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(face)
	set_mood(root, shape, mood, flavour.light_face)
	return root

static func set_mood(root: Node3D, shape: KinuShape, mood: String, light_face: bool = false) -> void:
	var style: String = root.get_meta("outfit_style", "")
	var key := "%s/%s/%s/%s"%[shape.id, mood, light_face, style]
	if not faces.has(key):
		var kit := MeshKit.new()
		_face(kit, shape, mood, Color("fff6e2") if light_face else INK, style)
		faces[key] = kit.commit_fill()
	(root.get_node("Face") as MeshInstance3D).mesh = faces[key]

static func clear_cache() -> void:
	bodies.clear()
	faces.clear()
	costumes.clear()
	exposed_faces.clear()
	materials.clear()

static func _body(kit: MeshKit, shape: KinuShape, flavour: KinuFlavour) -> void:
	var size := shape.size
	var half := size*.5
	var c := flavour.color
	var surface := Face.new(kit, size, shape.roundness)
	kit.add_rounded_box(Vector3.ZERO, size, c, Vector3.ZERO, true, shape.roundness)
	match flavour.pattern:
		"crisp":
			for i in 7:
				surface.mark(sin(i*2.3)*half.x*.7, half.y*.45+cos(i*1.7)*half.y*.3, Vector2(.14, .1), c.darkened(.1), i*.7, -.01)
		"speckled":
			for i in 14:
				surface.mark(sin(i*2.7)*half.x*.8, cos(i*1.9)*half.y*.8, Vector2(.05, .025), INK, i, 0.0)
		"grain":
			for i in 6:
				surface.mark(sin(i*1.3)*half.x*.2, -half.y*.7+i*half.y*.28, Vector2(half.x*1.3, .022), c.darkened(.28), sin(i*2.1)*.12, .002)
		"veins":
			for i in 5:
				surface.mark(sin(i*2.9)*half.x*.5, cos(i*1.7)*half.y*.5, Vector2(.42, .014), Color("b7b1a6"), i*1.1, .002)
		"stars", "sparkle":
			var count := 12 if flavour.pattern == "stars" else 3
			for i in count:
				var at := Vector2(sin(i*2.7+.4)*half.x*.75, cos(i*1.9+.2)*half.y*.75)
				var twinkle := .05 if flavour.pattern == "stars" else .14
				var tone := Color("fff3b0") if i % 3 == 0 else Color.WHITE
				for arm in 2:
					surface.mark(at.x, at.y, Vector2(twinkle, twinkle*.18), tone, arm*PI*.5, .006)
		"facets":
			for i in 4:
				surface.mark(-half.x*.4+i*half.x*.28, half.y*(.35-i*.18), Vector2(.3, .016), Color.WHITE, .8, .006)
		"petal":
			for i in 5:
				var a := TAU*i/5.0
				kit.add("sphere", Vector3(half.x*.35+sin(a)*.07, half.y+.02, cos(a)*.07), Vector3(.1, .03, .1), Color("ff7fa6"), Vector3.ZERO, false)
		"dusted":
			for i in 22:
				surface.mark(sin(i*2.7+.5)*half.x*.85, cos(i*1.9+.3)*half.y*.85, Vector2(.035, .03), c.darkened(.22) if i % 2 else c.lightened(.35), i, .002)
		"beans":
			for i in 9:
				surface.mark(sin(i*2.3+.7)*half.x*.78, cos(i*1.7+.1)*half.y*.78, Vector2(.075, .05), AZUKI, i*.9, .004)
		"bubbles":
			for i in 8:
				var at := Vector2(sin(i*2.5+.2)*half.x*.75, cos(i*1.6+.9)*half.y*.75)
				var bubble := .05+.035*(i % 3)
				surface.mark(at.x, at.y, Vector2(bubble, bubble), Color.WHITE, 0, .004)
				surface.mark(at.x, at.y, Vector2(bubble, bubble)*.62, c, 0, .008)
		"fireworks":
			var sparks := [Color("ffd166"), Color("ff7aa2"), Color("8ce0ff")]
			for burst in 3:
				var at := Vector2(sin(burst*2.4+.6)*half.x*.62, cos(burst*2.1+.3)*half.y*.6)
				for ray in 8:
					var angle := TAU*ray/8.0
					var reach := .1+.03*(ray % 2)
					surface.mark(at.x+cos(angle)*reach, at.y+sin(angle)*reach, Vector2(.075, .016), sparks[burst], angle, .006)
		"wrap":
			# A nori band wraps the bottom like onigiri, clear of the mouth.
			kit.add_rounded_box(Vector3(0, -half.y*.7, 0), Vector3(size.x*1.03, size.y*.3, size.z*1.03), NORI, Vector3.ZERO, true, shape.roundness)
		"stem":
			for i in 4:
				surface.mark(lerpf(-half.x*.6, half.x*.6, i/3.0), -half.y*.05, Vector2(.022, size.y*.8), c.darkened(.12), 0, .002)
			kit.add("cylinder", Vector3(0, half.y+.07, 0), Vector3(.07, .18, .07), Color("5d7a2e"), Vector3(0, 0, .25))
	for s in [-1.0, 1.0]:
		kit.add("sphere", Vector3(s*minf(half.x*.45, .3), -half.y-.02, half.z*.35), Vector3(.22, .12, .24), c.darkened(.06))
		if shape.id != "long":
			kit.add("sphere", Vector3(s*(half.x+.02), -half.y*.15, half.z*.2), Vector3(.14, .22, .16), c.darkened(.04), Vector3(0, 0, s*.4))

## Exposed tofu follows its flavour; fabric and costume markings stay separately coloured.
## Glass/jelly reveals the fabric beneath it, so the outfit never becomes transparent.
static func _opening(shape: KinuShape, style: String) -> Rect2:
	var size := shape.size
	var y := size.y*.175 if shape.id == "tall" else 0.0
	var extent := Vector2(minf(size.x*.85, .94), minf(size.y*.7, .60))
	y -= .005
	if style == "ninja":
		y += .060
		extent = Vector2(minf(size.x*.84, .9), .25)
	elif style == "astronaut":
		y += .020
		extent = Vector2(minf(size.x*.82, .92), minf(size.y*.66, .64))
	return Rect2(Vector2(0, y)-extent*.5, extent)

static func _exposed_face(kit: MeshKit, shape: KinuShape, flavour: KinuFlavour, style: String) -> void:
	var opening := _opening(shape, style)
	var center := opening.get_center()
	var radius := opening.size*.5
	var surface := Face.new(kit, shape.size*1.08, shape.roundness)
	# A curved patch matches the expression surface on round as well as boxy Kinu.
	for row in 8:
		for segment in 48:
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
				var r: float = (row+corner.y)/8.0
				var angle: float = TAU*(segment+corner.x)/48.0
				var at := center+Vector2(cos(angle), sin(angle))*radius*r
				var sample := surface.sample(at.x, at.y)
				kit.fill.set_color(Color(flavour.color, 0))
				kit.fill.set_normal(sample[1])
				kit.fill.add_vertex(sample[0]+sample[1]*.046)
	# Small, bounded details preserve flavour identity without spilling onto the mask or cloth.
	for i in 18:
		var at := center+Vector2(sin(i*2.7+.3), cos(i*1.9+.4))*radius*.74
		var extent := Vector2(.035, .022)
		var tone := flavour.color.darkened(.18)
		var roll := i*.7
		match flavour.pattern:
			"crisp":
				extent = Vector2(.055, .028)
			"speckled":
				tone = INK
			"grain":
				extent = Vector2(.14, .012)
				roll = .10
			"veins":
				extent = Vector2(.1, .012)
				tone = Color("b7b1a6")
			"stars", "sparkle", "facets":
				extent = Vector2(.05, .012)
				tone = Color("fff3b0") if i % 3 == 0 else Color.WHITE
			"dusted":
				extent = Vector2(.03, .03)
				tone = flavour.color.darkened(.22) if i % 2 else flavour.color.lightened(.35)
			"beans":
				extent = Vector2(.06, .04)
				tone = AZUKI
			"bubbles":
				extent = Vector2(.05, .05)
				tone = Color.WHITE
			"fireworks":
				extent = Vector2(.05, .014)
				tone = [Color("ffd166"), Color("ff7aa2"), Color("8ce0ff")][i % 3]
			"", "petal", "wrap", "stem":
				# Sakura's blossom sits on top of the bare body and is hidden by a hood.
				continue
		# Leave the central expression clear; show texture around its perimeter.
		var eye_y := shape.size.y*.175 if shape.id == "tall" else 0.0
		if absf(at.x) < .29 and at.y > eye_y-.18 and at.y < eye_y+.15:
			continue
		var margin := maxf(extent.x, extent.y)*.5
		if ((absf(at.x-center.x)+margin)/radius.x)**2+((absf(at.y-center.y)+margin)/radius.y)**2 >= .95:
			continue
		surface.mark(at.x, at.y, extent, tone, roll, .058)
		if flavour.pattern in ["stars", "sparkle"]:
			surface.mark(at.x, at.y, extent, tone, roll+PI*.5, .058)

static func _face(kit: MeshKit, shape: KinuShape, mood: String, ink: Color = INK, style: String = "") -> void:
	var dressed := style != "" and style not in BARE_STYLES
	var face := Face.new(kit, shape.size*1.08 if dressed else shape.size, shape.roundness)
	if dressed:
		face.offset = .065
		if style == "panda":
			ink = Color("fff6e2")
	if style == "ghost":
		face = Face.new(kit, _sheet_size(shape), 3.5)
		for side in [-1.0, 1.0]:
			face.mark(side*minf(shape.size.x*.21, .22), .09, Vector2(.15, .22 if mood == "falling" else .18), INK, side*-.18, .02)
		face.mark(0, -.14, Vector2(.16, .23 if mood in ["falling", "worried"] else .18), INK, 0, .02)
		return
	var half := shape.size*.5
	var y := half.y*.35 if shape.id == "tall" else 0.0
	var x := 0.0
	for s in [-1.0, 1.0]:
		if style == "pirate" and s < 0:
			continue
		var eye: float = x+s*minf(half.x*.42, .2)
		match mood:
			"happy":
				for side in [-1.0, 1.0]:
					face.mark(eye+side*.03, y+.05, Vector2(.08, .026), ink, side*-.75, .004)
			"content":
				for side in [-1.0, 1.0]:
					face.mark(eye+side*.03, y+.03, Vector2(.08, .024), ink, side*.75, .004)
			"squish":
				for side in [-1.0, 1.0]:
					face.mark(eye-s*.01, y+.04+side*.025, Vector2(.085, .026), ink, s*side*.5, .004)
			"falling":
				face.mark(eye, y+.05, Vector2(.13, .17), ink, 0, 0.0)
				face.mark(eye-.02, y+.09, Vector2(.055, .06), Color.WHITE, 0, .016)
				face.mark(eye+.025, y+.01, Vector2(.025, .025), Color.WHITE, 0, .016)
			_:
				if shape.sleepy and mood == "calm":
					face.mark(eye, y+.03, Vector2(.16, .04), ink, s*-.15, .006)
				else:
					face.mark(eye, y+.04, Vector2(.1, .135), ink, 0, 0.0)
					face.mark(eye-.015, y+.07, Vector2(.035, .04), Color.WHITE, 0, .016)
		if style == "panda" and mood not in ["happy", "content", "squish"] and not (shape.sleepy and mood == "calm"):
			face.mark(eye, y+.045, Vector2(.045, .07), INK, 0, .021)
		if mood == "worried":
			face.mark(eye+s*.01, y+.17, Vector2(.11, .026), ink, s*-.45, .004)
		if style in ["ninja", "panda"]:
			continue
		var blush := Color("ff8aa3") if mood in ["happy", "squish", "falling"] else BLUSH
		face.mark(x+s*minf(half.x*.62, .33), y-.07, Vector2(.18, .09), blush, 0, -.004)
	if style == "ninja":
		return
	if style == "panda":
		ink = INK
	match mood:
		"calm", "content":
			for s in [-1.0, 1.0]:
				face.mark(x+s*.034, y-.07, Vector2(.085, .032), ink, s*.55, .004)
		"worried", "squish":
			for k in 4:
				face.mark(x-.06+k*.04, y-.08+(.01 if k % 2 else -.01), Vector2(.03, .02), ink, 0, .004)
			if mood == "worried":
				kit.add("bead", Vector3(-half.x*.72, half.y*.6, half.z+.06), Vector3(.13, .16, .1), SWEAT, Vector3.ZERO, false)
				kit.add("cone", Vector3(-half.x*.72, half.y*.6+.11, half.z+.06), Vector3(.11, .16, .08), SWEAT, Vector3.ZERO, false)
		"happy":
			face.mark(x, y-.08, Vector2(.14, .1), ink, 0, 0.0)
			face.mark(x, y-.105, Vector2(.075, .04), Color("ff6f86"), 0, .006)
		"falling":
			face.mark(x, y-.1, Vector2(.1, .13), ink, 0, 0.0)
			face.mark(x, y-.13, Vector2(.06, .04), Color("ff6f86"), 0, .006)

## Costumes own their silhouette and face treatment; only animal suits share a pattern.
static func _outfit(kit: MeshKit, outfit: KinuOutfit, shape: KinuShape) -> void:
	var size := shape.size
	var h := size*.5
	var color := outfit.hood_color
	var cream := Color("fff4df")
	var dark := Color("302b37")
	var eye_y := h.y*.35 if shape.id == "tall" else 0.0
	var top := h.y*1.08
	var face := Face.new(kit, size*1.08, shape.roundness)
	var style := outfit.style
	if style == "leaf":
		kit.add("cylinder", Vector3(-h.x*.3, h.y+.08, 0), Vector3(.025, .17, .025), Color("4d9a2c"))
		kit.add("sphere", Vector3(-h.x*.3+.12, h.y+.18, 0), Vector3(.36, .045, .19), LEAF, Vector3(0, .4, .35))
		return
	if style == "ghost":
		_sheet(kit, shape, color)
		return
	if style in ["onsen", "nigiri", "hatchling", "parcel"]:
		_accessory(kit, shape, style)
		return
	if style == "pirate":
		# Tied red kerchief, a fitted vest, striped shirt and an actual one-eye patch.
		var red := Color("c93f49")
		kit.add_rounded_box(Vector3(0, h.y*.81, 0), Vector3(size.x*1.08, size.y*.3, size.z*1.08), red, Vector3.ZERO, true, shape.roundness)
		_ties(kit, Vector3(h.x+.02, h.y*.63, .02), red)
		kit.add_rounded_box(Vector3(0, -h.y*.65, 0), Vector3(size.x*1.06, size.y*.36, size.z*1.06), cream, Vector3.ZERO, true, shape.roundness)
		for i in 3:
			kit.add_rounded_box(Vector3(0, -h.y*.45-i*size.y*.085, h.z*1.04), Vector3(size.x*.72, size.y*.035, .03), Color("304257"), Vector3.ZERO, false, 4)
		for side in [-1.0, 1.0]:
			kit.add_rounded_box(Vector3(side*h.x*.8, -h.y*.48, .02), Vector3(size.x*.25, size.y*.49, size.z*1.08), dark, Vector3.ZERO, true, shape.roundness)
		var skin := Face.new(kit, size, shape.roundness)
		for i in 16:
			var t := float(i)/15
			skin.mark(lerpf(-h.x*.9, h.x*.9, t), eye_y+.04+(t-.35)*size.y*.23, Vector2(size.x*.1, .035), dark, .12, .027)
		skin.mark(-minf(h.x*.42, .2), eye_y+.04, Vector2(.24, .23), dark, -.15, .06)
		kit.add("torus", Vector3(-h.x-.035, eye_y-.07, h.z*.4), Vector3(.16, .16, .16), Color("f5c456"), Vector3(PI*.5, 0, 0))
		return
	# Full fabric shell, including the lower body. Face opening sits on the cloth surface.
	kit.add_rounded_box(Vector3.ZERO, size*1.08, color, Vector3.ZERO, true, shape.roundness)
	if style in ["tako", "daruma"]:
		_limbless_suit(kit, shape, style, color, face)
		return
	if style == "ninja":
		for side in [-1.0, 1.0]:
			kit.add("sphere", Vector3(side*minf(h.x*.5, .32), -h.y-.03, h.z*.4), Vector3(.25, .15, .28), color)
		_sash(kit, shape, Color("b94850"))
		_ties(kit, Vector3(h.x+.015, top*.65, -.15), Color("b94850"))
		# Wrapped tunic folds below the mask.
		face.mark(-size.x*.1, -h.y*.64, Vector2(size.x*.38, .025), color.lightened(.25), -.55, .015)
		return
	var paw := dark if style in ["panda", "bee"] else color.darkened(.08)
	if style == "unicorn":
		paw = Color("c9a3e6")
	elif style == "samurai":
		paw = Color("2a2530")
	for side in [-1.0, 1.0]:
		kit.add("sphere", Vector3(side*minf(h.x*.5, .32), -h.y-.03, h.z*.4), Vector3(.25, .16, .29), paw)
		# The lucky cat's beckoning arm is raised, and kimono sleeves replace the arms.
		if shape.id != "long" and not (style == "maneki" and side > 0) and style != "kimono":
			kit.add("sphere", Vector3(side*(h.x+.045), -h.y*.28, h.z*.15), Vector3(.19, size.y*.3, .23), paw, Vector3(0, 0, side*.2))
	# Belly panels make the animal costumes read as suits, even from a distance.
	if size.y > .8 and style in ["tanuki", "bunny", "fox", "frog", "dino", "shark", "tiger", "dragon", "kappa", "kitsune", "axolotl", "capybara"]:
		face.mark(0, -h.y*.82, Vector2(size.x*.46, size.y*.14), cream, 0, .018)
	if style in PREMIUM_STYLES:
		_premium_outfit(kit, shape, style, color, face)
		return
	if style in CUTE_STYLES:
		_cute_outfit(kit, shape, style, color, face)
		return
	match style:
		"panda":
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*h.x*.68, top+.06, 0), Vector3(.3, .3, .22), dark)
				# Patches and expression share eye anchors. Light eyes stay above the dark fabric.
				face.mark(side*minf(h.x*.42, .2), eye_y+.045, Vector2(.27, .30), dark, side*-.25, .012)
			face.mark(0, eye_y-.015, Vector2(.085, .055), dark, 0, .035)
			kit.add("sphere", Vector3(0, -h.y*.48, -h.z-.04), Vector3(.22, .22, .22), cream)
		"bunny":
			for side in [-1.0, 1.0]:
				var at := Vector3(side*h.x*.55, top+.24, 0)
				kit.add("sphere", at, Vector3(.24, .62, .18), color, Vector3(0, 0, side*-.2))
				kit.add("sphere", at+Vector3(0, 0, .075), Vector3(.11, .43, .045), Color("ed779f"), Vector3(0, 0, side*-.2), false)
			kit.add("sphere", Vector3(h.x*.5, -h.y*.48, -h.z-.08), Vector3(.32, .32, .32), cream)
		"tanuki", "fox", "tiger":
			for side in [-1.0, 1.0]:
				var at := Vector3(side*h.x*.64, top+.07, 0)
				var kind := "sphere" if style in ["tanuki", "tiger"] else "cone"
				kit.add(kind, at, Vector3(.29, .3, .22), dark if style == "tanuki" else color, Vector3(0, 0, side*-.2))
				kit.add(kind, at+Vector3(0, .01, .1), Vector3(.15, .18, .04), cream, Vector3(0, 0, side*-.2), false)
			# A visible curled tail, with a cream fox tip or alternating rings.
			for i in 5:
				var tone := color
				if style == "fox" and i >= 3:
					tone = cream
				elif style != "fox" and i % 2 == 1:
					tone = dark
				kit.add("sphere", Vector3(h.x*.8+.06*i, -h.y*.4+.065*i, -h.z-.06-.07*i), Vector3(.31, .29, .30)*(1.0-i*.07), tone)
			if style == "tanuki":
				kit.add("sphere", Vector3(.06, top+.13, 0), Vector3(.34, .05, .22), LEAF, Vector3(0, .3, .25))
				for side in [-1.0, 1.0]:
					face.mark(side*h.x*.79, eye_y, Vector2(size.x*.13, size.y*.3), dark, side*.18, .02)
			if style == "tiger":
				for side in [-1.0, 1.0]:
					for i in 3:
						face.mark(side*h.x*.84, h.y*(.55-i*.5), Vector2(size.x*.18, .045), dark, side*-.3, .025)
				for i in 3:
					face.mark((i-1)*size.x*.15, h.y*.83, Vector2(.05, size.y*.19), dark, 0, .025)
		"frog":
			for side in [-1.0, 1.0]:
				var at := Vector3(side*h.x*.57, top+.07, .03)
				kit.add("sphere", at, Vector3(.34, .32, .3), color)
				kit.add("sphere", at+Vector3(0, .035, .14), Vector3(.19, .18, .035), cream, Vector3.ZERO, false)
				kit.add("sphere", at+Vector3(0, .035, .16), Vector3(.09, .12, .025), INK, Vector3.ZERO, false)
				for toe in 3:
					kit.add("sphere", Vector3(side*minf(h.x*.5, .32)+(toe-1)*.07, -h.y-.08, h.z*.65), Vector3(.09, .07, .16), color)
		"bat", "dragon":
			for side in [-1.0, 1.0]:
				_wing(kit, Vector3(side*h.x*.88, h.y*.23, -h.z*.45), side, color.darkened(.15), size.y)
				kit.add("cone", Vector3(side*h.x*.5, top+.1, 0), Vector3(.18, .32, .17), cream if style == "dragon" else color, Vector3(0, 0, side*-.3))
			if style == "dragon":
				_tail(kit, h, color)
				for i in 3:
					kit.add("cone", Vector3(0, top+.05, -.1-i*.16), Vector3(.13, .19, .12), Color("f3ca72"))
		"dino":
			_tail(kit, h, color)
			for i in 5:
				kit.add("cone", Vector3(0, top+.055, -h.z+i*size.z*.2), Vector3(.18, .23, .16), Color("f4c574"))
		"shark":
			kit.add("cone", Vector3(0, top+.13, -h.z*.3), Vector3(.14, .42, .37), color, Vector3(-.2, 0, 0))
			for side in [-1.0, 1.0]:
				kit.add("cone", Vector3(side*(h.x+.15), -h.y*.3, 0), Vector3(.26, .42, .15), color, Vector3(0, 0, side*-1.0))
				kit.add("cone", Vector3(side*.13, 0, -h.z-.25), Vector3(.12, .42, .18), color, Vector3(0, 0, side*.7))
			# Teeth rim the face opening, outside the animated eyes and cheeks.
			for i in 5:
				kit.add("cone", Vector3((i-2)*minf(size.x*.13, .14), eye_y+minf(size.y*.31, .30), h.z*1.08+.035), Vector3(.085, .1, .055), cream, Vector3(PI, 0, 0), false)
		"strawberry":
			for i in 16:
				var x := sin(i*2.4)*h.x*.88
				var y := cos(i*1.7)*h.y*.87
				if absf(x) < minf(size.x*.43, .49) and absf(y-eye_y) < minf(size.y*.37, .37):
					continue
				face.mark(x, y, Vector2(.04, .065), Color("ffe9a8"), -.2, .025)
			for i in 6:
				var a := TAU*i/6.0
				kit.add("sphere", Vector3(sin(a)*size.x*.18, top+.04, cos(a)*size.z*.18), Vector3(.23, .065, .4), LEAF, Vector3(0, a, 0))
			kit.add("cylinder", Vector3(0, top+.14, 0), Vector3(.065, .23, .065), LEAF, Vector3(0, 0, -.2))
		"bee":
			# Stripes wrap below the face opening; short Kinu only have room for one.
			for frac in ([-.72, -.95] if size.y > .8 else [-.9]):
				_band(kit, shape, frac, .1 if size.y > .8 else .08, dark)
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*h.x*.45, top*.72, -h.z-.1), Vector3(.42, .56, .06), Color("dff3ff"), Vector3(0, side*.5, side*-.6))
				kit.add("cylinder", Vector3(side*h.x*.28, top+.12, 0), Vector3(.03, .26, .03), dark, Vector3(0, 0, side*-.35))
				kit.add("sphere", Vector3(side*(h.x*.28+.05), top+.25, 0), Vector3(.1, .1, .1), dark)
			kit.add("cone", Vector3(0, -h.y*.55, -h.z-.12), Vector3(.12, .22, .12), dark, Vector3(-PI*.5, 0, 0))
		"kappa":
			# A water dish ringed with hair on top, and a turtle shell on the back.
			var dish := Vector2(minf(size.x*.62, .62), minf(size.z*.62, .62))
			for i in 12:
				var a := TAU*i/12.0
				kit.add("sphere", Vector3(sin(a)*dish.x*.52, top+.01, cos(a)*dish.y*.52), Vector3(.13, .09, .13), color.darkened(.28))
			kit.add("cylinder", Vector3(0, top+.04, 0), Vector3(dish.x, .07, dish.y), Color("f6f1e3"))
			kit.add("cylinder", Vector3(0, top+.08, 0), Vector3(dish.x*.76, .02, dish.y*.76), Color("8fd3ff"), Vector3.ZERO, false)
			var shell := Color("8d6b3f")
			kit.add_rounded_box(Vector3(0, -h.y*.05, -h.z*1.08-.03), Vector3(size.x*.94, size.y*.88, .12), Color("f1d38a"), Vector3.ZERO, true, 3)
			kit.add_rounded_box(Vector3(0, -h.y*.02, -h.z*1.08-.09), Vector3(size.x*.8, size.y*.76, .14), shell, Vector3.ZERO, true, 3)
			for at in [Vector2(0, .1), Vector2(-.24, -.18), Vector2(.24, -.18)]:
				kit.add("sphere", Vector3(at.x*size.x, at.y*size.y, -h.z*1.08-.165), Vector3(.22, .18, .03), shell.darkened(.22), Vector3.ZERO, false)
		"astronaut":
			# Dark visor rim, ear seals, chest controls and twin life-support tanks.
			face.mark(0, eye_y+.015, Vector2(minf(size.x*.94, 1.08), minf(size.y*.8, .78)), Color("52657c"), 0, .01)
			for side in [-1.0, 1.0]:
				kit.add("cylinder", Vector3(side*(h.x+.045), eye_y+.04, 0), Vector3(.23, .13, .23), Color("778aa3"), Vector3(0, 0, PI*.5))
				kit.add("cylinder", Vector3(side*size.x*.22, 0, -h.z-.10), Vector3(.23, size.y*.76, .23), color)
			kit.add_rounded_box(Vector3(0, -h.y*.72, h.z*1.08), Vector3(size.x*.38, size.y*.18, .08), Color("52657c"), Vector3.ZERO, false, 4)
			for i in 3:
				kit.add("sphere", Vector3((i-1)*size.x*.105, -h.y*.72, h.z*1.08+.05), Vector3(.055, .055, .025), [Color("f57675"), Color("8cdbcf"), Color("f5d073")][i], Vector3.ZERO, false)

## How far a ray from `origin` travels before it leaves the superellipse with the given
## half-extents. The shape is convex, so a bisection always lands on the single exit point.
static func _surface_reach(origin: Vector2, direction: Vector2, half: Vector2, power: float) -> float:
	if pow(absf(origin.x/half.x), power)+pow(absf(origin.y/half.y), power) > 1.0:
		return 0.0
	var low := 0.0
	var high := half.length()*2.0
	for _step in 16:
		var middle := (low+high)*.5
		var probe := origin+direction*middle
		if pow(absf(probe.x/half.x), power)+pow(absf(probe.y/half.y), power) <= 1.0:
			low = middle
		else:
			high = middle
	return low

## A surface stripe trimmed to the body outline, laid down as a chain of short dashes rather than
## one long bar. A mark is a flat patch tangent to the point it is placed on, so a full-width bar
## leaves the surface behind at its ends: on the boxy shapes the rotated ends shot out past the
## silhouette, and on the round ones they hung off the sides like stray whiskers. Short dashes
## each sit on the surface they touch, so the crust follows the body whatever its shape.
static func _crust_line(face: Face, half: Vector2, power: float, roll: float, offset: float, color: Color, thickness: float, lift: float) -> void:
	var along := Vector2(cos(roll), sin(roll))
	var origin := Vector2(-along.y, along.x)*offset
	var ahead := _surface_reach(origin, along, half, power)
	var behind := _surface_reach(origin, -along, half, power)
	var span := ahead+behind
	if span < thickness*4.0:
		return
	var dashes := maxi(2, int(ceil(span/(minf(half.x, half.y)*.2))))
	var step := span/float(dashes)
	for i in dashes:
		var at := origin+along*(step*(i+.5)-behind)
		face.mark(at.x, at.y, Vector2(step*1.3, thickness), color, roll, lift)

## Bright, toy-like Catcher outfits. Shared primitives keep them readable on every Kinu shape,
## while each style gets its own silhouette, prop or surface motif.
static func _cute_outfit(kit: MeshKit, shape: KinuShape, style: String, color: Color, face: Face) -> void:
	var size := shape.size
	var h := size*.5
	var top := h.y*1.08
	var front := h.z*1.08
	var eye_y := h.y*.35 if shape.id == "tall" else 0.0
	var cream := Color("fff4df")
	var dark := Color("302b37")
	var pink := Color("ff9fbd")
	var gold := Color("f5c14e")
	var sky := Color("8fd3ff")
	match style:
		"chick":
			for i in 3:
				kit.add("sphere", Vector3((i-1)*.11, top+.12+(.06 if i == 1 else 0.0), -.02), Vector3(.13, .2, .12), color, Vector3(0, 0, (i-1)*-.3))
			kit.add("cone", Vector3(0, eye_y-.03, front+.13), Vector3(.1, .18, .1), Color("f28c28"), Vector3(PI*.5, 0, 0))
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*(h.x+.08), -.04, 0), Vector3(.11, size.y*.34, .34), color.lightened(.08), Vector3(.1, 0, side*.45))
				kit.add("sphere", Vector3(side*.22, -h.y-.08, front*.5), Vector3(.2, .07, .28), Color("f28c28"))
		"shiba", "calico", "red_panda", "snow_fox":
			var inner := Color("f7b6af") if style != "red_panda" else cream
			for side in [-1.0, 1.0]:
				var ear := Vector3(side*h.x*.62, top+.13, 0)
				kit.add("cone", ear, Vector3(.25, .38, .2), color, Vector3(0, 0, side*-.3))
				kit.add("cone", ear+Vector3(0, -.03, .08), Vector3(.12, .22, .04), inner, Vector3(0, 0, side*-.3), false)
			face.mark(0, eye_y-.14, Vector2(.24, .13), cream, 0, .02)
			if style == "calico":
				face.mark(-h.x*.83, eye_y+.18, Vector2(.25, .26), Color("e58a35"), -.35, .015)
				face.mark(h.x*.86, eye_y-.2, Vector2(.2, .26), dark, .3, .015)
			if style == "red_panda":
				for side in [-1.0, 1.0]:
					face.mark(side*h.x*.8, eye_y, Vector2(.16, .3), cream, side*.3, .02)
			for i in (8 if style == "snow_fox" else 6):
				var u := i/float(7 if style == "snow_fox" else 5)
				var tone := cream if style == "snow_fox" or (style == "shiba" and i > 3) else (dark if style == "red_panda" and i%2 else color)
				kit.add("sphere", Vector3(h.x*.72+i*.055, -h.y*.42+sin(u*PI)*.34, -h.z-.08-i*.07), Vector3.ONE*(.28-i*.018), tone)
			if style == "snow_fox":
				for flake in [-1.0, 1.0]:
					_cute_star(kit, Vector3(flake*h.x*.72, top+.02, front*.45), .11, sky, Vector3.FORWARD)
		"bear_cub", "hamster", "otter":
			for side in [-1.0, 1.0]:
				var ear := Vector3(side*h.x*.66, top+.04, 0)
				kit.add("sphere", ear, Vector3(.26, .25, .2), color)
				kit.add("sphere", ear+Vector3(0, 0, .11), Vector3(.13, .13, .035), pink if style == "hamster" else cream, Vector3.ZERO, false)
			face.mark(0, eye_y-.14, Vector2(.27, .16), cream, 0, .018)
			if style == "hamster":
				for side in [-1.0, 1.0]:
					face.mark(side*h.x*.76, eye_y-.12, Vector2(.17, .15), Color("ffb0b8"), 0, .02)
				kit.add("sphere", Vector3(.08, top+.13, .02), Vector3(.12, .2, .08), Color("d99b3d"), Vector3(0, 0, .6))
			elif style == "otter":
				face.mark(0, -h.y*.72, Vector2(size.x*.44, size.y*.17), cream, 0, .018)
				var shell := Vector3(0, -h.y*.3, front+.18)
				kit.add("sphere", shell, Vector3(.3, .26, .08), Color("d99b65"))
				for i in 3:
					kit.add("block", shell+Vector3((i-1)*.1, 0, .075), Vector3(.025, .32, .02), Color("9a6235"), Vector3.ZERO, false)
			else:
				_bell(kit, Vector3(0, -h.y*.72, front+.08), .12)
		"penguin":
			face.mark(0, -h.y*.45, Vector2(size.x*.58, size.y*.58), cream, 0, .016)
			kit.add("cone", Vector3(0, eye_y-.06, front+.12), Vector3(.09, .17, .09), Color("f2a12e"), Vector3(PI*.5, 0, 0))
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*(h.x+.1), -.08, -.02), Vector3(.08, size.y*.46, .28), color.darkened(.12), Vector3(.2, 0, side*.55))
				kit.add("sphere", Vector3(side*.23, -h.y-.08, front*.45), Vector3(.22, .07, .3), Color("f2a12e"))
		"duckling":
			kit.add("sphere", Vector3(0, top+.13, 0), Vector3(.12, .2, .12), color)
			kit.add("cone", Vector3(0, eye_y-.06, front+.15), Vector3(.11, .23, .11), Color("f28c28"), Vector3(PI*.5, 0, 0))
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*(h.x+.08), -.05, 0), Vector3(.1, size.y*.4, .34), color.lightened(.06), Vector3(.15, 0, side*.5))
		"seal":
			face.mark(0, eye_y-.15, Vector2(.3, .16), cream, 0, .02)
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*(h.x+.09), -h.y*.38, 0), Vector3(.09, .32, .28), color.darkened(.06), Vector3(.2, 0, side*.75))
				for whisker in [-1.0, 1.0]:
					face.mark(side*h.x*.2, eye_y-.15+whisker*.045, Vector2(.19, .012), dark, side*.08, .025)
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*.14, -h.y*.45, -h.z-.25), Vector3(.13, .34, .3), color, Vector3(.6, 0, side*.5))
		"mushroom":
			kit.add("sphere", Vector3(0, top+.11, 0), Vector3(size.x*.72, .3, size.z*.72), color)
			for i in 7:
				var a := TAU*i/7.0
				kit.add("sphere", Vector3(sin(a)*h.x*.58, top+.22, cos(a)*h.z*.58), Vector3(.09, .045, .09), cream, Vector3.ZERO, false)
			_band(kit, shape, -.76, .12, cream)
		"peach", "lemon":
			kit.add("cylinder", Vector3(0, top+.13, 0), Vector3(.045, .18, .045), Color("6d8f39"), Vector3(0, 0, -.25))
			kit.add("sphere", Vector3(.13, top+.22, .01), Vector3(.3, .045, .16), Color("74b84a"), Vector3(0, .35, .3))
			if style == "peach":
				face.mark(0, minf(eye_y+.31, h.y*.72), Vector2(.025, .24), color.darkened(.16), 0, .02)
			else:
				for side in [-1.0, 1.0]:
					kit.add("cone", Vector3(side*h.x*.45, top+.03, 0), Vector3(.14, .22, .14), color, Vector3(0, 0, side*-.7))
		"cupcake":
			for i in 5:
				face.mark((i-2)*size.x*.18, -h.y*.72, Vector2(.035, size.y*.28), Color("c94d68"), 0, .02)
			for i in 7:
				var a := TAU*i/7.0
				kit.add("sphere", Vector3(sin(a)*h.x*.55, top+.08, cos(a)*h.z*.55), Vector3(.28, .2, .28), cream)
			kit.add("sphere", Vector3(0, top+.32, .02), Vector3(.17, .17, .17), Color("e44755"))
		"pudding":
			kit.add("sphere", Vector3(0, top+.02, 0), Vector3(size.x*.48, .11, size.z*.48), Color("8b4d2c"))
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*.16, top+.13, .02), Vector3(.19, .13, .18), cream)
			kit.add("sphere", Vector3(0, top+.25, .02), Vector3(.12, .12, .12), Color("e44755"))
		"boba":
			for i in 9:
				face.mark(sin(i*2.2)*h.x*.72, -h.y*.78+cos(i*1.7)*h.y*.14, Vector2(.075, .075), Color("4a2d2a"), 0, .025)
			kit.add("cylinder", Vector3(h.x*.32, top+.25, 0), Vector3(.055, .6, .055), Color("ff8fb1"), Vector3(0, 0, -.18))
			_band(kit, shape, .82, .07, Color("fff4df"))
		"melonpan":
			var crust := color.darkened(.18)
			var crust_half := Vector2(face.half.x, face.half.y)*.9
			for roll in [.65, -.65]:
				var span := _surface_reach(Vector2.ZERO, Vector2(-sin(roll), cos(roll)), crust_half, shape.roundness)
				for i in 5:
					_crust_line(face, crust_half, shape.roundness, roll, (i-2)*span*.4, crust, .025, .018)
		"donut":
			kit.add("torus", Vector3(0, top+.13, 0), Vector3(size.x*.52, .18, size.z*.52), Color("d8a15c"), Vector3.ZERO)
			kit.add("torus", Vector3(0, top+.18, 0), Vector3(size.x*.45, .1, size.z*.45), pink, Vector3.ZERO, false)
			for i in 10:
				var a := TAU*i/10.0
				kit.add("block", Vector3(sin(a)*h.x*.38, top+.28, cos(a)*h.z*.38), Vector3(.025, .07, .025), RAINBOW[i%RAINBOW.size()], Vector3(0, a, .7), false)
		"marshmallow":
			kit.add_rounded_box(Vector3(0, top-.01, 0), Vector3(size.x*.86, .16, size.z*.86), Color("d6a170"), Vector3.ZERO, false, 8)
			for i in 5:
				face.mark((i-2)*size.x*.18, h.y*.82, Vector2(.06, .035), Color("d6a170"), i*.5, .02)
		"taiyaki":
			for i in 3:
				face.mark(-h.x*.78+i*h.x*.78, -h.y*.64, Vector2(.18, .08), color.darkened(.18), .25, .02)
			kit.add("cone", Vector3(0, top+.12, -.08), Vector3(.12, .28, .35), color.lightened(.08))
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*.2, -.05, -h.z-.27), Vector3(.12, .42, .34), color, Vector3(.1, 0, side*.45))
		"cloud_outfit":
			for i in 7:
				var a := TAU*i/7.0
				kit.add("sphere", Vector3(sin(a)*h.x*.65, top+.06+cos(a)*.04, cos(a)*h.z*.58), Vector3(.26, .2, .25), cream)
			for side in [-1.0, 1.0]:
				kit.add("bead", Vector3(side*h.x*.7, -h.y*.65, front+.05), Vector3(.09, .15, .06), sky, Vector3.ZERO, false)
		"star_outfit":
			_cute_star(kit, Vector3(0, top+.18, 0), .32, gold, Vector3.UP)
			for side in [-1.0, 1.0]:
				_cute_star(kit, Vector3(side*(h.x+.04), -.15, .04), .15, cream, Vector3(side, 0, 0))
		"moon_outfit":
			kit.add("torus", Vector3(0, top+.14, 0), Vector3(.34, .11, .34), gold, Vector3(PI*.5, 0, 0))
			for side in [-1.0, 1.0]:
				_cute_star(kit, Vector3(side*h.x*.65, top+.02, front*.35), .1, cream, Vector3.FORWARD)
		"sunflower", "daisy":
			var petals := Color("ffd34f") if style == "sunflower" else cream
			var center := Color("70452d") if style == "sunflower" else gold
			for i in 10:
				var a := TAU*i/10.0
				kit.add("sphere", Vector3(sin(a)*.3, top+.16+cos(a)*.3, .02), Vector3(.11, .23, .07), petals, Vector3(0, 0, -a))
			kit.add("sphere", Vector3(0, top+.16, .08), Vector3(.2, .2, .08), center, Vector3.ZERO, false)
			if style == "daisy":
				for side in [-1.0, 1.0]:
					_cute_flower(kit, Vector3(side*(h.x+.03), -.25, .08), .11, cream, Vector3(side, 0, 0))
		"sailor":
			kit.add("cylinder", Vector3(0, top+.08, 0), Vector3(size.x*.48, .12, size.z*.48), cream)
			kit.add("cylinder", Vector3(0, top+.15, 0), Vector3(size.x*.35, .16, size.z*.35), Color("3d67a3"))
			_band(kit, shape, -.65, .08, cream)
			_cute_bow(kit, Vector3(0, -h.y*.58, front+.08), Color("e84b57"), .22)
		"raincoat":
			kit.add("torus", Vector3(0, top+.03, 0), Vector3(size.x*.55, .09, size.z*.55), color.darkened(.08))
			for i in 3:
				kit.add("sphere", Vector3(0, -h.y*.42-i*.15, front+.08), Vector3(.055, .055, .035), cream, Vector3.ZERO, false)
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*.24, -h.y-.08, front*.45), Vector3(.22, .08, .3), Color("e85e4f"))
		"overalls":
			face.mark(0, -h.y*.64, Vector2(size.x*.58, size.y*.35), Color("4f8cc9"), 0, .02)
			for side in [-1.0, 1.0]:
				face.mark(side*h.x*.42, -h.y*.35, Vector2(.07, size.y*.55), Color("4f8cc9"), side*-.08, .02)
				face.mark(side*h.x*.33, -h.y*.42, Vector2(.055, .055), gold, 0, .026)
			face.mark(0, -h.y*.64, Vector2(.22, .12), Color("376fa9"), 0, .03)
		"artist":
			kit.add("sphere", Vector3(-.08, top+.12, 0), Vector3(size.x*.55, .13, size.z*.48), Color("d9485f"), Vector3(0, 0, -.12))
			_cute_bow(kit, Vector3(h.x+.06, -.1, .08), Color("4f8cc9"), .18)
			var palette := Vector3(-h.x-.12, -h.y*.25, front*.2)
			kit.add("sphere", palette, Vector3(.08, .3, .25), Color("d9a66b"), Vector3(0, 0, .5))
			for i in 4:
				kit.add("sphere", palette+Vector3(.04, -.1+i*.07, .22), Vector3.ONE*.035, RAINBOW[i], Vector3.ZERO, false)
		"sleepy_cap":
			kit.add("cone", Vector3(.14, top+.35, -.02), Vector3(.35, .75, .32), color, Vector3(0, 0, -.55))
			kit.add("sphere", Vector3(.43, top+.57, -.02), Vector3.ONE*.14, cream)
			for i in 3:
				_cute_star(kit, Vector3(-h.x*.55+i*.2, top+.04, front*.45), .07, gold, Vector3.FORWARD)
		"magical_girl":
			_cute_bow(kit, Vector3(0, top+.12, .04), Color("ffcf54"), .28)
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*(h.x+.07), -h.y*.2, 0), Vector3(.11, .38, .3), cream, Vector3(.1, 0, side*.45))
				_cute_star(kit, Vector3(side*h.x*.78, -.2, front+.04), .11, gold, Vector3.FORWARD)
			_band(kit, shape, -.72, .1, cream)
			var wand := Vector3(h.x+.22, -.05, front*.2)
			kit.add("cylinder", wand, Vector3(.035, .7, .035), gold, Vector3(0, 0, -.35))
			_cute_star(kit, wand+Vector3(.22, .34, 0), .14, pink, Vector3.FORWARD)
		"moon_princess":
			kit.add("torus", Vector3(0, top+.18, .02), Vector3(.32, .09, .32), gold, Vector3(PI*.5, 0, 0))
			for i in 5:
				kit.add("sphere", Vector3((i-2)*.12, top+.02-absf(i-2)*.02, front*.25), Vector3.ONE*.055, cream, Vector3.ZERO, false)
			_band(kit, shape, -.7, .09, gold)
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*(h.x+.08), -.15, -h.z*.25), Vector3(.1, size.y*.5, .35), color.lightened(.15), Vector3(.2, 0, side*.35))
		"candy_witch":
			kit.add("cone", Vector3(.08, top+.38, -.03), Vector3(.48, .9, .45), color.darkened(.12), Vector3(0, 0, -.25))
			kit.add("torus", Vector3(0, top+.03, 0), Vector3(size.x*.58, .1, size.z*.58), pink)
			for i in 4:
				kit.add("torus", Vector3(.08, top+.13+i*.15, -.03), Vector3(.25-i*.035, .055, .25-i*.035), [pink, gold][i%2], Vector3(0, 0, -.25), false)
			_cute_bow(kit, Vector3(h.x*.55, top+.14, front*.3), gold, .18)
		"celestial_bunny":
			for side in [-1.0, 1.0]:
				var ear := Vector3(side*h.x*.46, top+.31, 0)
				kit.add("sphere", ear, Vector3(.2, .66, .16), color, Vector3(0, 0, side*-.16))
				kit.add("sphere", ear+Vector3(0, 0, .08), Vector3(.08, .45, .035), pink, Vector3(0, 0, side*-.16), false)
				_cute_star(kit, Vector3(side*h.x*.7, top+.02, front*.4), .09, gold, Vector3.FORWARD)
			kit.add("sphere", Vector3(h.x*.55, -h.y*.42, -h.z-.08), Vector3(.32, .32, .32), cream)
			_bell(kit, Vector3(0, -h.y*.68, front+.08), .13)
		"sakura_deer":
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*h.x*.63, top+.02, 0), Vector3(.14, .27, .13), color, Vector3(0, 0, side*-.7))
				for branch in 2:
					kit.add("cylinder", Vector3(side*(h.x*.38+branch*.1), top+.25+branch*.12, -.03), Vector3(.035, .34, .035), Color("8a5a3a"), Vector3(0, 0, side*(-.35+branch*.2)))
					_cute_flower(kit, Vector3(side*(h.x*.46+branch*.1), top+.42+branch*.1, 0), .09, Color("ffb6ca"), Vector3.FORWARD)
			for i in 4:
				face.mark((i-1.5)*.16, -h.y*.7, Vector2(.07, .07), cream, 0, .02)
		"royal_frog":
			for side in [-1.0, 1.0]:
				var at := Vector3(side*h.x*.57, top+.07, .03)
				kit.add("sphere", at, Vector3(.32, .3, .28), color)
				kit.add("sphere", at+Vector3(0, .03, .14), Vector3(.17, .16, .035), cream, Vector3.ZERO, false)
				kit.add("sphere", at+Vector3(0, .03, .17), Vector3(.075, .09, .02), dark, Vector3.ZERO, false)
			for i in 3:
				kit.add("cone", Vector3((i-1)*.18, top+.28, 0), Vector3(.11, .3 if i == 1 else .22, .1), gold)
			_band(kit, shape, -.7, .08, Color("7d3fa0"))
		"pastel_dragon":
			for side in [-1.0, 1.0]:
				_wing(kit, Vector3(side*h.x*.88, h.y*.18, -h.z*.45), side, pink, size.y)
				kit.add("cone", Vector3(side*h.x*.48, top+.12, 0), Vector3(.16, .3, .15), gold, Vector3(0, 0, side*-.3))
			_tail(kit, h, color)
			for i in 4:
				kit.add("cone", Vector3(0, top+.05, -h.z+i*size.z*.22), Vector3(.12, .2, .11), RAINBOW[i+1])
		"jellyfish":
			kit.add("sphere", Vector3(0, top+.05, 0), Vector3(size.x*.65, .28, size.z*.65), color.lightened(.16))
			for i in 7:
				var x := (i-3)*size.x*.14
				kit.add("sphere", Vector3(x, -h.y*.45, -h.z-.13), Vector3(.07, size.y*(.34+.04*(i%2)), .09), [pink, sky, Color("c5a5ff")][i%3], Vector3(0, 0, sin(i)*.22))
			for i in 5:
				kit.add("sphere", Vector3((i-2)*.14, top+.11, front*.45), Vector3.ONE*.055, cream, Vector3.ZERO, false)
		"fairy":
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*(h.x+.12), .1, -h.z*.25), Vector3(.08, .48, .42), Color("dff8ff"), Vector3(.25, side*.35, side*.65))
				kit.add("sphere", Vector3(side*(h.x+.12), -h.y*.35, -h.z*.25), Vector3(.07, .3, .3), Color("ffdff0"), Vector3(.25, side*.35, side*.8))
				_cute_flower(kit, Vector3(side*h.x*.42, top+.11, front*.18), .1, pink if side < 0 else cream, Vector3.FORWARD)
			var wand := Vector3(h.x+.2, -.08, front*.18)
			kit.add("cylinder", wand, Vector3(.025, .62, .025), gold, Vector3(0, 0, -.4))
			_cute_star(kit, wand+Vector3(.2, .29, 0), .12, gold, Vector3.FORWARD)
		"builder":
			# A chunky hard hat, reflective vest and little tool belt make the early stacking reward read instantly.
			kit.add("cylinder", Vector3(0, top+.1, 0), Vector3(size.x*.54, .16, size.z*.54), Color("ffd34f"))
			kit.add("sphere", Vector3(0, top+.2, 0), Vector3(size.x*.46, .16, size.z*.46), Color("ffd34f"))
			_band(kit, shape, -.58, .16, Color("f18c31"))
			for side in [-1.0, 1.0]:
				face.mark(side*h.x*.45, -h.y*.55, Vector2(.05, size.y*.42), Color("fff2a3"), side*.2, .028)
		"acrobat":
			_band(kit, shape, -.72, .12, Color("d8434f"))
			kit.add("cylinder", Vector3(0, top+.24, 0), Vector3(.045, size.x*1.9, .045), Color("9a6235"), Vector3(0, 0, PI*.5))
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*(h.x+.18), top+.24, 0), Vector3(.12, .12, .12), cream)
		"chef":
			for i in 5:
				kit.add("sphere", Vector3((i-2)*.12, top+.16+absf(i-2)*.015, 0), Vector3(.17, .22, .16), cream)
			_band(kit, shape, .72, .07, Color("e54d5b"))
			_band(kit, shape, -.68, .08, Color("e54d5b"))
		"yukata":
			_band(kit, shape, -.72, .18, Color("344f9d"))
			for i in 6:
				_cute_flower(kit, Vector3((i%2-.5)*size.x*.72, (-.25+(i/3)*.24)*size.y, front+.025), .07, Color("ffd5e5"), Vector3.FORWARD)
			_cute_bow(kit, Vector3(0, -h.y*.68, -h.z-.1), Color("e75a8d"), .16)
		"climber":
			kit.add("sphere", Vector3(0, top+.12, 0), Vector3(size.x*.52, .16, size.z*.52), Color("d84c4d"))
			kit.add("sphere", Vector3(0, top+.27, -.08), Vector3(.16, .16, .16), Color("fff4df"))
			kit.add_rounded_box(Vector3(0, -.05, -h.z-.13), Vector3(size.x*.62, size.y*.62, .16), Color("4d7f57"), Vector3.ZERO, true, 5)
			for side in [-1.0, 1.0]:
				kit.add("cylinder", Vector3(side*h.x*.28, -.05, -h.z-.23), Vector3(.018, size.y*.5, .018), gold, Vector3(0, 0, side*.18))
		"lucky_charm":
			_band(kit, shape, .72, .07, Color("d8434f"))
			kit.add("sphere", Vector3(0, top+.14, 0), Vector3(.23, .18, .23), gold)
			_bell(kit, Vector3(0, -h.y*.67, front+.1), .14)
			for side in [-1.0, 1.0]:
				_cute_star(kit, Vector3(side*h.x*.63, top+.04, front*.45), .09, gold, Vector3.FORWARD)
		"jelly_cube":
			kit.add("sphere", Vector3(0, top+.06, 0), Vector3(size.x*.58, .2, size.z*.58), color.lightened(.18))
			for i in 5:
				kit.add("sphere", Vector3((i-2)*size.x*.18, top-.02, front*.7), Vector3(.1, .17, .05), color.lightened(.28), Vector3.ZERO, false)
		"rose_delight":
			kit.add("sphere", Vector3(0, top+.08, 0), Vector3(size.x*.56, .18, size.z*.56), Color("f6bfd0"))
			for i in 7:
				face.mark(sin(i*2.1)*h.x*.73, cos(i*1.7)*h.y*.73, Vector2(.04, .05), Color("e47e9e"), 0, .022)
		"chocolate_square":
			for row in 2:
				for column in 3:
					face.mark((column-1)*size.x*.27, (-.38+row*.38)*size.y, Vector2(size.x*.22, size.y*.25), Color("6e3d2a"), 0, .022)
			_band(kit, shape, .78, .07, Color("d9b080"))
		"burger":
			kit.add("sphere", Vector3(0, top+.08, 0), Vector3(size.x*.61, .25, size.z*.61), Color("e7a552"))
			_band(kit, shape, .5, .09, Color("74a64a"))
			_band(kit, shape, .33, .1, Color("6f3928"))
			for i in 7:
				kit.add("sphere", Vector3(sin(i*2.4)*h.x*.45, top+.25, cos(i*2.4)*h.z*.45), Vector3(.025, .02, .05), Color("fff0b5"), Vector3.ZERO, false)
		"snack_box":
			kit.add_rounded_box(Vector3(0, top+.08, 0), Vector3(size.x*.86, .2, size.z*.82), Color("f4c846"), Vector3.ZERO, true, 4)
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*h.x*.46, top+.23, 0), Vector3(.16, .34, .12), Color("f4c846"))
			_band(kit, shape, -.67, .13, Color("dd3e43"))
		"sea_sponge":
			for i in 11:
				face.mark(sin(i*2.3)*h.x*.78, cos(i*1.7)*h.y*.78, Vector2(.06, .07), Color("d2a739"), 0, .018)
			_band(kit, shape, -.62, .16, Color("f7f0d9"))
			_band(kit, shape, -.86, .17, Color("754b35"))
			face.mark(0, -h.y*.71, Vector2(.055, size.y*.23), Color("d94648"), 0, .03)
		"bread_loaf":
			kit.add("sphere", Vector3(0, top+.08, 0), Vector3(size.x*.62, .25, size.z*.62), Color("bd763f"))
			for i in 3:
				face.mark((i-1)*size.x*.22, top*.78, Vector2(.06, size.y*.28), Color("f4cb7b"), -.35, .024)

static func _cute_bow(kit: MeshKit, at: Vector3, color: Color, scale: float) -> void:
	for side in [-1.0, 1.0]:
		kit.add("sphere", at+Vector3(side*scale*.7, 0, 0), Vector3(scale, scale*.62, scale*.25), color, Vector3(0, 0, side*.35))
	kit.add("sphere", at+Vector3(0, 0, scale*.12), Vector3.ONE*scale*.35, color.darkened(.12), Vector3.ZERO, false)

static func _cute_flower(kit: MeshKit, at: Vector3, scale: float, color: Color, normal: Vector3) -> void:
	var facing := Basis.looking_at(-normal, Vector3.UP if absf(normal.y) < .9 else Vector3.FORWARD)
	for i in 5:
		var a := TAU*i/5.0
		kit.add_transformed("sphere", Transform3D(facing*Basis.from_scale(Vector3(scale*.72, scale, scale*.24)), at+facing*Vector3(sin(a)*scale*.72, cos(a)*scale*.72, 0)), color, false)
	kit.add("sphere", at+normal*.02, Vector3.ONE*scale*.35, GOLD, Vector3.ZERO, false)

static func _cute_star(kit: MeshKit, at: Vector3, scale: float, color: Color, normal: Vector3) -> void:
	var facing := Basis.looking_at(-normal, Vector3.UP if absf(normal.y) < .9 else Vector3.FORWARD)
	kit.add_transformed("sphere", Transform3D(facing*Basis.from_scale(Vector3.ONE*scale*.45), at), color, false)
	for i in 5:
		var a := TAU*i/5.0
		var ray := facing*Vector3(sin(a), cos(a), 0)
		kit.add_transformed("cone", Transform3D(Basis(Quaternion(Vector3.UP, ray))*Basis.from_scale(Vector3(scale*.42, scale, scale*.32)), at+ray*scale*.72), color, false)

## Kinu Catcher suits. Everything worn on the front stays outside the face opening so every mood
## reads, and tall trims (horns, crests, tails) sit above or behind the body.
static func _premium_outfit(kit: MeshKit, shape: KinuShape, style: String, color: Color, face: Face) -> void:
	var size := shape.size
	var h := size*.5
	var top := h.y*1.08
	var front := h.z*1.08
	var eye_y := h.y*.35 if shape.id == "tall" else 0.0
	var tall := size.y > .8
	var cream := Color("fff4df")
	var dark := Color("302b37")
	var red := Color("dd3f3f")
	var pink := Color("ffb3cf")
	# The opening's lower edge, and the lowest point a front trim can sit without leaving the body.
	var chin := eye_y-minf(size.y*.35, .3)
	match style:
		"kitsune":
			for side in [-1.0, 1.0]:
				var ear := Vector3(side*h.x*.55, top+.15, 0)
				kit.add("cone", ear, Vector3(.27, .44, .21), color, Vector3(0, 0, side*-.28))
				kit.add("cone", ear+Vector3(0, -.03, .09), Vector3(.13, .27, .04), red, Vector3(0, 0, side*-.28), false)
				# Painted kumadori swooshes on each cheek of the mask.
				face.mark(side*h.x*.94, eye_y-.04, Vector2(.05, minf(size.y*.28, .24)), red, side*.35, .02)
				face.mark(side*h.x*.9, eye_y+.12, Vector2(.035, minf(size.y*.14, .12)), red, side*.6, .02)
			if h.y*.95 > eye_y+.38:
				face.mark(0, eye_y+.39, Vector2(.08, .12), red, 0, .02)
				face.mark(0, eye_y+.36, Vector2(.04, .06), GOLD, 0, .03)
			if tall:
				var collar := -.74
				_band(kit, shape, collar, .07, red)
				_bell(kit, Vector3(0, h.y*collar-.09, front+.07), .13)
			# Three long fox tails fanned up behind, fluffy through the middle with a flame-orange tip.
			for t in 3:
				var fan := (t-1)*.62
				var base := Vector3(0, -h.y*.3, -h.z-.02)
				for i in 10:
					var u := i/9.0
					var at := base+Vector3(sin(fan)*(u*.95+u*u*.2), u*.9+u*u*.35-absf(sin(fan))*u*u*.3, -.12-u*.42+u*u*.15)
					var radius := lerpf(.16, .32, sin(u*PI*.9))*(1.0-maxf(u-.75, 0)*1.6)
					var tone := color if i < 7 else (Color("ffcf8a") if i == 7 else Color("ff9a4d") if i == 8 else Color("ff6a3d"))
					kit.add("sphere", at, Vector3.ONE*radius, tone)
		"phoenix":
			var flame := Color("ff8a3d")
			for i in 3:
				var lean := (i-1)*.5
				var turn := Vector3(-.35, 0, lean)
				var at := Vector3(sin(lean)*.12, top+.24+(.1 if i == 1 else 0.0), -.04)
				kit.add("sphere", at, Vector3(.12, .56, .12), [flame, red.lightened(.1), flame][i], turn)
				kit.add("sphere", at+Basis.from_euler(turn)*Vector3(0, .27, 0), Vector3(.16, .16, .16), GOLD)
			if h.y*.95 > eye_y+.34:
				for side in [-1.0, 1.0]:
					face.mark(side*.13, eye_y+.35, Vector2(.16, .05), GOLD, side*-.25, .02)
			# Wings raised at the sides: layered feathers, crimson to flame to gold at the tips.
			for side in [-1.0, 1.0]:
				for f in 4:
					var spread := .35+f*.3
					var root := Vector3(side*(h.x+.02), h.y*.1, -h.z*.25)
					var dir := Vector3(side*sin(spread), cos(spread), -.15).normalized()
					var length := minf(size.y, .8)*(.9-f*.1)+.25
					kit.add_transformed("sphere", Transform3D(Basis(Quaternion(Vector3.UP, dir))*Basis.from_scale(Vector3(.2, length, .09)), root+dir*length*.5), [color.darkened(.1), red.lightened(.15), flame, GOLD][f])
			if tall:
				for row in 2:
					for c in 3-row:
						face.mark((c-(2-row)*.5)*.2, chin-.07-row*.1, Vector2(.15, .09), GOLD if row == 0 else GOLD.darkened(.1), 0, .02+row*.004)
			# Five tail plumes arcing up and back like a fountain, each ending in a golden eye.
			for i in 5:
				var fan := (i-2)*.36
				var base := Vector3(0, -h.y*.2, -h.z-.02)
				var tip := base
				for k in 7:
					var u := (k+1)/7.0
					tip = base+Vector3(sin(fan)*u*.7, u*.95-u*u*.55+(.25 if i == 2 else 0.0)*u, -u*.85)
					kit.add("sphere", tip, Vector3(.15, .15, .15)*(1.0-u*.35), [color, red.lightened(.1), flame, flame, GOLD, GOLD, GOLD][k])
				kit.add("sphere", tip+Vector3(0, -.02, -.1), Vector3(.24, .3, .1), GOLD, Vector3(-.5, fan, 0))
				kit.add("sphere", tip+Vector3(0, -.02, -.16), Vector3(.12, .15, .04), Color("3fb6e8"), Vector3(-.5, fan, 0), false)
		"unicorn":
			var horn := Vector3(0, top+.22, minf(h.z*.3, .2))
			var tilt := Vector3(.28, 0, 0)
			kit.add("cone", horn, Vector3(.18, .56, .18), GOLD, tilt)
			for i in 3:
				kit.add("torus", horn+Basis.from_euler(tilt)*Vector3(0, -.18+i*.14, 0), Vector3(.16-i*.045, .14, .16-i*.045), GOLD.darkened(.18), tilt+Vector3(.35, 0, .2), false)
			for side in [-1.0, 1.0]:
				var ear := Vector3(side*h.x*.62, top+.1, -.02)
				kit.add("cone", ear, Vector3(.2, .3, .16), color, Vector3(0, 0, side*-.35))
				kit.add("cone", ear+Vector3(0, -.02, .07), Vector3(.1, .18, .03), pink, Vector3(0, 0, side*-.35), false)
				if tall:
					face.mark(side*h.x*.95, chin-.02, Vector2(.08, .02), GOLD, 0, .02)
					face.mark(side*h.x*.95, chin-.02, Vector2(.02, .08), GOLD, 0, .02)
			# A rainbow mane running over the crown and down the back, then a rainbow tail.
			var mane: Array[Vector3] = []
			# The mane falls from the crown over one side of the head and on down the back.
			for i in 5:
				mane.append(Vector3(-h.x*.25-i*.04, top+.08-i*.01, lerpf(h.z*.55, -h.z*.9, i/4.0)))
			for i in 6:
				mane.append(Vector3(-h.x*1.02-.06, lerpf(top-.02, -h.y*.35, i/5.0), lerpf(h.z*.5, -h.z*.3, i/5.0)))
			for i in 4:
				mane.append(Vector3(-h.x*.2, lerpf(h.y*.8, -h.y*.1, i/3.0), -h.z*1.08-.07))
			for i in mane.size():
				kit.add("sphere", mane[i], Vector3(.28, .24, .26), RAINBOW[i % RAINBOW.size()])
			for i in 6:
				var u := i/5.0
				kit.add("sphere", Vector3(sin(u*4.0)*.12, -h.y*.35-u*.12+sin(u*3.0)*.1, -h.z-.12-u*.42), Vector3.ONE*(.24-u*.08), RAINBOW[i])
		"maneki":
			var orange := Color("f2a33a")
			for side in [-1.0, 1.0]:
				var ear := Vector3(side*h.x*.6, top+.1, 0)
				kit.add("cone", ear, Vector3(.26, .3, .2), orange if side < 0 else color, Vector3(0, 0, side*-.25))
				kit.add("cone", ear+Vector3(0, -.02, .09), Vector3(.13, .17, .04), pink, Vector3(0, 0, side*-.25), false)
			# Calico patches over the crown and back.
			kit.add("fine", Vector3(-h.x*.35, top-.07, -h.z*.15), Vector3(size.x*.52, .16, size.z*.62), orange, Vector3(0, .5, 0))
			kit.add("fine", Vector3(h.x*.4, h.y*.1, -h.z*1.02), Vector3(size.x*.36, size.y*.4, .16), dark, Vector3(0, 0, .4))
			kit.add("fine", Vector3(-h.x*.45, -h.y*.35, -h.z*1.02), Vector3(size.x*.28, size.y*.3, .15), orange, Vector3(0, 0, -.3))
			# The beckoning paw, raised beside the face, with a pink pad.
			var arm := Vector3(h.x+.13, eye_y+minf(h.y*.55, .3), h.z*.35)
			kit.add("fine", arm, Vector3(.3, minf(size.y*.7, .6), .3), color, Vector3(0, 0, -.12))
			var paw_at := arm+Vector3(-.03, minf(size.y*.3, .26), .0)
			kit.add("fine", paw_at, Vector3(.34, .3, .32), color)
			kit.add("sphere", paw_at+Vector3(0, -.03, .16), Vector3(.15, .12, .03), pink, Vector3.ZERO, false)
			for toe in 3:
				kit.add("sphere", paw_at+Vector3(-.08+toe*.08, .07, .15), Vector3.ONE*.06, pink, Vector3.ZERO, false)
			if tall:
				_band(kit, shape, -.74, .07, red)
				_bell(kit, Vector3(0, -h.y*.74-.1, front+.07), .15)
			# A gold koban coin hugged against the side.
			var coin := Vector3(-(h.x+.09), -h.y*.3, h.z*.35)
			kit.add("cylinder", coin, Vector3(.24, .05, minf(size.y*.6, .38)), GOLD, Vector3(0, 0, PI*.5))
			for i in 3:
				kit.add("block", coin+Vector3(-.03, -.08+i*.08, 0), Vector3(.02, .015, .12), GOLD.darkened(.3), Vector3.ZERO, false)
			for i in 3:
				kit.add("sphere", Vector3(h.x*.3+i*.05, -h.y*.6+i*.1, -h.z-.1-i*.03), Vector3.ONE*(.16-i*.02), color)
		"samurai":
			var lacquer := Color("b8323c")
			var black := Color("2a2530")
			# Helmet bowl with raised ribs, a stepped neck guard, gold horns and a sun crest.
			kit.add("fine", Vector3(0, top-.12, -.02), Vector3(size.x*1.04, .52, size.z*1.04), black)
			for i in 5:
				var a := (i-2)*.32
				kit.add("sphere", Vector3(sin(a)*h.x*.55, top+.1-absf(a)*.08, -.02), Vector3(.035, .06, size.z*.9), black.lightened(.18), Vector3(0, 0, -a*.5), false)
			for step in (3 if tall else 2):
				var plate := Vector3(size.x*1.12+step*.1, .085, size.z*.85+step*.08)
				kit.add_rounded_box(Vector3(0, top-.16-step*.085, -h.z*.3-step*.03), plate, lacquer if step % 2 == 0 else black, Vector3(-.1, 0, 0), true, 6)
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*.2, top+.3, h.z*.6), Vector3(.08, .6, .05), GOLD, Vector3(-.15, 0, side*-.5))
				# Shoulder guards hanging over the arms, trimmed with gold lacing.
				var guard := Vector3(side*(h.x+.1), h.y*.05, 0)
				kit.add_rounded_box(guard, Vector3(.09, minf(size.y*.55, .48), size.z*.7), lacquer, Vector3(0, 0, side*.14), true, 6)
				for row in 2:
					kit.add_rounded_box(guard+Vector3(side*.05, .1-row*.16, 0), Vector3(.02, .025, size.z*.66), GOLD, Vector3(0, 0, side*.14), false, 6)
			kit.add("cylinder", Vector3(0, top+.12, h.z*.68), Vector3(.2, .05, .2), red, Vector3(PI*.5-.2, 0, 0))
			for i in (3 if tall else 1):
				var frac := -.64-i*.13 if tall else -.84
				_band(kit, shape, frac, .09, lacquer if i % 2 == 0 else lacquer.darkened(.28))
				for c in 5:
					face.mark((c-2)*size.x*.16, h.y*frac, Vector2(.03, .03), GOLD, 0, .045)
		"koi":
			var orange := Color("f0592f")
			# Kohaku patches: a red crown, red splashes at the top corners of the face and on the back.
			kit.add("fine", Vector3(0, top-.06, -h.z*.1), Vector3(size.x*.85, .18, size.z*.75), orange)
			for side in [-1.0, 1.0]:
				face.mark(side*h.x*.78, eye_y+minf(h.y*.62, .34), Vector2(size.x*.3, minf(size.y*.3, .24)), orange, side*.4, .014)
				kit.add("fine", Vector3(side*h.x*1.02, -h.y*.25, -h.z*.4), Vector3(.15, size.y*.4, size.z*.45), orange, Vector3(0, 0, side*.2))
			kit.add("fine", Vector3(0, 0, -h.z*1.03), Vector3(size.x*.6, size.y*.6, .16), orange)
			if tall:
				for row in 2:
					for c in 4:
						face.mark((c-1.5+row*.5)*.17, chin-.08-row*.1, Vector2(.12, .07), color.darkened(.1), 0, .02)
						face.mark((c-1.5+row*.5)*.17, chin-.065-row*.1, Vector2(.12, .07), color, 0, .024)
			# A tall rippled dorsal fin along the spine.
			for i in 5:
				var z := lerpf(h.z*.3, -h.z*.9, i/4.0)
				kit.add("sphere", Vector3(0, top+.16-absf(i-1.5)*.03, z), Vector3(.06, .36+sin(i*1.4)*.06, size.z*.26), orange.lightened(.12))
			for side in [-1.0, 1.0]:
				# Big translucent-looking pectoral fins and a long two-lobed tail.
				kit.add("sphere", Vector3(side*(h.x+.16), -h.y*.45, h.z*.2), Vector3(.06, .3, .5), Color("fff0e8"), Vector3(.4, 0, side*1.05))
				kit.add("sphere", Vector3(side*(h.x+.2), -h.y*.45, h.z*.2), Vector3(.05, .2, .34), orange.lightened(.25), Vector3(.4, 0, side*1.05), false)
				kit.add("sphere", Vector3(side*.24, -h.y*.05+.1, -h.z-.5), Vector3(.1, .62, .78), orange if side < 0 else Color("fff0e8"), Vector3(-.6, 0, side*.6))
				if tall:
					kit.add("cylinder", Vector3(side*.26, chin-.1, front+.05), Vector3(.03, .26, .03), orange, Vector3(.3, 0, side*.8))
		"axolotl":
			var gill := Color("e2507f")
			for side in [-1.0, 1.0]:
				for g in 3:
					var base := Vector3(side*(h.x*1.02), minf(top-.08, eye_y+.3)-g*minf(size.y*.14, .12), -.04)
					for k in 3:
						var at := base+Vector3(side*(.1+k*.11), .04+k*(.07-g*.05), -.02*k)
						kit.add("sphere", at, Vector3(.15, .1, .1)*(1.0-k*.12), gill, Vector3(0, 0, side*(.5-g*.4)))
						kit.add("sphere", at+Vector3(0, .06, 0), Vector3(.05, .05, .05), gill.lightened(.3), Vector3.ZERO, false)
			for i in 5:
				kit.add("sphere", Vector3(sin(i*2.3)*h.x*.6, top-.01, cos(i*1.7)*h.z*.5-.05), Vector3(.1, .03, .1), color.darkened(.18), Vector3.ZERO, false)
			kit.add("sphere", Vector3(0, -h.y*.1, -h.z-.3), Vector3(.08, minf(size.y*.7, .6), .62), color.darkened(.06), Vector3(-.25, 0, 0))
		"kimono":
			var obi := Color("e9b949")
			var cord := Color("d8434f")
			var print_tone := Color("fff0f4")
			var obi_frac := -.68 if tall else -.8
			var obi_y := h.y*obi_frac
			_band(kit, shape, obi_frac, .24 if tall else .2, obi)
			face.mark(0, obi_y, Vector2(size.x*.8, .032), cord, 0, .05)
			face.mark(0, obi_y, Vector2(.08, .08), GOLD, 0, .06)
			if tall:
				for side in [-1.0, 1.0]:
					face.mark(side*.1, obi_y+.12, Vector2(.28, .045), cream, side*-.9, .03)
			# The obi's drum bow on the back.
			var bow := Vector3(0, obi_y+.05, -h.z*1.14-.08)
			kit.add_rounded_box(bow, Vector3(size.x*.5, minf(size.y*.34, .3), .16), obi, Vector3.ZERO, true, 5)
			for side in [-1.0, 1.0]:
				kit.add("sphere", bow+Vector3(side*size.x*.2, .12, -.04), Vector3(.28, .2, .12), obi.darkened(.08))
				# Long swinging sleeves with a pink hem.
				var sleeve := Vector3(side*(h.x+.1), -h.y*.2, 0)
				kit.add_rounded_box(sleeve, Vector3(.12, minf(size.y*.8, .72), size.z*.66), color.lightened(.06), Vector3(0, 0, side*.1), true, 5)
				kit.add_rounded_box(sleeve+Vector3(side*.005, -minf(size.y*.4, .36)+.02, 0), Vector3(.13, .05, size.z*.67), print_tone, Vector3(0, 0, side*.1), false, 5)
			# Sakura prints scattered over the sides and back.
			if tall:
				for i in 4:
					var x: float = [-.42, .38, -.3, .44][i]*size.x
					var y := chin-.1-float(i % 2)*.08
					face.mark(x, y, Vector2(.09, .09), print_tone, i, .03)
					face.mark(x, y, Vector2(.035, .035), GOLD, 0, .036)
			for i in 8:
				var side := -1.0 if i % 2 else 1.0
				var at := Vector3(side*(h.x*1.09), lerpf(-h.y*.5, h.y*.6, fmod(i*.37, 1.0)), lerpf(-h.z*.6, h.z*.6, fmod(i*.61, 1.0)))
				if i >= 6:
					at = Vector3((i-6.5)*h.x*.9, h.y*.25, -h.z*1.09)
				_blossom(kit, at, Vector3(side, 0, 0) if i < 6 else Vector3.FORWARD, print_tone)
			var pin := Vector3(h.x*.5, top+.04, h.z*.25)
			for i in 3:
				kit.add("sphere", pin+Vector3(i*.1-.1, .02+(.04 if i == 1 else 0.0), -i*.03), Vector3(.14, .12, .14), [Color("ff7fa6"), cream, Color("ff9fbf")][i])
			for i in 2:
				var strand := pin+Vector3(.12+i*.07, -.12, .05)
				kit.add("cylinder", strand, Vector3(.012, .2, .012), GOLD, Vector3.ZERO, false)
				kit.add("sphere", strand-Vector3(0, .11, 0), Vector3(.05, .05, .05), GOLD)
		"oni":
			var horn := Color("ffd166")
			for side in [-1.0, 1.0]:
				var at := Vector3(side*h.x*.45, top+.16, .04)
				kit.add("cone", at, Vector3(.19, .38, .19), horn, Vector3(0, 0, side*-.28))
				kit.add("torus", at+Vector3(-side*.02, -.12, 0), Vector3(.21, .14, .21), horn.darkened(.25), Vector3(0, 0, side*-.28), false)
				if tall:
					kit.add("cone", Vector3(side*.12, chin+.03, front+.06), Vector3(.07, .1, .05), cream, Vector3.ZERO, false)
			for i in 5:
				kit.add("sphere", Vector3((i-2)*.1, top+.02, -.1+sin(i*2.0)*.08), Vector3(.14, .1, .14), Color("3a2a2a"))
			# A tiger-print loincloth.
			var cloth_frac := -.78 if tall else -.82
			_band(kit, shape, cloth_frac, .2 if tall else .22, Color("f5b93b"))
			for i in 7:
				face.mark((i-3)*size.x*.13, h.y*cloth_frac, Vector2(.035, minf(size.y*.16, .12)), dark, .35, .045)
			# A studded kanabo club leaning on the side.
			var club := Vector3(h.x+.2, -h.y*.1, h.z*.1)
			kit.add("cylinder", club, Vector3(.13, minf(size.y*1.15, 1.0), .13), Color("7a5236"), Vector3(0, 0, -.2))
			for i in 4:
				kit.add("sphere", club+Basis(Vector3.BACK, -.2)*Vector3(sin(i*2.1)*.07, .1+i*.1, cos(i*2.1)*.07), Vector3(.05, .05, .05), GOLD, Vector3.ZERO, false)
		"capybara":
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*h.x*.62, top+.02, -.06), Vector3(.15, .12, .1), color.darkened(.25))
				face.mark(side*h.x*.93, eye_y+.05, Vector2(.03, minf(size.y*.2, .16)), color.darkened(.2), side*.1, .02)
			kit.add("sphere", Vector3(0, top-.02, -h.z*.6), Vector3(size.x*.5, .06, size.z*.25), color.darkened(.12), Vector3.ZERO, false)
			# A yuzu balanced on the head, with a smaller one on top of that.
			var yuzu := Color("ffc93c")
			var fruit := Vector3(-h.x*.05, top+.17, 0)
			kit.add("fine", fruit, Vector3(.38, .32, .38), yuzu)
			kit.add("fine", fruit+Vector3(.03, .26, .01), Vector3(.22, .19, .22), yuzu.darkened(.04))
			for i in 7:
				var a := i*2.4
				kit.add("bead", fruit+Vector3(sin(a)*.15, sin(i*1.3)*.08, cos(a)*.15), Vector3(.025, .025, .025), yuzu.darkened(.18), Vector3.ZERO, false)
			kit.add("cylinder", fruit+Vector3(.03, .37, .01), Vector3(.03, .06, .03), Color("5d7a2e"))
			kit.add("sphere", fruit+Vector3(.12, .38, .02), Vector3(.2, .03, .1), LEAF, Vector3(0, .3, .3))

## A round gold bell with a dark slot.
static func _bell(kit: MeshKit, at: Vector3, radius: float) -> void:
	kit.add("sphere", at, Vector3.ONE*radius, GOLD)
	kit.add("block", at+Vector3(0, -radius*.2, radius*.48), Vector3(radius*.12, radius*.36, .02), Color("6b4a1a"), Vector3.ZERO, false)
	kit.add("block", at+Vector3(0, radius*.05, radius*.49), Vector3(radius*.7, radius*.08, .02), Color("c9912e"), Vector3.ZERO, false)

## A five-petal blossom pressed flat against the fabric, facing `normal`.
static func _blossom(kit: MeshKit, at: Vector3, normal: Vector3, color: Color) -> void:
	var facing := Basis.looking_at(-normal, Vector3.UP if absf(normal.y) < .9 else Vector3.FORWARD)
	for i in 5:
		var a := TAU*i/5.0
		kit.add_transformed("sphere", Transform3D(facing*Basis.from_scale(Vector3(.06, .06, .015)), at+facing*Vector3(sin(a)*.045, cos(a)*.045, 0)+normal*.01), color, false)
	kit.add_transformed("sphere", Transform3D(facing*Basis.from_scale(Vector3(.03, .03, .015)), at+normal*.018), GOLD, false)

## Tako and Daruma have no paws: tentacles or a weighted base replace them.
static func _limbless_suit(kit: MeshKit, shape: KinuShape, style: String, color: Color, face: Face) -> void:
	var size := shape.size
	var h := size*.5
	var cream := Color("fff4df")
	if style == "tako":
		for i in 8:
			var a := TAU*(i+.5)/8.0
			var out := Vector3(sin(a), 0, cos(a))
			var base := Vector3(sin(a)*h.x*.82, -h.y*.96, cos(a)*h.z*.82)
			# Each tentacle tapers outward and curls up at the tip.
			for k in 4:
				var at := base+out*(k*.1)+Vector3(0, k*k*.024, 0)
				kit.add("sphere", at, Vector3(.24, .16, .24)*(1.0-k*.2), color.darkened(.06))
			kit.add("sphere", base+out*.12+Vector3(0, .02, 0), Vector3(.06, .06, .03), cream, Vector3(0, a, 0), false)
		# Hachimaki headband with a red sun and a tied knot, for takoyaki day.
		_band(kit, shape, .86, .1, cream)
		face.mark(0, h.y*.86, Vector2(.09, .09), Color("d8434f"), 0, .045)
		_ties(kit, Vector3(h.x+.015, h.y*.86, -.12), cream)
		return
	var gold := Color("f2c14e")
	var opening := _opening(shape, style)
	# Gold rim inked on both edges, so it reads even when the face itself is gold.
	var rim_center := opening.get_center()
	face.mark(rim_center.x, rim_center.y, opening.size*1.22, INK, 0, .006)
	face.mark(rim_center.x, rim_center.y, opening.size*1.16, gold, 0, .012)
	face.mark(rim_center.x, rim_center.y, opening.size*1.05, INK, 0, .018)
	kit.add_rounded_box(Vector3(0, -h.y*.98, 0), Vector3(size.x*1.1, .1, size.z*1.1), color.darkened(.25), Vector3.ZERO, true, shape.roundness)
	if size.y > .8:
		for side in [-1.0, 1.0]:
			face.mark(side*h.x*.45, -h.y*.78, Vector2(size.x*.26, .05), gold, side*-.35, .02)
			face.mark(side*h.x*.28, -h.y*.9, Vector2(size.x*.16, .05), gold, side*.35, .02)
	else:
		for side in [-1.0, 1.0]:
			face.mark(side*h.x*.8, 0, Vector2(.05, size.y*.4), gold, side*.2, .02)

## Worn over the bare Kinu. Everything stays clear of the face so every mood reads.
static func _accessory(kit: MeshKit, shape: KinuShape, style: String) -> void:
	var size := shape.size
	var h := size*.5
	match style:
		"onsen":
			var towel_at := Vector3(-h.x*.1, h.y+.07, 0)
			var towel_turn := Vector3(0, .25, .05)
			var towel := Vector3(minf(size.x*.7, .8), .14, minf(size.z*.62, .62))
			kit.add_rounded_box(towel_at, towel, Color("f7f3ea"), towel_turn, true, 4)
			for side in [-1.0, 1.0]:
				var stripe_at := towel_at+Basis.from_euler(towel_turn)*Vector3(side*towel.x*.3, 0, 0)
				kit.add_rounded_box(stripe_at, Vector3(.05, towel.y+.012, towel.z+.012), Color("7fb8d8"), towel_turn, false, 4)
			var duck := towel_at+Vector3(.06, .17, .02)
			var yellow := Color("ffd84d")
			kit.add("sphere", duck, Vector3(.27, .2, .3), yellow)
			kit.add("sphere", duck+Vector3(0, .14, .07), Vector3(.17, .17, .17), yellow)
			kit.add("cone", duck+Vector3(0, .13, .18), Vector3(.07, .09, .07), Color("ff9a3c"), Vector3(PI*.5, 0, 0))
			for side in [-1.0, 1.0]:
				kit.add("sphere", duck+Vector3(side*.045, .17, .145), Vector3(.03, .035, .02), INK, Vector3.ZERO, false)
		"nigiri":
			var salmon := Color("f98a5e")
			kit.add_rounded_box(Vector3(0, h.y+.05, -.04), Vector3(size.x*1.12, .13, size.z*1.08), salmon, Vector3(-.08, 0, 0), true, 3)
			kit.add_rounded_box(Vector3(0, h.y*.5, -h.z-.05), Vector3(size.x*1.1, h.y*.95, .11), salmon, Vector3(.12, 0, 0), true, 3)
			for i in 4:
				var x := lerpf(-h.x*.72, h.x*.72, i/3.0)
				kit.add("sphere", Vector3(x, h.y+.12, -.04), Vector3(.05, .02, size.z*.9), Color("ffe3cf"), Vector3(-.08, .5, 0), false)
			kit.add("sphere", Vector3(h.x*.55, h.y+.17, h.z*.25), Vector3(.13, .09, .13), Color("9ccc5a"))
		"hatchling":
			_eggshell(kit, shape, false)
			_eggshell(kit, shape, true)
		"parcel":
			var card := Color("d9a86c")
			var flap := minf(size.y*.3, .3)
			var rim := -h.y*.36
			kit.add_rounded_box(Vector3(0, -h.y*.71, 0), Vector3(size.x*1.16, size.y*.35, size.z*1.16), card, Vector3.ZERO, true, 12)
			var front := Vector3(0, rim-flap*.45, size.z*.58+.035)
			kit.add_rounded_box(front, Vector3(size.x*1.1, flap, .04), card.darkened(.06), Vector3(-.25, 0, 0), true, 12)
			kit.add_rounded_box(front+Vector3(0, 0, .025), Vector3(.14, flap*1.01, .02), Color("f2e2b8"), Vector3(-.25, 0, 0), false, 12)
			kit.add_rounded_box(Vector3(0, rim+flap*.45, -size.z*.58-.06), Vector3(size.x*1.1, flap, .04), card.darkened(.06), Vector3(-.45, 0, 0), true, 12)
			for side in [-1.0, 1.0]:
				kit.add_rounded_box(Vector3(side*(size.x*.58+.06), rim+flap*.45, 0), Vector3(.04, flap, size.z*1.1), card.darkened(.06), Vector3(0, 0, -side*.45), true, 12)
			if size.y > .8:
				kit.add_rounded_box(Vector3(h.x*.5, -h.y*.92, size.z*.58+.01), Vector3(.24, .13, .02), Color("fff4df"), Vector3.ZERO, false, 8)
				kit.add_rounded_box(Vector3(h.x*.5, -h.y*.9, size.z*.58+.025), Vector3(.18, .025, .01), Color("d8434f"), Vector3.ZERO, false, 8)

## Half an eggshell hugging the body's own curve, with a zigzag cracked edge inked all round.
## The lower half dips at the front to clear the mouth; the cap stays above the eyes.
## Soy glaze coating the top of a Kinu (or its costume) and running down the sides and back in
## a few rounded drips. The front stays clear so every expression reads.
static func glaze(shape: KinuShape, outfit: KinuOutfit = null, underside: bool = false, sauce_color: Color = Color("efb547")) -> Node3D:
	if outfit and outfit.finish:
		outfit = null
	var kit := MeshKit.new()
	var style := outfit.style if outfit else ""
	var k := 3.5 if style == "ghost" else shape.roundness
	var cover := .5
	if style == "ghost":
		cover = .59
	elif style != "" and style not in BARE_STYLES:
		cover = .54
	elif style in ["pirate", "hatchling", "nigiri"]:
		cover = .56
	var half := shape.size*cover+Vector3.ONE*.018
	# Headwear sits above the body, so the top glaze is poured over it rather than hidden under it.
	var headwear := {"hatchling": .2, "nigiri": .13, "onsen": .16, "kappa": .1, "pirate": .02, "samurai": .14, "capybara": .3}
	if not underside:
		half.y += float(headwear.get(style, 0.0))
		# Round bodies narrow towards the top, so headwear reaches further past them.
		if headwear.has(style) and shape.roundness < 4.0:
			half += Vector3(.06, .1, .06)
	var sauce := sauce_color
	var segments := 96
	var rows := 10
	var eye_y := shape.size.y*.175 if shape.id == "tall" else 0.0
	var front_edge := maxf(.7, (eye_y+.15)/half.y) if not underside else .8
	var drips := [[1.2, .5], [1.9, .35], [2.6, .55], [3.14, .42], [3.7, .58], [4.4, .38], [5.1, .5]]
	var edge_at := func(theta: float) -> float:
		var frontness := clampf((cos(theta)-.2)/.6, 0, 1)
		var edge := lerpf(.5 if not underside else .72, front_edge, frontness)
		for drip in drips:
			var lobe := pow(maxf(0.0, cos((theta-float(drip[0]))*4.5)), 6.0)
			edge -= float(drip[1])*lobe*(1.0-frontness)*(1.0 if not underside else .45)
		return clampf(edge, -.7, .97)
	var point := func(phi: float, theta: float) -> Vector3:
		var ring := MeshKit._signed_pow(sin(phi), 2.0/k)
		var y := half.y*MeshKit._signed_pow(cos(phi), 2.0/k)
		return Vector3(half.x*ring*MeshKit._signed_pow(sin(theta), 2.0/k), -y if underside else y, half.z*ring*MeshKit._signed_pow(cos(theta), 2.0/k))
	for row in rows:
		for seg in segments:
			var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
			if underside:
				corners.reverse()
			for corner in corners:
				var theta: float = TAU*(seg+corner.x)/segments
				var rim := acos(MeshKit._signed_pow(edge_at.call(theta), k/2.0))
				var phi: float = rim*(row+corner.y)/rows
				var at: Vector3 = point.call(phi, theta)
				var down: Vector3 = point.call(phi+.002, theta)-point.call(maxf(phi-.002, 0.0), theta)
				var across: Vector3 = point.call(phi, theta+.002)-point.call(phi, theta-.002)
				var normal := down.cross(across)
				normal = normal.normalized() if normal.length() > .000001 else Vector3.UP
				if underside:
					normal = -normal
				kit.fill.set_color(Color(sauce, 0))
				kit.fill.set_normal(normal)
				kit.fill.add_vertex(at)
				kit.hull.set_normal(normal)
				kit.hull.add_vertex(at)
	kit.hull_used = true
	# Glossy streaks catch the light on top.
	for streak in ([] if underside else [[.55, -.9, Vector3(.3, .02, .09)], [.75, -.55, Vector3(.14, .02, .06)]]):
		var at: Vector3 = point.call(float(streak[0]), float(streak[1]))
		kit.add("sphere", at*1.01, streak[2], sauce.lightened(.30), Vector3(0, float(streak[1])+.6, 0), false)
	var node := kit.build(.02, false)
	node.name = "SauceBottom" if underside else "Sauce"
	var gloss := ShaderMaterial.new()
	gloss.shader = MeshKit.TOON
	gloss.set_shader_parameter("shine", .35)
	gloss.set_shader_parameter("rim_strength", .12)
	gloss.set_shader_parameter("shadow_tint", Color(.7, .6, .6))
	(node.get_node("Fill") as MeshInstance3D).material_override = gloss
	return node

## Golden rice syrup distinguishes a naturally Sticky Kinu from shoyu bottle glaze.
## It coats the whole Kinu, so the effect is readable from every rotation.
static func sticky_coat(shape: KinuShape, outfit: KinuOutfit = null) -> Node3D:
	var root := Node3D.new()
	root.name = "StickyCoat"
	root.add_child(glaze(shape, outfit))
	root.add_child(glaze(shape, outfit, true))
	return root

static func _eggshell(kit: MeshKit, shape: KinuShape, cap: bool) -> void:
	var size := shape.size
	var h := size*.5
	var k := shape.roundness
	var shell := Color("ffffff")
	var teeth := 13
	var segments := teeth*4
	var rows := 14
	var jag := .09
	var outer := h+Vector3.ONE*.05
	var inner := h+Vector3.ONE*.015
	var eye_y := h.y*.35 if shape.id == "tall" else 0.0
	var front_edge := maxf(.58, (eye_y+.2)/h.y+jag) if cap else minf(-.4, -.17/h.y)-jag
	# Short Kinu have little room under the mouth, so their shell climbs higher round the sides.
	var back_edge := front_edge+(-.12 if cap else clampf(.2+(.8-size.y)*.6, .2, .4))
	var rim_phi := func(theta: float, index: int) -> float:
		var frontness := clampf((cos(theta)-.45)/.45, 0, 1)
		var wave := absf(fmod(float(index)/4.0, 1.0)*2.0-1.0)*2.0-1.0
		var tooth := jag*wave*(.75+.25*sin(floor(index/4.0)*1.7))
		var edge := clampf(lerpf(back_edge, front_edge, frontness)+tooth, -.97, .97)
		return acos(MeshKit._signed_pow(edge, k/2.0))
	var point := func(half: Vector3, phi: float, theta: float) -> Vector3:
		var ring := MeshKit._signed_pow(sin(phi), 2.0/k)
		return Vector3(half.x*ring*MeshKit._signed_pow(sin(theta), 2.0/k), half.y*MeshKit._signed_pow(cos(phi), 2.0/k), half.z*ring*MeshKit._signed_pow(cos(theta), 2.0/k))
	# t runs from the top of each piece downward, matching the ghost sheet's winding.
	var phi_at := func(t: float, seg: int) -> float:
		var rim: float = rim_phi.call(TAU*seg/segments, seg)
		return lerpf(0.0, rim, t) if cap else lerpf(rim, PI, t)
	for layer in [outer, inner]:
		var outward: bool = layer == outer
		for row in rows:
			for seg in segments:
				var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
				if not outward:
					corners.reverse()
				for corner in corners:
					var index: int = seg+int(corner.x)
					var theta: float = TAU*index/segments
					var phi: float = phi_at.call((row+corner.y)/rows, index)
					var at: Vector3 = point.call(layer, phi, theta)
					var down: Vector3 = point.call(layer, phi+.002, theta)-point.call(layer, phi-.002, theta)
					var across: Vector3 = point.call(layer, phi, theta+.002)-point.call(layer, phi, theta-.002)
					var normal := down.cross(across)
					normal = normal.normalized() if normal.length() > .000001 else (Vector3.UP if phi < 1.0 else Vector3.DOWN)
					if not outward:
						normal = -normal
					kit.fill.set_color(Color(shell if outward else shell.darkened(.12), 0))
					kit.fill.set_normal(normal)
					kit.fill.add_vertex(at)
					if outward:
						kit.hull.set_normal(normal)
						kit.hull.add_vertex(at)
	# Ink the cracked edge: the rim between the two layers plus a strip down the outside.
	for seg in segments:
		var quads := []
		var rim_points := []
		for index in [seg, seg+1]:
			var theta: float = TAU*index/segments
			var phi: float = rim_phi.call(theta, index)
			var edge: Vector3 = point.call(outer, phi, theta)
			var flat := Vector3(edge.x, 0, edge.z).normalized()
			rim_points.append([point.call(inner, phi, theta), edge, edge+flat*.004+Vector3.UP*(-.035 if not cap else .035)])
		quads.append([rim_points[0][0], rim_points[1][0], rim_points[1][1], rim_points[0][1]])
		quads.append([rim_points[0][1], rim_points[1][1], rim_points[1][2], rim_points[0][2]])
		for quad in quads:
			var normal: Vector3 = (quad[1]-quad[0]).cross(quad[3]-quad[0]).normalized()
			for order in [[0, 1, 2, 0, 2, 3], [0, 2, 1, 0, 3, 2]]:
				for i in order:
					kit.fill.set_color(Color(INK, 0))
					kit.fill.set_normal(normal if order[1] == 1 else -normal)
					kit.fill.add_vertex(quad[i])
	kit.hull_used = true

## A wrapped band at a height fraction of the body, following the Kinu's curvature.
static func _band(kit: MeshKit, shape: KinuShape, frac: float, thickness: float, color: Color) -> void:
	var size := shape.size
	# Measured against the suit shell (8% larger than the body) so the band sits on the fabric.
	var waist := pow(1.0-pow(absf(frac)/1.08, shape.roundness), 1.0/shape.roundness)
	kit.add_rounded_box(Vector3(0, size.y*.5*frac, 0), Vector3(size.x*1.14*waist, size.y*thickness, size.z*1.14*waist), color, Vector3.ZERO, true, shape.roundness)

static func _sash(kit: MeshKit, shape: KinuShape, color: Color) -> void:
	var size := shape.size
	var waist := pow(1.0-pow(.65, shape.roundness), 1.0/shape.roundness)
	kit.add_rounded_box(Vector3(0, -size.y*.35, 0), Vector3(size.x*1.10*waist, size.y*.1, size.z*1.10*waist), color, Vector3.ZERO, true, shape.roundness)

static func _ties(kit: MeshKit, at: Vector3, color: Color) -> void:
	kit.add("sphere", at, Vector3(.16, .15, .16), color)
	for i in 2:
		kit.add_rounded_box(at+Vector3(.11+i*.025, -.13-i*.055, -.01), Vector3(.12, .35, .045), color, Vector3(0, .1, .55-i*.8), true, 3)

static func _tail(kit: MeshKit, h: Vector3, color: Color) -> void:
	for i in 5:
		kit.add("sphere", Vector3(h.x*.65+i*.08, -h.y*.5+i*.05, -h.z-i*.12), Vector3(.35, .32, .34)*(1.0-i*.16), color)

## Scalloped membrane silhouette, with thin raised wing fingers.
static func _wing(kit: MeshKit, at: Vector3, side: float, color: Color, height: float) -> void:
	var scale_y := minf(height, 1.0)
	var contour := PackedVector2Array([Vector2(0, .12), Vector2(.25, .44), Vector2(.63, .30), Vector2(.49, .21), Vector2(.41, .11), Vector2(.38, -.06), Vector2(.31, -.02), Vector2(.25, -.04), Vector2(.21, -.22), Vector2(.14, -.13), Vector2(.08, -.13), Vector2(0, -.27)])
	var indices := Geometry2D.triangulate_polygon(contour)
	for front in [true, false]:
		for t in range(0, indices.size(), 3):
			for c in ([0, 1, 2] if (front == (side < 0)) else [2, 1, 0]):
				var p := contour[indices[t+c]]
				var normal := Vector3(0, 0, 1 if front else -1)
				var vertex := at+Vector3(p.x*side, p.y*scale_y, .04 if front else 0.0)
				kit.fill.set_color(Color(color, 0))
				kit.fill.set_normal(normal)
				kit.fill.add_vertex(vertex)
				kit.hull.set_normal(normal)
				kit.hull.add_vertex(vertex)
	kit.hull_used = true
	for tip in [2, 5, 8, 11]:
		var end := contour[tip]
		var delta := Vector3(end.x*side, (end.y-.12)*scale_y, 0)
		kit.add("sphere", at+Vector3(0, .12*scale_y, .045)+delta*.5, Vector3(.025, delta.length(), .025), color.lightened(.2), Vector3(0, 0, -atan2(delta.x, delta.y)), false)

static func _sheet_size(shape: KinuShape) -> Vector3:
	return shape.size*Vector3(1.18, 1.16, 1.18)

## Gap kept between a worn ghost's sheet and the top and bottom of its hitbox. The inked hem is
## a thin strip right at the bottom edge, so any sheet below the hitbox is buried in whatever the
## ghost is sitting on and the hem line vanishes.
const GHOST_CLEARANCE := .01
static var ghost_fits: Dictionary = {}

## The flared, hanging sheet reaches well past Kinu's hitbox, so ghosts resting hitbox to hitbox
## sank into each other and two white sheets fused with no ink between them. In a pile the whole
## ghost (sheet, face and glaze) is drawn through this transform, which fits the sheet's measured
## bounds inside the hitbox: flush at the sides (so neighbouring hems meet rather than overlap)
## and GHOST_CLEARANCE short of the top and bottom. Single-Kinu previews don't need it.
static func ghost_fit(shape: KinuShape) -> Transform3D:
	if not ghost_fits.has(shape.id):
		var size := _sheet_size(shape)
		var low := Vector3.INF
		var high := -Vector3.INF
		for row in 41:
			for seg in 80:
				var point := _sheet_point(size, row/40.0, TAU*seg/80.0)
				low = low.min(point)
				high = high.max(point)
		var target := shape.size+Vector3(OUTLINE_WIDTH, OUTLINE_WIDTH-GHOST_CLEARANCE, OUTLINE_WIDTH)*2
		var reach := Vector3(maxf(-low.x, high.x)*2, high.y-low.y, maxf(-low.z, high.z)*2)
		var fit := Vector3(minf(1, target.x/reach.x), minf(1, target.y/reach.y), minf(1, target.z/reach.z))
		ghost_fits[shape.id] = Transform3D(Basis.from_scale(fit), Vector3(0, -(high.y+low.y)*.5*fit.y, 0))
	return ghost_fits[shape.id]

## A continuous cloth dome that flares into a wavy hem below Kinu's feet.
static func _sheet(kit: MeshKit, shape: KinuShape, color: Color) -> void:
	var size := _sheet_size(shape)
	var rings := 28
	var segments := 80
	for row in rings:
		for seg in segments:
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
				var t: float = (row+corner.y)/rings
				var angle: float = TAU*(seg+corner.x)/segments
				var point := _sheet_point(size, t, angle)
				var down := _sheet_point(size, minf(t+.001, 1), angle)-_sheet_point(size, maxf(t-.001, 0), angle)
				var across := _sheet_point(size, t, angle+.001)-_sheet_point(size, t, angle-.001)
				var normal := down.cross(across).normalized() if t > .001 else Vector3.UP
				kit.fill.set_color(Color(color, 0))
				kit.fill.set_normal(normal)
				kit.fill.add_vertex(point)
				kit.hull.set_normal(normal)
				kit.hull.add_vertex(point)
	# Close the underside against the exact wavy hem, including its outline hull.
	# The recessed centre keeps the edge looking like hanging fabric when tilted.
	var underside := Vector3(0, -size.y*.52-.035, 0)
	for seg in segments:
		var edge := _sheet_point(size, 1.0, TAU*seg/segments)
		var next := _sheet_point(size, 1.0, TAU*(seg+1)/segments)
		# A shared underside normal avoids radial toon-lighting wedges.
		var normal := Vector3.DOWN
		for point in [underside, edge, next]:
			kit.fill.set_color(Color(color, 0))
			kit.fill.set_normal(normal)
			kit.fill.add_vertex(point)
			kit.hull.set_normal(normal)
			kit.hull.add_vertex(point)
	# Keep the fine inked hem visible along the fabric edge.
	for seg in segments:
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			var angle: float = TAU*(seg+corner.x)/segments
			var point := _sheet_point(size, 1.0, angle)
			var normal := Vector3(sin(angle), 0, cos(angle))
			kit.fill.set_color(Color(INK, 0))
			kit.fill.set_normal(normal)
			kit.fill.add_vertex(point+normal*.004+Vector3.UP*(1.0-corner.y)*.04)
	kit.hull_used = true

static func _sheet_point(size: Vector3, t: float, angle: float) -> Vector3:
	var end_angle := acos(-pow(.24, 3.5/2.0))
	var radius: float
	var y: float
	if t <= .64:
		var latitude := end_angle*t/.64
		radius = pow(sin(latitude), 2.0/3.5)
		y = MeshKit._signed_pow(cos(latitude), 2.0/3.5)*size.y*.5
	else:
		var fall := (t-.64)/.36
		radius = pow(sin(end_angle), 2.0/3.5)+.10*fall+.025*sin(angle*10)*fall
		y = -size.y*.12-fall*(size.y*.40+.075)+.045*cos(angle*10)*fall*fall
	return Vector3(MeshKit._signed_pow(sin(angle), 2.0/3.5)*size.x*.5*radius, y, MeshKit._signed_pow(cos(angle), 2.0/3.5)*size.z*.5*radius)

## Places flat marks on the front of a superellipsoid, following its curvature.
class Face:
	var kit: MeshKit
	var half: Vector3
	var power: float
	var offset: float = 0.0

	func _init(target: MeshKit, size: Vector3, surface_power: float) -> void:
		kit = target
		half = size*.5
		power = surface_power

	func sample(x: float, y: float) -> Array[Vector3]:
		var k := power
		var rest := 1.0-pow(absf(x/half.x), k)-pow(absf(y/half.y), k)
		var z := half.z*pow(maxf(rest, 0.0), 1.0/k)
		var normal := Vector3(signf(x)*pow(absf(x/half.x), k-1)/half.x, signf(y)*pow(absf(y/half.y), k-1)/half.y, pow(z/half.z, k-1)/half.z).normalized()
		return [Vector3(x, y, z), normal]

	func mark(x: float, y: float, extent: Vector2, color: Color, roll: float, lift: float) -> void:
		var at := sample(x, y)
		var normal := at[1]
		var basis := Basis.looking_at(-normal, Vector3.UP)*Basis(Vector3.BACK, roll)*Basis.from_scale(Vector3(extent.x, extent.y, .03))
		kit.add_transformed("sphere", Transform3D(basis, at[0]+normal*(lift+offset)), color, false)
