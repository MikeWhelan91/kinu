class_name NestSettingsScreen
extends RefCounted
## Settings on a wooden board: paper rows with sliders and segmented choices.

const CONTROL_DESCRIPTIONS := "Classic: drag anywhere to move, swipe the bottom strip to spin.\nGrab: press on Kinu to move it, swipe anywhere else to spin.\nClaw: a move stick and a spin stick with a Drop button between them, down one side of the screen."

static func show(app: Node) -> void:
	app._new_screen("settings", true)
	var layout = app._header("Settings")
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var list: VBoxContainer = app._vbox(scroll, 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var board := _board(list, "Sound")
	for item in [["music", "Music"], ["sfx", "Sound Effects"]]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := NestTheme.label(NestTheme.t("%s   %d%%")%[NestTheme.t(item[1]), int(float(Save.data[item[0]])*100)], 20)
		row.add_child(label)
		var slider := TouchSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .01
		slider.value = Save.data[item[0]]
		slider.custom_minimum_size = Vector2(0, 44)
		slider.value_changed.connect(func(value: float) -> void:
			Save.setting(item[0], value)
			Sound.apply_settings()
			label.text = NestTheme.t("%s   %d%%")%[NestTheme.t(item[1]), int(value*100)]
		)
		if item[0] == "sfx":
			slider.drag_ended.connect(func(_changed: bool) -> void: Sound.play("combo"))
		row.add_child(slider)
		board.add_child(NestTheme.paper(row))
	_choice(app, board, "Haptics", [["On", true], ["Off", false]], Save.data.haptics, func(value: Variant) -> void:
		Save.setting("haptics", value)
		Haptics.pulse()
	)
	_choice(app, _board(list, "Language"), "", [["Auto", ""], ["English", "en"], ["日本語", "ja"], ["繁體中文", "zh_TW"], ["한국어", "ko"]], Save.data.language, func(value: Variant) -> void:
		Save.setting("language", value)
		app.apply_language()
	)
	var controls := _board(list, "Controls")
	var explain := NestTheme.label(_control_description(str(Save.data.controls)), 15)
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice(app, controls, "", [["Classic", "classic"], ["Grab", "grab"], ["Claw", "claw"]], Save.data.controls, func(value: Variant) -> void:
		Save.setting("controls", value)
		explain.text = _control_description(str(value))
		(controls.get_node("ClawHandRow") as Control).visible = value == "claw"
	, false)
	var sticks := _choice(app, controls, "Sticks", [["Right Hand", "right"], ["Left Hand", "left"]], Save.data.claw_hand, func(value: Variant) -> void:
		Save.setting("claw_hand", value)
	, false)
	sticks.name = "ClawHandRow"
	sticks.visible = Save.data.controls == "claw"
	controls.add_child(NestTheme.paper(explain))
	var show_cloud_details := OS.is_debug_build()
	var cloud := _board(list, "iCloud Save" if show_cloud_details else "Save Conflict")
	var cloud_board := cloud.get_parent() as Control
	var cloud_status := NestTheme.label(app.cloud_kvs.status() if show_cloud_details else NestTheme.t("Your iPhone and iCloud have different progress. Choose which to keep."), 16)
	cloud_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cloud.add_child(NestTheme.paper(cloud_status))
	var transfer_history := NestTheme.label(app.cloud_kvs.transfer_history(), 15, NestTheme.MUTED)
	transfer_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if show_cloud_details and app.game_center.available:
		cloud.add_child(transfer_history)
	var cloud_choices := HBoxContainer.new()
	cloud_choices.add_theme_constant_override("separation", 8)
	var keep_device := NestTheme.button("Keep iPhone Save", func() -> void:
		if app.cloud_kvs.has_conflict():
			app.cloud_kvs.choose_device_save()
		else:
			app.game_center.choose_device_save()
	)
	keep_device.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cloud_choices.add_child(keep_device)
	var use_icloud := NestTheme.button("Use iCloud Save", func() -> void:
		if app.cloud_kvs.has_conflict():
			app.cloud_kvs.choose_icloud_save()
		else:
			app.game_center.choose_icloud_save()
	)
	use_icloud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cloud_choices.add_child(use_icloud)
	cloud_choices.visible = app.cloud_kvs.has_conflict() or app.game_center.has_cloud_conflict()
	cloud.add_child(cloud_choices)
	cloud_board.visible = show_cloud_details or cloud_choices.visible
	var update_cloud_status := func() -> void:
		if is_instance_valid(cloud_status):
			cloud_status.text = app.cloud_kvs.status() if show_cloud_details else NestTheme.t("Your iPhone and iCloud have different progress. Choose which to keep.")
			if show_cloud_details and app.game_center.has_cloud_conflict() and not app.cloud_kvs.has_conflict():
				cloud_status.text += "\n" + app.game_center.cloud_status()
			transfer_history.text = app.cloud_kvs.transfer_history()
			cloud_choices.visible = app.cloud_kvs.has_conflict() or app.game_center.has_cloud_conflict()
			cloud_board.visible = show_cloud_details or cloud_choices.visible
	app.game_center.cloud_status_changed.connect(update_cloud_status)
	app.cloud_kvs.status_changed.connect(update_cloud_status)
	cloud_status.tree_exiting.connect(func() -> void:
		if app.game_center.cloud_status_changed.is_connected(update_cloud_status):
			app.game_center.cloud_status_changed.disconnect(update_cloud_status)
		if app.cloud_kvs.status_changed.is_connected(update_cloud_status):
			app.cloud_kvs.status_changed.disconnect(update_cloud_status)
	)
	if show_cloud_details and app.game_center.available:
		cloud.add_child(NestTheme.button("Sync Now", app.cloud_kvs.sync_now))
	var more := _board(list, "More")
	more.add_child(NestTheme.button("Replay The Tutorial", func() -> void:
		Save.setting("tutorial", false)
		app._start()
	))
	more.add_child(NestTheme.button("Credits & Licences", app._credits))
	if OS.is_debug_build():
		more.add_child(NestTheme.button(NestTheme.t("Debug · Unlock Everything: %s")%NestTheme.t("On" if Save.data.debug_unlocked else "Off"), func() -> void:
			Save.setting("debug_unlocked", not Save.data.debug_unlocked)
			app.run.refresh_decor()
			app._settings()
		))
		more.add_child(NestTheme.button(NestTheme.t("Debug · Reset All Tutorials"), func() -> void:
			Save.reset_tutorials()
			app._home()
		))
	# The translations were written against "1.0"; the real version is dropped in after translating,
	# so this line never needs retranslating when the version changes.
	var version := str(ProjectSettings.get_setting("application/config/version", "1.0")).trim_suffix(".0")
	var footer := NestTheme.t("Your nest saves automatically.\nKINU TUMBLE  ·  1.0").replace("1.0", version)
	var note := NestTheme.label(footer, 15, NestTheme.MUTED)
	note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)

## A wooden board with a carved heading; returns the column to fill.
static func _board(list: VBoxContainer, title: String) -> VBoxContainer:
	var board := SignBoard.new()
	board.ropes = false
	list.add_child(board)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	board.add_child(column)
	var heading := NestTheme.headline(title, 26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	return column

## A labelled segmented choice; the current value is highlighted.
static func _control_description(mode: String) -> String:
	var lines := NestTheme.t(CONTROL_DESCRIPTIONS).split("\n")
	var index := ["classic", "grab", "claw"].find(mode)
	return lines[index] if index >= 0 and index < lines.size() else lines[0]

static func _choice(app: Node, parent: VBoxContainer, title: String, options: Array, current: Variant, apply: Callable, rebuild_page := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if title != "":
		var label := NestTheme.headline(title, 22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
	for option in options:
		var button := NestTheme.tab(option[0], option[1] == current, func() -> void:
			apply.call(option[1])
			if rebuild_page:
				app._settings()
			else:
				_paint_choice(row, option[1])
		)
		button.set_meta("choice_value", option[1])
		button.custom_minimum_size = Vector2(0, 58)
		button.add_theme_font_size_override("font_size", 16 if options.size() > 3 else 18)
		if title != "":
			button.size_flags_horizontal = Control.SIZE_FILL
		row.add_child(button)
	parent.add_child(row)
	return row

static func _paint_choice(row: HBoxContainer, selected: Variant) -> void:
	for child in row.get_children():
		if not child is Button:
			continue
		var button := child as Button
		if button.get_meta("choice_value") == selected:
			NestTheme.set_primary(button, true)
		else:
			NestTheme.set_primary(button, false)
			button.add_theme_stylebox_override("normal", NestTheme.box(NestTheme.WOOD_LIGHT, 22, NestTheme.INK, 8))
			button.add_theme_stylebox_override("hover", NestTheme.box(NestTheme.WOOD_LIGHT.lightened(.1), 22, NestTheme.INK, 8))

## Shared MIT terms for the iOS plugins shipped with the game.
const MIT_LICENSE := """Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."""

static func credits(app: Node) -> void:
	app._new_screen("credits", true)
	var layout = app._header("Credits", app._settings)
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var text := RichTextLabel.new()
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.bbcode_enabled = true
	text.add_theme_color_override("default_color", NestTheme.INK)
	text.add_theme_font_size_override("normal_font_size", 16)
	text.add_theme_font_size_override("bold_font_size", 20)
	text.text = "[b]Kinu Tumble[/b]\nOriginal characters, tofu shop and interface created for this game. Music and sound effects used under royalty-free licences.\n\n[b]Nunito[/b]\nVernon Adams, Cyreal, Jacques Le Bailly. SIL Open Font License 1.1.\n\n[b]M PLUS Rounded 1c[/b]\nCopyright 2016 The Rounded M+ Project Authors (Coji Morishita, M+ Fonts Project). SIL Open Font License 1.1, reproduced below.\n\n[b]jf open 粉圓[/b]\nCopyright 2020–2024 jf open huninn, redistributed by justfont Co., Ltd. SIL Open Font License 1.1; Hanzi derived from Kosugi Maru (Apache-2.0).\n\n[b]Noto Sans CJK KR[/b]\nCopyright 2014–2025 Adobe, Google and Noto contributors. SIL Open Font License 1.1, reproduced below.\n\n"+FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")+"\n\n[b]SwiftGodot and GodotApplePlugins[/b]\nCopyright (c) 2025 Miguel de Icaza. MIT License, reproduced below.\n\n[b]Godot AdMob Plugin[/b]\nCopyright (c) 2024-present Cengiz (cengiz-pz). MIT License, reproduced below.\n\n"+MIT_LICENSE+"\n\n[b]Godot Engine[/b]\n"+Engine.get_license_text()
	for info in Engine.get_copyright_info():
		text.text += "\n\n"+str(info.get("name", ""))
		for part in info.get("parts", []):
			text.text += "\n"+str(part.get("copyright", []))+"\n"+str(part.get("license", ""))
	for license_name in Engine.get_license_info():
		text.text += "\n\n"+license_name+"\n"+Engine.get_license_info()[license_name]
	var board := SignBoard.new()
	board.ropes = false
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.add_child(NestTheme.paper(text))
	scroll.add_child(board)
