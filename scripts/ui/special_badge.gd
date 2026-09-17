class_name SpecialBadge
extends Control
## Special Kinu badges: gold star (Lucky), pink heart (Heart) and a little tofu (Tiny). Shared by
## the Next card and the marker floating over the Kinu in play.

const COLORS := {"lucky": Color("ffc93c"), "heart": Color("ff6f91"), "tiny": Color("8fd3ff")}
## Kinds that float a badge above the Kinu in play. Tiny Kinu are obvious enough on their own.
const MARKED := ["lucky", "heart"]
const INTRO := {
	"lucky": "Lucky Kinu! Land it for bonus beans",
	"heart": "Heart Kinu! Land it to win back a tumble",
	"tiny": "Tiny Kinu! Squeeze it into a gap",
}

var kind: String = "lucky"

static func outline(which: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	if which == "tiny":
		for i in 16:
			var a := TAU*i/16.0
			var corner := Vector2(signf(cos(a))*pow(absf(cos(a)), .35), signf(sin(a))*pow(absf(sin(a)), .35))
			points.append(corner*.62)
	elif which == "heart":
		for i in 32:
			var t := TAU*i/32.0
			points.append(Vector2(16*pow(sin(t), 3), -(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t)))/17.0)
	else:
		for i in 10:
			var a := -PI*.5+TAU*i/10.0
			points.append(Vector2(cos(a), sin(a))*(1.0 if i % 2 == 0 else .46))
	return points

## A camera-facing badge with a flat fill and ink silhouette. A closed 3D hull
## produces dark end caps as it spins; these symbols should read like the HUD.
static func marker(which: String) -> Node3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shape := outline(which)
	var triangles := Geometry2D.triangulate_polygon(shape)
	# Draw the larger ink silhouette behind the coloured face. Both layers share
	# one billboard transform, so their edges stay aligned at every camera angle.
	for layer in 2:
		var radius := .325 if layer == 0 else .3
		var color: Color = NestTheme.INK if layer == 0 else COLORS[which]
		for t in range(0, triangles.size(), 3):
			for c in 3:
				var p := shape[triangles[t+c]]*radius
				surface.set_color(color)
				surface.set_normal(Vector3.BACK)
				surface.add_vertex(Vector3(p.x, -p.y, layer*.004))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var shape := outline(kind)
	var radius := minf(size.x, size.y)*.46
	for i in shape.size():
		shape[i] = size*.5+shape[i]*radius
	draw_colored_polygon(shape, COLORS[kind])
	var loop := shape.duplicate()
	loop.append(shape[0])
	draw_polyline(loop, NestTheme.INK, 3, true)
