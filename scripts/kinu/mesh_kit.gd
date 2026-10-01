class_name MeshKit
extends RefCounted
## Accumulates vertex-coloured primitives into one toon "fill" mesh plus an
## inverted-hull "outline" mesh containing only silhouette parts.

const TOON := preload("res://resources/shaders/toon.gdshader")
const OUTLINE := preload("res://resources/shaders/outline.gdshader")

static var _primitives: Dictionary = {}
static var _toon_material: ShaderMaterial
static var _outline_materials: Dictionary = {}

## Kinu Toss throws the length of the room, so while a Toss room is built it clears a lane: any part
## whose centre falls inside `cull_zone` is left out. `cull_turn` is the angle the scenery being
## built will be turned to, so the test is made where the part will actually stand. Parts wider
## than CULL_MAX are floors, walls and skies rather than props, and always stay.
static var cull_zone := AABB()
static var cull_turn: float = 0.0
const CULL_MAX := 14.0

static func _culled(center: Vector3, extent: float) -> bool:
	if not cull_zone.has_volume() or extent > CULL_MAX:
		return false
	return cull_zone.has_point(Basis(Vector3.UP, cull_turn)*center)

var fill := SurfaceTool.new()
var hull := SurfaceTool.new()
var hull_used: bool = false

func _init() -> void:
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)

static func toon_material() -> ShaderMaterial:
	if _toon_material == null:
		_toon_material = ShaderMaterial.new()
		_toon_material.shader = TOON
	return _toon_material

static func outline_material(width: float) -> ShaderMaterial:
	if not _outline_materials.has(width):
		var mat := ShaderMaterial.new()
		mat.shader = OUTLINE
		mat.set_shader_parameter("width", width)
		_outline_materials[width] = mat
	return _outline_materials[width]

static func primitive(kind: String) -> Array:
	if not _primitives.has(kind):
		var mesh: PrimitiveMesh
		match kind:
			"sphere":
				mesh = SphereMesh.new()
				mesh.radial_segments = 24
				mesh.rings = 12
				mesh.radius = .5
				mesh.height = 1.0
			"fine":
				mesh = SphereMesh.new()
				mesh.radial_segments = 40
				mesh.rings = 24
				mesh.radius = .5
				mesh.height = 1.0
			"bead":
				mesh = SphereMesh.new()
				mesh.radial_segments = 12
				mesh.rings = 6
				mesh.radius = .5
				mesh.height = 1.0
			"dome":
				# A closed half ball, flat face at y = 0 and crown at y = .5.
				mesh = SphereMesh.new()
				mesh.radial_segments = 32
				mesh.rings = 10
				mesh.radius = .5
				mesh.height = .5
				mesh.is_hemisphere = true
			"cone":
				mesh = CylinderMesh.new()
				mesh.top_radius = 0.0
				mesh.bottom_radius = .5
				mesh.height = 1.0
				mesh.radial_segments = 16
				mesh.rings = 1
			"cylinder":
				mesh = CylinderMesh.new()
				mesh.top_radius = .5
				mesh.bottom_radius = .5
				mesh.height = 1.0
				mesh.radial_segments = 24
				mesh.rings = 1
			"block":
				mesh = BoxMesh.new()
				mesh.size = Vector3.ONE
			"torus":
				mesh = TorusMesh.new()
				mesh.inner_radius = .4
				mesh.outer_radius = .5
				mesh.rings = 32
				mesh.ring_segments = 10
		_primitives[kind] = mesh.get_mesh_arrays()
	return _primitives[kind]

## Scale is applied first, then the euler rotation, then the translation.
func add(kind: String, position: Vector3, scale: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO, outline: bool = true) -> void:
	var basis := Basis.from_euler(rotation) * Basis.from_scale(scale)
	# "fine" asks for a smooth silhouette, not for a fixed triangle budget: a blob a few pixels
	# wide reads exactly the same off the ordinary sphere.
	if kind == "fine" and _across(scale) < .45:
		kind = "sphere"
	add_transformed(kind, Transform3D(basis, position), color, outline)

func add_transformed(kind: String, transform: Transform3D, color: Color, outline: bool = true) -> void:
	if cull_zone.has_volume() and _culled(transform.origin, maxf(transform.basis.x.length(), maxf(transform.basis.y.length(), transform.basis.z.length()))):
		return
	var arrays := primitive(kind)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	for index in indices:
		var normal := (normal_basis * normals[index]).normalized()
		var vertex := transform * vertices[index]
		fill.set_color(Color(color, 0.0))
		fill.set_normal(normal)
		fill.add_vertex(vertex)
		if outline:
			hull.set_normal(normal)
			hull.add_vertex(vertex)
	hull_used = hull_used or outline

## Rounded box / squircle ball (superellipsoid). power 2 = ellipsoid, higher = boxier corners.
## Boxy ones flag their vertices (colour alpha) so the toon shader inks their edges.
func add_rounded_box(position: Vector3, size: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO, outline: bool = true, power: float = 6.0) -> void:
	if cull_zone.has_volume() and _culled(position, maxf(size.x, maxf(size.y, size.z))):
		return
	var arrays := primitive(_squircle_detail(size))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis := Basis.from_euler(rotation)
	var half := size*.5
	for index in indices:
		var u: Vector3 = vertices[index]*2.0
		var p := Vector3(_signed_pow(u.x, 2.0/power), _signed_pow(u.y, 2.0/power), _signed_pow(u.z, 2.0/power))
		var gradient := Vector3(_signed_pow(p.x, power-1.0)/half.x, _signed_pow(p.y, power-1.0)/half.y, _signed_pow(p.z, power-1.0)/half.z)
		var normal := (basis*gradient).normalized()
		var vertex := position+basis*(p*half)
		fill.set_color(Color(color, 1.0 if power >= 4.0 else 0.0))
		fill.set_normal(normal)
		fill.add_vertex(vertex)
		if outline:
			hull.set_normal(normal)
			hull.add_vertex(vertex)
	hull_used = hull_used or outline

## Picks the sphere a squircle is deformed from, by how big the part is. A stamp mark or a
## trim strip is a few pixels across, so spending the full 40x24 sphere on one is wasted:
## small parts drop to coarser spheres for the same silhouette at a fraction of the triangles.
static func _squircle_detail(size: Vector3) -> String:
	# The flat faces stay flat at any resolution, so what needs segments is the corner rounding,
	# and that is set by the part's second-largest dimension: a long thin plank rounds over a
	# thin cross-section however long it is.
	var across := _across(size)
	if across < .3:
		return "bead"
	if across < 1.0:
		return "sphere"
	return "fine"

## A part's second-largest dimension: how wide it is across the axis that has to round off.
static func _across(size: Vector3) -> float:
	var axes := [size.x, size.y, size.z]
	axes.sort()
	return axes[1]

static func _signed_pow(value: float, exponent: float) -> float:
	return signf(value)*pow(absf(value), exponent)

## Places a flattened feature (eye, cheek, brow) on an ellipsoid body so it hugs the surface.
func add_on_body(kind: String, body: Vector3, x: float, y: float, scale: Vector3, color: Color, roll: float = 0.0, outline: bool = false, lift: float = 0.0, center: Vector3 = Vector3.ZERO) -> void:
	var a := body*.5
	var z_sq := 1.0 - pow(x/a.x, 2) - pow(y/a.y, 2)
	var point := Vector3(x, y, a.z*sqrt(maxf(z_sq, 0.0)))
	var normal := Vector3(point.x/(a.x*a.x), point.y/(a.y*a.y), point.z/(a.z*a.z)).normalized()
	var facing := Basis.looking_at(-normal, Vector3.UP)
	var basis := facing * Basis(Vector3.BACK, roll) * Basis.from_scale(scale)
	add_transformed(kind, Transform3D(basis, center + point + normal*lift), color, outline)

## Revolves a 2D (radius, height) profile, ordered so the outward side is on the left
## (e.g. top centre -> rim -> down the outside). color_at(segment, profile_index) gives per-quad colours.
func lathe(profile: PackedVector2Array, segments: int, color_at: Callable, outline: bool = true) -> void:
	var count := profile.size()
	var profile_normals: Array[Vector2] = []
	for i in count:
		var tangent := profile[mini(i+1, count-1)] - profile[maxi(i-1, 0)]
		profile_normals.append(Vector2(-tangent.y, tangent.x).normalized())
	for s in segments:
		var a0 := TAU*s/segments
		var a1 := TAU*(s+1)/segments
		for i in count-1:
			var color: Color = color_at.call(s, i)
			var quad := [[a0, i], [a1, i], [a1, i+1], [a0, i+1]]
			for corner in [0, 1, 2, 0, 2, 3]:
				var angle: float = quad[corner][0]
				var p := profile[quad[corner][1]]
				var n := profile_normals[quad[corner][1]]
				var normal := Vector3(sin(angle)*n.x, n.y, cos(angle)*n.x)
				var vertex := Vector3(sin(angle)*p.x, p.y, cos(angle)*p.x)
				fill.set_color(Color(color, 0.0))
				fill.set_normal(normal)
				fill.add_vertex(vertex)
				if outline:
					hull.set_normal(normal)
					hull.add_vertex(vertex)
	hull_used = hull_used or outline

func build(outline_width: float = 0.028, casts_shadow: bool = true) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.name = "Fill"
	body.mesh = commit_fill()
	body.material_override = toon_material()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	if hull_used:
		var line := MeshInstance3D.new()
		line.name = "Outline"
		line.mesh = commit_hull()
		line.material_override = outline_material(outline_width)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(line)
	return root

func commit_fill() -> ArrayMesh:
	fill.index()
	return fill.commit()

func commit_hull() -> ArrayMesh:
	# Merging positions keeps the hull watertight so extruded seams stay closed.
	hull.index()
	return hull.commit()

## How many built model templates a cache keeps. Enough for the equipped set-up plus whatever
## a shop shelf or a reveal is showing, without holding every skin the player has ever scrolled
## past for the rest of the session.
const CACHE_KEEP := 6

## Shared backing for the model caches (boxes, tower plates). Each holds a built but
## unparented template that instances duplicate, so nothing in the scene tree ever frees them and
## an unbounded cache would keep every skin's meshes alive for the whole session. Evicting the
## least recently used template is safe for anything already on screen: instances hold their own
## duplicated nodes, and the meshes inside those are refcounted resources.
static func cached_model(cache: Dictionary, key: String, build: Callable) -> Node3D:
	if cache.has(key):
		# Re-insert so the freshest key sorts last and eviction takes the stalest one.
		var found: Node3D = cache[key]
		cache.erase(key)
		cache[key] = found
		return found
	var built: Node3D = build.call()
	cache[key] = built
	while cache.size() > CACHE_KEEP:
		var stalest: Variant = cache.keys()[0]
		(cache[stalest] as Node3D).free()
		cache.erase(stalest)
	return built
