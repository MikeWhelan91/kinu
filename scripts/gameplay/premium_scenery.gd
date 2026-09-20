class_name PremiumScenery
extends RoomScenery
## The rooms added with the Kinu Catcher. Same rules as RoomScenery: the counter, box, camera and
## physics never change, showpieces face the home screen, and anything tall stays outside the
## camera's orbit.

const LAYOUTS := ["arcade", "dragon_palace", "moon_base", "sky_shrine", "tea_fields", "sweets", "aurora", "beach", "lantern_river", "castle"]
const PASTELS := [Color("ff8fb1"), Color("7fd4e8"), Color("ffd84d"), Color("9ccc5a"), Color("b99cf2"), Color("ffffff")]

func build_layout(layout: String) -> void:
	match layout:
		"arcade":
			_arcade()
		"dragon_palace":
			_dragon_palace()
		"moon_base":
			_moon_base()
		"sky_shrine":
			_sky_shrine()
		"tea_fields":
			_tea_fields()
		"sweets":
			_sweets()
		"aurora":
			_aurora()
		"beach":
			_beach()
		"lantern_river":
			_lantern_river()
		"castle":
			_castle()

## A flat ground disc out to the horizon.
func _ground(color: Color) -> void:
	kit.add("cylinder", Vector3(0, FLOOR-.2, 0), Vector3(150, .4, 150), color, Vector3.ZERO, false)

## Soft distant hills or mounds, without the grass and flowers `_land` scatters.
func _horizon(color: Color, count: int = 16, low: float = 18.0, high: float = 34.0) -> void:
	for i in count:
		var a := TAU*i/count+rng.randf_range(-.1, .1)
		var r := rng.randf_range(62.0, 72.0)
		kit.add("fine", Vector3(sin(a)*r, FLOOR, cos(a)*r), Vector3(rng.randf_range(34, 50), rng.randf_range(low, high), 30), color.darkened(rng.randf_range(0, .12)), Vector3(0, a, 0), false)

## A local-space helper for props turned to face `facing`.
func _place(at: Vector3, facing: float, local: Vector3) -> Vector3:
	return at+Basis(Vector3.UP, facing)*local

# ---------- Game Centre: rings of cabinets and claw machines under neon ----------

func _arcade() -> void:
	var tile := _c("floor", Color("241c3d"))
	kit.add("block", Vector3(0, FLOOR-.3, 0), Vector3(70, .6, 70), tile)
	for i in range(-10, 11):
		for j in range(-10, 11):
			if (i+j) % 2 == 0 and Vector2(i, j).length() < 10.5:
				kit.add("block", Vector3(i*2.4, FLOOR+.01, j*2.4), Vector3(2.38, .02, 2.38), _c("floor_line", Color("33285a")), Vector3.ZERO, false)
	for i in 64:
		var a := TAU*i/64.0
		_lit("block", Vector3(sin(a)*10.6, FLOOR+.03, cos(a)*10.6), Vector3(1.1, .04, .12), [Color("ff4fb0"), Color("37e0ff")][i % 2], Vector3(0, a+PI*.5, 0))
	# Back wall with neon tubes.
	for i in 32:
		var a := TAU*i/32.0
		var at := Vector3(sin(a)*26.0, FLOOR, cos(a)*26.0)
		kit.add("block", at+Vector3(0, 8.0, 0), Vector3(5.4, 16.0, .6), _c("plaster", Color("1c1533")), Vector3(0, a, 0), false)
		_lit("block", at+Vector3(0, 11.5, 0)-Vector3(sin(a), 0, cos(a))*.4, Vector3(5.4, .22, .1), [Color("ff4fb0"), Color("37e0ff"), Color("ffe24f")][i % 3], Vector3(0, a, 0))
		_lit("block", at+Vector3(0, 3.0, 0)-Vector3(sin(a), 0, cos(a))*.4, Vector3(5.4, .12, .1), Color("b98cff"), Vector3(0, a, 0))
	var colors := [Color("e2445c"), Color("3a7bd5"), Color("ffb62e"), Color("7a4fd0"), Color("23a58f")]
	for i in 18:
		var a := TAU*(i+.5)/18.0
		# Leave the showpiece claw machine room.
		var featured_gap := absf(wrapf(a-MENU_FACING, -PI, PI))
		if featured_gap < .45:
			continue
		var at := Vector3(sin(a)*16.0, FLOOR, cos(a)*16.0)
		if i % 3 == 0:
			_claw_machine(at, a, 1.0, colors[i % colors.size()])
		else:
			_cabinet(at, a, colors[i % colors.size()], PASTELS[i % 5])
	_claw_machine(_featured(Vector3(0, FLOOR, 17.0)), MENU_FACING, 2.3, Color("ff6f91"))
	# Capsule toy machines and a prize shelf just inside the ring.
	for i in 4:
		_capsule_toy(_featured(Vector3(-8.0+i*1.6, FLOOR, 10.5)), MENU_FACING, PASTELS[i])
	_prize_shelf(_featured(Vector3(7.5, FLOOR, 10.5)), MENU_FACING)
	for i in 10:
		var a := TAU*i/10.0+.3
		var at := Vector3(sin(a)*20.0, FLOOR+13.0, cos(a)*20.0)
		_lit("block", at, Vector3(4.0, 1.4, .2), [Color("ff4fb0"), Color("37e0ff"), Color("ffe24f")][i % 3], Vector3(0, a, 0))
		kit.add("block", at-Vector3(sin(a), 0, cos(a))*.15, Vector3(3.0, .5, .1), Color("140f2a"), Vector3(0, a, 0), false)

func _cabinet(at: Vector3, facing: float, body: Color, screen: Color) -> void:
	var yaw := Vector3(0, facing, 0)
	kit.add_rounded_box(_place(at, facing, Vector3(0, 2.3, 0)), Vector3(2.2, 4.6, 1.8), body, yaw, true, 8)
	_lit("block", _place(at, facing, Vector3(0, 3.0, -.92)), Vector3(1.6, 1.25, .06), screen, yaw)
	_lit("block", _place(at, facing, Vector3(0, 4.3, -.78)), Vector3(2.0, .5, .3), Color("fff1c4"), yaw)
	kit.add_rounded_box(_place(at, facing, Vector3(0, 1.8, -1.15)), Vector3(2.1, .3, .9), Color("2b2438"), yaw+Vector3(.35, 0, 0), true, 8)
	kit.add("sphere", _place(at, facing, Vector3(-.45, 2.1, -1.25)), Vector3(.24, .24, .24), Color("e8434f"))
	for b in 3:
		_lit("sphere", _place(at, facing, Vector3(.15+b*.28, 1.98, -1.3)), Vector3(.16, .1, .16), PASTELS[b])

## A claw machine: cabinet base, see-through case full of capsules, the claw and a lit marquee.
func _claw_machine(at: Vector3, facing: float, scale: float, body: Color) -> void:
	var yaw := Vector3(0, facing, 0)
	var s := scale
	kit.add_rounded_box(_place(at, facing, Vector3(0, 1.1*s, 0)), Vector3(3.0, 2.2, 3.0)*s, body, yaw, true, 8)
	kit.add("block", _place(at, facing, Vector3(-.7*s, 1.3*s, -1.52*s)), Vector3(.9, .8, .06)*s, Color("2b2438"), yaw)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			kit.add("cylinder", _place(at, facing, Vector3(x*1.42*s, 3.5*s, z*1.42*s)), Vector3(.12*s, 2.6*s, .12*s), Color("d9dde6"))
	kit.add_rounded_box(_place(at, facing, Vector3(0, 5.0*s, 0)), Vector3(3.2, .5, 3.2)*s, body, yaw, true, 8)
	_lit("block", _place(at, facing, Vector3(0, 5.55*s, -1.2*s)), Vector3(2.8*s, .7*s, .14*s), Color("fff1c4"), yaw)
	for i in 9:
		_lit("sphere", _place(at, facing, Vector3(-1.4*s+i*.35*s, 5.95*s, -1.35*s)), Vector3.ONE*.18*s, [Color("ff4fb0"), Color("ffe24f"), Color("37e0ff")][i % 3])
	for i in 16:
		var spot := Vector3(sin(i*2.4)*1.0, 2.35+fmod(i*.37, .6), cos(i*1.7)*1.0)*s
		var capsule := _place(at, facing, spot)
		kit.add("sphere", capsule, Vector3.ONE*.46*s, Color("f2fbff"))
		kit.add("sphere", capsule-Vector3.UP*.08*s, Vector3(.47, .26, .47)*s, PASTELS[i % 5], Vector3.ZERO, false)
	var claw := _place(at, facing, Vector3(.3*s, 4.1*s, .2*s))
	kit.add("cylinder", claw+Vector3.UP*.4*s, Vector3(.05, .8, .05)*s, Color("aab2c4"))
	kit.add("sphere", claw, Vector3(.4, .3, .4)*s, Color("d9dde6"))
	for p in 3:
		var a := TAU*p/3.0
		_rod(claw, claw+Vector3(sin(a)*.4, -.55, cos(a)*.4)*s, .06*s, Color("aab2c4"))

func _capsule_toy(at: Vector3, facing: float, tone: Color) -> void:
	var yaw := Vector3(0, facing, 0)
	kit.add_rounded_box(at+Vector3(0, .8, 0), Vector3(1.2, 1.6, 1.1), tone.darkened(.1), yaw, true, 8)
	kit.add("fine", at+Vector3(0, 2.2, 0), Vector3(1.2, 1.2, 1.2), Color("e6f7ff"))
	for i in 6:
		kit.add("sphere", at+Vector3(sin(i*2.2)*.3, 2.0+fmod(i*.29, .4), cos(i*1.6)*.3), Vector3.ONE*.26, PASTELS[i % 5], Vector3.ZERO, false)
	kit.add("cylinder", _place(at, facing, Vector3(0, 1.0, -.56)), Vector3(.5, .08, .5), Color("f7f3ea"), yaw+Vector3(PI*.5, 0, 0))
	kit.add("cylinder", at+Vector3(0, 2.85, 0), Vector3(.9, .15, .9), tone.darkened(.1))

func _prize_shelf(at: Vector3, facing: float) -> void:
	var yaw := Vector3(0, facing, 0)
	kit.add("block", _place(at, facing, Vector3(0, 1.8, .4)), Vector3(4.6, 3.6, .3), Color("3a2d5e"), yaw)
	for level in 3:
		kit.add("block", _place(at, facing, Vector3(0, .5+level*1.2, 0)), Vector3(4.6, .15, 1.0), Color("d9dde6"), yaw)
		for i in 5:
			var plush := _place(at, facing, Vector3(-1.8+i*.9, .85+level*1.2, -.1))
			kit.add_rounded_box(plush, Vector3(.62, .55, .5), [Color("fff5dc"), Color("ffd3e2"), Color("cdeefc"), Color("d8f3bd"), Color("ffe7a3")][(i+level) % 5], yaw, true, 6)
			for side in [-1.0, 1.0]:
				kit.add("sphere", _place(at, facing, Vector3(-1.8+i*.9+side*.12, .9+level*1.2, -.37)), Vector3(.06, .08, .03), Color("2b1a17"), yaw, false)

# ---------- Dragon Palace: an undersea palace among coral and kelp ----------

func _dragon_palace() -> void:
	turn = MENU_FACING
	_ground(_c("floor", Color("e6d7ae")))
	_horizon(_c("hills", Color("1c5a78")), 18, 12.0, 26.0)
	for i in 40:
		var at := _ring_spot(7.5, 30.0)
		kit.add("sphere", at+Vector3(0, .08, 0), Vector3(rng.randf_range(.6, 1.6), .16, rng.randf_range(.5, 1.3)), _c("floor", Color("e6d7ae")).darkened(.12), Vector3(0, rng.randf()*TAU, 0), false)
	var coral := [Color("ff7a8a"), Color("ffb35c"), Color("c77dff"), Color("ff9fc0"), Color("ffd166")]
	for i in 26:
		var at := _ring_spot(8.0, 22.0)
		if (at-Vector3(0, FLOOR, 22.0)).length() < 9.0:
			continue
		var tone: Color = coral[i % coral.size()]
		match i % 3:
			0:
				for branch in 5:
					var a := TAU*branch/5.0+rng.randf()
					var tip := at+Vector3(sin(a)*rng.randf_range(.4, .9), rng.randf_range(1.2, 2.4), cos(a)*rng.randf_range(.4, .9))
					_rod(at, tip, .18, tone)
					kit.add("sphere", tip, Vector3.ONE*.34, tone.lightened(.2))
			1:
				kit.add("fine", at+Vector3(0, .6, 0), Vector3(1.8, 1.3, 1.8), tone)
				for ring in 3:
					kit.add("torus", at+Vector3(0, .6+ring*.25-.2, 0), Vector3(1.7-ring*.3, .3, 1.7-ring*.3), tone.darkened(.2), Vector3.ZERO, false)
			2:
				kit.add("sphere", at+Vector3(0, 1.4, 0), Vector3(2.6, 2.4, .2), tone, Vector3(0, rng.randf()*TAU, 0))
				_rod(at, at+Vector3(0, .8, 0), .2, tone.darkened(.25))
	for i in 34:
		var at := _ring_spot(12.0, 30.0)
		var height := rng.randi_range(8, 14)
		for k in height:
			kit.add("sphere", at+Vector3(sin(k*.6+i)*.35, .5+k*.95, cos(k*.5+i)*.2), Vector3(.5, 1.1, .16), Color("4f9a55").lightened(fmod(k*.07, .2)), Vector3(0, i, sin(k*.6)*.3), false)
	_undersea_palace(Vector3(0, FLOOR, 25.0))
	# The gate on the path out to the palace.
	for side in [-1.0, 1.0]:
		kit.add("cylinder", Vector3(side*3.4, FLOOR+3.0, 14.0), Vector3(.7, 6.0, .7), Color("d8432f"))
		_lit("sphere", Vector3(side*3.4, FLOOR+6.4, 14.0), Vector3.ONE*.8, Color("fff1a8"))
	kit.add_rounded_box(Vector3(0, FLOOR+6.3, 14.0), Vector3(9.0, .6, 1.4), Color("2f9a8a"), Vector3.ZERO, true, 6)
	kit.add_rounded_box(Vector3(0, FLOOR+6.9, 14.0), Vector3(10.4, .35, 2.0), Color("237a6e"), Vector3.ZERO, true, 6)
	for i in 6:
		kit.add("cylinder", Vector3(sin(i*.9)*.8, FLOOR+.05, 8.5+i*1.0), Vector3(1.4, .1, 1.0), Color("f3e6c4"), Vector3(0, i, 0))
	# A giant clam holding a glowing pearl.
	var clam := Vector3(-7.0, FLOOR, 9.0)
	kit.add("fine", clam+Vector3(0, .5, 0), Vector3(3.2, 1.0, 2.6), Color("e8c3e6"))
	kit.add("fine", clam+Vector3(0, 1.6, -1.0), Vector3(3.2, .9, 2.6), Color("f1d4ef"), Vector3(-1.0, 0, 0))
	for r in 6:
		kit.add("sphere", clam+Vector3(-1.2+r*.48, .95, .2), Vector3(.08, .14, 2.2), Color("c9a0c8"), Vector3.ZERO, false)
	_lit("sphere", clam+Vector3(0, 1.25, .2), Vector3.ONE*.95, Color("fff6fb"))
	# Schools of fish hanging in the water, and glowing jellyfish.
	for school in 6:
		var a := TAU*school/6.0+.4
		var center := Vector3(sin(a)*15.0, FLOOR+5.0+school % 3*2.0, cos(a)*15.0)
		var tone: Color = [Color("ffb62e"), Color("3fa9f5"), Color("ff6f91")][school % 3]
		for f in 8:
			var at := center+Vector3(sin(f*2.1)*1.8, cos(f*1.3)*.9, cos(f*2.7)*1.8)
			var heading := a+PI*.5
			kit.add("sphere", at, Vector3(.7, .4, .25), tone, Vector3(0, heading, 0))
			kit.add("cone", at-Vector3(cos(heading), 0, -sin(heading))*.45, Vector3(.35, .35, .1), tone.darkened(.15), Vector3(0, heading, PI*.5))
	for i in 7:
		var a := TAU*i/7.0
		var at := Vector3(sin(a)*11.5, FLOOR+6.0+sin(i*1.7)*1.5, cos(a)*11.5)
		_lit("sphere", at, Vector3(1.4, 1.0, 1.4), Color("ffb3dc"))
		for t in 5:
			var b := TAU*t/5.0
			kit.add("cylinder", at+Vector3(sin(b)*.4, -1.1, cos(b)*.4), Vector3(.06, 1.6, .06), Color("ffd6ec"), Vector3(sin(b)*.2, 0, cos(b)*.2), false)

func _undersea_palace(at: Vector3) -> void:
	var red := Color("d8432f")
	var jade := Color("2f9a8a")
	var gold := Color("f5c14e")
	kit.add("block", at+Vector3(0, .8, 0), Vector3(20, 1.6, 12), Color("f3e6c4"))
	kit.add("block", at+Vector3(0, 1.7, -7.0), Vector3(8, .3, 2.0), Color("e6d7ae"))
	for tier in 3:
		var width := 16.0-tier*4.5
		var base := 1.6+tier*5.2
		kit.add("block", at+Vector3(0, base+2.1, 0), Vector3(width-2.0, 4.2, 8.0-tier*1.8), Color("fff4e0"))
		for p in 5:
			kit.add("cylinder", at+Vector3(-width*.4+p*width*.2, base+2.1, -(4.0-tier*.9)-.1), Vector3(.5, 4.2, .5), red)
		for w in 3:
			_lit("block", at+Vector3(-width*.25+w*width*.25, base+2.4, -(4.0-tier*.9)-.15), Vector3(1.0, 1.6, .1), Color("ffd98a"))
		kit.add_rounded_box(at+Vector3(0, base+4.6, 0), Vector3(width+2.2, .7, 10.0-tier*1.8), jade, Vector3.ZERO, true, 6)
		kit.add_rounded_box(at+Vector3(0, base+5.1, 0), Vector3(width, .5, 8.4-tier*1.8), jade.darkened(.15), Vector3.ZERO, true, 6)
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				kit.add("cone", at+Vector3(x*(width*.5+1.0), base+5.0, z*(5.0-tier*.9)), Vector3(.45, 1.0, .45), gold, Vector3(z*-.6, 0, x*.6))
	kit.add("sphere", at+Vector3(0, 18.8, 0), Vector3.ONE*1.2, gold)
	kit.add("cone", at+Vector3(0, 20.0, 0), Vector3(.5, 1.6, .5), gold)

# ---------- Moon Base: domes, a rocket and the Earth rising ----------

func _moon_base() -> void:
	var dust := _c("floor", Color("c9c6d2"))
	_ground(dust)
	_horizon(_c("hills", Color("8e8a9c")), 18, 8.0, 18.0)
	for i in 22:
		var at := _ring_spot(8.5, 45.0)
		var radius := rng.randf_range(1.2, 4.5)
		kit.add("cylinder", at+Vector3(0, .03, 0), Vector3(radius*1.7, .06, radius*1.7), dust.darkened(.18), Vector3.ZERO, false)
		for k in 14:
			var a := TAU*k/14.0
			kit.add("sphere", at+Vector3(sin(a)*radius, .12, cos(a)*radius), Vector3(radius*.55, radius*.14, radius*.35), dust.lightened(.06), Vector3(0, a, 0), false)
	for i in 30:
		var at := _ring_spot(7.0, 30.0)
		kit.add("fine", at+Vector3(0, .2, 0), Vector3(rng.randf_range(.5, 1.4), rng.randf_range(.3, .8), rng.randf_range(.5, 1.2)), dust.darkened(rng.randf_range(.2, .4)), Vector3(0, rng.randf()*TAU, 0))
	var domes := [Vector3(-10.0, FLOOR, 15.0), Vector3(0, FLOOR, 21.0), Vector3(10.0, FLOOR, 14.0)]
	for i in domes.size():
		var dome := _featured(domes[i])
		var radius := 6.0 if i == 1 else 4.5
		kit.add("fine", dome, Vector3(radius*2, radius*1.6, radius*2), Color("eef0f6"))
		_lit("torus", dome+Vector3(0, radius*.35, 0), Vector3(radius*2.05, .6, radius*2.05), Color("7ff0ff"))
		kit.add("cylinder", dome+Vector3(0, radius*.62, 0), Vector3(radius*.8, .3, radius*.8), Color("b9c0cc"))
	for pair in [[0, 1], [1, 2]]:
		_rod(_featured(domes[pair[0]]+Vector3(0, 1.2, 0)), _featured(domes[pair[1]]+Vector3(0, 1.2, 0)), .9, Color("d9dde6"))
	_rocket(_featured(Vector3(-17.0, FLOOR, 24.0)))
	_rover(_featured(Vector3(5.5, FLOOR, 8.5)), MENU_FACING+.6)
	var flag := _featured(Vector3(-4.5, FLOOR, 8.5))
	kit.add("cylinder", flag+Vector3(0, 2.0, 0), Vector3(.1, 4.0, .1), Color("d9dde6"))
	kit.add("block", flag+Basis(Vector3.UP, MENU_FACING)*Vector3(.9, 3.4, 0), Vector3(1.8, 1.1, .05), Color("e8434f"), Vector3(0, MENU_FACING, 0))
	kit.add_rounded_box(flag+Basis(Vector3.UP, MENU_FACING)*Vector3(.9, 3.4, -.04), Vector3(.55, .5, .04), Color("fff4df"), Vector3(0, MENU_FACING, 0), false, 6)
	for i in 3:
		var panel := _featured(Vector3(13.0+i*2.6, FLOOR, 6.0+i*1.2))
		kit.add("cylinder", panel+Vector3(0, .8, 0), Vector3(.12, 1.6, .12), Color("aab2c4"))
		kit.add("block", panel+Vector3(0, 1.7, 0), Vector3(2.2, .08, 1.4), Color("2d3f7a"), Vector3(.5, MENU_FACING, 0))
	var dish := _featured(Vector3(-13.0, FLOOR, 8.0))
	kit.add("cylinder", dish+Vector3(0, 1.4, 0), Vector3(.3, 2.8, .3), Color("aab2c4"))
	kit.add("fine", dish+Vector3(0, 3.4, 0), Vector3(3.4, .6, 3.4), Color("eef0f6"), Vector3(-.7, MENU_FACING, 0))
	# The Earth hangs low in the black sky.
	var earth := _featured(Vector3(18.0, 26.0, 70.0))
	_lit("fine", earth, Vector3.ONE*16.0, Color("3f86e0"))
	for i in 7:
		var land := earth+Vector3(sin(i*2.3)*4.0, cos(i*1.7)*4.5, 0)+(Vector3.ZERO-earth).normalized()*6.4
		_lit("sphere", land, Vector3(rng.randf_range(2.0, 4.0), rng.randf_range(1.5, 3.0), 2.0), Color("5fcf6a"))
	for i in 5:
		var cloud := earth+Vector3(cos(i*2.0)*5.0, sin(i*1.1)*5.0, 0)+(Vector3.ZERO-earth).normalized()*7.4
		_lit("sphere", cloud, Vector3(3.5, .8, 1.5), Color("ffffff"))

func _rocket(at: Vector3) -> void:
	for x in [-2.4, 2.4]:
		kit.add("block", at+Vector3(x, 7.0, 2.2), Vector3(.35, 14.0, .35), Color("e8434f"))
	for y in [3.0, 7.0, 11.0]:
		kit.add("block", at+Vector3(0, y, 2.2), Vector3(5.0, .3, .3), Color("e8434f"))
	kit.add("cylinder", at+Vector3(0, 6.5, 0), Vector3(2.6, 11.0, 2.6), Color("f4f5f9"))
	kit.add("cone", at+Vector3(0, 14.0, 0), Vector3(2.6, 4.0, 2.6), Color("e8434f"))
	for i in 3:
		var a := TAU*i/3.0
		kit.add("block", at+Vector3(sin(a)*1.6, 2.0, cos(a)*1.6), Vector3(.25, 3.0, 1.6), Color("e8434f"), Vector3(0, a+PI*.5, .2))
	_lit("sphere", at+Vector3(0, 9.5, 1.3), Vector3(1.1, 1.1, .3), Color("9fe8ff"))
	kit.add("torus", at+Vector3(0, 9.5, 1.3), Vector3(1.3, .5, 1.3), Color("aab2c4"), Vector3(PI*.5, 0, 0))

func _rover(at: Vector3, facing: float) -> void:
	var yaw := Vector3(0, facing, 0)
	kit.add_rounded_box(at+Vector3(0, 1.2, 0), Vector3(2.6, .8, 1.8), Color("f4f5f9"), yaw, true, 8)
	for i in 3:
		for side in [-1.0, 1.0]:
			kit.add("cylinder", _place(at, facing, Vector3(-1.0+i*1.0, .5, side*1.05)), Vector3(.9, .3, .9), Color("4a4650"), yaw+Vector3(PI*.5, 0, 0))
	kit.add("block", _place(at, facing, Vector3(-.4, 1.75, 0)), Vector3(1.6, .06, 1.6), Color("2d3f7a"), yaw)
	kit.add("cylinder", _place(at, facing, Vector3(1.0, 2.3, .5)), Vector3(.06, 1.4, .06), Color("aab2c4"))
	_lit("sphere", _place(at, facing, Vector3(1.0, 3.0, .5)), Vector3.ONE*.22, Color("ff3b3b"))
	_lit("sphere", _place(at, facing, Vector3(1.32, 1.2, .5)), Vector3(.1, .25, .25), Color("fff1c4"))

# ---------- Sky Shrine: a shrine on floating islands above the clouds ----------

func _sky_shrine() -> void:
	turn = MENU_FACING
	var cloud := _c("floor", Color("fff6f4"))
	_ground(cloud)
	for i in 70:
		var at := _ring_spot(9.0, 50.0)
		var puff := rng.randf_range(2.0, 5.5)
		for k in 3:
			kit.add("sphere", at+Vector3(k*puff*.45-puff*.45, puff*.18+k % 2*puff*.12, sin(k*2.0)*puff*.3), Vector3(puff, puff*.55, puff*.8), cloud.darkened(rng.randf_range(0, .06)).lerp(Color("ffd3e2"), rng.randf_range(0, .25)), Vector3(0, rng.randf()*TAU, 0), false)
	kit.add("cylinder", Vector3(0, FLOOR+.2, 0), Vector3(15.0, .4, 15.0), Color("e8e2da"))
	kit.add("torus", Vector3(0, FLOOR+.42, 0), Vector3(15.0, .5, 15.0), Color("f5c14e"), Vector3.ZERO, false)
	# Stone steps climb from the plaza to the shrine island.
	for i in 12:
		kit.add("block", Vector3(0, FLOOR+.3+i*.55, 8.0+i*1.1), Vector3(4.2, .5, 1.2), Color("e8e2da"))
	_torii(Vector3(0, FLOOR+.4, 10.5), 0.0)
	var islands := [Vector3(0, FLOOR+6.0, 24.0), Vector3(-18.0, FLOOR+3.0, 16.0), Vector3(19.0, FLOOR+9.0, 18.0), Vector3(-28.0, FLOOR+11.0, -6.0), Vector3(26.0, FLOOR+5.0, -14.0), Vector3(2.0, FLOOR+14.0, -30.0)]
	for i in islands.size():
		var at: Vector3 = islands[i]
		var radius := 9.0 if i == 0 else rng.randf_range(3.5, 5.5)
		kit.add("cylinder", at, Vector3(radius*2, .8, radius*2), Color("8fcf6a"))
		kit.add("cone", at-Vector3(0, radius*.9, 0), Vector3(radius*2, radius*1.8, radius*2), Color("a88a6a"), Vector3(PI, 0, 0))
		if i > 0:
			_tree(at, 3.5, Color("6b4a33"), [Color("ffb3c8"), Color("ffc9d6")])
			if i % 2 == 0:
				kit.add("block", at+Vector3(radius*.8, -radius*.9, 0), Vector3(.8, radius*1.8, .2), Color("eaf8ff"), Vector3(0, 0, 0), false)
	_shrine_hall(islands[0]+Vector3(0, .4, 2.0))
	# A rainbow arcs over everything, and the morning sun.
	for band in 6:
		for k in 36:
			var a := PI*k/35.0
			var radius := 40.0-band*1.4
			_lit("sphere", Vector3(cos(a)*radius, FLOOR+sin(a)*radius-2.0, 62.0), Vector3(2.2, 2.2, .8), KinuModel.RAINBOW[band])
	_lit("fine", Vector3(-30.0, 30.0, 80.0), Vector3.ONE*12.0, Color("fff1b8"))

func _shrine_hall(at: Vector3) -> void:
	var red := Color("d8432f")
	kit.add("block", at+Vector3(0, .6, 0), Vector3(12, 1.2, 8), Color("e8e2da"))
	kit.add("block", at+Vector3(0, 3.6, 0), Vector3(9, 4.8, 5.5), Color("fffaf0"))
	for x in [-4.0, -1.3, 1.3, 4.0]:
		kit.add("cylinder", at+Vector3(x, 3.6, -2.9), Vector3(.55, 4.8, .55), red)
	kit.add_rounded_box(at+Vector3(0, 6.4, 0), Vector3(13, .7, 9.0), Color("6b4a33"), Vector3.ZERO, true, 6)
	kit.add_rounded_box(at+Vector3(0, 7.3, 0), Vector3(9, 1.4, 6.0), Color("5a3a28"), Vector3.ZERO, true, 4)
	kit.add("block", at+Vector3(0, 8.1, 0), Vector3(9.6, .3, .5), Color("f5c14e"))
	for x in [-3.0, 3.0]:
		kit.add("block", at+Vector3(x, 8.6, 0), Vector3(.2, 1.2, .2), Color("f5c14e"), Vector3(0, 0, x*.08))
	# Shimenawa rope with paper streamers across the front.
	_rod(at+Vector3(-4.0, 5.7, -3.1), at+Vector3(4.0, 5.7, -3.1), .3, Color("e8cf8a"))
	for i in 4:
		kit.add("block", at+Vector3(-2.4+i*1.6, 5.1, -3.2), Vector3(.35, .9, .05), Color("ffffff"), Vector3(0, 0, .1*(i % 2)))
	_lit("block", at+Vector3(0, 3.2, -2.8), Vector3(2.6, 2.8, .1), Color("ffe7a8"))

# ---------- Fuji Tea Fields: rows of tea under Mt Fuji ----------

func _tea_fields() -> void:
	turn = MENU_FACING
	_land(7.5)
	var tea := Color("3f8a43")
	for row in range(-12, 13):
		var z := row*2.6
		var x := -34.0
		while x < 34.0:
			if Vector2(x, z).length() > 8.5 and not (absf(x) < 2.0 and z > 0):
				kit.add("sphere", Vector3(x, FLOOR+.7, z), Vector3(4.2, 1.6, 1.9), tea.lightened(fmod(absf(x*.13+z*.07), .12)))
			x += 3.8
	# The stone path through the rows, lined with lanterns.
	for i in 12:
		kit.add("cylinder", Vector3(sin(i*.8)*.4, FLOOR+.05, 6.5+i*2.4), Vector3(1.4, .12, 1.1), STONE, Vector3(0, i*.6, 0))
	for side in [-1.0, 1.0]:
		for z in [10.0, 20.0]:
			_stone_lantern(Vector3(side*2.6, FLOOR, z))
	# Frost fans on poles, a tea house and baskets of picked leaves.
	for i in 12:
		var a := TAU*i/12.0+.2
		var at := Vector3(sin(a)*rng.randf_range(12.0, 24.0), FLOOR, cos(a)*rng.randf_range(12.0, 24.0))
		kit.add("cylinder", at+Vector3(0, 3.5, 0), Vector3(.25, 7.0, .25), Color("aab2c4"))
		kit.add_rounded_box(at+Vector3(0, 7.1, .3), Vector3(.6, .6, .8), Color("d9dde6"), Vector3(-.4, a, 0), true, 6)
		for blade in 3:
			kit.add("sphere", at+Vector3(0, 7.1, .8)+Basis(Vector3.UP, a)*Basis(Vector3.BACK, TAU*blade/3.0)*Vector3(0, .7, 0), Vector3(.35, 1.4, .08), Color("f4f5f9"), Vector3(-.4, a, TAU*blade/3.0), false)
	_hut(Vector3(-13.0, FLOOR, 19.0), 0.0, Color("e8d7b5"), Color("4a4650"))
	for i in 3:
		var basket := Vector3(5.5+i*1.3, FLOOR, 8.0+i*.4)
		kit.add("cylinder", basket+Vector3(0, .5, 0), Vector3(1.0, 1.0, 1.0), Color("c9a26b"))
		kit.add("sphere", basket+Vector3(0, 1.0, 0), Vector3(.9, .35, .9), Color("5ea85a"))
	var fuji := Vector3(0, FLOOR, 56.0)
	kit.add("cone", fuji+Vector3(0, 19.0, 0), Vector3(96.0, 38.0, 60.0), _c("mountain", Color("6f86b8")), Vector3.ZERO, false)
	kit.add("cone", fuji+Vector3(0, 32.0, -1.0), Vector3(32.0, 12.0, 20.0), Color("f8fbff"), Vector3.ZERO, false)
	for i in 7:
		var x := -12.0+i*4.0
		kit.add("cone", fuji+Vector3(x, 25.5-absf(x)*.15, 6.5-absf(x)*.2), Vector3(3.0, 3.5, 1.0), Color("f8fbff"), Vector3(PI, 0, 0), false)

# ---------- Wagashi Land: giant sweets on pink icing ----------

func _sweets() -> void:
	turn = MENU_FACING
	var icing := _c("floor", Color("ffcfe0"))
	_ground(icing)
	var mochi := [Color("fffaf2"), Color("ffd3e2"), Color("d8f3bd"), Color("ffe7a3")]
	for i in 16:
		var a := TAU*i/16.0
		var r := rng.randf_range(60.0, 70.0)
		kit.add("fine", Vector3(sin(a)*r, FLOOR, cos(a)*r), Vector3(rng.randf_range(30, 44), rng.randf_range(16, 28), 30), mochi[i % mochi.size()], Vector3(0, a, 0), false)
	for i in 14:
		var at := _ring_spot(7.5, 26.0)
		kit.add("cylinder", at+Vector3(0, .04, 0), Vector3(rng.randf_range(2.0, 4.0), .08, rng.randf_range(1.6, 3.0)), Color("fffaf2"), Vector3(0, rng.randf()*TAU, 0), false)
	for i in 12:
		var a := TAU*i/12.0+.3
		if absf(wrapf(a, -PI, PI)) < .5:
			continue
		var at := Vector3(sin(a)*rng.randf_range(12.0, 22.0), FLOOR, cos(a)*rng.randf_range(12.0, 22.0))
		_dango(at, rng.randf_range(-.25, .25), i % 3 == 0)
	for i in 18:
		var at := _ring_spot(7.0, 20.0)+Vector3(0, .4, 0)
		var tone: Color = PASTELS[i % 5]
		kit.add("sphere", at, Vector3.ONE*.8, tone)
		for k in 8:
			var dir := Vector3(sin(k*2.4), cos(k*1.3), cos(k*2.4)).normalized()
			kit.add_transformed("cone", Transform3D(Basis(Quaternion(Vector3.UP, dir))*Basis.from_scale(Vector3(.22, .3, .22)), at+dir*.4), tone, false)
	for i in 8:
		var at := _ring_spot(14.0, 26.0)
		var tone: Color = PASTELS[i % 5]
		kit.add("cylinder", at+Vector3(0, 2.5, 0), Vector3(.25, 5.0, .25), Color("fffaf2"))
		kit.add("cylinder", at+Vector3(0, 5.6, 0), Vector3(3.2, .5, 3.2), tone, Vector3(PI*.5, rng.randf()*TAU, 0))
		kit.add("torus", at+Vector3(0, 5.6, 0), Vector3(2.2, .9, 2.2), Color("fffaf2"), Vector3(PI*.5, 0, 0), false)
	_cake_castle(Vector3(0, FLOOR, 24.0))
	var taiyaki := Vector3(-8.0, FLOOR, 11.0)
	var brown := Color("d9924a")
	kit.add("fine", taiyaki+Vector3(0, 2.2, 0), Vector3(4.4, 3.2, 1.2), brown, Vector3(0, .3, 0))
	kit.add("cone", taiyaki+Vector3(2.4, 2.2, -.7), Vector3(2.0, 1.6, .9), brown.darkened(.08), Vector3(0, .3, -PI*.5))
	kit.add("sphere", taiyaki+Vector3(-1.2, 2.7, .5), Vector3(.4, .4, .15), Color("2b1a17"), Vector3(0, .3, 0), false)
	for i in 5:
		kit.add("sphere", taiyaki+Vector3(-.2+i*.45, 2.0+sin(i)*.3, .45-i*.13), Vector3(.5, .3, .1), brown.darkened(.18), Vector3(0, .3, 0), false)
	kit.add("block", taiyaki+Vector3(0, .5, 0), Vector3(2.4, 1.0, 1.4), Color("fffaf2"), Vector3(0, .3, 0))

func _dango(at: Vector3, lean: float, glazed: bool) -> void:
	var tip := at+Vector3(lean*4.0, 8.0, 0)
	_rod(at, tip, .18, Color("e8c48a"))
	var colors := [Color("ff9fbf"), Color("fffaf2"), Color("9ccc5a")]
	if glazed:
		colors = [Color("e8b04a"), Color("e8b04a"), Color("e8b04a")]
	for i in 3:
		var ball := at.lerp(tip, .45+i*.17)
		kit.add("fine", ball, Vector3(2.0, 1.8, 2.0), colors[i])
		if glazed:
			kit.add("sphere", ball+Vector3(0, .5, .4), Vector3(1.0, .3, .6), Color("f5d27a"), Vector3.ZERO, false)

func _cake_castle(at: Vector3) -> void:
	var tiers := [[10.0, 3.0], [7.5, 2.8], [5.0, 2.6]]
	var y := 0.0
	for i in tiers.size():
		var width: float = tiers[i][0]
		var height: float = tiers[i][1]
		kit.add("cylinder", at+Vector3(0, y+height*.5, 0), Vector3(width, height, width), Color("fff4e0"))
		kit.add("cylinder", at+Vector3(0, y+height*.55, 0), Vector3(width+.1, .5, width+.1), Color("ff9fbf"), Vector3.ZERO, false)
		for k in 14:
			var a := TAU*k/14.0
			kit.add("sphere", at+Vector3(sin(a)*width*.5, y+height, cos(a)*width*.5), Vector3(.9, .6, .9), Color("fffaf2"))
			kit.add("sphere", at+Vector3(sin(a)*width*.5, y+height-.5, cos(a)*width*.5), Vector3(.3, .9, .3), Color("fffaf2"), Vector3.ZERO, false)
			if k % 2 == 0:
				kit.add("cone", at+Vector3(sin(a)*width*.42, y+height+.5, cos(a)*width*.42), Vector3(.6, .7, .6), Color("e8434f"), Vector3(PI, 0, 0))
		y += height
	for i in 5:
		var a := TAU*i/5.0
		kit.add("cylinder", at+Vector3(sin(a)*1.4, y+1.0, cos(a)*1.4), Vector3(.3, 2.0, .3), PASTELS[i])
		_lit("sphere", at+Vector3(sin(a)*1.4, y+2.2, cos(a)*1.4), Vector3(.3, .5, .3), Color("ffd46b"))
	for side in [-1.0, 1.0]:
		var tower := at+Vector3(side*7.0, 0, -1.0)
		kit.add("cylinder", tower+Vector3(0, 3.5, 0), Vector3(1.8, 7.0, 1.8), Color("e8b87a"))
		for band in 6:
			kit.add("torus", tower+Vector3(0, .6+band*1.1, 0), Vector3(1.85, .5, 1.85), Color("6b3f2a"), Vector3(0, 0, .15), false)
		kit.add("cone", tower+Vector3(0, 8.0, 0), Vector3(2.4, 2.0, 2.4), Color("ff9fbf"))

# ---------- Aurora Snowfield: an igloo under the northern lights ----------

func _aurora() -> void:
	turn = MENU_FACING
	var snow := _c("floor", Color("e7eef8"))
	_ground(snow)
	_horizon(_c("hills", Color("cfdced")), 16, 14.0, 26.0)
	for i in 30:
		var at := _ring_spot(8.0, 30.0)
		kit.add("sphere", at+Vector3(0, .2, 0), Vector3(rng.randf_range(1.6, 3.6), rng.randf_range(.5, 1.2), rng.randf_range(1.4, 3.0)), snow.lightened(.4), Vector3(0, rng.randf()*TAU, 0))
	for i in 24:
		var at := _ring_spot(13.0, 28.0)
		if at.z > 6.0 and absf(at.x) < 12.0:
			continue
		_pine(at, rng.randf_range(7.0, 12.0))
	var lake := Vector3(7.0, FLOOR, 12.0)
	kit.add("cylinder", lake+Vector3(0, .05, 0), Vector3(10.0, .1, 7.0), Color("bfe6f5"), Vector3.ZERO, false)
	for i in 5:
		kit.add("block", lake+Vector3(sin(i*2.1)*2.0, .11, cos(i*1.4)*1.5), Vector3(2.4, .02, .06), Color("eaf8ff"), Vector3(0, i*.9, 0), false)
	var igloo := Vector3(-6.0, FLOOR, 12.0)
	kit.add("fine", igloo, Vector3(6.0, 5.0, 6.0), Color("fbfdff"))
	for ring in 3:
		kit.add("torus", igloo+Vector3(0, .7+ring*.75, 0), Vector3(5.8-ring*.9, .25, 5.8-ring*.9), Color("dce8f5"), Vector3.ZERO, false)
	kit.add("fine", igloo+Vector3(0, .6, -2.9), Vector3(2.4, 2.2, 2.4), Color("fbfdff"))
	_lit("fine", igloo+Vector3(0, .7, -4.05), Vector3(1.4, 1.5, .3), Color("ffcf7a"))
	_snowman(Vector3(1.0, FLOOR, 9.5))
	for side in [-1.0, 1.0]:
		_lantern_post(Vector3(-6.0+side*3.6, FLOOR, 8.0))
	# Northern lights: glowing curtains rippling across the sky.
	var bands := [Color("5dffb0"), Color("3fe0d0"), Color("62b8ff"), Color("b58cff")]
	for layer in 2:
		for i in 64:
			var a := -1.5+i*3.0/63.0
			var radius := 50.0+layer*8.0
			var at := Vector3(sin(a)*radius, FLOOR+22.0+sin(i*.35+layer)*4.0+layer*6.0, cos(a)*radius)
			var tone: Color = bands[int(i/16.0+layer) % bands.size()].lerp(bands[int(i/16.0+layer+1) % bands.size()], fmod(i/16.0, 1.0))
			_lit("block", at, Vector3(2.8, 12.0-absf(sin(i*.2))*5.0, .2), tone, Vector3(0, a, sin(i*.3)*.15))
	_lit("fine", Vector3(-22.0, 34.0, 60.0), Vector3.ONE*5.0, Color("fff4d0"))

# ---------- Summer Beach: parasols, palms and a lighthouse over the sea ----------

func _beach() -> void:
	turn = MENU_FACING
	var sand := _c("floor", Color("f3dca8"))
	_ground(sand)
	var water := _c("water", Color("4fc3e0"))
	kit.add("block", Vector3(0, FLOOR+.03, 60.0), Vector3(240, .1, 94), water, Vector3.ZERO, false)
	kit.add("block", Vector3(0, FLOOR+.02, 14.5), Vector3(240, .08, 3.0), water.lightened(.35), Vector3.ZERO, false)
	for i in 30:
		kit.add("sphere", Vector3(-58.0+i*4.0, FLOOR+.1, 13.2+sin(i*1.3)*.4), Vector3(3.6, .2, .9), Color("ffffff"), Vector3.ZERO, false)
	for band in 4:
		for i in 16:
			kit.add("sphere", Vector3(-60.0+i*8.0+band*3.0, FLOOR+.1, 20.0+band*7.0), Vector3(5.0, .1, .5), water.lightened(.25), Vector3.ZERO, false)
	for i in 3:
		kit.add("fine", Vector3(-40.0+i*42.0, FLOOR, 72.0+i*6.0), Vector3(26.0, 9.0+i*3.0, 12.0), Color("5c9a5a"), Vector3.ZERO, false)
	var lighthouse := Vector3(22.0, FLOOR, 38.0)
	kit.add("fine", lighthouse+Vector3(0, .6, 0), Vector3(9.0, 4.0, 7.0), Color("8a7a6a"))
	for i in 6:
		kit.add("cylinder", lighthouse+Vector3(0, 3.0+i*1.8, 0), Vector3(2.6-i*.18, 1.8, 2.6-i*.18), Color("e8434f") if i % 2 else Color("fbfbf6"))
	_lit("cylinder", lighthouse+Vector3(0, 14.4, 0), Vector3(1.6, 1.4, 1.6), Color("fff1a8"))
	kit.add("cone", lighthouse+Vector3(0, 15.8, 0), Vector3(2.4, 1.6, 2.4), Color("e8434f"))
	var boat := Vector3(-16.0, FLOOR, 30.0)
	kit.add_rounded_box(boat+Vector3(0, .5, 0), Vector3(5.0, 1.0, 1.8), Color("fbfbf6"), Vector3(0, .4, 0), true, 6)
	kit.add("cylinder", boat+Vector3(0, 4.0, 0), Vector3(.18, 7.0, .18), Color("8a6a50"))
	kit.add("cone", boat+Vector3(.9, 4.0, 0), Vector3(2.6, 6.0, .1), Color("fbfbf6"), Vector3(0, .4, 0))
	kit.add("torus", Vector3(5.0, FLOOR+.2, 19.0), Vector3(1.6, 1.4, 1.6), Color("ff6f91"))
	for i in 4:
		var a := -.9+i*.6
		var parasol := Vector3(sin(a)*9.5, FLOOR, cos(a)*9.5)
		kit.add("cylinder", parasol+Vector3(0, 2.2, 0), Vector3(.14, 4.4, .14), Color("fbfbf6"))
		kit.add("cone", parasol+Vector3(0, 4.6, 0), Vector3(4.6, 1.2, 4.6), [Color("e8434f"), Color("3fa9f5"), Color("ffb62e"), Color("23a58f")][i])
		for k in 4:
			var b := TAU*k/4.0+a
			_rod(parasol+Vector3(0, 5.2, 0), parasol+Vector3(sin(b)*2.25, 4.0, cos(b)*2.25), .16, Color("fbfbf6"), false)
		kit.add("block", parasol+Vector3(1.4, .03, .4), Vector3(1.6, .06, 3.0), [Color("ffd3e2"), Color("cdeefc"), Color("ffe7a3"), Color("d8f3bd")][i], Vector3(0, a, 0), false)
	var melon := Vector3(-3.5, FLOOR, 8.0)
	kit.add("fine", melon+Vector3(0, .8, 0), Vector3(1.8, 1.6, 1.8), Color("3f8a43"))
	for k in 5:
		kit.add("sphere", melon+Vector3(0, .8, 0), Vector3(1.82, 1.62, .25), Color("2a5f2e"), Vector3(0, TAU*k/10.0, 0), false)
	kit.add("sphere", melon+Vector3(1.6, .3, .4), Vector3(1.2, .6, .4), Color("ff5d6c"), Vector3(0, .3, 0))
	var castle := Vector3(4.0, FLOOR, 7.5)
	kit.add("block", castle+Vector3(0, .6, 0), Vector3(3.2, 1.2, 2.4), sand.darkened(.08))
	for x in [-1.2, 1.2]:
		kit.add("cylinder", castle+Vector3(x, 1.4, 0), Vector3(.9, 2.8, .9), sand.darkened(.1))
		kit.add("cone", castle+Vector3(x, 3.1, 0), Vector3(1.0, .7, 1.0), sand.darkened(.14))
	kit.add("block", castle+Vector3(1.2, 3.9, .2), Vector3(.5, .3, .03), Color("e8434f"))
	for i in 9:
		var a := PI+(-1.3+i*.33)
		var at := Vector3(sin(a)*rng.randf_range(12.0, 20.0), FLOOR, cos(a)*rng.randf_range(12.0, 20.0))
		_palm(at, rng.randf_range(6.0, 9.0))

func _palm(base: Vector3, height: float) -> void:
	var lean := Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
	var previous := base
	for s in 6:
		var u := (s+1)/6.0
		var point := base+Vector3(0, height*u, 0)+lean*u*u
		_rod(previous, point, .5-u*.12, Color("a0764a"))
		previous = point
	for f in 7:
		var a := TAU*f/7.0
		kit.add("sphere", previous+Vector3(sin(a)*1.6, -.4, cos(a)*1.6), Vector3(.8, .16, 3.4), Color("4fa04e"), Vector3(-.4, a, 0))
	for c in 3:
		kit.add("sphere", previous+Vector3(sin(c*2.1)*.4, -.5, cos(c*2.1)*.4), Vector3.ONE*.45, Color("7a5236"))

# ---------- Lantern River: paper lanterns floating downstream under fireworks ----------

func _lantern_river() -> void:
	turn = MENU_FACING
	_land(8.0)
	var water := _c("water", Color("223a62"))
	kit.add("block", Vector3(0, FLOOR+.04, 13.0), Vector3(120, .1, 8.0), water, Vector3.ZERO, false)
	for side in [-1.0, 1.0]:
		for i in 40:
			kit.add("block", Vector3(-60.0+i*3.0, FLOOR+.3, 13.0+side*4.2), Vector3(2.9, .6, .6), STONE.darkened(.35+fmod(i*.13, .1)), Vector3.ZERO, false)
	for i in 34:
		var at := Vector3(rng.randf_range(-40.0, 40.0), FLOOR+.25, rng.randf_range(9.8, 16.2))
		kit.add("block", at, Vector3(.7, .12, .7), Color("5a3a28"), Vector3(0, rng.randf()*TAU, 0), false)
		_lit("block", at+Vector3(0, .38, 0), Vector3(.55, .6, .55), [Color("ffd98a"), Color("ffb36b"), Color("fff1c4")][i % 3], Vector3(0, rng.randf()*TAU, 0))
		kit.add("sphere", at-Vector3(0, .2, 0), Vector3(1.4, .02, 1.0), Color("7a6a3a"), Vector3.ZERO, false)
	_bridge(Vector3(-12.0, FLOOR, 13.0), 0.0, Color("d8432f"))
	_houseboat(Vector3(9.0, FLOOR, 14.0))
	for i in 6:
		var x := -26.0+i*10.0
		_willow(Vector3(x, FLOOR, 7.5 if i % 2 else 18.8))
	var poles: Array[Vector3] = []
	for i in 9:
		var at := Vector3(-24.0+i*6.0, FLOOR, 19.5)
		kit.add("cylinder", at+Vector3(0, 2.6, 0), Vector3(.2, 5.2, .2), Color("3a2a1a"))
		poles.append(at+Vector3(0, 5.0, 0))
	for i in poles.size()-1:
		for bead in 5:
			var t := (bead+.5)/5.0
			var at := poles[i].lerp(poles[i+1], t)-Vector3(0, sin(t*PI)*.8, 0)
			_lit("sphere", at-Vector3(0, .3, 0), Vector3(.45, .58, .45), [_c("lantern", Color("ff6a3d")), Color("fff1c4")][bead % 2])
	for i in 8:
		_hut(Vector3(-28.0+i*8.0, FLOOR, 25.0+sin(i)*1.5), 0.0, _c("plaster", Color("3a3350")).lightened(.2), Color("2b2a3a"))
	_lit("fine", Vector3(-24.0, 24.0, 64.0), Vector3.ONE*8.0, _c("moon", Color("fff4c4")))

func _houseboat(at: Vector3) -> void:
	kit.add_rounded_box(at+Vector3(0, .5, 0), Vector3(9.0, 1.0, 2.8), Color("6b4a33"), Vector3.ZERO, true, 6)
	kit.add("block", at+Vector3(0, 1.8, 0), Vector3(7.0, 1.6, 2.4), Color("5a3a28"))
	for i in 6:
		_lit("block", at+Vector3(-2.9+i*1.16, 1.8, -1.22), Vector3(.9, .9, .06), Color("ffe0a0"))
	kit.add_rounded_box(at+Vector3(0, 2.8, 0), Vector3(7.8, .3, 3.0), Color("2b2a3a"), Vector3.ZERO, true, 6)
	for i in 7:
		_lit("sphere", at+Vector3(-3.6+i*1.2, 2.3, -1.6), Vector3(.4, .55, .4), Color("ff5a3a"))

func _willow(at: Vector3) -> void:
	_rod(at, at+Vector3(0, 5.0, 0), .5, Color("4a3428"))
	for i in 14:
		var a := TAU*i/14.0
		var hang := at+Vector3(sin(a)*1.8, 5.4, cos(a)*1.8)
		for k in 6:
			kit.add("sphere", hang+Vector3(sin(a)*k*.12, -k*.62, cos(a)*k*.12), Vector3(.32, .7, .32), Color("6f9a4a").darkened(k*.03), Vector3.ZERO, false)

# ---------- Castle Keep: a white castle above its moat, with blossom ----------

func _castle() -> void:
	turn = MENU_FACING
	_land(8.0)
	var keep := Vector3(0, FLOOR, 34.0)
	kit.add("block", keep+Vector3(0, .05, 0), Vector3(40, .1, 30), _c("water", Color("5a9ab5")), Vector3.ZERO, false)
	for step in 4:
		var width := 26.0-step*3.0
		kit.add("block", keep+Vector3(0, 1.0+step*2.0, 0), Vector3(width, 2.0, width*.72), STONE.darkened(.08+step*.02))
		for i in int(width/2.0):
			kit.add("block", keep+Vector3(-width*.5+1.0+i*2.0, 1.0+step*2.0, -width*.36-.02), Vector3(1.9, .05, .05), STONE.darkened(.3), Vector3.ZERO, false)
	var base := 8.0
	var white := Color("fbf8f0")
	var roof := Color("56606e")
	for tier in 4:
		var width := 14.0-tier*2.8
		var height := 3.2
		kit.add("block", keep+Vector3(0, base+height*.5, 0), Vector3(width, height, width*.8), white)
		for w in 3:
			kit.add("block", keep+Vector3(-width*.3+w*width*.3, base+height*.55, -width*.4-.03), Vector3(.9, .8, .06), Color("3a3440"), Vector3.ZERO, false)
		kit.add_rounded_box(keep+Vector3(0, base+height+.3, 0), Vector3(width+3.0, .6, width*.8+3.0), roof, Vector3.ZERO, true, 6)
		kit.add_rounded_box(keep+Vector3(0, base+height+.9, 0), Vector3(width+.6, .9, width*.8+.6), roof.darkened(.1), Vector3.ZERO, true, 4)
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				kit.add("cone", keep+Vector3(x*(width*.5+1.6), base+height+.6, z*(width*.4+1.6)), Vector3(.5, 1.0, .5), roof.darkened(.15), Vector3(z*-.7, 0, x*.7))
		# A triangular gable facing the garden.
		kit.add("cone", keep+Vector3(0, base+height+1.4, -width*.4-1.2), Vector3(width*.45, 1.6, .5), white, Vector3.ZERO)
		base += height+1.2
	for side in [-1.0, 1.0]:
		var fish := keep+Vector3(side*2.2, base+.8, 0)
		kit.add("sphere", fish, Vector3(.6, 1.2, .5), Color("f5c14e"), Vector3(0, 0, side*.4))
		kit.add("cone", fish+Vector3(-side*.4, .9, 0), Vector3(.6, .7, .2), Color("f5c14e"), Vector3(0, 0, -side*.8))
	kit.add_rounded_box(keep+Vector3(0, base+.2, 0), Vector3(5.0, .5, .8), roof, Vector3.ZERO, true, 6)
	# The gate and banners on the approach.
	for side in [-1.0, 1.0]:
		kit.add("block", Vector3(side*3.2, FLOOR+2.8, 15.0), Vector3(.8, 5.6, .8), Color("4a3428"))
		for z in [10.0, 12.5]:
			var pole := Vector3(side*5.5, FLOOR, z)
			kit.add("cylinder", pole+Vector3(0, 3.5, 0), Vector3(.15, 7.0, .15), Color("3a2a1a"))
			kit.add("block", pole+Vector3(side*-.5, 4.2, 0), Vector3(.9, 4.5, .05), [Color("d8432f"), Color("3a5aa8")][int(z) % 2])
	kit.add_rounded_box(Vector3(0, FLOOR+6.0, 15.0), Vector3(9.0, .8, 2.4), roof, Vector3.ZERO, true, 6)
	kit.add("block", Vector3(0, FLOOR+5.3, 15.0), Vector3(7.0, .5, .6), Color("4a3428"))
	for i in 12:
		var at := _ring_spot(10.0, 22.0)
		if at.z > 8.0 and absf(at.x) < 8.0:
			continue
		_tree(at, rng.randf_range(4.0, 5.5), Color("5a3a2a"), [Color("ffb3c8"), Color("ffc9d6"), Color("f58fae")])
	for i in 8:
		kit.add("cylinder", Vector3(sin(i*.7)*.5, FLOOR+.05, 7.5+i*1.0), Vector3(1.2, .1, .9), STONE, Vector3(0, i, 0))
