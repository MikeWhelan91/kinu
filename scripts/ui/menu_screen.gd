class_name NestMenuScreen
extends RefCounted

## The Modes sheet is built and works, but its "?" button crowded the mode row, so it is off the
## home screen for now. `modes()` below is kept ready for wherever it earns its place.
const SHOW_MODES_SHEET := false
## Pick once per app launch so the treat banner feels fresh without flickering on every reopen.
static var daily_treat_outfit_id := ""

## The touch target follows the cloth outline, including its slanted sides.
class CurtainButton extends Button:
	var hit_polygon := PackedVector2Array()

	func _has_point(point: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(point,hit_polygon)

static func home(app: Node) -> void:
	app.get_tree().paused = false
	Sound.play_room_music(str(Save.data.room))
	app.run.show_menu()
	app._new_screen("home")
	var front := ShopFront.new()
	front.top_margin = app.safe_top
	front.decor = app.run.room.decor
	app.screen.add_child(front)
	app.screen.move_child(front,1)
	# Play is the home screen's hero: the same prize-cabinet style as My Kinu and the Claw, in sun
	# gold, with a pulsing play badge.
	var play := GachaButton.new()
	play.name = "Play"
	play.icon_kind = "play"
	play.centered = true
	play.title_size = 36
	play.title_text = NestTheme.t("Play")
	play.top_color = Color("ffe066")
	play.bottom_color = Color("f59e1b")
	play.edge_color = Color("8a5310")
	_gacha_press(play,"tap",func() -> void:
		Sound.play("homeplay")
		app._start()
		# The shop front parts over the new play screen as the game begins.
		var exit := ShopFront.new()
		exit.top_margin = app.safe_top
		exit.decor = app.run.room.decor
		exit.parting = true
		app.screen.add_child(exit)
		_curtain_button(exit,"Shop","shop",Callable(),0)
		_curtain_button(exit,"Wardrobe","wardrobe",Callable(),1)
		_curtain_button(exit,"Kinu Book","book",Callable(),2)
		_curtain_button(exit,"Daily","daily",Callable(),3)
	)
	# Each noren panel doubles as a navigation tab, making the controls part of the shop front.
	_curtain_button(front,"Shop","shop",app._shop,0,"cashregister")
	_curtain_button(front,"Wardrobe","wardrobe",app._wardrobe,1,"wardrobe")
	_curtain_button(front,"Kinu Book","book",app._collection,2,"book")
	if Save.fresh_count() > 0:
		# Unlocks from recent runs wait in the Kinu Book until they've been looked at.
		var book_badge := NestTheme.count_badge(Save.fresh_count())
		book_badge.position = Vector2(14,-44)
		for child in front.get_children():
			if child.get_meta("curtain_panel",-1) == 2:
				child.add_child(book_badge)
	var daily_curtain := _curtain_button(front,"Daily","daily",func() -> void: daily_missions(app),3,"book")
	# The Daily curtain is the missions list; its badge counts missions ready to collect. The daily
	# treat and the Monthly Showcase have their own buttons on the event rail.
	var daily_ready := KinuProgress.claimable() + (1 if KinuProgress.weekly_claimable() else 0)
	if daily_ready > 0:
		var daily_badge := NestTheme.count_badge(daily_ready)
		daily_badge.position = Vector2(15, -34)
		daily_curtain.add_child(daily_badge)
	# The bottom controls sit together on a quiet lacquered control tray. The shop is already
	# visually busy, so this deliberately uses fine pinstriping rather than the thick, toy-block
	# outlines used elsewhere in the game. Reading order down the tray is mode, Play, prizes.
	var tray_width := minf(app.get_viewport().get_visible_rect().size.x-28,392)
	var play_row := CenterContainer.new()
	play_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	play_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	play_row.offset_bottom = -maxf(14,app.safe_bottom)
	app.content.add_child(play_row)
	var console := PanelContainer.new()
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console.custom_minimum_size.x = tray_width
	console.add_theme_stylebox_override("panel",_tray_style())
	play_row.add_child(console)
	var play_stack := VBoxContainer.new()
	play_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	play_stack.add_theme_constant_override("separation",10)
	console.add_child(play_stack)
	# Mode row: the segmented picker, with the mode blurbs on the button beside it.
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation",8)
	play_stack.add_child(mode_row)
	var picker := _mode_picker(app,front)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(picker)
	if SHOW_MODES_SHEET:
		var about := _home_action_button("?", Color("77492f"), func() -> void:
			modes(app,front)
		,48,"",false,"book")
		about.name = "AboutModes"
		about.custom_minimum_size.x = 48
		mode_row.add_child(about)
	# Play is the one unmissable control: the full width of the tray, and the only sun-yellow
	# surface on it.
	play.custom_minimum_size.y = 86
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_stack.add_child(play)
	# My Kinu is the player's progression hub, so it sits beside the prize counter on Home.
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation",10)
	play_stack.add_child(secondary)
	# Both are prize-machine cabinets with their own illustration popping over the top edge.
	var my_kinu := GachaButton.new()
	my_kinu.name = "MyKinuHome"
	my_kinu.icon_kind = "my_kinu"
	my_kinu.title_text = NestTheme.t("My Kinu")
	var level_progress := MyKinu.progress_for(MyKinu.xp())
	my_kinu.subtitle_text = NestTheme.t("Level %d")%MyKinu.level()
	my_kinu.progress = float(level_progress[0])/maxf(1.0,float(level_progress[1]))
	my_kinu.kinu_color = MyKinu.base(app.run.catalog).color
	my_kinu.top_color = Color("a98bff")
	my_kinu.bottom_color = Color("6b46d9")
	my_kinu.edge_color = Color("3b2283")
	# New parts the player has not looked at yet, in slots they can wear.
	my_kinu.badge = MyKinu.fresh_parts()
	_gacha_press(my_kinu,"wardrobe",func() -> void: MyKinuScreen.show(app,app._home))
	secondary.add_child(my_kinu)
	var catcher := GachaButton.new()
	catcher.name = "Catcher"
	catcher.icon_kind = "claw"
	catcher.title_text = NestTheme.t("Kinu Claw")
	var free_plays := KinuCatcher.free_remaining()
	catcher.subtitle_text = NestTheme.t("%d free plays")%free_plays if free_plays > 0 else NestTheme.t("%d tickets")%int(Save.data.tickets)
	catcher.ribbon = NestTheme.t("FREE") if free_plays > 0 else ""
	catcher.top_color = Color("ff86b4")
	catcher.bottom_color = Color("e2457f")
	catcher.edge_color = Color("8d2a55")
	_gacha_press(catcher,"cashregister",func() -> void: KinuCatcherScreen.show(app))
	secondary.add_child(catcher)
	for button in [my_kinu,catcher]:
		button.custom_minimum_size.y = 78
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The event rail stands on the left edge halfway between the curtains' hems and the tray, where
	# live games keep their event buttons: clear of both, and in easy reach.
	var rail := EventRail.build(app)
	rail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	rail.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rail.offset_left = -14
	app.content.add_child(rail)
	_seat_rail(rail,front,console)
	# Keep currency together at top-left; Settings occupies the matching top-right shortcut.
	var purse := VBoxContainer.new()
	purse.alignment = BoxContainer.ALIGNMENT_BEGIN
	purse.add_theme_constant_override("separation",6)
	purse.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# `content` already has the app-wide safety gutter, so do not add a second visual inset here.
	# The pull-up is dropped while a banner is showing: `content` starts below the ad, and pulling
	# back above that line puts the wallet under the ad instead of beside it.
	var lift := 0.0 if app.banner_showing() else -14.0
	purse.offset_left = -14
	purse.offset_right = -14
	purse.offset_top = lift
	purse.offset_bottom = lift
	app.content.add_child(purse)
	var wallet := BeanShop.WalletButton.new()
	wallet.pressed.connect(func() -> void: app._bean_shop())
	wallet.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	purse.add_child(wallet)
	# Tickets sit under the beans, and go straight to their own half of the shop.
	var tickets := BeanShop.TicketWalletButton.new()
	tickets.pressed.connect(func() -> void: app._bean_shop("tickets"))
	tickets.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	purse.add_child(tickets)
	var free_reset := NestTheme.label("", 12, NestTheme.CREAM)
	free_reset.add_theme_color_override("font_outline_color", NestTheme.INK)
	free_reset.add_theme_constant_override("outline_size", 4)
	purse.add_child(free_reset)
	var update_free_reset := func() -> void:
		if is_instance_valid(free_reset):
			free_reset.text = KinuCatcher.free_reset_text()
	update_free_reset.call()
	var free_clock := Timer.new()
	free_clock.wait_time = 1.0
	free_clock.timeout.connect(update_free_reset)
	purse.add_child(free_clock)
	free_clock.start()
	var top_actions := HBoxContainer.new()
	top_actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_actions.add_theme_constant_override("separation",6)
	top_actions.offset_left = -136
	app.content.add_child(top_actions)
	var leaderboards := _icon_button(top_actions, "Leaderboards", "leaderboards", app._leaderboards, 64, false, Color("4b5da8"))
	_update_leaderboard_button(leaderboards,NestRun.chosen_mode())
	_icon_button(top_actions, "Settings", "settings", app._settings, 64, false)
	var settings_lift := 0.0 if app.banner_showing() else -24.0
	top_actions.offset_top = settings_lift
	top_actions.offset_bottom = settings_lift
	if not _show_kinu_home_progress(app):
		GrandOpening.prompt(app)

## Finished runs bank XP immediately, but the reveal waits until the player comes home. A chain
## of Play Again runs therefore becomes one short celebration instead of lengthening each result.
static func _show_kinu_home_progress(app: Node) -> bool:
	var to_xp := MyKinu.xp()
	var from_xp := clampi(int(Save.data.my_kinu.get("home_seen_xp",to_xp)),0,to_xp)
	var intro := int(Save.data.runs) > 0 and not bool(Save.data.my_kinu.intro_seen)
	if to_xp == from_xp and not intro:
		return false
	var before_level := MyKinu.level_for(from_xp)
	var after_level := MyKinu.level_for(to_xp)
	var rewards := _kinu_rewards_between(before_level,after_level)
	# A single rounded celebration floats over home instead of the usual wooden sign and
	# a second reward card. All runs since the last visit share this one reveal.
	if is_instance_valid(app.modal):
		app.modal.queue_free()
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_to_group("modal_input_lock")
	app.modal = overlay
	app.screen.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(.14,.07,.16,.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var screen_width: float = app.get_viewport().get_visible_rect().size.x
	var card := FancyCard.new()
	card.name = "MyKinuHomeProgress"
	card.custom_minimum_size.x = minf(420,screen_width-32)
	card.ray_origin = Vector2(.5,.3)
	center.add_child(card)
	var stack: VBoxContainer = app._vbox(card,8)
	var banner_row := CenterContainer.new()
	banner_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner := FancyCard.Banner.new()
	banner.text = NestTheme.t("My Kinu").to_upper()
	banner.color = Color("8f6bea")
	banner.font_size = 24
	banner_row.add_child(banner)
	stack.add_child(banner_row)
	# Kinu in a glowing halo on a little gold dais, wearing its newest part if one arrived.
	var halo := KinuHalo.new()
	halo.custom_minimum_size = Vector2(0,170)
	halo.glow = MyKinu.base(app.run.catalog).color.lightened(.3)
	stack.add_child(halo)
	var preview := KinuPreview.new()
	var shown_parts: Array[KinuPart] = MyKinu.equipped(app.run.catalog)
	if not rewards.parts.is_empty():
		shown_parts.clear()
		shown_parts.append(rewards.parts[0] as KinuPart)
	preview.setup(app.run.catalog.shapes[0],MyKinu.base(app.run.catalog),true,Vector2i(200,150),"happy",null,true,false,shown_parts)
	preview.fit_model(1.1,true)
	preview.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	preview.offset_left = -100
	preview.offset_right = 100
	preview.offset_top = 0
	preview.offset_bottom = 150
	halo.add_child(preview)
	var numbers := HBoxContainer.new()
	numbers.alignment = BoxContainer.ALIGNMENT_CENTER
	numbers.add_theme_constant_override("separation",14)
	stack.add_child(numbers)
	var level_label := NestTheme.headline(NestTheme.t("Level %d")%before_level,28,Color("8f6bea"))
	level_label.name = "MyKinuHomeLevel"
	numbers.add_child(level_label)
	var earned_label := NestTheme.headline(NestTheme.t("+0 XP"),34,Color("ffd34a"))
	earned_label.name = "MyKinuHomeXP"
	numbers.add_child(earned_label)
	earned_label.resized.connect(func() -> void: earned_label.pivot_offset = earned_label.size*.5)
	var xp_pulse := earned_label.create_tween().set_loops()
	xp_pulse.tween_property(earned_label,"scale",Vector2(1.08,1.08),.8).set_trans(Tween.TRANS_SINE)
	xp_pulse.tween_property(earned_label,"scale",Vector2.ONE,.8).set_trans(Tween.TRANS_SINE)
	var before_progress := MyKinu.progress_for(from_xp)
	var xp_bar := FancyCard.XpMeter.new()
	xp_bar.name = "MyKinuHomeBar"
	xp_bar.level = before_level
	xp_bar.max_value = before_progress[1]
	xp_bar.value = before_progress[0]
	xp_bar.custom_minimum_size.y = 40
	stack.add_child(xp_bar)
	var final_progress := MyKinu.progress_for(to_xp)
	var next_label: Label = app._center_label(stack,NestTheme.t("%d / %d XP · Next: %s")%[final_progress[0],final_progress[1],MyKinuScreen.next_reward(after_level+1)],15,MyKinuScreen.SKY_TEXT)
	next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var gifts: Array[String] = []
	if after_level > before_level:
		for slot in rewards.slots:
			gifts.append(NestTheme.t("New slot: %s")%NestTheme.t(MyKinu.SLOT_NAMES[slot]))
		var part_names: Array[String] = []
		for part in rewards.parts:
			part_names.append(part.display_name)
		if not part_names.is_empty():
			var shown_names: Array[String] = part_names.slice(0,2)
			gifts.append(NestTheme.t("New part: %s")%(NestTheme.t_join(shown_names)+(" …" if part_names.size() > 2 else "")))
		if int(rewards.tickets) > 0:
			gifts.append(NestTheme.t("+%d Catcher tickets")%int(rewards.tickets))
		gifts.append(NestTheme.t("+%d level-up beans")%int(rewards.beans))
	elif intro:
		gifts.append(NestTheme.t("Meet My Kinu! Dress it up in the Wardrobe."))
	for gift in gifts:
		stack.add_child(_reward_row(gift))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	stack.add_child(actions)
	var done := GachaButton.new()
	done.name = "Done"
	done.icon_kind = ""
	done.centered = true
	done.title_text = NestTheme.t("Done")
	done.top_color = Color("fffaf0")
	done.bottom_color = Color("ead6bb")
	done.edge_color = Color("7a5a40")
	_gacha_press(done,"tap",func() -> void:
		Save.acknowledge_kinu_progress()
		app._close_modal()
		GrandOpening.prompt(app)
	)
	actions.add_child(done)
	var dress := GachaButton.new()
	dress.name = "Dress My Kinu"
	dress.icon_kind = "my_kinu"
	dress.title_text = NestTheme.t("Dress My Kinu")
	dress.kinu_color = MyKinu.base(app.run.catalog).color
	dress.top_color = Color("ff86b4")
	dress.bottom_color = Color("e2457f")
	dress.edge_color = Color("8d2a55")
	_gacha_press(dress,"wardrobe",func() -> void:
		Save.acknowledge_kinu_progress()
		app._close_modal()
		MyKinuScreen.show(app,app._home)
	)
	actions.add_child(dress)
	for button in [done,dress]:
		button.custom_minimum_size.y = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dress.size_flags_stretch_ratio = 1.5
	card.scale = Vector2.ONE
	card.modulate.a = 0
	var entrance := card.create_tween()
	entrance.tween_property(card,"modulate:a",1.0,.22)
	var finished_at := _animate_kinu_xp(app,xp_bar,level_label,earned_label,from_xp,to_xp,.25)
	if after_level > before_level:
		var progress_modal: Control = app.modal
		var celebration := progress_modal.create_tween()
		celebration.tween_interval(finished_at)
		celebration.tween_callback(func() -> void:
			if is_instance_valid(app) and app.page == "home" and is_instance_valid(progress_modal) and app.modal == progress_modal:
				_kinu_reward_burst(progress_modal,card))
	return true

## My Kinu's growth on the results card: XP earned since it was last shown (one run, or a chain of
## Play Again runs), the meter filling through any level-ups, and what those levels gave. Showing it
## here acknowledges it, so the home screen does not replay it.
static func _results_kinu_xp(app: Node, column: VBoxContainer, beat: float) -> float:
	var to_xp := MyKinu.xp()
	var from_xp := clampi(int(Save.data.my_kinu.get("home_seen_xp",to_xp)),0,to_xp)
	var intro := not bool(Save.data.my_kinu.intro_seen)
	if to_xp == from_xp and not intro:
		return beat
	var before_level := MyKinu.level_for(from_xp)
	var after_level := MyKinu.level_for(to_xp)
	var panel := PanelContainer.new()
	panel.name = "ResultsKinuXP"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1,1,1,.72)
	style.border_color = Color("8f6bea")
	style.set_border_width_all(3)
	style.border_width_bottom = 5
	style.set_corner_radius_all(18)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	style.anti_aliasing = true
	panel.add_theme_stylebox_override("panel",style)
	column.add_child(panel)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation",4)
	panel.add_child(stack)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation",14)
	stack.add_child(head)
	var face := KinuPreview.new()
	face.setup(app.run.catalog.shapes[0],MyKinu.base(app.run.catalog),true,Vector2i(58,48),"happy",null,true,false,MyKinu.equipped(app.run.catalog))
	face.fit_model(1.05)
	head.add_child(face)
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation",-4)
	head.add_child(names)
	names.add_child(NestTheme.label(NestTheme.t("My Kinu"),14,NestTheme.MUTED))
	var level_label := NestTheme.headline(NestTheme.t("Level %d")%before_level,22,Color("8f6bea"))
	level_label.name = "ResultsKinuLevel"
	names.add_child(level_label)
	var earned_label := NestTheme.headline(NestTheme.t("+%d XP")%(to_xp-from_xp),28,Color("ffd34a"))
	earned_label.name = "ResultsKinuGain"
	earned_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(earned_label)
	var before_progress := MyKinu.progress_for(from_xp)
	var meter := FancyCard.XpMeter.new()
	meter.name = "ResultsKinuMeter"
	meter.level = before_level
	meter.max_value = before_progress[1]
	meter.value = before_progress[0]
	meter.custom_minimum_size.y = 34
	stack.add_child(meter)
	var final_progress := MyKinu.progress_for(to_xp)
	var next_label := NestTheme.label(NestTheme.t("%d / %d XP · Next: %s")%[final_progress[0],final_progress[1],MyKinuScreen.next_reward(after_level+1)],13,MyKinuScreen.SKY_TEXT)
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(next_label)
	var gifts: Array[String] = []
	if after_level > before_level:
		var rewards := _kinu_rewards_between(before_level,after_level)
		gifts.append(NestTheme.t("My Kinu reached level %d!")%after_level)
		for slot in rewards.slots:
			gifts.append(NestTheme.t("New slot: %s")%NestTheme.t(MyKinu.SLOT_NAMES[slot]))
		for part in rewards.parts:
			gifts.append(NestTheme.t("New part: %s")%NestTheme.t(part.display_name))
		if int(rewards.tickets) > 0:
			gifts.append(NestTheme.t("+%d Catcher tickets")%int(rewards.tickets))
		gifts.append(NestTheme.t("+%d level-up beans")%int(rewards.beans))
	elif intro:
		gifts.append(NestTheme.t("Meet My Kinu! Dress it up in the Wardrobe."))
	beat += .3
	_reveal(app,panel,beat,"special")
	var finished := _animate_kinu_xp(app,meter,level_label,earned_label,from_xp,to_xp,beat+.15)
	for gift in gifts:
		var row := _reward_row(gift)
		stack.add_child(row)
		_reveal(app,row,finished,"")
	Save.acknowledge_kinu_progress()
	return beat

## A small stat tile for the results card: an icon, the value and its name.
static func _stat_tile(title: String, value: String, icon: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(124, 0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, .82)
	style.border_color = NestTheme.INK
	style.set_border_width_all(3)
	style.border_width_bottom = 5
	style.set_corner_radius_all(16)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	style.anti_aliasing = true
	tile.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 8)
	tile.add_child(line)
	var art: Control
	if icon == "beans":
		art = BeanIcon.new()
	else:
		art = StatIcon.new()
		(art as StatIcon).kind = icon
	art.custom_minimum_size = Vector2(30, 30)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(art)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", -4)
	line.add_child(text)
	var amount := NestTheme.label(value, 22)
	amount.name = "Value"
	text.add_child(amount)
	text.add_child(NestTheme.label(NestTheme.t(title), 12, NestTheme.MUTED))
	return tile

## Little drawn icons for the stat tiles: a ruler for height, a Kinu for counts.
class StatIcon extends Control:
	var kind := "kinu"
	func _draw() -> void:
		var s := minf(size.x, size.y)
		if kind == "height":
			var bar := Rect2(Vector2(s*.32, s*.04), Vector2(s*.36, s*.92))
			draw_colored_polygon(MyKinuScreen.rounded_points(bar, 4), NestTheme.SKY)
			var line := MyKinuScreen.rounded_points(bar, 4)
			line.append(line[0])
			draw_polyline(line, NestTheme.INK, 2.0, true)
			for i in 5:
				var y := s*(.16+.17*i)
				draw_line(Vector2(s*.32, y), Vector2(s*(.48 if i % 2 else .56), y), NestTheme.INK, 2.0, true)
		else:
			var body := Rect2(Vector2(s*.1, s*.18), Vector2(s*.8, s*.66))
			draw_colored_polygon(MyKinuScreen.rounded_points(body, s*.16), Color("fff3dc"))
			var line := MyKinuScreen.rounded_points(body, s*.16)
			line.append(line[0])
			draw_polyline(line, NestTheme.INK, 2.0, true)
			for side in [-1.0, 1.0]:
				draw_circle(Vector2(s*.5+side*s*.16, s*.48), s*.05, NestTheme.INK)
				draw_circle(Vector2(s*.5+side*s*.27, s*.62), s*.05, Color("ff9fb0"))

## A soft glow and a small gold dais for a Kinu preview to stand in.
class KinuHalo extends Control:
	var glow := Color("ffe9a0")
	var phase := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()

	func _draw() -> void:
		var centre := Vector2(size.x*.5, size.y*.48)
		for i in 14:
			var t := float(i)/14.0
			draw_circle(centre, size.y*.55*(1.0-t*.8), Color(glow, .05+t*.03))
		var dais := Vector2(size.x*.5, size.y-18)
		draw_colored_polygon(MyKinuScreen.ellipse_points(dais+Vector2(0, 10), Vector2(86, 12)), Color(0, 0, 0, .18))
		var top := MyKinuScreen.ellipse_points(dais, Vector2(78, 15))
		var side := MyKinuScreen.ellipse_points(dais+Vector2(0, 7), Vector2(78, 15))
		draw_colored_polygon(side, MyKinuScreen.GOLD_DEEP)
		var lit := PackedColorArray()
		for point in top:
			lit.append(MyKinuScreen.GOLD_LIGHT.lerp(MyKinuScreen.GOLD, clampf((point.y-dais.y+15)/30.0, 0, 1)))
		draw_polygon(top, lit)
		var rim := top.duplicate()
		rim.append(top[0])
		draw_polyline(rim, NestTheme.INK, 2.5, true)
		for i in 4:
			var angle := phase*.8+TAU*i/4.0
			var at := centre+Vector2(cos(angle)*size.y*.55, sin(angle)*size.y*.22)
			var twinkle := .5+.5*sin(phase*3.0+i)
			var star := PackedVector2Array()
			for j in 8:
				star.append(at+Vector2.UP.rotated(TAU*j/8.0)*5.0*twinkle*(1.7 if j % 2 == 0 else .38))
			draw_colored_polygon(star, Color("fff3b0"))

## One reward line in a celebration: a gold star and the text on a soft white strip.
static func _reward_row(text: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, .78)
	style.border_color = MyKinuScreen.GOLD_DEEP
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	style.anti_aliasing = true
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	line.add_child(NestTheme.headline("✦", 18, NestTheme.SUN))
	var label := NestTheme.label(text, 16, Color("5b3aa8"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	return row

static func _kinu_reward_burst(overlay: Control, card: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var origin := card.get_global_rect().get_center()
	for i in 16:
		var sparkle := NestTheme.headline("✦",rng.randi_range(18,31),[NestTheme.SUN,NestTheme.BERRY,NestTheme.CREAM,NestTheme.PURPLE][i%4])
		var angle := TAU*float(i)/16.0+rng.randf_range(-.18,.18)
		var direction := Vector2.RIGHT.rotated(angle)
		sparkle.position = origin+direction*160.0-Vector2(18,18)
		overlay.add_child(sparkle)
		overlay.move_child(sparkle,1)
		var distance := rng.randf_range(250,315)
		var flight := sparkle.create_tween().set_parallel(true)
		flight.tween_property(sparkle,"position",origin+direction*distance-Vector2(18,18),.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		flight.tween_property(sparkle,"rotation",rng.randf_range(-2.5,2.5),.75)
		flight.tween_property(sparkle,"modulate:a",0.0,.75).set_delay(.13)
		flight.chain().tween_callback(sparkle.queue_free)

static func _kinu_celebration_button(button: Button, color: Color, border: Color) -> void:
	for state in ["normal","hover","pressed"]:
		var style := NestTheme.box(color.lightened(.07) if state == "hover" else color,25,border,3)
		style.set_border_width_all(2)
		style.content_margin_left = 9
		style.content_margin_right = 9
		style.content_margin_top = 6
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state,style)

## Read-only recap: the actual items and currency were already granted by finish_run.
static func _kinu_rewards_between(before_level: int, after_level: int) -> Dictionary:
	var rewards := {"beans": 0, "tickets": 0, "parts": [], "slots": []}
	for reached in range(before_level+1,after_level+1):
		rewards.beans += MyKinu.level_beans(reached)
		for slot in MyKinu.SLOTS:
			if MyKinu.slot_level(slot) == reached:
				rewards.slots.append(slot)
		if reached % MyKinu.LEVEL_PART_EVERY == 0:
			var part := MyKinu.level_part(reached)
			if part:
				rewards.parts.append(part)
			else:
				rewards.tickets += MyKinu.SPARE_TICKETS
	return rewards

## A labelled icon centred over one of the four decorative medallions woven into the noren.
static func _curtain_button(front: ShopFront, title: String, icon: String, callback: Callable, index: int, sound: String = "plop") -> Node2D:
	# Animate a Node2D transform so Control pixel snapping cannot quantise the sway.
	var holder := Node2D.new()
	holder.set_meta("curtain_panel",index)
	front.add_child(holder)
	var button := CurtainButton.new()
	button.name = title
	button.flat = true
	button.set_meta("curtain_target",true)
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP if callback.is_valid() else Control.MOUSE_FILTER_IGNORE
	if callback.is_valid():
		button.pressed.connect(func() -> void:
			Sound.play(sound)
			callback.call()
		)
	holder.add_child(button)
	var art := MenuIcon.new()
	art.kind = icon
	art.position = Vector2(-26,-26)
	art.size = Vector2(52,52)
	holder.add_child(art)
	front._layout_navigation()
	return holder

## Centres the rail in the open space between the curtains' hems and the tray, once both have
## their real sizes; hidden until then.
static func _seat_rail(rail: Control, front: ShopFront, tray: Control) -> void:
	rail.modulate.a = 0
	await rail.get_tree().process_frame
	if not is_instance_valid(rail) or not is_instance_valid(front) or not is_instance_valid(tray):
		return
	var holder := rail.get_parent() as Control
	var hem := front.global_position.y+front.hem_y(front.size.y)
	var bottom := (hem+tray.global_position.y+rail.size.y)*.5
	rail.offset_bottom = bottom-(holder.global_position.y+holder.size.y)
	rail.offset_top = rail.offset_bottom
	rail.modulate.a = 1

## A round wooden button with a drawn icon and, optionally, a carved label underneath.
## The button is named after its label so it can be found by name.
static func _icon_button(parent: Node, title: String, icon: String, callback: Callable, diameter: float = 84, labelled: bool = true, fill: Color = NestTheme.WOOD) -> Button:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation",0)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(holder)
	var button := NestTheme.button("",callback)
	button.name = title
	button.custom_minimum_size = Vector2(diameter,diameter)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal","hover","pressed"]:
		var style := NestTheme.box(fill.lightened(.08 if state == "hover" else 0.0),int(diameter*.5),NestTheme.INK,4 if state == "pressed" else 7)
		style.set_content_margin_all(0)
		button.add_theme_stylebox_override(state,style)
	holder.add_child(button)
	var art := MenuIcon.new()
	art.kind = icon
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = diameter*.16
	art.offset_right = -diameter*.16
	art.offset_top = diameter*.14
	art.offset_bottom = -diameter*.2
	button.add_child(art)
	if labelled:
		var label := NestTheme.headline(title,12 if diameter <= 60 else 15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = diameter+6
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		holder.add_child(label)
	return button

## Pause mirrors the results screen: a sign hung on ropes from above the screen, actions below.
## It remains an overlay so resuming preserves the exact tower and camera position.
static func pause(app: Node) -> void:
	app._close_modal()
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	app.screen.add_child(overlay)
	app.modal = overlay
	var shade := ColorRect.new()
	shade.color = Color(.10,.08,.17,.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = app.safe_top+70
	overlay.add_child(holder)
	var sign := SignBoard.new()
	sign.rope_length = app.safe_top+160
	sign.custom_minimum_size.x = 400
	holder.add_child(sign)
	var column: VBoxContainer = app._vbox(sign,6)
	column.add_child(_mascot(app,app.run.active,"content"))
	var title := NestTheme.headline("Paused",58,NestTheme.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var ticket := PanelContainer.new()
	ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket.add_theme_stylebox_override("panel",SignBoard.paper())
	column.add_child(ticket)
	var tally: VBoxContainer = app._vbox(ticket,-8)
	var mode: String = app.run.mode
	app._center_label(tally,_score_title(mode),16,NestTheme.MUTED)
	var count := NestTheme.headline(_score_text(app,mode,app.run.score),76,NestTheme.SUN)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_child(count)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation",10)
	column.add_child(chips)
	chips.add_child(NestTheme.pill(NestTheme.t("%s Tall")%KinuFlavour.height_text(NestRun.height_cm(app.run.tower_height)),18))
	var left: int = NestRun.MAX_TUMBLES-app.run.tumbles
	if mode == "toss":
		var misses: int = TossPlay.MAX_MISSES-app.run.tumbles
		chips.add_child(NestTheme.pill(NestTheme.t("1 Miss Left") if misses == 1 else NestTheme.t("%d Misses Left")%misses,18))
	else:
		chips.add_child(NestTheme.pill(NestTheme.t("1 Tumble Left") if left == 1 else NestTheme.t("%d Tumbles Left")%left,18))
	var buttons: VBoxContainer = app._vbox(overlay,12)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buttons.offset_top = -app.safe_bottom
	buttons.offset_bottom = -app.safe_bottom
	_centre_column(buttons,340)
	var resume := NestTheme.button("Resume",func() -> void:
		app._close_modal()
		app.get_tree().paused = false
	,true,"plop")
	resume.custom_minimum_size.y = 80
	resume.add_theme_font_size_override("font_size",30)
	buttons.add_child(resume)
	# These abandon the active run. Only a game over reaches results and records completion.
	buttons.add_child(NestTheme.button("Restart",func() -> void:
		app._start()
	,false,"plop"))
	buttons.add_child(NestTheme.button("Main Menu",func() -> void:
		app._home()
	,false,"plop"))

## The sign's Kinu wears the player's outfit and takes the look of the given piece, if any.
static func _mascot(app: Node, body: KinuBody, mood: String) -> CenterContainer:
	var shape: KinuShape = app.run.catalog.shapes[0]
	var look: KinuFlavour = MyKinu.mascot_flavour(app.run.catalog)
	if is_instance_valid(body):
		shape = body.shape
		look = body.look
	var mascot := KinuPreview.new()
	mascot.setup(shape,look,true,Vector2i(200,130),mood,MyKinu.worn_outfit(app.run.catalog),false,false,MyKinu.worn_parts(app.run.catalog))
	mascot.fit_model(1.1,true)
	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mascot)
	return row

static func results(app: Node, stats: Dictionary) -> void:
	app.last_stats = stats
	var mode := str(stats.get("mode","classic"))
	var record = int(stats.score)>app.initial_best
	var rewards_before := KinuProgress.earned_keys()
	var claimable_before := KinuProgress.claimable()
	var modes_before := NestRun.MODES.filter(func(id: String) -> bool: return NestRun.mode_unlocked(id))
	Save.finish_run(stats)
	var rewards := KinuProgress.newly_earned(rewards_before)
	var missions_done := KinuProgress.claimable()-claimable_before
	var earned := NestRun.beans_for_run(stats, record)+int(stats.get("bonus", 0))
	var unlocked: Array[String] = []
	if mode == "classic":
		unlocked = NestRun.unlocks_between(app.run.catalog.flavours, app.initial_best, int(stats.score))
	var new_modes := NestRun.MODES.filter(func(id: String) -> bool: return NestRun.mode_unlocked(id) and not modes_before.has(id))
	Save.add_earned_beans(earned)
	app._new_screen("results")
	Sound.play("yay" if record else "gameover")
	if record:
		Haptics.pulse(50,.75)
	# Runs can unlock many things at once. Keep the result sign inside the space above the
	# fixed actions, and let players drag it to read every reward and the next goal.
	var scroll := DragScroll.new()
	scroll.name = "ResultsScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 70
	scroll.offset_bottom = -190
	app.content.add_child(scroll)
	var holder = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	# One premium card holds the whole result: a gold-sky card for a new best, sky for any other run.
	var card := FancyCard.new()
	card.name = "ResultsCard"
	card.custom_minimum_size.x = minf(410,app.get_viewport().get_visible_rect().size.x-28)
	card.ray_origin = Vector2(.5,.16)
	if record:
		card.top_color = Color("fff6d2")
		card.bottom_color = Color("ffd27a")
	holder.add_child(card)
	var column = app._vbox(card,8)
	# Kinu peeks out of a glow: worried after a tumble, delighted for a new best.
	var last: KinuBody = app.run.fallen_body
	if not is_instance_valid(last) and not app.run.bodies.is_empty():
		last = app.run.bodies.back()
	var mascot_halo := KinuHalo.new()
	mascot_halo.custom_minimum_size = Vector2(0,132)
	mascot_halo.glow = NestTheme.SUN.lightened(.4) if record else Color("ffffff")
	var mascot := _mascot(app,last,"happy" if record else "worried")
	mascot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mascot.offset_bottom = -12
	mascot_halo.add_child(mascot)
	column.add_child(mascot_halo)
	var ending: String = {"classic": "Tumble!", "tower": "Timber!", "toss": "Missed!"}[mode]
	# The headline earns its size: a new best shouts, and a strong run still gets told so.
	var praise := _praise(int(stats.score), int(app.initial_best), record)
	var banner_row := CenterContainer.new()
	banner_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := FancyCard.Banner.new()
	title.name = "ResultsTitle"
	title.text = NestTheme.t(praise if praise != "" else ending)
	title.color = Color("ffb62e") if record else NestTheme.BERRY
	title.font_size = 34
	banner_row.add_child(title)
	column.add_child(banner_row)
	var beat := 0.0
	_reveal(app,banner_row,beat,"highscore" if record else "")
	# The score: a label, then the big counted-up number.
	var tally := VBoxContainer.new()
	tally.add_theme_constant_override("separation",-6)
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tally)
	app._center_label(tally,NestTheme.t(_score_title(mode)).to_upper(),15,MyKinuScreen.SKY_TEXT)
	var big = NestTheme.headline(_score_text(app,mode,int(stats.score)),78,NestTheme.SUN)
	big.name = "ResultsScore"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_child(big)
	beat += .28
	# The score counts itself up rather than simply being there: the run is replayed as a number
	# climbing, which is the moment worth dwelling on.
	_count_up(app,big,int(stats.score),beat,func(value: int) -> String: return _score_text(app,mode,value))
	# How this run sits against the player's best. A near miss is the strongest reason to go again,
	# so it is shown as a bar with the gap named rather than left for the player to work out.
	if not record and int(app.initial_best) > 0:
		var chase: VBoxContainer = app._vbox(column,2)
		var target := int(app.initial_best)
		var bar := FancyCard.XpMeter.new()
		bar.show_levels = false
		bar.max_value = target
		bar.value = mini(int(stats.score),target)
		bar.custom_minimum_size.y = 20
		chase.add_child(bar)
		# Always name the target as well as the gap. maxi keeps the gap sane if the score ever ties
		# the best without counting as one.
		var short: int = maxi(1,target-int(stats.score)+1)
		var gap_text: String = NestTheme.t("%d more to beat your best of %s!")%[short,_score_text(app,mode,target)] if short <= _CLOSE_CALL else NestTheme.t("Your best: %s")%_score_text(app,mode,target)
		app._center_label(chase,gap_text,15,NestTheme.BERRY if short <= _CLOSE_CALL else MyKinuScreen.SKY_TEXT)
		beat += .22
		_reveal(app,chase,beat)
	# Stat tiles: what this run measured, and the beans it paid.
	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation",10)
	var tiles_row := MarginContainer.new()
	tiles_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left","margin_right"]:
		tiles_row.add_theme_constant_override(side,22)
	tiles_row.add_child(tiles)
	column.add_child(tiles_row)
	match mode:
		"tower":
			tiles.add_child(_stat_tile("Kinu",str(int(stats.get("pile",0))),"kinu"))
		"toss":
			tiles.add_child(_stat_tile("Kinu In",str(int(stats.get("pile",0))),"kinu"))
			if int(stats.get("distance",0)) > 0:
				tiles.add_child(_stat_tile("Longest",KinuFlavour.height_text(int(stats.get("distance",0))),"height"))
		_:
			tiles.add_child(_stat_tile("Height",KinuFlavour.height_text(NestRun.height_cm(float(stats.get("height",0.0)))),"height"))
	var bean_tile := _stat_tile("Beans","+%d"%earned,"beans")
	tiles.add_child(bean_tile)
	beat += .3
	_reveal(app,tiles_row,beat,"cashregister")
	# Beans tick up alongside the score, so the payout reads as something being counted out.
	var bean_value := bean_tile.find_child("Value",true,false) as Label
	if bean_value:
		_count_up(app,bean_value,earned,beat,func(value: int) -> String: return "+%d"%value)
	beat = _results_kinu_xp(app,column,beat)
	var news: Array[String] = []
	if not unlocked.is_empty():
		news.append(NestTheme.t("New My Kinu flavour: %s")%NestTheme.t_join(unlocked) if MyKinu.active() else NestTheme.t("New flavour: %s")%NestTheme.t_join(unlocked))
	if not rewards.is_empty():
		news.append(NestTheme.t("Earned: %s")%NestTheme.t_join(rewards))
	for id in new_modes:
		news.append(NestTheme.t("New mode: %s")%NestTheme.t(MODE_NAMES[id]))
	if missions_done > 0:
		news.append(NestTheme.t("Daily mission done!") if missions_done == 1 else NestTheme.t("%d daily missions done!")%missions_done)
	for line in news:
		var news_row := _reward_row(line)
		column.add_child(news_row)
		# Each piece of good news lands on its own beat, so three unlocks feel like three wins.
		beat += .26
		_reveal(app,news_row,beat,"special")
	# What the next run is for. Naming the very next flavour and how close it is turns "play again"
	# into a specific goal instead of a button.
	var next_up := _next_flavour(app,mode)
	if not next_up.is_empty():
		var goal_box: VBoxContainer = app._vbox(column,2)
		app._center_label(goal_box,NestTheme.t("Next: %s at %d Kinu")%[NestTheme.t(str(next_up.name)),int(next_up.at)],15,MyKinuScreen.SKY_TEXT)
		var goal_bar := FancyCard.XpMeter.new()
		goal_bar.show_levels = false
		goal_bar.fill_top = Color("e3d6ff")
		goal_bar.fill_bottom = Color("9b7bff")
		goal_bar.max_value = int(next_up.at)
		goal_bar.value = mini(int(Save.data.best),int(next_up.at))
		goal_bar.custom_minimum_size.y = 18
		goal_box.add_child(goal_bar)
		beat += .24
		_reveal(app,goal_box,beat)
	var buttons = app._vbox(app.content,12)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_top = -176
	_centre_column(buttons,360)
	var again := GachaButton.new()
	again.name = "Play Again"
	again.icon_kind = "again"
	again.centered = true
	again.title_size = 30
	again.title_text = NestTheme.t("Play Again")
	again.kinu_color = MyKinu.base(app.run.catalog).color
	again.top_color = Color("ffd75a")
	again.bottom_color = Color("f5a020")
	again.edge_color = Color("8a5310")
	again.custom_minimum_size.y = 84
	_gacha_press(again,"plop",func() -> void:
		Sound.play("homeplay")
		app._start())
	buttons.add_child(again)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	buttons.add_child(row)
	var menu := GachaButton.new()
	menu.name = "Main Menu"
	menu.icon_kind = "home"
	menu.title_text = NestTheme.t("Main Menu")
	menu.top_color = Color("7fc4f5")
	menu.bottom_color = Color("3f8fd8")
	menu.edge_color = Color("1f4f86")
	_gacha_press(menu,"plop",app._home)
	row.add_child(menu)
	# Straight from a finished run to the prize machine, with the beans still warm.
	var catcher := GachaButton.new()
	catcher.name = "ResultsCatcher"
	catcher.icon_kind = "claw"
	catcher.title_text = NestTheme.t("Kinu Claw")
	catcher.ribbon = NestTheme.t("FREE") if KinuCatcher.free_ready() else ""
	catcher.top_color = Color("ff86b4")
	catcher.bottom_color = Color("e2457f")
	catcher.edge_color = Color("8d2a55")
	_gacha_press(catcher,"cashregister",func() -> void: KinuCatcherScreen.show(app))
	row.add_child(catcher)
	for button in [menu,catcher]:
		button.custom_minimum_size.y = 70
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if record:
		app._confetti()

const MODE_NAMES := {"classic": "Classic", "tower": "Tower", "toss": "Toss"}
const MODE_BLURBS := {"classic": "Fill the box. Six tumbles and you're out.", "tower": "No box, just a plate. Build as tall as you can.", "toss": "Flick Kinu from the pan into the holes in the box. Six misses and you're out."}
## The line on the shop sign, so the home screen says what the Play button is about to start.
const MODE_TAGLINES := {"classic": "Pile in as many Kinu as you can!", "tower": "Stack them as high as you dare!", "toss": "Flick them into the box!"}
## Longer copy for the Modes sheet: how the mode actually plays, past the one-line blurb.
const MODE_DETAILS := {
	"classic": "Land Kinu in the tofu box. Anything that bounces out onto the counter is a tumble, and six tumbles end the run. You score the pile you keep.",
	"tower": "A narrow lacquer plate, no walls to catch a bad drop. Stack carefully: you score how tall it stands when it finally comes down.",
	"toss": "Slide the pan to line up, then flick up to throw. Kinu have to drop through a hole in the lid and stay in: smaller holes, longer throws and unbroken streaks score more. Each box takes a few Kinu before the next one arrives, further away or harder to hit. Six misses end the run."}
## What each mode is scored on, for the Modes sheet's best-so-far line.
const MODE_SCORE_LABELS := {"classic": "Best pile", "tower": "Tallest tower", "toss": "Best score"}

## A run within this many of the best is called out as a near miss rather than a plain score.
const _CLOSE_CALL := 5

## Headline for the run. A new best shouts; below that, a strong run is still told so, because a
## result screen that only ever says "Tumble!" teaches the player their run did not matter.
static func _praise(score: int, best: int, record: bool) -> String:
	if record:
		return "New Best!"
	if best <= 0 or score <= 0:
		return ""
	var share := float(score)/float(best)
	if score >= best:
		return "Matched Your Best!"
	if share >= .9:
		return "So Close!"
	if share >= .75:
		return "Great Run!"
	if share >= .5:
		return "Nice Pile!"
	return ""

## The next flavour waiting above the player's best, so the results screen can name what the next
## run is for. Only Classic unlocks flavours by pile, so the other modes get nothing.
static func _next_flavour(app: Node, mode: String) -> Dictionary:
	if mode != "classic":
		return {}
	var best := int(Save.data.best)
	var closest: KinuFlavour = null
	for flavour in app.run.catalog.flavours:
		if flavour.unlock_kinu > best and (closest == null or flavour.unlock_kinu < closest.unlock_kinu):
			closest = flavour
	return {} if closest == null else {"name": closest.display_name, "at": closest.unlock_kinu}

## Fades a finished element in on its own beat. Results elements are built complete and then
## revealed in order, so the screen reads as a sequence of small wins rather than a wall of numbers.
static func _reveal(app: Node, node: Control, delay: float, sound: String = "") -> void:
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_interval(maxf(delay,0.001))
	tween.tween_callback(func() -> void:
		if sound != "" and is_instance_valid(node):
			Sound.play(sound))
	tween.tween_property(node,"modulate:a",1.0,.22)

## Ticks a number up to its final value. The label is written through `text_for` so the same
## counter drives a plain score, a height in centimetres or a bean payout.
static func _count_up(app: Node, label: Label, to: int, delay: float, text_for: Callable) -> void:
	if to <= 0:
		return
	label.text = text_for.call(0)
	var tween := label.create_tween()
	tween.tween_interval(maxf(delay,0.001))
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(label):
			label.text = text_for.call(int(round(value)))
	,0.0,float(to),clampf(to*.015,.4,1.1)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Fill each level separately so the bar holds at full before the next level starts. The track and
## panel stay visible throughout; the level boundary is a beat rather than a one-frame reset.
static func _animate_kinu_xp(app: Node, bar: ProgressBar, level_label: Label, earned_label: Label, from_xp: int, to_xp: int, delay: float) -> float:
	var gained := maxi(0,to_xp-from_xp)
	var duration := clampf(float(gained)*.025,.6,1.6) if gained > 0 else .2
	var tween := bar.create_tween()
	tween.tween_interval(delay)
	var cursor := from_xp
	var elapsed := delay
	while cursor < to_xp:
		var level := MyKinu.level_for(cursor)
		var progress := MyKinu.progress_for(cursor)
		var boundary := cursor+progress[1]-progress[0]
		var target := mini(to_xp,boundary)
		var segment_time := maxf(.08,duration*float(target-cursor)/float(gained))
		var segment_start := cursor
		var segment_level := level
		var segment_target := target
		tween.tween_method(func(value: float) -> void:
			if not is_instance_valid(bar) or not is_instance_valid(earned_label):
				return
			var total := int(round(value))
			bar.max_value = MyKinu.xp_to_next(segment_level)
			bar.value = MyKinu.progress_for(segment_start)[0]+total-segment_start
			earned_label.text = NestTheme.t("+%d XP")%maxi(0,total-from_xp)
		, float(cursor),float(target),segment_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		elapsed += segment_time
		if target == boundary:
			tween.tween_interval(.28)
			elapsed += .28
			tween.tween_callback(func() -> void:
				if not is_instance_valid(bar) or not is_instance_valid(level_label):
					return
				var next_level := MyKinu.level_for(segment_target)
				bar.max_value = MyKinu.xp_to_next(next_level)
				bar.value = 0
				if bar is FancyCard.XpMeter:
					(bar as FancyCard.XpMeter).level = next_level
				level_label.text = NestTheme.t("Level %d")%next_level
				Sound.play("special")
				Haptics.pulse(40,.7))
		cursor = target
	return elapsed

static func _score_title(mode: String) -> String:
	return {"classic": "Kinu Piled", "tower": "Tower Height", "toss": "Score"}.get(mode, "Kinu Piled")

static func _score_text(app: Node, mode: String, score: int) -> String:
	return KinuFlavour.height_text(score) if mode == "tower" else app._number(score)

## Both set-ups stand on the counter at once, so choosing a mode pans the camera across to it
## rather than rebuilding the home screen. The chips restyle themselves in place for the same
## reason: a rebuild would pop the tableaux and throw away the camera move.
static func _mode_picker(app: Node, front: ShopFront = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	row.name = "ModePicker"
	for id in NestRun.MODES:
		var chip := _mode_plaque(MODE_NAMES[id], func() -> void:
			if not NestRun.mode_unlocked(id):
				locked_mode(app,id)
				return
			choose_mode(app,front,id)
		)
		chip.name = "Mode"+id.capitalize()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(chip)
	_paint_mode_row(row,NestRun.chosen_mode())
	if is_instance_valid(front):
		front.tagline = MODE_TAGLINES[NestRun.chosen_mode()]
	return row

## Selects a mode from anywhere on the home screen: remembers it, pans the camera across the
## counter to that set-up, retitles the sign and relights the chip.
static func choose_mode(app: Node, front: ShopFront, id: String) -> void:
	Save.setting("mode",id)
	app.run.focus_mode(id)
	if is_instance_valid(front):
		front.tagline = MODE_TAGLINES[id]
	var row: Node = app.content.find_child("ModePicker",true,false)
	if row is HBoxContainer:
		_paint_mode_row(row,id)
	var leaderboards: Node = app.content.find_child("Leaderboards",true,false)
	if leaderboards is Button:
		_update_leaderboard_button(leaderboards,id)

## The trophy is deliberately icon-only, but its hover/accessibility name follows the currently
## selected mode and its callback resolves that same mode when tapped.
static func _update_leaderboard_button(button: Button, mode: String) -> void:
	var mode_name := NestTheme.t(MODE_NAMES.get(mode,"Classic"))
	button.tooltip_text = "%s — %s"%[mode_name,NestTheme.t("Leaderboards")]
	button.accessibility_name = button.tooltip_text

static func _paint_mode_row(row: HBoxContainer, selected: String) -> void:
	for id in NestRun.MODES:
		var chip: Node = row.get_node_or_null("Mode"+id.capitalize())
		if chip is Button:
			_style_mode_plaque(chip,id == selected,NestRun.mode_unlocked(id))

## Why a mode is not selectable yet, and what unlocks it.
static func locked_mode(app: Node, id: String) -> void:
	var stack = app._modal(MODE_NAMES[id])
	app._paper_text(stack,NestTheme.t(MODE_BLURBS[id])+"\n\n"+NestTheme.t("Pile %d Kinu in Classic to unlock.")%int(NestRun.MODE_UNLOCK[id]),19)
	stack.add_child(NestTheme.button("Okay",app._close_modal,true))

## What each mode is, side by side, for a player deciding which to play. Choosing one here
## closes the sheet so the camera pan across the counter is actually visible.
static func modes(app: Node, front: ShopFront = null) -> void:
	var stack = app._modal("Modes")
	var current := NestRun.chosen_mode()
	for id in ["classic", "tower"]:
		var open := NestRun.mode_unlocked(id)
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation",10)
		var shot := _mode_shot(id)
		if shot:
			card.add_child(shot)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",5)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(column)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation",6)
		column.add_child(heading)
		var name_label := NestTheme.label(NestTheme.t(MODE_NAMES[id]),23)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(name_label)
		if not open:
			heading.add_child(NestTheme.pill(NestTheme.t("Locked"),13,NestTheme.MUTED))
		elif id == current:
			heading.add_child(NestTheme.pill(NestTheme.t("Playing"),13,Color("a5651f")))
		var body := NestTheme.label(NestTheme.t(MODE_DETAILS[id]),15)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(body)
		if open:
			var best := NestRun.best_for(id)
			var best_text: String = KinuFlavour.height_text(best) if id == "tower" else str(best)
			column.add_child(NestTheme.label("%s: %s"%[NestTheme.t(MODE_SCORE_LABELS[id]),best_text],14,NestTheme.MUTED))
		else:
			var need := NestTheme.label(NestTheme.t("Pile %d Kinu in Classic to unlock.")%int(NestRun.MODE_UNLOCK[id]),14,NestTheme.MUTED)
			need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(need)
		if open and id != current:
			var pick := NestTheme.button("Play This",func() -> void:
				choose_mode(app,front,id)
				app._close_modal()
			,true,"tap")
			pick.name = "Choose"+id.capitalize()
			pick.custom_minimum_size.y = 44
			pick.add_theme_font_size_override("font_size",16)
			column.add_child(pick)
		stack.add_child(NestTheme.paper(card))
	stack.add_child(NestTheme.button("Close",func() -> void:
		Sound.play("plop")
		app._close_modal()
	))

## The baked preview for a mode, if one has been rendered. Missing art is not worth failing the
## sheet over: the copy stands on its own, and the room behind shows the real thing. Rebuild these
## with tools/bake_mode_shots.tscn after changing the home tableaux.
static func _mode_shot(id: String) -> Control:
	var path := "res://resources/modes/%s.png"%id
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := NestTheme.box(NestTheme.INK,12,NestTheme.INK,3)
	style.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel",style)
	var shot := TextureRect.new()
	shot.texture = texture
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# The bake is already this shape, so nothing of the set-up is lost to the crop.
	shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	shot.custom_minimum_size = Vector2(102,136)
	shot.clip_contents = true
	frame.add_child(shot)
	return frame

## The released game modes are understated lacquer chips. They are intentionally flatter and
## finer-lined than the big in-world shop controls behind them.
static func _mode_plaque(title: String, callback: Callable, sound: String = "tap") -> Button:
	var button := NestTheme.button("", callback, false, sound)
	button.custom_minimum_size.y = 48
	button.focus_mode = Control.FOCUS_NONE
	var label := NestTheme.label(title, 19, NestTheme.INK)
	label.name = "Title"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(label)
	return button

## Paints a chip for its current state. The selected mode is the only lit surface in the row, so
## the pair reads as one segmented control rather than two competing buttons.
static func _style_mode_plaque(button: Button, selected: bool, unlocked: bool) -> void:
	var tone := Color("ffc14a") if selected else Color("6b4029")
	for state in ["normal", "hover", "pressed"]:
		var shade := tone.lightened(.06) if state == "hover" else tone.darkened(.08) if state == "pressed" else tone
		var style := _home_control_style(shade,16, state == "pressed" or not selected)
		if not selected:
			# Unselected chips sit flush in the tray; only the chosen one stands proud of it.
			style.shadow_size = 0
			style.border_color = Color("4a2a1b")
		button.add_theme_stylebox_override(state, style)
	var label := button.get_node_or_null("Title")
	if label is Label:
		label.add_theme_color_override("font_color", NestTheme.INK if selected else Color("e3c7ad"))
	button.modulate = Color(1,1,1,1) if unlocked else Color(.86,.82,.8,.85)

## Wires a GachaButton like NestTheme.button: a sound, and no press at the end of a scroll drag.
static func _gacha_press(button: Button, sound: String, callback: Callable) -> void:
	button.pressed.connect(func() -> void:
		if NestTheme.scroll_dragging:
			return
		Sound.play(sound)
		callback.call()
	)

## Home actions read as clean painted arcade controls: a single label, a fine outline, and no
## cartoon text outline fighting the already illustrated room behind them.
static func _home_action_button(title: String, tone: Color, callback: Callable, height: float, icon: String = "", primary: bool = false, sound: String = "tap") -> Button:
	var button := NestTheme.button("", callback, false, sound)
	if title != "":
		button.name = title
	button.custom_minimum_size.y = height
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var shade := tone.lightened(.07) if state == "hover" else tone.darkened(.08) if state == "pressed" else tone
		var style := _home_control_style(shade,22 if primary else 18, state == "pressed")
		button.add_theme_stylebox_override(state, style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(row)
	if icon != "":
		var art := MenuIcon.new()
		art.kind = icon
		# An icon with no label is the whole control, so it gets the room the label would have used.
		art.custom_minimum_size = Vector2(22, 22) if title != "" else Vector2(44, 44)
		row.add_child(art)
	# An empty label still takes part in the row's centring, pushing a lone icon off-centre.
	if title != "":
		var label := NestTheme.label(title, 30 if primary else 15 if title in ["My Kinu","Kinu Claw"] else 17, NestTheme.INK if primary else NestTheme.CREAM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(label)
	return button

## The tray the home controls sit on. Warm lacquer rather than the old near-black slab, which
## read as a hole cut in the counter; the lighter top edge gives it a lip to sit under.
static func _tray_style() -> StyleBoxFlat:
	var style := _home_control_style(Color("6e3a22"),26)
	style.bg_color = Color("6e3a22")
	style.border_color = Color("3d1f13")
	style.border_width_top = 3
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 11
	style.content_margin_bottom = 13
	style.shadow_color = Color("1b0c08",.4)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0,3)
	return style

## Extra weight for the prize counter: a thicker frame and a bigger label than the other
## secondary controls, so the gacha reads as the second thing on the screen after Play.
static func _dress_prize_button(button: Button) -> void:
	var radius := 18
	for state in ["normal", "hover", "pressed"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		if style == null:
			continue
		style.set_border_width_all(3)
		style.border_color = Color("8d2a55")
		style.shadow_size = 4
		style.shadow_color = Color("6d1339",.45)
		radius = style.corner_radius_top_left
	for row in button.get_children():
		if row is HBoxContainer:
			row.add_theme_constant_override("separation",10)
			for child in row.get_children():
				if child is Label:
					child.add_theme_font_size_override("font_size",21)
					child.add_theme_color_override("font_outline_color",Color("8d2a55"))
					child.add_theme_constant_override("outline_size",4)
				elif child is MenuIcon:
					# The claw is the draw here, so it is sized as artwork rather than as a
					# label's bullet: as tall as the button's inside allows.
					child.custom_minimum_size = Vector2(44,44)
	# Glass over the whole cabinet, under the claw and the label.
	var gloss := ButtonGloss.new()
	gloss.radius = radius
	button.add_child(gloss)
	button.move_child(gloss,0)

## A deliberately light home-only frame. NestTheme.box is the game\'s chunky comic frame;
## using it for the menu tray turned every control into a heavy black slab.
static func _home_control_style(fill: Color, radius: int, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("321b14")
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.anti_aliasing = true
	style.shadow_color = Color("1b0c08",.32)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0,1 if pressed else 2)
	return style

## Today's three missions, each earning beans.
static func daily_missions(app: Node) -> void:
	var stack = app._modal("Daily Missions")
	app.modal.set_meta("daily_missions", true)
	# The calendar is an upcoming reward, not a plain form button.
	var calendar := NestTheme.button("", func() -> void: DailyCalendar.show(app), false, "cashregister")
	calendar.custom_minimum_size.y = 142
	calendar.name = "DailyTreatStatus"
	var calendar_style := NestTheme.box(Color("5b3568"), 24, Color("ffd66d"), 7)
	calendar_style.content_margin_left = 12
	calendar_style.content_margin_right = 12
	calendar.add_theme_stylebox_override("normal", calendar_style)
	calendar.add_theme_stylebox_override("hover", NestTheme.box(Color("74427e"), 24, Color("fff0ad"), 7))
	calendar.add_theme_stylebox_override("pressed", NestTheme.box(Color("43274f"), 24, Color("ffd66d"), 3))
	var calendar_row := HBoxContainer.new()
	calendar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	calendar_row.add_theme_constant_override("separation", 8)
	calendar_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	calendar_row.offset_left = 20
	calendar_row.offset_right = -16
	calendar_row.offset_top = 8
	calendar_row.offset_bottom = -8
	calendar.add_child(calendar_row)
	var calendar_copy := VBoxContainer.new()
	calendar_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calendar_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	calendar_copy.add_theme_constant_override("separation", 5)
	calendar_row.add_child(calendar_copy)
	var treat_label := NestTheme.label("NEXT TREAT", 15, Color("ffe49b"))
	treat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	calendar_copy.add_child(treat_label)
	var countdown := NestTheme.label("", 32, NestTheme.CREAM)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calendar_copy.add_child(countdown)
	var encouragement := NestTheme.label("A little prize is waiting!", 15, Color("dfc9eb"))
	encouragement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	calendar_copy.add_child(encouragement)
	# The right-hand Kinu is a fresh costume pick each launch, then stays consistent in this session.
	var treat_kinu := KinuPreview.new()
	treat_kinu.setup(app.run.catalog.shapes[0], app.run.catalog.flavours[0], true, Vector2i(164, 126), "happy", _daily_treat_outfit(app), true)
	treat_kinu.fit_model(1.16, true)
	calendar_row.add_child(treat_kinu)
	var update_treat := func() -> void:
		countdown.text = "Claim it!" if DailyCalendar.ready() else DailyCalendar.countdown_clock()
		treat_label.text = "DAILY TREAT READY" if DailyCalendar.ready() else "NEXT TREAT"
		encouragement.text = "Tap to open your reward" if DailyCalendar.ready() else "Come back for your next treat"
	update_treat.call()
	var countdown_timer := Timer.new()
	countdown_timer.wait_time = 1.0
	countdown_timer.timeout.connect(update_treat)
	calendar.add_child(countdown_timer)
	countdown_timer.call_deferred("start")
	var gloss := ButtonGloss.new()
	gloss.radius = 18
	calendar.add_child(gloss)
	calendar.move_child(gloss, 0)
	stack.add_child(calendar)
	if GrandOpening.active() and not GrandOpening.complete():
		stack.add_child(_grand_opening_banner(app))
	if KinuShowcase.active():
		stack.add_child(_showcase_banner(app))
	var weekly := KinuProgress.weekly()
	var weekly_row := VBoxContainer.new()
	weekly_row.add_theme_constant_override("separation", 6)
	var weekly_top := HBoxContainer.new()
	weekly_row.add_child(weekly_top)
	var weekly_reset := NestTheme.label("", 15, NestTheme.MUTED)
	weekly_reset.name = "WeeklyResetTimer"
	var weekly_copy := VBoxContainer.new()
	weekly_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weekly_copy.add_theme_constant_override("separation", 2)
	weekly_top.add_child(weekly_copy)
	weekly_copy.add_child(NestTheme.label("WEEKLY CHALLENGE", 15, Color("9f562b")))
	weekly_copy.add_child(weekly_reset)
	var update_weekly := func() -> void:
		weekly_reset.text = NestTheme.t("Resets in %s") % KinuProgress.weekly_clock()
	update_weekly.call()
	var weekly_timer := Timer.new()
	weekly_timer.wait_time = 1.0
	weekly_timer.timeout.connect(update_weekly)
	weekly_reset.add_child(weekly_timer)
	weekly_timer.call_deferred("start")
	var weekly_label := NestTheme.label(KinuProgress.weekly_text(weekly), 19)
	weekly_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weekly_copy.add_child(weekly_label)
	var weekly_rewards := VBoxContainer.new()
	weekly_rewards.add_theme_constant_override("separation", 3)
	weekly_top.add_child(weekly_rewards)
	weekly_rewards.add_child(NestTheme.bean_pill("+%d"%KinuProgress.WEEKLY_BEANS, 16))
	weekly_rewards.add_child(NestTheme.ticket_pill("+%d"%KinuProgress.WEEKLY_TICKETS, 16))
	var weekly_bottom := HBoxContainer.new()
	weekly_row.add_child(weekly_bottom)
	var weekly_amount := int(weekly.amount)
	var weekly_progress := mini(int(weekly.progress), weekly_amount)
	var weekly_bar := NestTheme.progress(weekly_progress, weekly_amount)
	weekly_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weekly_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weekly_bottom.add_child(weekly_bar)
	if bool(weekly.claimed):
		_collected(weekly_bottom)
	elif KinuProgress.complete(weekly):
		var weekly_claim := NestTheme.button("Collect", func() -> void:
			if KinuProgress.claim_weekly():
				Sound.play("special")
				Haptics.pulse(35, .65)
			home(app)
			daily_missions(app)
		, true)
		weekly_claim.custom_minimum_size = Vector2(120, 50)
		weekly_claim.add_theme_font_size_override("font_size", 17)
		weekly_bottom.add_child(weekly_claim)
	else:
		var weekly_count := "%d / %d" % [weekly_progress, weekly_amount]
		if str(weekly.type) == "time":
			weekly_count = "%dm / %dm" % [floori(weekly_progress / 60.0), floori(weekly_amount / 60.0)]
		weekly_bottom.add_child(NestTheme.label(weekly_count, 16, NestTheme.MUTED))
	var weekly_paper := NestTheme.paper(weekly_row)
	stack.add_child(weekly_paper)
	if bool(weekly.claimed):
		_mark_done(weekly_paper, weekly_label)
	# Missions rotate at server UTC midnight, independently of the Treat's 24-hour cooldown.
	var reset_row := HBoxContainer.new()
	reset_row.name = "MissionResetTimer"
	reset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reset_row.add_theme_constant_override("separation", 8)
	reset_row.add_child(NestTheme.label("MISSIONS RESET IN", 15, Color("ffe49b")))
	var reset_clock := NestTheme.label(KinuProgress.daily_clock(), 22, NestTheme.CREAM)
	reset_row.add_child(reset_clock)
	var reset_timer := Timer.new()
	reset_timer.wait_time = 1.0
	reset_timer.timeout.connect(func() -> void: reset_clock.text = KinuProgress.daily_clock())
	reset_row.add_child(reset_timer)
	reset_timer.call_deferred("start")
	stack.add_child(reset_row)
	var missions := KinuProgress.today()
	for i in missions.size():
		var mission: Dictionary = missions[i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation",6)
		var top := HBoxContainer.new()
		row.add_child(top)
		var text := NestTheme.label(KinuProgress.mission_text(mission),18)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(text)
		var rewards := VBoxContainer.new()
		rewards.add_theme_constant_override("separation", 3)
		top.add_child(rewards)
		rewards.add_child(NestTheme.bean_pill("+%d"%int(mission.reward),16))
		var amount := int(mission.amount)
		var progress := mini(int(mission.progress),amount)
		var bottom := HBoxContainer.new()
		row.add_child(bottom)
		var bar := NestTheme.progress(progress,amount)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bottom.add_child(bar)
		if mission.claimed:
			_collected(bottom)
		elif KinuProgress.complete(mission):
			var claim := NestTheme.button("Collect",func() -> void:
				var beans := KinuProgress.claim(i)
				if beans > 0:
					Sound.play("special")
					Haptics.pulse(30,.5)
				home(app)
				daily_missions(app)
			,true)
			claim.custom_minimum_size = Vector2(120,50)
			claim.add_theme_font_size_override("font_size",17)
			bottom.add_child(claim)
		else:
			var count_text := "%s / %s"%[KinuFlavour.height_text(progress),KinuFlavour.height_text(amount)] if mission.type == "height" else "%d / %d"%[progress,amount]
			bottom.add_child(NestTheme.label(count_text,16,NestTheme.MUTED))
		var paper := NestTheme.paper(row)
		stack.add_child(paper)
		if mission.claimed:
			_mark_done(paper, text)
	stack.add_child(NestTheme.button("Close",func() -> void:
		Sound.play("plop")
		app._close_modal()
	))
	_fit_modal(app, stack)

## Collected missions sink back: the card dims and its line is struck through, so what's left to
## do stands out at a glance.
static func _mark_done(paper: Control, text: Label) -> void:
	paper.self_modulate = Color(.8, .76, .72)
	for child in paper.get_children():
		child.modulate = Color(.72, .68, .64)
	text.add_child(Strike.new())

static func _collected(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var seal := DailyTreats.Stamp.new()
	seal.custom_minimum_size = Vector2(28, 28)
	row.add_child(seal)
	row.add_child(NestTheme.label("Collected", 16, NestTheme.MUTED))
	parent.add_child(row)

## Daily Missions has grown past short phones' height: shrink the whole sign to fit rather than
## let its Close button fall off the bottom of the screen.
static func _fit_modal(app: Node, stack: Control) -> void:
	await app.get_tree().process_frame
	var sign := stack.get_parent() as Control
	if not is_instance_valid(sign):
		return
	var room: float = app.get_viewport().get_visible_rect().size.y-app.safe_top-maxf(16, app.safe_bottom)-24
	if sign.size.y > room:
		sign.pivot_offset = sign.size*.5
		sign.scale = Vector2.ONE*room/sign.size.y

## A slim ticket into the Grand Opening: the three launch exclusives in a row, and how many are in.
## It leaves the missions page once all three are collected, handing over to the Showcase below.
static func _grand_opening_banner(app: Node) -> Button:
	var banner := NestTheme.button("", func() -> void: GrandOpeningSheet.open(app), false, "cashregister")
	banner.name = "GrandOpeningBanner"
	banner.custom_minimum_size.y = 96
	banner.clip_contents = true
	banner.add_theme_stylebox_override("normal", NestTheme.box(GrandOpeningSheet.PANEL, 22, GrandOpeningSheet.GOLD, 7))
	banner.add_theme_stylebox_override("hover", NestTheme.box(GrandOpeningSheet.PANEL.lightened(.1), 22, GrandOpeningSheet.GOLD_BRIGHT, 7))
	banner.add_theme_stylebox_override("pressed", NestTheme.box(GrandOpeningSheet.DEEP, 22, GrandOpeningSheet.GOLD, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -10
	row.offset_top = 6
	row.offset_bottom = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var heading := NestTheme.label(NestTheme.t("GRAND OPENING"), 13, GrandOpeningSheet.GOLD_BRIGHT)
	heading.clip_text = true
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(heading)
	var name_label := NestTheme.headline(NestTheme.t("Launch exclusives"), 22)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(name_label)
	copy.add_child(NestTheme.label(NestTheme.t("%d / %d collected")%[GrandOpening.earned_count(), GrandOpening.rewards().size()]+" · "+GrandOpening.ends_text(), 13, GrandOpeningSheet.SOFT))
	# Each reward on its own cream tile, in full colour so it reads on the red; the ones already
	# collected are stamped rather than the others being faded.
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 4)
	tiles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tiles)
	for reward in GrandOpening.rewards():
		var tile := PanelContainer.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tile_style := NestTheme.box(NestTheme.CREAM, 12, GrandOpeningSheet.GOLD, 3)
		tile_style.set_content_margin_all(2)
		tile.add_theme_stylebox_override("panel", tile_style)
		tile.add_child(GrandOpeningSheet.thumb(reward.item, Vector2(40, 38)))
		if GrandOpening.earned(reward.key):
			var stamp := DailyTreats.Stamp.new()
			stamp.reach = 9.0
			tile.add_child(stamp)
		tiles.add_child(tile)
	var chevron := NestTheme.headline("›", 34, GrandOpeningSheet.GOLD_BRIGHT)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)
	var gloss := ButtonGloss.new()
	gloss.radius = 16
	banner.add_child(gloss)
	banner.move_child(gloss, 0)
	return banner

## A slim ticket into the Monthly Showcase: the reward, its name, and a pip per week.
static func _showcase_banner(app: Node) -> Button:
	var item := KinuShowcase.item_for(KinuShowcase.current_month())
	var kind := KinuShowcase.kind_of(item)
	var banner := NestTheme.button("", func() -> void: ShowcaseSheet.open(app), false, "cashregister")
	banner.name = "ShowcaseBanner"
	banner.custom_minimum_size.y = 96
	banner.add_theme_stylebox_override("normal", NestTheme.box(ShowcaseSheet.PANEL, 22, ShowcaseSheet.GOLD, 7))
	banner.add_theme_stylebox_override("hover", NestTheme.box(ShowcaseSheet.PANEL.lightened(.1), 22, ShowcaseSheet.GOLD_BRIGHT, 7))
	banner.add_theme_stylebox_override("pressed", NestTheme.box(ShowcaseSheet.DEEP, 22, ShowcaseSheet.GOLD, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -16
	row.offset_top = 6
	row.offset_bottom = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(row)
	var art: Control
	if kind == "room":
		art = DecorPreview.room_swatch(item, Vector2i(80, 70))
	else:
		var rect := TextureRect.new()
		rect.texture = CollectionThumb.outfit(item) if kind == "outfit" else CollectionThumb.box(item)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art = rect
	art.custom_minimum_size = Vector2(80, 70)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	copy.add_child(NestTheme.label(NestTheme.t("%s SHOWCASE")%KinuShowcase.month_only(KinuShowcase.current_month()).to_upper(), 14, ShowcaseSheet.GOLD))
	var name_label := NestTheme.headline(NestTheme.t(item.display_name), 22)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(name_label)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 5)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(pips)
	var now := KinuShowcase.current_week()
	for week in range(1, KinuShowcase.WEEKS+1):
		var pip := DailyTreats.Pip.new()
		pip.lit = KinuShowcase.week_done(week)
		pip.live = week == now and not pip.lit and not KinuShowcase.earned()
		if week < KinuShowcase.first_week():
			pip.modulate.a = .35
		pips.add_child(pip)
	var state := "Earned!" if KinuShowcase.earned() else ("Missed" if KinuShowcase.missed() else "%d / %d" % [KinuShowcase.progress(), KinuShowcase.required_weeks().size()])
	pips.add_child(NestTheme.label(state, 14, ShowcaseSheet.SOFT))
	var chevron := NestTheme.headline("›", 34, ShowcaseSheet.GOLD_BRIGHT)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)
	var gloss := ButtonGloss.new()
	gloss.radius = 16
	banner.add_child(gloss)
	banner.move_child(gloss, 0)
	return banner

static func _daily_treat_outfit(app: Node) -> KinuOutfit:
	if daily_treat_outfit_id.is_empty():
		var choices: Array[KinuOutfit] = []
		for outfit in app.run.catalog.outfits:
			# Keep pattern finishes out: this banner must always show a visibly dressed Kinu.
			if outfit.style in KinuModel.CUTE_STYLES or outfit.style in KinuModel.PREMIUM_STYLES or outfit.style in ["tanuki", "bunny", "bat", "fox", "frog", "pirate", "ninja", "panda", "dino", "astronaut", "ghost", "shark", "strawberry", "tiger", "dragon", "bee", "daruma", "tako", "kappa"]:
				choices.append(outfit)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		daily_treat_outfit_id = choices[rng.randi_range(0, choices.size()-1)].id
	return app.run.catalog.outfit(daily_treat_outfit_id)

class TreatCountdownIcon extends Control:
	var ready_to_claim := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size*.5
		var fill := NestTheme.SUN if ready_to_claim else Color("b77edf")
		draw_circle(c+Vector2(0, 2), size.x*.45, Color("2b1735"))
		draw_circle(c, size.x*.45, fill)
		draw_arc(c, size.x*.31, 0, TAU, 28, NestTheme.INK, 2.5, true)
		if ready_to_claim:
			draw_string(get_theme_default_font(), c+Vector2(-9, 8), "!", HORIZONTAL_ALIGNMENT_CENTER, 18, 22, NestTheme.INK)
		else:
			draw_line(c, c+Vector2(0, -size.y*.18), NestTheme.INK, 3.0, true)
			draw_line(c, c+Vector2(size.x*.14, size.y*.11), NestTheme.INK, 3.0, true)
			draw_circle(c, 3, NestTheme.INK)

## A strike-through across a label's text, following each wrapped line to its own length.
class Strike extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		get_parent().resized.connect(queue_redraw)
	func _draw() -> void:
		var host := get_parent() as Label
		if host == null or size.x <= 0.0:
			return
		var paragraph := TextParagraph.new()
		paragraph.width = size.x
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		paragraph.add_string(host.text, host.get_theme_font("font"), host.get_theme_font_size("font_size"))
		var y := 0.0
		var gap := float(host.get_theme_constant("line_spacing"))
		for line in paragraph.get_line_count():
			var height := paragraph.get_line_size(line).y
			var mid := y+height*.55
			draw_line(Vector2(-2, mid), Vector2(paragraph.get_line_width(line)+2, mid), Color(NestTheme.INK, .75), 2.5, true)
			y += height+gap

## Keeps a bottom button stack to a comfortable width, centred, instead of edge to edge.
static func _centre_column(column: Control, width: float) -> void:
	column.anchor_left = .5
	column.anchor_right = .5
	column.offset_left = -width*.5
	column.offset_right = width*.5
