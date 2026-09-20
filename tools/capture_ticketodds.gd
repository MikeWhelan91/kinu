extends Node
## Opens the ticket shop and its odds sheet, into out= (a folder).
var options := {"out": "user://"}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	get_window().size = Vector2i(393, 852)
	Save.save_path = "user://capture_ticketodds.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	Save.data.best = 40
	var app := load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(1.0).timeout
	app._bean_shop("tickets")
	await get_tree().create_timer(1.0).timeout
	await shot("ticketshop")
	var odds = app.content.find_child("TicketOdds", true, false)
	if odds is Button:
		odds.emit_signal("pressed")
		await get_tree().create_timer(1.0).timeout
		await shot("ticketodds")
	else:
		print("ODDS BUTTON MISSING")
	get_tree().quit()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(options.out).path_join(name+".png"))
