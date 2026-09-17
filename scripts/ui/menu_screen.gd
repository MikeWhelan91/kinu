class_name NestMenuScreen
extends RefCounted

## The touch target follows the cloth outline, including its slanted sides.
class CurtainButton extends Button:
	var hit_polygon := PackedVector2Array()

	func _has_point(point: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(point,hit_polygon)

static func home(app: Node) -> void:
	app.get_tree().paused = false
	app.run.show_menu()
	app._new_screen("home")
	var front := ShopFront.new()
	front.top_margin = app.safe_top
	front.decor = app.run.room.decor
	app.screen.add_child(front)
	app.screen.move_child(front,1)
	var play = NestTheme.button("Play",func() -> void:
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
		_curtain_button(exit,"Settings","settings",Callable(),3)
	,true)
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
	_curtain_button(front,"Settings","settings",app._settings,3)
	# Play is the only bottom action and gets the strongest visual weight.
	var play_row := CenterContainer.new()
	play_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	play_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	play_row.offset_bottom = -maxf(18,app.safe_bottom)
	app.content.add_child(play_row)
	var play_stack := VBoxContainer.new()
	play_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	play_stack.add_theme_constant_override("separation",10)
	play_row.add_child(play_stack)
	play.custom_minimum_size = Vector2(clampf(app.get_viewport().get_visible_rect().size.x*.5,190,270),84)
	play.add_theme_font_size_override("font_size",32)
	play_stack.add_child(play)
	var leaderboards := NestTheme.button("Leaderboards",func() -> void:
		app._leaderboards()
	,false)
	leaderboards.custom_minimum_size.x = play.custom_minimum_size.x
	play_stack.add_child(leaderboards)
	# Daily missions are useful from the first run onward; hiding the shortcut made the whole
	# system look absent until a second completed run.
	var daily := _icon_button(app.content,"Daily","daily",func() -> void: daily_missions(app),64,false)
	daily.pressed.connect(func() -> void: Sound.play("book"))
	daily.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# Centre the Daily button on the bean wallet so both top shortcuts sit level.
	daily.get_parent().offset_top = -24
	daily.get_parent().offset_bottom = -24
	var ready_count := KinuProgress.claimable()
	if ready_count > 0:
		var badge := NestTheme.count_badge(ready_count)
		badge.position = Vector2(46,-8)
		daily.add_child(badge)
	# Currency lives in the top-right corner, like a proper wallet.
	var wallet := BeanShop.WalletButton.new()
	wallet.pressed.connect(func() -> void: app._bean_shop())
	wallet.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	wallet.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	wallet.offset_top = -14
	app.content.add_child(wallet)

## A labelled icon centred over one of the four decorative medallions woven into the noren.
static func _curtain_button(front: ShopFront, title: String, icon: String, callback: Callable, index: int, sound: String = "plop") -> void:
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
	app._center_label(tally,"Kinu Piled",16,NestTheme.MUTED)
	var count := NestTheme.headline(app._number(app.run.score),76,NestTheme.SUN)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_child(count)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation",10)
	column.add_child(chips)
	chips.add_child(NestTheme.pill(NestTheme.t("%s Tall")%KinuFlavour.height_text(NestRun.height_cm(app.run.tower_height)),18))
	var left: int = NestRun.MAX_TUMBLES-app.run.tumbles
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
	buttons.add_child(NestTheme.button("Restart",func() -> void:
		Save.finish_run(app.run.summary())
		app._start()
	,false,"plop"))
	buttons.add_child(NestTheme.button("Main Menu",func() -> void:
		Save.finish_run(app.run.summary())
		app._home()
	,false,"plop"))

## The sign's Kinu wears the player's outfit and takes the look of the given piece, if any.
static func _mascot(app: Node, body: KinuBody, mood: String) -> CenterContainer:
	var shape: KinuShape = app.run.catalog.shapes[0]
	var look: KinuFlavour = app.run.catalog.pattern(str(Save.data.outfit))
	if not look:
		look = app.run.catalog.flavours[0]
	if is_instance_valid(body):
		shape = body.shape
		look = body.look
	var mascot := KinuPreview.new()
	mascot.setup(shape,look,true,Vector2i(200,130),mood,app.run.catalog.outfit(str(Save.data.outfit)))
	mascot.fit_model(1.1,true)
	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mascot)
	return row

static func results(app: Node, stats: Dictionary) -> void:
	app.last_stats = stats
	var record = int(stats.score)>app.initial_best
	var rewards_before := KinuProgress.earned_keys()
	var claimable_before := KinuProgress.claimable()
	Save.finish_run(stats)
	var rewards := KinuProgress.newly_earned(rewards_before)
	var missions_done := KinuProgress.claimable()-claimable_before
	var earned := NestRun.beans_for(int(stats.score), record)+int(stats.get("bonus", 0))
	var unlocked := NestRun.unlocks_between(app.run.catalog.flavours, app.initial_best, int(stats.score))
	Save.add_earned_beans(earned)
	app._new_screen("results")
	Sound.play("highscore" if record else "gameover")
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
	var last: KinuBody = app.run.fallen_body
	if not is_instance_valid(last) and not app.run.bodies.is_empty():
		last = app.run.bodies.back()
	column.add_child(_mascot(app,last,"happy" if record else "worried"))
	var title = NestTheme.headline("New Best!" if record else "Tumble!",58,NestTheme.SUN if record else NestTheme.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var ticket = PanelContainer.new()
	ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket.add_theme_stylebox_override("panel",SignBoard.paper())
	column.add_child(ticket)
	var tally = app._vbox(ticket,-8)
	app._center_label(tally,"Kinu Piled",16,NestTheme.MUTED)
	var big = NestTheme.headline(app._number(stats.score),76,NestTheme.SUN)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_child(big)
	var chips = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation",10)
	column.add_child(chips)
	chips.add_child(NestTheme.pill(NestTheme.t("%s Tall")%KinuFlavour.height_text(NestRun.height_cm(float(stats.get("height",0.0)))),18))
	chips.add_child(NestTheme.bean_pill(NestTheme.t("+%d beans")%earned,18))
	var news: Array[String] = []
	if not unlocked.is_empty():
		news.append(NestTheme.t("New flavour: %s")%NestTheme.t_join(unlocked))
	if not rewards.is_empty():
		news.append(NestTheme.t("Earned: %s")%NestTheme.t_join(rewards))
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
	buttons.add_child(NestTheme.button("Main Menu",app._home,false,"plop"))
	if record:
		app._confetti()

## Today's three missions, each with progress and a bean reward to collect.
static func daily_missions(app: Node) -> void:
	var stack = app._modal("Daily Missions")
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
		top.add_child(NestTheme.bean_pill("+%d"%int(mission.reward),16))
		var amount := int(mission.amount)
		var progress := mini(int(mission.progress),amount)
		var bottom := HBoxContainer.new()
		row.add_child(bottom)
		var bar := NestTheme.progress(progress,amount)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bottom.add_child(bar)
		if mission.claimed:
			bottom.add_child(NestTheme.label("Collected",16,NestTheme.MUTED))
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
		stack.add_child(NestTheme.paper(row))
	var note := NestTheme.label("New missions arrive every day.",15,NestTheme.CREAM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_outline_color",NestTheme.INK)
	note.add_theme_constant_override("outline_size",5)
	stack.add_child(note)
	stack.add_child(NestTheme.button("Close",func() -> void:
		Sound.play("plop")
		app._close_modal()
	))

## Keeps a bottom button stack to a comfortable width, centred, instead of edge to edge.
static func _centre_column(column: Control, width: float) -> void:
	column.anchor_left = .5
	column.anchor_right = .5
	column.offset_left = -width*.5
	column.offset_right = width*.5
