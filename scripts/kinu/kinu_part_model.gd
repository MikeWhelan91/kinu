class_name KinuPartModel
extends RefCounted
## Builds My Kinu's parts (body garment, hat, arms, glasses) onto a MeshKit for one shape.
## Every part fits all five shapes from shape.size, the way costumes do, and nothing here touches
## the body's hitbox: parts are drawn only. Garments stop below the expression and glasses sit
## around the eyes, so the flavour and every mood stay readable.

const CREAM := Color("fff4df")
const GOLD := Color("f5c14e")
const INK := Color("2b1a17")
const LEAF := Color("6cc94c")

## Styles whose arms take the Kinu's own colour; their meshes are cached per flavour too.
const BASE_COLOURED := ["nubs", "mittens", "gloves", "wave", "balloon", "boxing", "pompoms", "wand", "sparkler", "flag", "lantern", "lollipop", "maracas"]

static func uses_base_colour(parts: Array) -> bool:
	for part in parts:
		if part.slot == "arms" and part.style in BASE_COLOURED:
			return true
	return false

static func build(kit: MeshKit, shape: KinuShape, parts: Array, base_colour: Color) -> void:
	for part in parts:
		match part.slot:
			"body":
				_body(kit, shape, part)
			"hat":
				_hat(kit, shape, part)
			"arms":
				_arms(kit, shape, part, base_colour.darkened(.04))
			"glasses":
				_glasses(kit, shape, part)

# ---------- Shared measurements ----------

static func _eye_y(shape: KinuShape) -> float:
	return shape.size.y*.5*.35 if shape.id == "tall" else 0.0

## The lowest line the expression reaches (the blush), with a little clearance.
static func _waist(shape: KinuShape) -> float:
	return minf(-shape.size.y*.5*.26, _eye_y(shape)-.16)

## Hats scale with the narrowest top the shape offers.
static func _hat_width(shape: KinuShape) -> float:
	return clampf(minf(shape.size.x, shape.size.z)*.6, .4, .66)

static func _hat_scale(shape: KinuShape) -> float:
	return clampf(minf(minf(shape.size.x, shape.size.z), shape.size.y*1.3), .55, 1.0)

static func _spow(value: float, exponent: float) -> float:
	return signf(value)*pow(absf(value), exponent)

## A strip of the body's own superellipsoid, grown by `grow`, from `bottom` up to `top` (body-local
## heights). Leaving bottom at -INF closes it underneath. It follows every shape's curve, so a
## garment wraps a ball as snugly as a block.
static func _band(kit: MeshKit, shape: KinuShape, top: float, grow: float, color: Color, bottom: float = -INF, outline: bool = true, shoulder_lift: float = 0.0, lift_bottom: bool = false) -> void:
	var a := shape.size*.5*grow
	var k := shape.roundness
	var rows := 10
	var segments := 40
	var points: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for j in rows+1:
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for i in segments:
			var t := TAU*i/segments
			# A low neckline at the face rises over the sides and back like clothing
			# resting on shoulders. A level top makes Kinu look planted in a bowl.
			var lift := shoulder_lift*pow((1.0-sin(t))*.5, .7)
			var phi_top := asin(clampf(_spow(clampf((top+lift)/a.y, -1, 1), k*.5), -1, 1))
			var phi_bottom := -PI*.5 if bottom == -INF else asin(clampf(_spow(clampf((bottom+(lift if lift_bottom else 0.0))/a.y, -1, 1), k*.5), -1, 1))
			var phi := lerpf(phi_bottom, phi_top, float(j)/rows)
			var u := Vector3(cos(phi)*cos(t), sin(phi), cos(phi)*sin(t))
			var p := Vector3(_spow(u.x, 2.0/k), _spow(u.y, 2.0/k), _spow(u.z, 2.0/k))
			ring.append(p*a)
			ring_normals.append(Vector3(_spow(p.x, k-1)/a.x, _spow(p.y, k-1)/a.y, _spow(p.z, k-1)/a.z).normalized())
		points.append(ring)
		normals.append(ring_normals)
	for j in rows:
		for i in segments:
			var n := (i+1) % segments
			_triangle(kit, [points[j][i], points[j+1][i], points[j+1][n]], [normals[j][i], normals[j+1][i], normals[j+1][n]], color, outline)
			_triangle(kit, [points[j][i], points[j+1][n], points[j][n]], [normals[j][i], normals[j+1][n], normals[j][n]], color, outline)
	kit.hull_used = kit.hull_used or outline

## Front faces in MeshKit's primitives wind so that (b-a)x(c-a) points into the surface.
static func _triangle(kit: MeshKit, corners: Array, corner_normals: Array, color: Color, outline: bool) -> void:
	var face_normal: Vector3 = corner_normals[0]+corner_normals[1]+corner_normals[2]
	var cross: Vector3 = (corners[1]-corners[0]).cross(corners[2]-corners[0])
	if cross.length_squared() < 1e-12:
		return
	var order := [0, 1, 2] if cross.dot(face_normal) < 0 else [0, 2, 1]
	for index in order:
		kit.fill.set_color(Color(color, 0.0))
		kit.fill.set_normal(corner_normals[index])
		kit.fill.add_vertex(corners[index])
		if outline:
			kit.hull.set_normal(corner_normals[index])
			kit.hull.add_vertex(corners[index])

## A thin cuff round the body at height y.
static func _ring(kit: MeshKit, shape: KinuShape, y: float, thickness: float, grow: float, color: Color, shoulder_lift: float = 0.0) -> void:
	_band(kit, shape, y+thickness*.5, grow, color, y-thickness*.5, true, shoulder_lift, true)

## The front surface point and its outward normal at (x, y) on the body grown by `grow`.
static func _front(shape: KinuShape, x: float, y: float, grow: float = 1.0) -> Array[Vector3]:
	return KinuModel.Face.new(null, shape.size*grow, shape.roundness).sample(x, y)

## Where the body's sides are at height y, along x and z.
static func _reach(shape: KinuShape, y: float) -> Vector2:
	var h := shape.size*.5
	var k := shape.roundness
	var across := pow(maxf(1.0-pow(absf(y/h.y), k), 0.0), 1.0/k)
	return Vector2(h.x, h.z)*across

# ---------- Body ----------

static func _body(kit: MeshKit, shape: KinuShape, part: KinuPart) -> void:
	var h := shape.size*.5
	var waist := _waist(shape)
	var hem := -h.y
	var short_hem := hem+minf(.09, (waist-hem)*.25)
	var shoulders := minf(h.y*.6, .32)
	var face := KinuModel.Face.new(kit, shape.size*1.05, shape.roundness)
	var c := part.color
	var accent := part.accent
	match part.style:
		"tee", "stripes", "raincoat", "varsity", "patchwork":
			var garment_hem := hem if part.style == "raincoat" else short_hem
			_band(kit, shape, waist, 1.035, c, garment_hem, true, shoulders)
			_ring(kit, shape, waist, .055, 1.055, accent if part.style in ["tee", "varsity", "raincoat"] else c.darkened(.08), shoulders)
			if part.style == "tee":
				_ring(kit, shape, garment_hem+.015, .045, 1.055, accent)
				# A small chest pocket makes the starter shirt read as clothing on every shape.
				var pocket_y := lerpf(garment_hem, waist, .48)
				var pocket := _front(shape, -minf(h.x*.34, .21), pocket_y, 1.065)
				kit.add_rounded_box(pocket[0]+pocket[1]*.025, Vector3(.11, minf(.1,(waist-garment_hem)*.34), .018), c.lightened(.13), Basis.looking_at(-pocket[1],Vector3.UP).get_euler(), false, 3)
			if part.style == "stripes":
				for i in 3:
					_ring(kit, shape, lerpf(garment_hem+.035, waist, (i+1)/4.0), .04, 1.055, accent)
				_ring(kit, shape, garment_hem+.015, .04, 1.055, accent)
			if part.style == "raincoat":
				_ring(kit, shape, hem*.9, .06, 1.08, accent)
				var seam := _front(shape, 0, lerpf(hem, waist, .52), 1.07)
				kit.add_rounded_box(seam[0]+seam[1]*.028, Vector3(.025, (waist-hem)*.82, .015), accent, Basis.looking_at(-seam[1], Vector3.UP).get_euler(), false, 3)
				for i in 2:
					var button_at := _front(shape, .065, lerpf(hem, waist, .3+i*.32), 1.08)
					kit.add("bead", button_at[0]+button_at[1]*.025, Vector3.ONE*.045, accent, Vector3.ZERO, false)
			if part.style == "varsity":
				_ring(kit, shape, garment_hem+.015, .045, 1.055, accent)
				var patch := _front(shape, -minf(h.x*.3,.16), lerpf(garment_hem,waist,.52), 1.07)
				kit.add("bead", patch[0]+patch[1]*.03, Vector3(.105,.105,.025), accent, Vector3.ZERO, false)
			if part.style == "patchwork":
				for side in [-1.0,1.0]:
					var patch_y := lerpf(garment_hem,waist,.35 if side < 0 else .65)
					var patch := _front(shape,side*minf(h.x*.35,.21),patch_y,1.07)
					kit.add_rounded_box(patch[0]+patch[1]*.025, Vector3(.14,minf(.14,(waist-garment_hem)*.3),.018), accent if side < 0 else c.lightened(.2), Basis.looking_at(-patch[1],Vector3.UP).get_euler(), false, 3)
			_sleeves(kit, shape, c)
		"vest":
			_band(kit, shape, waist, 1.035, c, short_hem, true, shoulders)
			_ring(kit, shape, waist, .04, 1.055, accent, shoulders)
			_ring(kit, shape, short_hem+.015, .045, 1.055, accent)
			_arm_loops(kit, shape, waist, c)
			# Cream V lapels, a centre opening and buttons distinguish this
			# sleeveless waistcoat from the sleeved varsity cardigan.
			for side in [-1.0, 1.0]:
				face.mark(side*minf(h.x*.31,.16), waist-.055, Vector2(minf(.24,h.x*.35), .05), accent, side*-.72, .03)
			face.mark(0, lerpf(short_hem, waist, .52), Vector2(.025, waist-short_hem), c.darkened(.22), 0, .03)
			for i in 2:
				face.mark(.055, lerpf(short_hem, waist, .3+i*.3), Vector2(.045,.045), accent, 0, .04)
		"scarf":
			_ring(kit, shape, waist+.02, .1, 1.1, c)
			_ring(kit, shape, waist+.02, .025, 1.13, accent)
			var at := _front(shape, minf(h.x*.45, .3), waist-.08, 1.12)
			var tail := Vector3(.14, minf(.26, h.y*.9), .045)
			kit.add_rounded_box(at[0]+at[1]*.03, tail, c, Vector3(0, 0, .18), true, 4)
			for i in 3:
				kit.add_rounded_box(at[0]+at[1]*.035+Vector3(-.04+i*.04, -tail.y*.5-.02, 0), Vector3(.025, .05, .03), accent, Vector3.ZERO, false, 3)
		"bowtie":
			# The mouth sits just above the waist line; keep the bow below it on every shape.
			var at := _front(shape, 0, maxf(waist-.12,-h.y*.82), 1.04)
			var knot := at[0]+at[1]*.04
			for side in [-1.0, 1.0]:
				kit.add("sphere", knot+Vector3(side*.085, 0, -.01), Vector3(.16, .12, .07), c, Vector3(0, 0, side*.35))
			kit.add("sphere", knot+at[1]*.02, Vector3(.07, .07, .06), accent)
		"apron":
			var mid := (waist+hem)*.5+.01
			var at := _front(shape, 0, mid, 1.05)
			var facing := Basis.looking_at(-at[1], Vector3.UP)
			var panel := Vector3(minf(shape.size.x*.62, .66), waist-hem+.02, .035)
			kit.add_rounded_box(at[0]+at[1]*.01, panel, c, facing.get_euler(), true, 4)
			kit.add_rounded_box(at[0]+at[1]*.035+Vector3(0, -panel.y*.12, 0), Vector3(panel.x*.45, panel.y*.32, .02), accent, facing.get_euler(), false, 4)
			_ring(kit, shape, waist, .05, 1.07, accent)
			var back := Vector3(0, waist, -_reach(shape, waist).y*1.07-.03)
			for side in [-1.0, 1.0]:
				kit.add("sphere", back+Vector3(side*.07, 0, 0), Vector3(.13, .08, .05), accent, Vector3(0, 0, side*.4))
		"hoodie":
			_band(kit, shape, waist, 1.035, c, short_hem, true, shoulders)
			_ring(kit, shape, waist+.01, .1, 1.065, c.lightened(.08), shoulders)
			_ring(kit, shape, short_hem+.015, .05, 1.055, accent)
			face.mark(0, (waist+short_hem)*.5-.02, Vector2(minf(shape.size.x*.42, .42), (waist-short_hem)*.38), accent, 0, .03)
			var at := _front(shape, 0, waist-.04, 1.1)
			for side in [-1.0, 1.0]:
				kit.add("cylinder", at[0]+at[1]*.02+Vector3(side*.07, -.06, 0), Vector3(.022, .13, .022), CREAM, Vector3.ZERO, false)
			_sleeves(kit, shape, c)
		"dungarees":
			_band(kit, shape, waist, 1.035, c, -INF, true, shoulders)
			_ring(kit, shape, waist, .055, 1.055, c.darkened(.15), shoulders)
			_arm_loops(kit, shape, waist, c)
			face.mark(0, (waist+hem)*.5, Vector2(minf(shape.size.x*.3, .3), (waist-hem)*.42), c.darkened(.12), 0, .03)
			for side in [-1.0, 1.0]:
				var x: float = side*(minf(h.x*.7, .7) if shape.id == "long" else minf(h.x*.82, .43))
				var strap_height := minf(.24, shape.size.y*.2)
				face.mark(x, waist+strap_height*.35, Vector2(.085, strap_height), c, 0, .01)
				face.mark(x, waist+.015, Vector2(.055, .055), accent, 0, .03)
		"kimono":
			_band(kit, shape, waist, 1.035, c, -INF, true, shoulders)
			_ring(kit, shape, waist, .045, 1.055, accent, shoulders)
			for side in [-1.0, 1.0]:
				face.mark(side*.07, waist-.07, Vector2(minf(.34, shape.size.x*.3), .05), accent, side*-.75, .025)
			_ring(kit, shape, lerpf(hem, waist, .42), minf(.14, (waist-hem)*.4), 1.08, accent)
			kit.add("sphere", Vector3(0, lerpf(hem, waist, .42), -_reach(shape, lerpf(hem, waist, .42)).y*1.08-.05), Vector3(.22, .14, .1), accent)
			_sleeves(kit, shape, c)
		"sweater":
			_band(kit, shape, waist, 1.035, c, short_hem, true, shoulders)
			_ring(kit, shape, waist, .06, 1.055, accent, shoulders)
			_ring(kit, shape, short_hem+.015, .05, 1.055, accent)
			var row := lerpf(short_hem, waist, .55)
			var count := clampi(int(shape.size.x/.12), 5, 13)
			for i in count:
				var x := lerpf(-h.x*.75, h.x*.75, float(i)/(count-1))
				face.mark(x, row, Vector2(.08, .025), accent, .7 if i % 2 else -.7, .02)
			_sleeves(kit, shape, c)
		"tutu":
			_band(kit, shape, waist, 1.035, c.lightened(.12))
			_ring(kit, shape, waist-.02, .06, 1.08, accent)
			_tutu_skirt(kit, shape, waist, c, accent)
		"swim_ring":
			var y := lerpf(hem, waist, .7)
			var reach := _reach(shape, y)+Vector2(.08, .08)
			var k := shape.roundness
			var beads := 48
			for i in beads:
				var t := TAU*i/beads
				var at := Vector3(_spow(cos(t), 2.0/k)*reach.x, y, _spow(sin(t), 2.0/k)*reach.y)
				kit.add("bead", at, Vector3(.2, .17, .2), c if (i*6/beads) % 2 == 0 else accent, Vector3.ZERO, false)
			_ring(kit, shape, y, .17, 1.0+.16/minf(shape.size.x, shape.size.z), c)

## Short sleeves over the body's own little side arms (Long has none).
static func _sleeves(kit: MeshKit, shape: KinuShape, color: Color) -> void:
	if shape.id == "long":
		return
	var h := shape.size*.5
	for side in [-1.0, 1.0]:
		kit.add("sphere", Vector3(side*(h.x+.025), -h.y*.035, h.z*.2), Vector3(.21, .21, .2), color, Vector3(0, 0, side*.4))

## Dungarees need a visible opening around each arm rather than a straight waistband
## cutting across the arm. The lower half sinks into the garment, leaving a cloth arch.
static func _arm_loops(kit: MeshKit, shape: KinuShape, waist: float, color: Color) -> void:
	if shape.id == "long":
		return
	var h := shape.size*.5
	for side in [-1.0, 1.0]:
		var center := Vector3(side*(h.x+.025), waist+.015, minf(h.z*.2, .12))
		var across := .17
		var rise := minf(.17, h.y*.4)
		var thickness := minf(.045, shape.size.y*.055)
		var segments := 24
		var sides := 8
		for i in segments:
			var a0 := TAU*float(i)/segments
			var a1 := TAU*float(i+1)/segments
			for j in sides:
				var b0 := TAU*float(j)/sides
				var b1 := TAU*float(j+1)/sides
				var corners: Array = []
				var normals: Array = []
				for angles in [Vector2(a0,b0), Vector2(a1,b0), Vector2(a1,b1), Vector2(a0,b1)]:
					var radial := Vector3(0, sin(angles.x), cos(angles.x))
					var normal := Vector3(cos(angles.y), 0, 0)+radial*sin(angles.y)
					corners.append(center+Vector3(0, radial.y*rise, radial.z*across)+normal*thickness)
					normals.append(normal.normalized())
				_triangle(kit, [corners[0], corners[1], corners[2]], [normals[0], normals[1], normals[2]], color, true)
				_triangle(kit, [corners[0], corners[2], corners[3]], [normals[0], normals[2], normals[3]], color, true)

## A flared, pleated skirt with a scalloped tulle edge. The shape follows Kinu's
## waist but opens out from it, so it reads as a tutu rather than a straight band.
static func _tutu_skirt(kit: MeshKit, shape: KinuShape, waist: float, color: Color, accent: Color) -> void:
	var reach := _reach(shape, waist)
	var h := shape.size*.5
	var outer := minf(1.35, minf((h.x+.31)/maxf(reach.x,.01), (h.z+.24)/maxf(reach.y,.01)))
	var drop := minf(.17, (waist+shape.size.y*.5)*.75)
	var segments := 48
	var rows := 4
	for j in rows:
		for i in segments:
			var corners: Array = []
			var normals: Array = []
			for pair: Vector2 in [Vector2(i,j),Vector2(i+1,j),Vector2(i+1,j+1),Vector2(i,j+1)]:
				var t: float = TAU*pair.x/segments
				var u: float = pair.y/rows
				var flare := 1.07+(outer-1.07)*pow(u,.8)
				var wave: float = sin(t*12.0)*.018*u
				var radial := Vector3(_spow(cos(t), 2.0/shape.roundness), 0, _spow(sin(t), 2.0/shape.roundness))
				corners.append(Vector3(radial.x*reach.x*flare, waist-.035-drop*u+wave, radial.z*reach.y*flare))
				normals.append(Vector3(radial.x,.45,radial.z).normalized())
			var tone := color.lightened(.12) if int(i/4)%2 == 0 else color
			_triangle(kit, [corners[0],corners[1],corners[2]], [normals[0],normals[1],normals[2]], tone, true)
			_triangle(kit, [corners[0],corners[2],corners[3]], [normals[0],normals[2],normals[3]], tone, true)
	for i in 24:
		var t := TAU*i/24
		var radial := Vector3(_spow(cos(t), 2.0/shape.roundness), 0, _spow(sin(t), 2.0/shape.roundness))
		var edge := Vector3(radial.x*reach.x*outer, waist-.035-drop+sin(t*12.0)*.018, radial.z*reach.y*outer)
		kit.add("sphere", edge, Vector3(.09,.045,.09), accent if i%2 == 0 else color.lightened(.18), Vector3.ZERO, false)

# ---------- Hats ----------

static func _hat(kit: MeshKit, shape: KinuShape, part: KinuPart) -> void:
	var h := shape.size*.5
	var w := _hat_width(shape)
	var s := _hat_scale(shape)
	var y := h.y-.02
	var c := part.color
	var accent := part.accent
	match part.style:
		"beanie":
			kit.add("dome", Vector3(0, y-.02, 0), Vector3(w, w*.9, w)*1.02, c)
			kit.add("cylinder", Vector3(0, y+.01, 0), Vector3(w*1.04, .08, w*1.04), accent)
			kit.add("sphere", Vector3(0, y+w*.45, 0), Vector3.ONE*.15*s, accent)
		"cap":
			kit.add("dome", Vector3(0, y-.02, 0), Vector3(w, w*.75, w), c)
			kit.add("cylinder", Vector3(0, y+.005, w*.42), Vector3(w*.85, .025, w*.75), accent)
			kit.add("sphere", Vector3(0, y+w*.37, 0), Vector3.ONE*.06, accent, Vector3.ZERO, false)
		"beret":
			kit.add("sphere", Vector3(-w*.08, y+.04, 0), Vector3(w*1.25, .12*s+.02, w*1.15), c, Vector3(0, 0, .18))
			kit.add("cylinder", Vector3(-w*.06, y+.12, 0), Vector3(.03, .07, .03), accent)
		"party":
			kit.add("cone", Vector3(w*.1, y+.21*s, 0), Vector3(w*.7, .44*s, w*.7), c, Vector3(0, 0, -.15))
			for i in 2:
				kit.add("cylinder", Vector3(w*.1-i*.03, y+.06+i*.13*s, 0), Vector3(w*(.62-i*.22), .03, w*(.62-i*.22)), accent, Vector3(0, 0, -.15), false)
			kit.add("sphere", Vector3(w*.1+.06*s, y+.43*s, 0), Vector3.ONE*.11*s, accent)
		"bow":
			var at := Vector3(h.x*.35 if shape.size.x > 1.2 else w*.3, y+.06, 0)
			for side in [-1.0, 1.0]:
				kit.add("sphere", at+Vector3(side*.11*s, .02, 0), Vector3(.2, .14, .1)*s, c, Vector3(0, 0, side*.45))
			kit.add("sphere", at+Vector3(0, .02, .01), Vector3(.08, .08, .08)*s, accent)
		"bucket":
			kit.add("cylinder", Vector3(0, y+.03, 0), Vector3(w*1.35, .03, w*1.35), accent, Vector3(.06, 0, 0))
			kit.add("cylinder", Vector3(0, y+.12*s, 0), Vector3(w*.9, .2*s, w*.9), c)
			kit.add("dome", Vector3(0, y+.22*s, 0), Vector3(w*.9, .12, w*.9), c)
		"top_hat":
			kit.add("cylinder", Vector3(0, y+.015, 0), Vector3(w*1.2, .035, w*1.2), c)
			kit.add("cylinder", Vector3(0, y+.2*s, 0), Vector3(w*.72, .38*s, w*.72), c)
			kit.add("cylinder", Vector3(0, y+.08*s, 0), Vector3(w*.74, .07*s, w*.74), accent, Vector3.ZERO, false)
		"chef":
			kit.add("cylinder", Vector3(0, y+.08*s, 0), Vector3(w*.78, .17*s, w*.78), accent)
			for i in 5:
				var a := TAU*i/5
				kit.add("sphere", Vector3(sin(a)*w*.24, y+.24*s, cos(a)*w*.24), Vector3.ONE*w*.5, c)
			kit.add("sphere", Vector3(0, y+.31*s, 0), Vector3.ONE*w*.55, c)
		"flower_crown":
			var top := h.y*.9
			var reach := _reach(shape, top)*.92
			var k := shape.roundness
			# Multiples of four place blossoms at the centre of both the front
			# and back, closing the garland instead of leaving two side clusters.
			var count := clampi(int(ceil((reach.x+reach.y)*2.5))*4, 12, 20)
			_ring(kit, shape, top, .05, 1.03, c)
			for i in count:
				var t := TAU*i/count
				var at := Vector3(_spow(cos(t), 2.0/k)*reach.x, top+.05, _spow(sin(t), 2.0/k)*reach.y)
				for p in 5:
					var petal := TAU*p/5
					kit.add("bead", at+Vector3(cos(petal)*.048, .02, sin(petal)*.048), Vector3(.085, .055, .085), accent if i % 2 == 0 else Color("fff4df"), Vector3.ZERO, true)
				kit.add("bead", at+Vector3(0, .045, 0), Vector3.ONE*.06, Color("ffd34f"), Vector3.ZERO, false)
		"straw":
			kit.add("cylinder", Vector3(0, y+.015, 0), Vector3(w*1.6, .03, w*1.6), c)
			kit.add("dome", Vector3(0, y+.02, 0), Vector3(w*.8, w*.75, w*.8), c)
			kit.add("cylinder", Vector3(0, y+.05, 0), Vector3(w*.82, .06, w*.82), accent, Vector3.ZERO, false)
		"witch":
			kit.add("cylinder", Vector3(0, y+.015, 0), Vector3(w*1.4, .03, w*1.4), c)
			kit.add("cone", Vector3(0, y+.29*s, -.03), Vector3(w*.8, .56*s, w*.8), c, Vector3(-.18, 0, .1))
			kit.add("cylinder", Vector3(0, y+.06, 0), Vector3(w*.74, .06, w*.74), accent.darkened(.4), Vector3.ZERO, false)
			kit.add_rounded_box(Vector3(0, y+.06, w*.37), Vector3(.08, .06, .02), accent, Vector3.ZERO, false, 4)
		"crown":
			kit.add("cylinder", Vector3(0, y+.07*s, 0), Vector3(w*.8, .14*s, w*.8), c)
			for i in 6:
				var a := TAU*i/6
				kit.add("cone", Vector3(sin(a)*w*.34, y+.19*s, cos(a)*w*.34), Vector3(.1, .14, .1)*s, c)
				kit.add("bead", Vector3(sin(a)*w*.41, y+.07*s, cos(a)*w*.41), Vector3.ONE*.06*s, accent, Vector3.ZERO, false)
		"halo":
			kit.add("torus", Vector3(0, y+.22*s, 0), Vector3(w*.9, w*.9, w*.9), c)
		"sprout":
			kit.add("cylinder", Vector3(0, y+.09*s, 0), Vector3(.035, .18*s, .035), accent)
			for i in 4:
				var a := TAU*i/4+.4
				for lobe in [-1.0, 1.0]:
					var leaf: Vector3 = (Vector3(sin(a)*.1, 0, cos(a)*.1)+Vector3(cos(a), 0, -sin(a))*float(lobe)*.035)*s+Vector3(0, y+.2*s, 0)
					kit.add("sphere", leaf, Vector3(.13, .05, .13)*s, c, Vector3(0, a, .3))
		"bunny_band", "cat_band":
			# The band arches over the head along its own curve, so it hugs a ball as well as a block.
			_arch(kit, shape, h.y*.2, 1.04, .055, c)
			for side in [-1.0, 1.0]:
				var ear_x: float = side*w*.38
				var ear := Vector3(ear_x, _surface_y(shape, ear_x, 1.04)-.01, 0)
				if part.style == "bunny_band":
					kit.add("sphere", ear+Vector3(0, .24*s, 0), Vector3(.17, .5, .1)*s, c, Vector3(0, 0, side*-.15))
					kit.add("sphere", ear+Vector3(0, .24*s, .03), Vector3(.09, .36, .05)*s, accent, Vector3(0, 0, side*-.15), false)
				else:
					kit.add("cone", ear+Vector3(0, .1*s, 0), Vector3(.24, .22, .1)*s, c, Vector3(0, 0, side*-.2))
					kit.add("cone", ear+Vector3(0, .09*s, .03), Vector3(.13, .13, .05)*s, accent, Vector3(0, 0, side*-.2), false)
		"propeller":
			kit.add("dome", Vector3(0, y-.02, 0), Vector3(w, w*.7, w), c)
			kit.add("cylinder", Vector3(0, y+.005, w*.42), Vector3(w*.8, .025, w*.7), accent)
			kit.add("cylinder", Vector3(0, y+w*.38, 0), Vector3(.03, .1, .03), INK)
			for side in [-1.0, 1.0]:
				kit.add("sphere", Vector3(side*.13, y+w*.38+.05, 0), Vector3(.24, .025, .08), accent if side > 0 else Color("ffe36e"), Vector3(0, .3, 0))
		"mushroom":
			kit.add("dome", Vector3(0,y+.04,0), Vector3(w*1.3,.34*s,w*1.3), c)
			kit.add("cylinder",Vector3(0,y+.01,0),Vector3(w*1.37,.045,w*1.37),c)
			for i in 5:
				var a := TAU*i/5
				kit.add("sphere",Vector3(sin(a)*w*.46,y+.15*s,cos(a)*w*.46),Vector3(.075,.022,.06)*s,accent,Vector3.ZERO,false)
		"headphones":
			var ear_y := h.y*.55
			var ear_x := _reach(shape,ear_y).x
			# One continuous band arching over the head from cup to cup, just clear of the surface.
			_arch(kit, shape, ear_y, 1.1, .065, c)
			for side in [-1.0,1.0]:
				kit.add_rounded_box(Vector3(side*(ear_x+.03),ear_y,0),Vector3(.12,.23,.2)*s,accent,Vector3.ZERO,true,4)
				kit.add_rounded_box(Vector3(side*(ear_x+.09),ear_y,0),Vector3(.035,.12,.13)*s,c,Vector3.ZERO,false,3)

## Height of the shape's top surface (grown by `grow`) above x, in the front-to-back middle.
static func _surface_y(shape: KinuShape, x: float, grow: float = 1.0) -> float:
	var a := shape.size*.5*grow
	var k := shape.roundness
	return a.y*pow(maxf(1.0-pow(absf(x/a.x), k), 0.0), 1.0/k)

## A band arching over the head from one side at height `from_y` to the other, following the
## shape's own outline (grown by `grow`) so it sits snugly on every Kinu shape.
static func _arch(kit: MeshKit, shape: KinuShape, from_y: float, grow: float, thickness: float, color: Color) -> void:
	var a := shape.size*.5*grow
	var k := shape.roundness
	var start := asin(clampf(_spow(clampf(from_y/a.y, -1, 1), k*.5), -1, 1))
	var points: Array[Vector3] = []
	var steps := 40
	for i in steps+1:
		var t := lerpf(start, PI-start, float(i)/steps)
		points.append(Vector3(_spow(cos(t), 2.0/k)*a.x, _spow(sin(t), 2.0/k)*a.y, 0))
	for i in steps:
		var from := points[i]
		var to := points[i+1]
		var length := from.distance_to(to)
		if length < .0001:
			continue
		var up := (to-from)/length
		var side := up.cross(Vector3.BACK).normalized()
		var basis := Basis(side, up, side.cross(up)).orthonormalized()*Basis.from_scale(Vector3(thickness, length+thickness*.6, thickness))
		kit.add_transformed("cylinder", Transform3D(basis, (from+to)*.5), color)

# ---------- Arms ----------

static func _arms(kit: MeshKit, shape: KinuShape, part: KinuPart, skin: Color) -> void:
	var h := shape.size*.5
	var reach := clampf(shape.size.y*.32, .16, .3)
	var c := part.color
	var accent := part.accent
	if part.style == "wings":
		var wing_width := clampf(shape.size.x*.72, .54, 1.32)
		var wing_height := clampf(shape.size.y*.78, .38, .95)
		var root_x := minf(h.x*.22, .18)
		var root_y := minf(h.y*.14, .11)
		var back_z := -_reach(shape, root_y).y*1.04-.045
		for side in [-1.0, 1.0]:
			var root := Vector3(side*root_x, root_y, back_z)
			# The fan grows across the back from a close-set shoulder root.
			# Only the outer feather tips show when Kinu faces forward.
			kit.add("sphere", root+Vector3(side*wing_width*.16, wing_height*.08, 0),
				Vector3(wing_width*.35, wing_height*.28, .13), c, Vector3(0, 0, -side*.35))
			kit.add("sphere", root+Vector3(side*wing_width*.36, wing_height*.32, -.025),
				Vector3(wing_width*.36, wing_height*.72, .13), c, Vector3(0, 0, -side*.65))
			kit.add("sphere", root+Vector3(side*wing_width*.55, wing_height*.12, -.045),
				Vector3(wing_width*.38, wing_height*.58, .12), c, Vector3(0, 0, -side*1.05))
			kit.add("sphere", root+Vector3(side*wing_width*.48, -wing_height*.12, -.06),
				Vector3(wing_width*.32, wing_height*.47, .11), c, Vector3(0, 0, -side*1.35))
			kit.add("sphere", root+Vector3(side*wing_width*.29, wing_height*.14, -.105),
				Vector3(wing_width*.12, wing_height*.37, .025), accent, Vector3(0, 0, -side*.68), false)
		return
	for side in [-1.0, 1.0]:
		var raised: bool = (part.style == "wave" and side > 0) or (part.style in ["pompoms", "sparkler"])
		var tilt: float = side*(-.5 if raised else .55)
		var shoulder := Vector3(side*(h.x-.02), -h.y*.1, minf(h.z*.2, .12))
		var direction := Vector3(side*sin(absf(tilt)), (cos(tilt) if raised else -cos(tilt)), 0).normalized()
		var hand := shoulder+direction*reach+Vector3(side*.04, 0, 0)
		kit.add("sphere", (shoulder+hand)*.5, Vector3(.15, reach+.06, .17), skin, Vector3(0, 0, tilt))
		match part.style:
			"nubs", "wave":
				kit.add("sphere", hand, Vector3.ONE*.15, skin)
			"mittens":
				kit.add("sphere", hand, Vector3(.2, .19, .19), c)
				kit.add("sphere", hand+Vector3(side*-.02, .06, .07), Vector3(.08, .1, .08), c)
				kit.add("torus", hand-direction*.08, Vector3(.17, .17, .17), accent, Vector3(0, 0, tilt), false)
			"gloves":
				kit.add("sphere", hand, Vector3(.2, .18, .19), c)
				kit.add("torus", hand-direction*.08, Vector3(.18, .2, .18), accent, Vector3(0, 0, tilt))
			"boxing":
				kit.add("sphere", hand+Vector3(0, 0, .03), Vector3(.28, .26, .3), c)
				kit.add("cylinder", hand-direction*.1, Vector3(.17, .06, .17), accent, Vector3(0, 0, tilt))
			"pompoms":
				for i in 6:
					var a := TAU*i/6
					kit.add("bead", hand+Vector3(cos(a)*.08, sin(a)*.08, .02), Vector3.ONE*.12, c if i % 2 else accent, Vector3.ZERO, false)
				kit.add("sphere", hand, Vector3.ONE*.13, c)
			"balloon":
				kit.add("sphere", hand, Vector3.ONE*.15, skin)
				if side > 0:
					var balloon := hand+Vector3(.12, .5, -.05)
					kit.add("cylinder", (hand+balloon)*.5, Vector3(.012, hand.distance_to(balloon), .012), CREAM, Vector3(0, 0, -.23), false)
					kit.add("sphere", balloon+Vector3(0, .13, 0), Vector3(.26, .3, .26), c)
					kit.add("cone", balloon-Vector3(0, .02, 0), Vector3(.06, .05, .06), c.darkened(.15), Vector3(PI, 0, 0), false)
			"wand", "flag", "sparkler", "lantern", "lollipop", "maracas":
				kit.add("sphere", hand, Vector3.ONE*.15, skin)
				if side > 0 or part.style in ["sparkler", "maracas"]:
					var length := .42 if part.style == "flag" else .3
					var tip := hand+Vector3(side*.04, length, .05)
					kit.add("cylinder", (hand+tip)*.5, Vector3(.025, length, .025), accent if part.style != "sparkler" else Color("8a8f99"), Vector3.ZERO, false)
					match part.style:
						"wand":
							kit.add("torus", tip+Vector3(0, .07, 0), Vector3(.16, .16, .16), c, Vector3(PI*.5, 0, 0))
							for i in 3:
								kit.add("sphere", tip+Vector3(.12+i*.07, .1+i*.08, .02), Vector3.ONE*(.07+i*.02), Color(.85, .95, 1.0), Vector3.ZERO, true)
						"flag":
							kit.add_rounded_box(tip+Vector3(side*.13, -.08, 0), Vector3(.24, .16, .02), c, Vector3.ZERO, true, 4)
							kit.add_rounded_box(tip+Vector3(side*.13, -.08, .012), Vector3(.24, .04, .01), accent, Vector3.ZERO, false, 4)
						"sparkler":
							for ray in 6:
								var a := TAU*ray/6
								kit.add("sphere", tip+Vector3(cos(a)*.06, sin(a)*.06, 0), Vector3(.14, .025, .025), c if ray % 2 else accent, Vector3(0, 0, a), false)
						"lantern":
							kit.add("sphere",tip+Vector3(0,.09,0),Vector3(.19,.22,.12),c)
							kit.add("cylinder",tip+Vector3(0,.21,0),Vector3(.13,.035,.1),accent)
							kit.add("cylinder",tip+Vector3(0,-.03,0),Vector3(.13,.035,.1),accent)
						"lollipop":
							kit.add("sphere",tip+Vector3(0,.1,0),Vector3(.22,.22,.09),c)
							kit.add("torus",tip+Vector3(0,.1,.055),Vector3(.12,.12,.12),accent,Vector3(PI*.5,0,0),false)
						"maracas":
							kit.add("sphere",tip+Vector3(0,.08,0),Vector3(.16,.2,.14),c)
							kit.add("cylinder",tip+Vector3(0,.03,.13),Vector3(.11,.025,.025),accent,Vector3(PI*.5,0,0),false)

# ---------- Glasses ----------

static func _glasses(kit: MeshKit, shape: KinuShape, part: KinuPart) -> void:
	var h := shape.size*.5
	var eye_x := minf(h.x*.42, .2)
	var eye_y := _eye_y(shape)+.04
	var c := part.color
	var accent := part.accent
	var r := minf(.115, h.x*.42)
	var tube := .03
	if part.style == "thick":
		r = minf(.125, h.x*.45)
		tube = .045
	var lenses: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var at := _front(shape, side*eye_x, eye_y)
		var basis := Basis.looking_at(-at[1], Vector3.UP)
		lenses.append(Transform3D(basis, at[0]+at[1]*.04))
	if part.style == "monocle":
		var lens := lenses[1]
		_hoop(kit, lens, r*1.1, tube, c)
		for i in 4:
			kit.add("bead", lens*Vector3(r*.7, -r-.03-i*.045, 0), Vector3.ONE*.03, c, Vector3.ZERO, false)
		return
	for lens in lenses:
		match part.style:
			"square", "three_d", "pixel":
				for bar in [[Vector3(0, r, 0), Vector3(r*2.2, tube*1.6, tube*1.6)], [Vector3(0, -r, 0), Vector3(r*2.2, tube*1.6, tube*1.6)], [Vector3(-r*1.05, 0, 0), Vector3(tube*1.6, r*2, tube*1.6)], [Vector3(r*1.05, 0, 0), Vector3(tube*1.6, r*2, tube*1.6)]]:
					kit.add_transformed("block", Transform3D(lens.basis*Basis.from_scale(bar[1]), lens*(bar[0] as Vector3)), c)
				if part.style == "pixel":
					for step in [-1.0,1.0]:
						kit.add_transformed("block",Transform3D(lens.basis*Basis.from_scale(Vector3(.045,.045,.025)),lens*Vector3(step*r*.8,r*.85,0)),accent,false)
				if part.style == "three_d":
					var tint := accent if lens == lenses[0] else Color("4fa3e0")
					kit.add_transformed("sphere", Transform3D(lens.basis*Basis.from_scale(Vector3(r*2, r*1.9, .015)), lens*Vector3(0, 0, -.005)), tint, false)
			"shades":
				_hoop(kit, lens, r, tube, c)
				kit.add_transformed("sphere", Transform3D(lens.basis*Basis.from_scale(Vector3(r*2.1, r*1.8, .02)), lens*Vector3(0, -.005, -.003)), c.darkened(.2), false)
				kit.add_transformed("sphere", Transform3D(lens.basis*Basis.from_scale(Vector3(r*.5, r*.3, .01)), lens*Vector3(-r*.35, r*.35, .01)), accent if accent != c else Color(1, 1, 1, 1), false)
			"goggles":
				_hoop(kit, lens, r*1.1, tube*1.8, accent)
				kit.add_transformed("sphere", Transform3D(lens.basis*Basis.from_scale(Vector3(r*2, r*2, .01)), lens*Vector3(0, 0, -.01)), c.lightened(.35), false)
			"star":
				_hoop(kit, lens, r, tube, c)
				for p in 5:
					var a := TAU*p/5+PI*.5
					kit.add_transformed("cone", Transform3D(lens.basis*Basis(Vector3.BACK, a-PI*.5)*Basis.from_scale(Vector3(.05, .06, .03)), lens*Vector3(cos(a)*(r+.03), sin(a)*(r+.03), 0)), accent, false)
			"heart":
				for lobe in [-1.0, 1.0]:
					_hoop(kit, Transform3D(lens.basis, lens*Vector3(lobe*.04, .025, 0)), r*.62, tube*.9, c)
				kit.add_transformed("cone", Transform3D(lens.basis*Basis(Vector3.BACK, PI)*Basis.from_scale(Vector3(.12, .1, .03)), lens*Vector3(0, -.06, 0)), accent, false)
			"cat_eye":
				_hoop(kit, lens, r, tube, c)
				var outward := 1.0 if lens == lenses[1] else -1.0
				kit.add_transformed("cone", Transform3D(lens.basis*Basis(Vector3.BACK, -outward*.7)*Basis.from_scale(Vector3(.06, .1, .03)), lens*Vector3(outward*r*.95, r*.75, 0)), accent)
			"butterfly":
				_hoop(kit,lens,r*.9,tube,c)
				var outward := 1.0 if lens == lenses[1] else -1.0
				kit.add_transformed("sphere",Transform3D(lens.basis*Basis.from_scale(Vector3(.13,.08,.02)),lens*Vector3(outward*r*.75,r*.55,0)),accent,false)
			"browline":
				# A heavy brow over a fine gold rim, so it never reads as plain round specs.
				_hoop(kit, lens, r, tube*.7, accent)
				kit.add_transformed("block", Transform3D(lens.basis*Basis.from_scale(Vector3(r*2.35, tube*3.2, tube*2)), lens*Vector3(0, r*.82, .005)), c)
			"visor":
				_hoop(kit,lens,r,tube,accent)
				kit.add_transformed("sphere",Transform3D(lens.basis*Basis.from_scale(Vector3(r*2,r*1.7,.02)),lens*Vector3(0,0,-.004)),c.lightened(.25),false)
			_:
				_hoop(kit, lens, r, tube, c)
	# Bridge, then the temples running back towards the sides.
	var bridge_y := r*.25
	var left := lenses[0]*Vector3(r*.95, bridge_y, 0)
	var right := lenses[1]*Vector3(-r*.95, bridge_y, 0)
	var middle := (left+right)*.5+Vector3(0, .015, .01)
	kit.add("cylinder", middle, Vector3(tube*1.4, left.distance_to(right), tube*1.4), c if part.style != "goggles" else accent, Vector3(0, 0, PI*.5))
	for i in 2:
		var lens := lenses[i]
		var outward := -1.0 if i == 0 else 1.0
		var hinge := lens*Vector3(outward*r*1.05, r*.2, 0)
		kit.add("cylinder", hinge+Vector3(outward*.015, 0, -.06), Vector3(tube*1.3, .13, tube*1.3), c if part.style != "goggles" else accent, Vector3(PI*.5, 0, 0))

## A round frame of radius r facing along the lens's +Z, with a tube `tube` thick.
static func _hoop(kit: MeshKit, lens: Transform3D, r: float, tube: float, color: Color) -> void:
	# The torus primitive lies flat in XZ; turn it to face out. Its height sets the frame's depth.
	# The primitive's tube is a tenth of its size across, so thicker frames nest a few rings.
	var rings := maxi(1, int(round(tube/(r*.18))))
	for i in rings:
		var radius := r-i*r*.14
		var basis := lens.basis*Basis(Vector3.RIGHT, PI*.5)*Basis.from_scale(Vector3(radius*2.0, maxf(tube*2.5, .02), radius*2.0))
		kit.add_transformed("torus", Transform3D(basis, lens.origin), color, i == 0)
