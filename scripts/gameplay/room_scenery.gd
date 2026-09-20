class_name RoomScenery
extends RefCounted
## Outdoor settings around the counter. The counter, box, camera and physics never change;
## only the surroundings do. Tall props stay beyond the camera's orbit so they never block the pile.

const FLOOR := -TofuShop.COUNTER_HEIGHT
## The home screen looks from this orbit angle, so featured props sit opposite it.
const MENU_FACING := .35+PI
const STONE := Color("b3ada2")
const WOOD := Color("a9744a")

var shop: TofuShop
var kit := MeshKit.new()
var glow := MeshKit.new()
var glowing := false
var rng := RandomNumberGenerator.new()
## Symmetric layouts build with their showpiece on +z and are turned to face the home screen.
var turn := 0.0

static func build(owner: TofuShop, layout: String) -> Node3D:
	var scenery: RoomScenery = PremiumScenery.new() if layout in PremiumScenery.LAYOUTS else RoomScenery.new()
	scenery.shop = owner
	scenery.rng.seed = 11
	if scenery is PremiumScenery:
		(scenery as PremiumScenery).build_layout(layout)
	match layout:
		"grove":
			scenery._grove()
		"onsen":
			scenery._onsen()
		"festival":
			scenery._festival()
		"rooftop":
			scenery._rooftop()
		"veranda":
			scenery._veranda()
	var root := scenery.kit.build(.06, false)
	root.rotation.y = scenery.turn
	if scenery.glowing:
		var lit := scenery.glow.build(.06, false)
		var material := ShaderMaterial.new()
		material.shader = MeshKit.TOON
		material.set_shader_parameter("glow", .75)
		(lit.get_node("Fill") as MeshInstance3D).material_override = material
		root.add_child(lit)
	return root

func _c(key: String, fallback: Color) -> Color:
	return shop._c(key, fallback)

func _lit(kind: String, position: Vector3, scale: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	glowing = true
	glow.add(kind, position, scale, color, rotation, false)

## Ground to the horizon, ringed by soft distant hills.
func _land(clear_radius: float = 7.0) -> void:
	kit.add("cylinder", Vector3(0, FLOOR-.2, 0), Vector3(150, .4, 150), _c("floor", Color("8fb86a")), Vector3.ZERO, false)
	for i in 16:
		var a := TAU*i/16.0+rng.randf_range(-.1, .1)
		var r := rng.randf_range(62.0, 72.0)
		kit.add("fine", Vector3(sin(a)*r, FLOOR, cos(a)*r), Vector3(rng.randf_range(34, 50), rng.randf_range(18, 34), 30), _c("hills", Color("7a9f63")), Vector3(0, a, 0), false)

	_scatter(clear_radius)

## Grass tufts, bushes, rocks and flowers fill the ground between the counter and the horizon.
func _scatter(clear: float) -> void:
	var ground := _c("floor", Color("8fb86a"))
	var snowy: bool = shop.decor.palette.get("tree", "") == "pine"
	for i in 26:
		var at := _ring_spot(clear, clear+19.0)
		var bush := ground.lightened(.35) if snowy else ground.darkened(.28)
		for k in 3:
			kit.add("sphere", at+Vector3(k*.9-.9, .7+(k % 2)*.35, sin(k*2.1)*.5), Vector3.ONE*rng.randf_range(1.4, 2.0), bush.darkened(k*.05))
	for i in 18:
		var at := _ring_spot(clear, clear+15.0)
		kit.add("fine", at+Vector3(0, .25, 0), Vector3(rng.randf_range(.9, 1.6), rng.randf_range(.5, .9), rng.randf_range(.8, 1.4)), STONE.darkened(rng.randf_range(0, .2)), Vector3(0, rng.randf()*TAU, 0))
	if snowy:
		return
	for i in 70:
		var at := _ring_spot(clear-.5, clear+17.0)
		for k in 3:
			kit.add("cone", at+Vector3(k*.18-.18, .3, 0), Vector3(.14, .6+k*.12, .14), ground.darkened(.18), Vector3(0, 0, (k-1)*.35), false)
	var flowers: Array = shop.decor.palette.get("flowers", [Color("fff4d6"), Color("ffd45c"), Color("ff9fc0")])
	for i in 40:
		var at := _ring_spot(clear-.5, clear+13.0)
		kit.add("sphere", at+Vector3(0, .12, 0), Vector3(.28, .16, .28), flowers[i % flowers.size()], Vector3.ZERO, false)

## Places a point given in "featured" coordinates (positive z = in view of the home screen).
func _featured(local: Vector3) -> Vector3:
	return Basis(Vector3.UP, MENU_FACING)*local

func _rod(from: Vector3, to: Vector3, width: float, color: Color, outline: bool = true) -> void:
	var dir := to-from
	var up := dir.normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length() < .01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	kit.add_transformed("cylinder", Transform3D(Basis(side*width, dir, side.cross(up)*width), (from+to)*.5), color, outline)

func _ring_spot(r_min: float, r_max: float) -> Vector3:
	var a := rng.randf()*TAU
	var r := rng.randf_range(r_min, r_max)
	return Vector3(sin(a)*r, FLOOR, cos(a)*r)

func _stone_lantern(at: Vector3) -> void:
	kit.add_rounded_box(at+Vector3(0, .3, 0), Vector3(1.2, .6, 1.2), STONE, Vector3.ZERO, true, 4)
	kit.add("cylinder", at+Vector3(0, 1.4, 0), Vector3(.45, 1.6, .45), STONE)
	kit.add_rounded_box(at+Vector3(0, 2.35, 0), Vector3(1.1, .3, 1.1), STONE, Vector3.ZERO, true, 4)
	kit.add_rounded_box(at+Vector3(0, 2.95, 0), Vector3(.85, .9, .85), STONE, Vector3.ZERO, true, 4)
	_lit("block", at+Vector3(0, 2.95, 0), Vector3(.5, .42, .9), _c("lantern", Color("ffd46b")))
	_lit("block", at+Vector3(0, 2.95, 0), Vector3(.9, .42, .5), _c("lantern", Color("ffd46b")))
	kit.add("cone", at+Vector3(0, 3.75, 0), Vector3(1.8, .8, 1.8), STONE.darkened(.12))
	kit.add("sphere", at+Vector3(0, 4.25, 0), Vector3(.32, .32, .32), STONE)

# ---------- Grove: bamboo, maple, sakura or snowy pine ----------

func _grove() -> void:
	_land()
	var tree: String = shop.decor.palette.get("tree", "bamboo")
	var canopy: Array = shop.decor.palette.get("canopy", [Color("e8552f")])
	var trunk := _c("post", Color("6b4a33"))
	# A stepping-stone path runs out from the counter, on the side the home screen looks at.
	for i in 7:
		kit.add("cylinder", _featured(Vector3(sin(i*.9)*.6, FLOOR+.05, 5.2+i*1.5)), Vector3(1.3, .12, 1.0), STONE, Vector3(0, i*.7, 0))
	match tree:
		"bamboo":
			for i in 54:
				_bamboo(_ring_spot(10.0, 22.0), trunk, canopy)
		"pine":
			for i in 22:
				_pine(_ring_spot(11.0, 24.0), rng.randf_range(8.0, 13.0))
			_snowman(_featured(Vector3(7.5, FLOOR, 7.0)))
		_:
			for i in 16:
				_tree(_ring_spot(11.0, 22.0), rng.randf_range(4.5, 6.5), trunk, canopy)
	if shop.decor.palette.get("torii", false):
		_torii(_featured(Vector3(0, FLOOR, 16.5)), MENU_FACING)
	for side in [-1.0, 1.0]:
		_stone_lantern(_featured(Vector3(side*3.2, FLOOR, 9.0)))
	match tree:
		"bamboo":
			_basin(_featured(Vector3(-6.0, FLOOR, 7.5)))
			_bench(_featured(Vector3(6.5, FLOOR, 8.0)), MENU_FACING)
			_hut(_featured(Vector3(1.5, FLOOR, 17.0)), MENU_FACING, Color("c9a26b"), Color("6b7a3a"))
			for z in [12.0, 14.5]:
				for side in [-1.0, 1.0]:
					_lantern_post(_featured(Vector3(side*2.4, FLOOR, z)))
		"maple":
			_temple(_featured(Vector3(0, FLOOR, 23.0)), MENU_FACING)
			_bell_tower(_featured(Vector3(-11.0, FLOOR, 13.0)), MENU_FACING)
			_ema_rack(_featured(Vector3(6.5, FLOOR, 9.5)), MENU_FACING)
			for side in [-1.0, 1.0]:
				_stone_lantern(_featured(Vector3(side*3.2, FLOOR, 12.5)))
			for i in 16:
				var pile := _ring_spot(6.5, 18.0)
				kit.add("sphere", pile+Vector3(0, .15, 0), Vector3(rng.randf_range(1.2, 2.2), .35, rng.randf_range(1.0, 1.8)), canopy[i % canopy.size()].darkened(.1), Vector3(0, rng.randf()*TAU, 0))
		"sakura":
			_stream(MENU_FACING)
			_bridge(_featured(Vector3(0, FLOOR, 11.5)), MENU_FACING, Color("d8432f"))
			_picnic(_featured(Vector3(-6.5, FLOOR, 7.5)), MENU_FACING)
			_hut(_featured(Vector3(7.5, FLOOR, 15.5)), MENU_FACING-.5, Color("f3e3c6"), Color("b8452e"))
			for side in [-1.0, 1.0]:
				_lantern_post(_featured(Vector3(side*9.0, FLOOR, 8.5)))
		"pine":
			_hut(_featured(Vector3(2.0, FLOOR, 16.5)), MENU_FACING, Color("a9744a"), Color("f7fbff"))
			_kamakura(_featured(Vector3(-7.5, FLOOR, 10.5)), MENU_FACING+.4)
			_sled(_featured(Vector3(4.5, FLOOR, 9.0)), MENU_FACING+.8)

## A stone water basin fed by a bamboo spout.
func _basin(at: Vector3) -> void:
	kit.add("fine", at+Vector3(0, .6, 0), Vector3(2.0, 1.2, 2.0), STONE)
	kit.add("cylinder", at+Vector3(0, 1.17, 0), Vector3(1.3, .05, 1.3), _c("water", Color("7fcbd6")), Vector3.ZERO, false)
	_rod(at+Vector3(1.6, 0, 0), at+Vector3(1.6, 2.4, 0), .22, _c("post", Color("8fbf5a")))
	_rod(at+Vector3(1.6, 2.2, 0), at+Vector3(.4, 1.9, 0), .16, _c("post", Color("8fbf5a")))

func _bench(at: Vector3, facing: float) -> void:
	var basis := Basis(Vector3.UP, facing)
	kit.add_rounded_box(at+Vector3(0, 1.1, 0), Vector3(3.2, .25, 1.0), WOOD, Vector3(0, facing, 0), true, 10)
	for x in [-1.3, 1.3]:
		kit.add("block", at+basis*Vector3(x, .5, 0), Vector3(.2, 1.0, .8), WOOD.darkened(.25), Vector3(0, facing, 0))

func _bamboo(base: Vector3, stalk: Color, leaves: Array) -> void:
	var height := rng.randf_range(15.0, 24.0)
	var top := base+Vector3(rng.randf_range(-1, 1), height, rng.randf_range(-1, 1))
	_rod(base, top, .42, stalk)
	for n in int(height/2.6):
		var at := base.lerp(top, (1.3+n*2.6)/height)
		kit.add("cylinder", at, Vector3(.5, .12, .5), stalk.darkened(.22), Vector3.ZERO, false)
	for l in 6:
		var at := base.lerp(top, rng.randf_range(.55, 1.0))
		kit.add("sphere", at+Vector3(rng.randf_range(-.8, .8), 0, rng.randf_range(-.8, .8)), Vector3(1.9, .18, .55), leaves[l % leaves.size()], Vector3(rng.randf_range(-.3, .3), rng.randf()*TAU, rng.randf_range(-.4, .4)), false)

func _tree(base: Vector3, height: float, trunk: Color, canopy: Array) -> void:
	_rod(base, base+Vector3(0, height, 0), .8, trunk)
	for side in [-1.0, 1.0]:
		_rod(base+Vector3(0, height*.6, 0), base+Vector3(side*1.8, height*1.05, rng.randf_range(-.8, .8)), .3, trunk)
	for i in 7:
		var at := base+Vector3(rng.randf_range(-2.4, 2.4), height+rng.randf_range(-.4, 2.0), rng.randf_range(-2.4, 2.4))
		kit.add("fine", at, Vector3.ONE*rng.randf_range(2.8, 4.2), canopy[i % canopy.size()])

func _pine(base: Vector3, height: float) -> void:
	var green := _c("pine", Color("3f6b4f"))
	kit.add("cylinder", base+Vector3(0, 1.0, 0), Vector3(.6, 2.0, .6), Color("6b4a33"))
	for tier in 3:
		var width := 4.6-tier*1.2
		var tall := height*.42
		var center := base+Vector3(0, 1.8+tier*height*.24+tall*.5, 0)
		kit.add("cone", center, Vector3(width, tall, width), green)
		kit.add("cone", center+Vector3(0, tall*.3, 0), Vector3(width*.43, tall*.43, width*.43), Color("f7fbff"), Vector3.ZERO, false)

func _snowman(at: Vector3) -> void:
	var snow := Color("fbfdff")
	kit.add("fine", at+Vector3(0, .9, 0), Vector3(1.9, 1.8, 1.9), snow)
	kit.add("fine", at+Vector3(0, 2.3, 0), Vector3(1.3, 1.25, 1.3), snow)
	kit.add("cone", at+Vector3(0, 2.3, .75), Vector3(.18, .5, .18), Color("f28b2c"), Vector3(PI*.5, 0, 0))
	for side in [-1.0, 1.0]:
		kit.add("sphere", at+Vector3(side*.22, 2.5, .58), Vector3(.13, .13, .08), Color("2b1a17"), Vector3.ZERO, false)
	kit.add("cylinder", at+Vector3(0, 3.05, 0), Vector3(.9, .6, .9), Color("c93f49"))

func _torii(at: Vector3, facing: float = 0.0) -> void:
	var basis := Basis(Vector3.UP, facing)
	var turn := Vector3(0, facing, 0)
	var red := _c("torii_color", Color("d8432f"))
	var black := Color("2b1a17")
	for side in [-1.0, 1.0]:
		kit.add("cylinder", at+basis*Vector3(side*3.2, 4.5, 0), Vector3(.7, 9.0, .7), red)
		kit.add("cylinder", at+basis*Vector3(side*3.2, .3, 0), Vector3(.9, .6, .9), black)
	kit.add_rounded_box(at+Vector3(0, 7.4, 0), Vector3(8.4, .5, .6), red, turn, true, 8)
	kit.add_rounded_box(at+Vector3(0, 9.2, 0), Vector3(10.0, .6, .9), black, turn, true, 8)
	kit.add_rounded_box(at+Vector3(0, 8.75, 0), Vector3(9.2, .45, .75), red, turn, true, 8)


## A small wooden hut with a pitched roof, a door and warmly lit windows.
func _hut(at: Vector3, facing: float, walls: Color, roof: Color) -> void:
	var basis := Basis(Vector3.UP, facing)
	var yaw := Vector3(0, facing, 0)
	kit.add("block", at+Vector3(0, 1.8, 0), Vector3(6.0, 3.6, 4.5), walls, yaw)
	for side in [-1.0, 1.0]:
		kit.add_rounded_box(at+basis*Vector3(0, 4.4, side*1.3), Vector3(7.2, .35, 3.4), roof, yaw+Vector3(side*-.55, 0, 0), true, 10)
	kit.add("block", at+basis*Vector3(0, 5.3, 0), Vector3(7.2, .3, .5), roof.darkened(.2), yaw)
	kit.add("block", at+basis*Vector3(-1.4, 1.2, -2.27), Vector3(1.3, 2.4, .1), walls.darkened(.35), yaw)
	for x in [1.0, 2.2]:
		_lit("block", at+basis*Vector3(x, 2.1, -2.28), Vector3(.9, .9, .08), Color("ffd98a"), yaw)

func _lantern_post(at: Vector3) -> void:
	kit.add("cylinder", at+Vector3(0, 1.6, 0), Vector3(.22, 3.2, .22), Color("5a3a28"))
	kit.add("block", at+Vector3(0, 3.2, .35), Vector3(.12, .12, .9), Color("5a3a28"))
	_lit("sphere", at+Vector3(0, 2.65, .75), Vector3(.55, .75, .55), _c("lantern", Color("ff8a3d")))
	kit.add("cylinder", at+Vector3(0, 3.1, .75), Vector3(.3, .12, .3), Color("2b1a17"))

## A temple hall on a stone plinth: red pillars, white walls and a wide sweeping roof.
func _temple(at: Vector3, facing: float) -> void:
	var basis := Basis(Vector3.UP, facing)
	var yaw := Vector3(0, facing, 0)
	var red := _c("torii_color", Color("d8432f"))
	kit.add("block", at+Vector3(0, .6, 0), Vector3(14, 1.2, 9), STONE, yaw)
	for i in 4:
		kit.add("block", at+basis*Vector3(0, .15+i*.3, -4.8-i*.35), Vector3(4.0, .3, .7), STONE.darkened(.08), yaw)
	kit.add("block", at+Vector3(0, 3.6, 0), Vector3(11, 4.8, 6.5), Color("f6ecd8"), yaw)
	for x in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		kit.add("cylinder", at+basis*Vector3(x, 3.6, -3.4), Vector3(.6, 4.8, .6), red)
	kit.add("block", at+basis*Vector3(0, 5.8, -3.4), Vector3(11.4, .5, .6), red, yaw)
	kit.add_rounded_box(at+Vector3(0, 6.6, 0), Vector3(16, .8, 11), Color("3a3440"), yaw, true, 6)
	kit.add_rounded_box(at+Vector3(0, 7.6, 0), Vector3(11, 1.6, 7), Color("3a3440"), yaw, true, 4)
	kit.add_rounded_box(at+Vector3(0, 8.7, 0), Vector3(6, .5, 3), Color("2b2630"), yaw, true, 8)
	for side in [-1.0, 1.0]:
		_lit("sphere", at+basis*Vector3(side*3.6, 4.6, -4.0), Vector3(.9, 1.2, .9), _c("lantern", Color("f39c34")))

func _bell_tower(at: Vector3, facing: float) -> void:
	var yaw := Vector3(0, facing, 0)
	var wood := Color("6b4a33")
	for x in [-1.3, 1.3]:
		for z in [-1.3, 1.3]:
			kit.add("cylinder", at+Basis(Vector3.UP, facing)*Vector3(x, 3.0, z), Vector3(.35, 6.0, .35), wood)
	kit.add_rounded_box(at+Vector3(0, 6.4, 0), Vector3(4.6, .6, 4.6), Color("3a3440"), yaw, true, 6)
	kit.add("cone", at+Vector3(0, 7.3, 0), Vector3(3.8, 1.4, 3.8), Color("3a3440"))
	kit.add("fine", at+Vector3(0, 4.6, 0), Vector3(1.3, 1.8, 1.3), Color("8a7a4a"))
	kit.add("cylinder", at+Vector3(0, 3.65, 0), Vector3(1.4, .2, 1.4), Color("6f6238"))

## A rack of little wooden wish plaques with red cords.
func _ema_rack(at: Vector3, facing: float) -> void:
	var basis := Basis(Vector3.UP, facing)
	var yaw := Vector3(0, facing, 0)
	for x in [-1.8, 1.8]:
		kit.add("cylinder", at+basis*Vector3(x, 1.2, 0), Vector3(.2, 2.4, .2), Color("6b4a33"))
	kit.add("block", at+Vector3(0, 2.3, 0), Vector3(4.0, .2, .6), Color("5a3a28"), yaw)
	kit.add("block", at+Vector3(0, 2.6, 0), Vector3(4.4, .12, 1.0), Color("3a3440"), yaw)
	for row in 2:
		for i in 6:
			kit.add("block", at+basis*Vector3(-1.4+i*.56, 1.95-row*.7, -.12), Vector3(.45, .35, .05), Color("e8c48a"), yaw+Vector3(0, 0, sin(i+row)*.12))
			kit.add("block", at+basis*Vector3(-1.4+i*.56, 1.72-row*.7, -.16), Vector3(.05, .12, .02), Color("d8432f"), yaw, false)

## A gentle arched bridge, drawn as planks along a curve.
func _bridge(at: Vector3, facing: float, rail: Color) -> void:
	var basis := Basis(Vector3.UP, facing)
	var yaw := Vector3(0, facing, 0)
	for i in 11:
		var t := (i-5)/5.0
		var y := .25+1.1*(1.0-t*t)
		kit.add("block", at+basis*Vector3(0, y, t*4.0), Vector3(2.6, .22, .8), Color("a9744a"), yaw+Vector3(-t*.45, 0, 0))
		for side in [-1.0, 1.0]:
			kit.add("cylinder", at+basis*Vector3(side*1.3, y+.55, t*4.0), Vector3(.14, 1.0, .14), rail)
	for side in [-1.0, 1.0]:
		for i in 10:
			var t0 := (i-5)/5.0
			var t1 := (i-4)/5.0
			_rod(at+basis*Vector3(side*1.3, 1.3+1.1*(1.0-t0*t0), t0*4.0), at+basis*Vector3(side*1.3, 1.3+1.1*(1.0-t1*t1), t1*4.0), .16, rail)

## A stream crossing the garden on the home-screen side, under the bridge.
func _stream(facing: float) -> void:
	var basis := Basis(Vector3.UP, facing)
	for i in 16:
		var x := -24.0+i*3.2
		kit.add("cylinder", basis*Vector3(x, 0, 11.5+sin(i*.6)*1.2)+Vector3(0, FLOOR+.03, 0), Vector3(4.2, .06, 3.2), _c("water", Color("8fd3e8")), Vector3.ZERO, false)

func _picnic(at: Vector3, facing: float) -> void:
	var basis := Basis(Vector3.UP, facing)
	var yaw := Vector3(0, facing, 0)
	kit.add("block", at+Vector3(0, .05, 0), Vector3(4.0, .1, 3.0), Color("d8432f"), yaw)
	for i in 4:
		kit.add("block", at+basis*Vector3(-1.5+i*1.0, .07, 0), Vector3(.4, .1, 3.0), Color("fff4e0"), yaw, false)
	kit.add_rounded_box(at+basis*Vector3(-.6, .35, .2), Vector3(1.2, .5, .9), Color("2b2226"), yaw, true, 10)
	kit.add_rounded_box(at+basis*Vector3(-.6, .62, .2), Vector3(1.25, .08, .95), Color("d8432f"), yaw, true, 10)
	for i in 2:
		kit.add("cylinder", at+basis*Vector3(.8+i*.6, .3, -.4), Vector3(.35, .4, .35), Color("f7f3ea"))
	kit.add("cylinder", at+Vector3(0, 2.2, 0)+basis*Vector3(1.4, 0, .8), Vector3(.12, 4.4, .12), Color("5a3a28"))
	kit.add("cone", at+Vector3(0, 4.5, 0)+basis*Vector3(1.4, 0, .8), Vector3(5.0, 1.2, 5.0), Color("d8432f"))

## A snow hut glowing from inside.
func _kamakura(at: Vector3, facing: float) -> void:
	var basis := Basis(Vector3.UP, facing)
	kit.add("fine", at+Vector3(0, .6, 0), Vector3(5.0, 4.2, 5.0), Color("f7fbff"))
	_lit("fine", at+basis*Vector3(0, 1.1, -2.15), Vector3(1.6, 2.0, .6), Color("ffcf7a"))

func _sled(at: Vector3, facing: float) -> void:
	var basis := Basis(Vector3.UP, facing)
	var yaw := Vector3(0, facing, 0)
	kit.add("block", at+Vector3(0, .55, 0), Vector3(1.3, .15, 2.6), Color("c93f49"), yaw)
	for x in [-.55, .55]:
		_rod(at+basis*Vector3(x, .12, -1.3), at+basis*Vector3(x, .12, 1.2), .1, Color("3a3440"))
		kit.add("torus", at+basis*Vector3(x, .35, -1.35), Vector3(.5, .5, .5), Color("3a3440"), yaw+Vector3(0, 0, PI*.5), false)

# ---------- Onsen: a rock-ringed hot spring with a bamboo fence ----------

func _onsen() -> void:
	turn = MENU_FACING
	_land(18.0)
	var water := _c("water", Color("7fcbd6"))
	kit.add("cylinder", Vector3(0, FLOOR+.25, 0), Vector3(25, .1, 25), water, Vector3.ZERO, false)
	for i in 10:
		var spot := _ring_spot(7.5, 11.0)
		kit.add("sphere", spot+Vector3(0, .32, 0), Vector3(rng.randf_range(1.2, 2.4), .02, .35), water.lightened(.45), Vector3(0, rng.randf()*TAU, 0), false)
	kit.add_rounded_box(Vector3(0, FLOOR+.35, 0), Vector3(12.5, .4, 12.5), WOOD, Vector3.ZERO, true, 10)
	for i in 8:
		kit.add("block", Vector3(-6.25+(i+.5)*12.5/8.0, FLOOR+.56, 0), Vector3(.05, .02, 12.4), WOOD.darkened(.25), Vector3.ZERO, false)
	for i in 34:
		var a := TAU*i/34.0+rng.randf_range(-.05, .05)
		var r := rng.randf_range(12.4, 13.4)
		var tone := STONE.darkened(rng.randf_range(0, .25))
		kit.add("fine", Vector3(sin(a)*r, FLOOR+.4, cos(a)*r), Vector3(rng.randf_range(1.8, 2.8), rng.randf_range(1.0, 1.8), rng.randf_range(1.5, 2.3)), tone, Vector3(0, rng.randf()*TAU, rng.randf_range(-.2, .2)))
	var fence := _c("post", Color("b9a15f"))
	for i in 120:
		var a := TAU*i/120.0
		kit.add("cylinder", Vector3(sin(a)*17.0, FLOOR+2.8, cos(a)*17.0), Vector3(.46, 5.6+sin(i*1.7)*.25, .46), fence if i % 2 else fence.darkened(.1))
	for band in [1.6, 4.2]:
		for i in 24:
			var a := TAU*i/24.0
			var b := TAU*(i+1)/24.0
			_rod(Vector3(sin(a)*16.7, FLOOR+band, cos(a)*16.7), Vector3(sin(b)*16.7, FLOOR+band, cos(b)*16.7), .16, Color("5a4630"), false)
	for i in 12:
		_pine_top(_ring_spot(20.0, 26.0))
	for i in 3:
		kit.add("cylinder", Vector3(5.2+i*.1, FLOOR+.8+i*.55, -4.6), Vector3(1.0, .5, 1.0), Color("c89a64"))
	_stone_lantern(Vector3(-10.5, FLOOR+.4, -6.0))
	_stone_lantern(Vector3(9.5, FLOOR+.4, 7.5))
	# A bathhouse roof rising beyond the fence, and a rock waterfall pouring into the pool.
	_hut(Vector3(0, FLOOR, 23.0), 0.0, Color("e8dcc4"), Color("3a3440"))
	for i in 7:
		var x := -2.4+i*.8
		kit.add("fine", Vector3(x, FLOOR+1.0+sin(i*1.3)*.6+absf(x)*-.2, 13.4), Vector3(1.8, 2.6+cos(i)*.6, 1.8), STONE.darkened(.1+.05*(i % 2)))
	kit.add("block", Vector3(0, FLOOR+1.6, 12.4), Vector3(1.2, 2.8, .2), Color(1, 1, 1, 1), Vector3(-.15, 0, 0), false)
	for i in 5:
		kit.add("sphere", Vector3(-1.0+i*.5, FLOOR+.35, 11.9), Vector3(.6, .3, .6), Color("f2fbff"), Vector3.ZERO, false)
	for i in 16:
		var a := TAU*i/16.0
		_lit("sphere", Vector3(sin(a)*16.6, FLOOR+5.2, cos(a)*16.6), Vector3(.45, .6, .45), _c("lantern", Color("f2a65a")))

func _pine_top(base: Vector3) -> void:
	var green := _c("pine", Color("4f7a55"))
	for tier in 3:
		kit.add("cone", base+Vector3(0, 5.0+tier*2.4, 0), Vector3(5.4-tier*1.4, 4.2, 5.4-tier*1.4), green.darkened(tier*.06))

# ---------- Festival: a ring of yatai stalls under strings of lanterns ----------

func _festival() -> void:
	turn = MENU_FACING
	_land(16.5)
	_yagura(Vector3(0, FLOOR, 22.0))
	_goldfish(Vector3(-5.5, FLOOR, 8.2))
	_taiko(Vector3(5.8, FLOOR, 8.0))
	var awning: Array = shop.decor.palette.get("awning", [Color("e24a4a"), Color("3a7bd5")])
	for i in 9:
		_stall(TAU*(i+.5)/9.0, awning[i % awning.size()])
	var poles: Array[Vector3] = []
	for i in 9:
		var a := TAU*i/9.0
		var base := Vector3(sin(a)*10.5, FLOOR, cos(a)*10.5)
		kit.add("cylinder", base+Vector3(0, 4.2, 0), Vector3(.3, 8.4, .3), Color("5a3a28"))
		poles.append(base+Vector3(0, 8.2, 0))
	for i in poles.size():
		var from: Vector3 = poles[i]
		var to: Vector3 = poles[(i+1) % poles.size()]
		for bead in 7:
			var t := (bead+.5)/7.0
			var at := from.lerp(to, t)-Vector3(0, sin(t*PI)*1.3, 0)
			_lit("sphere", at-Vector3(0, .35, 0), Vector3(.5, .62, .5), [_c("lantern", Color("ff8a3d")), Color("fff1c4")][bead % 2])
			kit.add("cylinder", at, Vector3(.05, .5, .05), Color("2b1a17"), Vector3.ZERO, false)

## The festival drum tower: a scaffold with a red-and-white skirt and lanterns on top.
func _yagura(at: Vector3) -> void:
	var wood := Color("6b4a33")
	for x in [-2.4, 2.4]:
		for z in [-2.4, 2.4]:
			kit.add("cylinder", at+Vector3(x, 4.5, z), Vector3(.35, 9.0, .35), wood)
	kit.add("block", at+Vector3(0, 6.0, 0), Vector3(5.6, .4, 5.6), wood)
	for i in 12:
		var a := TAU*i/12.0
		var edge := Vector3(sin(a), 0, cos(a))*2.9
		kit.add("block", at+edge+Vector3(0, 5.1, 0), Vector3(1.55, 1.6, .1), Color("d8432f") if i % 2 == 0 else Color("fff4e0"), Vector3(0, a, 0), false)
	kit.add_rounded_box(at+Vector3(0, 9.3, 0), Vector3(6.6, .5, 6.6), Color("3a3440"), Vector3.ZERO, true, 6)
	kit.add("cylinder", at+Vector3(0, 7.0, 0), Vector3(1.6, 1.4, 1.6), Color("b5652e"))
	kit.add("cylinder", at+Vector3(0, 7.72, 0), Vector3(1.5, .05, 1.5), Color("f3e3c6"), Vector3.ZERO, false)
	for i in 8:
		var a := TAU*i/8.0
		_lit("sphere", at+Vector3(sin(a)*3.1, 8.4, cos(a)*3.1), Vector3(.6, .8, .6), [_c("lantern", Color("ff8a3d")), Color("fff1c4")][i % 2])

## A shallow pool of goldfish for scooping.
func _goldfish(at: Vector3) -> void:
	kit.add("cylinder", at+Vector3(0, .35, 0), Vector3(3.4, .7, 3.4), Color("3a7bd5"))
	kit.add("cylinder", at+Vector3(0, .69, 0), Vector3(3.0, .04, 3.0), Color("9fe0f2"), Vector3.ZERO, false)
	for i in 7:
		var spot := Vector3(sin(i*2.4)*1.0, .73, cos(i*1.9)*1.0)
		kit.add("sphere", at+spot, Vector3(.32, .06, .16), Color("ff7a2f"), Vector3(0, i*.9, 0), false)

func _taiko(at: Vector3) -> void:
	for x in [-.7, .7]:
		_rod(at+Vector3(x, 0, -.6), at+Vector3(x*.6, 1.6, 0), .16, Color("5a3a28"))
		_rod(at+Vector3(x, 0, .6), at+Vector3(x*.6, 1.6, 0), .16, Color("5a3a28"))
	kit.add("cylinder", at+Vector3(0, 2.0, 0), Vector3(1.8, 1.4, 1.8), Color("b5652e"), Vector3(PI*.5, 0, 0))
	for z in [-.72, .72]:
		kit.add("cylinder", at+Vector3(0, 2.0, z), Vector3(1.9, .06, 1.9), Color("f3e3c6"), Vector3(PI*.5, 0, 0), false)

func _stall(angle: float, stripe: Color) -> void:
	var basis := Basis(Vector3.UP, angle)
	var origin := Vector3(sin(angle), 0, cos(angle))*14.0+Vector3(0, FLOOR, 0)
	var at := func(local: Vector3) -> Vector3:
		return origin+basis*local
	var turn := Vector3(0, angle, 0)
	kit.add_rounded_box(at.call(Vector3(0, 1.1, -1.2)), Vector3(5.0, 2.2, 1.4), _c("wood", WOOD), turn, true, 10)
	kit.add("block", at.call(Vector3(0, 3.2, 1.0)), Vector3(5.0, 6.4, .3), _c("plaster", Color("f3e3c6")), turn)
	for x in [-2.4, 2.4]:
		for z in [-1.9, 1.0]:
			kit.add("cylinder", at.call(Vector3(x, 3.4, z)), Vector3(.22, 6.8, .22), _c("post", Color("6b4a33")))
	for s in 7:
		var x := -2.7+(s+.5)*5.4/7.0
		kit.add_rounded_box(at.call(Vector3(x, 6.5, -.7)), Vector3(5.4/7.0, .14, 3.6), stripe if s % 2 == 0 else Color("fff7ea"), turn+Vector3(-.3, 0, 0), s == 0 or s == 6, 10)
	kit.add("block", at.call(Vector3(0, 5.5, -2.6)), Vector3(3.2, .9, .12), _c("paper", Color("fff4dc")), turn+Vector3(-.3, 0, 0))
	for g in 5:
		var tone: Color = [Color("ff6f91"), Color("ffd45c"), Color("7fd4e8"), Color("9ccc5a"), Color("ffffff")][g]
		kit.add("sphere", at.call(Vector3(-1.8+g*.9, 2.5, -1.3)), Vector3(.5, .5, .5), tone)
	for x in [-2.2, 2.2]:
		_lit("sphere", at.call(Vector3(x, 5.2, -2.4)), Vector3(.6, .78, .6), _c("lantern", Color("ff8a3d")))

# ---------- Rooftop: a city roof with a glowing skyline and neon signs ----------

func _rooftop() -> void:
	var concrete := _c("floor", Color("4a4460"))
	kit.add("block", Vector3(0, FLOOR-.3, 0), Vector3(26, .6, 26), concrete)
	for i in 9:
		var x := -13.0+(i+1)*2.6
		kit.add("block", Vector3(x, FLOOR+.01, 0), Vector3(.06, .02, 26), concrete.darkened(.2), Vector3.ZERO, false)
		kit.add("block", Vector3(0, FLOOR+.01, x), Vector3(26, .02, .06), concrete.darkened(.2), Vector3.ZERO, false)
	for side in 4:
		var basis := Basis(Vector3.UP, side*PI*.5)
		kit.add("block", basis*Vector3(0, FLOOR+.5, 12.8), Vector3(26, 1.0, .4), concrete.lightened(.1), Vector3(0, side*PI*.5, 0))
		for p in 14:
			kit.add("cylinder", basis*Vector3(-12.6+p*1.94, FLOOR+1.6, 12.8), Vector3(.12, 1.4, .12), Color("8f96a8"))
		kit.add("cylinder", basis*Vector3(0, FLOOR+2.35, 12.8), Vector3(.16, 25.6, .16), Color("aab2c4"), Vector3(0, side*PI*.5, PI*.5))
	var tank := Vector3(-9.0, FLOOR, -9.0)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			kit.add("cylinder", tank+Vector3(x*1.1, 2.0, z*1.1), Vector3(.2, 4.0, .2), Color("6f7488"))
	kit.add("cylinder", tank+Vector3(0, 5.3, 0), Vector3(3.2, 2.8, 3.2), Color("8a6d5a"))
	kit.add("cone", tank+Vector3(0, 7.1, 0), Vector3(3.4, .9, 3.4), Color("5a4a40"))
	for i in 3:
		var unit := Vector3(8.5-i*2.6, FLOOR+.7, -10.5)
		kit.add_rounded_box(unit, Vector3(2.2, 1.4, 1.2), Color("c9cfdb"), Vector3.ZERO, true, 10)
		kit.add("torus", unit+Vector3(0, 0, .62), Vector3(.9, .1, .9), Color("7a8194"), Vector3(PI*.5, 0, 0), false)
	for i in 2:
		var machine := _featured(Vector3(-5.5+i*1.6, FLOOR, 11.6))
		kit.add_rounded_box(machine+Vector3(0, 1.6, 0), Vector3(1.4, 3.2, 1.0), [Color("e24a4a"), Color("3a7bd5")][i], Vector3(0, MENU_FACING, 0), true, 10)
		_lit("block", machine+Basis(Vector3.UP, MENU_FACING)*Vector3(0, 2.1, -.52), Vector3(1.1, 1.3, .05), Color("dff6ff"), Vector3(0, MENU_FACING, 0))
	var antenna := _featured(Vector3(8.0, FLOOR, 9.5))
	kit.add("cylinder", antenna+Vector3(0, 5.0, 0), Vector3(.18, 10.0, .18), Color("aab2c4"))
	for h in [4.0, 7.0]:
		kit.add("cylinder", antenna+Vector3(0, h, 0), Vector3(2.2, .08, .08), Color("aab2c4"), Vector3(0, MENU_FACING, PI*.5))
	_lit("sphere", antenna+Vector3(0, 10.2, 0), Vector3(.45, .45, .45), Color("ff3b3b"))
	for i in 5:
		var pot := _featured(Vector3(-10.5+i*.9, FLOOR, 7.0+i*.2))
		kit.add("cylinder", pot+Vector3(0, .4, 0), Vector3(.7, .8, .7), Color("c46f45"))
		kit.add("fine", pot+Vector3(0, 1.2, 0), Vector3(1.1, 1.0, 1.1), Color("4f9a55"))
	var line_a := _featured(Vector3(3.0, FLOOR+3.2, 5.5))
	var line_b := _featured(Vector3(11.5, FLOOR+3.2, 5.5))
	for end in [line_a, line_b]:
		kit.add("cylinder", end-Vector3(0, 1.6, 0), Vector3(.14, 3.2, .14), Color("8f96a8"))
	_rod(line_a, line_b, .04, Color("2b1a17"), false)
	for i in 5:
		var peg := line_a.lerp(line_b, (i+.7)/6.0)
		kit.add("block", peg-Vector3(0, .5, 0), Vector3(1.0, 1.0, .06), [Color("ff9fc0"), Color("fff4e0"), Color("7fd4e8")][i % 3], Vector3(0, MENU_FACING, 0), false)
	var windows: Array = shop.decor.palette.get("windows", [Color("ffd46b"), Color("7ff0ff"), Color("ff8fd1")])
	var building := _c("plaster", Color("2a2442"))
	for i in 30:
		var a := TAU*i/30.0+rng.randf_range(-.06, .06)
		var r := rng.randf_range(26.0, 40.0)
		var width := rng.randf_range(6.0, 10.0)
		var height := rng.randf_range(24.0, 60.0)
		var basis := Basis(Vector3.UP, a)
		var base := Vector3(sin(a)*r, FLOOR-34.0, cos(a)*r)
		kit.add("block", base+Vector3(0, height*.5, 0), Vector3(width, height, 6.0), building.darkened(rng.randf_range(0, .3)), Vector3(0, a, 0))
		var top := base.y+height
		var y := FLOOR-8.0
		while y < top-1.5:
			for col in int(width/1.8):
				if rng.randf() < .38:
					var x := -width*.5+.9+col*1.8
					_lit("block", base+basis*Vector3(x, y-base.y, -3.05), Vector3(.9, 1.1, .1), windows[rng.randi() % windows.size()], Vector3(0, a, 0))
			y += 2.2
		if i % 5 == 2 and top > FLOOR+6.0:
			var board := base+basis*Vector3(0, top-base.y+2.4, 0)
			for x in [-2.0, 2.0]:
				kit.add("cylinder", base+basis*Vector3(x, top-base.y+1.0, 0), Vector3(.2, 2.0, .2), Color("6f7488"))
			_lit("block", board, Vector3(7.0, 3.0, .3), [Color("ff4fb0"), Color("37e0ff"), Color("ffe24f")][i % 3], Vector3(0, a, 0))
			kit.add("block", board+basis*Vector3(0, 0, -.2), Vector3(5.0, 1.2, .1), Color("1a1630"), Vector3(0, a, 0), false)
		if i % 4 == 0 and top > FLOOR+4.0:
			var sign_color: Color = [Color("ff4fb0"), Color("37e0ff"), Color("ffe24f")][(i/4) % 3]
			_lit("block", base+basis*Vector3(width*.5-.4, top-base.y-5.0, -3.3), Vector3(.9, 6.0, .3), sign_color, Vector3(0, a, 0))

# ---------- Veranda: an engawa at night with pampas grass and the full moon ----------

func _veranda() -> void:
	turn = MENU_FACING
	_land(9.0)
	var wood := _c("wood", Color("8a6a50"))
	kit.add_rounded_box(Vector3(0, FLOOR+.2, 0), Vector3(15, .4, 15), wood, Vector3.ZERO, true, 10)
	for i in 10:
		kit.add("block", Vector3(-7.5+(i+.5)*1.5, FLOOR+.41, 0), Vector3(.05, .02, 14.8), wood.darkened(.3), Vector3.ZERO, false)
	# The house: plaster wall with warmly lit shoji, under a deep eave.
	var wall_z := -15.0
	kit.add("block", Vector3(0, FLOOR+5.0, wall_z-.3), Vector3(34, 10, .4), _c("plaster", Color("3a3350")))
	for p in 6:
		var x := -12.5+p*5.0
		_lit("block", Vector3(x, FLOOR+3.6, wall_z), Vector3(4.4, 6.2, .1), _c("paper", Color("ffe7a8")))
		for c in 3:
			kit.add("block", Vector3(x-1.1+c*1.1, FLOOR+3.6, wall_z+.12), Vector3(.1, 6.2, .08), _c("post", Color("2a2230")), Vector3.ZERO, false)
		for r in 4:
			kit.add("block", Vector3(x, FLOOR+1.2+r*1.6, wall_z+.12), Vector3(4.4, .1, .08), _c("post", Color("2a2230")), Vector3.ZERO, false)
		kit.add("block", Vector3(x+2.5, FLOOR+3.6, wall_z+.1), Vector3(.5, 7.2, .5), _c("post", Color("2a2230")))
	kit.add_rounded_box(Vector3(0, FLOOR+8.6, wall_z+2.0), Vector3(36, .7, 6.0), _c("roof", Color("2b2a3a")), Vector3(.28, 0, 0), true, 10)
	# Pampas grass along the garden edge, away from the house.
	for cluster in 14:
		var a := rng.randf_range(-2.3, 2.3)
		var r := rng.randf_range(9.5, 14.0)
		var base := Vector3(sin(a)*r, FLOOR, cos(a)*r)
		for stalk in 7:
			var tip := base+Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(2.6, 4.2), rng.randf_range(-1.2, 1.2))
			_rod(base, tip, .06, Color("8a9a5a"), false)
			var lean := (tip-base).normalized()
			kit.add("sphere", tip+lean*.4, Vector3(.28, 1.2, .28), Color("f1e3bf"), Vector3(lean.z*1.2, 0, -lean.x*1.2), false)
	# Tsukimi dango on a little stand.
	var stand := Vector3(6.0, FLOOR+.4, 4.0)
	kit.add_rounded_box(stand+Vector3(0, .5, 0), Vector3(1.4, 1.0, 1.4), Color("d9b27a"), Vector3.ZERO, true, 10)
	var layers := [[Vector2(-.3, -.3), Vector2(.3, -.3), Vector2(-.3, .3), Vector2(.3, .3)], [Vector2(0, 0)]]
	for level in layers.size():
		for spot in layers[level]:
			kit.add("sphere", stand+Vector3(spot.x, 1.3+level*.45, spot.y), Vector3(.55, .5, .55), Color("fffaf0"))
	_lit("fine", Vector3(0, 13.0, 62.0), Vector3.ONE*12.0, _c("moon", Color("fff4c4")))
	# Garden on the moon side: a koi pond, a maple, a stone lantern and a bamboo fence.
	var pond := Vector3(-5.0, FLOOR, 12.0)
	kit.add("cylinder", pond+Vector3(0, .05, 0), Vector3(7.0, .1, 4.8), _c("water", Color("3f6f86")), Vector3.ZERO, false)
	for i in 14:
		var a := TAU*i/14.0
		kit.add("fine", pond+Vector3(sin(a)*3.6, .3, cos(a)*2.5), Vector3(1.1, .7, .9), STONE.darkened(.35), Vector3(0, a, 0))
	for i in 4:
		kit.add("sphere", pond+Vector3(sin(i*2.1)*1.6, .14, cos(i*1.4)*1.0), Vector3(.6, .08, .26), [Color("ff7a2f"), Color("fff4e0")][i % 2], Vector3(0, i*1.3, 0), false)
	_tree(Vector3(7.5, FLOOR, 14.5), 5.0, Color("4a3428"), [Color("c9483a"), Color("e07a3a")])
	_stone_lantern(Vector3(-1.0, FLOOR, 9.5))
	for i in 26:
		var x := -13.0+i*1.0
		kit.add("cylinder", Vector3(x, FLOOR+1.4, 19.0), Vector3(.3, 2.8, .3), Color("8a7a4a"))
	_rod(Vector3(-13, FLOOR+2.2, 19.0), Vector3(12, FLOOR+2.2, 19.0), .12, Color("3a2a1a"), false)
