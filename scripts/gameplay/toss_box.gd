class_name TossBox
extends Node3D
## Kinu Toss's target: a long bento in the equipped box skin, propped up at the back like a
## cornhole board, with a lid laid across it and square holes cut in the lid. Kinu have to drop
## through a hole and stay in. Each box is built for one stretch of a run — its size, holes, tilt
## and place on the table change every time a fresh one slides in.
##
## The walls are the real TofuBox (so every skin works), stretched long and narrow. The lid is built
## unscaled in world units, so a hole's size means the same thing next to a Kinu on any box.
## Everything that tilts hangs off `board`; the root only stands on the table and turns.

const LID_THICK := .16
## Hole tiers, largest first. `half` is half the opening in world units: a Block (0.88 wide in play)
## drops through a small hole only if it arrives square-on, and a Long (1.6) needs the big one end-first.
## A hole of any other size takes the colour and name of the tier it is closest to, and its points
## from its size (see points_for).
const TIERS := {
	"big": {"half": .82, "color": RING, "name": "Big hole"},
	"medium": {"half": .64, "color": RING, "name": "Nice"},
	"small": {"half": .52, "color": RING, "name": "Small hole"},
	"gold": {"half": .48, "color": Color("ffd23f"), "name": "Lucky Box"},
}
## Every hole is ringed in the same painted red, the way a cornhole board is: one colour the eye
## goes straight to, on every box and every skin. Only the lucky hole breaks it, in gold.
const RING := Color("e0463a")
## A pale line between the ring and the opening. Box skins run from cream to near-black, and this
## is what keeps the target readable on the dark ones, where red on black would close up.
const LINER := Color("fff6e2")
## An open box, with no lid at all, pays this for any Kinu that stays in.
const OPEN_POINTS := 50
const GOLD_POINTS := 600
## Space kept between two holes, and between a hole and the inside of the wall.
const HOLE_GAP := .26
const WALL_CLEAR := .06

var decor: KinuDecor
## Half the inside of the box across (x) and along the throw (z), in world units.
var half_x: float = 1.95
var half_z: float = 1.5
## How tall the walls stand against a normal box's, so an early box is roomy in every direction.
var rise: float = 1.0
## How far the back is propped up, in radians.
var tilt: float = .4
## Holes as {"tier", "center": Vector2 in lid space, "half"}. Only lidded boxes use these.
var holes: Array[Dictionary] = []
## False for the open boxes a run starts on: no lid, just get it in.
var lidded: bool = true
## How many equal walled-off pockets an open box is divided into. 0 or 1 is just the plain open
## box; 2 or more gets real, collidable dividers between them.
var compartments: int = 0
var with_collision: bool = true
var board: Node3D
var shell: TofuBox
var lid_body: StaticBody3D

func stretch() -> Vector2:
	return Vector2(half_x, half_z)/TofuBox.INNER_HALF

func outer() -> Vector2:
	return stretch()*(TofuBox.INNER_HALF+TofuBox.WALL)

## The top of the walls, and the top of the lid, in the board's own frame.
func rim() -> float:
	return TofuBox.RIM_HEIGHT*rise

func lid_top() -> float:
	return rim()+LID_THICK

func _color(key: String, fallback: Color) -> Color:
	return decor.palette.get(key, fallback) if decor else fallback

func _ready() -> void:
	board = Node3D.new()
	board.name = "Board"
	# Tipped back about its front edge, which stays on the table.
	board.rotation.x = tilt
	board.position.y = outer().y*sin(tilt)
	add_child(board)
	shell = TofuBox.new()
	shell.decor = decor
	shell.with_collision = with_collision
	shell.scale = Vector3(stretch().x, rise, stretch().y)
	board.add_child(shell)
	if lidded:
		board.add_child(_build_lid())
		if with_collision:
			_lid_collision()
	else:
		board.add_child(_open_ring())
	if compartments > 1:
		board.add_child(_build_compartment_walls())
		if with_collision:
			_compartment_collision()
	add_child(_build_stand())

## Points for a Kinu through this hole: the smaller the hole, the steeper the reward.
static func points_for(hole: Dictionary) -> int:
	if hole.tier == "gold":
		return GOLD_POINTS
	return maxi(100, int(snappedf(100.0*pow(float(TIERS.big.half)/float(hole.half), 3.0), 50.0)))

## The tier a hole of this half-width looks like.
static func tier_for(half: float) -> String:
	return "big" if half >= .74 else "medium" if half >= .58 else "small"

## Lays out holes at random, largest first, skipping any that no longer fit. Each entry is a tier
## name, or a half-width for a hole sized between the tiers.
static func place_holes(sizes: Array, inside: Vector2, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	var limit := inside-Vector2.ONE*WALL_CLEAR
	var specs: Array[Dictionary] = []
	for size in sizes:
		if size is String:
			specs.append({"tier": size, "half": float(TIERS[size].half)})
		else:
			specs.append({"tier": tier_for(float(size)), "half": float(size)})
	specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.half) > float(b.half))
	for spec in specs:
		var tier: String = spec.tier
		var half: float = spec.half
		var room := limit-Vector2.ONE*half
		if room.x < 0.0 or room.y < 0.0:
			continue
		for attempt in 80:
			var center := Vector2(rng.randf_range(-room.x, room.x), rng.randf_range(-room.y, room.y))
			var clear := true
			for other in placed:
				var reach := half+float(other.half)+HOLE_GAP
				var gap: Vector2 = (center-(other.center as Vector2)).abs()
				if gap.x < reach and gap.y < reach:
					clear = false
					break
			if clear:
				placed.append({"tier": tier, "center": center, "half": half})
				break
	return placed

## Lays holes out in a row of equal strips across the box, one per hole, instead of place_holes's
## free scatter: what lets _build_compartment_walls put a real, collidable wall on every strip
## boundary, so a Kinu through one hole can never end up sitting in another's pocket.
static func place_compartment_holes(sizes: Array, inside: Vector2, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for size in sizes:
		if size is String:
			specs.append({"tier": size, "half": float(TIERS[size].half)})
		else:
			specs.append({"tier": tier_for(float(size)), "half": float(size)})
	var n := specs.size()
	if n == 0:
		return []
	var limit := inside-Vector2.ONE*WALL_CLEAR
	var strip := limit.x*2.0/float(n)
	var placed: Array[Dictionary] = []
	for i in n:
		var spec: Dictionary = specs[i]
		var half: float = spec.half
		var strip_center := -limit.x+strip*(i+.5)
		var room_x := maxf(strip*.5-half-HOLE_GAP*.5, 0.0)
		var room_z := maxf(limit.y-half, 0.0)
		var center := Vector2(strip_center+rng.randf_range(-room_x, room_x), rng.randf_range(-room_z, room_z))
		placed.append({"tier": spec.tier, "center": center, "half": half})
	return placed

## The lid is split into rectangles along every hole edge; the ones not inside a hole are solid.
func _cells() -> Array[Rect2]:
	var edge := outer()
	var xs: Array[float] = [-edge.x, edge.x]
	var zs: Array[float] = [-edge.y, edge.y]
	for hole in holes:
		var c: Vector2 = hole.center
		var h: float = hole.half
		xs.append_array([c.x-h, c.x+h])
		zs.append_array([c.y-h, c.y+h])
	xs.sort()
	zs.sort()
	var cells: Array[Rect2] = []
	for j in zs.size()-1:
		if zs[j+1]-zs[j] < .001:
			continue
		var run_start := -1
		for i in xs.size():
			var solid := false
			if i < xs.size()-1 and xs[i+1]-xs[i] > .001:
				solid = hole_at(Vector2((xs[i]+xs[i+1])*.5, (zs[j]+zs[j+1])*.5)) < 0
			if solid and run_start < 0:
				run_start = i
			elif not solid and run_start >= 0:
				# Neighbouring solid cells in a row are merged, so the lid is a handful of planks.
				cells.append(Rect2(xs[run_start], zs[j], xs[i]-xs[run_start], zs[j+1]-zs[j]))
				run_start = -1
	return cells

func _build_lid() -> Node3D:
	var kit := MeshKit.new()
	var wood := _color("wood_light", TofuBox.WOOD_LIGHT)
	var edge := _color("wood_dark", TofuBox.WOOD_DARK)
	var y := rim()+LID_THICK*.5
	for cell in _cells():
		var mid := cell.get_center()
		kit.add("block", Vector3(mid.x, y, mid.y), Vector3(cell.size.x, LID_THICK, cell.size.y), wood, Vector3.ZERO, false)
	# An inked frame round the outside, so the lid reads as one piece sitting on the box.
	var size := outer()
	for side in 4:
		var angle := side*PI*.5
		var along := size.x if side % 2 == 0 else size.y
		var across := size.y if side % 2 == 0 else size.x
		kit.add_rounded_box(Basis(Vector3.UP, angle)*Vector3(0, y+.02, across-.05), Vector3(along*2, LID_THICK+.06, .12), edge, Vector3(0, angle, 0), true, 8.0)
	# Each hole gets a painted collar in its tier's colour, stood just outside the opening so it
	# never narrows it. The dark inner lip shows it as a hole rather than a painted square.
	for hole in holes:
		var c: Vector2 = hole.center
		var h: float = hole.half
		var collar: Color = TIERS[hole.tier].color
		for side in 4:
			var angle := side*PI*.5
			var basis := Basis(Vector3.UP, angle)
			kit.add_rounded_box(Vector3(c.x, y+.04, c.y)+basis*Vector3(0, 0, h+.12), Vector3(h*2+.42, LID_THICK+.1, .18), collar, Vector3(0, angle, 0), true, 8.0)
			kit.add_rounded_box(Vector3(c.x, y+.06, c.y)+basis*Vector3(0, 0, h+.035), Vector3(h*2+.14, LID_THICK+.06, .07), LINER, Vector3(0, angle, 0), false, 8.0)
			kit.add("block", Vector3(c.x, y-.02, c.y)+basis*Vector3(0, 0, h-.005), Vector3(h*2, LID_THICK+.02, .01), edge.darkened(.45), Vector3(0, angle, 0), false)
	return kit.build(.035)

## An open box is one big hole, so its whole lip is the ring: red all the way round the rim, with
## the same pale liner inside it. Without this the opening would be whatever colour the skin is.
func _open_ring() -> Node3D:
	var kit := MeshKit.new()
	var size := outer()
	var y := rim()
	for side in 4:
		var angle := side*PI*.5
		var along := size.x if side % 2 == 0 else size.y
		var across := size.y if side % 2 == 0 else size.x
		var basis := Basis(Vector3.UP, angle)
		kit.add_rounded_box(basis*Vector3(0, y-.02, across-TofuBox.WALL*.5), Vector3(along*2+.06, .2, TofuBox.WALL+.08), RING, Vector3(0, angle, 0), true, 8.0)
		kit.add_rounded_box(basis*Vector3(0, y+.03, across-TofuBox.WALL-.02), Vector3(along*2-.1, .1, .07), LINER, Vector3(0, angle, 0), false, 8.0)
	return kit.build(.035)

## Two legs and a rail under the raised back, standing straight on the table.
func _build_stand() -> Node3D:
	var kit := MeshKit.new()
	var size := outer()
	var leg := _color("wood_dark", TofuBox.WOOD_DARK)
	var along := size.y-.3
	var z := -along*cos(tilt)
	var height := (size.y+along)*sin(tilt)
	for side in [-1.0, 1.0]:
		kit.add_rounded_box(Vector3(side*(size.x-.3), height*.5, z), Vector3(.3, height, .3), leg, Vector3.ZERO, true, 8.0)
	kit.add_rounded_box(Vector3(0, height*.35, z), Vector3(size.x*2-.6, .16, .16), leg.darkened(.1), Vector3.ZERO, true, 8.0)
	var stand := kit.build(.035)
	if with_collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x*2-.3, height, .3)
		shape.shape = box
		shape.position = Vector3(0, height*.5, z)
		body.add_child(shape)
		stand.add_child(body)
	return stand

func _lid_collision() -> void:
	lid_body = StaticBody3D.new()
	lid_body.collision_layer = 1
	lid_body.collision_mask = 2
	# Slick, like a cornhole board: a Kinu that lands short slides down the slope.
	lid_body.physics_material_override = PhysicsMaterial.new()
	lid_body.physics_material_override.friction = .3
	board.add_child(lid_body)
	for cell in _cells():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(cell.size.x, LID_THICK, cell.size.y)
		shape.shape = box
		var mid := cell.get_center()
		shape.position = Vector3(mid.x, rim()+LID_THICK*.5, mid.y)
		lid_body.add_child(shape)

## The x of every strip boundary between `compartments` equal pockets, in board space.
func _compartment_walls_x() -> Array[float]:
	var xs: Array[float] = []
	var strip := half_x*2.0/float(compartments)
	for i in compartments-1:
		xs.append(-half_x+strip*(i+1))
	return xs

## A wall on every strip boundary, floor to rim, capped in the same red as the box's own open
## ring: what a landed Kinu runs into before it can roll off into another pocket.
func _build_compartment_walls() -> Node3D:
	var kit := MeshKit.new()
	var wood := _color("wood_dark", TofuBox.WOOD_DARK)
	var top := rim()
	var depth := half_z*2-WALL_CLEAR
	for x in _compartment_walls_x():
		kit.add_rounded_box(Vector3(x, top*.5, 0), Vector3(.1, top, depth), wood, Vector3.ZERO, true, 6.0)
		kit.add_rounded_box(Vector3(x, top-.03, 0), Vector3(.18, .08, depth), RING, Vector3.ZERO, true, 6.0)
	return kit.build(.03)

func _compartment_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var top := rim()
	for x in _compartment_walls_x():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(.12, top, half_z*2)
		shape.shape = box
		shape.position = Vector3(x, top*.5, 0)
		body.add_child(shape)
	board.add_child(body)

## A world point in the board's own frame, where the lid is flat.
func local(world: Vector3) -> Vector3:
	return board.to_local(world) if is_instance_valid(board) else to_local(world)

## Index of the hole a point in lid space lies over, or -1.
func hole_at(point: Vector2, margin: float = 0.0) -> int:
	for i in holes.size():
		var gap: Vector2 = (point-(holes[i].center as Vector2)).abs()
		var reach: float = float(holes[i].half)+margin
		if gap.x < reach and gap.y < reach:
			return i
	return -1

## The hole nearest a point in lid space, for a Kinu found inside without a crossing on record.
func nearest_hole(point: Vector2) -> int:
	var best := -1
	var closest := INF
	for i in holes.size():
		var gap := point.distance_to(holes[i].center)
		if gap < closest:
			closest = gap
			best = i
	return best

## Where the middle of the lid is in the world, for distances and popups.
func lid_center() -> Vector3:
	return board.to_global(Vector3(0, lid_top(), 0)) if is_instance_valid(board) else global_position

## "in" (in the box), "lid" (resting on top of the lid) or "out".
##
## Anything standing between the walls is in, however high it is piled. Measuring against the rim
## made a Kinu on the heap, or one wedged nose-up in a hole, read as a miss while it sat plainly
## inside the box. Only a Kinu up on the lid itself is "lid", and it has to be a whole body's
## height above the lid to count as that.
func classify(world: Vector3) -> String:
	var at := local(world)
	if at.y <= -.2:
		return "out"
	var inside := Vector2(half_x, half_z)
	var within := absf(at.x) < inside.x+.05 and absf(at.z) < inside.y+.05
	if not lidded:
		return "in" if within else "out"
	# Through a hole and standing proud of it — a Tall on its end, or one riding the heap — is
	# still in the box, not on the lid.
	if within and (at.y < lid_top()+.25 or (hole_at(Vector2(at.x, at.z), .15) >= 0 and at.y < lid_top()+.9)):
		return "in"
	var edge := outer()
	if absf(at.x) < edge.x+.12 and absf(at.z) < edge.y+.12 and at.y >= rim():
		return "lid"
	return "out"
