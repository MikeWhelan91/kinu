extends Control
## Renders the home curtain icons on their paper medallions, at real size and enlarged:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/icon_sheet.tscn -- out.png

const KINDS := ["shop", "wardrobe", "book", "settings"]

func _ready() -> void:
	get_window().size = Vector2i(700, 380)
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "icon-sheet.png"
	for row in 2:
		var scale_by := 1.0 if row == 0 else 3.0
		for i in KINDS.size():
			var centre := Vector2(90+i*170, 70 if row == 0 else 250)
			var disc := Medallion.new()
			disc.radius = 25*scale_by
			disc.position = centre
			add_child(disc)
			var art := MenuIcon.new()
			art.kind = KINDS[i]
			art.size = Vector2(36, 36)*scale_by
			art.position = centre-art.size*.5
			add_child(art)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[icons] -> ", path)
	get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("4466aa"))

class Medallion extends Node2D:
	var radius := 25.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, TofuShop.PAPER)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, NestTheme.INK, radius*.16, true)
