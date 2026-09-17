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
	for side in [-1.0, 1.0]:
		kit.add("sphere", Vector3(side*minf(h.x*.5, .32), -h.y-.03, h.z*.4), Vector3(.25, .16, .29), paw)
		if shape.id != "long":
			kit.add("sphere", Vector3(side*(h.x+.045), -h.y*.28, h.z*.15), Vector3(.19, size.y*.3, .23), paw, Vector3(0, 0, side*.2))
	# Belly panels make the animal costumes read as suits, even from a distance.
	if size.y > .8 and style in ["tanuki", "bunny", "fox", "frog", "dino", "shark", "tiger", "dragon", "kappa"]:
		face.mark(0, -h.y*.82, Vector2(size.x*.46, size.y*.14), cream, 0, .018)
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
static func glaze(shape: KinuShape, outfit: KinuOutfit = null, underside: bool = false) -> Node3D:
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
	var headwear := {"hatchling": .2, "nigiri": .13, "onsen": .16, "kappa": .1, "pirate": .02}
	if not underside:
		half.y += float(headwear.get(style, 0.0))
		# Round bodies narrow towards the top, so headwear reaches further past them.
		if headwear.has(style) and shape.roundness < 4.0:
			half += Vector3(.06, .1, .06)
	var sauce := Color("a8612c")
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
		kit.add("sphere", at*1.01, streak[2], Color("d9a36e"), Vector3(0, float(streak[1])+.6, 0), false)
	var node := kit.build(.02, false)
	node.name = "SauceBottom" if underside else "Sauce"
	var gloss := ShaderMaterial.new()
	gloss.shader = MeshKit.TOON
	gloss.set_shader_parameter("shine", .35)
	gloss.set_shader_parameter("rim_strength", .12)
	gloss.set_shader_parameter("shadow_tint", Color(.7, .6, .6))
	(node.get_node("Fill") as MeshInstance3D).material_override = gloss
	return node

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
