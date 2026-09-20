extends Node
var run: NestRun
var canvas: CanvasLayer
var screen: Control
var content: Control
var modal: Control
var toast: Label
var toast_panel: PanelContainer
var toast_tween: Tween
## Stars in the air right now, with the tweens carrying them down, so a burst can be cleared the
## instant the page changes instead of raining over whatever comes next.
var confetti_stars: Array[Control] = []
var confetti_tweens: Array[Tween] = []
var page: String = ""
var score_label: Label
var height_label: Label
var best_label: Label
var tumble_meter: TumbleMeter
## Lid prototype: offers to close and send out the box once it holds enough.
var ship_button: Button
var bottle_button: Button
var score_title: Label
var timer_pill: PanelContainer
var box_pill: PanelContainer
var drop_button: Button
var hint_pill: PanelContainer
var next_slot: VBoxContainer
var tutorial_panel: TutorialCoach
var tutorial_step: int = -1
var initial_best: int = 0
var flavour_filter: String = "All"
var collection_filter: String = "All"
var shop_tab: String = "outfit"
var wardrobe_tab: String = "outfit"
var book_tab: String = "flavours"
var last_stats: Dictionary = {}
var safe_top: float = 26
var safe_bottom: float = 20
var device_safe_top: float = 26
var device_safe_bottom: float = 20
var bean_shop_back: Callable
var shop_back: Callable
var wardrobe_back: Callable
var game_center: GameCenterService
var admob: Admob
var deaths_since_interstitial := 0
const ADMOB_APP_ID := "ca-app-pub-1257499604453174~7129218341"
const ADMOB_BANNER_ID := "ca-app-pub-1257499604453174/5408942564"
const ADMOB_INTERSTITIAL_ID := "ca-app-pub-1257499604453174/5516306663"
## Google's test ad units in debug builds, the real units in release builds.
var admob_is_real := not OS.is_debug_build()
# Native banners are outside Godot's canvas. Reserve their space explicitly so they
# never sit over the daily/wallet buttons. This conservative value is replaced with
# the plugin's measured pixel height as soon as it loads.
var banner_inset := 64.0
var _banner_visible := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	apply_language()
	Sound.start_music()
	run = NestRun.new()
	add_child(run)
	run.updated.connect(_hud_update)
	run.message.connect(_toast)
	run.finished.connect(_results)
	run.action_done.connect(_tutorial_action)
	game_center = GameCenterService.new()
	game_center.authenticate()
	Store.changed.connect(_store_changed)
	setup_admob()
	canvas = CanvasLayer.new()
	add_child(canvas)
	get_viewport().size_changed.connect(_resized)
	_home()
	Store.notice.connect(func(message: String) -> void: _toast(message, NestTheme.SUN))
	if Rewards.configured():
		_refresh_reward_time()

func _refresh_reward_time() -> void:
	var status: Dictionary = await Rewards.time_status()
	KinuProgress.apply_time_status(status)
	KinuCatcher.apply_time_status(status)

## "" follows the phone's language; otherwise the player's choice in Settings.
func apply_language() -> void:
	var chosen: String = Save.data.language
	if chosen == "":
		var locale := OS.get_locale().replace("-", "_")
		chosen = "zh_TW" if locale.begins_with("zh_TW") or locale.begins_with("zh_HK") or locale.begins_with("zh_Hant") else "ko" if locale.begins_with("ko") else OS.get_locale_language()
	TranslationServer.set_locale(chosen)
	# Han characters exist in the Japanese, Chinese and Korean fonts with different regional
	# shapes, so the current language's font is tried first.
	var japanese: Font = load("res://assets/fonts/MPLUSRounded1c-Bold.ttf")
	var chinese: Font = load("res://assets/fonts/jf-openhuninn-zh_TW.ttf")
	var korean: Font = load("res://assets/fonts/NotoSansCJKkr-ko.otf")
	match chosen:
		"zh_TW":
			NestTheme.font.fallbacks = [chinese, japanese, korean]
		"ko":
			NestTheme.font.fallbacks = [korean, japanese, chinese]
		_:
			NestTheme.font.fallbacks = [japanese, chinese, korean]

func _resized() -> void:
	_update_safe_area()
	if is_instance_valid(content):
		content.offset_top = safe_top
		content.offset_bottom = -safe_bottom

func _update_safe_area() -> void:
	device_safe_top = 26
	device_safe_bottom = 20
	if OS.has_feature("ios") or OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var window := DisplayServer.window_get_size()
		var viewport := get_viewport().get_visible_rect().size
		if window.y>0 and safe.size.y>0:
			var scale_factor := viewport.y/window.y
			device_safe_top = maxf(16,safe.position.y*scale_factor+8)
			device_safe_bottom = maxf(16,(window.y-safe.end.y)*scale_factor+8)
	safe_bottom = device_safe_bottom
	run.bottom_inset = safe_bottom
	_sync_banner()

## The banner only runs on non-gameplay screens, never over the box itself.
func _banner_wanted() -> bool:
	return is_instance_valid(admob) and page != "play" and page != "pause"

func _sync_banner() -> void:
	var want := is_instance_valid(admob) and _banner_wanted() and admob.is_banner_ad_loaded()
	safe_top = device_safe_top + (banner_inset if want else 0.0)
	if not is_instance_valid(admob) or want == _banner_visible:
		return
	# Showing an already-shown banner can re-trigger its size measurement, which
	# would loop straight back into this function via refresh_banner_inset().
	_banner_visible = want
	if want:
		admob.show_banner_ad()
	else:
		admob.hide_banner_ad()

func _new_screen(name_: String, paper: bool = false) -> void:
	if page == "collection" and name_ != "collection":
		Save.clear_all_fresh()
	# A celebration belongs to the page that earned it, not to the one being opened.
	_clear_confetti()
	page = name_
	# A screen swap mid-drag can free the DragScroll before its deferred release clears this,
	# leaving every button silently ignoring taps until the app restarts.
	NestTheme.scroll_dragging = false
	if is_instance_valid(screen):
		canvas.remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.theme = NestTheme.theme()
	canvas.add_child(screen)
	var decoration := GardenOverlay.new()
	decoration.paper = paper
	decoration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(decoration)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 26
	content.offset_right = -26
	screen.add_child(content)
	_resized()
	toast_panel = NestTheme.pill("",28)
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# Messages sit low, above the controls, where they don't cover the tower.
	toast_panel.anchor_top = .72
	toast_panel.anchor_bottom = .72
	toast_panel.modulate.a = 0
	content.add_child(toast_panel)
	toast = toast_panel.get_child(0)
	modal = null
	tutorial_panel = null
	run.accepting_input = name_ == "play"

func _vbox(parent: Node, separation: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",separation)
	parent.add_child(box)
	return box

func _center_label(parent: Node, text: String, font_size: int, color: Color = NestTheme.INK) -> Label:
	var label := NestTheme.label(text,font_size,color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _home() -> void:
	if not run.decor_outdated():
		NestMenuScreen.home(self)
		return
	# A new box or room takes a moment to build: cover it with a curtain rendered first.
	var curtain := LoadingCurtain.new()
	canvas.add_child(curtain)
	await get_tree().process_frame
	await get_tree().process_frame
	NestMenuScreen.home(self)
	canvas.move_child(curtain, -1)
	curtain.finish()

func _start() -> void:
	get_tree().paused = false
	initial_best = NestRun.best_for(NestRun.chosen_mode())
	_new_screen("play")
	_build_hud()
	tutorial_step = -1 if Save.data.tutorial or NestRun.chosen_mode() != "classic" else 0
	run.begin()
	if tutorial_step == 0:
		_build_tutorial()

func _build_hud() -> void:
	var pad := HudOverlay.new()
	pad.run = run
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(pad)
	screen.move_child(pad,1)
	var score_card := PanelContainer.new()
	score_card.custom_minimum_size = Vector2(172,0)
	score_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(score_card)
	var column := _vbox(score_card,-6)
	var mode := NestRun.chosen_mode()
	score_title = _center_label(column,{"classic": "Kinu Piled", "tower": "Tower Height", "rush": "Bentos Packed"}[mode],15,NestTheme.MUTED)
	score_label = NestTheme.headline("0",40,NestTheme.SUN)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(score_label)
	best_label = _center_label(column,"Best 0",15,NestTheme.MUTED)
	tumble_meter = TumbleMeter.new()
	tumble_meter.total = NestRun.MAX_TUMBLES
	column.add_child(tumble_meter)
	tumble_meter.visible = mode != "rush" or NestRun.PACKING_RUSH
	var next_card := PanelContainer.new()
	next_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	next_card.offset_left = -124
	next_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	content.add_child(next_card)
	# The bottle waits under the Next card; its count is the squirts left this run.
	bottle_button = NestTheme.button("×1",func() -> void: run.toggle_bottle())
	bottle_button.name = "ShoyuBottle"
	bottle_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bottle_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bottle_button.offset_left = -124
	bottle_button.offset_top = 158
	bottle_button.custom_minimum_size = Vector2(124,62)
	bottle_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottle_button.add_theme_font_size_override("font_size",24)
	var bottle_icon := ShoyuBottle.Icon.new()
	bottle_icon.tint = Color(str(NestRun.SAUCES[NestRun.BOTTLE_SAUCE].tint)).darkened(.25)
	bottle_icon.position = Vector2(16,8)
	bottle_icon.size = Vector2(30,40)
	bottle_button.add_child(bottle_icon)
	content.add_child(bottle_button)
	# Sits under the bottle and only appears once the box is worth closing, so the choice to ship
	# now or keep packing is the player's.
	ship_button = NestTheme.button(tr("Close Lid"),func() -> void: run.ship_box(),true)
	ship_button.name = "ShipBox"
	ship_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ship_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ship_button.offset_left = -124
	ship_button.offset_top = 228
	ship_button.custom_minimum_size = Vector2(124,58)
	ship_button.add_theme_font_size_override("font_size",19)
	ship_button.hide()
	content.add_child(ship_button)
	next_slot = _vbox(next_card,0)
	var pause_button := NestTheme.button("II",_pause,false,"plop")
	pause_button.custom_minimum_size = Vector2(70,70)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pause_button.offset_left = -35
	pause_button.offset_right = 35
	pause_button.offset_bottom = 70
	content.add_child(pause_button)
	var height_pill := NestTheme.pill("0 cm",22)
	height_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	height_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	height_pill.offset_top = 82
	content.add_child(height_pill)
	height_label = height_pill.get_child(0)
	timer_pill = null
	box_pill = null
	if mode == "rush" and not NestRun.PACKING_RUSH:
		# Bento Flip trades the height readout for the remaining tosses and current bento progress.
		height_pill.hide()
		timer_pill = NestTheme.pill("12 tosses",24)
		timer_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		timer_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		timer_pill.offset_top = 80
		content.add_child(timer_pill)
		box_pill = NestTheme.pill("",17)
		box_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		box_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		box_pill.offset_top = 136
		content.add_child(box_pill)
		var charge := BentoChargeMeter.new()
		charge.run = run
		charge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		charge.grow_horizontal = Control.GROW_DIRECTION_BOTH
		charge.offset_top = 182
		charge.offset_bottom = 210
		content.add_child(charge)
	if Save.data.controls == "claw" and not (mode == "rush" and not NestRun.PACKING_RUSH):
		_build_claw_controls()
	else:
		var hint := "Pack the box  ·  close the lid when it's full" if mode == "rush" and NestRun.PACKING_RUSH else "Hold to flip  ·  swipe bottom strip to spin" if mode == "rush" else "Drag Kinu to move  ·  swipe to spin" if Save.data.controls == "grab" else "Drag to move  ·  let go to drop"
		hint_pill = NestTheme.pill(hint,18)
		hint_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		hint_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		hint_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
		hint_pill.offset_bottom = -12
		if Save.data.controls == "classic":
			hint_pill.anchor_top = .78
			hint_pill.anchor_bottom = .78
			screen.add_child(hint_pill)
		else:
			content.add_child(hint_pill)
	pad.hint = hint_pill
	pad.app = self

## The claw scheme: a column down one side of the screen (right, or left for left-handed play)
## with the move stick on top, Drop in the middle and the spin stick below. Each stick tracks its
## own finger, so both can be held at once.
func _build_claw_controls() -> void:
	var left_handed: bool = Save.data.claw_hand == "left"
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation",6)
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if left_handed else Control.PRESET_BOTTOM_RIGHT)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.grow_horizontal = Control.GROW_DIRECTION_END if left_handed else Control.GROW_DIRECTION_BEGIN
	content.add_child(column)
	var move_stick := Joystick.new()
	move_stick.kind = "move"
	move_stick.label = "Move"
	move_stick.run = run
	column.add_child(move_stick)
	var drop_row := CenterContainer.new()
	drop_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(drop_row)
	drop_button = NestTheme.button("Drop",func() -> void: run.drop(),false,"plop")
	drop_button.custom_minimum_size = Vector2(96,96)
	drop_button.add_theme_font_size_override("font_size",24)
	for state in ["normal","hover","pressed","disabled"]:
		var fill: Color = {"normal": NestTheme.SUN, "hover": NestTheme.SUN.lightened(.12), "pressed": NestTheme.SUN.darkened(.08), "disabled": Color("d9c7a8")}[state]
		var round := NestTheme.box(fill,48,NestTheme.INK,4 if state == "pressed" else 8)
		round.content_margin_left = 0
		round.content_margin_right = 0
		drop_button.add_theme_stylebox_override(state,round)
	drop_row.add_child(drop_button)
	var spin_stick := Joystick.new()
	spin_stick.kind = "spin"
	spin_stick.label = "Spin"
	spin_stick.run = run
	column.add_child(spin_stick)
	hint_pill = NestTheme.pill("Move, spin, then tap Drop",18)
	hint_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_pill.offset_top = 136
	content.add_child(hint_pill)

func _hud_update() -> void:
	if page != "play" or not is_instance_valid(score_label):
		return
	match run.mode:
		"tower":
			score_label.text = KinuFlavour.height_text(run.score)
			best_label.text = tr("Best %s")%KinuFlavour.height_text(NestRun.best_for("tower"))
			height_label.text = tr("%d Kinu")%run.pile_count()
		"rush":
			score_label.text = _number(run.score)
			best_label.text = tr("Best %s")%_number(NestRun.best_for("rush"))
		_:
			score_label.text = _number(run.score)
			best_label.text = tr("Best %s")%_number(Save.data.best)
	tumble_meter.used = run.tumbles
	if is_instance_valid(bottle_button):
		bottle_button.text = "×%d"%run.squirts
		bottle_button.disabled = run.state != "aim" or (run.squirts == 0 and run.aim_mode != "bottle")
		NestTheme.set_primary(bottle_button,run.aim_mode == "bottle")
	if is_instance_valid(drop_button):
		drop_button.text = tr("Squirt") if run.aim_mode == "bottle" else tr("Drop")
		drop_button.disabled = run.state != "aim"
	if is_instance_valid(ship_button):
		ship_button.visible = run.can_ship()
	if run.lid_mode():
		# What matters while packing is how full this box is, not how tall the pile got.
		height_label.text = tr("%d / %d packed")%[run.packed_count(),run.pack_target()]
	elif run.mode == "classic":
		height_label.text = KinuFlavour.height_text(NestRun.height_cm(run.tower_height))
	if is_instance_valid(timer_pill):
		var tosses := int(run.time_left)
		var toss_label: Label = timer_pill.get_child(0)
		toss_label.text = tr("%d tosses")%tosses
		toss_label.add_theme_color_override("font_color",Color("e0463a") if tosses <= 3 else NestTheme.INK)
		(box_pill.get_child(0) as Label).text = tr("Bento %d  ·  %d / %d")%[run.boxes_shipped+1, mini(run.pile_count(),NestRun.RUSH_BOX_TARGET), NestRun.RUSH_BOX_TARGET]
	hint_pill.visible = run.placed < 3 and run.state == "aim" and tutorial_step < 0
	for child in next_slot.get_children():
		next_slot.remove_child(child)
		child.queue_free()
	_center_label(next_slot,"Next",15,NestTheme.MUTED)
	if run.next_shape:
		var finish: KinuFlavour = run.pattern_for(run.next_flavour)
		var outfit: KinuOutfit = run.catalog.outfit(str(Save.data.outfit))
		var preview := KinuPreview.new()
		preview.setup(run.next_shape,finish if finish else run.next_flavour,true,Vector2i(100,76),"calm",outfit,false,run.next_special == "sticky")
		preview.fit_model(1.04)
		next_slot.add_child(preview)
		if run.next_special != "":
			var badge := SpecialBadge.new()
			badge.kind = run.next_special
			badge.size = Vector2(34,34)
			badge.position = Vector2(66,-4)
			preview.add_child(badge)
		var special_names := {"lucky": "Lucky Kinu", "heart": "Heart Kinu", "tiny": "Tiny Kinu", "sticky": "Sticky Kinu"}
		var next_name := tr(special_names[run.next_special]) if special_names.has(run.next_special) else tr("%s Kinu")%tr(run.next_flavour.display_name)
		var name_label := _center_label(next_slot,next_name,14,SpecialBadge.COLORS[run.next_special].darkened(.35) if special_names.has(run.next_special) else NestTheme.INK)
		name_label.clip_text = true
		name_label.custom_minimum_size.x = 100
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _toast(text: String, color: Color) -> void:
	if page != "play":
		return
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast.text = text
	# Messages sit in a cream pill, so their colour is darkened for contrast against it.
	toast.add_theme_color_override("font_color",color.darkened(.15))
	var extent := toast_panel.get_combined_minimum_size()
	toast_panel.offset_left = -extent.x*.5
	toast_panel.offset_right = extent.x*.5
	toast_panel.offset_top = -extent.y*.5
	toast_panel.offset_bottom = extent.y*.5
	toast_panel.modulate.a = 1
	toast_panel.pivot_offset = extent*.5
	toast_panel.scale = Vector2(.6,.6)
	toast_tween = create_tween()
	toast_tween.tween_property(toast_panel,"scale",Vector2.ONE,.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toast_tween.tween_interval(1.6)
	toast_tween.tween_property(toast_panel,"modulate:a",0.0,.4)

## Page header: one wooden sign contains both navigation and a title centred across the page.
func _header(title: String, callback: Callable = _home) -> VBoxContainer:
	var layout := _vbox(content,14)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plank := PanelContainer.new()
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.custom_minimum_size.y = 72
	plank.add_theme_stylebox_override("panel",NestTheme.box(NestTheme.WOOD,20,NestTheme.INK,8))
	layout.add_child(plank)
	# PanelContainer lays out this one canvas; the title and back button then share the same sign
	# without the back button consuming a column and shifting the title off the page centre.
	var canvas := Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.add_child(canvas)
	var label := NestTheme.headline(title,28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(label)
	var back := NestTheme.button("",func() -> void:
		Sound.play("plop")
		callback.call()
	)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.position = Vector2.ZERO
	back.size = Vector2(58, 54)
	back.custom_minimum_size = Vector2.ZERO
	for state in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	canvas.add_child(back)
	# Draw the chevron instead of relying on a font glyph. Its point geometry stays centred in
	# the fixed left-hand hit area at every page width, while the title stays centred in the sign.
	var chevron_points := PackedVector2Array([Vector2(35, 14), Vector2(22, 27), Vector2(35, 40)])
	var chevron_outline := Line2D.new()
	chevron_outline.points = chevron_points
	chevron_outline.width = 9
	chevron_outline.default_color = NestTheme.INK
	chevron_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	chevron_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	chevron_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	back.add_child(chevron_outline)
	var chevron := Line2D.new()
	chevron.points = chevron_points
	chevron.width = 4
	chevron.default_color = NestTheme.CREAM
	chevron.joint_mode = Line2D.LINE_JOINT_ROUND
	chevron.begin_cap_mode = Line2D.LINE_CAP_ROUND
	chevron.end_cap_mode = Line2D.LINE_CAP_ROUND
	back.add_child(chevron)
	return layout

## Wraps text in a paper strip, for readable copy sitting on wood.
func _paper_text(parent: Node, text: String, font_size: int = 18) -> Label:
	var label := NestTheme.label(text,font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(NestTheme.paper(label))
	return label

func _collection() -> void:
	KinuBookScreen.show(self)

func _flavour_detail(flavour: KinuFlavour, known: bool) -> void:
	KinuBookScreen.flavour_detail(self, flavour, known)

func _shop() -> void:
	shop_back = _home
	_show_shop()

func _show_shop() -> void:
	KinuShopScreen.show(self)

func _bean_shop(section: String = "beans") -> void:
	Sound.play("cashregister")
	if page == "shop":
		bean_shop_back = _show_shop
	elif page == "catcher":
		bean_shop_back = func() -> void: KinuCatcherScreen.show(self)
	else:
		bean_shop_back = _home
	BeanShop.open(self, bean_shop_back, section)

func _wardrobe() -> void:
	wardrobe_back = _home
	_show_wardrobe()

func _show_wardrobe() -> void:
	WardrobeScreen.show(self)

func _settings() -> void:
	NestSettingsScreen.show(self)

func _credits() -> void:
	NestSettingsScreen.credits(self)

func _leaderboards() -> void:
	game_center.show_leaderboard(NestRun.chosen_mode())

func _modal(title: String) -> VBoxContainer:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.process_mode = Node.PROCESS_MODE_ALWAYS
	# DragScroll listens globally so it can support touch drags; mark this overlay so lists below it
	# do not react to gestures meant for an item preview or its buttons.
	modal.add_to_group("modal_input_lock")
	screen.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(.12,.07,.05,.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var sign := SignBoard.new()
	sign.ropes = false
	sign.custom_minimum_size.x = minf(430,get_viewport().get_visible_rect().size.x-40)
	center.add_child(sign)
	var stack := _vbox(sign,14)
	var heading := NestTheme.headline(title,34)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(heading)
	return stack

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null

func _pause() -> void:
	if page != "play" or get_tree().paused:
		return
	run.gesture = ""
	run.pointer_id = -99
	get_tree().paused = true
	NestMenuScreen.pause(self)

func _results(stats: Dictionary) -> void:
	var mode := str(stats.get("mode","classic"))
	if mode in ["classic", "tower"]:
		game_center.submit_score(mode, int(stats.get("score", 0)))
	NestMenuScreen.results(self, stats)
	show_ad_after_run()

func _confetti() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 30:
		var star := NestTheme.headline("★",rng.randi_range(22,40),[NestTheme.SUN,NestTheme.BERRY,NestTheme.SKY,Color("7ed957")][i%4])
		star.position = Vector2(rng.randf_range(0,500),-80)
		screen.add_child(star)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(star,"position:y",1100,rng.randf_range(3.5,6)).set_delay(i*.05)
		tween.tween_property(star,"rotation",rng.randf_range(-3,3),4)
		tween.chain().tween_callback(star.queue_free)
		confetti_stars.append(star)
		confetti_tweens.append(tween)

## Sweeps up a burst still in the air. The tweens are bound to this node rather than to the stars,
## so they outlive the screen the stars were added to unless they are stopped here.
func _clear_confetti() -> void:
	for tween in confetti_tweens:
		if tween and tween.is_valid():
			tween.kill()
	confetti_tweens.clear()
	for star in confetti_stars:
		if is_instance_valid(star):
			star.hide()
			star.queue_free()
	confetti_stars.clear()

func _tutorial_steps() -> Array:
	var grab: bool = Save.data.controls == "grab"
	var claw: bool = Save.data.controls == "claw"
	return [
		["Left Stick Aims","Push the left stick to move Kinu. The shadow shows where it lands."] if claw \
			else ["Grab Kinu","Press on Kinu and drag to move it. The shadow shows where it lands."] if grab \
			else ["Drag To Aim","Drag anywhere to move Kinu. The shadow shows where it lands."],
		["Tap Drop","Tap the Drop button and watch Kinu plop into the box."] if claw \
			else ["Let Go To Drop","Lift your finger and watch Kinu plop into the box."],
		["Spin The Box","Push the right stick to turn the box."] if claw \
			else ["Spin The Box","Swipe anywhere else to turn the box. Swipe up or down to tilt the view."] if grab \
			else ["Spin The Box","Swipe along the bottom strip to turn the box. Swipe up or down to tilt the view."],
		["Pile Them Up","Your score is how many Kinu are on the pile, not how tall it is. Fill the box, then stack up when it's full."],
		["Sticky Kinu","You're holding one — see the syrup badge. Anything it touches is glued in place, so drop it where the pile needs holding together."],
		["Nigari","Tap the bottle icon to pick it up, aim it over a crowded spot and let go. Nigari makes up to three Kinu smaller and frees up room. You earn another at 20, 35 and 50 Kinu."],
		["Careful!","Kinu that tumble onto the counter don't count. Six tumbles and the run is over."]]

func _build_tutorial() -> void:
	tutorial_panel = TutorialCoach.new()
	screen.add_child(tutorial_panel)
	tutorial_panel.build(self,safe_bottom)
	_tutorial_refresh()

func _tutorial_refresh() -> void:
	if is_instance_valid(tutorial_panel):
		tutorial_panel.refresh(tutorial_step,_tutorial_steps())
	# The queue always runs a turn ahead, so each subject is ordered one step before the card that
	# explains it. The card itself only turns over once that subject is actually in hand.
	if is_instance_valid(run):
		if tutorial_step == 3 and run.next_special != "sticky":
			run.forced_special = "sticky"


func _tutorial_action(action: String) -> void:
	if tutorial_step<0 or page!="play":
		return
	var expected := ["aim","drop","spin","sticky_ready","settle","squirt"]
	if tutorial_step<expected.size() and action==expected[tutorial_step]:
		if action=="squirt":
			# The practice squirt is on the house: the guide shouldn't cost a real charge.
			run.squirts += 1
			run.updated.emit()
		tutorial_step += 1
		_tutorial_refresh()

func _finish_tutorial() -> void:
	Save.setting("tutorial",true)
	tutorial_step = -1
	_hud_update()
	if is_instance_valid(tutorial_panel):
		tutorial_panel.queue_free()
		tutorial_panel = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Save.persist()
		Sound.shutdown()
		await get_tree().create_timer(.15,true).timeout
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and page=="play":
		_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if page=="play":
			_pause()
		elif page == "beans" and bean_shop_back.is_valid():
			bean_shop_back.call()
		elif page in ["collection","settings","credits","shop","wardrobe"]:
			_home()

func _number(value: Variant) -> String:
	var raw := str(int(value))
	var result := ""
	for i in raw.length():
		if i>0 and (raw.length()-i)%3==0:
			result += ","
		result += raw[i]
	return result

## A banner on menu/shop/settings screens plus a rare interstitial (every 2nd run),
## both skipped entirely once Remove Ads is bought - see Store's ads_removed flag.
func setup_admob() -> void:
	if OS.get_name() != "iOS" or Store.ads_removed() or is_instance_valid(admob): return
	if not Engine.has_singleton("AdmobPlugin"):
		push_error("[Ads] Native AdmobPlugin missing from this export")
		return
	admob = Admob.new()
	var ads := admob
	ads.is_real = admob_is_real
	ads.ios_real_application_id = ADMOB_APP_ID
	ads.ios_real_banner_id = ADMOB_BANNER_ID
	ads.ios_real_interstitial_id = ADMOB_INTERSTITIAL_ID
	ads.att_enabled = true
	ads.att_text = "This identifier lets us show you ads relevant to you."
	ads.banner_anchor_to_safe_area = true
	add_child(ads)
	ads.tracking_authorization_granted.connect(func() -> void: _on_ads_tracking_resolved(ads, true))
	ads.tracking_authorization_denied.connect(func() -> void: _on_ads_tracking_resolved(ads, false))
	ads.initialization_completed.connect(func(_status: Variant) -> void:
		if not _ads_session_active(ads): return
		print("[Ads] SDK initialized")
		_load_initial_ads(ads))
	ads.banner_ad_loaded.connect(func(_ad_info: Variant, _response_info: Variant) -> void:
		if not _ads_session_active(ads): return
		print("[Ads] Banner loaded")
		_sync_banner()
		call_deferred("refresh_banner_inset"))
	ads.banner_ad_size_measured.connect(func(_ad_info: Variant) -> void: call_deferred("refresh_banner_inset"))
	ads.banner_ad_failed_to_load.connect(func(_ad_info: Variant, error_data: Variant) -> void:
		push_warning("[Ads] Banner load failed (%s/%s): %s" % [error_data.get_domain(), error_data.get_code(), error_data.get_message()]))
	ads.interstitial_ad_loaded.connect(func(_ad_info: Variant, _response_info: Variant) -> void: print("[Ads] Interstitial loaded"))
	ads.interstitial_ad_failed_to_load.connect(func(_ad_info: Variant, error_data: Variant) -> void:
		push_warning("[Ads] Interstitial load failed (%s/%s): %s" % [error_data.get_domain(), error_data.get_code(), error_data.get_message()]))
	ads.consent_info_updated.connect(func() -> void: _on_ads_consent_updated(ads))
	ads.consent_info_update_failed.connect(func(error_data: Variant) -> void:
		push_warning("[Ads] Consent update failed: %s" % error_data.get_message())
		_continue_ads_after_consent(ads))
	ads.consent_form_loaded.connect(func() -> void:
		if not _ads_session_active(ads): return
		print("[Ads] Consent form loaded; presenting")
		ads.show_consent_form())
	ads.consent_form_dismissed.connect(func(error_data: Variant) -> void:
		if error_data.get_message() != "":
			push_warning("[Ads] Consent presentation failed: %s" % error_data.get_message())
		_continue_ads_after_consent(ads))
	ads.consent_form_failed_to_load.connect(func(error_data: Variant) -> void:
		push_warning("[Ads] Consent form load failed: %s" % error_data.get_message())
		_continue_ads_after_consent(ads))
	print("[Ads] Updating consent; real ad units: %s" % admob_is_real)
	ads.update_consent_info()

## StoreKit can grant Remove Ads while the app is already running. AdMob banners
## live outside Godot's canvas, so changing the saved entitlement alone does not
## dismiss one that is already on screen; tear down the native ad session too.
## A later revocation starts a fresh session without requiring an app restart.
func _store_changed() -> void:
	if Store.ads_removed():
		_stop_admob()
	elif not is_instance_valid(admob):
		setup_admob()

func _stop_admob() -> void:
	if not is_instance_valid(admob):
		return
	var ads := admob
	# Invalidate the session before native callbacks from an in-flight load arrive.
	admob = null
	if ads.is_banner_ad_loaded():
		ads.hide_banner_ad()
	_banner_visible = false
	ads.queue_free()
	# Removing the native banner also removes the space reserved above the UI.
	_resized()

func _ads_session_active(ads: Admob) -> bool:
	return is_instance_valid(ads) and admob == ads and not Save.data.get("ads_removed", false)

func _on_ads_consent_updated(ads: Admob) -> void:
	if not _ads_session_active(ads): return
	var consent := ads.get_consent_status()
	print("[Ads] Consent status: %s; can request ads: %s" % [consent.to_status_string(), ads.can_request_ads()])
	if consent.status == UserConsent.Status.REQUIRED and ads.is_consent_form_available():
		print("[Ads] Loading required consent form before SDK initialization")
		ads.load_consent_form()
	else:
		_continue_ads_after_consent(ads)

func _continue_ads_after_consent(ads: Admob) -> void:
	if not _ads_session_active(ads): return
	if not ads.can_request_ads():
		push_warning("[Ads] UMP does not yet permit ads; retrying consent in 30 seconds")
		if ads.has_meta("consent_retry_pending"): return
		ads.set_meta("consent_retry_pending", true)
		await get_tree().create_timer(30.0).timeout
		if not _ads_session_active(ads): return
		ads.remove_meta("consent_retry_pending")
		ads.update_consent_info()
		return
	if ads.has_meta("tracking_requested"): return
	ads.set_meta("tracking_requested", true)
	print("[Ads] Consent resolved; requesting ATT when iOS is active")
	ads.request_tracking_authorization()

func _on_ads_tracking_resolved(ads: Admob, authorized: bool) -> void:
	if not _ads_session_active(ads) or not ads.can_request_ads(): return
	if ads.has_meta("sdk_start_requested"): return
	ads.set_meta("sdk_start_requested", true)
	print("[Ads] ATT resolved (authorized: %s); starting ads" % authorized)
	# The native singleton outlives an Admob node (for example, a restored
	# purchase can remove that node). Reuse an already initialized SDK.
	if ads.is_sdk_initialized():
		ads.set_request_configuration()
		ads.is_initialization_completed = true
		_load_initial_ads(ads)
	else:
		ads.initialize()

func _load_initial_ads(ads: Admob) -> void:
	if not _ads_session_active(ads) or not ads.can_request_ads(): return
	if ads.has_meta("initial_ads_requested"): return
	ads.set_meta("initial_ads_requested", true)
	print("[Ads] Loading banner and interstitial")
	ads.load_banner_ad()
	ads.load_interstitial_ad()

func refresh_banner_inset() -> void:
	if not is_instance_valid(admob): return
	var measured := admob.get_banner_dimension_in_pixels().y
	var new_inset := banner_inset
	if measured > 1.0:
		# The plugin reports physical pixels, while the Godot canvas may be
		# letterboxed/scaled. Convert before using it as a layout inset; using the
		# raw number is what created the oversized blank header on the phone.
		var screen_size := DisplayServer.screen_get_size()
		var viewport := get_viewport().get_visible_rect().size
		var canvas_scale := viewport.y/float(screen_size.y) if screen_size.y > 0 else 1.0
		new_inset = maxf(56.0,measured*canvas_scale+8.0)
	# Re-showing the banner after a rebuild can re-fire this same measurement signal;
	# only rebuild the screen once the inset actually settles on a new value, or a
	# measure/rebuild/measure loop chews through Controls until the app crashes.
	var changed := absf(new_inset-banner_inset) > 1.0
	banner_inset = new_inset
	_sync_banner()
	if is_instance_valid(content):
		content.offset_top = safe_top
	if changed and page == "home":
		_home()

# Counts finished runs rather than starts, so a player who quits mid-run doesn't
# rack up interstitials, and the count survives across screens between runs.
func show_ad_after_run() -> void:
	if Save.data.get("ads_removed", false) or not is_instance_valid(admob): return
	deaths_since_interstitial += 1
	if deaths_since_interstitial < 2: return
	deaths_since_interstitial = 0
	await get_tree().create_timer(1.4,true,false,true).timeout
	if Save.data.get("ads_removed", false) or not is_instance_valid(admob): return
	if admob.is_interstitial_ad_loaded(): admob.show_interstitial_ad()
	admob.load_interstitial_ad()
