class_name ShoyuBottle
extends Node3D
## A little sauce bottle the player aims like a Kinu. Letting go tips it over and squirts onto
## the Kinu below. The glass and the drops take the colour of whichever sauce it is holding, so
## Nigari and Koji read apart at a glance in the air as well as on the Next card.

signal squirted(target: KinuBody)

const GLAZE := Color("6b3418")
## Set before the bottle enters the tree; defaults to the old soy brown.
var tint := Color("3a1a10")
var tipping: bool = false

func _ready() -> void:
	var kit := MeshKit.new()
	var glass := tint
	kit.add("cylinder", Vector3(0, .32, 0), Vector3(.42, .5, .42), glass)
	kit.add("sphere", Vector3(0, .58, 0), Vector3(.42, .22, .42), glass)
	kit.add("cylinder", Vector3(0, .74, 0), Vector3(.18, .22, .18), glass)
	kit.add("cylinder", Vector3(0, .9, 0), Vector3(.26, .14, .26), Color("d8432f"))
	kit.add("cone", Vector3(.08, 1.02, 0), Vector3(.1, .14, .1), Color("d8432f"), Vector3(0, 0, -.5))
	kit.add("cylinder", Vector3(0, .32, 0), Vector3(.44, .2, .44), Color("fff4df"), Vector3.ZERO, false)
	kit.add("sphere", Vector3(0, .32, .22), Vector3(.12, .12, .02), Color("d8432f"), Vector3.ZERO, false)
	kit.add("sphere", Vector3(-.1, .42, .19), Vector3(.05, .22, .02), Color(1, 1, 1, 1), Vector3(0, 0, .1), false)
	var model := kit.build(.03, false)
	model.position.y = -.7
	model.scale = Vector3.ONE*1.4
	add_child(model)

## Tips the bottle, rains a few drops down onto the target, then reports what was hit.
func squirt(target: KinuBody, hit_point: Vector3) -> void:
	tipping = true
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", -2.3, .18).set_trans(Tween.TRANS_BACK)
	await tween.finished
	var nozzle := global_position+Vector3(.6, -.75, 0)
	var land := hit_point if hit_point != Vector3.INF else global_position-Vector3.UP*4.0
	for i in 5:
		var drop := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = .09
		mesh.height = .18
		drop.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = tint.lightened(.25)
		drop.material_override = material
		get_parent().add_child(drop)
		drop.global_position = nozzle
		var fall := drop.create_tween()
		fall.tween_interval(i*.05)
		fall.tween_property(drop, "global_position", land+Vector3(sin(i*2.0)*.12, .05, cos(i*2.0)*.12), .28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_callback(drop.queue_free)
	await get_tree().create_timer(.5).timeout
	squirted.emit(target)
	queue_free()

## The bottle drawn on the HUD button.
class Icon extends Control:
	## Matches the bottle in play, so the card and the thing in your hand are the same object.
	var tint := Color("3a1a10")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink := NestTheme.INK
		var body := StyleBoxFlat.new()
		body.bg_color = tint
		body.border_color = ink
		body.set_border_width_all(3)
		body.set_corner_radius_all(9)
		draw_style_box(body, Rect2(Vector2(size.x*.18, size.y*.34), Vector2(size.x*.64, size.y*.64)))
		draw_rect(Rect2(Vector2(size.x*.36, size.y*.16), Vector2(size.x*.28, size.y*.2)), tint)
		draw_rect(Rect2(Vector2(size.x*.36, size.y*.16), Vector2(size.x*.28, size.y*.2)), ink, false, 3)
		var cap := StyleBoxFlat.new()
		cap.bg_color = Color("d8432f")
		cap.border_color = ink
		cap.set_border_width_all(3)
		cap.set_corner_radius_all(4)
		draw_style_box(cap, Rect2(Vector2(size.x*.28, 0), Vector2(size.x*.44, size.y*.2)))
		draw_rect(Rect2(Vector2(size.x*.24, size.y*.56), Vector2(size.x*.52, size.y*.16)), Color("fff4df"))
