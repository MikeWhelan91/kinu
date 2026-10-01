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
	var play = _home_action_button("Play", NestTheme.SUN, func() -> void:
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
	,82,"",true)
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
	# The claw machine is the game's prize counter, so it gets a near-full-width button of its
	# own instead of sharing a cramped row; leaderboards drop to an icon beside it.
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation",8)
	play_stack.add_child(secondary)
	var catcher := _home_action_button("Kinu Claw", Color("ef5e97"), func() -> void:
		KinuCatcherScreen.show(app)
	,68,"claw",false,"cashregister")
	catcher.name = "Catcher"
	catcher.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dress_prize_button(catcher)
	secondary.add_child(catcher)
	var leaderboards := _home_action_button("", Color("4b5da8"), func() -> void:
		app._leaderboards()
	,68,"leaderboards")
	leaderboards.name = "Leaderboards"
	leaderboards.custom_minimum_size.x = 68
	_update_leaderboard_button(leaderboards,NestRun.chosen_mode())
	secondary.add_child(leaderboards)
	# The event rail stands on the left edge halfway between the curtains' hems and the tray, where
	# live games keep their event buttons: clear of both, and in easy reach.
	var rail := EventRail.build(app)
	rail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	rail.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rail.offset_left = -14
	app.content.add_child(rail)
	_seat_rail(rail,front,console)
	GrandOpening.prompt(app)
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
	var settings := _icon_button(app.content, "Settings", "settings", app._settings, 64, false)
	settings.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings.get_parent().grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var settings_lift := 0.0 if app.banner_showing() else -24.0
	settings.get_parent().offset_top = settings_lift
	settings.get_parent().offset_bottom = settings_lift

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
	var sign = SignBoard.new()
	sign.custom_minimum_size.x = 400
	holder.add_child(sign)
	var column = app._vbox(sign,6)
	# Kinu peeks over the top of the sign: worried after a tumble, delighted for a new best.
	var last: KinuBody = app.run.fallen_body
	if not is_instance_valid(last) and not app.run.bodies.is_empty():
		last = app.run.bodies.back()
	column.add_child(_mascot(app,last,"happy" if record else "worried"))
	var ending: String = {"classic": "Tumble!", "tower": "Timber!", "toss": "Missed!"}[mode]
	# The headline earns its size: a new best shouts, and a strong run still gets told so.
	var praise := _praise(int(stats.score), int(app.initial_best), record)
	var title = NestTheme.headline(praise if praise != "" else ending,58,NestTheme.SUN if record else NestTheme.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var beat := 0.0
	_reveal(app,title,beat,"highscore" if record else "")
	var ticket = PanelContainer.new()
	ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket.add_theme_stylebox_override("panel",SignBoard.paper())
	column.add_child(ticket)
	var tally = app._vbox(ticket,-8)
	app._center_label(tally,_score_title(mode),16,NestTheme.MUTED)
	var big = NestTheme.headline(_score_text(app,mode,int(stats.score)),76,NestTheme.SUN)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_child(big)
	beat += .28
	# The score counts itself up rather than simply being there: the run is replayed as a number
	# climbing, which is the moment worth dwelling on.
	_count_up(app,big,int(stats.score),beat,func(value: int) -> String: return _score_text(app,mode,value))
	# How this run sits against the player's best. A near miss is the strongest reason to go again,
	# so it is shown as a bar with the gap named rather than left for the player to work out.
	if not record and int(app.initial_best) > 0:
		var chase: VBoxContainer = app._vbox(tally,2)
		var target := int(app.initial_best)
		var bar := NestTheme.progress(mini(int(stats.score),target),target)
		chase.add_child(bar)
		# Always name the target as well as the gap. Showing only "4 more" leaves the player to
		# infer the number, and if their memory of it differs the screen looks like it moved the
		# goalposts. maxi keeps the gap sane if the score ever ties the best without counting as one.
		var short: int = maxi(1,target-int(stats.score)+1)
		var gap_text: String = NestTheme.t("%d more to beat your best of %s!")%[short,_score_text(app,mode,target)] if short <= _CLOSE_CALL else NestTheme.t("Your best: %s")%_score_text(app,mode,target)
		app._center_label(chase,gap_text,15,NestTheme.SUN if short <= _CLOSE_CALL else NestTheme.MUTED)
		beat += .22
		_reveal(app,chase,beat)
	var chips = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation",10)
	column.add_child(chips)
	match mode:
		"tower":
			chips.add_child(NestTheme.pill(NestTheme.t("%d Kinu")%int(stats.get("pile",0)),18))
		"toss":
			chips.add_child(NestTheme.pill(NestTheme.t("%d Kinu in")%int(stats.get("pile",0)),18))
			if int(stats.get("distance",0)) > 0:
				chips.add_child(NestTheme.pill(NestTheme.t("Longest %s")%KinuFlavour.height_text(int(stats.get("distance",0))),18))
		_:
			chips.add_child(NestTheme.pill(NestTheme.t("%s Tall")%KinuFlavour.height_text(NestRun.height_cm(float(stats.get("height",0.0)))),18))
	var bean_pill := NestTheme.bean_pill(NestTheme.t("+%d beans")%earned,18)
	chips.add_child(bean_pill)
	beat += .3
	_reveal(app,chips,beat,"cashregister")
	# Beans tick up alongside the score, so the payout reads as something being counted out.
	var bean_label := bean_pill.find_children("*","Label",true,false)
	if not bean_label.is_empty():
		_count_up(app,bean_label[0],earned,beat,func(value: int) -> String: return NestTheme.t("+%d beans")%value)
	# My Kinu's XP from this run, then what any new level brought.
	var growth: Dictionary = stats.get("my_kinu", {})
	if not growth.is_empty():
		var xp_box: VBoxContainer = app._vbox(column,2)
		xp_box.name = "MyKinuXP"
		var after := int(growth.level_after)
		var progress := MyKinu.progress_for(MyKinu.xp())
		app._center_label(xp_box,NestTheme.t("My Kinu +%d XP · Level %d")%[int(growth.xp),after],15,NestTheme.MUTED)
		xp_box.add_child(NestTheme.progress(progress[0],progress[1]))
		beat += .24
		_reveal(app,xp_box,beat)
	var news: Array[String] = []
	if not growth.is_empty() and int(growth.level_after) > int(growth.level_before):
		news.append(NestTheme.t("My Kinu reached level %d!")%int(growth.level_after))
		var gifts: Dictionary = growth.rewards
		for slot in gifts.slots:
			news.append(NestTheme.t("New slot: %s")%NestTheme.t(MyKinu.SLOT_NAMES[slot]))
		var names: Array[String] = []
		for part in gifts.parts:
			names.append(part.display_name)
		if not names.is_empty():
			news.append(NestTheme.t("New part: %s")%NestTheme.t_join(names))
		if int(gifts.tickets) > 0:
			news.append(NestTheme.t("+%d Catcher tickets")%int(gifts.tickets))
		if int(gifts.beans) > 0:
			news.append(NestTheme.t("+%d level-up beans")%int(gifts.beans))
	# My Kinu is introduced once, on the results of the first run that has it.
	if not bool(Save.data.my_kinu.intro_seen):
		Save.data.my_kinu.intro_seen = true
		Save.persist()
		news.append(NestTheme.t("Meet My Kinu! Dress it up in the Wardrobe."))
	if not unlocked.is_empty():
		news.append(NestTheme.t("New My Kinu flavour: %s")%NestTheme.t_join(unlocked) if MyKinu.active() else NestTheme.t("New flavour: %s")%NestTheme.t_join(unlocked))
	if not rewards.is_empty():
		news.append(NestTheme.t("Earned: %s")%NestTheme.t_join(rewards))
	for id in new_modes:
		news.append(NestTheme.t("New mode: %s")%NestTheme.t(MODE_NAMES[id]))
	if missions_done > 0:
		news.append(NestTheme.t("Daily mission done!") if missions_done == 1 else NestTheme.t("%d daily missions done!")%missions_done)
	for line in news:
		var news_row := CenterContainer.new()
		news_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pill := NestTheme.pill(line,17,Color("7a4fd0"))
		if line.length() > 30:
			var text: Label = pill.get_child(0)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.custom_minimum_size.x = 320
		news_row.add_child(pill)
		column.add_child(news_row)
		# Each piece of good news lands on its own beat, so three unlocks feel like three wins.
		beat += .26
		_reveal(app,news_row,beat,"special")
	# What the next run is for. Naming the very next flavour and how close it is turns "play again"
	# into a specific goal instead of a button.
	var next_up := _next_flavour(app,mode)
	if not next_up.is_empty():
		var goal_box: VBoxContainer = app._vbox(column,2)
		app._center_label(goal_box,NestTheme.t("Next: %s at %d Kinu")%[NestTheme.t(str(next_up.name)),int(next_up.at)],15,NestTheme.MUTED)
		goal_box.add_child(NestTheme.progress(mini(int(Save.data.best),int(next_up.at)),int(next_up.at)))
		beat += .24
		_reveal(app,goal_box,beat)
	var buttons = app._vbox(app.content,12)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_top = -170
	_centre_column(buttons,340)
	var again = NestTheme.button("Play Again",func() -> void:
		Sound.play("homeplay")
		app._start(),true,"plop")
	again.custom_minimum_size.y = 80
	again.add_theme_font_size_override("font_size",30)
	buttons.add_child(again)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	buttons.add_child(row)
	var menu := NestTheme.button("Main Menu",app._home,false,"plop")
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_font_size_override("font_size",20)
	row.add_child(menu)
	# Straight from a finished run to the prize machine, with the beans still warm.
	var catcher := NestTheme.button("Kinu Claw",func() -> void: KinuCatcherScreen.show(app),false,"cashregister")
	catcher.name = "ResultsCatcher"
	catcher.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catcher.add_theme_font_size_override("font_size",17)
	for state in ["normal","hover","pressed"]:
		catcher.add_theme_stylebox_override(state,NestTheme.box(Color("ff8fb1").lightened(.1 if state == "hover" else 0.0),26,NestTheme.INK,4 if state == "pressed" else 8))
	row.add_child(catcher)
	if KinuCatcher.free_ready():
		var free := NestTheme.count_badge(0)
		(free.get_child(0) as Label).text = NestTheme.t("FREE")
		free.position = Vector2(8,-12)
		catcher.add_child(free)
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
	var tween := app.create_tween()
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
	var tween := app.create_tween()
	tween.tween_interval(maxf(delay,0.001))
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(label):
			label.text = text_for.call(int(round(value)))
	,0.0,float(to),clampf(to*.015,.4,1.1)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
		var label := NestTheme.label(title, 30 if primary else 17, NestTheme.INK if primary else NestTheme.CREAM)
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
