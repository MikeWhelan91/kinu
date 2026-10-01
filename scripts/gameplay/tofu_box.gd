class_name TofuBox
extends Node3D
## A wooden masu tofu box, about three to four Kinu wide: roomy enough to plan a base,
## small enough that the pile soon has to grow upward. Square, so spinning reads clearly.

## Scaled up 10% from the original 1.8/.24/.18/1.1 to leave more room for the Kinu inside.
const INNER_HALF := 1.98
const WALL := .264
const FLOOR_TOP := .198
const RIM_HEIGHT := 1.21
## Radius used by circular checks (balance support, placement): the inner wall distance.
const RIM_RADIUS := INNER_HALF

const WOOD := Color("f6dfb4")
const WOOD_DARK := Color("d9ad74")
const WOOD_LIGHT := Color("fbe9c8")
const HANKO := Color("e0463a")

## The equipped box skin (colours and finish). Null uses the default hinoki palette.
var decor: KinuDecor
## Previews skip physics.
var with_collision: bool = true

func _color(key: String, fallback: Color) -> Color:
	return decor.palette.get(key, fallback) if decor else fallback

static func contains(point: Vector3, margin: float = 0.0) -> bool:
	var reach := INNER_HALF+WALL+margin
	return absf(point.x) <= reach and absf(point.z) <= reach

## Built box models by skin id; new boxes and shop previews duplicate these (sharing meshes).
## Bounded, so scrolling the shop does not keep every skin built for the rest of the session.
static var models: Dictionary = {}

func _ready() -> void:
	var key := decor.id if decor else "default"
	add_child(MeshKit.cached_model(models, key, _build_model).duplicate())
	if with_collision:
		_add_collision()

## Box finishes that replace the red hanko seal with their own emblem.
const EMBLEM_EFFECTS := ["gachapon", "taiko", "treasure", "shortcake", "starry", "cloud", "koi_pond", "abyss", "starforge", "moss", "driftwood", "coral", "pumpkin_patch", "snowdrift", "paper_lantern", "first_edition"]

## Gold, gems and other trims built apart from the walls so they get their own finish.
var accent := MeshKit.new()
var accent_used := false

func _build_model() -> Node3D:
	var kit := MeshKit.new()
	var effect := decor.effect if decor else ""
	# Neon trim is built separately so only the rim, posts and stamps glow.
	var trim := MeshKit.new() if effect in ["glow", "paper_lantern"] else kit
	var outer := INNER_HALF+WALL
	var wood := _color("wood", WOOD)
	var wood_dark := _color("wood_dark", WOOD_DARK)
	var wood_light := _color("wood_light", WOOD_LIGHT)
	accent = MeshKit.new()
	accent_used = false
	# Floor boards.
	for i in 5:
		var x := -INNER_HALF+INNER_HALF*.4*(i+.5)
		kit.add_rounded_box(Vector3(x, FLOOR_TOP*.5, 0), Vector3(INNER_HALF*.4-.02, FLOOR_TOP, INNER_HALF*2), wood_light if i % 2 else wood, Vector3.ZERO, true, 10.0)
	# Two stacked planks per wall, with a darker rim trim.
	for side in 4:
		var angle := side*PI*.5
		var basis := Basis(Vector3.UP, angle)
		for plank in 2:
			var height := (RIM_HEIGHT-.08)*.5
			var center := basis*Vector3(0, height*(plank+.5), INNER_HALF+WALL*.5)
			kit.add_rounded_box(center, Vector3(outer*2-.02, height-.02, WALL), wood if plank == 0 else wood_light, Vector3(0, angle, 0), true, 10.0)
		trim.add_rounded_box(basis*Vector3(0, RIM_HEIGHT-.04, INNER_HALF+WALL*.5), Vector3(outer*2+.04, .1, WALL+.06), wood_dark, Vector3(0, angle, 0), true, 10.0)
		_wall_pattern(kit, effect, basis, angle, outer)
		var face := basis*Vector3(0, RIM_HEIGHT*.45, outer+.022)
		if effect in EMBLEM_EFFECTS:
			_emblem(kit, effect, face, basis, angle)
			continue
		# Hanko stamp: a red seal with a little white tofu square, on every side.
		trim.add("cylinder", face, Vector3(.46, .02, .46), _color("stamp", HANKO), Vector3(PI*.5, angle, 0), false)
		trim.add_rounded_box(face+basis*Vector3(0, 0, .02), Vector3(.2, .2, .02), _color("stamp_mark", Color("fff6e2")), Vector3(0, angle, 0), false, 8.0)
	# Corner posts.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var post := Vector3(x*(outer-.04), RIM_HEIGHT*.5, z*(outer-.04))
			trim.add_rounded_box(post, Vector3(.2, RIM_HEIGHT+.06, .2), wood_dark, Vector3.ZERO, true, 10.0)
			if effect == "petals":
				_blossom(kit, Vector3(x*(outer-.04), RIM_HEIGHT+.08, z*(outer-.04)))
			_corner(kit, effect, post, Vector2(x, z))
	if effect == "ribbon":
		_bow(kit, Vector3(outer-.04, RIM_HEIGHT+.12, outer-.04), _color("ribbon", Color("ff6f91")))
	var model := kit.build(.035)
	var fill := model.get_node("Fill") as MeshInstance3D
	match effect:
		"shiny", "kintsugi", "raden", "taiko", "gachapon", "first_edition":
			fill.material_override = shiny_material()
		"glass", "koi_pond":
			fill.material_override = glass_material()
		"glow", "paper_lantern":
			var glowing := trim.build(.035)
			(glowing.get_node("Fill") as MeshInstance3D).material_override = glow_material()
			model.add_child(glowing)
	if accent_used:
		var trims := accent.build(.03)
		trims.name = "Accent"
		match effect:
			"starry", "geode", "abyss", "starforge", "paper_lantern":
				(trims.get_node("Fill") as MeshInstance3D).material_override = glow_material()
			"cloud", "shortcake", "koi_pond", "moss", "driftwood", "coral", "pumpkin_patch", "snowdrift":
				pass
			_:
				(trims.get_node("Fill") as MeshInstance3D).material_override = gold_material()
		model.add_child(trims)
	return model

## Surface detail on each outer wall: candy stripes, a gift ribbon or a woven wicker lattice.
func _wall_pattern(kit: MeshKit, effect: String, basis: Basis, angle: float, outer: float) -> void:
	var turn := Vector3(0, angle, 0)
	var body := (RIM_HEIGHT-.08)*.5
	match effect:
		"stripes":
			for i in 8:
				var x := -outer+.3+i*(outer*2-.6)/7.0
				if absf(x) < .36:
					continue
				kit.add_rounded_box(basis*Vector3(x, body, outer+.008), Vector3(.2, RIM_HEIGHT-.16, .02), _color("stripe", Color.WHITE), turn, false, 8.0)
		"ribbon":
			var ribbon := _color("ribbon", Color("ff6f91"))
			kit.add_rounded_box(basis*Vector3(0, body, outer+.01), Vector3(.36, RIM_HEIGHT-.08, .02), ribbon, turn, false, 8.0)
			kit.add_rounded_box(basis*Vector3(0, RIM_HEIGHT+.02, INNER_HALF+WALL*.5), Vector3(.36, .04, WALL+.1), ribbon, turn, false, 8.0)
		"weave":
			for row in 4:
				for i in 9:
					var x := -outer+.2+i*(outer*2-.4)/8.0
					var raised := (i+row) % 2 == 0
					if absf(x) < .4 and row in [1, 2]:
						continue
					kit.add_rounded_box(basis*Vector3(x, .14+row*.23, outer+(.02 if raised else .006)), Vector3(.36, .19, .03), _color("wood_light", WOOD_LIGHT) if raised else _color("wood_dark", WOOD_DARK), turn, false, 6.0)
		"kintsugi":
			# Gold seams wandering across the glaze, with a few forks.
			var rng := RandomNumberGenerator.new()
			rng.seed = int(angle*100)+3
			for crack in 3:
				var point := Vector2(-outer+.1 if crack != 1 else outer-.1, rng.randf_range(.2, 1.0))
				var heading := 0.0 if crack != 1 else PI
				for step in 7:
					heading += rng.randf_range(-.8, .8)
					var length := rng.randf_range(.22, .4)
					var next := point+Vector2(cos(heading), sin(heading))*length
					next.y = clampf(next.y, .1, RIM_HEIGHT-.16)
					next.x = clampf(next.x, -outer+.08, outer-.08)
					_seam(basis, angle, outer, point, next, .075)
					if step == 3:
						_seam(basis, angle, outer, next, next+Vector2(rng.randf_range(-.3, .3), -.28), .05)
					point = next
		"treasure":
			var iron := _color("stamp_mark", Color("4a4650"))
			for y in [.16, RIM_HEIGHT-.2]:
				kit.add_rounded_box(basis*Vector3(0, y, outer+.02), Vector3(outer*2, .12, .04), iron, turn, true, 8.0)
				for i in 9:
					_accent("bead", basis*Vector3(-outer+.25+i*(outer*2-.5)/8.0, y, outer+.05), Vector3(.06, .06, .04), GOLD_TRIM)
			for x in [-outer*.62, outer*.62]:
				kit.add_rounded_box(basis*Vector3(x, body, outer+.03), Vector3(.12, RIM_HEIGHT-.1, .04), iron, turn, true, 8.0)
		"geode":
			for i in 7:
				var x := -outer+.35+i*(outer*2-.7)/6.0
				kit.add("fine", basis*Vector3(x, .2+fmod(i*.37, .6), outer+.01), Vector3(.34, .26, .06), _color("wood_light", WOOD_LIGHT).darkened(fmod(i*.29, .2)), turn, false)
			for i in 5:
				var x := -outer*.7+i*outer*.35
				if absf(x) < .4:
					continue
				for k in 3:
					_accent("cone", basis*Vector3(x+(k-1)*.14, .2+k*.05, outer+.1), Vector3(.17, .56-absf(k-1)*.16, .17), _color("stamp", Color("b77cf2")).lightened(k*.1), turn+Vector3(-.3, 0, (k-1)*.35))
		"first_edition":
			# The opening-day ribbon runs right round the box, with a line of gold studs along the
			# foot like the trim on a presentation case.
			kit.add_rounded_box(basis*Vector3(0, RIM_HEIGHT*.45, outer+.01), Vector3(outer*2-.02, .3, .02), _color("ribbon", Color("d8403f")), turn, false, 8.0)
			for edge in [-1.0, 1.0]:
				kit.add_rounded_box(basis*Vector3(0, RIM_HEIGHT*.45+edge*.17, outer+.012), Vector3(outer*2-.02, .04, .02), _color("stamp", Color("f5c14e")), turn, false, 8.0)
			for i in 11:
				_accent("bead", basis*Vector3(-outer+.22+i*(outer*2-.44)/10.0, .13, outer+.03), Vector3(.075, .075, .05), GOLD_TRIM)
		"gachapon":
			for i in 3:
				kit.add_rounded_box(basis*Vector3(0, .2+i*.004, outer+.01+i*.004), Vector3(outer*2-.1, .06, .02), [Color("fff7ea"), Color("ffd84d"), Color("fff7ea")][i], turn, false, 8.0)
			for x in [-outer*.62, outer*.62]:
				# Clear windows full of tiny capsules.
				kit.add_rounded_box(basis*Vector3(x, .72, outer+.012), Vector3(.9, .56, .02), Color("dff6ff"), turn, true, 8.0)
				for c in 5:
					var spot := Vector2(x-.3+c*.15, .6+fmod(c*.53, .25))
					kit.add("sphere", basis*Vector3(spot.x, spot.y, outer+.05), Vector3(.13, .13, .05), [Color("ff6f91"), Color("7fd4e8"), Color("ffd84d"), Color("9ccc5a"), Color("b99cf2")][c], turn, false)
		"taiko":
			for y in [.12, RIM_HEIGHT-.18]:
				kit.add_rounded_box(basis*Vector3(0, y, outer+.015), Vector3(outer*2, .1, .03), _color("stamp_mark", Color("2b1a17")), turn, false, 8.0)
				for i in 13:
					_accent("bead", basis*Vector3(-outer+.18+i*(outer*2-.36)/12.0, y, outer+.045), Vector3(.075, .075, .05), Color("d9d4c8"))
		"shortcake":
			var cream := _color("stripe", Color("fffaf2"))
			kit.add_rounded_box(basis*Vector3(0, body+.02, outer+.012), Vector3(outer*2-.04, .16, .02), _color("ribbon", Color("ff9fbf")), turn, false, 8.0)
			for i in 6:
				var x := -outer+.4+i*(outer*2-.8)/5.0
				if absf(x) < .45:
					continue
				kit.add("sphere", basis*Vector3(x, body+.03, outer+.05), Vector3(.2, .14, .06), Color("e8434f"), turn, false)
				kit.add("sphere", basis*Vector3(x, body+.03, outer+.08), Vector3(.12, .08, .02), Color("ffd0d6"), turn, false)
			for i in 14:
				var x := -outer+.16+i*(outer*2-.32)/13.0
				_accent("sphere", basis*Vector3(x, RIM_HEIGHT-.02-sin(i*1.3)*.03, outer+.03), Vector3(.24, .2+fmod(i*.3, .1), .16), cream)
				if i % 2 == 0:
					_accent("sphere", basis*Vector3(x, RIM_HEIGHT-.2-fmod(i*.17, .12), outer+.02), Vector3(.1, .26, .06), cream)
		"starry":
			var rng := RandomNumberGenerator.new()
			rng.seed = int(angle*100)+11
			for i in 16:
				var at := Vector2(rng.randf_range(-outer+.2, outer-.2), rng.randf_range(.15, RIM_HEIGHT-.2))
				if absf(at.x) < .36 and absf(at.y-RIM_HEIGHT*.45) < .36:
					continue
				var twinkle := rng.randf_range(.06, .14)
				for arm in 2:
					_accent("sphere", basis*Vector3(at.x, at.y, outer+.02), Vector3(twinkle, twinkle*.22, .02), Color("fff1b0") if i % 3 else Color("bfe6ff"), turn+Vector3(0, 0, arm*PI*.5+.2))
		"koi_pond":
			for i in 3:
				var x: float = [-1.35, .9, 1.55][i]*(1 if int(angle*10) % 2 == 0 else -1)
				var y: float = [.4, .78, .3][i]
				_koi(basis, angle, Vector3(x, y, outer+.03), i % 2 == 0)
			for i in 5:
				_accent("sphere", basis*Vector3(-outer+.4+i*.9, .12+fmod(i*.41, .9), outer+.02), Vector3(.05, .05, .02), Color(1, 1, 1, 1))
		"cloud":
			var fluff := Color("ffffff")
			for i in 9:
				var x := -outer+.1+i*(outer*2-.2)/8.0
				_accent("fine", basis*Vector3(x, .06+sin(i*1.9)*.04, outer+.05), Vector3(.5, .34+fmod(i*.37, .16), .22), fluff)
				_accent("fine", basis*Vector3(x+.2, RIM_HEIGHT+.02, outer-.05), Vector3(.42, .3+fmod(i*.29, .14), .34), fluff)
			for i in 4:
				var at := Vector2(-outer*.75+i*outer*.5, .72+fmod(i*.31, .25))
				if absf(at.x) < .45:
					continue
				_accent("fine", basis*Vector3(at.x, at.y, outer+.02), Vector3(.36, .18, .04), fluff.darkened(.02))
		"raden":
			# Mother-of-pearl inlay: vines of iridescent chips curling across the black lacquer.
			var shimmer := [Color("f7d6ff"), Color("c6f2ff"), Color("fff1c9"), Color("d6ffe9"), Color("ffd6e7")]
			for vine in 2:
				var origin := Vector2(-outer+.3, .3) if vine == 0 else Vector2(outer-.3, RIM_HEIGHT-.35)
				var direction := 1.0 if vine == 0 else -1.0
				for i in 16:
					var u := i/15.0
					var at := origin+Vector2(direction*u*(outer*.95), sin(u*TAU*1.2)*.18+(u*.3 if vine == 0 else -u*.2))
					if absf(at.x) < .36 and absf(at.y-RIM_HEIGHT*.45) < .34:
						continue
					kit.add("sphere", basis*Vector3(at.x, at.y, outer+.012), Vector3(.17, .085, .02), shimmer[i % shimmer.size()], turn+Vector3(0, 0, u*3.0), false)
					if i % 5 == 2:
						for petal in 5:
							var a := TAU*petal/5.0
							kit.add("sphere", basis*Vector3(at.x+sin(a)*.11, at.y+.18+cos(a)*.11, outer+.014), Vector3(.16, .09, .02), shimmer[(i+petal) % shimmer.size()], turn+Vector3(0, 0, -a), false)
							_accent("bead", basis*Vector3(at.x, at.y+.18, outer+.02), Vector3(.08, .08, .02), GOLD_TRIM)
		"moss":
			# Moss creeping up from the base, with clover, pebbles and two little mushrooms.
			for i in 13:
				var x := -outer+.2+i*(outer*2-.4)/12.0
				kit.add("fine", basis*Vector3(x, .06+fmod(i*.29, .2), outer+.04), Vector3(.46, .34+fmod(i*.23, .18), .18), _color("wood_light", WOOD_LIGHT).lightened(.06 if i % 2 else 0.0))
				if i % 3 == 0:
					kit.add("fine", basis*Vector3(x+.1, RIM_HEIGHT-.16, outer+.03), Vector3(.34, .24, .14), _color("wood_light", WOOD_LIGHT).darkened(.08))
			for i in 4:
				var x := -outer*.72+i*outer*.48
				if absf(x) < .5:
					continue
				for leaf in 3:
					var a := TAU*leaf/3.0
					kit.add("sphere", basis*Vector3(x+sin(a)*.1, .42+cos(a)*.1, outer+.03), Vector3(.17, .17, .03), Color("8cc85a"), turn, false)
			for mushroom in [-outer*.55, outer*.62]:
				kit.add("cylinder", basis*Vector3(mushroom, .3, outer+.08), Vector3(.1, .28, .1), Color("f5ead2"))
				kit.add("sphere", basis*Vector3(mushroom, .44, outer+.08), Vector3(.3, .22, .3), Color("d4544c"))
				for spot in 3:
					kit.add("sphere", basis*Vector3(mushroom-.08+spot*.08, .48, outer+.16), Vector3(.06, .06, .03), Color("fff6e2"), turn, false)
		"driftwood":
			# Long sun-bleached grain grooves, a rope lashing and a stranded starfish.
			for i in 5:
				var y := .18+i*(RIM_HEIGHT-.4)/4.0
				kit.add_rounded_box(basis*Vector3(sin(i*1.7)*.3, y, outer+.008), Vector3(outer*1.5, .035, .02), _color("wood_dark", WOOD_DARK), turn+Vector3(0, 0, sin(i*2.3)*.03), false, 4.0)
				kit.add_rounded_box(basis*Vector3(-outer*.5+fmod(i*.9, 1.4), y+.06, outer+.008), Vector3(outer*.5, .025, .02), _color("wood_light", WOOD_LIGHT), turn, false, 4.0)
			for rope in 2:
				var x := (-1.0 if rope == 0 else 1.0)*outer*.66
				for wrap in 4:
					kit.add_rounded_box(basis*Vector3(x, .2+wrap*.2, outer+.03), Vector3(.34, .12, .05), Color("e2cda4"), turn+Vector3(0, 0, .28), true, 5.0)
			for arm in 5:
				var a := TAU*arm/5.0
				kit.add("cone", basis*Vector3(sin(a)*.17, RIM_HEIGHT*.72+cos(a)*.17, outer+.03), Vector3(.18, .4, .04), _color("stamp", Color("48a0b4")), turn+Vector3(0, 0, -a), false)
		"coral":
			# Branching coral climbing each wall, with anemone tufts and a scatter of polyps.
			for i in 4:
				var x := -outer*.74+i*outer*.5
				if absf(x) < .5:
					continue
				var tone: Color = [Color("ff9d7a"), Color("ffd0a1"), Color("ff7fa8"), Color("ffe1b0")][i]
				kit.add_rounded_box(basis*Vector3(x, .5, outer+.03), Vector3(.14, .9, .05), tone, turn, true, 5.0)
				for branch in 3:
					var lean := (branch-1)*.6
					kit.add_rounded_box(basis*Vector3(x+lean*.24, .72+branch*.16, outer+.035), Vector3(.1, .46, .05), tone.lightened(.1), turn+Vector3(0, 0, -lean), true, 5.0)
					kit.add("sphere", basis*Vector3(x+lean*.42, .96+branch*.18, outer+.05), Vector3(.13, .13, .05), tone.lightened(.22), turn, false)
			for i in 5:
				var x := -outer+.35+i*(outer*2-.7)/4.0
				if absf(x) < .45:
					continue
				for frond in 6:
					var a := PI*frond/5.0
					kit.add("sphere", basis*Vector3(x+cos(a)*.16, .12+sin(a)*.24, outer+.03), Vector3(.07, .3, .04), Color("ffc0d8"), turn+Vector3(0, 0, PI*.5-a), false)
			for i in 9:
				kit.add("sphere", basis*Vector3(-outer+.3+i*(outer*2-.6)/8.0, RIM_HEIGHT-.14, outer+.02), Vector3(.1, .1, .03), Color("fff0d6"), turn, false)
		"pumpkin_patch":
			# A vine running the length of each wall, hung with leaves and little pumpkins.
			var vine := Color("4f7f33")
			for i in 10:
				var x := -outer+.2+i*(outer*2-.4)/9.0
				kit.add_rounded_box(basis*Vector3(x, .8+sin(i*1.4)*.16, outer+.02), Vector3((outer*2-.4)/8.0, .08, .03), vine, turn+Vector3(0, 0, cos(i*1.4)*.3), false, 4.0)
				if i % 2 == 0:
					kit.add("sphere", basis*Vector3(x, .8+sin(i*1.4)*.16+.2, outer+.04), Vector3(.32, .28, .05), vine.lightened(.2), turn+Vector3(0, 0, sin(i)*.5), false)
			for i in 3:
				var x := -outer*.66+i*outer*.66
				if absf(x) < .45:
					continue
				for rib in 5:
					kit.add("sphere", basis*Vector3(x+(rib-2)*.12, .34, outer+.1), Vector3(.2, .62, .2), Color("f79331").darkened(.06*absf(rib-2)), turn, rib == 0 or rib == 4)
				kit.add("cylinder", basis*Vector3(x, .68, outer+.1), Vector3(.09, .24, .09), vine)
				kit.add("sphere", basis*Vector3(x-.24, .66, outer+.1), Vector3(.3, .1, .16), vine.lightened(.2), turn+Vector3(0, .4, .35))
			for i in 7:
				kit.add("sphere", basis*Vector3(-outer+.28+i*(outer*2-.56)/6.0, RIM_HEIGHT-.16, outer+.02), Vector3(.1, .1, .03), Color("f5c46a"), turn, false)
		"snowdrift":
			# Drifts banked along the rim and the base, with icicles hanging off the trim.
			var snow := Color("fbfdff")
			for i in 11:
				var x := -outer+.16+i*(outer*2-.32)/10.0
				kit.add("fine", basis*Vector3(x, RIM_HEIGHT-.06, outer-.02), Vector3(.56, .3+fmod(i*.31, .2), .34), snow)
				kit.add("fine", basis*Vector3(x+.12, .05, outer+.04), Vector3(.5, .24+fmod(i*.27, .16), .2), snow)
			for i in 6:
				var x := -outer+.42+i*(outer*2-.84)/5.0
				kit.add("cone", basis*Vector3(x, RIM_HEIGHT-.36, outer+.06), Vector3(.12, .42+fmod(i*.4, .26), .12), Color("d6ecfb"), turn+Vector3(PI, 0, 0))
			for i in 9:
				var at := Vector2(-outer+.3+fmod(i*.83, outer*1.7), .3+fmod(i*.41, RIM_HEIGHT-.7))
				if absf(at.x) < .45:
					continue
				for arm in 3:
					kit.add("sphere", basis*Vector3(at.x, at.y, outer+.02), Vector3(.16, .025, .02), snow, turn+Vector3(0, 0, arm*PI/3.0), false)
		"paper_lantern":
			# Washi panels between bamboo ribs, lit from within, with a tassel at each end.
			for i in 7:
				var x := -outer+.28+i*(outer*2-.56)/6.0
				kit.add_rounded_box(basis*Vector3(x, RIM_HEIGHT*.5, outer+.012), Vector3(.055, RIM_HEIGHT-.16, .025), _color("wood_dark", WOOD_DARK), turn, false, 4.0)
			for y in [.2, RIM_HEIGHT*.5, RIM_HEIGHT-.22]:
				kit.add_rounded_box(basis*Vector3(0, y, outer+.008), Vector3(outer*2-.12, .07, .02), _color("wood_light", WOOD_LIGHT), turn, false, 5.0)
			for side in [-1.0, 1.0]:
				var x: float = side*(outer-.22)
				kit.add("cylinder", basis*Vector3(x, RIM_HEIGHT-.3, outer+.06), Vector3(.14, .12, .14), _color("stamp", Color("ffd464")))
				for strand in 5:
					kit.add_rounded_box(basis*Vector3(x-.1+strand*.05, RIM_HEIGHT-.56, outer+.06), Vector3(.035, .42, .035), _color("stamp", Color("ffd464")), turn, false, 4.0)
		"abyss":
			# Bioluminescent life in the dark: drifting jellyfish, glowing plankton and
			# a pair of anglerfish lures dangling from the rim.
			var deep_glow := [Color("35e4e0"), Color("817cff"), Color("a7f3e8")]
			for i in 18:
				var at := Vector2(-outer+.18+fmod(i*.73, outer*1.8), .14+fmod(i*.37, RIM_HEIGHT-.28))
				if absf(at.x) < .42 and absf(at.y-RIM_HEIGHT*.45) < .34:
					continue
				_accent("bead", basis*Vector3(at.x, at.y, outer+.03), Vector3(.07, .07, .025), deep_glow[i % deep_glow.size()])
			for i in 3:
				var x: float = [-outer*.68, outer*.3, outer*.78][i]
				if absf(x) < .5:
					continue
				var bell := basis*Vector3(x, .5+fmod(i*.47, .4), outer+.05)
				_accent("fine", bell, Vector3(.52, .38, .1), deep_glow[i % deep_glow.size()])
				for tentacle in 4:
					_accent("sphere", bell+basis*Vector3(-.15+tentacle*.1, -.3-fmod(tentacle*.17, .12), 0), Vector3(.045, .46, .03), deep_glow[(i+1) % deep_glow.size()], turn+Vector3(0, 0, (tentacle-1.5)*.16), false)
			for side in [-1.0, 1.0]:
				var stalk: float = side*outer*.5
				kit.add_rounded_box(basis*Vector3(stalk, RIM_HEIGHT-.34, outer+.03), Vector3(.035, .5, .03), Color("123a48"), turn+Vector3(0, 0, side*.2), false, 4.0)
				_accent("sphere", basis*Vector3(stalk+side*.1, RIM_HEIGHT-.6, outer+.05), Vector3(.17, .17, .05), Color("d9fff4"))
		"starforge":
			# Molten seams cracking up through the cooled metal, throwing off sparks.
			var rng := RandomNumberGenerator.new()
			rng.seed = int(angle*100)+7
			for seam in 3:
				var point := Vector2(-outer*.72+seam*outer*.72, .1)
				for step in 6:
					var next := point+Vector2(rng.randf_range(-.26, .26), (RIM_HEIGHT-.24)/6.0)
					next.x = clampf(next.x, -outer+.12, outer-.12)
					if absf(next.x) < .4 and absf(next.y-RIM_HEIGHT*.45) < .34:
						next.x += .5
					var middle := (point+next)*.5
					var delta := next-point
					_accent("sphere", basis*Vector3(middle.x, middle.y, outer+.02), Vector3(delta.length()+.08, .085, .03), Color("ff8a2b"), turn+Vector3(0, 0, atan2(delta.y, delta.x)))
					if step % 2 == 1:
						_accent("bead", basis*Vector3(next.x+.14, next.y+.1, outer+.05), Vector3(.075, .075, .03), Color("ffe07a"))
					point = next
			for i in 9:
				var x := -outer+.24+i*(outer*2-.48)/8.0
				_accent("bead", basis*Vector3(x, RIM_HEIGHT-.08+fmod(i*.23, .14), outer+.04), Vector3(.06, .06, .03), Color("ffd15c"))

const GOLD_TRIM := Color("f2c14e")

func _accent(kind: String, position: Vector3, scale: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO, outline: bool = true) -> void:
	accent.add(kind, position, scale, color, rotation, outline)
	accent_used = true

## One straight gold seam between two points on a wall, in (x along the wall, height) coordinates.
func _seam(basis: Basis, angle: float, outer: float, from: Vector2, to: Vector2, width: float) -> void:
	var middle := (from+to)*.5
	var delta := to-from
	accent.add_rounded_box(basis*Vector3(middle.x, middle.y, outer+.015), Vector3(delta.length()+width, width, .03), GOLD_TRIM, Vector3(0, angle, atan2(delta.y, delta.x)), false, 4.0)
	accent.add("bead", basis*Vector3(to.x, to.y, outer+.015), Vector3(width*1.2, width*1.2, .03), GOLD_TRIM, Vector3.ZERO, false)
	accent_used = true

## A little koi swimming along a wall.
func _koi(basis: Basis, angle: float, at: Vector3, left: bool) -> void:
	var turn := Vector3(0, angle, 0 if left else PI)
	var ahead := basis*Basis(Vector3.BACK, turn.z)*Vector3.RIGHT
	var orange := Color("f0592f")
	_accent("sphere", basis*at, Vector3(.42, .2, .04), Color("fffaf5"), turn)
	_accent("sphere", basis*at+ahead*.06, Vector3(.2, .14, .05), orange, turn, false)
	_accent("sphere", basis*at-ahead*.28, Vector3(.18, .22, .03), orange, turn+Vector3(0, 0, .3))

## The emblem on each wall for finishes that swap out the hanko seal.
func _emblem(kit: MeshKit, effect: String, face: Vector3, basis: Basis, angle: float) -> void:
	var turn := Vector3(0, angle, 0)
	var disc := Vector3(PI*.5, angle, 0)
	var out := basis*Vector3(0, 0, 1)
	match effect:
		"gachapon":
			# The coin slot and turning handle.
			kit.add("cylinder", face, Vector3(.62, .04, .62), Color("f7f3ea"), disc)
			_accent("cylinder", face+out*.04, Vector3(.5, .05, .5), Color("d9dde6"), disc)
			_accent("block", face+out*.08+Vector3.UP*.02, Vector3(.42, .1, .06), Color("b9c0cc"), turn+Vector3(0, 0, .6))
			_accent("sphere", face+out*.1, Vector3(.14, .14, .08), Color("e8434f"), turn)
			kit.add_rounded_box(face+Vector3.UP*.42+out*.01, Vector3(.28, .05, .02), Color("2b1a17"), turn, false, 8.0)
		"taiko":
			# A cream drum skin with a black mitsudomoe swirl.
			kit.add("cylinder", face, Vector3(.66, .03, .66), Color("f3e3c6"), disc)
			for i in 3:
				var a := TAU*i/3.0
				var head := face+basis*Vector3(sin(a)*.11, cos(a)*.11, .03)
				kit.add("sphere", head, Vector3(.13, .13, .02), Color("2b1a17"), turn, false)
				for k in 3:
					var b := a+(k+1)*.55
					kit.add("sphere", face+basis*Vector3(sin(b)*(.13+k*.02), cos(b)*(.13+k*.02), .03), Vector3(.1-k*.025, .1-k*.025, .02), Color("2b1a17"), turn, false)
		"treasure":
			_accent("block", face, Vector3(.36, .42, .05), GOLD_TRIM, turn)
			_accent("sphere", face+Vector3.UP*.07+out*.03, Vector3(.1, .1, .03), Color("2b1a17"), turn, false)
			_accent("block", face-Vector3.UP*.05+out*.03, Vector3(.05, .14, .03), Color("2b1a17"), turn, false)
			_accent("torus", face+Vector3.UP*.26, Vector3(.24, .3, .24), GOLD_TRIM.darkened(.1), turn+Vector3(0, 0, 0))
		"shortcake":
			kit.add_rounded_box(face, Vector3(.54, .32, .05), Color("6b3f2a"), turn, true, 6.0)
			kit.add_rounded_box(face+out*.03, Vector3(.4, .04, .02), Color("fffaf2"), turn, false, 6.0)
			kit.add("sphere", face+Vector3.UP*.2+out*.02, Vector3(.16, .16, .1), Color("e8434f"), turn)
		"starry":
			_accent("sphere", face, Vector3(.46, .46, .04), Color("ffe9a0"), turn)
			kit.add("sphere", face+basis*Vector3(.12, .08, .025), Vector3(.4, .4, .04), _color("wood", WOOD), turn, false)
		"cloud":
			for band in 5:
				var radius := .34-band*.055
				for k in 11:
					var a := PI*k/10.0
					_accent("sphere", face+basis*Vector3(cos(a)*radius, sin(a)*radius-.14, .01+band*.004), Vector3(.1, .1, .02), RAINBOW_ARC[band], turn, false)
			_accent("fine", face+basis*Vector3(-.32, -.16, .04), Vector3(.3, .2, .08), Color.WHITE, turn)
			_accent("fine", face+basis*Vector3(.32, -.16, .04), Vector3(.3, .2, .08), Color.WHITE, turn)
		"koi_pond":
			_accent("cylinder", face, Vector3(.54, .03, .54), Color("5fb86a"), disc)
			for i in 6:
				var a := TAU*i/6.0
				_accent("sphere", face+basis*Vector3(sin(a)*.1, cos(a)*.1+.02, .05), Vector3(.12, .2, .05), Color("ffb3cf"), turn+Vector3(0, 0, -a))
			_accent("sphere", face+out*.07, Vector3(.1, .1, .05), Color("ffd84d"), turn)
		"abyss":
			# A glowing anglerfish lure hanging over a dark crescent.
			_accent("sphere", face, Vector3(.5, .5, .04), Color("2be1d3"), turn)
			kit.add("sphere", face+basis*Vector3(.12, .08, .025), Vector3(.36, .36, .04), _color("wood", WOOD), turn, false)
			for i in 5:
				var a := TAU*i/5.0
				_accent("bead", face+basis*Vector3(sin(a)*.42, cos(a)*.42, .01), Vector3(.075, .075, .03), Color("a7f3e8"))
		"starforge":
			# A struck star over the forge, with four sparks flying off it.
			_accent("sphere", face, Vector3(.5, .5, .04), Color("ffe07a"), turn)
			for i in 4:
				var a := TAU*i/4.0
				kit.add("cone", face+basis*Vector3(sin(a)*.23, cos(a)*.23, .035), Vector3(.1, .28, .03), Color("e86d27"), turn+Vector3(0, 0, -a), false)
			for i in 4:
				var a := TAU*i/4.0+PI*.25
				_accent("bead", face+basis*Vector3(sin(a)*.44, cos(a)*.44, .01), Vector3(.08, .08, .03), Color("ff8a2b"))
		"moss":
			# A three-leaf sprig pressed into a pale stone.
			kit.add("cylinder", face, Vector3(.66, .03, .66), Color("d9d2be"), disc)
			for i in 3:
				var a := TAU*i/3.0
				kit.add("sphere", face+basis*Vector3(sin(a)*.14, cos(a)*.14+.04, .03), Vector3(.26, .3, .03), Color("6fae45"), turn+Vector3(0, 0, -a), false)
			kit.add_rounded_box(face+basis*Vector3(0, -.22, .03), Vector3(.05, .22, .02), Color("4f7f33"), turn, false, 4.0)
		"driftwood":
			# A scallop shell, ribbed and sun-faded.
			kit.add("sphere", face+basis*Vector3(0, -.08, 0), Vector3(.72, .58, .05), Color("fdf1dc"), turn)
			for i in 5:
				var a := PI*.5+(i-2)*.36
				kit.add("sphere", face+basis*Vector3(cos(a)*.2, -.2+sin(a)*.24, .035), Vector3(.05, .44, .02), Color("d9bf97"), turn+Vector3(0, 0, PI*.5-a), false)
			kit.add("sphere", face+basis*Vector3(0, -.28, .04), Vector3(.14, .1, .03), Color("c6a87c"), turn, false)
		"coral":
			# A branching coral head over a pale disc.
			kit.add("cylinder", face, Vector3(.66, .03, .66), Color("fff0dc"), disc)
			for i in 3:
				var lean := (i-1)*.5
				kit.add_rounded_box(face+basis*Vector3(lean*.14, -.06+absf(lean)*.04, .03), Vector3(.09, .44, .02), Color("ff7fa8"), turn+Vector3(0, 0, -lean), false, 5.0)
				kit.add("sphere", face+basis*Vector3(lean*.26, .18, .04), Vector3(.14, .14, .03), Color("ffc0d8"), turn, false)
		"pumpkin_patch":
			# One plump pumpkin with a curled stem.
			for rib in 5:
				kit.add("sphere", face+basis*Vector3((rib-2)*.09, -.04, .02), Vector3(.16, .5, .04), Color("f07c1e").darkened(.06*absf(rib-2)), turn, false)
			kit.add_rounded_box(face+basis*Vector3(.02, .26, .03), Vector3(.06, .2, .02), Color("4f7f33"), turn+Vector3(0, 0, .3), false, 4.0)
			kit.add("sphere", face+basis*Vector3(-.16, .28, .03), Vector3(.24, .12, .02), Color("6fae45"), turn+Vector3(0, 0, .4), false)
		"snowdrift":
			# A six-armed snowflake on a frosted disc.
			kit.add("cylinder", face, Vector3(.66, .03, .66), Color("e6f4ff"), disc)
			for i in 3:
				kit.add("sphere", face+basis*Vector3(0, 0, .03), Vector3(.62, .06, .02), Color("fbfdff"), turn+Vector3(0, 0, i*PI/3.0), false)
			for i in 6:
				var a := TAU*i/6.0
				kit.add("sphere", face+basis*Vector3(sin(a)*.22, cos(a)*.22, .04), Vector3(.2, .05, .02), Color("fbfdff"), turn+Vector3(0, 0, -a+PI*.5), false)
			kit.add("sphere", face+basis*Vector3(0, 0, .05), Vector3(.12, .12, .03), Color("9fd2f5"), turn, false)
		"first_edition":
			# A gold "No. 1" medal: pleated rosette, a red face with a gold numeral, and ribbon tails.
			for tail in [-1.0, 1.0]:
				kit.add_rounded_box(face+basis*Vector3(tail*.14, -.4, -.005), Vector3(.14, .36, .02), Color("d8403f"), turn+Vector3(0, 0, tail*.3), false, 4.0)
			for i in 14:
				var a := TAU*i/14.0
				_accent("sphere", face+basis*Vector3(sin(a)*.3, cos(a)*.3, .005), Vector3(.17, .17, .04), GOLD_TRIM)
			kit.add("cylinder", face+out*.03, Vector3(.48, .03, .48), Color("d8403f"), disc, false)
			_accent("torus", face+out*.045, Vector3(.5, .12, .5), GOLD_TRIM, disc)
			_accent("block", face+out*.06+basis*Vector3(.015, 0, 0), Vector3(.075, .26, .03), GOLD_TRIM, turn)
			_accent("block", face+out*.06+basis*Vector3(-.045, .095, 0), Vector3(.1, .055, .03), GOLD_TRIM, turn+Vector3(0, 0, .6))
			_accent("block", face+out*.06+basis*Vector3(.015, -.12, 0), Vector3(.17, .045, .03), GOLD_TRIM, turn)
		"paper_lantern":
			# A lit washi roundel inside a bamboo hoop.
			_accent("cylinder", face, Vector3(.68, .03, .68), _color("stamp", Color("ffd464")), disc)
			kit.add("torus", face+out*.02, Vector3(.72, .06, .72), _color("wood_dark", WOOD_DARK), disc, false)
			kit.add_rounded_box(face+out*.04, Vector3(.28, .28, .02), Color("b8221f"), turn, false, 8.0)
			for i in 2:
				kit.add_rounded_box(face+out*.06+basis*Vector3(0, .08-i*.16, 0), Vector3(.2, .05, .02), _color("stamp", Color("ffd464")), turn, false, 4.0)

const RAINBOW_ARC := [Color("ff8fa3"), Color("ffb65c"), Color("ffe36e"), Color("8fdc8a"), Color("7fc4f5")]

## Decoration perched on each corner post.
func _corner(kit: MeshKit, effect: String, post: Vector3, corner: Vector2) -> void:
	var cap := post+Vector3.UP*(RIM_HEIGHT*.5+.06)
	match effect:
		"treasure":
			_accent("block", cap-Vector3.UP*.05, Vector3(.28, .12, .28), GOLD_TRIM)
			_accent("bead", cap+Vector3.UP*.08, Vector3(.2, .24, .2), [Color("e8434f"), Color("3fb6e8"), Color("5fcf6a"), Color("b77cf2")][int(corner.x+1)+int((corner.y+1)*.5)])
		"geode":
			for k in 5:
				var a := TAU*k/5.0
				_accent("cone", cap+Vector3(sin(a)*.12, .18+k*.03, cos(a)*.12), Vector3(.2, .8-k*.08, .2), _color("stamp", Color("b77cf2")).lightened(k*.08), Vector3(sin(a)*.35, 0, cos(a)*-.35))
		"gachapon":
			_accent("sphere", cap+Vector3.UP*.1, Vector3(.3, .3, .3), Color("dff6ff"))
			kit.add("sphere", cap+Vector3.UP*.05, Vector3(.29, .16, .29), [Color("ff6f91"), Color("7fd4e8"), Color("ffd84d"), Color("9ccc5a")][int(corner.x+1)+int((corner.y+1)*.5)], Vector3.ZERO, false)
		"shortcake":
			kit.add("cone", cap+Vector3.UP*.12, Vector3(.26, .32, .26), Color("e8434f"), Vector3(PI, 0, 0))
			kit.add("sphere", cap+Vector3.UP*.3, Vector3(.24, .06, .24), Color("6cc94c"))
		"taiko":
			if corner == Vector2(1, 1):
				for side in [-1.0, 1.0]:
					kit.add("cylinder", cap+Vector3(side*.12, .25, 0), Vector3(.06, .9, .06), Color("e8c48a"), Vector3(side*.5, .8, side*.4))
		"starry", "raden", "kintsugi":
			_accent("bead", cap, Vector3(.24, .08, .24), GOLD_TRIM)
		"koi_pond":
			kit.add("cylinder", cap+Vector3.UP*.02, Vector3(.5, .03, .5), Color("5fb86a"), Vector3.ZERO, false)
		"cloud":
			_accent("fine", cap+Vector3.UP*.08, Vector3(.5, .36, .5), Color.WHITE)
		"moss":
			kit.add("fine", cap+Vector3.UP*.06, Vector3(.46, .3, .46), _color("wood_light", WOOD_LIGHT).lightened(.08))
			for blade in 3:
				var a := TAU*blade/3.0
				kit.add("sphere", cap+Vector3(sin(a)*.1, .24, cos(a)*.1), Vector3(.07, .3, .07), Color("8cc85a"), Vector3(sin(a)*.3, 0, -cos(a)*.3))
		"driftwood":
			for wrap in 3:
				kit.add_rounded_box(cap+Vector3(0, -.06+wrap*.11, 0), Vector3(.3, .09, .3), Color("e2cda4"), Vector3(0, wrap*.4, .12), true, 5.0)
			kit.add("fine", cap+Vector3.UP*.2, Vector3(.3, .26, .3), Color("fdf1dc"))
		"coral":
			for frond in 5:
				var a := TAU*frond/5.0
				kit.add("sphere", cap+Vector3(sin(a)*.1, .24, cos(a)*.1), Vector3(.09, .46, .09), [Color("ff9d7a"), Color("ff7fa8"), Color("ffd0a1")][frond % 3], Vector3(sin(a)*.42, 0, -cos(a)*.42))
		"pumpkin_patch":
			for rib in 5:
				kit.add("sphere", cap+Vector3((rib-2)*.06, .12, 0), Vector3(.1, .3, .28), Color("f07c1e").darkened(.05*absf(rib-2)), Vector3.ZERO, rib == 0 or rib == 4)
			kit.add("cylinder", cap+Vector3(0, .3, 0), Vector3(.07, .18, .07), Color("4f7f33"))
		"snowdrift":
			kit.add("fine", cap+Vector3.UP*.08, Vector3(.48, .34, .48), Color("fbfdff"))
			kit.add("fine", cap+Vector3(.08, .24, -.05), Vector3(.28, .22, .28), Color("fbfdff"))
		"first_edition":
			# A little gold kusudama on each post, tied with a red cord.
			_accent("sphere", cap+Vector3.UP*.14, Vector3(.32, .32, .32), GOLD_TRIM)
			kit.add("torus", cap+Vector3.UP*.14, Vector3(.34, .3, .34), Color("d8403f"), Vector3(PI*.5, PI*.25*corner.x*corner.y, 0), false)
			kit.add("cone", cap+Vector3.UP*-.08, Vector3(.1, .2, .1), Color("d8403f"), Vector3(PI, 0, 0), false)
		"paper_lantern":
			_accent("sphere", cap+Vector3.UP*.12, Vector3(.34, .38, .34), _color("stamp", Color("ffd464")))
			kit.add("cylinder", cap+Vector3.UP*.3, Vector3(.16, .06, .16), _color("wood_dark", WOOD_DARK))
		"abyss":
			_accent("fine", cap+Vector3.UP*.14, Vector3(.4, .3, .4), Color("35e4e0"))
			for tentacle in 4:
				var a := TAU*tentacle/4.0
				_accent("sphere", cap+Vector3(sin(a)*.1, -.04, cos(a)*.1), Vector3(.05, .34, .05), Color("a7f3e8"), Vector3(sin(a)*.3, 0, -cos(a)*.3), false)
		"starforge":
			_accent("sphere", cap+Vector3.UP*.1, Vector3(.28, .28, .28), Color("ff8a2b"))
			for spark in 4:
				var a := TAU*spark/4.0+.4
				_accent("bead", cap+Vector3(sin(a)*.2, .3+fmod(spark*.11, .16), cos(a)*.2), Vector3(.075, .075, .075), Color("ffe07a"))

## A looped ribbon bow perched on one corner post.
func _bow(kit: MeshKit, center: Vector3, color: Color) -> void:
	var across := Vector3(1, 0, -1).normalized()
	for side in [-1.0, 1.0]:
		kit.add("torus", center+across*side*.3+Vector3(0, .12, 0), Vector3(.5, .9, .5), color, Vector3(PI*.5, PI*.25, side*.6))
		kit.add_rounded_box(center+across*side*.14+Vector3(0, -.28, 0), Vector3(.14, .5, .04), color, Vector3(0, PI*.25, side*.35), true, 4.0)
	kit.add("sphere", center+Vector3(0, .06, 0), Vector3(.28, .24, .28), color.darkened(.12))

## Tower and Toss put the box away: hidden, and nothing can land on it. The mask goes too —
## a body still collides when the *other* side's mask matches, so clearing the layer alone left
## an invisible box in the middle of the counter for Kinu to hit.
func set_active(active: bool) -> void:
	visible = active
	if is_instance_valid(body):
		body.collision_layer = 1 if active else 0
		body.collision_mask = 2 if active else 0

var body: StaticBody3D

func _add_collision() -> void:
	var outer := INNER_HALF+WALL

	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 1.0
	add_child(body)
	_box(body, Vector3(0, FLOOR_TOP*.5, 0), Vector3(outer*2, FLOOR_TOP, outer*2))
	for side in 4:
		var basis := Basis(Vector3.UP, side*PI*.5)
		var shape := _box(body, basis*Vector3(0, RIM_HEIGHT*.5, INNER_HALF+WALL*.5), Vector3(outer*2, RIM_HEIGHT, WALL))
		shape.basis = basis

static var _shiny: ShaderMaterial

static func shiny_material() -> ShaderMaterial:
	if _shiny == null:
		_shiny = ShaderMaterial.new()
		_shiny.shader = MeshKit.TOON
		_shiny.set_shader_parameter("shine", .8)
		_shiny.set_shader_parameter("rim_strength", .18)
	return _shiny

static var _glass: ShaderMaterial
static var _glow: ShaderMaterial

## See-through ice: the pile inside stays visible through the walls.
static func glass_material() -> ShaderMaterial:
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.shader = KinuModel.GLASS
		_glass.set_shader_parameter("opacity", .55)
		_glass.set_shader_parameter("shine", 1.0)
		_glass.set_shader_parameter("rim_strength", .5)
	return _glass

static var _gold: ShaderMaterial

## Polished gold for trims: bright highlights and a faint warmth in the shadows.
static func gold_material() -> ShaderMaterial:
	if _gold == null:
		_gold = ShaderMaterial.new()
		_gold.shader = MeshKit.TOON
		_gold.set_shader_parameter("shine", 1.0)
		_gold.set_shader_parameter("rim_strength", .35)
		_gold.set_shader_parameter("glow", .12)
	return _gold

static func glow_material() -> ShaderMaterial:
	if _glow == null:
		_glow = ShaderMaterial.new()
		_glow.shader = MeshKit.TOON
		_glow.set_shader_parameter("glow", .7)
		_glow.set_shader_parameter("rim_strength", .3)
	return _glow

func _blossom(kit: MeshKit, center: Vector3) -> void:
	for i in 5:
		var a := TAU*i/5.0
		kit.add("sphere", center+Vector3(sin(a)*.09, 0, cos(a)*.09), Vector3(.13, .05, .13), Color("ffb3c8"))
	kit.add("bead", center+Vector3(0, .03, 0), Vector3(.07, .05, .07), Color("ffd85c"), Vector3.ZERO, false)

func _box(body: StaticBody3D, center: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	return shape
