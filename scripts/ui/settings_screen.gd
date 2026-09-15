class_name NestSettingsScreen
extends RefCounted

static func show(app: Node) -> void:
	app._new_screen("settings",true)
	var layout = app._header("Your cosy corner")
	var scroll = DragScroll.new()
	layout.add_child(scroll)
	var list = app._vbox(scroll,18)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app._center_label(list,"A little quiet, or a little joy.",20,NestTheme.MUTED)
	for item in [["music","Garden music"],["sfx","Sound effects"]]:
		var card = PanelContainer.new()
		list.add_child(card)
		var stack = app._vbox(card,12)
		var label = NestTheme.label("%s   %d%%"%[item[1],int(float(Save.data[item[0]])*100)],22)
		stack.add_child(label)
		var slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .01
		slider.value = Save.data[item[0]]
		slider.custom_minimum_size = Vector2(0,48)
		slider.value_changed.connect(func(value: float) -> void:
			Save.setting(item[0],value)
			Sound.apply_settings()
			label.text = "%s   %d%%"%[item[1],int(value*100)]
		)
		if item[0] == "sfx":
			slider.drag_ended.connect(func(_changed: bool) -> void: Sound.play("combo"))
		stack.add_child(slider)
	var haptic = NestTheme.button("Haptics   "+("On" if Save.data.haptics else "Off"),func() -> void:
		Save.setting("haptics",not Save.data.haptics)
		Haptics.pulse()
		app._settings()
	)
	list.add_child(haptic)
	if OS.is_debug_build():
		list.add_child(NestTheme.button("Debug · unlock all   "+("On" if Save.data.debug_unlocked else "Off"),func() -> void:
			Save.setting("debug_unlocked",not Save.data.debug_unlocked)
			app.run.refresh_decor()
			app._settings()
		))
	var classic: bool = Save.data.controls == "classic"
	var controls = NestTheme.button("Controls   "+("Classic" if classic else "Grab"),func() -> void:
		Save.setting("controls","grab" if classic else "classic")
		app._settings()
	)
	list.add_child(controls)
	var explain = app._center_label(list,"Classic: drag anywhere to move, swipe the bottom strip to spin.\nGrab: press on Kinu to move it, swipe anywhere else to spin.",15,NestTheme.MUTED)
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(NestTheme.button("Replay the little tutorial",func() -> void:
		Save.setting("tutorial",false)
		app._start()
	))
	list.add_child(NestTheme.button("Credits & licences",app._credits))
	var note = app._center_label(list,"Your nest saves automatically.\nNo accounts. No ads. Just Kinu.",18,NestTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app._center_label(list,"KINU TUMBLE  ·  1.0",13,NestTheme.MUTED)

static func credits(app: Node) -> void:
	app._new_screen("credits",true)
	var layout = app._header("Made with care",app._settings)
	var scroll = DragScroll.new()
	layout.add_child(scroll)
	var text = RichTextLabel.new()
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.bbcode_enabled = true
	text.add_theme_color_override("default_color",NestTheme.INK)
	text.text = "[b]Kinu Tumble[/b]\nOriginal character, tofu shop, interface, music and sound effects created for this game.\n\n[b]Nunito[/b]\nVernon Adams, Cyreal, Jacques Le Bailly. SIL Open Font License 1.1.\n\n"+FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")+"\n\n[b]Godot Engine[/b]\n"+Engine.get_license_text()
	for info in Engine.get_copyright_info():
		text.text += "\n\n"+str(info.get("name",""))
		for part in info.get("parts",[]):
			text.text += "\n"+str(part.get("copyright",[]))+"\n"+str(part.get("license",""))
	for license_name in Engine.get_license_info():
		text.text += "\n\n"+license_name+"\n"+Engine.get_license_info()[license_name]
	scroll.add_child(text)
