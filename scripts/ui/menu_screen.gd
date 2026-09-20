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
	# Bento Flip was shelved rather than deleted. While the slot holds the packing mode it is
	# player-facing again; if PACKING_RUSH is turned off, anyone in it goes back to Classic.
	if str(Save.data.mode) == "rush" and not NestRun.PACKING_RUSH:
		Save.setting("mode", "classic")
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
	# Every claimable thing behind the Daily curtain gets one combined red badge, including the
	# attendance treat. Keeping it on the curtain means the top of Home can stay uncluttered.
	var daily_ready := KinuProgress.claimable() + (1 if KinuProgress.weekly_claimable() else 0) + (1 if DailyCalendar.ready() else 0)
	if daily_ready > 0:
		var daily_badge := NestTheme.count_badge(daily_ready)
		daily_badge.position = Vector2(15, -48)
		daily_curtain.add_child(daily_badge)
	_daily_countdown(daily_curtain)
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
	DailyCalendar.prompt(app)
	# Keep currency together at top-left; Settings occupies the matching top-right shortcut.
	var purse := VBoxContainer.new()
	purse.alignment = BoxContainer.ALIGNMENT_BEGIN
	purse.add_theme_constant_override("separation",6)
	purse.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# `content` already has the app-wide safety gutter, so do not add a second visual inset here.
	purse.offset_left = -14
	purse.offset_right = -14
	purse.offset_top = -14
	purse.offset_bottom = -14
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
	var settings := _icon_button(app.content, "Settings", "settings", app._settings, 64, false)
	settings.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings.get_parent().grow_horizontal = Control.GROW_DIRECTION_BEGIN
	settings.get_parent().offset_top = -24
	settings.get_parent().offset_bottom = -24

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

## A small status chip rides immediately above the calendar emblem. Because it belongs to the
## curtain's holder, it follows that panel's sway and opening animation exactly.
static func _daily_countdown(holder: Node2D) -> void:
	var chip := Panel.new()
	chip.name = "DailyCountdown"
	chip.position = Vector2(-45, -64)
	chip.size = Vector2(90, 28)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", NestTheme.box(NestTheme.BERRY, 16, NestTheme.INK, 3))
	holder.add_child(chip)
	var label := NestTheme.label("", 14, NestTheme.CREAM)
	label.name = "DailyCountdown"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", NestTheme.INK)
	label.add_theme_constant_override("outline_size", 2)
	chip.add_child(label)
	var update := func() -> void:
		label.text = "TREAT READY!" if DailyCalendar.ready() else DailyCalendar.countdown_text().trim_prefix("Next treat in ")
	update.call()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(update)
	holder.add_child(timer)
	timer.start()

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
	if mode == "rush":
		chips.add_child(NestTheme.pill(NestTheme.t("%ds left")%ceili(app.run.time_left),18))
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
	var ending: String = {"classic": "Tumble!", "tower": "Timber!", "rush": "Time's Up!" if not NestRun.PACKING_RUSH else "Out of Room!"}[mode]
	var title = NestTheme.headline("New Best!" if record else ending,58,NestTheme.SUN if record else NestTheme.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var ticket = PanelContainer.new()
	ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket.add_theme_stylebox_override("panel",SignBoard.paper())
	column.add_child(ticket)
	var tally = app._vbox(ticket,-8)
	app._center_label(tally,_score_title(mode),16,NestTheme.MUTED)
	var big = NestTheme.headline(_score_text(app,mode,int(stats.score)),76,NestTheme.SUN)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.add_child(big)
	var chips = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation",10)
	column.add_child(chips)
	match mode:
		"tower":
			chips.add_child(NestTheme.pill(NestTheme.t("%d Kinu")%int(stats.get("pile",0)),18))
		"rush":
			chips.add_child(NestTheme.pill(NestTheme.t("1 box shipped") if int(stats.get("boxes",0)) == 1 else NestTheme.t("%d boxes shipped")%int(stats.get("boxes",0)),18))
		_:
			chips.add_child(NestTheme.pill(NestTheme.t("%s Tall")%KinuFlavour.height_text(NestRun.height_cm(float(stats.get("height",0.0)))),18))
	chips.add_child(NestTheme.bean_pill(NestTheme.t("+%d beans")%earned,18))
	var news: Array[String] = []
	if not unlocked.is_empty():
		news.append(NestTheme.t("New flavour: %s")%NestTheme.t_join(unlocked))
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

const MODE_NAMES := {"classic": "Classic", "tower": "Tower", "rush": "Bento Pack"}
const MODE_BLURBS := {"classic": "Fill the box. Six tumbles and you're out.", "tower": "No box, just a plate. Build as tall as you can.", "rush": "Pack the box, close the lid, take the next one. Each box wants more under a lower lid."}
## The line on the shop sign, so the home screen says what the Play button is about to start.
const MODE_TAGLINES := {"classic": "Pile in as many Kinu as you can!", "tower": "Stack them as high as you dare!", "rush": "Pack every box before the lid runs out of room!"}
## Longer copy for the Modes sheet: how the mode actually plays, past the one-line blurb.
const MODE_DETAILS := {
	"classic": "Land Kinu in the tofu box. Anything that bounces out onto the counter is a tumble, and six tumbles end the run. You score the pile you keep.",
	"tower": "A narrow lacquer plate, no walls to catch a bad drop. Stack carefully: you score how tall it stands when it finally comes down.",
	"rush": "Fill the box, then close the lid and send it out. Nothing may stand above the lid line, and every box that leaves wants more Kinu under a lid that sits a little lower."}
## What each mode is scored on, for the Modes sheet's best-so-far line.
const MODE_SCORE_LABELS := {"classic": "Best pile", "tower": "Tallest tower", "rush": "Most packed"}

static func _score_title(mode: String) -> String:
	return {"classic": "Kinu Piled", "tower": "Tower Height", "rush": "Kinu Packed"}.get(mode, "Kinu Piled")

static func _score_text(app: Node, mode: String, score: int) -> String:
	return KinuFlavour.height_text(score) if mode == "tower" else app._number(score)

## Both set-ups stand on the counter at once, so choosing a mode pans the camera across to it
## rather than rebuilding the home screen. The chips restyle themselves in place for the same
## reason: a rebuild would pop the tableaux and throw away the camera move.
static func _mode_picker(app: Node, front: ShopFront = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	row.name = "ModePicker"
	for id in ["classic", "tower", "rush"] if NestRun.PACKING_RUSH else ["classic", "tower"]:
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
	for id in ["classic", "tower"]:
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
		countdown.text = "Claim it!" if DailyCalendar.ready() else DailyCalendar.countdown_text().trim_prefix("Next treat in ")
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
	var weekly := KinuProgress.weekly()
	var weekly_row := VBoxContainer.new()
	weekly_row.add_theme_constant_override("separation", 6)
	var weekly_top := HBoxContainer.new()
	weekly_row.add_child(weekly_top)
	var weekly_copy := VBoxContainer.new()
	weekly_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weekly_copy.add_theme_constant_override("separation", 2)
	weekly_top.add_child(weekly_copy)
	weekly_copy.add_child(NestTheme.label("WEEKLY CHALLENGE", 15, Color("9f562b")))
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
		weekly_bottom.add_child(NestTheme.label("Collected", 16, NestTheme.MUTED))
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
	stack.add_child(NestTheme.paper(weekly_row))
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
	stack.add_child(NestTheme.button("Close",func() -> void:
		Sound.play("plop")
		app._close_modal()
	))

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

## Keeps a bottom button stack to a comfortable width, centred, instead of edge to edge.
static func _centre_column(column: Control, width: float) -> void:
	column.anchor_left = .5
	column.anchor_right = .5
	column.offset_left = -width*.5
	column.offset_right = width*.5
