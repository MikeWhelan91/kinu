class_name NestMenuScreen
extends RefCounted

static func home(app: Node) -> void:
	app.get_tree().paused = false
	app.run.show_menu()
	app._new_screen("home")
	var front := ShopFront.new()
	front.top_margin = app.safe_top
	app.screen.add_child(front)
	app.screen.move_child(front,1)
	var buttons = app._vbox(app.content,12)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_top = -250
	buttons.offset_left = 24
	buttons.offset_right = -24
	var play = NestTheme.button("Play",func() -> void:
		app._start()
		# The shop front parts over the new play screen as the game begins.
		var exit := ShopFront.new()
		exit.top_margin = app.safe_top
		exit.parting = true
		app.screen.add_child(exit)
	,true)
	play.custom_minimum_size.y = 84
	play.add_theme_font_size_override("font_size",32)
	buttons.add_child(play)
	var row = HBoxContainer.new()
	buttons.add_child(row)
	for item in [["Shop",app._shop],["Kinu Book",app._collection],["Settings",app._settings]]:
		var button = NestTheme.button(item[0],item[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",19)
		row.add_child(button)
	var flavours: Array[KinuFlavour] = app.run.catalog.flavours
	var stats_row = CenterContainer.new()
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_child(NestTheme.bean_pill("%s beans  ·  Best %s cm  ·  %d / %d flavours"%[app._number(Save.data.beans),app._number(Save.data.best),KinuBookScreen.found(flavours),flavours.size()],17))
	buttons.add_child(stats_row)

static func results(app: Node, stats: Dictionary) -> void:
	app.last_stats = stats
	var record = int(stats.score)>app.initial_best
	Save.finish_run(stats.score, float(stats.get("height",0.0)))
	var earned := NestRun.beans_for(int(stats.score), record)
	Save.add_beans(earned)
	app._new_screen("results")
	Sound.play("record" if record else "over")
	if record:
		Haptics.pulse(50,.75)
	var holder = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 70
	app.content.add_child(holder)
	var sign = SignBoard.new()
	sign.custom_minimum_size.x = 400
	holder.add_child(sign)
	var column = app._vbox(sign,6)
	# Kinu peeks over the top of the sign: worried after a tumble, delighted for a new best.
	var mascot = KinuPreview.new()
	mascot.setup(app.run.catalog.shapes[0],app.run.catalog.flavours[0],true,Vector2i(150,110),"happy" if record else "worried")
	var mascot_row = CenterContainer.new()
	mascot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mascot_row.add_child(mascot)
	column.add_child(mascot_row)
	var title = NestTheme.headline("New best!" if record else "Tumble!",58,NestTheme.SUN if record else NestTheme.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var ticket = PanelContainer.new()
	ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket.add_theme_stylebox_override("panel",SignBoard.paper())
	column.add_child(ticket)
	var tally = app._vbox(ticket,-8)
	app._center_label(tally,"TOWER HEIGHT",16,NestTheme.MUTED)
	var big = NestTheme.headline(app._number(stats.score)+" cm",76,NestTheme.SUN)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_child(big)
	var chips = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation",10)
	column.add_child(chips)
	chips.add_child(NestTheme.pill("%d Kinu stacked"%int(stats.get("placed",0)),18))
	chips.add_child(NestTheme.bean_pill("+%d"%earned,18))
	var buttons = app._vbox(app.content,12)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_top = -170
	buttons.offset_left = 24
	buttons.offset_right = -24
	var again = NestTheme.button("Play again",app._start,true)
	again.custom_minimum_size.y = 80
	again.add_theme_font_size_override("font_size",30)
	buttons.add_child(again)
	buttons.add_child(NestTheme.button("Main menu",app._home))
	if record:
		app._confetti()
