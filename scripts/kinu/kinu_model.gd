class_name KinuModel
extends RefCounted
## Builds Kinu: a body mesh (shape + flavour + outfit) and a separate face mesh (shape + mood),
## so changing expression never rebuilds the body.

const INK := Color("2b1a17")
const BLUSH := Color("ff9fb0")
const SWEAT := Color("8fd3ff")
const LEAF := Color("6cc94c")
const OUTLINE_WIDTH := .02
const MOODS := ["calm", "falling", "squish", "happy", "content", "worried"]

const GLASS := preload("res://resources/shaders/toon_glass.gdshader")

static var bodies: Dictionary = {}
static var faces: Dictionary = {}
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
	var root := Node3D.new()
	var key := "%s/%s/%s"%[shape.id, flavour.id, outfit.id if outfit else ""]
	if not bodies.has(key):
		var kit := MeshKit.new()
		_body(kit, shape, flavour, outfit)
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
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.material_override = MeshKit.toon_material()
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(face)
	set_mood(root, shape, mood, flavour.light_face)
	return root

static func set_mood(root: Node3D, shape: KinuShape, mood: String, light_face: bool = false) -> void:
	var key := "%s/%s/%s"%[shape.id, mood, light_face]
	if not faces.has(key):
		var kit := MeshKit.new()
		_face(kit, shape, mood, Color("fff6e2") if light_face else INK)
		faces[key] = kit.commit_fill()
	(root.get_node("Face") as MeshInstance3D).mesh = faces[key]

static func clear_cache() -> void:
	bodies.clear()
	faces.clear()
	materials.clear()

static func _body(kit: MeshKit, shape: KinuShape, flavour: KinuFlavour, outfit: KinuOutfit) -> void:
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
	for s in [-1.0, 1.0]:
		kit.add("sphere", Vector3(s*minf(half.x*.45, .3), -half.y-.02, half.z*.35), Vector3(.22, .12, .24), c.darkened(.06))
		if shape.id != "long":
			kit.add("sphere", Vector3(s*(half.x+.02), -half.y*.15, half.z*.2), Vector3(.14, .22, .16), c.darkened(.04), Vector3(0, 0, s*.4))
	if outfit:
		_outfit(kit, outfit, shape)

static func _face(kit: MeshKit, shape: KinuShape, mood: String, ink: Color = INK) -> void:
	var face := Face.new(kit, shape.size, shape.roundness)
	var half := shape.size*.5
	var y := half.y*.35 if shape.id == "tall" else 0.0
	var x := 0.0
	for s in [-1.0, 1.0]:
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
		if mood == "worried":
			face.mark(eye+s*.01, y+.17, Vector2(.11, .026), ink, s*-.45, .004)
		var blush := Color("ff8aa3") if mood in ["happy", "squish", "falling"] else BLUSH
		face.mark(x+s*minf(half.x*.62, .33), y-.07, Vector2(.18, .09), blush, 0, -.004)
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

## Hood = a cap over the top plus a back panel, so it wraps like a real onesie and leaves the face showing.
static func _outfit(kit: MeshKit, outfit: KinuOutfit, shape: KinuShape) -> void:
	var size := shape.size
	var half := size*.5
	var power := shape.roundness
	var hood := outfit.hood_color
	var top := half.y+size.y*.08
	if outfit.style != "leaf":
		kit.add_rounded_box(Vector3(0, half.y*.62, -size.z*.02), Vector3(size.x*1.07, size.y*.46, size.z*1.08), hood, Vector3.ZERO, true, power)
		kit.add_rounded_box(Vector3(0, -half.y*.05, -half.z*.55), Vector3(size.x*1.07, size.y*.98, size.z*.5), hood, Vector3.ZERO, true, power)
	match outfit.style:
		"leaf":
			kit.add("cylinder", Vector3(half.x*-.3, half.y+.1, 0), Vector3(.03, .2, .03), Color("4d9a2c"))
			kit.add("sphere", Vector3(half.x*-.3+.1, half.y+.2, 0), Vector3(.26, .06, .15), LEAF, Vector3(0, .4, .35))
		"tanuki":
			for s in [-1.0, 1.0]:
				kit.add("sphere", Vector3(s*half.x*.6, top, 0), Vector3(.26, .24, .16), Color("6b4430"))
			kit.add("sphere", Vector3(.05, top+.08, 0), Vector3(.32, .08, .2), LEAF, Vector3(0, .3, .3))
			for i in 3:
				kit.add("sphere", Vector3(half.x*.6+i*.1, -half.y*.2+i*.08, -half.z-.12), Vector3(.3, .26, .26)*(1.0-i*.12), Color("6b4430") if i % 2 else hood)
		"bunny":
			for s in [-1.0, 1.0]:
				kit.add("sphere", Vector3(s*half.x*.42, top+.28, -.05), Vector3(.24, .62, .16), hood, Vector3(-.2, 0, s*-.25))
				kit.add("sphere", Vector3(s*half.x*.42, top+.28, .02), Vector3(.12, .44, .06), Color("ff8fb0"), Vector3(-.2, 0, s*-.25), false)
		"bat":
			for s in [-1.0, 1.0]:
				kit.add("cone", Vector3(s*half.x*.5, top+.12, 0), Vector3(.28, .34, .18), hood, Vector3(0, 0, s*-.35))
				kit.add("sphere", Vector3(s*(half.x+.32), .05, -.1), Vector3(.55, .36, .08), hood.lightened(.2), Vector3(0, s*.3, s*-.4))
		"fox":
			for s in [-1.0, 1.0]:
				kit.add("cone", Vector3(s*.24, top+.12, 0), Vector3(.26, .34, .18), hood, Vector3(0, 0, s*-.3))
			kit.add("sphere", Vector3(half.x+.25, .05, -.15), Vector3(.7, .4, .4), hood, Vector3(0, .4, .5))
			kit.add("sphere", Vector3(half.x+.55, .22, -.3), Vector3(.28, .24, .24), Color("fff6ea"), Vector3(0, .4, .5))
		"frog":
			for s in [-1.0, 1.0]:
				kit.add("sphere", Vector3(s*half.x*.45, top+.05, .05), Vector3(.32, .3, .3), hood)
				kit.add("sphere", Vector3(s*half.x*.45, top+.08, .19), Vector3(.12, .14, .06), INK, Vector3.ZERO, false)

## Places flat marks on the front of a superellipsoid, following its curvature.
class Face:
	var kit: MeshKit
	var half: Vector3
	var power: float

	func _init(target: MeshKit, size: Vector3, surface_power: float) -> void:
		kit = target
		half = size*.5
		power = surface_power

	func mark(x: float, y: float, extent: Vector2, color: Color, roll: float, lift: float) -> void:
		var k := power
		var rest := 1.0-pow(absf(x/half.x), k)-pow(absf(y/half.y), k)
		var z := half.z*pow(maxf(rest, 0.0), 1.0/k)
		var normal := Vector3(signf(x)*pow(absf(x/half.x), k-1)/half.x, signf(y)*pow(absf(y/half.y), k-1)/half.y, pow(z/half.z, k-1)/half.z).normalized()
		var basis := Basis.looking_at(-normal, Vector3.UP)*Basis(Vector3.BACK, roll)*Basis.from_scale(Vector3(extent.x, extent.y, .03))
		kit.add_transformed("sphere", Transform3D(basis, Vector3(x, y, z)+normal*lift), color, false)
